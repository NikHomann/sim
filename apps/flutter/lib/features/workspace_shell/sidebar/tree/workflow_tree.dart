import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/sidebar/presence/presence_avatars.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/context_menu.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/inline_rename.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/sidebar_chip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_events.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/delete_modal.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/drop_logic.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_cubit.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_menus.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_model.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_operations.dart';
import 'package:sim_design/sim_design.dart';

/// `TREE_SPACING.INDENT_PER_LEVEL`.
const double treeIndentPerLevel = 20;

/// Row gap of the tree (`space-y-0.5`).
const double treeRowGap = 2;

/// `SCROLL_THRESHOLD` / `SCROLL_SPEED` of `use-drag-drop.ts`.
const double autoScrollThreshold = 60;
const double autoScrollSpeed = 8;

/// The 12px edge drop zones of the root list.
const double edgeZoneHeight = 12;

/// The 24px drop zone of an empty expanded folder while dragging.
const double emptyFolderZoneHeight = 24;

/// Interval of the drag auto-scroll loop (one animation frame).
const Duration autoScrollTick = Duration(milliseconds: 16);

/// Parity id of the row context menu (`sidebar.tree.context-menu`); its
/// items are `.item.<id>`, its separator `.separator`.
const String treeContextMenuId = 'sidebar.tree.context-menu';

/// `WorkflowList` (`components/workflow-list/workflow-list.tsx`): the
/// folder/workflow tree of the expanded rail with selection, inline rename,
/// row context menus, the empty-area menu and drag and drop.
class WorkflowTree extends StatefulWidget {
  const WorkflowTree({
    required this.workspaceId,
    required this.services,
    required this.operations,
    required this.canEdit,
    required this.canAdmin,
    required this.disableCreate,
    super.key,
    this.scrollController,
    this.scrollViewportKey,
    this.presence = const <PresenceUser>[],
    this.sidebarWidth = 224,
  });

  final String workspaceId;
  final SidebarServices services;
  final TreeOperations operations;
  final bool canEdit;
  final bool canAdmin;

  /// `!canEdit || isCreatingWorkflow || isCreatingFolder` (empty-area menu).
  final bool disableCreate;

  /// The sidebar scroll region (auto-scroll and scroll-to-item).
  final ScrollController? scrollController;
  final GlobalKey? scrollViewportKey;

  /// Presence on the open workflow (Phase 2; empty in Phase 1).
  final List<PresenceUser> presence;
  final double sidebarWidth;

  @override
  State<WorkflowTree> createState() => WorkflowTreeState();
}

enum _ZoneKind { workflow, folder }

class _Zone {
  _Zone({
    required this.kind,
    required this.id,
    required this.scope,
    required this.key,
  });

  final _ZoneKind kind;
  final String id;

  /// The folder the row sits in (`null` = root).
  final String? scope;
  final GlobalKey key;
}

class WorkflowTreeState extends State<WorkflowTree> {
  final GlobalKey _rootZoneKey = GlobalKey(debugLabel: 'tree.root-zone');
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _childrenKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _emptyZoneKeys = <String, GlobalKey>{};
  List<_Zone> _zones = <_Zone>[];
  List<String> _childrenZones = <String>[];
  List<String> _emptyZones = <String>[];
  String? _firstRootId;
  String? _lastRootId;

  Offset? _lastPointer;
  Timer? _autoScroll;
  StreamSubscription<String>? _scrollRequests;
  SimMenuHandle? _menu;
  bool _initialScrollDone = false;

  /// The inputs the last reveal ran for (`workflow-list.tsx:360-372`
  /// re-runs on every route, folder map or workflow list change).
  String? _revealedFor;
  List<Folder>? _revealedFolders;
  List<WorkflowListItem>? _revealedWorkflows;

  /// The primary pointer that went down on the tree (the one a drag rides
  /// on), so Escape can cancel the drag like the browser does.
  PointerDownEvent? _pointerDown;
  bool _escapeHandlerAdded = false;
  final FocusNode _treeFocus = FocusNode(
    debugLabel: 'sidebar.tree',
    skipTraversal: true,
  );

  /// Set at drag start, cleared one frame after drag end: the click that
  /// follows a drop must not toggle or navigate (`shouldPreventClickRef`).
  bool suppressClick = false;

  SidebarTreeCubit get _tree => widget.services.tree;
  TreeOperations get _ops => widget.operations;

  @override
  void initState() {
    super.initState();
    _scrollRequests = SidebarEvents.scrollToItemRequests.listen(scrollToItem);
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    _removeEscapeHandler();
    unawaited(_scrollRequests?.cancel());
    _menu?.close();
    _treeFocus.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(Map<String, GlobalKey> map, String id) =>
      map.putIfAbsent(id, () => GlobalKey(debugLabel: id));

  // Scroll-to-item.

  /// `sidebar-scroll-to-item`: up to 10 frames to find the row; centred
  /// only when it lies outside the scroll region.
  void scrollToItem(String itemId, [int attempt = 0]) {
    if (!mounted) return;
    final rowContext = _rowKeys[itemId]?.currentContext;
    if (rowContext == null) {
      if (attempt >= 9) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => scrollToItem(itemId, attempt + 1),
      );
      WidgetsBinding.instance.scheduleFrame();
      return;
    }
    final viewport = _globalRect(widget.scrollViewportKey?.currentContext);
    final row = _globalRect(rowContext);
    if (viewport == null || row == null) return;
    final visible = row.top >= viewport.top && row.bottom <= viewport.bottom;
    if (visible) return;
    unawaited(
      Scrollable.ensureVisible(
        rowContext,
        alignment: 0.5,
        duration: SimMotion.of(const Duration(milliseconds: 300)),
        curve: SimMotion.easeOut,
      ),
    );
  }

  Rect? _globalRect(BuildContext? context) {
    final box = context?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  // Drag and drop.

  void _onDragStarted(DragSelection selection, String? scope) {
    suppressClick = true;
    _menu?.close();
    if (!_escapeHandlerAdded) {
      _escapeHandlerAdded = true;
      HardwareKeyboard.instance.addHandler(_onDragKey);
    }
    _tree.dragStart(
      sourceFolderId: scope,
      draggingIds: <String>{...selection.workflowIds, ...selection.folderIds},
    );
    _autoScroll?.cancel();
    _autoScroll = Timer.periodic(autoScrollTick, (_) => runAutoScrollTick());
  }

  void _removeEscapeHandler() {
    if (!_escapeHandlerAdded) return;
    _escapeHandlerAdded = false;
    HardwareKeyboard.instance.removeHandler(_onDragKey);
  }

  /// Escape during a drag cancels it the way native DnD does: the pointer
  /// the drag rides on is cancelled, so the drag ends with no drop (no
  /// requests) and `handleDragEnd` closes the folders it spring-opened.
  bool _onDragKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        !_tree.state.isDragging) {
      return false;
    }
    cancelDrag();
    return true;
  }

  /// Cancels the drag in progress (Escape).
  void cancelDrag() {
    final down = _pointerDown;
    _pointerDown = null;
    if (down != null) {
      GestureBinding.instance.handlePointerEvent(
        PointerCancelEvent(
          timeStamp: down.timeStamp,
          pointer: down.pointer,
          kind: down.kind,
          device: down.device,
          position: _lastPointer ?? down.position,
        ),
      );
    }
    if (_tree.state.isDragging) _onDragEnded();
  }

  void _onDragEnded() {
    _removeEscapeHandler();
    _autoScroll?.cancel();
    _autoScroll = null;
    _lastPointer = null;
    _tree.dragEnd();
    WidgetsBinding.instance.addPostFrameCallback((_) => suppressClick = false);
    WidgetsBinding.instance.scheduleFrame();
  }

  /// One frame of `handleAutoScroll`: within 60px of the scroll region's
  /// top or bottom edge, scroll by up to 8px scaled by proximity.
  void runAutoScrollTick() {
    final controller = widget.scrollController;
    final pointer = _lastPointer;
    final viewport = _globalRect(widget.scrollViewportKey?.currentContext);
    if (controller == null || !controller.hasClients || pointer == null) return;
    if (viewport == null) return;
    if (pointer.dy < viewport.top || pointer.dy > viewport.bottom) return;
    final position = controller.position;
    final fromTop = pointer.dy - viewport.top;
    final fromBottom = viewport.bottom - pointer.dy;
    var delta = 0.0;
    if (fromTop < autoScrollThreshold && position.pixels > 0) {
      final intensity = (1 - fromTop / autoScrollThreshold).clamp(0.0, 1.0);
      delta = -autoScrollSpeed * intensity;
    } else if (fromBottom < autoScrollThreshold &&
        position.pixels < position.maxScrollExtent) {
      final intensity = (1 - fromBottom / autoScrollThreshold).clamp(0.0, 1.0);
      delta = autoScrollSpeed * intensity;
    }
    if (delta == 0) return;
    controller.jumpTo(
      (position.pixels + delta).clamp(0.0, position.maxScrollExtent),
    );
  }

  /// Resolves the drop indicator for a pointer position the way the DOM
  /// handlers do: the 12px edge zones over everything, then the row under
  /// the pointer, then an empty folder's 24px zone, then a folder's own
  /// children container (its 2px top margin), then the empty root zone.
  /// Gaps between rows keep the previous indicator.
  void resolveDragOver(Offset global, SidebarTree tree) {
    _lastPointer = global;
    final state = _tree.state;
    final source = _tree.dragSourceFolderId;
    List<SiblingItem> siblings(String? scope) => tree.siblingsOf(scope);
    final root = _globalRect(_rootZoneKey.currentContext);
    if (root == null) return;
    final hasRootItems = _firstRootId != null;
    if (state.isDragging && hasRootItems && root.contains(global)) {
      if (global.dy < root.top + edgeZoneHeight) {
        _tree
          ..setHoverFolder(null)
          ..setIndicator(
            DropIndicator(
              targetId: _firstRootId!,
              position: DropPosition.before,
              folderId: null,
            ),
            siblings,
            normalize: false,
          );
        return;
      }
      if (global.dy > root.bottom - edgeZoneHeight) {
        _tree
          ..setHoverFolder(null)
          ..setIndicator(
            DropIndicator(
              targetId: _lastRootId!,
              position: DropPosition.after,
              folderId: null,
            ),
            siblings,
            normalize: false,
          );
        return;
      }
    }
    for (final zone in _zones) {
      final rect = _globalRect(zone.key.currentContext);
      if (rect == null || !rect.contains(global)) continue;
      final dy = global.dy - rect.top;
      if (zone.kind == _ZoneKind.workflow) {
        _tree
          ..setHoverFolder(null)
          ..setIndicator(
            workflowRowIndicator(
              workflowId: zone.id,
              folderId: zone.scope,
              sourceFolderId: source,
              dy: dy,
              height: rect.height,
            ),
            siblings,
          );
      } else {
        final result = folderRowIndicator(
          folderId: zone.id,
          parentFolderId: zone.scope,
          sourceFolderId: source,
          dy: dy,
          height: rect.height,
        );
        _tree
          ..setIndicator(result.indicator, siblings)
          ..setHoverFolder(result.hover ? zone.id : null);
      }
      return;
    }
    _tree.setHoverFolder(null);
    for (final folderId in _emptyZones) {
      final rect = _globalRect(_emptyZoneKeys[folderId]?.currentContext);
      if (rect != null && rect.contains(global)) {
        _tree.setIndicator(
          DropIndicator(
            targetId: folderId,
            position: DropPosition.inside,
            folderId: folderId,
          ),
          siblings,
        );
        return;
      }
    }
    for (final folderId in _childrenZones.reversed) {
      final rect = _globalRect(_childrenKeys[folderId]?.currentContext);
      if (rect == null) continue;
      final margin = Rect.fromLTWH(rect.left, rect.top, rect.width, treeRowGap);
      if (margin.contains(global)) {
        if (source != folderId) {
          _tree.setIndicator(
            DropIndicator(
              targetId: folderId,
              position: DropPosition.inside,
              folderId: null,
            ),
            siblings,
          );
        }
        return;
      }
    }
    if (!hasRootItems && root.contains(global)) {
      _tree.setIndicator(
        const DropIndicator(
          targetId: rootDropTarget,
          position: DropPosition.inside,
          folderId: null,
        ),
        siblings,
      );
    }
  }

  Future<void> _onDrop(DragSelection selection, SidebarTree tree) async {
    final indicator = _tree.takeDrop(tree);
    if (indicator == null) return;
    await _ops.drop(selection, indicator);
  }

  // Context menus.

  void _trackMenu(String id, SimMenuHandle handle) {
    _menu = handle;
    _tree.setMenuOpen(id);
    unawaited(
      handle.closed.then((_) {
        if (_tree.state.menuOpenId == id) _tree.setMenuOpen(null);
      }),
    );
  }

  /// Right-click / "…" on a workflow row (`workflow-item.tsx:208-286`).
  void openWorkflowMenu(WorkflowListItem workflow, Offset position) {
    final captured = _tree.captureForWorkflow(workflow.id);
    final tree = _ops.snapshot();
    final canDelete =
        tree.canDeleteWorkflows(captured.workflowIds) &&
        captured.folderIds.every(tree.canDeleteFolder);
    final gates = RowMenuGates(
      workflowCount: captured.workflowIds.length,
      folderCount: captured.folderIds.length,
      canEdit: widget.canEdit,
      canAdmin: widget.canAdmin,
      effectiveLocked: tree.workflowEffectivelyLocked(workflow),
      inheritedLocked: tree.workflowInheritedLocked(workflow),
      canDeleteSelection: canDelete,
      isDuplicating: _ops.isDuplicating.value,
      canOpenInNewTab: widget.services.navigator.canOpenInNewTab,
      exportAvailable: widget.services.onExport != null,
    );
    final handle = showSidebarContextMenu(
      context,
      position,
      semanticsIdentifier: treeContextMenuId,
      entries: () => menuEntries(
        workflowMenuSpecs(gates),
        (id) => _onWorkflowMenu(id, workflow, captured),
        parityPrefix: treeContextMenuId,
      ),
    );
    _trackMenu(workflow.id, handle);
  }

  void _onWorkflowMenu(
    String id,
    WorkflowListItem workflow,
    CapturedSelection captured,
  ) {
    switch (id) {
      case 'open-new-tab':
        widget.services.navigator.openInNewTab(_ops.workflowHref(workflow.id));
      case 'rename':
        _tree.startEditing(workflow.id);
      case 'lock':
        _ops.toggleWorkflowLock(workflow);
      case 'duplicate':
        unawaited(_ops.duplicate(captured));
      case 'export':
        widget.services.onExport?.call(captured);
      case 'delete':
        _confirmDelete(captured, fallbackName: workflow.name, isFolder: false);
    }
  }

  /// Right-click / "…" on a folder row (`folder-item.tsx:283-331`).
  void openFolderMenu(Folder folder, Offset position) {
    final captured = _tree.captureForFolder(folder.id);
    final tree = _ops.snapshot();
    final canDelete =
        captured.folderIds.every(tree.canDeleteFolder) &&
        (captured.workflowIds.isEmpty ||
            tree.canDeleteWorkflows(captured.workflowIds));
    final gates = RowMenuGates(
      workflowCount: captured.workflowIds.length,
      folderCount: captured.folderIds.length,
      canEdit: widget.canEdit,
      canAdmin: widget.canAdmin,
      effectiveLocked: tree.folderEffectivelyLocked(folder),
      inheritedLocked: tree.folderInheritedLocked(folder),
      canDeleteSelection: canDelete,
      isDuplicating: _ops.isDuplicating.value,
      isCreatingWorkflow: _ops.isCreatingWorkflow.value,
      isCreatingFolder: _ops.isCreatingFolder.value,
      hasExportableContent:
          tree.folderHasWorkflows(folder.id) || captured.workflowIds.isNotEmpty,
      exportAvailable: widget.services.onExport != null,
    );
    final handle = showSidebarContextMenu(
      context,
      position,
      semanticsIdentifier: treeContextMenuId,
      entries: () => menuEntries(
        folderMenuSpecs(gates),
        (id) => _onFolderMenu(id, folder, captured),
        parityPrefix: treeContextMenuId,
      ),
    );
    _trackMenu(folder.id, handle);
  }

  void _onFolderMenu(String id, Folder folder, CapturedSelection captured) {
    final locked = _ops.snapshot().folderEffectivelyLocked(folder);
    switch (id) {
      case 'rename':
        _tree.startEditing(folder.id);
      case 'create-workflow':
        if (!locked) _ops.createWorkflow(folderId: folder.id);
      case 'create-folder':
        if (!locked) unawaited(_ops.createFolder(parentId: folder.id));
      case 'lock':
        _ops.toggleFolderLock(folder);
      case 'duplicate':
        unawaited(_ops.duplicate(captured));
      case 'export':
        widget.services.onExport?.call(captured);
      case 'delete':
        _confirmDelete(captured, fallbackName: folder.name, isFolder: true);
    }
  }

  void _confirmDelete(
    CapturedSelection captured, {
    required String fallbackName,
    required bool isFolder,
  }) {
    final tree = _ops.snapshot();
    String? folderName(String id) => tree.folders[id]?.name;
    String? workflowName(String id) => tree.workflow(id)?.name;
    final names = <String>[
      for (final id in isFolder ? captured.folderIds : captured.workflowIds)
        ?(isFolder ? folderName(id) : workflowName(id)),
      for (final id in isFolder ? captured.workflowIds : captured.folderIds)
        ?(isFolder ? workflowName(id) : folderName(id)),
    ];
    final type = captured.isMixed
        ? DeleteItemType.mixed
        : isFolder
        ? DeleteItemType.folder
        : DeleteItemType.workflow;
    unawaited(
      showDeleteModal(
        context,
        type: type,
        names: names.isEmpty ? <String>[fallbackName] : names,
        onConfirm: () => _ops.delete(captured),
      ),
    );
  }

  /// Right-click on the tree's empty area (`EmptyAreaContextMenu`): a `sm`
  /// popover with "Create workflow" and "Create folder", no icons.
  void openEmptyAreaMenu(Offset position) {
    final overlay = SimOverlay.of(context);
    final local = overlay.globalToHost(position);
    SimPopover.show(
      context,
      anchorRect: Rect.fromLTWH(local.dx, local.dy, 1, 1),
      sideOffset: 4,
      size: SimPopoverSize.sm,
      builder: (context) => Parity(
        'sidebar.tree.empty-menu',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SimPopoverItem(
              label: 'Create workflow',
              enabled: !widget.disableCreate,
              onPressed: _ops.createWorkflow,
            ),
            SimPopoverItem(
              label: 'Create folder',
              enabled: !widget.disableCreate,
              onPressed: () => unawaited(_ops.createFolder()),
            ),
          ],
        ),
      ),
    );
  }

  // Rendering.

  /// `workflow-list.tsx:360-372`: once both lists loaded, every change of
  /// the route workflow, the folder list or the workflow list re-expands the
  /// active path and re-selects the active workflow (a no-op when nothing
  /// changed), e.g. after a folder drag reparents an ancestor or a drop
  /// cleared the selection.
  void _maybeReveal(
    List<Folder> folders,
    List<WorkflowListItem> workflows, {
    required bool loading,
  }) {
    final active = _ops.activeWorkflowId;
    if (active == null || loading) return;
    if (active == _revealedFor &&
        identical(folders, _revealedFolders) &&
        identical(workflows, _revealedWorkflows)) {
      return;
    }
    _revealedFor = active;
    _revealedFolders = folders;
    _revealedWorkflows = workflows;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tree.revealActiveWorkflow(_ops.snapshot(), active);
      if (!_initialScrollDone) {
        _initialScrollDone = true;
        SidebarEvents.scrollToItem(active);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return ListenableBuilder(
      listenable: services.navigator.changes,
      builder: (context, _) => BlocBuilder<WorkflowsCubit, WorkflowsState>(
        bloc: services.workflows,
        builder: (context, workflows) =>
            BlocBuilder<FoldersCubit, FoldersState>(
              bloc: services.folders,
              builder: (context, folders) =>
                  BlocBuilder<SidebarTreeCubit, SidebarTreeState>(
                    bloc: services.tree,
                    builder: (context, state) {
                      final tree = SidebarTree(
                        workspaceId: widget.workspaceId,
                        folders: folders.items,
                        workflows: workflows.items,
                      );
                      _maybeReveal(
                        folders.items,
                        workflows.items,
                        loading: workflows.isLoading || folders.isLoading,
                      );
                      return _buildTree(context, tree, state);
                    },
                  ),
            ),
      ),
    );
  }

  Widget _buildTree(
    BuildContext context,
    SidebarTree tree,
    SidebarTreeState state,
  ) {
    final c = SimTheme.of(context).colors;
    _zones = <_Zone>[];
    _childrenZones = <String>[];
    _emptyZones = <String>[];
    final rootEntries = tree.rootEntries;
    _firstRootId = rootEntries.isEmpty ? null : rootEntries.first.id;
    _lastRootId = rootEntries.isEmpty ? null : rootEntries.last.id;
    final indicator = state.dropIndicator;
    final showRootInside =
        state.isDragging &&
        indicator?.targetId == rootDropTarget &&
        indicator?.position == DropPosition.inside;

    Widget rootZone = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: rootEntries.isEmpty ? 26 : 0,
            minWidth: double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: treeRowGap,
            children: <Widget>[
              for (final entry in rootEntries)
                _entry(context, tree, state, entry, 0, null),
            ],
          ),
        ),
        if (showRootInside)
          Positioned.fill(child: _InsideOverlay(color: c.textSubtle)),
        if (state.isDragging && rootEntries.isNotEmpty) ...<Widget>[
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: edgeZoneHeight,
            child: Parity(
              'sidebar.tree.edge-zone.top',
              child: IgnorePointer(child: SizedBox.expand()),
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: edgeZoneHeight,
            child: Parity(
              'sidebar.tree.edge-zone.bottom',
              child: IgnorePointer(child: SizedBox.expand()),
            ),
          ),
        ],
      ],
    );
    rootZone = Parity(
      'sidebar.tree.root-zone',
      child: KeyedSubtree(key: _rootZoneKey, child: rootZone),
    );

    final draggable = widget.canEdit;
    final zone = rootZone;
    rootZone = DragTarget<DragSelection>(
      onWillAcceptWithDetails: (_) => draggable,
      onMove: (details) => resolveDragOver(details.offset, tree),
      onLeave: (_) => _tree.dragLeave(),
      onAcceptWithDetails: (details) => unawaited(_onDrop(details.data, tree)),
      builder: (context, candidate, rejected) => zone,
    );

    return Parity(
      'sidebar.tree',
      child: Semantics(
        label: 'Workflows',
        child: Focus(
          focusNode: _treeFocus,
          onKeyEvent: _onTreeKey,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onTreePointerDown,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _resetSelection,
              child: rootZone,
            ),
          ),
        ),
      ),
    );
  }

  /// `handleContainerClick`: select the open workflow only, or clear.
  void _resetSelection() {
    final active = _ops.activeWorkflowId;
    if (active != null) {
      _tree.selectOnly(active);
    } else {
      _tree.clearAllSelection();
    }
  }

  /// Enter / Space on the tree container itself, not on a row inside it
  /// (`e.target !== e.currentTarget` returns). Like the `role=tree` div,
  /// the container is not a tab stop.
  KeyEventResult _onTreeKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !node.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _resetSelection();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Records the drag pointer, and resolves a right-click on the empty area
  /// (the container, a row gap, an empty zone) by hit position, as
  /// `handleContainerContextMenu` ignores presses on rows (they open their
  /// own menu). A competing secondary-tap recognizer would fire together
  /// with the row one once the press outlasts the tap deadline.
  void _onTreePointerDown(PointerDownEvent event) {
    if (event.buttons == kPrimaryButton) _pointerDown = event;
    if (event.buttons != kSecondaryButton) return;
    for (final zone in _zones) {
      final rect = _globalRect(zone.key.currentContext);
      if (rect != null && rect.contains(event.position)) return;
    }
    // After this pointer-down has run its course: the overlay host handles
    // the same event after this listener and would otherwise treat it as
    // an outside press on the popover that just opened.
    final position = event.position;
    scheduleMicrotask(() {
      if (mounted) openEmptyAreaMenu(position);
    });
  }

  Widget _entry(
    BuildContext context,
    SidebarTree tree,
    SidebarTreeState state,
    TreeEntry entry,
    int level,
    String? scope,
  ) => switch (entry) {
    TreeFolderEntry(:final node) => _folderSection(
      context,
      tree,
      state,
      node,
      level,
      scope,
    ),
    TreeWorkflowEntry(:final workflow) => _workflowItem(
      context,
      tree,
      state,
      workflow,
      level,
      scope,
    ),
  };

  Widget _lines(
    SidebarTreeState state,
    String id,
    int level,
    Widget child, {
    Widget? overlay,
  }) {
    final indicator = state.dropIndicator;
    final before =
        indicator?.targetId == id && indicator?.position == DropPosition.before;
    final after =
        indicator?.targetId == id && indicator?.position == DropPosition.after;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        ?overlay,
        if (before) _DropLine(level: level, top: -2),
        if (after) _DropLine(level: level, bottom: -2),
      ],
    );
  }

  Widget _workflowItem(
    BuildContext context,
    SidebarTree tree,
    SidebarTreeState state,
    WorkflowListItem workflow,
    int level,
    String? scope,
  ) {
    final key = _keyFor(_rowKeys, workflow.id);
    _zones.add(
      _Zone(kind: _ZoneKind.workflow, id: workflow.id, scope: scope, key: key),
    );
    final row = KeyedSubtree(
      key: key,
      child: Padding(
        padding: EdgeInsets.only(left: level * treeIndentPerLevel),
        child: WorkflowTreeRow(
          key: ValueKey<String>('workflow-row-${workflow.id}'),
          tree: this,
          snapshot: tree,
          state: state,
          workflow: workflow,
          scope: scope,
        ),
      ),
    );
    return _lines(state, workflow.id, level, row);
  }

  Widget _folderSection(
    BuildContext context,
    SidebarTree tree,
    SidebarTreeState state,
    FolderNode node,
    int level,
    String? scope,
  ) {
    final c = SimTheme.of(context).colors;
    final key = _keyFor(_rowKeys, node.id);
    _zones.add(
      _Zone(kind: _ZoneKind.folder, id: node.id, scope: scope, key: key),
    );
    final expanded = state.isExpanded(node.id);
    final hasChildren = tree.hasChildren(node.id);
    final indicator = state.dropIndicator;
    final showInside =
        state.isDragging &&
        indicator?.targetId == node.id &&
        indicator?.position == DropPosition.inside;
    final children = <Widget>[
      KeyedSubtree(
        key: key,
        child: Padding(
          padding: EdgeInsets.only(left: level * treeIndentPerLevel),
          child: FolderTreeRow(
            key: ValueKey<String>('folder-row-${node.id}'),
            tree: this,
            snapshot: tree,
            state: state,
            folder: node.folder,
            scope: scope,
          ),
        ),
      ),
    ];
    if (expanded && (hasChildren || state.isDragging)) {
      _childrenZones.add(node.id);
      final childEntries = tree.childrenOf(node.id);
      final emptyKey = _keyFor(_emptyZoneKeys, node.id);
      if (!hasChildren) _emptyZones.add(node.id);
      children.add(
        Parity(
          'sidebar.tree.folder.children',
          child: KeyedSubtree(
            key: _keyFor(_childrenKeys, node.id),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    top: treeRowGap,
                    left: treeRowGap,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: treeRowGap,
                    children: <Widget>[
                      for (final entry in childEntries)
                        _entry(context, tree, state, entry, level + 1, node.id),
                      if (!hasChildren && state.isDragging)
                        SizedBox(key: emptyKey, height: emptyFolderZoneHeight),
                    ],
                  ),
                ),
                Positioned(
                  left: level * treeIndentPerLevel + 12,
                  top: 0,
                  bottom: 0,
                  width: 1,
                  child: Parity(
                    'sidebar.tree.folder.guide',
                    child: IgnorePointer(child: ColoredBox(color: c.border)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _lines(
      state,
      node.id,
      level,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
      overlay: showInside
          ? Positioned.fill(child: _InsideOverlay(color: c.textSubtle))
          : null,
    );
  }

  // Row callbacks used by the row widgets.

  void onDragStarted(DragSelection selection, String? scope) =>
      _onDragStarted(selection, scope);
  // ignore: use_setters_to_change_properties, a drag callback
  void onDragUpdate(Offset global) => _lastPointer = global;
  void onDragEnded() => _onDragEnded();
}

class _InsideOverlay extends StatelessWidget {
  const _InsideOverlay({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Parity(
    'sidebar.tree.drop-inside',
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(SimRadii.sm),
        ),
      ),
    ),
  );
}

/// `DropIndicatorLine`: a 2px `--text-subtle` rounded line 2px outside the
/// row, indented by its level.
class _DropLine extends StatelessWidget {
  const _DropLine({required this.level, this.top, this.bottom});

  final int level;
  final double? top;
  final double? bottom;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: top,
    bottom: bottom,
    height: 2,
    child: Padding(
      padding: EdgeInsets.only(left: level * treeIndentPerLevel),
      child: Parity(
        'sidebar.tree.drop-line',
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: SimTheme.of(context).colors.textSubtle,
              borderRadius: BorderRadius.circular(SimRadii.full),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The drag image pill (`createSidebarDragGhost`): `--surface-active`,
/// 1px `rgba(255,255,255,.08)` border, radius 8, 4×10 padding, 13px label
/// capped at 200px, `0 4px 12px rgba(0,0,0,.4)`; a 14px icon only for a
/// single item. Centred on the pointer.
class DragGhost extends StatelessWidget {
  const DragGhost({required this.label, super.key, this.icon});

  final String label;
  final SimIconData? icon;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: Parity(
        'sidebar.tree.drag-ghost',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.surfaceActive,
            border: Border.all(color: const Color(0x14FFFFFF)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: <Widget>[
              if (icon != null) SimIcon(icon!, color: c.textIcon),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: sim.text.small.copyWith(color: c.textBody),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a row in a [Draggable] carrying [selection] when dragging is
/// allowed; the default drag image is replaced by [DragGhost].
Widget _draggable({
  required bool enabled,
  required WorkflowTreeState tree,
  required DragSelection Function() selection,
  required String label,
  required SimIconData icon,
  required String? scope,
  required Widget child,
}) {
  if (!enabled) return child;
  final payload = selection();
  final total = payload.total;
  return Draggable<DragSelection>(
    data: payload,
    maxSimultaneousDrags: 1,
    dragAnchorStrategy: pointerDragAnchorStrategy,
    feedback: DragGhost(
      label: total > 1 ? '$label +${total - 1} more' : label,
      icon: total == 1 ? icon : null,
    ),
    onDragStarted: () => tree.onDragStarted(payload, scope),
    onDragUpdate: (details) => tree.onDragUpdate(details.globalPosition),
    onDragEnd: (_) => tree.onDragEnded(),
    child: child,
  );
}

/// Detects a double click on a region without delaying single clicks
/// (the DOM fires `click`, `click`, `dblclick`).
class _DoubleClickRegion extends StatefulWidget {
  const _DoubleClickRegion({required this.onDoubleClick, required this.child});

  final VoidCallback? onDoubleClick;
  final Widget child;

  @override
  State<_DoubleClickRegion> createState() => _DoubleClickRegionState();
}

class _DoubleClickRegionState extends State<_DoubleClickRegion> {
  Duration? _lastDown;
  Offset? _lastPosition;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) {
      if (event.buttons != kPrimaryButton) return;
      final last = _lastDown;
      final lastPosition = _lastPosition;
      if (last != null &&
          lastPosition != null &&
          event.timeStamp - last <= kDoubleTapTimeout &&
          (event.position - lastPosition).distance <= kDoubleTapSlop) {
        _lastDown = null;
        _lastPosition = null;
        widget.onDoubleClick?.call();
        return;
      }
      _lastDown = event.timeStamp;
      _lastPosition = event.position;
    },
    child: widget.child,
  );
}

/// Shared hover/focus-within tracking of a tree row.
mixin _RowHover<T extends StatefulWidget> on State<T> {
  bool hovered = false;
  bool focusWithin = false;

  Widget trackRow(Widget child) => MouseRegion(
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => focusWithin = focused),
      child: child,
    ),
  );
}

/// `FolderItem` (`folder-item.tsx:498-576`).
class FolderTreeRow extends StatefulWidget {
  const FolderTreeRow({
    required this.tree,
    required this.snapshot,
    required this.state,
    required this.folder,
    required this.scope,
    super.key,
  });

  final WorkflowTreeState tree;
  final SidebarTree snapshot;
  final SidebarTreeState state;
  final Folder folder;
  final String? scope;

  @override
  State<FolderTreeRow> createState() => _FolderTreeRowState();
}

class _FolderTreeRowState extends State<FolderTreeRow> with _RowHover {
  InlineRenameController? _rename;

  WorkflowTreeState get _host => widget.tree;
  SidebarTreeCubit get _cubit => _host._tree;
  Folder get _folder => widget.folder;

  @override
  void dispose() {
    _rename?.dispose();
    super.dispose();
  }

  InlineRenameController _renameController() =>
      _rename ??= InlineRenameController(
        initialName: _folder.name,
        onSave: (name) => _host._ops.renameFolder(_folder.id, name),
        onSavingChanged: (saving) =>
            _cubit.setSaving(saving ? _folder.id : null),
        onExit: () {
          _cubit.stopEditing(_folder.id);
          final done = _rename;
          _rename = null;
          WidgetsBinding.instance.addPostFrameCallback((_) => done?.dispose());
        },
      );

  void _onTap() {
    if (_host.suppressClick || widget.state.editingId == _folder.id) return;
    final shift = isShiftPressed;
    final meta = isModifierPressed;
    if (shift || meta) {
      _cubit.folderClick(widget.snapshot, _folder.id, shift: shift, meta: meta);
      return;
    }
    _cubit
      ..clearFolderSelection()
      ..toggleExpanded(_folder.id);
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final state = widget.state;
    final id = _folder.id;
    final editing = state.editingId == id;
    if (!editing && _rename != null && !_rename!.isDone) {
      _rename!.dispose();
      _rename = null;
    }
    final expanded = state.isExpanded(id);
    final selected = state.selectedFolders.contains(id);
    final menuOpen = state.menuOpenId == id;
    final effectiveLocked = widget.snapshot.folderEffectivelyLocked(_folder);
    final dimmed =
        state.draggingIds.contains(id) || (state.isDragging && selected);

    Widget label;
    if (editing) {
      label = Parity(
        'sidebar.tree.folder-row.rename-input',
        child: InlineRenameField(
          controller: _renameController(),
          maxLength: 50,
          semanticsLabel: 'Folder name',
        ),
      );
    } else {
      label = Row(
        spacing: 8,
        children: <Widget>[
          Expanded(
            child: _DoubleClickRegion(
              onDoubleClick: effectiveLocked
                  ? null
                  : () => _cubit.startEditing(id),
              child: Parity(
                'sidebar.tree.folder-row.label',
                child: SimOverflowText(
                  label: _folder.name,
                  style: sim.text.sm.copyWith(color: c.textBody),
                  tooltipEnabled: false,
                ),
              ),
            ),
          ),
          SidebarRowActions(
            revealed: hovered || focusWithin,
            open: menuOpen,
            revealOnHover: !state.isDragging,
            actionLabel: 'Folder options',
            actionsParityId: 'sidebar.tree.folder-row.actions',
            indicatorParityId: 'sidebar.tree.folder-row.lock',
            indicator: _folder.locked
                ? SimIcon(
                    SimEmcnIcons.lock,
                    color: c.textIcon,
                    semanticLabel: 'Folder is locked',
                  )
                : null,
            onAction: (rect) =>
                _host.openFolderMenu(_folder, moreButtonAnchor(rect)),
          ),
        ],
      );
    }

    Widget row = SidebarChip(
      active: selected || menuOpen,
      semanticsLabel:
          '${_folder.name} folder, ${expanded ? 'expanded' : 'collapsed'}',
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: SimChipChrome.gap,
        children: <Widget>[
          Parity(
            'sidebar.tree.folder-row.chevron',
            child: AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: SimMotion.of(SimMotion.sidebarChevron),
              child: SimIcon(SimEmcnIcons.chevronRight, color: c.textIcon),
            ),
          ),
          Parity(
            'sidebar.tree.folder-row.icon',
            child: SimIcon(
              expanded ? SimEmcnIcons.folderOpen : SimEmcnIcons.folder,
              size: SimChipChrome.contentIconSize,
              color: c.textIcon,
            ),
          ),
        ],
      ),
      content: label,
      onPressed: _onTap,
      onSecondaryTapDown: editing
          ? null
          : (position) => _host.openFolderMenu(_folder, position),
    );
    row = Semantics(expanded: expanded, child: row);
    row = trackRow(Opacity(opacity: dimmed ? 0.5 : 1, child: row));
    row = _draggable(
      enabled: _host.widget.canEdit && !editing && !effectiveLocked,
      tree: _host,
      selection: () => _cubit.dragSelectionFor(id: id, isFolder: true),
      label: _folder.name,
      icon: SimEmcnIcons.folder,
      scope: widget.scope,
      child: row,
    );
    // State ids ride on always-present wrappers so toggling them never
    // remounts the row (and its double-click / rename state).
    row = Semantics(
      identifier: selected || menuOpen
          ? 'sidebar.tree.folder-row.active'
          : null,
      container: true,
      child: row,
    );
    row = Semantics(
      identifier: expanded ? 'sidebar.tree.folder-row.expanded' : null,
      container: true,
      child: row,
    );
    return Parity('sidebar.tree.folder-row.$id', child: row);
  }
}

/// `WorkflowItem` (`workflow-item.tsx:406-476`).
class WorkflowTreeRow extends StatefulWidget {
  const WorkflowTreeRow({
    required this.tree,
    required this.snapshot,
    required this.state,
    required this.workflow,
    required this.scope,
    super.key,
  });

  final WorkflowTreeState tree;
  final SidebarTree snapshot;
  final SidebarTreeState state;
  final WorkflowListItem workflow;
  final String? scope;

  @override
  State<WorkflowTreeRow> createState() => _WorkflowTreeRowState();
}

class _WorkflowTreeRowState extends State<WorkflowTreeRow> with _RowHover {
  InlineRenameController? _rename;

  WorkflowTreeState get _host => widget.tree;
  SidebarTreeCubit get _cubit => _host._tree;
  WorkflowListItem get _workflow => widget.workflow;

  @override
  void dispose() {
    _rename?.dispose();
    super.dispose();
  }

  InlineRenameController _renameController() =>
      _rename ??= InlineRenameController(
        initialName: _workflow.name,
        onSave: (name) => _host._ops.renameWorkflow(_workflow.id, name),
        onSavingChanged: (saving) =>
            _cubit.setSaving(saving ? _workflow.id : null),
        onExit: () {
          _cubit.stopEditing(_workflow.id);
          final done = _rename;
          _rename = null;
          WidgetsBinding.instance.addPostFrameCallback((_) => done?.dispose());
        },
      );

  void _onTap() {
    if (_host.suppressClick || widget.state.editingId == _workflow.id) return;
    final services = _host.widget.services;
    final href = _host._ops.workflowHref(_workflow.id);
    if (isModifierPressed) {
      services.navigator.openInNewTab(href);
      return;
    }
    final shift = isShiftPressed;
    _cubit.workflowClick(
      widget.snapshot,
      _workflow.id,
      shift: shift,
      activeWorkflowId: _host._ops.activeWorkflowId,
    );
    if (!shift) services.navigator.go(href);
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final state = widget.state;
    final id = _workflow.id;
    final editing = state.editingId == id;
    if (!editing && _rename != null && !_rename!.isDone) {
      _rename!.dispose();
      _rename = null;
    }
    final activeRoute = _host._ops.activeWorkflowId == id;
    final selected = state.selectedWorkflows.contains(id);
    final menuOpen = state.menuOpenId == id;
    final active =
        activeRoute ||
        menuOpen ||
        (selected && state.selectedWorkflows.length > 1);
    final effectiveLocked = widget.snapshot.workflowEffectivelyLocked(
      _workflow,
    );
    final dimmed =
        state.draggingIds.contains(id) || (state.isDragging && selected);
    final services = _host.widget.services;
    final presence = activeRoute
        ? _host.widget.presence
        : const <PresenceUser>[];

    final Widget content;
    if (editing) {
      content = Parity(
        'sidebar.tree.workflow-row.rename-input',
        child: InlineRenameField(
          controller: _renameController(),
          maxLength: 100,
          semanticsLabel: 'Workflow name',
        ),
      );
    } else {
      // `workflow-item.tsx:423-475`: the label hugs its text inside a
      // `gap-2` row with the avatars right after it; the actions sit at
      // the chip's own 6px gap.
      content = Row(
        spacing: SimChipChrome.gap,
        children: <Widget>[
          Expanded(
            child: Row(
              spacing: 8,
              children: <Widget>[
                Flexible(
                  child: _DoubleClickRegion(
                    onDoubleClick: effectiveLocked
                        ? null
                        : () => _cubit.startEditing(id),
                    child: Parity(
                      'sidebar.tree.workflow-row.label',
                      child: SimOverflowText(
                        label: _workflow.name,
                        style: sim.text.sm.copyWith(color: c.textBody),
                        tooltipEnabled: false,
                      ),
                    ),
                  ),
                ),
                if (presence.isNotEmpty)
                  Parity(
                    'sidebar.tree.workflow-row.avatars',
                    child: PresenceAvatars(
                      users: presence,
                      maxVisible: presenceMaxVisible(
                        _host.widget.sidebarWidth,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SidebarRowActions(
            revealed: hovered || focusWithin,
            open: menuOpen,
            revealOnHover: !state.isDragging,
            actionLabel: 'Workflow options',
            actionsParityId: 'sidebar.tree.workflow-row.actions',
            indicatorParityId: 'sidebar.tree.workflow-row.lock',
            indicator: _workflow.locked
                ? SimIcon(
                    SimEmcnIcons.lock,
                    color: c.textIcon,
                    semanticLabel: 'Workflow is locked',
                  )
                : null,
            onAction: (rect) =>
                _host.openWorkflowMenu(_workflow, moreButtonAnchor(rect)),
          ),
        ],
      );
    }

    Widget row = SidebarChip(
      active: active,
      isLink: true,
      semanticsLabel: _workflow.name,
      content: content,
      onPressed: _onTap,
      onMiddleTap: () =>
          services.navigator.openInNewTab(_host._ops.workflowHref(id)),
      onSecondaryTapDown: editing
          ? null
          : (position) => _host.openWorkflowMenu(_workflow, position),
    );
    row = trackRow(Opacity(opacity: dimmed ? 0.5 : 1, child: row));
    row = _draggable(
      enabled: _host.widget.canEdit && !editing && !effectiveLocked,
      tree: _host,
      selection: () => _cubit.dragSelectionFor(id: id, isFolder: false),
      label: _workflow.name,
      icon: SimEmcnIcons.workflow,
      scope: widget.scope,
      child: row,
    );
    row = Semantics(
      identifier: activeRoute ? 'sidebar.tree.workflow-row.active' : null,
      container: true,
      child: row,
    );
    return Parity('sidebar.tree.workflow-row.$id', child: row);
  }
}
