/// The command palette (`search-modal.tsx` `SearchModal` /
/// `SearchModalContent`, `command-chrome.tsx`): a transparent full-screen
/// click-catcher plus the floating dialog, rendered as a [SimOverlayEntry]
/// while the [SearchPaletteController] is open.
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show RenderClipPath, RenderProxyBox;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/chrome/search_palette_controller.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_navigation_guard.dart';
import 'package:sim_app/features/workspace_shell/search/palette_catalog.dart';
import 'package:sim_app/features/workspace_shell/search/palette_content.dart';
import 'package:sim_app/features/workspace_shell/search/palette_models.dart';
import 'package:sim_app/features/workspace_shell/search/palette_rows.dart';
import 'package:sim_app/features/workspace_shell/shared/app_links.dart';
import 'package:sim_app/features/workspace_shell/shared/permission_config.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/global_commands.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_events.dart';
import 'package:sim_design/sim_design.dart';
import 'package:url_launcher/url_launcher.dart';

/// The long-lived cubits the palette reads.
class SearchPaletteDependencies {
  const SearchPaletteDependencies({
    required this.workspaces,
    required this.workflows,
    required this.folders,
    required this.deploymentShape,
    required this.permissions,
  });

  factory SearchPaletteDependencies.fromLocator() => SearchPaletteDependencies(
    workspaces: locator<WorkspacesCubit>(),
    workflows: locator<WorkflowsCubit>(),
    folders: locator<FoldersCubit>(),
    deploymentShape: locator<DeploymentShapeCubit>(),
    permissions: locator<PermissionsCubit>(),
  );

  final WorkspacesCubit workspaces;
  final WorkflowsCubit workflows;
  final FoldersCubit folders;
  final DeploymentShapeCubit deploymentShape;
  final PermissionsCubit permissions;

  List<Stream<Object?>> get streams => [
    workspaces.stream,
    workflows.stream,
    folders.stream,
    deploymentShape.stream,
    permissions.stream,
  ];
}

/// `getFolderPathNames`: ancestor folder names, root first; `null` at the
/// root. A cycle stops the walk.
List<String>? folderPathNames(Map<String, Folder> folders, String? folderId) {
  if (folderId == null) return null;
  final chain = <String>[];
  final visited = <String>{};
  String? current = folderId;
  while (current != null && visited.add(current)) {
    final folder = folders[current];
    if (folder == null) break;
    chain.insert(0, folder.name);
    current = folder.parentId;
  }
  return chain.isEmpty ? null : chain;
}

/// Mounts the palette for the workspace shell. Place it once inside the
/// shell (below the router, so navigation works) with the route facts the
/// palette needs; it renders [child] and, while [controller] is open, the
/// palette layer on the nearest [SimOverlayHost].
class SearchPaletteLayer extends StatefulWidget {
  const SearchPaletteLayer({
    required this.controller,
    required this.workspaceId,
    super.key,
    this.child,
    this.pathname,
    this.currentWorkflowId,
    this.logsDashboard = false,
    this.sidebarWidth = 0,
    this.panelWidth = 0,
    this.dependencies,
    this.catalog = const PaletteCatalog.empty(),
    this.sources = const PaletteSources(),
    this.permissions,
    this.permissionConfigs,
    this.accessRequestsEnabled = false,
    this.links,
    this.addBlockBus,
    this.onNavigate,
    this.onInvokeCommand,
    this.onCreateWorkflow,
    this.onCreateFolder,
    this.onImportWorkflow,
    this.onOpenHelp,
    this.onNavigateToSettings,
    this.onAskSim,
    this.onRevealWorkflow,
  });

  final SearchPaletteController controller;
  final String workspaceId;
  final Widget? child;

  /// The current location path (decides the page context).
  final String? pathname;
  final String? currentWorkflowId;

  /// `/logs` is showing its dashboard view.
  final bool logsDashboard;

  /// `--sidebar-width` and, on the canvas, `--panel-width`: the dialog
  /// centres over the content pane between them.
  final double sidebarWidth;
  final double panelWidth;
  final SearchPaletteDependencies? dependencies;
  final PaletteCatalog catalog;

  /// Phase 4 lists (files, tables, knowledge bases, logs, connected
  /// accounts, chats); workflows and workspaces come from the cubits.
  final PaletteSources sources;

  /// A fixed permission config; when null the palette reads the workspace's
  /// config from [permissionConfigs] (the one source the sidebar reads).
  final ShellPermissionConfig? permissions;
  final ShellPermissionConfigSource? permissionConfigs;
  final bool accessRequestsEnabled;

  /// The link base "Copy link" resolves against; the platform's by default.
  final AppLinks? links;
  final AddBlockBus? addBlockBus;

  /// Navigates to an in-app location; defaults to `GoRouter.go`.
  final void Function(String location)? onNavigate;

  /// Runs a page-registered global command by id.
  final void Function(String commandId)? onInvokeCommand;
  final VoidCallback? onCreateWorkflow;

  /// "Create folder" / "Import workflow"; default to the mounted sidebar's
  /// own flows (`sidebar.tsx:1945-1947`), and the rows hide without one.
  final VoidCallback? onCreateFolder;
  final VoidCallback? onImportWorkflow;

  /// `open-help-modal`.
  final VoidCallback? onOpenHelp;

  /// `navigateToSettings({ section })`; defaults to
  /// `/workspace/{ws}/settings/{section ?? 'general'}`.
  final void Function(String? section)? onNavigateToSettings;

  /// Ask-mode Enter with text (the Phase 4 chat handoff); defaults to
  /// opening Home.
  final void Function(String query)? onAskSim;

  /// `sidebar-scroll-to-item` after a workflow is opened from the palette.
  final void Function(String workflowId)? onRevealWorkflow;

  @override
  State<SearchPaletteLayer> createState() => _SearchPaletteLayerState();
}

class _SearchPaletteLayerState extends State<SearchPaletteLayer> {
  SimOverlayEntry? _entry;
  SimOverlayController? _overlay;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(SearchPaletteLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
    _entry?.markNeedsBuild();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overlay = SimOverlay.maybeOf(context);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final open = widget.controller.isOpen;
    if (open && _entry == null) {
      final overlay = _overlay;
      if (overlay == null) return;
      late final SimOverlayEntry entry;
      entry = SimOverlayEntry(
        z: SimZ.modal,
        modal: true,
        onDismissRequested: widget.controller.close,
        onRemoved: () {
          if (identical(_entry, entry)) _entry = null;
        },
        builder: (context) => _PaletteLayerBody(
          contentKey: entry.contentKey,
          config: _config(),
        ),
      );
      _entry = entry;
      overlay.insert(entry);
    } else if (!open && _entry != null) {
      final entry = _entry!;
      _entry = null;
      entry.remove();
    }
  }

  void _invokeRegistered(String commandId) {
    if (locator.isRegistered<GlobalCommandRegistry>()) {
      locator<GlobalCommandRegistry>().invoke(commandId);
    }
  }

  /// `navigator.clipboard.writeText(window.location.href)`: the current
  /// route resolved through the shared link base (never `Uri.base`, which
  /// nests the route under the current one on web and is a `file:` URL on
  /// desktop).
  void _copyLink() {
    final location = mounted
        ? GoRouter.maybeOf(
            context,
          )?.routerDelegate.currentConfiguration.uri.toString()
        : null;
    final href = (widget.links ?? AppLinks.platform()).resolve(
      location ?? widget.pathname ?? '/',
    );
    if (href == null) return;
    unawaited(
      Clipboard.setData(ClipboardData(text: href)).catchError(
        (Object error) =>
            developer.log('copy link', name: 'sim_app.palette', error: error),
      ),
    );
  }

  void _navigate(String location) {
    final custom = widget.onNavigate;
    if (custom != null) {
      custom(location);
      return;
    }
    if (!mounted || GoRouter.maybeOf(context) == null) return;
    ShellNavigator.of(context).go(location);
  }

  _PaletteConfig _config() {
    final w = widget;
    final ws = w.workspaceId;
    return _PaletteConfig(
      workspaceId: ws,
      currentWorkflowId: w.currentWorkflowId,
      pageContext: pageContextForPath(
        pathname: w.pathname,
        workspaceId: ws,
        workflowId: w.currentWorkflowId,
        logsDashboard: w.logsDashboard,
      ),
      sidebarWidth: w.sidebarWidth,
      panelWidth: w.panelWidth,
      dependencies: w.dependencies ?? SearchPaletteDependencies.fromLocator(),
      catalog: w.catalog,
      sources: w.sources,
      permissions: w.permissions != null
          ? _FixedValue<ShellPermissionConfig>(w.permissions!)
          : (w.permissionConfigs ?? sharedPermissionConfigs).of(ws),
      accessRequestsEnabled: w.accessRequestsEnabled,
      addBlockBus: w.addBlockBus ?? AddBlockBus.instance,
      close: w.controller.close,
      navigate: _navigate,
      invokeCommand: w.onInvokeCommand ?? _invokeRegistered,
      createWorkflow: w.onCreateWorkflow,
      createFolder: w.onCreateFolder ?? SidebarEvents.createFolder,
      importWorkflow: w.onImportWorkflow ?? SidebarEvents.importWorkflow,
      openHelp: w.onOpenHelp ?? () {},
      navigateToSettings:
          w.onNavigateToSettings ??
          (section) =>
              _navigate('/workspace/$ws/settings/${section ?? 'general'}'),
      askSim: w.onAskSim ?? (_) => _navigate('/workspace/$ws/home'),
      revealWorkflow: w.onRevealWorkflow ?? (_) {},
      copyLink: _copyLink,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}

/// Everything the palette body needs, snapshotted from the layer.
class _PaletteConfig {
  const _PaletteConfig({
    required this.workspaceId,
    required this.currentWorkflowId,
    required this.pageContext,
    required this.sidebarWidth,
    required this.panelWidth,
    required this.dependencies,
    required this.catalog,
    required this.sources,
    required this.permissions,
    required this.accessRequestsEnabled,
    required this.addBlockBus,
    required this.close,
    required this.navigate,
    required this.invokeCommand,
    required this.createWorkflow,
    required this.createFolder,
    required this.importWorkflow,
    required this.openHelp,
    required this.navigateToSettings,
    required this.askSim,
    required this.revealWorkflow,
    required this.copyLink,
  });

  final String workspaceId;
  final String? currentWorkflowId;
  final PageActionContext? pageContext;
  final double sidebarWidth;
  final double panelWidth;
  final SearchPaletteDependencies dependencies;
  final PaletteCatalog catalog;
  final PaletteSources sources;

  /// The workspace's permission config (fixed or live).
  final ValueListenable<ShellPermissionConfig> permissions;
  final bool accessRequestsEnabled;
  final AddBlockBus addBlockBus;
  final VoidCallback close;
  final void Function(String location) navigate;
  final void Function(String commandId) invokeCommand;
  final VoidCallback? createWorkflow;
  final VoidCallback? createFolder;
  final VoidCallback? importWorkflow;
  final VoidCallback openHelp;
  final void Function(String? section) navigateToSettings;
  final void Function(String query) askSim;
  final void Function(String workflowId) revealWorkflow;
  final VoidCallback copyLink;
}

/// Horizontal centre of the dialog (`search-modal.tsx:1335-1341`):
/// `clamp(16px + H, CENTER, 100% - 16px - H)` with
/// `H = min(250px, 50% - 16px)`; CENTER sits over the content pane right of
/// the sidebar, and between sidebar and panel on the canvas.
double paletteCenterX({
  required double viewportWidth,
  required double sidebarWidth,
  required double panelWidth,
  required bool onCanvas,
}) {
  final half = math.min(
    PaletteMetrics.maxHalfWidth,
    viewportWidth / 2 - PaletteMetrics.edgeGutter,
  );
  final center = onCanvas
      ? viewportWidth / 2 + (sidebarWidth - panelWidth) / 2
      : sidebarWidth / 2 + viewportWidth / 2;
  final low = PaletteMetrics.edgeGutter + half;
  final high = viewportWidth - PaletteMetrics.edgeGutter - half;
  // CSS clamp(): the minimum wins when the bounds cross.
  return math.max(low, math.min(center, high));
}

class _PaletteLayerBody extends StatelessWidget {
  const _PaletteLayerBody({required this.contentKey, required this.config});

  final GlobalKey contentKey;
  final _PaletteConfig config;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final width = math
          .min(
            PaletteMetrics.maxWidth,
            size.width - 2 * PaletteMetrics.edgeGutter,
          )
          .clamp(0.0, double.infinity);
      final centerX = paletteCenterX(
        viewportWidth: size.width,
        sidebarWidth: config.sidebarWidth,
        panelWidth: config.panelWidth,
        onCanvas: config.pageContext == PageActionContext.workflow,
      );
      return Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              container: true,
              identifier: 'search.overlay',
              child: const SimOverlayBarrier(color: Color(0x00000000)),
            ),
          ),
          Positioned(
            top: size.height * PaletteMetrics.topFraction,
            left: centerX - width / 2,
            width: width,
            child: KeyedSubtree(
              key: contentKey,
              child: _SearchPaletteDialog(
                config: config,
                viewportHeight: size.height,
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// The dialog: ring, card, faded list and floating input, with the cmdk
/// keyboard model.
class _SearchPaletteDialog extends StatefulWidget {
  const _SearchPaletteDialog({
    required this.config,
    required this.viewportHeight,
  });

  final _PaletteConfig config;
  final double viewportHeight;

  @override
  State<_SearchPaletteDialog> createState() => _SearchPaletteDialogState();
}

class _SearchPaletteDialogState extends State<_SearchPaletteDialog> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _inputFocus = FocusNode(debugLabel: 'SearchPaletteInput');
  final ScrollController _scroll = ScrollController();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _askMode = false;
  int _selected = 0;

  /// The selected row's identity (`<section>.<id>`), so a list update
  /// while the palette is open keeps the selection on the same item
  /// instead of whatever now sits at its index.
  String? _selectedKey;
  List<PaletteEntry> _entries = const [];
  List<PaletteGroup> _groups = const [];

  _PaletteConfig get _config => widget.config;
  SearchPaletteDependencies get _deps => _config.dependencies;
  bool get _chatEnabled => _deps.deploymentShape.state.shape.chatEnabled;

  @override
  void initState() {
    super.initState();
    for (final stream in _deps.streams) {
      _subscriptions.add(
        stream.listen((_) {
          if (mounted) setState(_compute);
        }),
      );
    }
    _config.permissions.addListener(_onPermissions);
    _compute();
  }

  @override
  void didUpdateWidget(_SearchPaletteDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.config, widget.config)) {
      if (!identical(oldWidget.config.permissions, _config.permissions)) {
        oldWidget.config.permissions.removeListener(_onPermissions);
        _config.permissions.addListener(_onPermissions);
      }
      _compute();
    }
  }

  void _onPermissions() {
    if (mounted) setState(_compute);
  }

  @override
  void dispose() {
    _config.permissions.removeListener(_onPermissions);
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _query.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  PaletteSources _sources() {
    final ws = _config.workspaceId;
    final folders = _deps.folders.state.byId;
    return PaletteSources(
      workflows: [
        for (final w in _deps.workflows.state.forSidebar)
          PaletteFolderedItem(
            id: w.id,
            name: w.name,
            href: '/workspace/$ws/w/${w.id}',
            folderPath: folderPathNames(folders, w.folderId),
            isCurrent: w.id == _config.currentWorkflowId,
          ),
      ],
      workspaces: [
        for (final w in _deps.workspaces.state.ordered)
          PaletteWorkspaceItem(
            id: w.id,
            name: w.name,
            href: '/workspace/${w.id}/w',
            isCurrent: w.id == ws,
            logoUrl: w.logoUrl,
          ),
      ],
      files: _config.sources.files,
      tables: _config.sources.tables,
      knowledgeBases: _config.sources.knowledgeBases,
      logs: _config.sources.logs,
      connectedAccounts: _config.sources.connectedAccounts,
      chats: _config.sources.chats,
    );
  }

  /// Ranks every section (`entriesBySection`, memoised on the deferred
  /// query upstream): runs on query, data, permission or config changes
  /// only, never on arrow keys, hover or Tab, which re-render from the
  /// cached groups.
  void _compute() {
    final perms = _deps.permissions.state.userPermissions;
    final config = _config;
    final permissionConfig = config.permissions.value;
    final actions = buildPaletteActions(
      pageContext: config.pageContext,
      canEdit: perms.canEdit,
      canAdmin: perms.canAdmin,
      chatEnabled: _chatEnabled,
      handlers: PaletteActionHandlers(
        invokeCommand: config.invokeCommand,
        copyWorkflowLink: config.copyLink,
        newChat: () => config.navigate('/workspace/${config.workspaceId}/home'),
        navigateToSettings: config.navigateToSettings,
        createWorkflow: config.createWorkflow,
        createFolder: config.createFolder,
        importWorkflow: config.importWorkflow,
      ),
    );
    final pages = buildPalettePages(
      workspaceId: config.workspaceId,
      permissions: permissionConfig,
      accessRequestsEnabled: config.accessRequestsEnabled,
      openHelp: config.openHelp,
      openSettings: () => config.navigateToSettings(null),
    );
    final view = buildPaletteView(
      query: _query.text,
      actions: actions,
      pages: pages,
      catalog: config.catalog,
      sources: _sources(),
      pageContext: config.pageContext,
      permissions: permissionConfig,
      chatEnabled: _chatEnabled,
      currentWorkflowId: config.currentWorkflowId,
    );
    _groups = view.groups;
    _entries = view.entries;
    final kept = _selectedKey == null
        ? -1
        : _entries.indexWhere((e) => e.enabled && e.parityId == _selectedKey);
    final first = _entries.indexWhere((e) => e.enabled);
    _selected = kept >= 0 ? kept : math.max(first, 0);
    _selectedKey = first < 0 ? null : _entries[_selected].parityId;
  }

  /// cmdk never selects a `disabled` item.
  bool _selectable(int index) =>
      _askMode || (index < _entries.length && _entries[index].enabled);

  String get _askLabel {
    final q = _query.text.trim();
    return q.isEmpty ? 'Start a new chat' : 'New chat: $q';
  }

  int get _rowCount => _askMode ? 1 : _entries.length;

  void _onChanged(String _) {
    setState(() {
      _selectedKey = null;
      _compute();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _select(int index, {bool reveal = true}) {
    if (_rowCount == 0) return;
    setState(() {
      _selected = index;
      if (!_askMode && index < _entries.length) {
        _selectedKey = _entries[index].parityId;
      }
    });
    if (reveal) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(index));
    }
  }

  /// The next selectable row [step] away, wrapping; disabled rows are
  /// stepped over.
  void _move(int step) {
    final n = _rowCount;
    if (n == 0) return;
    var index = _selected;
    for (var i = 0; i < n; i++) {
      index = (index + step + n) % n;
      if (_selectable(index)) {
        _select(index);
        return;
      }
    }
  }

  /// The first selectable row from [from] towards [step].
  void _selectEdge(int from, int step) {
    for (var i = from; i >= 0 && i < _rowCount; i += step) {
      if (_selectable(i)) {
        _select(i);
        return;
      }
    }
  }

  /// cmdk `scrollIntoView({block: 'nearest'})` with the row's
  /// `scroll-mt-12` / `scroll-mb-1.5`; a group's first row brings its
  /// heading along.
  void _reveal(int index) {
    if (!mounted || !_scroll.hasClients || _askMode) return;
    var offset = PaletteMetrics.listPaddingTop;
    var flat = 0;
    for (var g = 0; g < _groups.length; g++) {
      final group = _groups[g];
      final groupTop = offset + (g == 0 ? 0 : PaletteMetrics.groupGap);
      final rowsTop =
          groupTop +
          (group.heading == null
              ? 0
              : PaletteMetrics.headingHeight + PaletteMetrics.headingGap);
      if (index < flat + group.entries.length) {
        final j = index - flat;
        final rowTop =
            rowsTop + j * (PaletteMetrics.rowHeight + PaletteMetrics.rowGap);
        final top = j == 0 && group.heading != null ? groupTop : rowTop;
        final bottom = rowTop + PaletteMetrics.rowHeight;
        final position = _scroll.position;
        var target = position.pixels;
        if (top - PaletteMetrics.scrollMarginTop < target) {
          target = top - PaletteMetrics.scrollMarginTop;
        } else if (bottom + PaletteMetrics.scrollMarginBottom >
            target + position.viewportDimension) {
          target =
              bottom +
              PaletteMetrics.scrollMarginBottom -
              position.viewportDimension;
        }
        target = target.clamp(0.0, position.maxScrollExtent);
        if (target != position.pixels) _scroll.jumpTo(target);
        return;
      }
      flat += group.entries.length;
      offset += PaletteMetrics.groupExtent(group, first: g == 0);
    }
  }

  void _toggleAskMode() {
    setState(() {
      _askMode = !_askMode;
      final first = _entries.indexWhere((e) => e.enabled);
      _selected = _askMode ? 0 : math.max(first, 0);
      _selectedKey = first < 0 ? null : _entries[first].parityId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(0));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_query.value.composing.isValid) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab) {
      if (_chatEnabled) {
        _toggleAskMode();
      } else {
        _move(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (key == LogicalKeyboardKey.home) {
      _selectEdge(0, 1);
    } else if (key == LogicalKeyboardKey.end) {
      _selectEdge(_rowCount - 1, -1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) _activate(_selected);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _activate(int index) {
    if (_askMode) {
      _askSim();
      return;
    }
    if (index < 0 || index >= _entries.length || !_selectable(index)) return;
    _choose(_entries[index]);
  }

  void _askSim() {
    final config = _config;
    final query = _query.text.trim();
    if (query.isEmpty) {
      config.navigate('/workspace/${config.workspaceId}/home');
    } else {
      config.askSim(query);
    }
    config.close();
  }

  Future<void> _openExternal(String href) async {
    await launchUrl(Uri.parse(href), webOnlyWindowName: '_blank');
  }

  void _choose(PaletteEntry entry) {
    final config = _config;
    switch (entry.item) {
      case final PaletteAction action:
        config.close();
        action.run();
        return;
      case final PaletteBlockItem block:
        config.addBlockBus.dispatch(
          AddBlockRequest(
            type: block.type,
            enableTriggerMode:
                entry.section == SearchSection.triggers && block.triggerCapable,
          ),
        );
      case final PaletteToolOperationItem op:
        config.addBlockBus.dispatch(
          AddBlockRequest(type: op.blockType, presetOperation: op.operationId),
        );
      case final PaletteFolderedItem item:
        if (entry.section == SearchSection.workflows) {
          if (!item.isCurrent) {
            config
              ..navigate(item.href)
              ..revealWorkflow(item.id);
          }
        } else {
          config.navigate(item.href);
        }
      case final PaletteWorkspaceItem workspace:
        if (!workspace.isCurrent) config.navigate(workspace.href);
      case final PalettePageItem page:
        if (page.onSelect != null) {
          page.onSelect!();
        } else if (page.href != null) {
          if (page.href!.startsWith('http')) {
            unawaited(_openExternal(page.href!));
          } else {
            config.navigate(page.href!);
          }
        }
      case final PaletteIntegrationItem item:
        config.navigate(item.href);
      case final PaletteTaskItem item:
        config.navigate(item.href);
      case final PaletteLogItem item:
        config.navigate(item.href);
    }
    config.close();
  }

  double get _listMaxHeight => math.max(
    0,
    math.min(
      PaletteMetrics.listMaxHeight,
      widget.viewportHeight * 0.85 - 26,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Semantics(
      container: true,
      identifier: 'search.dialog',
      label: 'Search',
      scopesRoute: true,
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.all(PaletteMetrics.ringPadding),
        decoration: BoxDecoration(
          color: sim.isDark ? c.surface5 : c.surface4,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(SimRadii.xl),
        ),
        child: Semantics(
          container: true,
          identifier: 'search.card',
          // `overflow-hidden` on the card: a paint clip only, so the boxes
          // inside report their full extent (see [_PaintClip]).
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.bg,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(SimRadii.lg),
            ),
            child: _PaintClip(
              clipper: const _RoundedClipper(radius: SimRadii.lg),
              child: Padding(
                padding: const EdgeInsets.all(SimLayout.borderWidth),
                child: DefaultTextStyle.merge(
                  style: sim.text.sm.copyWith(color: c.textBody),
                  child: Stack(
                    children: [
                      _buildList(context),
                      Positioned(
                        left: PaletteMetrics.inputBandInset,
                        right: PaletteMetrics.inputBandInset,
                        top: PaletteMetrics.inputBandInset,
                        child: _buildInput(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final style = sim.text.sm.copyWith(color: c.textBody);
    return Container(
      height: PaletteMetrics.inputBandHeight,
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.bg,
            c.bg.withValues(alpha: 0.88),
            c.bg.withValues(alpha: 0),
          ],
          stops: const [0, 0.68, 1],
        ),
      ),
      child: Row(
        children: [
          Semantics(
            container: true,
            identifier: 'search.palette.input.icon',
            child: SimIcon(SimEmcnIcons.search, color: c.textMuted),
          ),
          // `gap-2` less the input's `-ml-1`: the 32px input box starts
          // 4px early and `indent-1` puts the text back.
          const SizedBox(
            width: PaletteMetrics.inputGap - PaletteMetrics.inputIndent,
          ),
          Expanded(
            child: Semantics(
              container: true,
              identifier: 'search.palette.input',
              child: SizedBox(
                height: PaletteMetrics.inputHeight,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: PaletteMetrics.inputIndent,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SimEditable(
                      controller: _query,
                      focusNode: _inputFocus,
                      autofocus: true,
                      style: style,
                      placeholder: _askMode
                          ? 'Ask Sim anything...'
                          : 'Search anything...',
                      placeholderStyle: style.copyWith(color: c.textMuted),
                      semanticsLabel: _askMode ? 'Ask Sim' : 'Search anything',
                      onChanged: _onChanged,
                      onKeyEvent: _onKey,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_chatEnabled) ...[
            const SizedBox(width: PaletteMetrics.inputGap),
            Semantics(
              container: true,
              identifier: 'search.palette.input.hint',
              child: _TabHint(
                label: _askMode ? 'Search' : 'Ask Sim',
                style: sim.text.xs.copyWith(color: c.textSubtle),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    const padding = EdgeInsets.only(
      left: PaletteMetrics.listPaddingX,
      right: PaletteMetrics.listPaddingX,
      top: PaletteMetrics.listPaddingTop,
      bottom: PaletteMetrics.listPaddingBottom,
    );
    Widget body;
    double contentHeight;
    if (_askMode) {
      contentHeight = PaletteMetrics.rowHeight;
      body = Padding(
        padding: padding,
        child: PaletteRow(
          parityId: 'search.palette.ask-row',
          label: _askLabel,
          selected: true,
          onHover: () {},
          onTap: _askSim,
          leading: PaletteRow.icon(SimEmcnIcons.home),
        ),
      );
    } else if (_groups.isEmpty) {
      contentHeight = 24 + 20 + 24;
      body = Padding(
        padding: padding,
        child: Semantics(
          container: true,
          identifier: 'search.palette.empty',
          child: Container(
            height: contentHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No results found.',
              style: sim.text.sm.copyWith(color: c.textSubtle, height: 20 / 14),
            ),
          ),
        ),
      );
    } else {
      final extents = [
        for (var g = 0; g < _groups.length; g++)
          PaletteMetrics.groupExtent(_groups[g], first: g == 0),
      ];
      contentHeight = extents.fold<double>(0, (a, b) => a + b);
      final starts = <int>[];
      var flat = 0;
      for (final group in _groups) {
        starts.add(flat);
        flat += group.entries.length;
      }
      body = SimScrollFade(
        inset: PaletteMetrics.listPaddingTop,
        // `scrollbar-none`: the desktop/web scroll behaviour would add a
        // Scrollbar here.
        child: ListView.builder(
          controller: _scroll,
          // The list clips through [_PaintClip] below.
          clipBehavior: Clip.none,
          padding: padding,
          itemCount: _groups.length,
          itemExtentBuilder: (index, _) =>
              index < extents.length ? extents[index] : null,
          itemBuilder: (context, g) => _buildGroup(
            _groups[g],
            first: g == 0,
            start: starts[g],
          ),
        ),
      );
    }
    final total =
        PaletteMetrics.listPaddingTop +
        contentHeight +
        PaletteMetrics.listPaddingBottom;
    return Semantics(
      container: true,
      identifier: 'search.palette.list',
      child: SizedBox(
        height: math.min(total, _listMaxHeight),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: _PaintClip(clipper: const _ListClipper(), child: body),
        ),
      ),
    );
  }

  Widget _buildGroup(
    PaletteGroup group, {
    required bool first,
    required int start,
  }) {
    final children = <Widget>[
      if (group.heading != null)
        PaletteGroupHeading(text: group.heading!, groupKey: group.key),
    ];
    for (var j = 0; j < group.entries.length; j++) {
      final index = start + j;
      if (j > 0) children.add(const SizedBox(height: PaletteMetrics.rowGap));
      children.add(
        _ListVisibility(
          child: buildPaletteEntryRow(
            group.entries[j],
            selected: index == _selected,
            onHover: () {
              if (_selected != index && _selectable(index)) {
                _select(index, reveal: false);
              }
            },
            onTap: () => _activate(index),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : PaletteMetrics.groupGap),
      child: _ListVisibility(
        child: Semantics(
          identifier: 'search.palette.group.${group.key}',
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A constant [ValueListenable] (a palette mounted with a fixed permission
/// config).
class _FixedValue<T> implements ValueListenable<T> {
  const _FixedValue(this.value);

  @override
  final T value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// `[clip-path:inset(3px_round_13px)]` on the list.
class _ListClipper extends CustomClipper<Path> {
  const _ListClipper();

  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(PaletteMetrics.clipInset),
        const Radius.circular(PaletteMetrics.clipRadius),
      ),
    );

  @override
  bool shouldReclip(_ListClipper oldClipper) => false;
}

/// The card's `rounded-lg overflow-hidden` clip.
class _RoundedClipper extends CustomClipper<Path> {
  const _RoundedClipper({required this.radius});

  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );

  @override
  bool shouldReclip(_RoundedClipper oldClipper) => oldClipper.radius != radius;
}

/// Clips painting like [ClipPath] but describes no clip to semantics. The
/// palette's ids are element boxes: `getBoundingClientRect` ignores
/// `overflow` and `clip-path`, so a group the list scrolls partly out of
/// view still reports its whole box, as React's does.
class _PaintClip extends SingleChildRenderObjectWidget {
  const _PaintClip({required this.clipper, super.child});

  final CustomClipper<Path> clipper;

  @override
  RenderClipPath createRenderObject(BuildContext context) =>
      _RenderPaintClip(clipper: clipper);

  @override
  void updateRenderObject(BuildContext context, RenderClipPath renderObject) {
    renderObject.clipper = clipper;
  }
}

class _RenderPaintClip extends RenderClipPath {
  _RenderPaintClip({super.clipper}) : super(clipBehavior: Clip.antiAlias);

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => null;
}

/// Semantics visibility of a group or row against the list's
/// [_PaintClip], which itself describes no clip: a box that shows any part
/// inside the list keeps its whole rect (React's element box); one wholly
/// outside describes an empty clip, so the framework marks it hidden and
/// still reports its whole rect, instead of the part the overlay's screen
/// clip leaves.
class _ListVisibility extends SingleChildRenderObjectWidget {
  const _ListVisibility({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderListVisibility();
}

class _RenderListVisibility extends RenderProxyBox {
  /// Wholly outside the list's paint clip.
  bool get _outside {
    var clip = parent;
    while (clip != null && clip is! _RenderPaintClip) {
      clip = clip.parent;
    }
    if (clip is! _RenderPaintClip || !clip.hasSize || !hasSize) return false;
    final box = MatrixUtils.transformRect(
      getTransformTo(clip),
      Offset.zero & size,
    );
    return !box.overlaps(Offset.zero & clip.size);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _outside ? Rect.zero : null;

  /// The empty paint clip would also empty the semantics clip (and with it
  /// the rect); an unbounded one keeps the node's rect whole, `mx-0.5`
  /// overhang included.
  @override
  Rect? describeSemanticsClip(RenderObject? child) =>
      _outside ? Rect.largest : null;
}

/// `⇥ Ask Sim` / `⇥ Search`. The browser draws `⇥` (U+21E5, in no
/// bundled face) from the platform symbol font; CanvasKit's fallback
/// draws it narrower, so the slot takes the browser's advance for the
/// glyph and the label after it, end-aligned so the label sits where
/// React's does.
class _TabHint extends StatelessWidget {
  const _TabHint({required this.label, required this.style});

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: ' $label', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = PaletteMetrics.tabGlyphAdvance + painter.width;
    painter.dispose();
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '⇥ $label',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: style,
        ),
      ),
    );
  }
}
