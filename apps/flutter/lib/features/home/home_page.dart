import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/home/access/permission_access_boundary.dart';
import 'package:sim_app/features/home/conversation/conversation_view.dart';
import 'package:sim_app/features/home/hero/credits_chip.dart';
import 'package:sim_app/features/home/hero/hero_layout.dart';
import 'package:sim_app/features/home/hero/suggested_actions.dart';
import 'package:sim_app/features/home/home_services.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/panel/add_resource_menu.dart';
import 'package:sim_app/features/home/panel/chat_panel_layout.dart';
import 'package:sim_app/features/home/panel/panel_geometry.dart';
import 'package:sim_app/features/home/panel/resource_content.dart';
import 'package:sim_app/features/home/panel/resource_inventory.dart';
import 'package:sim_app/features/home/panel/resource_panel_controller.dart';
import 'package:sim_app/features/home/panel/resource_tabs.dart';
import 'package:sim_app/features/home/shared/home_states.dart';
import 'package:sim_app/features/home/slots.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_navigation_guard.dart';
import 'package:sim_design/sim_design.dart';

/// `/workspace/{id}/chat/{chatId}[?resource=]` (`chat-url.ts`): only the
/// `resource` param is carried.
String homeChatUrl(String workspaceId, String chatId, {String? resource}) {
  final base = '/workspace/$workspaceId/chat/$chatId';
  return resource == null
      ? base
      : Uri(
          path: base,
          queryParameters: <String, String>{
            'resource': resource,
          },
        ).toString();
}

/// `/workspace/{id}/home[?resource=]`.
String homeUrl(String workspaceId, {String? resource}) {
  final base = '/workspace/$workspaceId/home';
  return resource == null
      ? base
      : Uri(
          path: base,
          queryParameters: <String, String>{
            'resource': resource,
          },
        ).toString();
}

/// The document title (`metadata.title` + the whitelabel template
/// `%s | {brand}`): "New chat | Sim" on `/home`, "Chat | Sim" on a chat.
String homeDocumentTitle({required bool chatRoute, String brand = 'Sim'}) =>
    '${chatRoute ? 'Chat' : 'New chat'} | $brand';

/// The page of `/workspace/:id/home` and `/workspace/:id/chat/:chatId`
/// (`home/page.tsx`, `chat/[chatId]/page.tsx` and their layouts): the
/// route frame (`home.page`), the document title, the chat-disabled 404 of
/// the chat route (`/home` redirects in the router), and the mount that
/// survives the new chat's in-place URL rewrite.
class HomeRoutePage extends StatelessWidget {
  const HomeRoutePage({
    required this.workspaceId,
    super.key,
    this.chatId,
    this.initialResource,
  });

  final String workspaceId;

  /// The routed chat; null on `/home`.
  final String? chatId;

  /// `?resource=` at mount.
  final String? initialResource;

  bool get _chatRoute => chatId != null;

  @override
  Widget build(BuildContext context) {
    final services = HomeServices.of(context);
    final c = SimTheme.of(context).colors;
    final brand = locator.isRegistered<BrandingCubit>()
        ? locator<BrandingCubit>().state.brand.name
        : 'Sim';
    final page = Semantics(
      identifier: 'home.page',
      container: true,
      child: ColoredBox(
        color: c.bg,
        child: HomeSurfaceHost(
          workspaceId: workspaceId,
          chatId: chatId,
          initialResource: initialResource,
        ),
      ),
    );
    // One tree shape for both routes, so the in-place move from `/home`
    // to `/chat/<id>` keeps the mount. `chat/[chatId]/layout.tsx:5`: chat
    // disabled → 404 (the `/home` redirect lives in the router).
    final body = BlocBuilder<DeploymentShapeCubit, DeploymentShapeState>(
      bloc: services.deploymentShape,
      builder: (context, state) {
        if (!_chatRoute) return page;
        final known =
            state.seeded != null || state.isReady || state.publicEnv.hasError;
        if (!known) return ColoredBox(color: c.bg);
        if (!state.shape.chatEnabled) {
          return HomeNotFound(workspaceId: workspaceId);
        }
        return page;
      },
    );
    return Title(
      title: homeDocumentTitle(chatRoute: _chatRoute, brand: brand),
      color: c.bg,
      child: body,
    );
  }
}

/// `WorkspaceNotFound` (`app/workspace/[workspaceId]/not-found.tsx`).
class HomeNotFound extends StatelessWidget {
  const HomeNotFound({required this.workspaceId, super.key});

  final String workspaceId;

  @override
  Widget build(BuildContext context) => HomeErrorShell(
    title: 'Page not found',
    description:
        "The page you're looking for doesn't exist or has been moved. Head "
        'back to your workspace to keep building.',
    icon: SimEmcnIcons.compass,
    parityId: 'home.not-found',
    actions: <Widget>[
      SimChip(
        label: 'Go back',
        leftIcon: SimEmcnIcons.arrowLeft,
        onPressed: () {
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          } else {
            ShellNavigator.of(context).go('/workspace/$workspaceId');
          }
        },
      ),
      SimChip(
        label: 'Return home',
        leftIcon: SimEmcnIcons.home,
        variant: SimChipVariant.primary,
        onPressed: () =>
            ShellNavigator.of(context).go('/workspace/$workspaceId'),
      ),
    ],
  );
}

/// Keeps one Home mount across the new chat's URL rewrite
/// (`/home` → `/chat/<id>` for the chat this mount created, like
/// `history.replaceState`), and remounts for any other chat (`<Home
/// key={chatId}>`) or workspace.
class HomeSurfaceHost extends StatefulWidget {
  const HomeSurfaceHost({
    required this.workspaceId,
    super.key,
    this.chatId,
    this.initialResource,
  });

  final String workspaceId;
  final String? chatId;
  final String? initialResource;

  @override
  State<HomeSurfaceHost> createState() => _HomeSurfaceHostState();
}

class _HomeSurfaceHostState extends State<HomeSurfaceHost> {
  int _generation = 0;
  String? _adoptedChatId;
  late String? _mountChatId = widget.chatId;
  late String? _mountResource = widget.initialResource;

  @override
  void didUpdateWidget(HomeSurfaceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final adopted =
        widget.chatId != null &&
        widget.chatId == _adoptedChatId &&
        widget.workspaceId == oldWidget.workspaceId;
    if (oldWidget.workspaceId != widget.workspaceId ||
        (oldWidget.chatId != widget.chatId && !adopted)) {
      _generation++;
      _adoptedChatId = null;
      _mountChatId = widget.chatId;
      _mountResource = widget.initialResource;
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = HomeServices.of(context);
    return KeyedSubtree(
      key: ValueKey<int>(_generation),
      child: PermissionAccessBoundary(
        workspaceId: widget.workspaceId,
        source: services.access,
        onViewRequest: (requestId) => ShellNavigator.of(context).go(
          Uri(
            path: '/workspace/${widget.workspaceId}/settings/requests',
            queryParameters: <String, String>{
              'view': 'requests',
              'requestId': requestId,
            },
          ).toString(),
        ),
        child: HomeContent(
          workspaceId: widget.workspaceId,
          chatId: _mountChatId,
          initialResource: _mountResource,
          onChatAdopted: (id) => _adoptedChatId = id,
        ),
      ),
    );
  }
}

/// The `md` breakpoint of `useIsMobile()` / `isMobileViewport()`.
const double compactLayoutBreakpoint = 768;

/// `HomeContent` (`home.tsx:72-506`): the chat session of this mount wired
/// to the hero or the conversation, and the resource panel.
class HomeContent extends StatefulWidget {
  const HomeContent({
    required this.workspaceId,
    super.key,
    this.chatId,
    this.initialResource,
    this.onChatAdopted,
  });

  final String workspaceId;

  /// The routed chat at mount (null for a new chat).
  final String? chatId;
  final String? initialResource;

  /// The session adopted a chat id (before the URL moves to it).
  final ValueChanged<String>? onChatAdopted;

  @override
  State<HomeContent> createState() => HomeContentState();
}

class HomeContentState extends State<HomeContent> {
  late final HomeServices _services = HomeServices.of(context);
  HomeChatSession? _session;
  Object? _sessionError;
  late final ResourcePanelController _panel;
  final HomeComposerController _heroComposer = HomeComposerController();
  final HomeComposerController _footerComposer = HomeComposerController();
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  final GlobalKey<ChatPanelLayoutState> _layoutKey =
      GlobalKey<ChatPanelLayoutState>();

  /// Before the chat exists its panel width lives under this scope
  /// (`pending:<id>`); adoption migrates it to the chat id.
  late final String _pendingScope =
      'pending:${math.Random().nextInt(1 << 30).toRadixString(36)}';
  HomeRequestMode _mode = HomeRequestMode.agent;
  bool _inputEntering = false;
  bool _wasSending = false;
  String? _readChatId;
  bool _readInitialised = false;
  double? _preferredWidth;
  String? _preferredFor;
  bool _initialised = false;

  /// The session of this mount (tests drive the placeholder through it).
  HomeChatSession? get session => _session;
  ResourcePanelController get panel => _panel;
  HomeRequestMode get requestMode => _mode;

  String? get _userId => _services.session.state.user?.id;

  String get _scope => _session?.chatId ?? widget.chatId ?? _pendingScope;

  @override
  void initState() {
    super.initState();
    _panel = ResourcePanelController(
      initialSelection: widget.initialResource,
      onSelectionChanged: _writeUrl,
      onAddResource: (resource) => _session?.addResource(resource),
    )..addListener(_rebuild);
  }

  /// `isCompactLayout || isMobileViewport()`: `width < 768`.
  bool _compactLayout = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final compact = MediaQuery.sizeOf(context).width < compactLayoutBreakpoint;
    if (compact != _compactLayout) {
      _compactLayout = compact;
      if (_initialised) _onSession();
    }
    if (_initialised) return;
    _initialised = true;
    final services = _services;
    _subscriptions
      ..add(services.flags.stream.listen((_) => _rebuild()))
      ..add(services.host.stream.listen((_) => _rebuild()))
      ..add(services.deploymentShape.stream.listen((_) => _rebuild()))
      ..add(services.session.stream.listen((_) => _rebuild()));
    // `prefetchHomeSurface`: the workspace file list, once.
    unawaited(
      services.inventory
          .workspaceFiles(widget.workspaceId)
          .then((_) {}, onError: (Object _) {}),
    );
    _openSession();
  }

  /// Opens this mount's session (again after "Try again").
  void _openSession() {
    try {
      _session = HomeSlots.of(context).session(
        HomeSessionRequest(
          workspaceId: widget.workspaceId,
          chatId: widget.chatId,
          callbacks: HomeSessionCallbacks(
            onChatResolved: _onChatResolved,
            onResourceEvent: _panel.handleResourceEvent,
            activeResourceId: () => _panel.selectedResourceId,
          ),
        ),
      )..addListener(_onSession);
      _onSession();
    } on Object catch (error) {
      _sessionError = error;
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _session
      ?..removeListener(_onSession)
      ..dispose();
    _panel
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  bool _rebuildScheduled = false;

  /// setState, deferred to after the frame when a notification arrives
  /// while the tree is building.
  void _rebuild() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      setState(() {});
      return;
    }
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _onSession() {
    final session = _session;
    if (session == null || !mounted) return;
    _panel.sync(
      chatId: session.chatId,
      resources: session.resources,
      compactLayout: _compactLayout,
    );
    _markRead(session);
    _rebuild();
  }

  /// `home.tsx:193-200`: mark read when the resolved chat changes and when
  /// a send finishes.
  void _markRead(HomeChatSession session) {
    final chatId = session.chatId;
    final markRead = _services.markRead;
    if (!_readInitialised || chatId != _readChatId) {
      _readInitialised = true;
      _readChatId = chatId;
      _wasSending = false;
      if (chatId != null && markRead != null) {
        unawaited(markRead(chatId).catchError((Object _) {}));
      }
    }
    if (_wasSending && !session.isSending && chatId != null) {
      if (markRead != null) {
        unawaited(markRead(chatId).catchError((Object _) {}));
      }
    }
    _wasSending = session.isSending;
  }

  void _onChatResolved(String chatId) {
    _services.widths.migrate(_pendingScope, chatId);
    widget.onChatAdopted?.call(chatId);
    _replaceUrl(
      homeChatUrl(
        widget.workspaceId,
        chatId,
        resource: _panel.selectedResourceId,
      ),
    );
  }

  /// `?resource=` follows the selection with replace semantics.
  void _writeUrl(String? resource) {
    final chatId = _session?.chatId ?? widget.chatId;
    _replaceUrl(
      chatId == null
          ? homeUrl(widget.workspaceId, resource: resource)
          : homeChatUrl(widget.workspaceId, chatId, resource: resource),
    );
  }

  String? _pendingUrl;

  /// Writes [location] after the current frame (the last write wins).
  void _replaceUrl(String location) {
    final scheduled = _pendingUrl != null;
    _pendingUrl = location;
    if (scheduled) return;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        final url = _pendingUrl;
        _pendingUrl = null;
        if (!mounted || url == null) return;
        final router = GoRouter.maybeOf(context);
        if (router == null) return;
        if (router.routeInformationProvider.value.uri.toString() == url) {
          return;
        }
        // `history.replaceState`: no new history entry, no remount.
        Router.neglect(context, () => router.go(url));
      })
      ..ensureVisualUpdate();
  }

  void _handleSubmit(HomeOutgoingMessage message) {
    final session = _session;
    if (session == null) return;
    final trimmed = message.text.trim();
    if (trimmed.isEmpty && message.attachments.isEmpty) return;
    if (session.messageCount == 0 && !_showSkeleton(session)) {
      setState(() => _inputEntering = true);
    }
    _panel.prepareForAgentTurn();
    session.sendMessage(
      HomeOutgoingMessage(
        text: trimmed.isEmpty ? 'Analyze the attached file(s).' : trimmed,
        attachments: message.attachments,
        contexts: message.contexts,
        payload: message.payload,
      ),
      requestMode: widget.chatId == null ? _mode : null,
    );
  }

  void _handleContextAdd(HomeChatContext context) {
    final resolved = context.resource;
    if (resolved == null) return;
    _panel.addFromUser(
      HomeResource(
        type: resolved.type,
        id: resolved.id,
        title: context.resourceTitle,
      ),
    );
  }

  void _handleInitialContextRemove(
    HomeChatContext removed,
    List<HomeChatContext> remaining,
  ) {
    final resolved = removed.resource;
    final session = _session;
    if (resolved == null || session == null) return;
    final stillReferenced = remaining.any((other) {
      final r = other.resource;
      return r != null && r.type == resolved.type && r.id == resolved.id;
    });
    if (stillReferenced) return;
    session.removeResource(
      HomeResource(
        type: resolved.type,
        id: resolved.id,
        title: removed.resourceTitle,
      ),
    );
  }

  /// `handleWorkspaceResourceSelect` (`home.tsx:368-401`).
  Future<void> openResourceRef(HomeResourceRef ref) async {
    if (ref.type != HomeResourceType.file) {
      final id = ref.id?.trim();
      if (id != null && id.isNotEmpty) {
        _panel.addFromUser(
          HomeResource(type: ref.type, id: id, title: ref.title),
        );
      }
      return;
    }
    final inventory = _services.inventory;
    HomeResource? resolve(List<InventoryItem> files) {
      for (final candidate in <String?>[ref.id, ref.path, ref.title]) {
        final value = candidate?.trim();
        if (value == null || value.isEmpty) continue;
        final match = _findFile(files, value);
        if (match != null) {
          return HomeResource(
            type: HomeResourceType.file,
            id: match.id,
            title: ref.title.isNotEmpty ? ref.title : match.name,
          );
        }
      }
      return null;
    }

    List<InventoryItem>? cached;
    try {
      cached = await inventory.workspaceFiles(widget.workspaceId);
    } on Object {
      cached = null;
    }
    final immediate = cached == null ? null : resolve(cached);
    if (immediate != null) {
      if (mounted) _panel.addFromUser(immediate);
      return;
    }
    List<InventoryItem>? files;
    try {
      files = await inventory.workspaceFiles(widget.workspaceId, force: true);
    } on Object {
      files = null;
    }
    if (!mounted) return;
    final resolved = files == null ? null : resolve(files);
    if (resolved != null) {
      _panel.addFromUser(resolved);
      return;
    }
    _services.toasts.error(
      files != null
          ? 'Couldn\'t find "${ref.title}" in this workspace'
          : 'Couldn\'t open "${ref.title}" — check your connection and try again',
    );
  }

  /// A file by id, by path, or by a name only one file has.
  static InventoryItem? _findFile(List<InventoryItem> files, String ref) {
    for (final f in files) {
      if (f.id == ref) return f;
    }
    final path = ref.startsWith('/') ? ref.substring(1) : ref;
    for (final f in files) {
      final own = f.path;
      if (own != null &&
          (own == ref || own == path || own.endsWith('/$path'))) {
        return f;
      }
    }
    InventoryItem? match;
    for (final f in files) {
      if (f.name != ref) continue;
      if (match != null) return null;
      match = f;
    }
    return match;
  }

  bool _showSkeleton(HomeChatSession session) =>
      widget.chatId != null &&
      session.messageCount == 0 &&
      session.isHistoryPending;

  /// The stored width, re-read when the user or the scope changes (keyed
  /// `'$userId:$scope'` like the store): a session that loads after the
  /// first build must not keep the no-user `null`.
  double? _preferred() {
    final scope = _scope;
    final userId = _userId;
    final key = '$userId:$scope';
    if (_preferredFor != key) {
      _preferredFor = key;
      _preferredWidth = _services.widths.preferred(userId, scope);
    }
    return _preferredWidth;
  }

  void _commitWidth(double width) {
    final preferred = math.max(panelMinWidth, width);
    setState(() => _preferredWidth = preferred);
    final userId = _userId;
    if (userId != null) _services.widths.setWidth(userId, _scope, preferred);
  }

  @override
  Widget build(BuildContext context) {
    final error = _sessionError;
    if (error != null) {
      return HomeErrorShell(
        title: widget.chatId == null
            ? 'Failed to load home'
            : 'Failed to load chat',
        description: widget.chatId == null
            ? 'Something went wrong while loading your workspace home. '
                  'Please try again.'
            : 'Something went wrong while loading this chat. Please try again.',
        parityId: 'home.error',
        actions: <Widget>[
          SimChip(
            label: 'Try again',
            variant: SimChipVariant.primary,
            onPressed: () => setState(() {
              _sessionError = null;
              _openSession();
            }),
          ),
        ],
      );
    }
    final session = _session;
    if (session == null) {
      return ColoredBox(color: SimTheme.of(context).colors.bg);
    }
    final slots = HomeSlots.of(context);
    final hasMessages = session.messageCount > 0;
    final showSkeleton = _showSkeleton(session);
    final showEmpty = !hasMessages && !showSkeleton;
    final chat = Semantics(
      identifier: 'home.chat-column',
      container: true,
      child: showEmpty
          ? _buildHero(context, session, slots)
          : _buildConversation(context, session, slots, showSkeleton),
    );
    return ChatPanelLayout(
      key: _layoutKey,
      collapsed: _panel.isCollapsed,
      skipTransition: _panel.skipTransition,
      activityCount: _panel.activityCount,
      preferredWidth: _preferred(),
      onToggle: _panel.toggle,
      onCommitWidth: _commitWidth,
      onResizeStart: _panel.claimSelection,
      onPanelInteraction: _panel.claimSelection,
      chat: chat,
      panel: _buildPanel(context, session),
    );
  }

  Widget _buildPanel(BuildContext context, HomeChatSession session) {
    final flags = _services.flags.state.flags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ResourceTabStrip(
          resources: session.resources,
          activeId: _panel.activeResourceId,
          chatId: session.chatId,
          activityIds: _panel.activityIds,
          onSelect: _panel.select,
          onClose: (targets) => targets.forEach(session.removeResource),
          onReorder: session.reorderResources,
          addControl: AddResourceControl(
            workspaceId: widget.workspaceId,
            inventory: _services.inventory,
            dashboardsEnabled: flags.dashboards,
            testsEnabled: flags.workflowTests,
            onAdd: _panel.addFromUser,
          ),
        ),
        Expanded(
          child: ResourceContentView(
            workspaceId: widget.workspaceId,
            resource: _panel.activeResource,
            session: session,
            folders: _services.folders,
            workflows: _services.workflows,
            onOpenWorkflow: (id) => ShellNavigator.of(
              context,
            ).go('/workspace/${widget.workspaceId}/w/$id'),
          ),
        ),
      ],
    );
  }

  String get _draftScopeKey =>
      '${widget.workspaceId}:${widget.chatId ?? 'new'}';

  Widget _buildHero(
    BuildContext context,
    HomeChatSession session,
    HomeSlots slots,
  ) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final viewport = MediaQuery.sizeOf(context);
    final name = _services.session.state.user?.name ?? '';
    final firstName = name.split(' ').first;
    final heading = Text(
      'What should we get done${firstName.isNotEmpty ? ', $firstName' : ''}?',
      textAlign: TextAlign.center,
      textWidthBasis: TextWidthBasis.longestLine,
      style: sim.text
          .pageHeading(viewportWidth: viewport.width)
          .copyWith(color: c.textPrimary),
    );
    final composer = slots.composer(
      context,
      HomeComposerProps(
        variant: HomeComposerVariant.hero,
        controller: _heroComposer,
        workspaceId: widget.workspaceId,
        draftScopeKey: _draftScopeKey,
        isSending: session.isSending,
        onSubmit: _handleSubmit,
        onStop: () => unawaited(session.stopGeneration().catchError((_) {})),
        requestMode: widget.chatId == null ? _mode : null,
        onRequestModeChanged: widget.chatId == null
            ? (mode) => setState(() => _mode = mode)
            : null,
        onContextAdd: _handleContextAdd,
        onContextRemove: _handleInitialContextRemove,
      ),
    );
    final host = _services.host.state;
    final hostContext = host.workspaceId == widget.workspaceId
        ? host.context
        : null;
    return Semantics(
      identifier: 'home.empty',
      container: true,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Semantics(
              identifier: 'home.empty.scroll',
              container: true,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: HeroClusterLayout(
                    minHeight: constraints.maxHeight,
                    paddingTop: viewport.height * 0.02,
                    paddingBottom: viewport.height * 0.22,
                    heading: Semantics(
                      identifier: 'home.hero.heading',
                      container: true,
                      child: heading,
                    ),
                    composer: composer,
                    suggested: SuggestedActions(
                      workspaceId: widget.workspaceId,
                      signals: _services.signals,
                      random: _services.random,
                      onSelectPrompt: _heroComposer.populatePrompt,
                      // `ConnectOAuthModal` is a later phase (known gap).
                      onSelectIntegration: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: _panel.skipTransition
                ? Duration.zero
                : SimMotion.of(panelDuration),
            curve: panelCurve,
            top: 0,
            height: ResourceHeaderGeometry.controlsHeight,
            right: _panel.isCollapsed
                ? ResourceHeaderGeometry.adjacentEnd
                : ResourceHeaderGeometry.endInset,
            child: Semantics(
              identifier: 'home.credits',
              container: true,
              child: Center(
                child: CreditsChip(
                  workspaceId: widget.workspaceId,
                  billingEnabled:
                      _services.deploymentShape.state.shape.billingEnabled,
                  host: hostContext,
                  userId: _userId,
                  source: _services.credits,
                  onUpgrade: () => ShellNavigator.of(context).go(
                    '/workspace/${widget.workspaceId}/upgrade?reason=credits',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversation(
    BuildContext context,
    HomeChatSession session,
    HomeSlots slots,
    bool loading,
  ) {
    final transcript = slots.transcript(
      context,
      HomeTranscriptProps(
        session: session,
        workspaceId: widget.workspaceId,
        onViewSources: (messageId, requestId) => _panel.addFromUser(
          HomeResource(
            type: HomeResourceType.sources,
            id: 'cited-sources',
            title: 'Sources',
            sourcesMessageId: messageId,
            sourcesRequestId: requestId,
          ),
        ),
        onResourceRef: (ref) => unawaited(openResourceRef(ref)),
        onContextAdd: _handleContextAdd,
      ),
    );
    final composer = slots.composer(
      context,
      HomeComposerProps(
        variant: HomeComposerVariant.conversation,
        controller: _footerComposer,
        workspaceId: widget.workspaceId,
        draftScopeKey: _draftScopeKey,
        isSending: session.isSending,
        onSubmit: _handleSubmit,
        onStop: () => unawaited(session.stopGeneration().catchError((_) {})),
        onContextAdd: _handleContextAdd,
        onSendQueuedHead: () {
          final head = session.queuedMessages.firstOrNull;
          if (head != null) unawaited(session.sendQueuedNow(head.id));
        },
        onEditQueuedTail: () {
          final tail = session.queuedMessages.lastOrNull;
          if (tail != null) _editQueued(session, tail.id);
        },
      ),
    );
    return ConversationView(
      session: session,
      transcript: transcript,
      composer: KeyedSubtree(
        key: ValueKey<String>(_draftScopeKey),
        child: composer,
      ),
      isLoading: loading,
      animateFooter: _inputEntering,
      onFooterAnimationEnd: () {
        if (mounted && _inputEntering) setState(() => _inputEntering = false);
      },
      onRemoveQueued: session.removeQueuedMessage,
      onSendQueuedNow: (id) =>
          unawaited(session.sendQueuedNow(id).catchError((_) {})),
      onEditQueued: (id) => _editQueued(session, id),
      onCancelQueueEdit: session.cancelQueueEdit,
    );
  }

  /// `handleEditQueued` (`mothership-chat.tsx:774-799`).
  void _editQueued(HomeChatSession session, String id) {
    final message = session.editQueuedMessage(id);
    if (message != null) _footerComposer.loadQueuedMessage(message);
  }
}
