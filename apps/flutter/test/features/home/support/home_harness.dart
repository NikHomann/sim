// Harness for the Home page tests: the workspace shell harness (real data
// cubits over mocked repositories, stub sidebar) with the app's own route
// transform (withHomeRoutes), a recording fake HTTP for every request the
// Home surface issues, and the placeholder slots with every session the
// page opens captured.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/entry/entry_routes.dart';
import 'package:sim_app/features/home/access/permission_access_boundary.dart';
import 'package:sim_app/features/home/hero/credits_chip.dart';
import 'package:sim_app/features/home/hero/suggested_actions.dart';
import 'package:sim_app/features/home/home_http.dart';
import 'package:sim_app/features/home/home_routes.dart';
import 'package:sim_app/features/home/home_services.dart';
import 'package:sim_app/features/home/panel/panel_width_store.dart';
import 'package:sim_app/features/home/panel/resource_inventory.dart';
import 'package:sim_app/features/home/placeholder_slots.dart';
import 'package:sim_app/features/home/platform/local_storage.dart';
import 'package:sim_app/features/home/slots.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_dirty_store.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_navigation_guard.dart';
import 'package:sim_app/features/workspace_shell/routes.dart';
import 'package:sim_design/sim_design.dart';

import '../../workspace_shell/chrome/support/shell_harness.dart';

export '../../workspace_shell/chrome/support/shell_harness.dart';

const String homePath = '/workspace/$workspaceId/home';

/// `fixedId('copilot_chat')` of tools/seed: the seeded "E2E conversation".
const String seededChatId = 'b65b240b-1fbe-5ea9-bd3c-16a12311cbf6';
const String chatPath = '/workspace/$workspaceId/chat/$seededChatId';

/// One recorded request.
class RecordedRequest {
  RecordedRequest(this.method, this.path, this.query, this.body);

  final String method;
  final String path;
  final Map<String, Object?>? query;
  final Object? body;

  @override
  String toString() => '$method $path ${query ?? ''}';
}

/// [HomeHttp] answering from [handlers] (by exact path), recording every
/// request; an unknown path answers 404.
class FakeHomeHttp implements HomeHttp {
  final Map<String, FutureOr<Object?> Function(Map<String, Object?>? query)>
  handlers = <String, FutureOr<Object?> Function(Map<String, Object?>?)>{};
  final List<RecordedRequest> requests = <RecordedRequest>[];

  /// Paths of the recorded requests, in order.
  List<String> get paths => <String>[for (final r in requests) r.path];

  int count(String path) => requests.where((r) => r.path == path).length;

  void answer(String path, Object? json) => handlers[path] = (_) => json;

  @override
  Future<Object?> get(String path, {Map<String, Object?>? query}) async {
    requests.add(RecordedRequest('GET', path, query, null));
    final handler = handlers[path];
    if (handler == null) throw apiError(404, 'no handler for $path');
    return handler(query);
  }

  @override
  Future<Object?> post(String path, {Object? body}) async {
    requests.add(RecordedRequest('POST', path, null, body));
    final handler = handlers[path];
    if (handler == null) return <String, Object?>{'success': true};
    return handler(null);
  }
}

/// The Home harness: [shell] plus the Home services and slots.
class HomeHarness {
  final ShellHarness shell = ShellHarness();
  final FakeHomeHttp http = FakeHomeHttp();
  final MemoryHomeLocalStorage storage = MemoryHomeLocalStorage();
  final List<PlaceholderChatSession> sessions = <PlaceholderChatSession>[];
  final List<String> markedRead = <String>[];
  late ChatPanelWidthStore widths;
  late HomeServices services;
  late HomeSlots slots;
  HomeAccessSource? accessOverride;

  /// The props the transcript slot was last built with.
  HomeTranscriptProps? transcriptProps;
  bool chatEnabled = true;
  bool billingEnabled = false;

  /// The session the page opened last.
  PlaceholderChatSession get session => sessions.last;

  GoRouter get router => shell.router;

  Future<void> setUp() async {
    await shell.setUp();
    HomeServices.resetShared();
    http
      ..answer('/api/permission-groups/user', <String, Object?>{
        'config': <String, Object?>{},
      })
      ..answer('/api/access-requests/discovery', <String, Object?>{
        'enabled': false,
        'entries': <Object?>[],
      })
      ..answer('/api/credentials', <String, Object?>{
        'credentials': <Object?>[],
      })
      ..answer('/api/auth/oauth/connections', <String, Object?>{
        'connections': <Object?>[],
      })
      ..answer('/api/table', <String, Object?>{
        'data': <String, Object?>{'tables': <Object?>[]},
      })
      ..answer('/api/knowledge', <String, Object?>{'data': <Object?>[]})
      ..answer('/api/workspaces/$workspaceId/files', <String, Object?>{
        'success': true,
        'files': <Object?>[],
      })
      ..answer('/api/workspaces/$workspaceId/files/folders', <String, Object?>{
        'folders': <Object?>[],
      })
      ..answer('/api/folders', <String, Object?>{'folders': <Object?>[]})
      ..answer('/api/mothership/chats', <String, Object?>{'data': <Object?>[]})
      ..answer('/api/logs', <String, Object?>{'data': <Object?>[]})
      ..answer(
        '/api/workspaces/$workspaceId/credit-availability',
        <String, Object?>{'remainingDollars': 10, 'scope': 'payer'},
      );
    widths = ChatPanelWidthStore(storage: storage);
    stubDeployment();
  }

  /// Seeds the host context's deployment shape (chat / billing) and the
  /// public-env fallback that agrees with it.
  void stubDeployment({
    String? hostOrganizationId,
    bool isAdmin = false,
    bool enterprise = false,
  }) {
    when(
      () => shell.runtime.publicEnv(cancelToken: any(named: 'cancelToken')),
    ).thenAnswer(
      (_) async => PublicEnv(<String, String>{
        if (!chatEnabled) 'NEXT_PUBLIC_CHAT_DISABLED': 'true',
        if (billingEnabled) 'NEXT_PUBLIC_BILLING_ENABLED': 'true',
      }),
    );
    final billing = hostContext().ownerBilling;
    when(
      () => shell.runtime.hostContext(
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => WorkspaceAccess.granted(
        WorkspaceHostContext(
          workspace: const HostWorkspace(
            id: workspaceId,
            name: 'Flutter E2E workspace',
            workspaceMode: WorkspaceMode.grandfatheredShared,
            billedAccountUserId: userId,
          ),
          hostOrganizationId: hostOrganizationId,
          ownerBilling: enterprise
              ? OwnerBilling(
                  plan: 'enterprise',
                  status: 'active',
                  isPaid: true,
                  isPro: false,
                  isTeam: false,
                  isEnterprise: true,
                  isOrgScoped: billing.isOrgScoped,
                  organizationId: billing.organizationId,
                  billingInterval: billing.billingInterval,
                  billingBlocked: false,
                  billingBlockedReason: null,
                )
              : billing,
          viewer: HostViewer(
            permission: WorkspacePermission.admin,
            isHostOrganizationMember: hostOrganizationId != null,
            isHostOrganizationAdmin: isAdmin,
          ),
          deployment: DeploymentShape(
            chatEnabled: chatEnabled,
            billingEnabled: billingEnabled,
          ),
        ),
      ),
    );
  }

  /// The signed-in user carries [name].
  void signInAs(String? name) =>
      when(
        () => shell.auth.getSession(
          disableCookieCache: any(named: 'disableCookieCache'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => AuthSession(
          user: AuthUser(
            id: userId,
            email: 'flutter-e2e@example.com',
            name: name,
          ),
          session: const SessionInfo(id: 's1', userId: userId),
        ),
      );

  Future<void> tearDown() => shell.tearDown();

  void _buildServices() {
    services = HomeServices(
      session: shell.sessionCubit,
      host: shell.host,
      deploymentShape: shell.shape,
      flags: shell.flags,
      queries: shell.queries,
      http: http,
      workflows: locator<WorkflowsCubit>(),
      folders: locator<FoldersCubit>(),
      access: accessOverride ?? HttpHomeAccessSource(http),
      credits: HttpCreditAvailabilitySource(http: http, queries: shell.queries),
      signals: HttpSuggestionSignalsSource(http: http, queries: shell.queries),
      inventory: HttpResourceInventorySource(
        http: http,
        queries: shell.queries,
        workflows: locator<WorkflowsCubit>(),
        folders: locator<FoldersCubit>(),
        now: () => DateTime.utc(2026, 10, 22, 12),
      ),
      widths: widths,
      random: math.Random(7),
      markRead: (chatId) async => markedRead.add(chatId),
      toasts: shell.toasts,
    );
    slots = HomeSlots(
      session: (request) {
        final session = PlaceholderChatSession(request);
        sessions.add(session);
        return session;
      },
      transcript: (context, props) {
        transcriptProps = props;
        return buildPlaceholderTranscript(context, props);
      },
      composer: buildPlaceholderComposer,
    );
  }

  /// The router: entry routes + the shell routes with Home + a login stub.
  GoRouter buildRouter(String location) {
    final router = GoRouter(
      initialLocation: location,
      redirect: (context, state) =>
          appSurfaceRedirect(state.uri.path, shell.sessionCubit),
      routes: <RouteBase>[
        ...entryRoutes(),
        ...withHomeRoutes(workspaceShellRoutes()),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Center(child: Text('Login page')),
        ),
      ],
    );
    router.routerDelegate.addListener(() {
      final configuration = router.routerDelegate.currentConfiguration;
      if (configuration.isNotEmpty) {
        shell.visited.add(configuration.uri.toString());
      }
    });
    return router;
  }

  Widget app(String location, {ThemeMode themeMode = ThemeMode.light}) {
    _buildServices();
    shell.router = buildRouter(location);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: simLightTheme(),
      darkTheme: simDarkTheme(),
      themeMode: themeMode,
      routerConfig: shell.router,
      builder: (context, child) => HomeEnvironment(
        services: services,
        child: HomeSlotsScope(
          slots: slots,
          child: Material(
            type: MaterialType.transparency,
            child: SimOverlayHost(
              child: SettingsNavigationGuard(
                store: locator<SettingsDirtyStore>(),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    child ?? const SizedBox.shrink(),
                    SimToastStack(controller: shell.toasts),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester,
    String location, {
    Size size = shellViewport,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(location, themeMode: themeMode));
    await settle(tester);
  }

  /// The settled location (after redirects and in-place rewrites).
  String get location =>
      shell.router.routeInformationProvider.value.uri.toString();
}

/// Lets the async loaders answer and the frames settle (motion is off).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pumpAndSettle();
}

/// The rect of the [Semantics] node carrying [id].
Rect rectOf(WidgetTester tester, String id) =>
    tester.getRect(byParityId(id).first);
