// Shared harness for the workspace shell, modal and entry tests: real data
// cubits over mocked repositories (the cubit states drive the UI exactly as
// in the app), the shell services in the locator, fake session actions and
// a GoRouter mounting the entry and workspace shell routes at 1440x900.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/entry/entry_routes.dart';
import 'package:sim_app/features/workspace_shell/chrome/session_actions.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_dirty_store.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_navigation_guard.dart';
import 'package:sim_app/features/workspace_shell/chrome/shell_services.dart';
import 'package:sim_app/features/workspace_shell/chrome/workspace_chrome.dart';
import 'package:sim_app/features/workspace_shell/routes.dart';
import 'package:sim_design/sim_design.dart';

import '../../../../data/support/mocks.dart';

export '../../../../data/support/mocks.dart';

const Size shellViewport = Size(1440, 900);

/// Records the session-ending calls.
class FakeSessionActionsLog {
  int signOuts = 0;
  int clears = 0;
  int stops = 0;
  bool preservedImpersonations = false;
  bool signOutFails = false;

  /// Holds the sign-out open until completed.
  Completer<void>? signOutGate;
  bool stopFails = false;
}

class ShellHarness {
  final MockAuthRepository auth = MockAuthRepository();
  final MockRuntimeConfigRepository runtime = MockRuntimeConfigRepository();
  final MockWorkspacesRepository workspacesRepo = MockWorkspacesRepository();
  final MockInvitationsRepository invitationsRepo = MockInvitationsRepository();
  final MockPinnedItemsRepository pinnedRepo = MockPinnedItemsRepository();
  final MockWorkflowsRepository workflowsRepo = MockWorkflowsRepository();
  final MockFoldersRepository foldersRepo = MockFoldersRepository();
  final MockOrganizationsRepository organizationsRepo =
      MockOrganizationsRepository();
  final MemorySharedWebState storage = MemorySharedWebState();
  final MemoryAuthSessionStore sessionStore = MemoryAuthSessionStore();
  final SimToasts toasts = SimToasts();
  final FakeSessionActionsLog actionsLog = FakeSessionActionsLog();
  final List<String> visited = <String>[];

  /// Every location navigated to (before redirects).
  final List<String> requested = <String>[];

  /// The query clock; advance it to make cached queries stale.
  DateTime now = DateTime(2026, 10, 22, 9);
  late QueryClient queries;
  late SessionCubit sessionCubit;
  late WorkspaceHostCubit host;
  late FeatureFlagsCubit flags;
  late PermissionsCubit permissionsCubit;
  late WorkspacesCubit workspaces;
  late DeploymentShapeCubit shape;
  late InvitationsCubit invitations;
  late GoRouter router;

  /// Registers everything with the default "signed in, admin, granted"
  /// stubs; tests override the stubs before pumping.
  Future<void> setUp() async {
    await locator.reset();
    registerFallbackValue(ListScope.active);
    registerFallbackValue(FolderScope.active);
    registerFallbackValue(FolderResourceType.workflow);
    queries = QueryClient(now: () => now);
    when(
      () => auth.getSession(
        disableCookieCache: any(named: 'disableCookieCache'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => session());
    when(
      () => runtime.hostContext(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => WorkspaceAccess.granted(hostContext()));
    when(
      () => runtime.featureFlags(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer(
      (_) async => const FeatureFlagsLoaded(
        WorkspaceFeatureFlagsResponse(
          flags: WorkspaceFeatureFlags(),
          desktopExecutor: DesktopExecutorStatus(),
        ),
      ),
    );
    when(
      () => runtime.publicEnv(cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => PublicEnv.empty);
    when(
      () => workspacesRepo.list(
        scope: any(named: 'scope'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => workspaceList());
    when(
      () => workspacesRepo.permissions(
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => permissions(viewer: WorkspacePermission.admin));
    when(
      () => workspacesRepo.recordVisit(
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => workflowsRepo.list(
        workspaceId: any(named: 'workspaceId'),
        scope: any(named: 'scope'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => <WorkflowListItem>[]);
    when(
      () => foldersRepo.list(
        workspaceId: any(named: 'workspaceId'),
        scope: any(named: 'scope'),
        resourceType: any(named: 'resourceType'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => <Folder>[]);

    sessionCubit = SessionCubit(auth: auth, queryClient: queries);
    shape = DeploymentShapeCubit(runtimeConfig: runtime, queryClient: queries);
    host = WorkspaceHostCubit(
      runtimeConfig: runtime,
      queryClient: queries,
      deploymentShape: shape,
    );
    flags = FeatureFlagsCubit(runtimeConfig: runtime, queryClient: queries);
    permissionsCubit = PermissionsCubit(
      workspaces: workspacesRepo,
      queryClient: queries,
    );
    workspaces = WorkspacesCubit(
      workspaces: workspacesRepo,
      pinnedItems: pinnedRepo,
      invitations: invitationsRepo,
      queryClient: queries,
    );
    invitations = InvitationsCubit(
      invitations: invitationsRepo,
      workspaces: workspacesRepo,
      queryClient: queries,
    );

    locator
      ..registerSingleton<QueryClient>(queries)
      ..registerSingleton<SharedWebState>(storage)
      ..registerSingleton<AuthSessionStore>(sessionStore)
      ..registerSingleton<WorkflowsRepository>(workflowsRepo)
      ..registerSingleton<OrganizationsRepository>(organizationsRepo)
      ..registerSingleton<SessionCubit>(sessionCubit)
      ..registerSingleton<DeploymentShapeCubit>(shape)
      ..registerSingleton<WorkspaceHostCubit>(host)
      ..registerSingleton<FeatureFlagsCubit>(flags)
      ..registerSingleton<PermissionsCubit>(permissionsCubit)
      ..registerSingleton<WorkspacesCubit>(workspaces)
      ..registerSingleton<InvitationsCubit>(invitations)
      ..registerSingleton<WorkflowsCubit>(
        WorkflowsCubit(workflows: workflowsRepo, queryClient: queries),
      )
      ..registerSingleton<FoldersCubit>(
        FoldersCubit(folders: foldersRepo, queryClient: queries),
      )
      ..registerSingleton<SimToasts>(toasts)
      ..registerSingleton<SessionActions>(
        SessionActions(
          signOut: () async {
            actionsLog.signOuts++;
            await actionsLog.signOutGate?.future;
            if (actionsLog.signOutFails) throw apiError(500);
          },
          clearUserData: ({preserveRecentImpersonations = false}) async {
            actionsLog.clears++;
            actionsLog.preservedImpersonations = preserveRecentImpersonations;
            return true;
          },
          stopImpersonating: () async {
            actionsLog.stops++;
            if (actionsLog.stopFails) throw apiError(500);
          },
        ),
      )
      ..registerSingleton<SidebarSlotBuilder>(
        (workspaceId, {required collapsed}) => const SizedBox.expand(),
      );
    registerWorkspaceShellServices();
  }

  Future<void> tearDown() async {
    toasts.dismissAll();
    await locator.reset();
  }

  /// Pumps the app shell (entry + workspace routes, a `/login` stub) at
  /// [location].
  Future<void> pump(
    WidgetTester tester,
    String location, {
    Size size = shellViewport,
    ThemeMode themeMode = ThemeMode.light,
    bool withRedirect = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(location, themeMode: themeMode, withRedirect: withRedirect),
    );
    await tester.pump();
    await tester.pump();
  }

  /// The app (router with the entry and workspace shell routes, a `/login`
  /// stub, overlay host, toast stack and dirty guard) starting at
  /// [location]; also used directly by the goldens.
  Widget app(
    String location, {
    ThemeMode themeMode = ThemeMode.light,
    bool withRedirect = true,
  }) {
    router = buildRouter(location, withRedirect: withRedirect);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: simLightTheme(),
      darkTheme: simDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => Material(
        type: MaterialType.transparency,
        child: SimOverlayHost(
          child: SettingsNavigationGuard(
            store: locator<SettingsDirtyStore>(),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                child ?? const SizedBox.shrink(),
                SimToastStack(controller: toasts),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The harness router: the entry and workspace shell routes and a
  /// `/login` stub behind the app-surface gate, recording every location
  /// the delegate settles on in [visited] and every request in [requested].
  GoRouter buildRouter(String location, {bool withRedirect = true}) {
    final router = GoRouter(
      initialLocation: location,
      redirect: withRedirect
          ? (context, state) => appSurfaceRedirect(state.uri.path, sessionCubit)
          : null,
      routes: <RouteBase>[
        ...entryRoutes(),
        ...workspaceShellRoutes(),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Center(child: Text('Login page')),
        ),
      ],
    );
    router.routerDelegate.addListener(() {
      final configuration = router.routerDelegate.currentConfiguration;
      if (configuration.isNotEmpty) visited.add(configuration.uri.toString());
    });
    router.routeInformationProvider.addListener(
      () => requested.add(
        router.routeInformationProvider.value.uri.toString(),
      ),
    );
    return router;
  }

  /// The current path of the router.
  String get location => router.routeInformationProvider.value.uri.toString();

  /// The location after redirects, as the router delegate holds it.
  String get settledLocation =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Finds the [Semantics] widget carrying a parity id.
Finder byParityId(String identifier) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == identifier,
  description: 'parity id $identifier',
);

/// Mounts [child] in a light Sim app with an overlay host (no router).
Future<void> pumpBare(
  WidgetTester tester,
  Widget child, {
  Size size = shellViewport,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: simLightTheme(),
      builder: (context, c) => SimOverlayHost(child: c ?? const SizedBox()),
      home: Scaffold(body: child),
    ),
  );
}
