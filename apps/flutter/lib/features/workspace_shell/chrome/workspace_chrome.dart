import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/auth/shared/platform/browser.dart';
import 'package:sim_app/features/chat/integration/chat_events_host.dart';
import 'package:sim_app/features/workspace_shell/chrome/application_loading.dart';
import 'package:sim_app/features/workspace_shell/chrome/fullscreen_origin.dart';
import 'package:sim_app/features/workspace_shell/chrome/permission_toasts.dart';
import 'package:sim_app/features/workspace_shell/chrome/search_palette_controller.dart';
import 'package:sim_app/features/workspace_shell/chrome/session_actions.dart';
import 'package:sim_app/features/workspace_shell/chrome/session_banners.dart';
import 'package:sim_app/features/workspace_shell/chrome/sidebar_controller.dart';
import 'package:sim_app/features/workspace_shell/chrome/sidebar_frame.dart';
import 'package:sim_app/features/workspace_shell/chrome/status_card.dart';
import 'package:sim_app/features/workspace_shell/search/search_palette.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/commands.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/global_commands.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_events.dart';
import 'package:sim_design/sim_design.dart';

/// Replaces the sidebar slot (tests of the chrome alone register a stub);
/// absent, the chrome mounts [WorkspaceSidebar].
typedef SidebarSlotBuilder =
    Widget Function(String workspaceId, {required bool collapsed});

final RegExp _workflowPath = RegExp('^/workspace/[^/]+/w/([^/]+)');
final RegExp _fileViewerPath = RegExp('^/workspace/[^/]+/files/[^/]+');

/// `app/workspace/[workspaceId]/layout.tsx` + `WorkspaceChrome`: the
/// provider/gate tree of one workspace mapped onto the data cubits, and the
/// frame those gates render.
///
/// Gates, in order: host context answered 403/404 → [WorkspaceAccessDenied]
/// in place of everything (feature flags never deny: a failed flags load
/// falls back to all flags off, like `FeatureFlagsProvider`); host context
/// not loaded
/// yet → [ApplicationLoading]; otherwise the viewport column: the
/// impersonation banner, the chrome row (sidebar + content pane) and the
/// session-expired takeover over all of it. The persistent connection
/// toasts, the `open-search` / `toggle-sidebar` / `goto-logs` commands and
/// the workspace loaders (host context, flags, permissions, workspace list
/// and visit, the sidebar's workflows and folders, settings, custom blocks,
/// block visibility, provider models, branding) live here too, all issued
/// together on entry.
class WorkspaceChrome extends StatefulWidget {
  const WorkspaceChrome({
    required this.workspaceId,
    required this.location,
    required this.child,
    super.key,
  });

  final String workspaceId;

  /// The current path (without `/app`), for route-scoped behaviour.
  final String location;
  final Widget child;

  @override
  State<WorkspaceChrome> createState() => _WorkspaceChromeState();
}

class _WorkspaceChromeState extends State<WorkspaceChrome> {
  late final SessionCubit _session = locator<SessionCubit>();
  late final WorkspaceHostCubit _host = locator<WorkspaceHostCubit>();
  late final FeatureFlagsCubit _flags = locator<FeatureFlagsCubit>();
  late final PermissionsCubit _permissions = locator<PermissionsCubit>();
  late final WorkspacesCubit _workspaces = locator<WorkspacesCubit>();
  late final SidebarController _sidebar = locator<SidebarController>();
  late final SearchPaletteController _palette =
      locator<SearchPaletteController>();
  late final GlobalCommandRegistry _commands = locator<GlobalCommandRegistry>();
  late final SessionActions _actions = locator<SessionActions>();
  late final SimToasts _toasts = locator<SimToasts>();
  late final FullscreenOriginStore _fullscreenOrigin =
      locator<FullscreenOriginStore>();

  T? _optional<T extends Object>() =>
      locator.isRegistered<T>() ? locator<T>() : null;

  late final BrandingCubit? _branding = _optional<BrandingCubit>();
  late final SettingsCubit? _settings = _optional<SettingsCubit>();
  late final ProviderModelsCubit? _providerModels =
      _optional<ProviderModelsCubit>();
  late final CustomBlocksCubit? _customBlocks = _optional<CustomBlocksCubit>();
  late final BlockVisibilityCubit? _blockVisibility =
      _optional<BlockVisibilityCubit>();
  late final WorkflowsCubit? _workflows = _optional<WorkflowsCubit>();
  late final FoldersCubit? _folders = _optional<FoldersCubit>();

  StreamSubscription<WorkspaceHostState>? _hostSubscription;
  StreamSubscription<SessionState>? _sessionSubscription;

  /// Once the shell has rendered, a workspace switch keeps it mounted while
  /// the next host context loads (the server layout swaps in one step).
  bool _shellShown = false;

  @override
  void initState() {
    super.initState();
    _palette.addListener(_onPaletteChanged);
    _hostSubscription = _host.stream.listen(_configureBranding);
    _sessionSubscription = _session.stream.listen(
      (s) => _permissions.setSessionEmail(s.user?.email),
    );
    unawaited(_session.load());
    _enterWorkspace(widget.workspaceId, switching: false);
    _onLocation(widget.location);
  }

  @override
  void didUpdateWidget(WorkspaceChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) {
      _enterWorkspace(widget.workspaceId, switching: true);
    }
    if (oldWidget.location != widget.location) _onLocation(widget.location);
  }

  @override
  void dispose() {
    _palette.removeListener(_onPaletteChanged);
    unawaited(_hostSubscription?.cancel());
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }

  /// The client-side half of the layout prefetch (`prefetch.ts:81-120`,
  /// `prefetch-access.ts`) and the providers' own queries, issued together.
  /// The sidebar's workflow and folder lists start here, in parallel with
  /// the host context, rather than when the sidebar mounts behind the host
  /// gate (one round trip later); the sidebar binds to the warm queries.
  void _enterWorkspace(String id, {required bool switching}) {
    if (switching) _blockVisibility?.resetForSwitch();
    _permissions.setSessionEmail(_session.state.user?.email);
    unawaited(_host.load(id).then((_) => _configureBranding(_host.state)));
    unawaited(_flags.load(id));
    unawaited(_permissions.load(id));
    unawaited(_workflows?.load(id));
    unawaited(_folders?.load(id));
    unawaited(_workspaces.load());
    _workspaces.setActiveWorkspace(id);
    unawaited(_settings?.load());
    unawaited(_customBlocks?.load(id));
    unawaited(_blockVisibility?.load(id));
    _providerModels?.setRoute(pathname: widget.location, workspaceId: id);
  }

  void _onLocation(String path) {
    final workflowMatch = _workflowPath.firstMatch(path);
    _permissions.setRoute(
      workflowId: workflowMatch?.group(1),
      isFileViewer: _fileViewerPath.hasMatch(path),
    );
    _providerModels?.setRoute(
      pathname: path,
      workspaceId: widget.workspaceId,
    );
    if (!isFullscreenPath(path)) _fullscreenOrigin.setOrigin(path);
  }

  void _onPaletteChanged() =>
      _providerModels?.setSearchModalOpen(open: _palette.isOpen);

  void _configureBranding(WorkspaceHostState state) {
    final context = state.context;
    if (context == null || state.workspaceId != widget.workspaceId) return;
    unawaited(
      _branding?.configure(
        hostOrganizationId: context.hostOrganizationId,
        isHostOrganizationMember: context.viewer.isHostOrganizationMember,
      ),
    );
  }

  void _refresh() {
    const window = BrowserWindow();
    if (window.origin != null) {
      window.reload();
    } else {
      unawaited(_permissions.refetch());
    }
  }

  List<GlobalCommand> get _chromeCommands => <GlobalCommand>[
    createCommand(CommandId.openSearch, _palette.toggle),
    createCommand(CommandId.toggleSidebar, _sidebar.toggleCollapsed),
    createCommand(
      CommandId.gotoLogs,
      () => GoRouter.of(context).go('/workspace/${widget.workspaceId}/logs'),
    ),
  ];

  /// Access is gated on the host context only, as in
  /// `app/workspace/[workspaceId]/layout.tsx` (host-context 403 →
  /// `WorkspaceAccessDenied`). A failed feature-flags load (e.g. a 404 from
  /// a server without the endpoint) must not deny access: flags fall back to
  /// their defaults (all off), like `FeatureFlagsProvider`'s defaults.
  bool _denied(WorkspaceHostState host) =>
      host.workspaceId == widget.workspaceId && host.accessDenied;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkspaceHostCubit, WorkspaceHostState>(
      bloc: _host,
      builder: (context, host) {
        if (_denied(host)) return const WorkspaceAccessDenied();
        final ready =
            host.workspaceId == widget.workspaceId &&
            (host.context != null || host.error != null);
        if (!ready && !_shellShown) return const ApplicationLoading();
        _shellShown = true;
        return _buildShell(context);
      },
    );
  }

  Widget _buildShell(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final fullscreen = isFullscreenPath(widget.location);
    Widget shell = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ImpersonationBanner(session: _session, actions: _actions),
        Expanded(
          child: Semantics(
            identifier: 'shell.chrome',
            container: true,
            child: ListenableBuilder(
              listenable: _sidebar,
              builder: (context, _) => SidebarFrame(
                controller: _sidebar,
                fullscreen: fullscreen,
                sidebar: locator.isRegistered<SidebarSlotBuilder>()
                    ? locator<SidebarSlotBuilder>()(
                        widget.workspaceId,
                        collapsed: _sidebar.isCollapsed,
                      )
                    : WorkspaceSidebar(
                        workspaceId: widget.workspaceId,
                        collapsed: _sidebar.isCollapsed,
                      ),
                content: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
    shell = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        shell,
        Positioned.fill(
          child: SessionExpiredTakeover(session: _session, actions: _actions),
        ),
      ],
    );
    shell = Semantics(
      identifier: 'shell.viewport',
      container: true,
      child: ColoredBox(color: c.surface1, child: shell),
    );
    final brand = _branding;
    if (brand != null) {
      // The builder must close over the frame built so far, never over the
      // reassigned `shell` variable: that would make the BlocBuilder return
      // itself and recurse until the stack overflows.
      final frame = shell;
      shell = BlocBuilder<BrandingCubit, BrandingState>(
        bloc: brand,
        builder: (context, state) {
          final name = state.brand.name;
          if (name == const BrandConfig().name) return frame;
          return Title(title: name, color: c.bg, child: frame);
        },
      );
    }
    // The workspace chat-status events (sidebar chat list, running dots,
    // stream recovery on resume) live as long as the workspace shell.
    return ChatEventsHost(
      workspaceId: widget.workspaceId,
      child: GlobalCommandsScope(
        registry: _commands,
        child: RegisterGlobalCommands(
          commands: _chromeCommands,
          child: PermissionToastsListener(
            permissions: _permissions,
            toasts: _toasts,
            onRefresh: _refresh,
            child: ListenableBuilder(
              listenable: _sidebar,
              child: shell,
              builder: (context, shell) => SearchPaletteLayer(
                controller: _palette,
                workspaceId: widget.workspaceId,
                pathname: widget.location,
                currentWorkflowId: _workflowPath
                    .firstMatch(widget.location)
                    ?.group(1),
                sidebarWidth: fullscreen
                    ? 0
                    : _sidebar.renderedWidth(MediaQuery.sizeOf(context).width),
                onInvokeCommand: _commands.invoke,
                // The sidebar registers `add-workflow` with its own create
                // flow (name, optimistic row, navigation).
                onCreateWorkflow: () =>
                    _commands.invoke(CommandId.addWorkflow.wireName),
                onOpenHelp: SidebarEvents.openHelpModal,
                onRevealWorkflow: SidebarEvents.scrollToItem,
                child: shell,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
