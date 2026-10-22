// Mocked repositories and wire-shaped fixtures for the data-layer cubit
// tests. Fixtures mirror the seeded docker stack's bodies.

import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRuntimeConfigRepository extends Mock
    implements RuntimeConfigRepository {}

class MockWorkspacesRepository extends Mock implements WorkspacesRepository {}

class MockFoldersRepository extends Mock implements FoldersRepository {}

class MockWorkflowsRepository extends Mock implements WorkflowsRepository {}

class MockInvitationsRepository extends Mock implements InvitationsRepository {}

class MockPinnedItemsRepository extends Mock implements PinnedItemsRepository {}

class MockUsersRepository extends Mock implements UsersRepository {}

class MockOrganizationsRepository extends Mock
    implements OrganizationsRepository {}

class MockBlocksRepository extends Mock implements BlocksRepository {}

class MockRealtimeTransport extends Mock implements RealtimeTransport {}

const workspaceId = '44098e20-360c-53b2-adb0-efed21a7919c';
const otherWorkspaceId = '8a0a7d5c-1111-4111-8111-111111111111';
const userId = '74ec8a68-36ee-5159-a49a-3fb9d373ba32';

Workspace workspace({
  String id = workspaceId,
  String name = 'Flutter E2E workspace',
}) => Workspace(
  id: id,
  name: name,
  ownerId: userId,
  organizationId: null,
  workspaceMode: WorkspaceMode.grandfatheredShared,
  permissions: WorkspacePermission.admin,
  inviteMembersEnabled: true,
);

WorkspaceList workspaceList({
  List<Workspace>? workspaces,
  String? lastActiveWorkspaceId = workspaceId,
  List<String> pinned = const [],
}) => WorkspaceList(
  workspaces:
      workspaces ??
      [workspace(), workspace(id: otherWorkspaceId, name: 'Other')],
  lastActiveWorkspaceId: lastActiveWorkspaceId,
  pinnedWorkspaceIds: pinned,
  creationPolicy: const WorkspaceCreationPolicy(
    canCreate: true,
    workspaceMode: WorkspaceMode.personal,
    organizationId: null,
    maxWorkspaces: null,
    currentWorkspaceCount: 2,
    reason: null,
  ),
);

WorkflowListItem workflow({
  required String id,
  String name = 'Workflow',
  String? folderId,
  num sortOrder = 0,
  String createdAt = '2026-10-21T09:48:13.097Z',
  String? inWorkspace,
}) => WorkflowListItem(
  id: id,
  name: name,
  description: '',
  workspaceId: inWorkspace ?? workspaceId,
  folderId: folderId,
  sortOrder: sortOrder,
  createdAt: createdAt,
  updatedAt: createdAt,
  archivedAt: null,
  locked: false,
);

Folder folder({
  required String id,
  String name = 'Folder',
  String? parentId,
  num sortOrder = 0,
}) => Folder(
  id: id,
  resourceType: FolderResourceType.workflow,
  name: name,
  userId: userId,
  workspaceId: workspaceId,
  parentId: parentId,
  locked: false,
  sortOrder: sortOrder,
  createdAt: '2026-10-21T09:48:13.097Z',
  updatedAt: '2026-10-21T09:48:13.097Z',
  deletedAt: null,
);

PinnedItem pinnedItem(PinnedResourceType type, String resourceId) => PinnedItem(
  id: 'pin-$resourceId',
  userId: userId,
  workspaceId: workspaceId,
  resourceType: type,
  resourceId: resourceId,
  pinnedAt: '2026-10-21T09:48:13.097Z',
);

AuthSession session({String? impersonatedBy, String role = 'user'}) =>
    AuthSession(
      user: AuthUser(id: userId, email: 'flutter-e2e@example.com', role: role),
      session: SessionInfo(
        id: 's1',
        userId: userId,
        impersonatedBy: impersonatedBy,
      ),
    );

WorkspaceHostContext hostContext({
  DeploymentShape? deployment = const DeploymentShape(),
  String? hostOrganizationId,
  bool isMember = false,
}) => WorkspaceHostContext(
  workspace: const HostWorkspace(
    id: workspaceId,
    name: 'Flutter E2E workspace',
    workspaceMode: WorkspaceMode.grandfatheredShared,
    billedAccountUserId: userId,
  ),
  hostOrganizationId: hostOrganizationId,
  ownerBilling: const OwnerBilling(
    plan: 'free',
    status: null,
    isPaid: false,
    isPro: false,
    isTeam: false,
    isEnterprise: false,
    isOrgScoped: false,
    organizationId: null,
    billingInterval: 'month',
    billingBlocked: false,
    billingBlockedReason: null,
  ),
  viewer: HostViewer(
    permission: WorkspacePermission.admin,
    isHostOrganizationMember: isMember,
    isHostOrganizationAdmin: false,
  ),
  deployment: deployment,
);

WorkspacePermissions permissions({
  WorkspacePermission? viewer,
  List<WorkspaceUser> users = const [],
}) => WorkspacePermissions(
  users: users,
  total: users.length,
  viewer: viewer == null
      ? null
      : PermissionsViewer(
          userId: userId,
          isAdmin: viewer == WorkspacePermission.admin,
          permissionType: viewer,
        ),
);

WorkspaceUser workspaceUser(String email, WorkspacePermission permission) =>
    WorkspaceUser(
      userId: 'u-$email',
      email: email,
      name: null,
      image: null,
      permissionType: permission,
      isExternal: false,
      joinedAt: '2026-10-21T09:48:13.097Z',
      roleSource: 'explicit',
      isOrgAdmin: false,
      isBilledAccount: false,
    );

ApiClientError apiError(int status, [String message = 'failed']) =>
    ApiClientError(status: status, message: message, body: {'error': message});
