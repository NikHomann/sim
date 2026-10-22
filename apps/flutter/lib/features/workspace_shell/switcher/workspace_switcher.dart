/// The workspace switcher (`workspace-header.tsx`): the sidebar header's
/// workspace chip, its 256px menu (organization back-link, search at six or
/// more workspaces, the pinned-first list with row actions and inline
/// rename, footer actions), the per-workspace context menu, and the create /
/// delete / leave modals.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/chrome/sidebar_controller.dart';
import 'package:sim_app/features/workspace_shell/modals/create_workspace_modal.dart';
import 'package:sim_app/features/workspace_shell/modals/workspace_confirm_modals.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/context_menu.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/switcher/identity_tile.dart';
import 'package:sim_app/features/workspace_shell/switcher/switcher_actions.dart';
import 'package:sim_app/features/workspace_shell/switcher/switcher_logic.dart';
import 'package:sim_design/sim_design.dart';

/// The long-lived cubits the switcher reads.
class WorkspaceSwitcherDependencies {
  const WorkspaceSwitcherDependencies({
    required this.workspaces,
    required this.invitations,
    required this.permissions,
    required this.session,
    required this.deploymentShape,
    this.host,
  });

  factory WorkspaceSwitcherDependencies.fromLocator() =>
      WorkspaceSwitcherDependencies(
        workspaces: locator<WorkspacesCubit>(),
        invitations: locator<InvitationsCubit>(),
        permissions: locator<PermissionsCubit>(),
        session: locator<SessionCubit>(),
        deploymentShape: locator<DeploymentShapeCubit>(),
        host: locator.isRegistered<WorkspaceHostCubit>()
            ? locator<WorkspaceHostCubit>()
            : null,
      );

  final WorkspacesCubit workspaces;
  final InvitationsCubit invitations;
  final PermissionsCubit permissions;
  final SessionCubit session;
  final DeploymentShapeCubit deploymentShape;

  /// Supplies the workspace name before the list resolves.
  final WorkspaceHostCubit? host;
}

/// Switcher geometry (`workspace-header.tsx:521-599`).
abstract final class SwitcherMetrics {
  static const double menuWidth = SimLayout.workspaceSwitcherWidth;
  static const double viewportGutter = 24;
  static const double sideOffset = 8;
  static const double listMaxHeight = 200;
  static const double listBleed = 6;
  static const double rowGap = 2;
  static const double rowHeight = 30;
  static const double actionSlot = 28;
}

/// Parity id of the per-workspace context menu; its items are
/// `.item.<key>` (`pin`, `rename`, `upload-logo`, `leave`, `delete`).
const String switcherContextMenuId = 'workspace.switcher.context-menu';

/// Shared menu state the chip, the menu layer and the context menu touch.
class _SwitcherModel extends ChangeNotifier {
  String? editingId;
  String editingName = '';
  bool renameSaving = false;

  /// The row whose context menu is open (drawn active).
  String? menuOpenWorkspaceId;
  bool contextMenuOpen = false;

  /// Set by a pointer-down on a row's "…" so the closing context menu does
  /// not close the switcher.
  bool contextMenuOpening = false;

  /// Set by Rename and Pin: their result shows in the still-open switcher.
  bool keepMenuOpen = false;

  /// The menu was opened from the keyboard (Enter, Space, ArrowDown on the
  /// trigger): its first item takes the roving focus, like Radix.
  bool openedByKeyboard = false;

  void changed() => notifyListeners();
}

/// The sidebar header's workspace chip (`WorkspaceHeader`). Mounted by the
/// sidebar with the route's [workspaceId] and the rail state.
class WorkspaceSwitcherChip extends StatefulWidget {
  const WorkspaceSwitcherChip({
    required this.workspaceId,
    required this.collapsed,
    super.key,
    this.organizationHref,
    this.dependencies,
    this.navigator,
    this.onExpandSidebar,
    this.onInviteTeammates,
    this.onViewInvitations,
    this.onUploadLogo,
    this.invitationsDisabledByConfig = false,
  });

  final String workspaceId;
  final bool collapsed;

  /// "Back to organization" target (`/o/{orgId}`), when any.
  final String? organizationHref;
  final WorkspaceSwitcherDependencies? dependencies;

  /// The sidebar's navigator (in-app moves behind the settings guard, new
  /// tabs through the shared link base); defaults to the one the sidebar
  /// environment resolves.
  final SidebarNavigator? navigator;

  /// Collapsed rail click; defaults to the chrome's [SidebarController].
  final VoidCallback? onExpandSidebar;

  /// Entry points of modals owned by the workspace-modals spec.
  final VoidCallback? onInviteTeammates;
  final VoidCallback? onViewInvitations;
  final void Function(String workspaceId)? onUploadLogo;

  /// `usePermissionConfig().isInvitationsDisabled`.
  final bool invitationsDisabledByConfig;

  @override
  State<WorkspaceSwitcherChip> createState() => _WorkspaceSwitcherChipState();
}

class _WorkspaceSwitcherChipState extends State<WorkspaceSwitcherChip> {
  late WorkspaceSwitcherDependencies _deps =
      widget.dependencies ?? WorkspaceSwitcherDependencies.fromLocator();
  final _SwitcherModel _model = _SwitcherModel();
  final GlobalKey _triggerKey = GlobalKey(debugLabel: 'WorkspaceSwitcher');
  SimOverlayEntry? _menuEntry;
  SimMenuHandle? _contextMenu;
  bool _railHovered = false;
  bool _disposed = false;

  late final WorkspaceSwitcherActions _actions = WorkspaceSwitcherActions(
    workspaces: _deps.workspaces,
    navigator: () => widget.navigator ?? _defaultNavigator,
    currentWorkspaceId: () => widget.workspaceId,
    sessionUserId: () => _deps.session.state.user?.id,
  );

  late final SidebarNavigator _defaultNavigator = resolveSidebarServices(
    context,
  ).navigator;

  SidebarNavigator get _navigator => _actions.navigator;

  @override
  void initState() {
    super.initState();
    _ensureList();
  }

  @override
  void didUpdateWidget(WorkspaceSwitcherChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dependencies != null &&
        widget.dependencies != oldWidget.dependencies) {
      _deps = widget.dependencies!;
    }
    if (oldWidget.workspaceId != widget.workspaceId) _ensureList();
    if (oldWidget.collapsed != widget.collapsed && widget.collapsed) {
      _closeMenu();
    }
    _menuEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _disposed = true;
    final contextMenu = _contextMenu;
    final menu = _menuEntry;
    _contextMenu = null;
    _menuEntry = null;
    contextMenu?.close();
    menu?.remove();
    _model.dispose();
    super.dispose();
  }

  /// The list the chip reads; the visit itself (`useWorkspaceManagement`)
  /// is recorded once by the chrome on workspace entry.
  void _ensureList() {
    final workspaces = _deps.workspaces;
    if (!workspaces.state.list.hasData && !workspaces.state.isLoading) {
      unawaited(workspaces.load());
    }
  }

  bool get _menuOpen => _menuEntry != null;

  void _toggleMenu() => _menuOpen ? _requestCloseMenu() : _openMenu();

  /// Radix's trigger keys: Enter, Space and ArrowDown open the menu with
  /// its first item focused.
  KeyEventResult _onTriggerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _menuOpen) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _openMenu(keyboard: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openMenu({bool keyboard = false}) {
    if (_menuEntry != null) return;
    _model.openedByKeyboard = keyboard;
    final overlay = SimOverlay.maybeOf(context);
    final triggerContext = _triggerKey.currentContext;
    if (overlay == null || triggerContext == null) return;
    // Opening is the "user is looking" moment: refetch stale server state.
    unawaited(_deps.workspaces.load());
    unawaited(_deps.invitations.loadMine());
    late final SimOverlayEntry entry;
    entry = SimOverlayEntry(
      z: SimZ.dropdown,
      modal: true,
      onDismissRequested: _requestCloseMenu,
      onRemoved: () {
        if (identical(_menuEntry, entry)) _menuEntry = null;
        if (mounted && !_disposed) setState(() {});
      },
      builder: (context) => _SwitcherMenuLayer(
        contentKey: entry.contentKey,
        anchor: overlay.rectOf(triggerContext),
        menu: _menuContent,
      ),
    );
    _menuEntry = entry;
    overlay.insert(entry);
    setState(() {});
  }

  Widget _menuContent() => _SwitcherMenu(
    workspaceId: widget.workspaceId,
    organizationHref: widget.organizationHref,
    deps: _deps,
    model: _model,
    invitationsDisabledByConfig: widget.invitationsDisabledByConfig,
    onSwitch: _switchFromMenu,
    onOpenInNewTab: _actions.openInNewTab,
    onContextMenu: _openContextMenu,
    onRename: _saveRename,
    onOrganization: _goToOrganization,
    onNewWorkspace: _newWorkspace,
    onInvite: _invite,
    onViewInvitations: _viewInvitations,
  );

  /// `onOpenChange(false)`: refused while a context menu is open or opening
  /// or a rename is active. Escape during a rename cancels it instead.
  void _requestCloseMenu() {
    if (_model.contextMenuOpen || _model.contextMenuOpening) return;
    if (_model.editingId != null) {
      final escape = _menuEntry?.dismissReason == SimDismissReason.escape;
      if (escape) {
        if (!_model.renameSaving) {
          _model
            ..editingId = null
            ..changed();
        }
      } else {
        // An outside press blurs the input (which saves); the menu stays.
        FocusManager.instance.primaryFocus?.unfocus();
      }
      return;
    }
    _closeMenu();
  }

  /// `setIsWorkspaceMenuOpen(false)`; a changed name still being edited is
  /// saved.
  void _closeMenu() {
    final entry = _menuEntry;
    if (entry == null) return;
    final editing = _model.editingId;
    if (editing != null) {
      final ws = _deps.workspaces.state.byId(editing);
      final name = _model.editingName.trim();
      if (ws != null && name.isNotEmpty && name != ws.name) {
        unawaited(_actions.rename(editing, name));
      }
      _model.editingId = null;
    }
    _menuEntry = null;
    entry.remove();
    if (mounted && !_disposed) setState(() {});
  }

  void _switchFromMenu(Workspace target) {
    _closeMenu();
    _actions.switchTo(target);
  }

  void _goToOrganization() {
    final href = widget.organizationHref;
    _closeMenu();
    if (href == null) return;
    _navigator.go(href);
  }

  void _newWorkspace() {
    final policy = _deps.workspaces.state.creationPolicy;
    if (policy != null && !policy.canCreate) return;
    _closeMenu();
    unawaited(
      showCreateWorkspaceModal(
        context,
        onConfirm: _actions.create,
        describeError: (e) => errorMessage(e, 'Failed to create workspace'),
      ),
    );
  }

  void _invite() {
    _closeMenu();
    final active = _deps.workspaces.state.byId(widget.workspaceId);
    final disabled =
        widget.invitationsDisabledByConfig ||
        active?.inviteDisabledReason != null;
    if (disabled) {
      if (_deps.deploymentShape.state.shape.billingEnabled) {
        _navigator.go('/workspace/${widget.workspaceId}/settings/billing');
      }
      return;
    }
    widget.onInviteTeammates?.call();
  }

  void _viewInvitations() {
    _closeMenu();
    widget.onViewInvitations?.call();
  }

  Future<void> _saveRename(String workspaceId, String name) async {
    _model
      ..renameSaving = true
      ..changed();
    try {
      await _actions.rename(workspaceId, name);
    } finally {
      _model.renameSaving = false;
      if (_model.editingId == workspaceId) _model.editingId = null;
      _model.changed();
    }
  }

  /// `WorkspaceContextMenu` → the shared `ContextMenu`
  /// (`context-menu.tsx:201`, `modal={false}`): the 1×1 trigger at the
  /// pointer (or the "…" corner) puts the menu 5px below it. Non-modal, so a
  /// pointer-down on another row's "…" both closes this menu and reaches
  /// that button, which hands the switcher over to its own menu.
  void _openContextMenu(Workspace workspace, Offset globalPosition) {
    if (SimOverlay.maybeOf(context) == null) return;
    final previous = _contextMenu;
    _model
      ..contextMenuOpening = true
      ..menuOpenWorkspaceId = workspace.id
      ..contextMenuOpen = true
      ..changed();
    if (previous != null) {
      _contextMenu = null;
      previous.close();
    }
    late final SimMenuHandle handle;
    handle = showSidebarContextMenu(
      context,
      globalPosition,
      semanticsIdentifier: switcherContextMenuId,
      entries: () => _contextEntries(workspace),
      onClose: () => _onContextMenuClosed(handle),
    );
    _contextMenu = handle;
    _model.contextMenuOpening = false;
  }

  /// `closeContextMenu`: closes the switcher too unless the action kept it
  /// open or another context menu is opening.
  void _onContextMenuClosed(SimMenuHandle handle) {
    if (!identical(_contextMenu, handle)) return;
    _contextMenu = null;
    final openingAnother = _model.contextMenuOpening;
    final keep = _model.keepMenuOpen;
    _model
      ..contextMenuOpen = false
      ..menuOpenWorkspaceId = null
      ..contextMenuOpening = false
      ..keepMenuOpen = false
      ..changed();
    if (!keep && !openingAnother) _closeMenu();
  }

  SimMenuItem _contextItem(
    String key,
    String label,
    SimIconData icon,
    VoidCallback onSelect, {
    bool enabled = true,
  }) => sidebarMenuItem(
    icon,
    label,
    onSelect,
    enabled: enabled,
    semanticsIdentifier: '$switcherContextMenuId.item.$key',
  );

  /// Pin, Rename, Upload logo, ─, Leave, Delete
  /// (`workspace-context-menu.tsx:30-45`).
  List<SimMenuEntry> _contextEntries(Workspace workspace) {
    final state = _deps.workspaces.state;
    final policy = WorkspaceMenuPolicy.of(
      workspace,
      workspaceCount: state.workspaces.length,
      sessionUserId: _deps.session.state.user?.id,
    );
    final pinned = state.pinnedIds.contains(workspace.id);
    return [
      _contextItem(
        'pin',
        pinned ? 'Unpin' : 'Pin',
        pinned ? SimEmcnIcons.pinOff : SimEmcnIcons.pin,
        () {
          _model.keepMenuOpen = true;
          unawaited(_actions.togglePin(workspace.id));
        },
      ),
      _contextItem('rename', 'Rename', SimEmcnIcons.pencil, () {
        _model
          ..keepMenuOpen = true
          ..editingId = workspace.id
          ..editingName = workspace.name
          ..changed();
        _openMenu();
      }, enabled: policy.canRename),
      _contextItem(
        'upload-logo',
        'Upload logo',
        SimEmcnIcons.imageUp,
        () => widget.onUploadLogo?.call(workspace.id),
        enabled: policy.canUploadLogo,
      ),
      const SimMenuSeparator(
        semanticsIdentifier: '$switcherContextMenuId.separator',
      ),
      if (policy.showLeave)
        _contextItem(
          'leave',
          'Leave',
          SimEmcnIcons.logOut,
          () => _confirmLeave(workspace),
        ),
      _contextItem(
        'delete',
        'Delete',
        SimEmcnIcons.trash,
        () => _confirmDelete(workspace),
        enabled: policy.canDelete,
      ),
    ];
  }

  void _confirmDelete(Workspace workspace) {
    _closeMenuAfterContext();
    unawaited(
      showDeleteWorkspaceModal(
        context,
        workspaceName: workspace.name,
        onConfirm: () => _actions.delete(workspace),
      ),
    );
  }

  void _confirmLeave(Workspace workspace) {
    _closeMenuAfterContext();
    unawaited(
      showLeaveWorkspaceModal(
        context,
        workspaceName: workspace.name,
        onConfirm: () => _actions.leave(workspace),
        onError: (error) => SimToasts.instance.error(
          "Couldn't leave workspace",
          description: errorMessage(error, 'Please try again in a moment.'),
        ),
      ),
    );
  }

  /// The switcher closes once the context menu that triggered this does.
  void _closeMenuAfterContext() => _model.keepMenuOpen = false;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkspacesCubit, WorkspacesState>(
        bloc: _deps.workspaces,
        builder: (context, state) {
          final full = state.byId(widget.workspaceId);
          final hostName = _hostName();
          final name = full?.name ?? hostName;
          if (widget.collapsed) return _railChip(full, name);
          final ready = !state.isLoading && full != null;
          if (!ready) return _loadingTrigger(full, name);
          return _trigger(full, name);
        },
      );

  String? _hostName() {
    final host = _deps.host?.state;
    final ws = host?.context?.workspace;
    if (ws == null || ws.id != widget.workspaceId) return null;
    return ws.name;
  }

  Widget _trigger(Workspace full, String? name) {
    final sim = SimTheme.of(context);
    final label = name ?? '';
    return Align(
      alignment: AlignmentDirectional.centerStart,
      heightFactor: 1,
      child: Semantics(
        key: _triggerKey,
        identifier: 'workspace.switcher.trigger',
        container: true,
        expanded: _menuOpen,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onTriggerKey,
          child: SimChip(
            semanticsLabel: 'Switch workspace',
            onPressed: _toggleMenu,
            onSecondaryTapDown: (position) => _openContextMenu(full, position),
            leftAdornment: Semantics(
              container: true,
              identifier: 'workspace.switcher.trigger.tile',
              child: IdentityTile(name: full.name, logoUrl: full.logoUrl),
            ),
            rightAdornment: label.isEmpty
                ? null
                : Semantics(
                    container: true,
                    identifier: 'workspace.switcher.trigger.chevron',
                    child: const SimChipChevron(),
                  ),
            child: Semantics(
              container: true,
              identifier: 'workspace.switcher.trigger.label',
              child: SimOverflowText(
                label: label,
                style: sim.text.sm.copyWith(color: sim.colors.textBody),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The disabled stand-in while the list resolves: same pill geometry, no
  /// hover, the host-context name when known.
  Widget _loadingTrigger(Workspace? full, String? name) {
    final sim = SimTheme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      heightFactor: 1,
      child: Semantics(
        container: true,
        identifier: 'workspace.switcher.trigger',
        button: true,
        enabled: false,
        label: 'Switch workspace',
        child: Container(
          height: SimChipChrome.height,
          padding: const EdgeInsets.symmetric(
            horizontal: SimChipChrome.paddingX,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: SimChipChrome.gap,
            children: [
              if (name != null)
                IdentityTile(name: name, logoUrl: full?.logoUrl)
              else
                const SimSkeleton(
                  width: 16,
                  height: 16,
                  radius: SimRadii.identityTile16,
                ),
              if (name != null && name.isNotEmpty) ...[
                Flexible(
                  child: SimOverflowText(
                    label: name,
                    style: sim.text.sm.copyWith(color: sim.colors.textBody),
                  ),
                ),
                const SimChipChevron(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The collapsed rail's 32px expand chip: the tile swaps to a rotated
  /// `PanelLeft` on hover.
  Widget _railChip(Workspace? full, String? name) {
    final expand =
        widget.onExpandSidebar ??
        () {
          if (locator.isRegistered<SidebarController>()) {
            locator<SidebarController>().toggleCollapsed();
          }
        };
    final mark = name == null
        ? const SimSkeleton(
            width: 16,
            height: 16,
            radius: SimRadii.identityTile16,
          )
        : Stack(
            alignment: Alignment.center,
            children: [
              Visibility.maintain(
                visible: !_railHovered,
                child: IdentityTile(name: name, logoUrl: full?.logoUrl),
              ),
              Visibility.maintain(
                visible: _railHovered,
                child: Transform.rotate(
                  angle: math.pi,
                  child: const SimIcon(SimEmcnIcons.panelLeft, size: 16),
                ),
              ),
            ],
          );
    return Semantics(
      identifier: 'workspace.switcher.trigger.collapsed',
      container: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _railHovered = true),
        onExit: (_) => setState(() => _railHovered = false),
        child: SizedBox(
          width: SimLayout.sidebarRailChip,
          child: SimChip(
            fullWidth: true,
            semanticsLabel: 'Expand sidebar',
            onPressed: expand,
            leftAdornment: SizedBox.square(
              dimension: 16,
              child: Center(child: mark),
            ),
          ),
        ),
      ),
    );
  }
}

/// Positions the menu under the trigger (`align='start' side='bottom'
/// sideOffset={8}`), 256px wide but at most `100vw - 24px`, and at most the
/// available height.
class _SwitcherMenuLayer extends StatelessWidget {
  const _SwitcherMenuLayer({
    required this.contentKey,
    required this.anchor,
    required this.menu,
  });

  final GlobalKey contentKey;
  final Rect anchor;
  final Widget Function() menu;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(
        SwitcherMetrics.menuWidth,
        constraints.maxWidth - SwitcherMetrics.viewportGutter,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          const SimOverlayBarrier(color: Color(0x00000000)),
          SimAnchoredOverlay(
            anchor: anchor,
            sideOffset: SwitcherMetrics.sideOffset,
            minWidth: width,
            maxWidth: width,
            contentKey: contentKey,
            child: menu(),
          ),
        ],
      );
    },
  );
}

/// A selectable entry of the menu for keyboard navigation (no search).
class _MenuTarget {
  const _MenuTarget({
    required this.id,
    required this.label,
    required this.activate,
    this.workspace,
  });

  final String id;

  /// Matched by typeahead.
  final String label;
  final VoidCallback activate;
  final Workspace? workspace;
}

/// How long typed characters accumulate into one typeahead search (Radix).
const Duration _typeaheadReset = Duration(seconds: 1);

class _SwitcherMenu extends StatefulWidget {
  const _SwitcherMenu({
    required this.workspaceId,
    required this.organizationHref,
    required this.deps,
    required this.model,
    required this.invitationsDisabledByConfig,
    required this.onSwitch,
    required this.onOpenInNewTab,
    required this.onContextMenu,
    required this.onRename,
    required this.onOrganization,
    required this.onNewWorkspace,
    required this.onInvite,
    required this.onViewInvitations,
  });

  final String workspaceId;
  final String? organizationHref;
  final WorkspaceSwitcherDependencies deps;
  final _SwitcherModel model;
  final bool invitationsDisabledByConfig;
  final void Function(Workspace workspace) onSwitch;
  final void Function(Workspace workspace) onOpenInNewTab;
  final void Function(Workspace workspace, Offset globalPosition) onContextMenu;
  final Future<void> Function(String workspaceId, String name) onRename;
  final VoidCallback onOrganization;
  final VoidCallback onNewWorkspace;
  final VoidCallback onInvite;
  final VoidCallback onViewInvitations;

  @override
  State<_SwitcherMenu> createState() => _SwitcherMenuState();
}

class _SwitcherMenuState extends State<_SwitcherMenu> {
  final SwitcherSearch _search = SwitcherSearch();
  final TextEditingController _query = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'WorkspaceSearch');
  final FocusNode _menuFocus = FocusNode(debugLabel: 'WorkspaceMenu');
  final ScrollController _listScroll = ScrollController();
  final Map<String, GlobalKey> _rowKeys = {};
  final Map<String, GlobalKey> _actionKeys = {};
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Roving focus without search: the focused target id, and whether focus
  /// sits on that row's "…" action.
  String? _focusedId;
  bool _actionFocused = false;

  /// Radix typeahead: characters typed within [_typeaheadReset].
  String _typeahead = '';
  Timer? _typeaheadTimer;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_onModel);
    final deps = widget.deps;
    for (final stream in [
      deps.workspaces.stream,
      deps.invitations.stream,
      deps.permissions.stream,
    ]) {
      _subscriptions.add(
        stream.listen((_) {
          if (mounted) setState(() {});
        }),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_showSearch) {
        _searchFocus.requestFocus();
      } else if (widget.model.editingId == null) {
        _menuFocus.requestFocus();
        if (widget.model.openedByKeyboard) {
          final targets = _targets(_workspaces, _footer());
          if (targets.isNotEmpty) setState(() => _focusedId = targets.first.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _typeaheadTimer?.cancel();
    widget.model.removeListener(_onModel);
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _query.dispose();
    _searchFocus.dispose();
    _menuFocus.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  void _onModel() {
    if (mounted) setState(() {});
  }

  List<Workspace> get _workspaces => widget.deps.workspaces.state.ordered;
  bool get _showSearch => _workspaces.length >= workspaceSearchThreshold;

  /// `scrollIntoView({block: 'nearest'})`: a row above the viewport aligns
  /// to its top, one below to its bottom, a visible one does not scroll.
  void _reveal(String workspaceId) {
    final ctx = _rowKeys[workspaceId]?.currentContext;
    if (ctx == null) return;
    unawaited(
      Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ),
    );
    unawaited(
      Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ),
    );
  }

  _Footer _footer() {
    final deps = widget.deps;
    final state = deps.workspaces.state;
    final policy = state.creationPolicy;
    final active = state.byId(widget.workspaceId);
    return _Footer(
      canCreate: policy?.canCreate ?? true,
      createReason: policy?.canCreate == false ? policy?.reason : null,
      showInvite: deps.permissions.state.userPermissions.canAdmin,
      inviteReason: active?.inviteDisabledReason,
      showInvitations: deps.invitations.state.hasPending,
    );
  }

  KeyEventResult _onSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_query.value.composing.isValid) return KeyEventResult.ignored;
    final filtered = _search.filter(_workspaces);
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (filtered.isEmpty) return KeyEventResult.handled;
      setState(
        () => _search.move(
          filtered,
          key == LogicalKeyboardKey.arrowDown ? 1 : -1,
        ),
      );
      final id = _search.highlightedId;
      if (id != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(id));
      }
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        event is KeyDownEvent) {
      final target = _search.enterTarget(filtered);
      if (target != null) widget.onSwitch(target);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<_MenuTarget> _targets(List<Workspace> rows, _Footer footer) => [
    if (widget.organizationHref != null)
      _MenuTarget(
        id: 'org',
        label: 'Back to organization',
        activate: widget.onOrganization,
      ),
    for (final w in rows)
      if (w.id != widget.model.editingId)
        _MenuTarget(
          id: 'row:${w.id}',
          label: w.name,
          workspace: w,
          activate: () => widget.onSwitch(w),
        ),
    if (footer.canCreate)
      _MenuTarget(
        id: 'new',
        label: 'New workspace',
        activate: widget.onNewWorkspace,
      ),
    if (footer.showInvite)
      _MenuTarget(
        id: 'invite',
        label: 'Invite teammates',
        activate: widget.onInvite,
      ),
    if (footer.showInvitations)
      _MenuTarget(
        id: 'invitations',
        label: 'View invitations',
        activate: widget.onViewInvitations,
      ),
  ];

  /// Radix typeahead: the next target (after the focused one, wrapping)
  /// whose label starts with the typed characters.
  bool _typeAhead(String character, List<_MenuTarget> targets) {
    _typeaheadTimer?.cancel();
    _typeaheadTimer = Timer(_typeaheadReset, () => _typeahead = '');
    _typeahead += character.toLowerCase();
    final start = targets.indexWhere((t) => t.id == _focusedId);
    final n = targets.length;
    // A repeated single character cycles through its matches.
    final repeated =
        _typeahead.length > 1 &&
        _typeahead.split('').every((c) => c == _typeahead[0]);
    final search = repeated ? _typeahead[0] : _typeahead;
    final single = repeated || _typeahead.length == 1;
    final from = start < 0 ? (single ? -1 : 0) : start;
    for (var step = 0; step < n; step++) {
      final i = (from + (single ? step + 1 : step)) % n;
      if (targets[i].label.toLowerCase().startsWith(search)) {
        setState(() {
          _focusedId = targets[i].id;
          _actionFocused = false;
        });
        final ws = targets[i].workspace;
        if (ws != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(ws.id));
        }
        return true;
      }
    }
    return false;
  }

  KeyEventResult _onMenuKey(
    KeyEvent event,
    List<_MenuTarget> targets,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (targets.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final index = targets.indexWhere((t) => t.id == _focusedId);
    void focus(int i) => setState(() {
      _focusedId = targets[i].id;
      _actionFocused = false;
      final ws = targets[i].workspace;
      if (ws != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(ws.id));
      }
    });
    final n = targets.length;
    if (key == LogicalKeyboardKey.arrowDown) {
      focus(index < 0 ? 0 : (index + 1) % n);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      focus(index < 0 ? n - 1 : (index - 1 + n) % n);
    } else if (key == LogicalKeyboardKey.home) {
      focus(0);
    } else if (key == LogicalKeyboardKey.end) {
      focus(n - 1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (index < 0 || targets[index].workspace == null) {
        return KeyEventResult.ignored;
      }
      setState(() => _actionFocused = true);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (!_actionFocused) return KeyEventResult.ignored;
      setState(() => _actionFocused = false);
    } else if (event is KeyDownEvent && isKeyboardActivation(event)) {
      if (index < 0) return KeyEventResult.ignored;
      final target = targets[index];
      final ws = target.workspace;
      if (_actionFocused && ws != null) {
        _openActionMenu(ws);
      } else {
        target.activate();
      }
    } else {
      final character = event.character;
      final keys = HardwareKeyboard.instance;
      if (character == null ||
          character.length != 1 ||
          character.trim().isEmpty ||
          keys.isControlPressed ||
          keys.isMetaPressed ||
          keys.isAltPressed) {
        return KeyEventResult.ignored;
      }
      _typeAhead(character, targets);
    }
    return KeyEventResult.handled;
  }

  /// The "…" opens the context menu at the button's top-right corner.
  void _openActionMenu(Workspace workspace) {
    final box =
        _actionKeys[workspace.id]?.currentContext?.findRenderObject()
            as RenderBox?;
    if (box == null || !box.attached) return;
    final topRight = box.localToGlobal(Offset(box.size.width, 0));
    widget.onContextMenu(workspace, topRight);
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final deps = widget.deps;
    final state = deps.workspaces.state;
    final loading = state.isLoading;
    final workspaces = _workspaces;
    final showSearch = _showSearch;
    final filtered = _search.filter(workspaces);
    if (showSearch) _search.seed(filtered);
    final activeIndex = _search.activeIndex(filtered);
    final footer = _footer();
    final targets = _targets(filtered, footer);
    final hasOrg = widget.organizationHref != null;
    final model = widget.model;

    final children = <Widget>[
      if (hasOrg) ...[
        Semantics(
          container: true,
          identifier: 'workspace.switcher.menu.org-link',
          link: true,
          child: _SwitcherRow(
            label: 'Back to organization',
            leading: const SimIcon(SimEmcnIcons.arrowLeft),
            focused: _focusedId == 'org',
            onTap: widget.onOrganization,
          ),
        ),
        if (!showSearch || loading) const SimMenuSeparatorLine(),
      ],
      if (!loading) ...[
        if (showSearch)
          Padding(
            padding: EdgeInsets.only(top: hasOrg ? 8 : 0),
            child: Semantics(
              container: true,
              identifier: 'workspace.switcher.menu.search',
              child: SimChipInput(
                controller: _query,
                focusNode: _searchFocus,
                icon: SimIcons.search,
                placeholder: 'Search workspaces...',
                onKeyEvent: _onSearchKey,
                onChanged: (value) => setState(() => _search.type(value)),
              ),
            ),
          ),
        _list(filtered, showSearch, activeIndex),
        Container(
          height: SimLayout.borderWidth,
          margin: const EdgeInsets.only(bottom: 4),
          color: c.border,
          child: Semantics(
            container: true,
            identifier: 'workspace.switcher.menu.separator',
            child: const SizedBox.expand(),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: SwitcherMetrics.rowGap,
          children: [
            _withReason(
              footer.createReason,
              Semantics(
                container: true,
                identifier: 'workspace.switcher.menu.new',
                child: _SwitcherRow(
                  label: 'New workspace',
                  leading: const SimIcon(SimEmcnIcons.plus),
                  enabled: footer.canCreate,
                  focused: _focusedId == 'new',
                  onTap: widget.onNewWorkspace,
                ),
              ),
            ),
            if (footer.showInvite)
              _withReason(
                footer.inviteReason,
                Semantics(
                  container: true,
                  identifier: 'workspace.switcher.menu.invite',
                  child: _SwitcherRow(
                    label: 'Invite teammates',
                    leading: const SimIcon(SimEmcnIcons.send),
                    focused: _focusedId == 'invite',
                    onTap: widget.onInvite,
                  ),
                ),
              ),
            if (footer.showInvitations)
              Semantics(
                container: true,
                identifier: 'workspace.switcher.menu.invitations',
                child: _SwitcherRow(
                  label: 'View invitations',
                  leading: const SimIcon(SimEmcnIcons.mail),
                  focused: _focusedId == 'invitations',
                  onTap: widget.onViewInvitations,
                ),
              ),
          ],
        ),
      ],
    ];

    return Semantics(
      identifier: 'workspace.switcher.menu',
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: SimMenuStyles.surface(c),
        child: Focus(
          focusNode: _menuFocus,
          onKeyEvent: (node, event) => model.editingId != null || showSearch
              ? KeyEventResult.ignored
              : _onMenuKey(event, targets),
          // A scroll view clips its descendants' semantics boxes to its
          // width, but the list (`-mx-1.5`) overhangs the content box by
          // the 1px border on each side: the viewport spans that overhang
          // and pads it back, so the list reports its whole 258px box.
          child: _Bleed(
            bleed: SimLayout.borderWidth,
            child: SingleChildScrollView(
              // The CSS border adds to the box: content starts 1px inside it.
              padding:
                  SimMenuStyles.padding +
                  const EdgeInsets.all(SimLayout.borderWidth) +
                  const EdgeInsets.symmetric(
                    horizontal: SimLayout.borderWidth,
                  ),
              child: DefaultTextStyle.merge(
                style: sim.text.sm.copyWith(color: c.textBody),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _withReason(String? reason, Widget child) =>
      reason == null ? child : SimTooltip(message: reason, child: child);

  Widget _list(List<Workspace> filtered, bool showSearch, int activeIndex) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final model = widget.model;
    final pinned = widget.deps.workspaces.state.pinnedIds;
    final rows = <Widget>[
      if (filtered.isEmpty && _search.query.isNotEmpty)
        Semantics(
          container: true,
          identifier: 'workspace.switcher.menu.empty',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              'No results for "${_search.query}"',
              style: sim.text.caption.copyWith(color: c.textMuted),
            ),
          ),
        ),
      for (var i = 0; i < filtered.length; i++)
        _row(
          filtered[i],
          index: i,
          showSearch: showSearch,
          keyboardHighlighted:
              showSearch && _search.keyboardNav && i == activeIndex,
          pinned: pinned.contains(filtered[i].id),
          model: model,
        ),
    ];
    return _Bleed(
      bleed: SwitcherMetrics.listBleed,
      child: Semantics(
        identifier: 'workspace.switcher.menu.list',
        container: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: SwitcherMetrics.listMaxHeight,
          ),
          child: SimScrollFade(
            child: SingleChildScrollView(
              controller: _listScroll,
              padding: EdgeInsets.fromLTRB(
                SwitcherMetrics.listBleed,
                showSearch ? 6 : 0,
                SwitcherMetrics.listBleed,
                4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: SwitcherMetrics.rowGap,
                children: rows,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    Workspace workspace, {
    required int index,
    required bool showSearch,
    required bool keyboardHighlighted,
    required bool pinned,
    required _SwitcherModel model,
  }) {
    final rowKey = _rowKeys.putIfAbsent(workspace.id, GlobalKey.new);
    final actionKey = _actionKeys.putIfAbsent(workspace.id, GlobalKey.new);
    final isActive = workspace.id == widget.workspaceId;
    final isMenuOpen = model.menuOpenWorkspaceId == workspace.id;
    if (model.editingId == workspace.id) {
      return KeyedSubtree(
        key: rowKey,
        child: _RenameRow(
          workspace: workspace,
          model: model,
          onSave: widget.onRename,
        ),
      );
    }
    final focused = _focusedId == 'row:${workspace.id}';
    return Semantics(
      key: rowKey,
      identifier: 'workspace.switcher.menu.row.${workspace.id}',
      container: true,
      child: Semantics(
        container: true,
        identifier: isActive ? 'workspace.switcher.menu.row.active' : null,
        child: _SwitcherRow(
          label: workspace.name,
          leading: IdentityTile(
            name: workspace.name,
            logoUrl: workspace.logoUrl,
          ),
          active: isActive || isMenuOpen || keyboardHighlighted,
          focused: focused && !_actionFocused,
          actionFocused: focused && _actionFocused,
          actionOpen: isMenuOpen,
          indicator: pinned
              ? Semantics(
                  container: true,
                  identifier: 'workspace.switcher.menu.row.pin',
                  label: 'Pinned',
                  image: true,
                  child: const SimIcon(SimEmcnIcons.pin, size: 12),
                )
              : null,
          action: Semantics(
            container: true,
            identifier: 'workspace.switcher.menu.row.more',
            child: _RowActionButton(
              key: actionKey,
              onPointerDown: () => model.contextMenuOpening = true,
              onCancel: () => model.contextMenuOpening = false,
              onPressed: () {
                model.contextMenuOpening = false;
                _openActionMenu(workspace);
              },
            ),
          ),
          onPointerMove: showSearch
              ? () {
                  if (_search.highlightedId == workspace.id &&
                      !_search.keyboardNav) {
                    return;
                  }
                  setState(() => _search.hover(workspace.id));
                }
              : null,
          onTap: () {
            final keys = HardwareKeyboard.instance;
            if (keys.isMetaPressed || keys.isControlPressed) {
              widget.onOpenInNewTab(workspace);
              return;
            }
            widget.onSwitch(workspace);
          },
          onMiddleTap: () => widget.onOpenInNewTab(workspace),
          onSecondaryTapDown: (position) =>
              widget.onContextMenu(workspace, position),
        ),
      ),
    );
  }
}

class _Footer {
  const _Footer({
    required this.canCreate,
    required this.createReason,
    required this.showInvite,
    required this.inviteReason,
    required this.showInvitations,
  });

  final bool canCreate;
  final String? createReason;
  final bool showInvite;
  final String? inviteReason;
  final bool showInvitations;
}

/// A menu row at `size='lg'`: 30px chip geometry, 14px `--text-body`,
/// hover/focus `--surface-hover`, `active` `--surface-active` held through
/// hover, an optional right slot (pin indicator that yields to the "…"
/// action on hover, focus, or while the row's context menu is open).
class _SwitcherRow extends StatefulWidget {
  const _SwitcherRow({
    required this.label,
    required this.onTap,
    this.leading,
    this.active = false,
    this.focused = false,
    this.actionFocused = false,
    this.enabled = true,
    this.indicator,
    this.action,
    this.actionOpen = false,
    this.onPointerMove,
    this.onMiddleTap,
    this.onSecondaryTapDown,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final bool active;
  final bool focused;
  final bool actionFocused;
  final bool enabled;
  final Widget? indicator;
  final Widget? action;
  final bool actionOpen;
  final VoidCallback? onPointerMove;
  final VoidCallback? onMiddleTap;
  final void Function(Offset globalPosition)? onSecondaryTapDown;

  @override
  State<_SwitcherRow> createState() => _SwitcherRowState();
}

class _SwitcherRowState extends State<_SwitcherRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final w = widget;
    final engaged = _hovered || w.focused || w.actionFocused;
    final showAction = w.action != null && (w.actionOpen || engaged);
    final reserve =
        w.indicator != null || w.actionOpen || (w.action != null && engaged);
    final fill = w.active
        ? c.surfaceActive
        : (w.enabled && engaged)
        ? c.surfaceHover
        : const Color(0x00000000);
    final row = Container(
      height: SwitcherMetrics.rowHeight,
      padding: EdgeInsets.only(
        left: SimChipChrome.paddingX,
        right: reserve ? SwitcherMetrics.actionSlot : SimChipChrome.paddingX,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(SimChipChrome.radius),
      ),
      child: Row(
        spacing: SimChipChrome.gap,
        children: [
          ?w.leading,
          Expanded(
            child: SimOverflowText(
              label: w.label,
              style: sim.text.sm.copyWith(color: c.textBody),
            ),
          ),
        ],
      ),
    );
    return Opacity(
      opacity: w.enabled ? 1 : 0.5,
      child: Semantics(
        button: true,
        enabled: w.enabled,
        selected: w.active,
        label: w.label,
        child: MouseRegion(
          cursor: w.enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          onHover: w.onPointerMove == null ? null : (_) => w.onPointerMove!(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: w.enabled ? w.onTap : null,
            onTertiaryTapUp: w.onMiddleTap == null
                ? null
                : (_) => w.onMiddleTap!(),
            onSecondaryTapDown: w.onSecondaryTapDown == null
                ? null
                : (details) => w.onSecondaryTapDown!(details.globalPosition),
            child: Stack(
              children: [
                row,
                if (showAction)
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _FocusRing(
                        focused: w.actionFocused,
                        child: w.action!,
                      ),
                    ),
                  )
                else if (w.indicator != null)
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: 18,
                      child: Center(child: w.indicator),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keyboard focus on a row's "…" (`--surface-hover` on the 18px button).
class _FocusRing extends StatelessWidget {
  const _FocusRing({required this.focused, required this.child});

  final bool focused;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: focused
          ? SimTheme.of(context).colors.surfaceActive
          : const Color(0x00000000),
      borderRadius: BorderRadius.circular(SimRadii.sm),
    ),
    child: child,
  );
}

/// `DropdownMenuItemAction`: the 18px "…" button (16px `MoreHorizontal`).
/// Its pointer-down marks a context menu as opening before the overlay host
/// dismisses the previous one.
class _RowActionButton extends StatelessWidget {
  const _RowActionButton({
    required this.onPointerDown,
    required this.onPressed,
    required this.onCancel,
    super.key,
  });

  final VoidCallback onPointerDown;
  final VoidCallback onPressed;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Workspace options',
    child: Listener(
      onPointerDown: (event) {
        if (event.buttons == kPrimaryButton) onPointerDown();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        onTapCancel: onCancel,
        child: const SizedBox.square(
          dimension: 18,
          child: Center(child: SimIcon(SimEmcnIcons.moreHorizontal, size: 16)),
        ),
      ),
    ),
  );
}

/// `SidebarRenameRow`: the active-fill chip holding an input (max 100
/// chars), focused and fully selected once. Enter saves the trimmed value
/// (even empty), Escape cancels, blur saves a changed non-empty value.
class _RenameRow extends StatefulWidget {
  const _RenameRow({
    required this.workspace,
    required this.model,
    required this.onSave,
  });

  final Workspace workspace;
  final _SwitcherModel model;
  final Future<void> Function(String workspaceId, String name) onSave;

  @override
  State<_RenameRow> createState() => _RenameRowState();
}

class _RenameRowState extends State<_RenameRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.model.editingName,
  );
  final FocusNode _focus = FocusNode(debugLabel: 'RenameWorkspace');
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus || _done) return;
    final name = _controller.text.trim();
    if (widget.model.editingId != widget.workspace.id) return;
    _done = true;
    if (name.isNotEmpty && name != widget.workspace.name) {
      unawaited(widget.onSave(widget.workspace.id, name));
    } else {
      widget.model
        ..editingId = null
        ..changed();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _done = true;
      unawaited(widget.onSave(widget.workspace.id, _controller.text.trim()));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _done = true;
      widget.model
        ..editingId = null
        ..changed();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final style = sim.text.sm.copyWith(color: c.textBody);
    return Semantics(
      container: true,
      identifier: 'workspace.switcher.menu.row.rename',
      child: Container(
        height: SwitcherMetrics.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: SimChipChrome.paddingX),
        decoration: BoxDecoration(
          color: c.surfaceActive,
          borderRadius: BorderRadius.circular(SimChipChrome.radius),
        ),
        child: Row(
          spacing: SimChipChrome.gap,
          children: [
            IdentityTile(
              name: widget.workspace.name,
              logoUrl: widget.workspace.logoUrl,
            ),
            Expanded(
              child: SimEditable(
                controller: _controller,
                focusNode: _focus,
                style: style,
                maxLength: 100,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !widget.model.renameSaving,
                semanticsLabel: 'Rename workspace ${widget.workspace.name}',
                onChanged: (value) => widget.model.editingName = value,
                onKeyEvent: _onKey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `-mx-1.5 … px-1.5`: lays [child] out [bleed] px wider on each side than
/// the slot it occupies, so the list's scroll fade runs into the menu's
/// padding while the rows stay aligned with the other menu rows.
class _Bleed extends SingleChildRenderObjectWidget {
  const _Bleed({required this.bleed, required super.child});

  final double bleed;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBleed(bleed);

  @override
  void updateRenderObject(BuildContext context, _RenderBleed renderObject) {
    renderObject.bleed = bleed;
  }
}

class _RenderBleed extends RenderShiftedBox {
  _RenderBleed(this._bleed) : super(null);

  double _bleed;

  double get bleed => _bleed;

  set bleed(double value) {
    if (value == _bleed) return;
    _bleed = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final width = constraints.maxWidth;
    child.layout(
      constraints.copyWith(
        minWidth: width + 2 * _bleed,
        maxWidth: width + 2 * _bleed,
      ),
      parentUsesSize: true,
    );
    (child.parentData! as BoxParentData).offset = Offset(-_bleed, 0);
    size = constraints.constrain(Size(width, child.size.height));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final offset = (child.parentData! as BoxParentData).offset;
    return result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }
}
