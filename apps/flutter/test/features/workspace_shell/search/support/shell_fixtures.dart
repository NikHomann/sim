// Real data cubits over mocked repositories for the palette and switcher
// widget tests, plus a pump helper (Material app + overlay host).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_design/sim_design.dart';

import '../../../../data/support/mocks.dart';

export '../../../../data/support/mocks.dart';

/// A workspace row with explicit role facts.
Workspace ws(
  String id, {
  String? name,
  WorkspacePermission? permissions = WorkspacePermission.admin,
  String ownerId = userId,
  bool isOrgAdmin = false,
  String? inviteDisabledReason,
}) => Workspace(
  id: id,
  name: name ?? 'Workspace $id',
  ownerId: ownerId,
  organizationId: null,
  workspaceMode: WorkspaceMode.personal,
  permissions: permissions,
  isOrgAdmin: isOrgAdmin,
  inviteMembersEnabled: true,
  inviteDisabledReason: inviteDisabledReason,
);

/// The cubits the palette and the switcher read, wired to mocks.
class ShellFixture {
  ShellFixture({
    List<Workspace>? workspaces,
    List<String> pinned = const [],
    WorkspaceCreationPolicy? policy,
    this.viewer = WorkspacePermission.admin,
    bool chatEnabled = true,
    bool billingEnabled = false,
    List<WorkflowListItem> workflows = const [],
    List<Folder> folders = const [],
    List<InvitationDetails> invitations = const [],
    bool signedIn = true,
    PinnedItemsRepository? pinnedItems,
  }) : pinnedItems = pinnedItems ?? MockPinnedItemsRepository(),
       serverList = WorkspaceList(
         workspaces: workspaces ?? [ws(workspaceId, name: 'Acme')],
         lastActiveWorkspaceId: workspaceId,
         pinnedWorkspaceIds: pinned,
         creationPolicy: policy,
       ) {
    registerFallbackValue(<PermissionUpdate>[]);
    when(
      () => workspacesRepo.list(cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async {
      listCalls++;
      return serverList;
    });
    when(
      () => workspacesRepo.recordVisit(
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((invocation) async {
      visits.add(invocation.positionalArguments.first as String);
    });
    when(
      () => workspacesRepo.permissions(
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => WorkspacePermissions(
        users: const [],
        total: 1,
        viewer: PermissionsViewer(
          userId: userId,
          isAdmin: viewer == WorkspacePermission.admin,
          permissionType: viewer,
        ),
      ),
    );
    when(
      () => workflowsRepo.list(
        workspaceId: any(named: 'workspaceId'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => workflows);
    when(
      () => foldersRepo.list(
        workspaceId: any(named: 'workspaceId'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => folders);
    when(
      () => invitationsRepo.listMine(cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => invitations);
    deploymentShape.seed(
      DeploymentShape(chatEnabled: chatEnabled, billingEnabled: billingEnabled),
    );
    if (signedIn) session.setSession(sessionFixture());
  }

  final WorkspacePermission viewer;
  WorkspaceList serverList;
  int listCalls = 0;
  final List<String> visits = [];

  final queryClient = QueryClient();
  final workspacesRepo = MockWorkspacesRepository();
  final PinnedItemsRepository pinnedItems;
  MockPinnedItemsRepository get pinsRepo =>
      pinnedItems as MockPinnedItemsRepository;
  final invitationsRepo = MockInvitationsRepository();
  final workflowsRepo = MockWorkflowsRepository();
  final foldersRepo = MockFoldersRepository();
  final authRepo = MockAuthRepository();
  final runtimeRepo = MockRuntimeConfigRepository();

  late final workspaces = WorkspacesCubit(
    workspaces: workspacesRepo,
    pinnedItems: pinnedItems,
    invitations: invitationsRepo,
    queryClient: queryClient,
  );
  late final workflows = WorkflowsCubit(
    workflows: workflowsRepo,
    queryClient: queryClient,
  );
  late final folders = FoldersCubit(
    folders: foldersRepo,
    queryClient: queryClient,
  );
  late final permissions = PermissionsCubit(
    workspaces: workspacesRepo,
    queryClient: queryClient,
  );
  late final invitationsCubit = InvitationsCubit(
    invitations: invitationsRepo,
    workspaces: workspacesRepo,
    queryClient: queryClient,
  );
  late final session = SessionCubit(auth: authRepo, queryClient: queryClient);
  late final deploymentShape = DeploymentShapeCubit(
    runtimeConfig: runtimeRepo,
    queryClient: queryClient,
  );

  /// Loads every list once.
  Future<void> load() async {
    await workspaces.load();
    await workflows.load(workspaceId);
    await folders.load(workspaceId);
    await permissions.load(workspaceId);
  }

  Future<void> dispose() async {
    await workspaces.close();
    await workflows.close();
    await folders.close();
    await permissions.close();
    await invitationsCubit.close();
    await session.close();
    await deploymentShape.close();
  }
}

AuthSession sessionFixture() => const AuthSession(
  user: AuthUser(id: userId, email: 'flutter-e2e@example.com'),
);

/// The parity-capture viewport.
const Size shellViewport = Size(1440, 900);

/// Mounts [child] the way the app does: theme, overlay host, 1440×900.
Future<void> pumpShell(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  Size size = shellViewport,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? simDarkTheme() : simLightTheme(),
      builder: (context, page) =>
          SimOverlayHost(child: page ?? const SizedBox.shrink()),
      home: ColoredBox(
        color: dark ? SimColors.dark.surface1 : SimColors.light.surface1,
        child: child,
      ),
    ),
  );
}

/// Finds the [Semantics] widget carrying a parity id.
Finder byParityId(String identifier) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == identifier,
  description: 'parity id $identifier',
);
