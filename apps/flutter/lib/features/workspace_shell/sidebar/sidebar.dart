import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/shared/browser_context_menu.dart';
import 'package:sim_app/features/workspace_shell/shared/permission_config.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/commands.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/global_commands.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/chats_section.dart';
import 'package:sim_app/features/workspace_shell/sidebar/footer/sidebar_footer.dart';
import 'package:sim_app/features/workspace_shell/sidebar/help/help_modal.dart';
import 'package:sim_app/features/workspace_shell/sidebar/nav/nav_chip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/nav/nav_items.dart';
import 'package:sim_app/features/workspace_shell/sidebar/nav/workspace_section.dart';
import 'package:sim_app/features/workspace_shell/sidebar/seams.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/sidebar_chip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/sidebar_tooltip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_events.dart';
import 'package:sim_app/features/workspace_shell/sidebar/status/status_notice.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_operations.dart';
import 'package:sim_app/features/workspace_shell/sidebar/workflows/workflows_section.dart';
import 'package:sim_design/sim_design.dart';

/// The workspace sidebar (`w/components/sidebar/sidebar.tsx`), mounted by
/// the chrome at the rail width (224px expanded by default, 48px
/// collapsed). Services come from the nearest [SidebarEnvironment], else
/// the app locator; the collapse toggle from the chrome's
/// `SidebarChromeScope`.
class WorkspaceSidebar extends StatefulWidget {
  const WorkspaceSidebar({
    required this.workspaceId,
    required this.collapsed,
    super.key,
  });

  final String workspaceId;
  final bool collapsed;

  @override
  State<WorkspaceSidebar> createState() => _WorkspaceSidebarState();
}

class _WorkspaceSidebarState extends State<WorkspaceSidebar> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _viewportKey = GlobalKey(debugLabel: 'sidebar.scroll');
  SidebarServices? _services;
  TreeOperations? _ops;
  WorkspaceWorkflowsRoom? _room;
  StreamSubscription<void>? _helpRequests;
  void Function()? _unregisterActions;
  SimScrollEdges _edges = SimScrollEdges.none;

  SidebarServices get services => _services!;
  TreeOperations get ops => _ops!;

  @override
  void initState() {
    super.initState();
    _helpRequests = SidebarEvents.openHelpModalRequests.listen(
      (_) => _openHelp(),
    );
  }

  /// Registers this sidebar's create-folder and import flows for the
  /// palette (`SearchModal onCreateFolder / onImportWorkflow`).
  void _registerActions() {
    _unregisterActions?.call();
    final import = services.onImportWorkflow;
    _unregisterActions = SidebarEvents.registerSidebarActions(
      createFolder: () {
        final ops = _ops;
        if (ops != null) unawaited(ops.createFolder());
      },
      importWorkflow: import,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = resolveSidebarServices(context);
    final provided = SidebarEnvironment.maybeOf(context) != null;
    if (_services == null || (provided && !identical(next, _services))) {
      _services = next;
      _bindWorkspace();
      _registerActions();
    }
  }

  @override
  void didUpdateWidget(WorkspaceSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) _bindWorkspace();
  }

  /// Mount effects per workspace: the workflow and folder lists, and the
  /// `workspace-workflows` invalidation room (`useWorkspaceWorkflowsRoom`).
  void _bindWorkspace() {
    final s = services;
    _ops?.dispose();
    _ops = TreeOperations(services: s, workspaceId: widget.workspaceId);
    unawaited(s.workflows.load(widget.workspaceId));
    unawaited(s.folders.load(widget.workspaceId));
    unawaited(_room?.dispose());
    _room = null;
    // TODO(phase-2): the room joins only when a `RealtimeTransport` is
    // registered, and none is until Phase 2 registers the socket transport
    // (docs/port/00-plan.md §6 Phase 2 "realtime collaboration end to end",
    // §4.3 SocketTransport; docs/port/known-gaps.md). Until then edits from
    // another tab or a teammate reach the tree through the 60 s staleness
    // refetch only.
    final transport = s.realtime;
    if (transport != null) {
      _room = WorkspaceWorkflowsRoom(
        transport: transport,
        workspaceId: widget.workspaceId,
        onChanged: s.workflows.onWorkspaceWorkflowsChanged,
      )..start();
    }
  }

  @override
  void dispose() {
    _unregisterActions?.call();
    unawaited(_helpRequests?.cancel());
    unawaited(_room?.dispose());
    _ops?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openHelp() {
    if (!mounted) return;
    unawaited(
      showHelpModal(
        context,
        repository: services.help,
        workspaceId: widget.workspaceId,
        workflowId: ops.activeWorkflowId,
        browser: services.browser,
      ),
    );
  }

  /// `handleSidebarClick` on a non-control target: select the open
  /// workflow only, or clear the selection.
  void _onBackgroundTap() {
    final active = ops.activeWorkflowId;
    if (active != null) {
      services.tree.selectOnly(active);
    } else {
      services.tree.clearAllSelection();
    }
  }

  Widget _header(BuildContext context) {
    final collapsed = widget.collapsed;
    final mac = services.mac;
    final toggle = sidebarToggle(context, services);
    return Parity(
      'shell.sidebar.header',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: SizedBox(
          height: SimChipChrome.height,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: WorkspaceSwitcherSlot(
                    workspaceId: widget.workspaceId,
                    collapsed: collapsed,
                  ),
                ),
              ),
              Parity(
                'shell.sidebar.header.actions',
                child: ExcludeFocus(
                  excluding: collapsed,
                  child: IgnorePointer(
                    ignoring: collapsed,
                    child: Opacity(
                      opacity: collapsed ? 0 : 1,
                      child: SizedBox(
                        width: collapsed ? 0 : 65,
                        height: SimChipChrome.height,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            maxWidth: 65,
                            child: Row(
                              spacing: 1,
                              children: <Widget>[
                                Parity(
                                  'shell.sidebar.header.search',
                                  child: SidebarTooltip(
                                    label: 'Search',
                                    shortcut: mac ? '⌘K' : 'Ctrl+K',
                                    enabled: !collapsed,
                                    // `search.trigger.chip` is the palette
                                    // spec's id for the same chip.
                                    child: const Parity(
                                      'search.trigger.chip',
                                      child: SidebarIconChip(
                                        icon: SimEmcnIcons.search,
                                        semanticsLabel: 'Search',
                                        onPressed: openSearchPalette,
                                      ),
                                    ),
                                  ),
                                ),
                                Parity(
                                  'shell.sidebar.header.collapse',
                                  child: SidebarTooltip(
                                    label: 'Collapse sidebar',
                                    shortcut: mac ? '⌘B' : 'Ctrl+B',
                                    enabled: !collapsed,
                                    child: SidebarIconChip(
                                      icon: SimEmcnIcons.panelLeft,
                                      semanticsLabel: 'Collapse sidebar',
                                      onPressed: toggle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = services;
    return ListenableBuilder(
      listenable: s.navigator.changes,
      builder: (context, _) =>
          BlocBuilder<FeatureFlagsCubit, FeatureFlagsState>(
            bloc: s.featureFlags,
            builder: (context, flags) =>
                BlocBuilder<PermissionsCubit, PermissionsState>(
                  bloc: s.permissions,
                  builder: (context, permissions) =>
                      BlocBuilder<DeploymentShapeCubit, DeploymentShapeState>(
                        bloc: s.deploymentShape,
                        builder: (context, deployment) =>
                            ValueListenableBuilder<ShellPermissionConfig>(
                              valueListenable: s.permissionConfigs.of(
                                widget.workspaceId,
                              ),
                              builder: (context, config, _) => _buildBody(
                                context,
                                flags,
                                permissions,
                                deployment,
                                config,
                              ),
                            ),
                      ),
                ),
          ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    FeatureFlagsState flags,
    PermissionsState permissions,
    DeploymentShapeState deployment,
    ShellPermissionConfig permissionConfig,
  ) {
    final s = services;
    final c = SimTheme.of(context).colors;
    final collapsed = widget.collapsed;
    final pathname = s.navigator.location;
    final user = permissions.userPermissions;
    final chatEnabled = deployment.shape.chatEnabled;
    final gating = NavGating(
      workspaceId: widget.workspaceId,
      chatEnabled: chatEnabled,
      canEdit: user.canEdit,
      permissionsLoading: permissions.permissionsLoading,
      dashboardsEnabled: flags.flag('dashboards'),
      changelogEnabled: flags.flag('changelog'),
      testsEnabled: flags.flag('workflow-tests'),
      permissionConfig: permissionConfig,
      accessRequestsEnabled: s.accessRequestsEnabled,
    );
    final top = topNavItems(gating);
    final showChats = chatEnabled && !permissionConfig.hideCopilot;
    final hosted = deployment.shape.hosted;
    final preview = deployment.env.statusNoticePreview;

    // The 16px `mt-4` sits outside the identified box (React measures the
    // nav element without its margin).
    final nav = Padding(
      padding: const EdgeInsets.only(top: SimLayout.sidebarSectionGap),
      child: Parity(
        'shell.sidebar.nav',
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _edges.start ? c.border : const Color(0x00000000),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: SimLayout.sidebarItemGap,
            children: <Widget>[
              for (final item in top)
                SidebarNavRow(
                  item: item,
                  active: isNavItemActive(item, pathname),
                  collapsed: collapsed,
                  services: s,
                  onAction: ops.createWorkflow,
                ),
            ],
          ),
        ),
      ),
    );

    final scroll = Expanded(
      child: Parity(
        'shell.sidebar.scroll',
        child: KeyedSubtree(
          key: _viewportKey,
          child: SimScrollFade(
            onEdgesChanged: (edges) {
              if (edges != _edges) setState(() => _edges = edges);
            },
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (showChats)
                    ChatsSection(
                      workspaceId: widget.workspaceId,
                      collapsed: collapsed,
                      pathname: pathname,
                      services: s,
                      canEdit: user.canEdit,
                    ),
                  WorkspaceNavSection(
                    workspaceId: widget.workspaceId,
                    items: workspaceNavItems(gating),
                    pathname: pathname,
                    collapsed: collapsed,
                    services: s,
                  ),
                  WorkflowsSection(
                    workspaceId: widget.workspaceId,
                    collapsed: collapsed,
                    services: s,
                    operations: ops,
                    canEdit: user.canEdit,
                    canAdmin: user.canAdmin,
                    permissionsLoading: permissions.permissionsLoading,
                    scrollController: _scroll,
                    scrollViewportKey: _viewportKey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final aside = ColoredBox(
      color: c.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _header(context),
          nav,
          scroll,
          if ((hosted || preview) && !collapsed)
            StatusNotice(services: s, preview: preview),
          SidebarFooter(
            workspaceId: widget.workspaceId,
            collapsed: collapsed,
            showDivider: _edges.end,
            services: s,
            onContactSupport: _openHelp,
          ),
        ],
      ),
    );

    return SuppressBrowserContextMenu(
      child: RegisterGlobalCommands(
        commands: <GlobalCommand>[
          createCommand(CommandId.addWorkflow, () {
            final canEdit = s.permissions.state.userPermissions.canEdit;
            if (canEdit && !ops.isCreatingWorkflow.value) {
              ops.createWorkflow();
            }
          }),
        ],
        child: Parity(
          'shell.sidebar',
          child: Semantics(
            label: 'Workspace sidebar',
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _onBackgroundTap,
              child: ClipRect(child: aside),
            ),
          ),
        ),
      ),
    );
  }
}
