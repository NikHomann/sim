// The sidebar test harness: real data cubits over mocktail repositories,
// an inert navigator, a private tree cubit and toast stack, and the pump
// helper that mounts WorkspaceSidebar the way the chrome does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/shared/permission_config.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/chat_models.dart';
import 'package:sim_app/features/workspace_shell/sidebar/seams.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_cubit.dart';
import 'package:sim_design/sim_design.dart';

import '../../../../data/support/mocks.dart';

export '../../../../data/support/mocks.dart'
    show
        MockFoldersRepository,
        MockWorkflowsRepository,
        otherWorkspaceId,
        userId,
        workspaceId;

class MockHelpRepository extends Mock implements HelpRepository {}

const String created = '2026-10-21T09:48:13.097Z';

WorkflowListItem wf(
  String id, {
  String? name,
  String? folderId,
  num sortOrder = 0,
  String createdAt = created,
  bool locked = false,
}) => WorkflowListItem(
  id: id,
  name: name ?? id,
  description: '',
  workspaceId: workspaceId,
  folderId: folderId,
  sortOrder: sortOrder,
  createdAt: createdAt,
  updatedAt: createdAt,
  archivedAt: null,
  locked: locked,
);

Folder fd(
  String id, {
  String? name,
  String? parentId,
  num sortOrder = 0,
  String createdAt = created,
  bool locked = false,
}) => Folder(
  id: id,
  resourceType: FolderResourceType.workflow,
  name: name ?? id,
  userId: userId,
  workspaceId: workspaceId,
  parentId: parentId,
  locked: locked,
  sortOrder: sortOrder,
  createdAt: createdAt,
  updatedAt: createdAt,
  deletedAt: null,
);

/// The seeded-like workspace: two root folders (one with a nested folder),
/// three workflows; "Empty workflow" is the open one.
List<Folder> seedFolders() => <Folder>[
  fd('f-e2e', name: 'E2E folder', sortOrder: 1),
  fd('f-ops', name: 'Ops', sortOrder: 3),
  fd('f-nested', name: 'Nested', parentId: 'f-e2e'),
];

List<WorkflowListItem> seedWorkflows() => <WorkflowListItem>[
  wf('w-empty', name: 'Empty workflow'),
  wf('w-bench', name: 'Benchmark 200 blocks', sortOrder: 2),
  wf('w-mixed', name: 'Mixed 20 blocks', folderId: 'f-e2e', sortOrder: 1),
];

class SidebarHarness {
  SidebarHarness() {
    WorkspaceSwitcherSlot.debugAllowStub = true;
    registerFallbackValue(ListScope.active);
    when(
      () => workflowsRepo.list(
        workspaceId: any(named: 'workspaceId'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => List.of(serverWorkflows));
    when(
      () => foldersRepo.list(
        workspaceId: any(named: 'workspaceId'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => List.of(serverFolders));
    when(
      () => workspacesRepo.permissions(
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => WorkspacePermissions(
        users: const <WorkspaceUser>[],
        total: 1,
        viewer: PermissionsViewer(
          userId: userId,
          isAdmin: permission == WorkspacePermission.admin,
          permissionType: permission,
        ),
      ),
    );
    when(
      () => runtime.featureFlags(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer(
      (_) async => FeatureFlagsLoaded(
        WorkspaceFeatureFlagsResponse(
          flags: flags,
          desktopExecutor: const DesktopExecutorStatus(),
        ),
      ),
    );
    when(
      () => workspacesRepo.list(
        scope: any(named: 'scope'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => workspaceList());
  }

  final MockWorkflowsRepository workflowsRepo = MockWorkflowsRepository();
  final MockFoldersRepository foldersRepo = MockFoldersRepository();
  final MockWorkspacesRepository workspacesRepo = MockWorkspacesRepository();
  final MockRuntimeConfigRepository runtime = MockRuntimeConfigRepository();
  final MockAuthRepository auth = MockAuthRepository();
  final MockHelpRepository help = MockHelpRepository();
  final QueryClient queryClient = QueryClient();
  final InertSidebarNavigator navigator = InertSidebarNavigator(
    '/workspace/$workspaceId/w/w-empty',
  );
  final SidebarTreeCubit tree = SidebarTreeCubit();
  final SimToasts toasts = SimToasts();
  final List<String> clipboard = <String>[];

  /// The Chats rows (empty unless a test seeds them).
  SidebarChatsSource? chats;
  int toggles = 0;

  List<WorkflowListItem> serverWorkflows = seedWorkflows();
  List<Folder> serverFolders = seedFolders();
  WorkspacePermission permission = WorkspacePermission.admin;
  WorkspaceFeatureFlags flags = const WorkspaceFeatureFlags();
  DeploymentShape shape = const DeploymentShape();

  late final WorkflowsCubit workflows = WorkflowsCubit(
    workflows: workflowsRepo,
    queryClient: queryClient,
    now: () => DateTime.utc(2026, 10, 22),
  );
  late final FoldersCubit folders = FoldersCubit(
    folders: foldersRepo,
    queryClient: queryClient,
    now: () => DateTime.utc(2026, 10, 22),
  );
  late final PermissionsCubit permissions = PermissionsCubit(
    workspaces: workspacesRepo,
    queryClient: queryClient,
  );
  late final FeatureFlagsCubit featureFlags = FeatureFlagsCubit(
    runtimeConfig: runtime,
    queryClient: queryClient,
  );
  late final DeploymentShapeCubit deployment = DeploymentShapeCubit(
    runtimeConfig: runtime,
    queryClient: queryClient,
  );
  late final SessionCubit session = SessionCubit(
    auth: auth,
    queryClient: queryClient,
  );
  late final WorkspacesCubit workspaces = WorkspacesCubit(
    workspaces: workspacesRepo,
    pinnedItems: MockPinnedItemsRepository(),
    invitations: MockInvitationsRepository(),
    queryClient: queryClient,
  );

  SidebarServices services({ShellPermissionConfig? permissionConfig}) =>
      SidebarServices(
        workflows: workflows,
        folders: folders,
        permissions: permissions,
        featureFlags: featureFlags,
        deploymentShape: deployment,
        session: session,
        workspaces: workspaces,
        help: help,
        foldersRepository: foldersRepo,
        navigator: navigator,
        onToggleCollapsed: () => toggles++,
        permissionConfigs: ShellPermissionConfigSource.fixed(
          permissionConfig ?? const ShellPermissionConfig(),
        ),
        tree: tree,
        toasts: toasts,
        isMac: false,
        clipboard: (text) async => clipboard.add(text),
        chats: chats,
      );

  /// Loads every cubit the sidebar reads.
  Future<void> load() async {
    deployment.seed(shape);
    session.setSession(
      const AuthSession(
        user: AuthUser(id: userId, email: 'e2e@sim.ai', name: 'Flutter E2E'),
      ),
    );
    await Future.wait<Object?>(<Future<Object?>>[
      workflows.load(workspaceId),
      folders.load(workspaceId),
      permissions.load(workspaceId),
      featureFlags.load(workspaceId),
      workspaces.load(),
    ]);
  }

  Future<void> dispose() async {
    await tree.close();
    await workflows.close();
    await folders.close();
    await permissions.close();
    await featureFlags.close();
    await deployment.close();
    await session.close();
    await workspaces.close();
  }
}

/// The app's theme + overlay host around [child].
Widget sidebarApp(Widget child, {bool dark = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark ? simDarkTheme() : simLightTheme(),
  builder: (context, inner) =>
      SimOverlayHost(child: inner ?? const SizedBox.shrink()),
  home: child,
);

/// Mounts the sidebar at [width] × 900 (the left edge of a 1440×900 page).
Future<void> pumpSidebar(
  WidgetTester tester,
  SidebarHarness h, {
  bool collapsed = false,
  double? width,
  bool dark = false,
  ShellPermissionConfig? permissionConfig,
  bool loaded = true,
  double height = 900,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (loaded) await tester.runAsync(h.load);
  await tester.pumpWidget(
    sidebarApp(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width ?? (collapsed ? 48 : 224),
          height: height,
          child: SidebarEnvironment(
            services: h.services(permissionConfig: permissionConfig),
            child: WorkspaceSidebar(
              workspaceId: workspaceId,
              collapsed: collapsed,
            ),
          ),
        ),
      ),
      dark: dark,
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Finds the widget carrying a parity id.
Finder byParity(String identifier) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == identifier,
  description: 'parity id $identifier',
);
