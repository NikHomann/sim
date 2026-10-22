// Failure modes of FoldersCubit and PinnedItemsCubit (spec §4.5, §4.7, §6,
// §10 #58-64):
// 1. folder create without a name uses "Folder N" over the cached root
//    folders, the temp row takes the top-insertion order over cached
//    workflows and folders of the same parent (display only: the request
//    carries no sortOrder), and the server row replaces it; a 400 restores the snapshot;
// 2. folder reorder applies sortOrder/parentId optimistically and rolls
//    back on failure;
// 3. folder update is not optimistic and refetches every workspace's
//    workflow-folder list (`resource('workflow')`), not just this one;
// 4. a pin appends a row to the typed list AND the unscoped workspace list,
//    leaves the other-typed list alone, and a 409 rolls both back;
// 5. an unpin filters the row and refetches `workspaceLists(ws)`;
// 6. the pinned ids are read per type.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';

import 'support/mocks.dart';

void main() {
  group('FoldersCubit', () {
    late MockFoldersRepository folders;
    late QueryClient queryClient;
    late FoldersCubit cubit;
    late int listCalls;

    setUp(() {
      folders = MockFoldersRepository();
      queryClient = QueryClient();
      listCalls = 0;
      when(
        () => folders.list(
          workspaceId: workspaceId,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async {
        listCalls += 1;
        return [
          folder(id: 'f1', name: 'Folder 3', sortOrder: 1),
          folder(id: 'f2', name: 'Nested', parentId: 'f1'),
        ];
      });
      cubit = FoldersCubit(
        folders: folders,
        queryClient: queryClient,
        idGenerator: () => 'temp-folder',
        now: () => DateTime.utc(2026),
      );
    });

    tearDown(() => cubit.close());

    test(
      'create: name rule, top insertion over workflows + folders, replace, rollback',
      () async {
        await cubit.load(workspaceId);
        queryClient.setQueryData<List<WorkflowListItem>>(
          WorkflowKeys.list(workspaceId),
          [
            workflow(id: 'w', sortOrder: -2),
          ],
        );
        final gate = Completer<Folder>();
        when(
          () => folders.create(
            id: 'temp-folder',
            name: 'Folder 4',
            workspaceId: workspaceId,
            // No sortOrder: the server computes the top insertion.
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) => gate.future);
        final future = cubit.create();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.byId['temp-folder']?.name, 'Folder 4');
        expect(cubit.state.byId['temp-folder']?.sortOrder, -3);
        gate.complete(folder(id: 'real', name: 'Folder 4', sortOrder: -3));
        await future;
        expect(cubit.state.byId.containsKey('temp-folder'), isFalse);
        expect(cubit.state.byId['real'], isNotNull);
        expect(listCalls, 2);

        when(
          () => folders.create(
            id: any(named: 'id'),
            name: any(named: 'name'),
            workspaceId: any(named: 'workspaceId'),
            parentId: any(named: 'parentId'),
            sortOrder: any(named: 'sortOrder'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => throw apiError(400, 'Invalid name'));
        await expectLater(
          cubit.create(name: ' '),
          throwsA(isA<ApiClientError>()),
        );
        expect(cubit.state.items.map((f) => f.id), ['f1', 'f2']);
      },
    );

    test('reorder applies and rolls back', () async {
      await cubit.load(workspaceId);
      final gate = Completer<ReorderResult>();
      when(
        () => folders.reorder(
          workspaceId: workspaceId,
          updates: any(named: 'updates'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) => gate.future);
      final future = cubit.reorder(const [
        FolderReorderUpdate(id: 'f2', sortOrder: 7, clearParent: true),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.byId['f2']!.sortOrder, 7);
      expect(cubit.state.byId['f2']!.parentId, isNull);
      gate.completeError(apiError(500));
      await expectLater(future, throwsA(isA<ApiClientError>()));
      expect(cubit.state.byId['f2']!.parentId, 'f1');
    });

    test("update refetches every workspace's workflow-folder list", () async {
      await cubit.load(workspaceId);
      var otherCalls = 0;
      queryClient.query<List<Folder>>(FolderKeys.list(otherWorkspaceId), (
        _,
      ) async {
        otherCalls += 1;
        return [];
      });
      var tableCalls = 0;
      queryClient.query<List<Folder>>(
        FolderKeys.list(workspaceId, 'active', 'table'),
        (_) async {
          tableCalls += 1;
          return [];
        },
      );
      when(
        () => folders.update(
          'f1',
          update: const FolderUpdate(name: 'Z'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => folder(id: 'f1', name: 'Z'));
      await cubit.update('f1', const FolderUpdate(name: 'Z'));
      expect(listCalls, 2);
      expect(otherCalls, 1);
      expect(tableCalls, 0);
    });
  });

  group('PinnedItemsCubit', () {
    late MockPinnedItemsRepository pins;
    late QueryClient queryClient;
    late PinnedItemsCubit cubit;

    setUp(() {
      pins = MockPinnedItemsRepository();
      queryClient = QueryClient();
      when(
        () => pins.list(
          workspaceId: workspaceId,
          resourceType: PinnedResourceType.workflow,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => [pinnedItem(PinnedResourceType.workflow, 'w1')],
      );
      when(
        () => pins.list(
          workspaceId: workspaceId,
          resourceType: PinnedResourceType.folder,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => []);
      cubit = PinnedItemsCubit(
        pinnedItems: pins,
        queryClient: queryClient,
        idGenerator: () => 'temp-pin',
        now: () => DateTime.utc(2026),
      );
    });

    tearDown(() => cubit.close());

    test(
      'pin updates typed + unscoped lists, not the other type; 409 rolls back',
      () async {
        await cubit.load(workspaceId);
        queryClient.setQueryData<List<PinnedItem>>(
          PinnedItemKeys.list(workspaceId),
          [
            pinnedItem(PinnedResourceType.workflow, 'w1'),
          ],
        );
        final gate = Completer<PinnedItem>();
        when(
          () => pins.pin(
            workspaceId: workspaceId,
            resourceType: PinnedResourceType.folder,
            resourceId: 'f1',
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) => gate.future);
        final future = cubit.pin(PinnedResourceType.folder, 'f1');
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.folderIds, {'f1'});
        expect(cubit.state.workflowIds, {'w1'});
        expect(
          queryClient
              .getQueryData<List<PinnedItem>>(PinnedItemKeys.list(workspaceId))!
              .map((p) => p.resourceId),
          ['w1', 'f1'],
        );
        gate.completeError(apiError(409, 'This item is already pinned'));
        await expectLater(future, throwsA(isA<ApiClientError>()));
        expect(cubit.state.folderIds, isEmpty);
        expect(
          queryClient
              .getQueryData<List<PinnedItem>>(PinnedItemKeys.list(workspaceId))!
              .map((p) => p.resourceId),
          ['w1'],
        );
      },
    );

    test('unpin filters and refetches the workspace lists', () async {
      await cubit.load(workspaceId);
      when(
        () => pins.unpin(
          resourceType: PinnedResourceType.workflow,
          resourceId: 'w1',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => pins.list(
          workspaceId: workspaceId,
          resourceType: PinnedResourceType.workflow,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => []);
      await cubit.unpin(PinnedResourceType.workflow, 'w1');
      expect(cubit.state.workflowIds, isEmpty);
      verify(
        () => pins.list(
          workspaceId: workspaceId,
          resourceType: PinnedResourceType.workflow,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(2);
      expect(cubit.state.isPinned(PinnedResourceType.workflow, 'w1'), isFalse);
    });
  });
}
