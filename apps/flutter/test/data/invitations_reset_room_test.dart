// Failure modes of InvitationsCubit, resetUserData and MutationScope
// (spec §4.4, §6, §7, §10 #19-20, #41-47):
// InvitationsCubit
// 1. accept refetches `workspace/list`, `organizations`, credentials and
//    subscription on success, refreshes the session, and `invitations/mine`
//    once settled; a failed accept still settles `mine` but refetches
//    nothing else and keeps the typed InvitationError;
// 2. a batch send with `failed[]` is returned (partial failure) and the
//    per-workspace lists refetch;
// 3. `mine` is bound only on demand and the switcher flag reads non-empty;
// resetUserData
// 4. every key except the keep-list is deleted; `recent-impersonations`
//    survives only when preserved; registered cubits reset; the query
//    cache empties; a throwing reset reports false but still clears cookies;
// MutationScope
// 5. mutations run one at a time in order; `isLast` is false while a later
//    one is queued and true for the last; a failure does not block the
//    queue;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';

import 'support/mocks.dart';

void main() {
  group('InvitationsCubit', () {
    late MockInvitationsRepository invitations;
    late MockWorkspacesRepository workspaces;
    late QueryClient queryClient;
    late int sessionRefreshes;
    late InvitationsCubit cubit;
    late Map<String, int> refetches;

    setUp(() {
      invitations = MockInvitationsRepository();
      workspaces = MockWorkspacesRepository();
      queryClient = QueryClient();
      sessionRefreshes = 0;
      refetches = {};
      void count(QueryKey key) =>
          refetches[queryHash(key)] = (refetches[queryHash(key)] ?? 0) + 1;
      for (final key in [
        WorkspaceKeys.list(),
        OrganizationKeys.lists(),
        SubscriptionKeys.user(),
      ]) {
        queryClient.query<Object?>(key, (_) async {
          count(key);
          return null;
        });
      }
      queryClient.query<List<PendingWorkspaceInvitation>>(
        InvitationKeys.list(workspaceId),
        (_) async {
          count(InvitationKeys.list(workspaceId));
          return [];
        },
      );
      cubit = InvitationsCubit(
        invitations: invitations,
        workspaces: workspaces,
        queryClient: queryClient,
        refreshSession: () async => sessionRefreshes += 1,
      );
    });

    tearDown(() => cubit.close());

    int count(QueryKey key) => refetches[queryHash(key)] ?? 0;

    test('accept invalidation set and failure path', () async {
      queryClient.query<List<InvitationDetails>>(InvitationKeys.mine(), (
        _,
      ) async {
        refetches[queryHash(InvitationKeys.mine())] =
            (refetches[queryHash(InvitationKeys.mine())] ?? 0) + 1;
        return [];
      });
      when(
        () => invitations.accept(
          'inv',
          token: 't',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => const AcceptedInvitation(
          redirectPath: '/workspace/x',
          id: 'inv',
          kind: InvitationKind.workspace,
          organizationId: null,
          acceptedWorkspaceIds: ['x'],
        ),
      );
      final accepted = await cubit.accept('inv', token: 't');
      expect(accepted.redirectPath, '/workspace/x');
      expect(sessionRefreshes, 1);
      expect(count(WorkspaceKeys.list()), 1);
      expect(count(OrganizationKeys.lists()), 1);
      expect(count(SubscriptionKeys.user()), 1);
      expect(count(InvitationKeys.mine()), 1);

      when(
        () => invitations.accept(
          'bad',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async =>
            throw InvitationError.from(apiError(409, 'disclosure-outdated')),
      );
      await expectLater(
        cubit.accept('bad'),
        throwsA(
          isA<InvitationError>().having(
            (e) => e.kind,
            'kind',
            InvitationErrorCode.disclosureOutdated,
          ),
        ),
      );
      expect(sessionRefreshes, 1);
      expect(count(WorkspaceKeys.list()), 1, reason: 'no success invalidation');
      expect(count(InvitationKeys.mine()), 2, reason: 'settled regardless');
    });

    test(
      'batch send returns the partial failure and refetches per workspace',
      () async {
        when(
          () => invitations.sendBatch(
            workspaceIds: [workspaceId],
            emails: ['a@b.c'],
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => const BatchInvitationResult(
            success: true,
            successful: [],
            added: [],
            failed: [BatchInvitationFailure(email: 'a@b.c', error: 'nope')],
            invitations: [],
          ),
        );
        final result = await cubit.sendBatch(
          workspaceIds: [workspaceId],
          emails: ['a@b.c'],
        );
        expect(result.isPartialFailure, isTrue);
        expect(count(InvitationKeys.list(workspaceId)), 1);
      },
    );

    test('mine binds on demand', () async {
      expect(cubit.state.hasPending, isFalse);
      verifyNever(
        () => invitations.listMine(cancelToken: any(named: 'cancelToken')),
      );
      when(
        () => invitations.listMine(cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => [
          const InvitationDetails(
            id: 'i',
            kind: InvitationKind.workspace,
            email: 'e',
            organizationId: null,
            organizationName: null,
            membershipIntent: MembershipIntent.internal,
            role: 'member',
            status: 'pending',
            expiresAt: 'x',
            createdAt: 'x',
            inviterName: null,
            inviterEmail: null,
            grants: [],
          ),
        ],
      );
      await cubit.loadMine();
      expect(cubit.state.hasPending, isTrue);
    });
  });

  group('resetUserData', () {
    test('keep-list, registry, cache, cookies, failure reporting', () async {
      final store = InMemoryKeyValueStore();
      await store.write('sim-theme', 'dark');
      await store.write('next-favicon', 'x');
      await store.write('sim-landing-theme', 'light');
      await store.write('recent-impersonations', ['u']);
      await store.write('console:wf1', {'entries': <String>[]});
      final queryClient = QueryClient()..setQueryData(['workspace', 'list'], 1);
      final registry = UserDataResetRegistry();
      var resets = 0;
      var cookiesCleared = 0;
      registry.register(() => resets += 1);

      final ok = await resetUserData(
        store: store,
        queryClient: queryClient,
        registry: registry,
        clearCookies: () async => cookiesCleared += 1,
      );
      expect(ok, isTrue);
      expect(
        await store.keys(),
        unorderedEquals(['sim-theme', 'next-favicon', 'sim-landing-theme']),
      );
      expect(resets, 1);
      expect(cookiesCleared, 1);
      expect(queryClient.getQueryData<int>(['workspace', 'list']), isNull);

      await store.write('recent-impersonations', ['u']);
      await store.write('draft', 'd');
      await resetUserData(
        store: store,
        queryClient: queryClient,
        registry: registry,
        preserveRecentImpersonations: true,
      );
      expect(await store.keys(), contains('recent-impersonations'));
      expect(await store.keys(), isNot(contains('draft')));

      registry.register(() => throw StateError('boom'));
      final failed = await resetUserData(
        store: store,
        queryClient: queryClient,
        registry: registry,
        clearCookies: () async => cookiesCleared += 1,
      );
      expect(failed, isFalse);
      expect(cookiesCleared, 2);
    });
  });

  group('MutationScope', () {
    test('serialises, reports isLast, survives failures', () async {
      final scope = MutationScope();
      final order = <String>[];
      final lastFlags = <bool>[];
      final a = Completer<void>();
      final b = Completer<void>();
      final first = scope.run(() async {
        order.add('a-start');
        await a.future;
        order.add('a-end');
      }, onSettled: ({required isLast}) => lastFlags.add(isLast));
      final second = scope.run(() async {
        order.add('b-start');
        await b.future;
        throw StateError('b failed');
      }, onSettled: ({required isLast}) => lastFlags.add(isLast));
      final third = scope.run(
        () async => order.add('c'),
        onSettled: ({required isLast}) => lastFlags.add(isLast),
      );
      expect(scope.pending, 3);
      await Future<void>.delayed(Duration.zero);
      expect(order, ['a-start']);
      a.complete();
      await first;
      expect(order, ['a-start', 'a-end', 'b-start']);
      b.complete();
      await expectLater(second, throwsStateError);
      await third;
      expect(order.last, 'c');
      expect(lastFlags, [false, false, true]);
      expect(scope.pending, 0);
    });
  });
}
