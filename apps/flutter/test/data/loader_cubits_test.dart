// Failure modes of the loader cubits (spec §3.1, §4.2, §4.9, §7, §10 #24,
// #25, #68-72):
// DeploymentShapeCubit
// 1. without a seeded shape the public-env fallback is used; seeding an
//    equal shape emits nothing; a different one does; a 5xx on public env
//    is "failed to start";
// WorkspaceHostCubit
// 2. a granted context seeds the deployment shape; a 403 is accessDenied
//    with no seed; a workspace switch re-binds the key;
// FeatureFlagsCubit
// 3. every flag is false until loaded; 403 → accessDenied; 429 → retryAfter;
//    the organization surface maps plan-mode to benchmarkEnabled;
// BlockVisibilityCubit
// 4. the first empty projection does not hydrate; a workspace switch resets
//    fail-closed but carries `disabled` over; an equal projection does not
//    emit;
// SettingsCubit
// 5. the theme is written to `sim-theme` on load, on an optimistic change,
//    and restored on rollback; the patch carries exactly one key;
// ProviderModelsCubit
// 6. nothing loads off-route; the palette opens the gate; the four
//    workspace-scoped providers carry the workspace id; a provider failure
//    is recorded on that entry only and never throws;
// CustomBlocksCubit
// 7. the overlay version bumps on data change, not on an identical refetch;
//    disabled blocks are hidden from the toolbar and the icon falls back to
//    the organization logo.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';

import 'support/mocks.dart';

void main() {
  late QueryClient queryClient;

  setUpAll(() => registerFallbackValue(ProviderName.base));

  setUp(() {
    queryClient = QueryClient();
  });

  group('DeploymentShapeCubit', () {
    test(
      'fallback, equal seed is a no-op, different seed emits, 5xx fails',
      () async {
        final runtime = MockRuntimeConfigRepository();
        when(
          () => runtime.publicEnv(cancelToken: any(named: 'cancelToken')),
        ).thenAnswer(
          (_) async => const PublicEnv({'NEXT_PUBLIC_CHAT_DISABLED': 'true'}),
        );
        final cubit = DeploymentShapeCubit(
          runtimeConfig: runtime,
          queryClient: queryClient,
        );
        await cubit.loadPublicEnv();
        expect(
          cubit.state.shape.chatEnabled,
          isFalse,
          reason: 'fallback from public env',
        );
        final emitted = <DeploymentShapeState>[];
        final sub = cubit.stream.listen(emitted.add);
        cubit
          ..seed(const DeploymentShape(billingEnabled: true))
          ..seed(const DeploymentShape(billingEnabled: true));
        await Future<void>.delayed(Duration.zero);
        expect(emitted.length, 1, reason: 'the equal seed did not notify');
        expect(cubit.state.shape.billingEnabled, isTrue);
        expect(
          cubit.state.shape.chatEnabled,
          isTrue,
          reason: 'seeded shape wins over the fallback',
        );
        await sub.cancel();
        await cubit.close();

        when(
          () => runtime.publicEnv(cancelToken: any(named: 'cancelToken')),
        ).thenAnswer((_) async => throw apiError(500));
        final failing = DeploymentShapeCubit(
          runtimeConfig: runtime,
          queryClient: QueryClient(),
        );
        expect(await failing.loadPublicEnv(), isNull);
        expect(failing.state.failedToStart, isTrue);
        await failing.close();
      },
    );
  });

  group('WorkspaceHostCubit', () {
    test('granted seeds, denied does not, switch re-binds', () async {
      final runtime = MockRuntimeConfigRepository();
      final shape = DeploymentShapeCubit(
        runtimeConfig: runtime,
        queryClient: queryClient,
      );
      when(
        () => runtime.hostContext(
          workspaceId,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => WorkspaceAccess.granted(
          hostContext(deployment: const DeploymentShape(hosted: true)),
        ),
      );
      when(
        () => runtime.hostContext(
          otherWorkspaceId,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => WorkspaceAccess.denied(
          error: apiError(403, 'Workspace access denied'),
        ),
      );
      final cubit = WorkspaceHostCubit(
        runtimeConfig: runtime,
        queryClient: queryClient,
        deploymentShape: shape,
      );
      await cubit.load(workspaceId);
      expect(cubit.state.context?.viewer.permission, WorkspacePermission.admin);
      expect(shape.state.seeded?.hosted, isTrue);
      await cubit.load(otherWorkspaceId);
      expect(cubit.state.workspaceId, otherWorkspaceId);
      expect(cubit.state.accessDenied, isTrue);
      expect(cubit.state.context, isNull);
      expect(
        shape.state.seeded?.hosted,
        isTrue,
        reason: 'the seeded shape persists upstream',
      );
      await cubit.close();
      await shape.close();
    });
  });

  group('FeatureFlagsCubit', () {
    test('defaults, denied, rate limited, organization surface', () async {
      final runtime = MockRuntimeConfigRepository();
      final cubit = FeatureFlagsCubit(
        runtimeConfig: runtime,
        queryClient: queryClient,
      );
      expect(cubit.state.flag('dashboards'), isFalse);
      when(
        () => runtime.featureFlags(
          workspaceId,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => FeatureFlagsDenied(apiError(403)));
      await cubit.load(workspaceId);
      expect(cubit.state.accessDenied, isTrue);
      final limited = ApiClientError.fromResponse(
        status: 429,
        body: {'error': 'Rate limit exceeded'},
        headers: {
          'retry-after': ['3'],
        },
      );
      when(
        () => runtime.featureFlags(
          otherWorkspaceId,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => FeatureFlagsRateLimited(limited));
      await cubit.load(otherWorkspaceId);
      expect(cubit.state.isRateLimited, isTrue);
      expect(cubit.state.retryAfter, const Duration(seconds: 3));
      expect(cubit.state.accessDenied, isFalse);

      cubit.applyOrganizationSurface(
        const OrganizationSurface(
          context: OrganizationSurfaceContext(
            organization: SurfaceOrganization(
              id: 'o',
              name: 'O',
              slug: 'o',
              logo: null,
              memberCount: 1,
            ),
            viewer: SurfaceViewer(
              role: 'member',
              isAdmin: false,
              canInviteMembers: false,
              canConnectSearchIntegrations: false,
              canUsePersonalApiKeys: false,
              canUseSearchMcp: false,
            ),
            connectedAccountsAvailable: false,
            mothershipAvailable: true,
            canBuild: true,
            searchAccess: SearchAccess(
              sourceMirrored: false,
              memberScoped: false,
            ),
            settingsFeatures: SettingsFeatures(
              billingEnabled: false,
              hasEnterprisePlan: false,
              governanceActive: false,
              hosted: false,
              selfHosted: {},
            ),
            deployment: DeploymentShape(),
          ),
          flags: WorkspaceFeatureFlags(
            dashboards: true,
            mothershipMemorySpaces: true,
          ),
          benchmarkEnabled: true,
        ),
      );
      expect(
        cubit.state.flag('mothership-plan-mode'),
        isTrue,
        reason: 'benchmarkEnabled',
      );
      expect(cubit.state.flag('mothership-memory-spaces'), isTrue);
      expect(cubit.state.flag('dashboards'), isTrue);
      cubit.clearOrganizationSurface();
      expect(cubit.state.flag('dashboards'), isFalse);
      await cubit.close();
    });
  });

  group('BlockVisibilityCubit', () {
    test(
      'empty first projection, fail-closed switch keeps disabled, equal guard',
      () async {
        final blocks = MockBlocksRepository();
        when(
          () => blocks.visibility(
            workspaceId,
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => const BlockVisibility());
        final cubit = BlockVisibilityCubit(
          blocks: blocks,
          queryClient: queryClient,
        );
        await cubit.load(workspaceId);
        expect(
          cubit.state.hydrated,
          isFalse,
          reason: 'an empty first projection is not a hydrate',
        );

        when(
          () => blocks.visibility(
            workspaceId,
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => const BlockVisibility(
            revealed: {'r'},
            disabled: {'k'},
            previewTagged: {'p'},
          ),
        );
        queryClient.removeQueries(BlockVisibilityKeys.all);
        await cubit.load(workspaceId);
        expect(cubit.state.hydrated, isTrue);
        expect(cubit.state.revealed, {'r'});

        final states = <BlockVisibilityState>[];
        final sub = cubit.stream.listen(states.add);
        cubit.hydrate(
          const BlockVisibility(
            revealed: {'r'},
            disabled: {'k'},
            previewTagged: {'p'},
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(states, isEmpty, reason: 'deep-equal guard');

        when(
          () => blocks.visibility(
            otherWorkspaceId,
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => const BlockVisibility(revealed: {'other'}));
        final load = cubit.load(otherWorkspaceId);
        expect(
          cubit.state.revealed,
          isEmpty,
          reason: 'reveals dropped while the switch is in flight',
        );
        expect(cubit.state.previewTagged, isEmpty);
        expect(cubit.state.disabled, {
          'k',
        }, reason: 'kill-switch entries carried over');
        await load;
        expect(cubit.state.revealed, {'other'});
        expect(cubit.state.disabled, isEmpty);
        await sub.cancel();
        await cubit.close();
      },
    );
  });

  group('SettingsCubit', () {
    test('theme sync on load, optimistic change and rollback', () async {
      final users = MockUsersRepository();
      final shared = MemorySharedWebState();
      when(
        () => users.settings(cancelToken: any(named: 'cancelToken')),
      ).thenAnswer((_) async => const UserSettings(theme: ThemeSetting.dark));
      final cubit = SettingsCubit(
        users: users,
        queryClient: queryClient,
        sharedState: shared,
      );
      await cubit.load();
      expect(shared.readTheme(), 'dark');

      when(
        () => users.updateSetting(
          'theme',
          'light',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async {
        expect(
          shared.readTheme(),
          'light',
          reason: 'synced before the request settles',
        );
      });
      await cubit.updateSetting('theme', 'light');
      verify(
        () => users.updateSetting(
          'theme',
          'light',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);

      when(
        () => users.settings(cancelToken: any(named: 'cancelToken')),
      ).thenAnswer((_) async => const UserSettings(theme: ThemeSetting.light));
      await cubit.refresh();
      when(
        () => users.updateSetting(
          'theme',
          'system',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => throw apiError(500));
      await expectLater(
        cubit.updateSetting('theme', 'system'),
        throwsA(isA<ApiClientError>()),
      );
      expect(
        shared.readTheme(),
        'light',
        reason: 'rollback re-synced the previous theme',
      );
      expect(cubit.state.theme, ThemeSetting.light);
      await cubit.close();
    });
  });

  group('ProviderModelsCubit', () {
    test('route gate, workspace query, per-provider failure', () async {
      final blocks = MockBlocksRepository();
      when(
        () => blocks.providerModels(
          any(),
          workspaceId: any(named: 'workspaceId'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        final provider = invocation.positionalArguments.first as ProviderName;
        if (provider == ProviderName.vllm) throw apiError(500);
        return ProviderModels(models: ['${provider.wireName}-1']);
      });
      final cubit =
          ProviderModelsCubit(blocks: blocks, queryClient: queryClient)
            ..setRoute(
              pathname: '/workspace/$workspaceId/settings/general',
              workspaceId: workspaceId,
            );
      await Future<void>.delayed(Duration.zero);
      verifyNever(
        () => blocks.providerModels(
          any(),
          workspaceId: any(named: 'workspaceId'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
      expect(cubit.state.enabled, isFalse);

      cubit.setSearchModalOpen(open: true);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.enabled, isTrue);
      verify(
        () => blocks.providerModels(
          ProviderName.fireworks,
          workspaceId: workspaceId,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
      verify(
        () => blocks.providerModels(
          ProviderName.base,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
      expect(cubit.state.models(ProviderName.base), ['base-1']);
      expect(cubit.state.entry(ProviderName.vllm).error, isA<ApiClientError>());
      expect(cubit.state.entry(ProviderName.vllm).models, isEmpty);

      expect(
        shouldLoadProviderModels(
          pathname: '/workspace/$workspaceId/w/wf',
          workspaceId: workspaceId,
          isSearchModalOpen: false,
        ),
        isTrue,
      );
      expect(
        shouldLoadProviderModels(
          pathname: '/workspace/$workspaceId/home',
          workspaceId: workspaceId,
          isSearchModalOpen: false,
        ),
        isTrue,
      );
      expect(
        shouldLoadProviderModels(
          pathname: '/workspace/$workspaceId/logs',
          workspaceId: workspaceId,
          isSearchModalOpen: false,
        ),
        isFalse,
      );
      expect(
        shouldLoadProviderModels(
          pathname: '/home',
          workspaceId: null,
          isSearchModalOpen: true,
        ),
        isFalse,
      );
      await cubit.close();
    });
  });

  group('CustomBlocksCubit', () {
    test('overlay version and fallback icon', () async {
      final blocks = MockBlocksRepository();
      const block = CustomBlock(
        id: 'cb',
        organizationId: 'o',
        workflowId: 'wf',
        workflowName: 'wf',
        workspaceId: workspaceId,
        workspaceName: 'ws',
        type: 'custom_cb',
        name: 'CB',
        description: '',
        iconUrl: null,
        enabled: false,
        traceChildRuns: false,
        inputFields: [],
        exposedOutputs: [],
      );
      when(
        () => blocks.customBlocks(
          workspaceId,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async =>
            const CustomBlocksResponse(enabled: true, customBlocks: [block]),
      );
      final cubit = CustomBlocksCubit(blocks: blocks, queryClient: queryClient);
      await cubit.load(workspaceId);
      final version = cubit.state.overlayVersion;
      expect(cubit.state.overlay.single.hideFromToolbar, isTrue);
      expect(cubit.state.overlay.single.iconUrl, isNull);
      await queryClient.invalidateQueries(CustomBlockKeys.lists());
      expect(
        cubit.state.overlayVersion,
        version,
        reason: 'identical refetch does not rebuild',
      );
      cubit.setFallbackIcon('https://org/logo.png');
      expect(cubit.state.overlayVersion, version + 1);
      expect(cubit.state.overlay.single.iconUrl, 'https://org/logo.png');
      await cubit.close();
    });
  });
}
