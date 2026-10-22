// The real app composition for the chat integration tests: the app's own
// locator wiring with only the repositories replaced by mocks answering
// like the seeded docker stack, as in
// `test/features/workspace_shell/integration/real_shell_test.dart`.

import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/config.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';

import '../../../../data/support/mocks.dart';
import '../../../workspace_shell/sidebar/support/harness.dart'
    show MockHelpRepository, seedFolders, seedWorkflows;

/// Replaces a lazily registered [T] (never instantiated yet) with [value].
Future<void> _override<T extends Object>(T value) async {
  if (locator.isRegistered<T>()) await locator.unregister<T>();
  locator.registerSingleton<T>(value);
}

/// The app's own locator wiring with the repositories mocked like the
/// seeded docker stack (copied from `real_shell_test.dart`).
Future<void> configureRealLocator() async {
  await configureLocator(
    const AppConfig(surface: AppSurface.web, backendOrigin: null, e2e: true),
  );
  registerFallbackValue(ListScope.active);
  registerFallbackValue(FolderScope.active);
  registerFallbackValue(FolderResourceType.workflow);
  registerFallbackValue(ProviderName.values.first);

  final auth = MockAuthRepository();
  when(
    () => auth.getSession(
      disableCookieCache: any(named: 'disableCookieCache'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => session());

  final runtime = MockRuntimeConfigRepository();
  when(
    () => runtime.hostContext(any(), cancelToken: any(named: 'cancelToken')),
  ).thenAnswer((_) async => WorkspaceAccess.granted(hostContext()));
  when(
    () => runtime.featureFlags(any(), cancelToken: any(named: 'cancelToken')),
  ).thenAnswer((_) async => FeatureFlagsDenied(apiError(404)));
  when(
    () => runtime.publicEnv(cancelToken: any(named: 'cancelToken')),
  ).thenThrow(apiError(404));

  final workspacesRepo = MockWorkspacesRepository();
  when(
    () => workspacesRepo.list(
      scope: any(named: 'scope'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => workspaceList(workspaces: [workspace()]));
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

  final workflowsRepo = MockWorkflowsRepository();
  when(
    () => workflowsRepo.list(
      workspaceId: any(named: 'workspaceId'),
      scope: any(named: 'scope'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => seedWorkflows());

  final foldersRepo = MockFoldersRepository();
  when(
    () => foldersRepo.list(
      workspaceId: any(named: 'workspaceId'),
      scope: any(named: 'scope'),
      resourceType: any(named: 'resourceType'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => seedFolders());

  final pinnedRepo = MockPinnedItemsRepository();
  when(
    () => pinnedRepo.list(
      workspaceId: any(named: 'workspaceId'),
      resourceType: any(named: 'resourceType'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => <PinnedItem>[]);

  final invitationsRepo = MockInvitationsRepository();
  when(
    () => invitationsRepo.listMine(cancelToken: any(named: 'cancelToken')),
  ).thenAnswer((_) async => <InvitationDetails>[]);

  final usersRepo = MockUsersRepository();
  when(
    () => usersRepo.settings(cancelToken: any(named: 'cancelToken')),
  ).thenAnswer((_) async => const UserSettings());

  final blocksRepo = MockBlocksRepository();
  when(
    () =>
        blocksRepo.customBlocks(any(), cancelToken: any(named: 'cancelToken')),
  ).thenAnswer(
    (_) async => const CustomBlocksResponse(enabled: false, customBlocks: []),
  );
  when(
    () => blocksRepo.visibility(any(), cancelToken: any(named: 'cancelToken')),
  ).thenAnswer((_) async => const BlockVisibility());
  when(
    () => blocksRepo.providerModels(
      any(),
      workspaceId: any(named: 'workspaceId'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => const ProviderModels(models: []));

  // No HTTP client on the VM (the web surface has no backend origin):
  // everything that would reach the network is a mocked repository, and
  // the shell's permission-config source falls back to its fixed form.
  await locator.unregister<SimHttpClient>();
  await _override<QueryClient>(QueryClient());
  await _override<KeyValueStore>(InMemoryKeyValueStore());
  await _override<SharedWebState>(MemorySharedWebState());
  await _override<AuthSessionStore>(MemoryAuthSessionStore());
  await _override<AuthRepository>(auth);
  await _override<RuntimeConfigRepository>(runtime);
  await _override<WorkspacesRepository>(workspacesRepo);
  await _override<WorkflowsRepository>(workflowsRepo);
  await _override<FoldersRepository>(foldersRepo);
  await _override<PinnedItemsRepository>(pinnedRepo);
  await _override<InvitationsRepository>(invitationsRepo);
  await _override<UsersRepository>(usersRepo);
  await _override<OrganizationsRepository>(MockOrganizationsRepository());
  await _override<BlocksRepository>(blocksRepo);
  await _override<HelpRepository>(MockHelpRepository());
}
