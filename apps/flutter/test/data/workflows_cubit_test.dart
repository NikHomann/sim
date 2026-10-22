// Failure modes of WorkflowsCubit (spec §4.6, §6, §10 #51-56):
// 1. create inserts a temp row with the client id and the top-insertion
//    sort order (min sibling − 1 over cached workflows AND folders) before
//    the request (for display only: the request carries no sortOrder, the
//    server computes it), sends `deduplicate: true` and `folderId`, replaces the
//    temp row with the server row and marks the workflow created;
// 2. a 4xx on create restores the snapshot and marks created `null`;
// 3. invalidation ordering: the list is refetched only after the mutation
//    settled (one list request during the optimistic window, one after);
// 4. delete removes the row optimistically and rolls back on 403;
// 5. update merges the metadata and bumps `updatedAt` from the injected
//    clock; reorder applies sortOrder/folderId per row;
// 6. the sidebar view sorts by createdAt desc and filters other
//    workspaces' rows;
// 7. the socket change handler refetches active + archived lists and the
//    workflow folders of that workspace only.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';

import 'support/mocks.dart';

void main() {
  late MockWorkflowsRepository workflows;
  late QueryClient queryClient;
  late WorkflowsCubit cubit;
  late int listCalls;
  late List<WorkflowListItem> serverRows;
  final now = DateTime.utc(2026, 10, 21, 12);

  setUp(() {
    workflows = MockWorkflowsRepository();
    queryClient = QueryClient();
    listCalls = 0;
    serverRows = [
      workflow(id: 'a', sortOrder: 2),
      workflow(id: 'b', folderId: 'f1'),
    ];
    when(
      () => workflows.list(
        workspaceId: workspaceId,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      listCalls += 1;
      return List.of(serverRows);
    });
    cubit = WorkflowsCubit(
      workflows: workflows,
      queryClient: queryClient,
      idGenerator: () => 'temp-id',
      now: () => now,
    );
  });

  tearDown(() => cubit.close());

  CreatedWorkflow created(String id, {num sortOrder = 1}) => CreatedWorkflow(
    id: id,
    name: 'bolt-ivy',
    description: '',
    workspaceId: workspaceId,
    folderId: null,
    sortOrder: sortOrder,
    createdAt: '2026-10-21T12:00:00.000Z',
    updatedAt: '2026-10-21T12:00:00.000Z',
    startBlockId: 'start',
    subBlockValues: const {},
  );

  test(
    'create: temp row, top insertion order, replace, created mark',
    () async {
      await cubit.load(workspaceId);
      queryClient.setQueryData<List<Folder>>(FolderKeys.list(workspaceId), [
        folder(id: 'f1', sortOrder: -3),
      ]);
      final gate = Completer<CreatedWorkflow>();
      when(
        () => workflows.create(
          id: 'temp-id',
          name: 'bolt-ivy',
          workspaceId: workspaceId,
          sendFolder: true,
          // No sortOrder: the server computes the top insertion.
          deduplicate: true,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => gate.future);

      final future = cubit.create(name: 'bolt-ivy');
      await Future<void>.delayed(Duration.zero);
      final temp = cubit.state.byId['temp-id'];
      expect(temp, isNotNull, reason: 'optimistic row before the response');
      expect(
        temp!.sortOrder,
        -4,
        reason: 'min(2, -3) - 1 over workflows and root folders',
      );
      expect(temp.createdAt, now.toIso8601String());
      expect(listCalls, 1, reason: 'no refetch during the optimistic window');

      serverRows.add(
        workflow(id: 'server-id', name: 'bolt-ivy', sortOrder: -4),
      );

      gate.complete(created('server-id', sortOrder: -4));
      await future;
      expect(cubit.state.byId.containsKey('temp-id'), isFalse);
      expect(cubit.state.byId['server-id']?.name, 'bolt-ivy');
      expect(cubit.state.createdWorkflowId, 'server-id');
      expect(listCalls, 2, reason: 'active list refetched once settled');
    },
  );

  test(
    'a 4xx on create restores the snapshot and clears the created mark',
    () async {
      await cubit.load(workspaceId);
      cubit.markWorkflowCreating('temp-id');
      when(
        () => workflows.create(
          id: any(named: 'id'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          workspaceId: any(named: 'workspaceId'),
          folderId: any(named: 'folderId'),
          sendFolder: any(named: 'sendFolder'),
          sortOrder: any(named: 'sortOrder'),
          deduplicate: any(named: 'deduplicate'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => throw apiError(403, 'read only'));
      await expectLater(
        cubit.create(name: 'x'),
        throwsA(isA<ApiClientError>()),
      );
      expect(cubit.state.items.map((w) => w.id), ['a', 'b']);
      expect(cubit.state.createdWorkflowId, isNull);
      expect(cubit.state.creatingWorkflowId, 'temp-id');
      expect(
        listCalls,
        2,
        reason: 'settled refetch runs after the rollback too',
      );
    },
  );

  test('delete: optimistic removal, rollback on 403', () async {
    await cubit.load(workspaceId);
    final gate = Completer<void>();
    when(
      () => workflows.delete('a', cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) => gate.future);
    final future = cubit.delete('a');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.items.map((w) => w.id), ['b']);
    gate.completeError(apiError(403));
    await expectLater(future, throwsA(isA<ApiClientError>()));
    expect(cubit.state.items.map((w) => w.id), ['a', 'b']);
  });

  test(
    'update merges metadata with the injected clock; reorder applies rows',
    () async {
      await cubit.load(workspaceId);
      final gate = Completer<WorkflowListItem>();
      when(
        () => workflows.update(
          'a',
          update: const WorkflowUpdate(name: 'Renamed', clearFolder: true),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => gate.future);
      final future = cubit.update(
        'a',
        const WorkflowUpdate(name: 'Renamed', clearFolder: true),
      );
      await Future<void>.delayed(Duration.zero);
      final row = cubit.state.byId['a']!;
      expect(row.name, 'Renamed');
      expect(row.updatedAt, now.toIso8601String());
      gate.complete(workflow(id: 'a', name: 'Renamed'));
      await future;

      when(
        () => workflows.reorder(
          workspaceId: workspaceId,
          updates: any(named: 'updates'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => const ReorderResult(updated: 2));
      await cubit.reorder(const [
        WorkflowReorderUpdate(id: 'a', sortOrder: 5, folderId: 'f9'),
        WorkflowReorderUpdate(id: 'b', sortOrder: 6, clearFolder: true),
      ]);
      // The settled refetch replaced the optimistic rows with the mock list;
      // the optimistic application is observable through the cache snapshot
      // taken by a slow mutation instead.
      final slow = Completer<ReorderResult>();
      when(
        () => workflows.reorder(
          workspaceId: workspaceId,
          updates: any(named: 'updates'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => slow.future);
      final pending = cubit.reorder(const [
        WorkflowReorderUpdate(id: 'b', sortOrder: 9, clearFolder: true),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.byId['b']!.sortOrder, 9);
      expect(cubit.state.byId['b']!.folderId, isNull);
      slow.complete(const ReorderResult(updated: 1));
      await pending;
    },
  );

  test('sidebar view: newest first, this workspace only', () async {
    when(
      () => workflows.list(
        workspaceId: workspaceId,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => [
        workflow(id: 'old', createdAt: '2026-01-01T00:00:00.000Z'),
        workflow(id: 'new', createdAt: '2026-06-01T00:00:00.000Z'),
        const WorkflowListItem(
          id: 'foreign',
          name: 'x',
          description: null,
          workspaceId: otherWorkspaceId,
          folderId: null,
          sortOrder: 0,
          createdAt: '2026-09-01T00:00:00.000Z',
          updatedAt: '2026-09-01T00:00:00.000Z',
          archivedAt: null,
          locked: false,
        ),
      ],
    );
    await cubit.load(workspaceId);
    expect(cubit.state.forSidebar.map((w) => w.id), ['new', 'old']);
  });

  test('socket change refetches active + archived lists and folders', () async {
    await cubit.load(workspaceId);
    var archivedCalls = 0;
    var folderCalls = 0;
    queryClient.query<List<WorkflowListItem>>(
      WorkflowKeys.list(workspaceId, 'archived'),
      (_) async {
        archivedCalls += 1;
        return [];
      },
    );
    var otherCalls = 0;
    queryClient
      ..query<List<Folder>>(FolderKeys.list(workspaceId), (_) async {
        folderCalls += 1;
        return [];
      })
      ..query<List<WorkflowListItem>>(
        WorkflowKeys.list(otherWorkspaceId),
        (_) async {
          otherCalls += 1;
          return [];
        },
      );
    await cubit.onWorkspaceWorkflowsChanged(workspaceId);
    expect(listCalls, 2);
    expect(archivedCalls, 1);
    expect(folderCalls, 1);
    expect(otherCalls, 0);
  });
}
