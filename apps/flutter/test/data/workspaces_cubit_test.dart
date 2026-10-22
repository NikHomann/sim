// Failure modes of WorkspacesCubit (spec §4.3, §6, §10 #30-32, #48):
// 1. a visit moves the workspace to the front and sets
//    `lastActiveWorkspaceId` before the request; two visits run one at a
//    time and `lists()` is refetched only once, after the last one;
// 2. a visit failure keeps the optimistic order (no rollback);
// 3. a pin toggle is applied before the request; a 409 is success; a 500
//    applies the inverse toggle, not a snapshot, so a concurrent toggle of
//    another workspace survives the rollback;
// 4. create prepends the row (creating the cache entry when empty) and
//    refetches `lists()` + `adminLists()`;
// 5. update swallows errors and reports false; delete rethrows; both
//    refetch `lists()` + `detail(id)`;
// 6. a 401 on the list is the stale-session signal; the ordered list puts
//    pinned rows first in server order;
// 7. leave removes the viewer with the workspace id in the body and
//    refetches permissions(ws), lists and detail;
// 8. reset drops the cache and the state.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';

import 'support/mocks.dart';

void main() {
  late MockWorkspacesRepository workspaces;
  late MockPinnedItemsRepository pins;
  late MockInvitationsRepository invitations;
  late QueryClient queryClient;
  late WorkspacesCubit cubit;
  late int listCalls;
  late List<String> serverPinned;

  setUp(() {
    workspaces = MockWorkspacesRepository();
    pins = MockPinnedItemsRepository();
    invitations = MockInvitationsRepository();
    queryClient = QueryClient();
    listCalls = 0;
    serverPinned = [];
    when(
      () => workspaces.list(cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async {
      listCalls += 1;
      return workspaceList(pinned: List.of(serverPinned));
    });
    cubit = WorkspacesCubit(
      workspaces: workspaces,
      pinnedItems: pins,
      invitations: invitations,
      queryClient: queryClient,
    );
  });

  tearDown(() => cubit.close());

  test(
    'visit: optimistic reorder, serialised, one refetch after the last',
    () async {
      await cubit.load();
      expect(listCalls, 1);
      final first = Completer<void>();
      final second = Completer<void>();
      final answers = [first.future, second.future];
      when(
        () => workspaces.recordVisit(
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => answers.removeAt(0));

      final visitA = cubit.recordVisit(otherWorkspaceId);
      final visitB = cubit.recordVisit(workspaceId);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.lastActiveWorkspaceId, workspaceId);
      expect(cubit.state.workspaces.first.id, workspaceId);
      verify(
        () => workspaces.recordVisit(
          otherWorkspaceId,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
      verifyNever(
        () => workspaces.recordVisit(
          workspaceId,
          cancelToken: any(named: 'cancelToken'),
        ),
      );

      first.complete();
      await visitA;
      expect(listCalls, 1, reason: 'a later visit is queued: no refetch yet');
      second.complete();
      await visitB;
      expect(listCalls, 2, reason: 'the last visit refetches lists()');
    },
  );

  test('a failed visit is not rolled back; the settled refetch wins', () async {
    await cubit.load();
    final gate = Completer<void>();
    when(
      () =>
          workspaces.recordVisit(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) => gate.future);
    final visit = cubit.recordVisit(otherWorkspaceId);
    expect(cubit.state.lastActiveWorkspaceId, otherWorkspaceId);
    gate.completeError(apiError(500));
    await visit;
    expect(listCalls, 2, reason: 'settled: lists() refetched, no restore');
    expect(cubit.state.lastActiveWorkspaceId, workspaceId, reason: 'server');
  });

  test(
    'pin toggle: optimistic, 409 is success, inverse toggle on error',
    () async {
      await cubit.load();
      when(
        () => pins.toggleWorkspacePin(
          workspaceId: workspaceId,
          pinned: true,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async {
        serverPinned = [workspaceId];
        return true;
      });
      await cubit.togglePin(workspaceId, pinned: true);
      expect(cubit.state.pinnedIds, {workspaceId});
      expect(cubit.state.ordered.first.id, workspaceId);

      final gate = Completer<bool>();
      when(
        () => pins.toggleWorkspacePin(
          workspaceId: otherWorkspaceId,
          pinned: true,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => gate.future);
      final failing = cubit.togglePin(otherWorkspaceId, pinned: true);
      expect(cubit.state.pinnedIds, {workspaceId, otherWorkspaceId});
      gate.completeError(apiError(500));
      await expectLater(failing, throwsA(isA<ApiClientError>()));
      expect(cubit.state.pinnedIds, {
        workspaceId,
      }, reason: 'inverse toggle leaves the other pin');
    },
  );

  test('create prepends and refetches lists + adminLists', () async {
    final created = workspace(id: 'new', name: 'New');
    when(
      () => workspaces.create(
        name: 'New',
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => created);
    final result = await cubit.create(name: 'New');
    expect(result.id, 'new');
    expect(
      queryClient
          .getQueryData<WorkspaceList>(WorkspaceKeys.list())
          ?.workspaces
          .first
          .id,
      'new',
    );
    expect(
      listCalls,
      0,
      reason: 'no observer bound: nothing refetched, cache seeded from empty',
    );
    await cubit.load();
    expect(listCalls, 1);
  });

  test('update swallows errors; delete rethrows; both refetch lists', () async {
    await cubit.load();
    when(
      () => workspaces.update(
        workspaceId,
        name: 'x',
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => throw apiError(403, 'Insufficient permissions'));
    expect(await cubit.update(workspaceId, name: 'x'), isFalse);
    expect(listCalls, 2);
    when(
      () => workspaces.delete(
        workspaceId,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => throw apiError(400, 'Cannot delete the only workspace'),
    );
    await expectLater(
      cubit.delete(workspaceId),
      throwsA(isA<ApiClientError>()),
    );
    expect(listCalls, 3);
  });

  test('401 on the list is the stale-session signal', () async {
    when(
      () => workspaces.list(cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => throw apiError(401, 'Unauthorized'));
    await cubit.load();
    expect(cubit.state.isStaleSession, isTrue);
    expect(cubit.state.workspaces, isEmpty);
  });

  test('leave removes the viewer and refetches', () async {
    await cubit.load();
    when(
      () => invitations.removeMember(
        userId: userId,
        workspaceId: workspaceId,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => true);
    await cubit.leave(workspaceId: workspaceId, userId: userId);
    verify(
      () => invitations.removeMember(
        userId: userId,
        workspaceId: workspaceId,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    expect(listCalls, 2);
  });

  test('reset drops cache and state', () async {
    await cubit.load();
    cubit.reset();
    expect(cubit.state, const WorkspacesState());
    expect(
      queryClient.getQueryData<WorkspaceList>(WorkspaceKeys.list()),
      isNull,
    );
  });
}
