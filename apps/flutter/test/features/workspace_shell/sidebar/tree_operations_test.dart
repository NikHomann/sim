// Failure modes of the tree mutations (use-drag-drop.ts buildAndSubmit,
// use-delete-*, use-duplicate-*, use-workflow/folder-operations):
// 1. a drop that moves folders AND workflows sends both reorder PUTs
//    concurrently; one failing toasts "Only some items moved", both
//    failing "Failed to move items", success clears both selections;
// 2. deleting the open workflow navigates FIRST to the next remaining
//    workflow after it (cached list order), else the first remaining,
//    else the workspace root;
// 3. a single folder delete never navigates; a multi-folder delete also
//    counts the folders' direct workflows for navigation;
// 4. duplicates: folders get "X Copy N" under the same parent, workflows
//    "X (Copy)" in the same folder; one workflow duplicate opens it;
// 5. new workflow: navigates to the client id before the POST resolves,
//    with a creative name; in a folder it expands the folder (the wire
//    sortOrder belongs to the data layer's contract tests);
// 6. in-folder create folder names "Subfolder N" from a fresh list and
//    toasts the server message on failure;
// 7. selection clearing follows the hook that ran: a single-folder delete
//    still clears the workflow selection (`use-delete-folder`), a mixed or
//    multi-folder delete / duplicate also clears the folder selection
//    (`use-*-selection`);
// 8. a request still in flight when the sidebar rebinds to another
//    workspace (disposing these operations) must not write the disposed
//    busy flags.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/drop_logic.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_cubit.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_operations.dart';

import 'support/harness.dart';

ApiClientError serverError(String message) =>
    ApiClientError.fromResponse(status: 409, body: {'error': message});

void main() {
  late SidebarHarness h;
  late TreeOperations ops;
  var ids = 0;

  setUpAll(() {
    registerFallbackValue(const WorkflowUpdate());
    registerFallbackValue(const FolderUpdate());
  });

  setUp(() async {
    h = SidebarHarness();
    await h.load();
    ids = 0;
    ops = TreeOperations(
      services: h.services(),
      workspaceId: workspaceId,
      idGenerator: () => 'new-${ids++}',
    );
  });

  tearDown(() async {
    ops.dispose();
    await h.dispose();
  });

  void stubReorders({bool foldersFail = false, bool workflowsFail = false}) {
    when(
      () => h.foldersRepo.reorder(
        workspaceId: any(named: 'workspaceId'),
        updates: any(named: 'updates'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      if (foldersFail) throw serverError('nope');
      return const ReorderResult(updated: 1);
    });
    when(
      () => h.workflowsRepo.reorder(
        workspaceId: any(named: 'workspaceId'),
        updates: any(named: 'updates'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async {
      if (workflowsFail) throw serverError('nope');
      return const ReorderResult(updated: 1);
    });
  }

  const mixed = DragSelection(
    workflowIds: <String>['w-bench'],
    folderIds: <String>['f-ops'],
  );
  const beforeEmpty = DropIndicator(
    targetId: 'w-empty',
    position: DropPosition.before,
    folderId: null,
  );

  group('drop', () {
    test('sends both payloads; success clears selections', () async {
      stubReorders();
      h.tree
        ..selectOnly('w-bench')
        ..selectFolder('f-ops');
      await ops.drop(mixed, beforeEmpty);
      final folders =
          verify(
                () => h.foldersRepo.reorder(
                  workspaceId: workspaceId,
                  updates: captureAny(named: 'updates'),
                  cancelToken: any(named: 'cancelToken'),
                ),
              ).captured.single
              as List<FolderReorderUpdate>;
      final workflows =
          verify(
                () => h.workflowsRepo.reorder(
                  workspaceId: workspaceId,
                  updates: captureAny(named: 'updates'),
                  cancelToken: any(named: 'cancelToken'),
                ),
              ).captured.single
              as List<WorkflowReorderUpdate>;
      // Moving rows first in sibling order (w-bench 2, f-ops 3), then the
      // rest: w-empty, f-e2e.
      expect(
        folders.map((u) => '${u.id}:${u.sortOrder}'),
        <String>['f-ops:1', 'f-e2e:3'],
      );
      expect(
        workflows.map((u) => '${u.id}:${u.sortOrder}'),
        <String>['w-bench:0', 'w-empty:2'],
      );
      expect(h.tree.state.selectedWorkflows, isEmpty);
      expect(h.tree.state.selectedFolders, isEmpty);
      expect(h.toasts.toasts, isEmpty);
    });

    test('one failure toasts "Only some items moved"', () async {
      stubReorders(foldersFail: true);
      h.tree.selectOnly('w-bench');
      await ops.drop(mixed, beforeEmpty);
      expect(h.toasts.toasts.single.message, 'Only some items moved');
      expect(h.tree.state.selectedWorkflows, <String>{'w-bench'});
    });

    test('total failure toasts "Failed to move items"', () async {
      stubReorders(foldersFail: true, workflowsFail: true);
      await ops.drop(mixed, beforeEmpty);
      expect(h.toasts.toasts.single.message, 'Failed to move items');
    });

    test('an invalid drop sends nothing', () async {
      stubReorders();
      await ops.drop(
        const DragSelection(
          workflowIds: <String>[],
          folderIds: <String>['f-e2e'],
        ),
        const DropIndicator(
          targetId: 'f-nested',
          position: DropPosition.inside,
          folderId: 'f-e2e',
        ),
      );
      verifyNever(
        () => h.foldersRepo.reorder(
          workspaceId: any(named: 'workspaceId'),
          updates: any(named: 'updates'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });
  });

  group('delete', () {
    setUp(() {
      when(
        () => h.workflowsRepo.delete(
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async {});
      when(
        () =>
            h.foldersRepo.delete(any(), cancelToken: any(named: 'cancelToken')),
      ).thenAnswer((_) async => const FolderCascadeResult());
    });

    test('the open workflow navigates to the next one first', () async {
      await ops.delete(
        const CapturedSelection(
          workflowIds: <String>['w-empty'],
          folderIds: <String>[],
        ),
      );
      expect(h.navigator.visited, <String>[
        '/workspace/$workspaceId/w/w-bench',
      ]);
      verify(
        () => h.workflowsRepo.delete(
          'w-empty',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });

    test('the last workflow in list order falls back to the first', () async {
      h.navigator.location = '/workspace/$workspaceId/w/w-mixed';
      await ops.delete(
        const CapturedSelection(
          workflowIds: <String>['w-mixed', 'w-bench'],
          folderIds: <String>[],
        ),
      );
      expect(h.navigator.visited.last, '/workspace/$workspaceId/w/w-empty');
    });

    test('deleting everything lands on the workspace root', () async {
      await ops.delete(
        const CapturedSelection(
          workflowIds: <String>['w-empty', 'w-bench', 'w-mixed'],
          folderIds: <String>[],
        ),
      );
      expect(h.navigator.visited.last, '/workspace/$workspaceId');
    });

    test('a single folder never navigates', () async {
      h.navigator.location = '/workspace/$workspaceId/w/w-mixed';
      await ops.delete(
        const CapturedSelection(
          workflowIds: <String>[],
          folderIds: <String>['f-e2e'],
        ),
      );
      expect(h.navigator.visited, isEmpty);
    });

    test('a single folder delete clears the workflow selection', () async {
      h.tree.selectOnly('w-bench');
      await ops.delete(
        const CapturedSelection(
          workflowIds: <String>[],
          folderIds: <String>['f-ops'],
        ),
      );
      expect(h.tree.state.selectedWorkflows, isEmpty);
    });

    test('a mixed delete clears the folder selection too', () async {
      h.tree
        ..selectOnly('w-bench')
        ..selectFolder('f-ops');
      await ops.delete(
        const CapturedSelection(
          workflowIds: <String>['w-bench'],
          folderIds: <String>['f-ops'],
        ),
      );
      expect(h.tree.state.selectedWorkflows, isEmpty);
      expect(h.tree.state.selectedFolders, isEmpty);
    });

    test('a multi-folder delete navigates off a contained workflow', () async {
      h.navigator.location = '/workspace/$workspaceId/w/w-mixed';
      await ops.delete(
        const CapturedSelection(
          workflowIds: <String>[],
          folderIds: <String>['f-e2e', 'f-ops'],
        ),
      );
      expect(h.navigator.visited.single, '/workspace/$workspaceId/w/w-empty');
      verifyNever(
        () => h.workflowsRepo.delete(
          'w-mixed',
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });
  });

  test('duplicates name folders and workflows like upstream', () async {
    h.queryClient.setQueryData<List<Folder>>(
      FolderKeys.list(workspaceId),
      <Folder>[...seedFolders(), fd('copy', name: 'Ops Copy')],
    );
    await Future<void>.delayed(Duration.zero);
    when(
      () => h.foldersRepo.duplicate(
        any(),
        name: any(named: 'name'),
        workspaceId: any(named: 'workspaceId'),
        parentId: any(named: 'parentId'),
        sendParent: any(named: 'sendParent'),
        newId: any(named: 'newId'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => fd('new-0', name: 'Ops Copy 2'));
    when(
      () => h.workflowsRepo.duplicate(
        any(),
        name: any(named: 'name'),
        description: any(named: 'description'),
        workspaceId: any(named: 'workspaceId'),
        folderId: any(named: 'folderId'),
        sendFolder: any(named: 'sendFolder'),
        newId: any(named: 'newId'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => const DuplicatedWorkflow(
        id: 'new-1',
        name: 'Mixed 20 blocks (Copy)',
        description: '',
        workspaceId: workspaceId,
        folderId: 'f-e2e',
        sortOrder: 0,
        locked: false,
        blocksCount: 0,
        edgesCount: 0,
        subflowsCount: 0,
      ),
    );
    await ops.duplicate(
      const CapturedSelection(
        workflowIds: <String>['w-mixed'],
        folderIds: <String>['f-ops'],
      ),
    );
    verify(
      () => h.foldersRepo.duplicate(
        'f-ops',
        name: 'Ops Copy 2',
        workspaceId: workspaceId,
        sendParent: true,
        newId: 'new-0',
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    verify(
      () => h.workflowsRepo.duplicate(
        'w-mixed',
        name: 'Mixed 20 blocks (Copy)',
        description: '',
        workspaceId: workspaceId,
        folderId: 'f-e2e',
        sendFolder: true,
        newId: 'new-1',
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    // A folder was duplicated too, so nothing opens.
    expect(h.navigator.visited, isEmpty);
  });

  test('a mixed duplicate clears the folder selection too', () async {
    when(
      () => h.foldersRepo.duplicate(
        any(),
        name: any(named: 'name'),
        workspaceId: any(named: 'workspaceId'),
        parentId: any(named: 'parentId'),
        sendParent: any(named: 'sendParent'),
        newId: any(named: 'newId'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => fd('f-copy', name: 'Ops Copy'));
    when(
      () => h.workflowsRepo.duplicate(
        any(),
        name: any(named: 'name'),
        description: any(named: 'description'),
        workspaceId: any(named: 'workspaceId'),
        folderId: any(named: 'folderId'),
        sendFolder: any(named: 'sendFolder'),
        newId: any(named: 'newId'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => const DuplicatedWorkflow(
        id: 'w-copy',
        name: 'Benchmark 200 blocks (Copy)',
        description: '',
        workspaceId: workspaceId,
        folderId: null,
        sortOrder: 0,
        locked: false,
        blocksCount: 0,
        edgesCount: 0,
        subflowsCount: 0,
      ),
    );
    h.tree
      ..selectOnly('w-bench')
      ..selectFolder('f-ops');
    await ops.duplicate(
      const CapturedSelection(
        workflowIds: <String>['w-bench'],
        folderIds: <String>['f-ops'],
      ),
    );
    expect(h.tree.state.selectedWorkflows, isEmpty);
    expect(h.tree.state.selectedFolders, isEmpty);
  });

  test('a request finishing after dispose leaves the busy flags alone', () {
    final pending = Completer<Folder>();
    when(
      () => h.foldersRepo.generateName(
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => 'Folder 4');
    when(
      () => h.foldersRepo.create(
        name: any(named: 'name'),
        workspaceId: any(named: 'workspaceId'),
        id: any(named: 'id'),
        parentId: any(named: 'parentId'),
        sortOrder: any(named: 'sortOrder'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => pending.future);
    final disposing = TreeOperations(
      services: h.services(),
      workspaceId: workspaceId,
    );
    final running = disposing.createFolder();
    expect(disposing.isCreatingFolder.value, isTrue);
    disposing.dispose();
    pending.complete(fd('f-new', name: 'Folder 4'));
    return expectLater(running, completes);
  });

  test('new workflow navigates before the POST resolves', () async {
    final pending = Completer<CreatedWorkflow>();
    when(
      () => h.workflowsRepo.create(
        name: any(named: 'name'),
        id: any(named: 'id'),
        description: any(named: 'description'),
        workspaceId: any(named: 'workspaceId'),
        folderId: any(named: 'folderId'),
        sendFolder: any(named: 'sendFolder'),
        sortOrder: any(named: 'sortOrder'),
        deduplicate: any(named: 'deduplicate'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => pending.future);
    ops.createWorkflow(folderId: 'f-ops');
    expect(h.navigator.visited.single, '/workspace/$workspaceId/w/new-0');
    expect(h.tree.state.isExpanded('f-ops'), isTrue);
    expect(ops.isCreatingWorkflow.value, isTrue);
    expect(h.workflows.state.creatingWorkflowId, 'new-0');
    final row = h.workflows.state.items.firstWhere((w) => w.id == 'new-0');
    expect(row.folderId, 'f-ops');
    expect(row.name, matches(RegExp(r'^[a-z]+-[a-z]+$')));
    pending.completeError(serverError('boom'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(ops.isCreatingWorkflow.value, isFalse);
  });

  test('in-folder create folder: "Subfolder N" and an error toast', () async {
    when(
      () => h.foldersRepo.list(
        workspaceId: workspaceId,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => <Folder>[
        ...seedFolders(),
        fd('s', name: 'Subfolder 4', parentId: 'f-e2e'),
        fd('t', name: 'Subfolder 9'),
      ],
    );
    when(
      () => h.foldersRepo.create(
        name: any(named: 'name'),
        workspaceId: any(named: 'workspaceId'),
        id: any(named: 'id'),
        parentId: any(named: 'parentId'),
        sortOrder: any(named: 'sortOrder'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => throw serverError('Name taken'));
    await ops.createFolder(parentId: 'f-e2e');
    verify(
      () => h.foldersRepo.create(
        name: 'Subfolder 5',
        workspaceId: workspaceId,
        id: 'new-0',
        parentId: 'f-e2e',
        sortOrder: any(named: 'sortOrder'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    expect(h.toasts.toasts.single.message, 'Name taken');
    expect(ops.isCreatingFolder.value, isFalse);
  });

  test('the tree cubit is untouched by an empty selection', () async {
    stubReorders();
    await ops.drop(
      const DragSelection(workflowIds: <String>[], folderIds: <String>[]),
      beforeEmpty,
    );
    expect(h.tree.state, const SidebarTreeState());
  });
}
