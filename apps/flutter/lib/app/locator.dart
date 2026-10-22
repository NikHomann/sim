import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/config.dart';
import 'package:sim_app/app/platform/key_value_shared_state.dart';
import 'package:sim_app/app/platform/session_storage.dart';
import 'package:sim_app/app/platform/storage_path.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/entry/entry_support.dart';

/// GetIt service locator (OttoFrontend convention). Feature packages register
/// their singletons here through [configureLocator]; widgets read them with
/// `locator<T>()`.
final GetIt locator = GetIt.instance;

Future<void> configureLocator(AppConfig config) async {
  if (locator.isRegistered<AppConfig>()) {
    await locator.reset();
  }
  locator
    ..registerSingleton<AppConfig>(config)
    ..registerLazySingleton<SimHttpClient>(
      () => SimHttpClient.forPlatform(
        desktopOrigin: config.backendOrigin?.toString(),
      ),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepository(locator<SimHttpClient>()),
    )
    ..registerLazySingleton<QueryClient>(() => QueryClient.instance)
    ..registerLazySingleton<KeyValueStore>(
      () => createPlatformKeyValueStore(filePath: defaultStoragePath()),
    )
    // localStorage/cookies shared with React on web; the key-value store
    // elsewhere (`bootstrap` loads it before the first read).
    ..registerLazySingleton<SharedWebState>(
      () => kIsWeb
          ? createSharedWebState()
          : KeyValueSharedWebState(locator<KeyValueStore>()),
    );
  _registerRepositories();
  _registerDataCubits();
}

/// The Phase 1 repositories (`packages/sim_api/lib/src/repositories`).
void _registerRepositories() {
  SimHttpClient http() => locator<SimHttpClient>();
  locator
    ..registerLazySingleton<RuntimeConfigRepository>(
      () => RuntimeConfigRepository(http()),
    )
    ..registerLazySingleton<WorkspacesRepository>(
      () => WorkspacesRepository(http()),
    )
    ..registerLazySingleton<FoldersRepository>(() => FoldersRepository(http()))
    ..registerLazySingleton<WorkflowsRepository>(
      () => WorkflowsRepository(http()),
    )
    ..registerLazySingleton<InvitationsRepository>(
      () => InvitationsRepository(http()),
    )
    ..registerLazySingleton<PinnedItemsRepository>(
      () => PinnedItemsRepository(http()),
    )
    ..registerLazySingleton<UsersRepository>(() => UsersRepository(http()))
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepository(http()),
    )
    ..registerLazySingleton<OrganizationsRepository>(
      () => OrganizationsRepository(http()),
    )
    ..registerLazySingleton<BlocksRepository>(() => BlocksRepository(http()))
    ..registerLazySingleton<HelpRepository>(() => HelpRepository(http()))
    ..registerLazySingleton<RecentlyDeletedRepository>(
      () => RecentlyDeletedRepository(http()),
    );
}

/// The long-lived data cubits of spec §7, each registered with the
/// user-data reset registry so `resetUserData()` clears them on sign-out.
void _registerDataCubits() {
  final registry = UserDataResetRegistry();
  QueryClient queries() => locator<QueryClient>();

  T resettable<T>(T cubit, void Function(T) reset) {
    registry.register(() => reset(cubit));
    return cubit;
  }

  locator
    ..registerSingleton<UserDataResetRegistry>(registry)
    ..registerLazySingleton<SessionCubit>(
      () => resettable(
        SessionCubit(auth: locator<AuthRepository>(), queryClient: queries()),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<DeploymentShapeCubit>(
      () => resettable(
        DeploymentShapeCubit(
          runtimeConfig: locator<RuntimeConfigRepository>(),
          queryClient: queries(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<WorkspaceHostCubit>(
      () => resettable(
        WorkspaceHostCubit(
          runtimeConfig: locator<RuntimeConfigRepository>(),
          queryClient: queries(),
          deploymentShape: locator<DeploymentShapeCubit>(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<FeatureFlagsCubit>(
      () => resettable(
        FeatureFlagsCubit(
          runtimeConfig: locator<RuntimeConfigRepository>(),
          queryClient: queries(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<WorkspacesCubit>(
      () => resettable(
        WorkspacesCubit(
          workspaces: locator<WorkspacesRepository>(),
          pinnedItems: locator<PinnedItemsRepository>(),
          invitations: locator<InvitationsRepository>(),
          queryClient: queries(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<FoldersCubit>(
      () => resettable(
        FoldersCubit(
          folders: locator<FoldersRepository>(),
          queryClient: queries(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<WorkflowsCubit>(
      () => resettable(
        WorkflowsCubit(
          workflows: locator<WorkflowsRepository>(),
          queryClient: queries(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<PinnedItemsCubit>(
      () => resettable(
        PinnedItemsCubit(
          pinnedItems: locator<PinnedItemsRepository>(),
          queryClient: queries(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<PermissionsCubit>(
      () => resettable(
        PermissionsCubit(
          workspaces: locator<WorkspacesRepository>(),
          queryClient: queries(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<BrandingCubit>(
      () => resettable(
        BrandingCubit(
          organizations: locator<OrganizationsRepository>(),
          queryClient: queries(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<SettingsCubit>(
      () => resettable(
        SettingsCubit(
          users: locator<UsersRepository>(),
          queryClient: queries(),
          sharedState: locator<SharedWebState>(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<ProviderModelsCubit>(
      () => resettable(
        ProviderModelsCubit(
          blocks: locator<BlocksRepository>(),
          queryClient: queries(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<CustomBlocksCubit>(
      () => resettable(
        CustomBlocksCubit(
          blocks: locator<BlocksRepository>(),
          queryClient: queries(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<BlockVisibilityCubit>(
      () => resettable(
        BlockVisibilityCubit(
          blocks: locator<BlocksRepository>(),
          queryClient: queries(),
        ),
        (c) => c.reset(),
      ),
    )
    ..registerLazySingleton<InvitationsCubit>(
      () => resettable(
        InvitationsCubit(
          invitations: locator<InvitationsRepository>(),
          workspaces: locator<WorkspacesRepository>(),
          queryClient: queries(),
          refreshSession: () => locator<SessionCubit>().refresh(),
        ),
        (c) => c.reset(),
      ),
    );
}

/// `clearUserData()`: the store reset wired to the locator's singletons.
Future<bool> clearUserData({bool preserveRecentImpersonations = false}) =>
    resetUserData(
      store: locator<KeyValueStore>(),
      queryClient: locator<QueryClient>(),
      registry: locator<UserDataResetRegistry>(),
      preserveRecentImpersonations: preserveRecentImpersonations,
      clearCookies: () => locator<SimHttpClient>().clearCookies(),
      clearSessionStorage: () {
        clearBrowserSessionStorage();
        clearEntrySessionStore();
      },
    );
