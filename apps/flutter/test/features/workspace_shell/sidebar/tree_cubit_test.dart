// Failure modes of the tree UI state (stores/folders/store.ts,
// use-*-selection.ts, use-drag-drop.ts):
// 1. Shift ranges anchor on the ACTIVE ROUTE workflow (not the last click)
//    and deselect ancestor folders; without an anchor Shift toggles;
// 2. Cmd/Ctrl on a folder toggles and the clicked folder wins over its
//    selected ancestors/descendants; Shift ranges keep the ancestor;
//    workflows inside selected folders are deselected;
// 3. Finder capture: a row outside the selection replaces it; a selected
//    row acts on everything; drag payloads follow the same rule;
// 4. hover-expand: 400 ms on a COLLAPSED folder's middle band, cancelled by
//    leaving it, never for an expanded folder, never after drag end;
// 5. drag end collapses spring-opened folders except the drop destination
//    and its ancestors; folders the user opened stay open;
// 6. equal indicators do not re-emit; revealActiveWorkflow expands the
//    path and selects without clobbering an existing multi-selection;
// 7. chat selection (`selectChatOnly`, `toggleChatSelection`,
//    `selectChatRange`): Shift ranges from the anchor, Shift on the anchor
//    toggles and moves the anchor to another selected chat (or none), and
//    toggling a workflow or folder clears the chats.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/drop_logic.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_cubit.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_model.dart';

import 'support/harness.dart';

SidebarTree tree(List<Object> rows) => SidebarTree(
  workspaceId: workspaceId,
  folders: rows.whereType<Folder>().toList(),
  workflows: rows.whereType<WorkflowListItem>().toList(),
);

void main() {
  late SidebarTreeCubit cubit;
  final t = tree(<Object>[
    fd('a'),
    fd('a1', parentId: 'a'),
    wf('wa', folderId: 'a', sortOrder: 1),
    wf('w1', sortOrder: 1),
    wf('w2', sortOrder: 2),
    wf('w3', sortOrder: 3),
    fd('b', sortOrder: 4),
  ]);

  setUp(() => cubit = SidebarTreeCubit());
  tearDown(() => cubit.close());

  group('workflow selection', () {
    test('Shift ranges from the active route workflow', () {
      cubit
        ..selectOnly('w3')
        ..workflowClick(t, 'w2', shift: true, activeWorkflowId: 'wa');
      expect(cubit.state.selectedWorkflows, <String>{'wa', 'w1', 'w2'});
    });

    test('Shift without an anchor toggles; ancestor folders drop out', () {
      cubit
        ..selectFolder('a')
        ..workflowClick(t, 'wa', shift: true);
      expect(cubit.state.selectedWorkflows, <String>{'wa'});
      expect(cubit.state.selectedFolders, isEmpty);
      cubit.workflowClick(t, 'wa', shift: true);
      expect(cubit.state.selectedWorkflows, isEmpty);
    });

    test('a plain click selects only that row and clears folders', () {
      cubit
        ..selectFolder('b')
        ..workflowClick(t, 'w1', shift: false, activeWorkflowId: 'w2');
      expect(cubit.state.selectedWorkflows, <String>{'w1'});
      expect(cubit.state.selectedFolders, isEmpty);
    });
  });

  group('folder selection', () {
    test('Cmd toggles and the clicked folder wins over its relatives', () {
      cubit
        ..folderClick(t, 'a', shift: false, meta: true)
        ..folderClick(t, 'a1', shift: false, meta: true);
      expect(cubit.state.selectedFolders, <String>{'a1'});
      cubit.folderClick(t, 'a1', shift: false, meta: true);
      expect(cubit.state.selectedFolders, isEmpty);
    });

    test('Shift ranges from the anchor and keeps ancestors only', () {
      cubit
        ..folderClick(t, 'a', shift: false, meta: false)
        ..folderClick(t, 'b', shift: true, meta: false);
      expect(cubit.state.selectedFolders, <String>{'a', 'b'});
      expect(cubit.state.lastSelectedFolderId, 'a');
    });

    test('workflows inside selected folders are deselected', () {
      cubit
        ..selectOnly('wa')
        ..folderClick(t, 'a', shift: false, meta: true);
      expect(cubit.state.selectedWorkflows, isEmpty);
    });
  });

  group('capture', () {
    test('an unselected row replaces the selection', () {
      cubit
        ..selectOnly('w1')
        ..toggleWorkflowSelection('w2');
      final outside = cubit.captureForFolder('b');
      expect(outside.folderIds, <String>['b']);
      expect(outside.workflowIds, isEmpty);
    });

    test('a selected row acts on the whole selection', () {
      cubit
        ..selectOnly('w1')
        ..toggleWorkflowSelection('w2')
        ..selectFolder('b');
      final inside = cubit.captureForWorkflow('w2');
      expect(inside.isMixed, isTrue);
      expect(inside.count, 3);
      final drag = cubit.dragSelectionFor(id: 'w1', isFolder: false);
      expect(drag.total, 3);
      final lone = cubit.dragSelectionFor(id: 'a', isFolder: true);
      expect(lone.folderIds, <String>['a']);
      expect(lone.workflowIds, isEmpty);
    });
  });

  group('drag', () {
    test('hover-expand fires at 400 ms and is cancelled by leaving', () {
      fakeAsync((async) {
        cubit
          ..dragStart(sourceFolderId: null, draggingIds: <String>{'w1'})
          ..setHoverFolder('b');
        async.elapse(const Duration(milliseconds: 399));
        expect(cubit.state.isExpanded('b'), isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(cubit.state.isExpanded('b'), isTrue);

        cubit
          ..setHoverFolder('a')
          ..setHoverFolder(null);
        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.isExpanded('a'), isFalse);
      });
    });

    test('no timer for an expanded folder or after drag end', () {
      fakeAsync((async) {
        cubit
          ..setExpanded('a', expanded: true)
          ..dragStart(sourceFolderId: null, draggingIds: <String>{'w1'})
          ..setHoverFolder('a')
          ..setHoverFolder('b')
          ..dragEnd();
        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.isExpanded('b'), isFalse);
        expect(cubit.state.isExpanded('a'), isTrue);
      });
    });

    test('drag end closes spring-opened folders except the destination', () {
      fakeAsync((async) {
        final nested = tree(<Object>[
          fd('p'),
          fd('q', parentId: 'p'),
          fd('r'),
        ]);
        cubit
          ..setExpanded('r', expanded: true)
          ..dragStart(sourceFolderId: null, draggingIds: <String>{'w'})
          ..setHoverFolder('p');
        async.elapse(hoverExpandDelay);
        cubit.setHoverFolder('q');
        async.elapse(hoverExpandDelay);
        cubit.setIndicator(
          const DropIndicator(
            targetId: 'q',
            position: DropPosition.inside,
            folderId: 'p',
          ),
          nested.siblingsOf,
        );
        final indicator = cubit.takeDrop(nested);
        cubit.dragEnd();
        expect(indicator?.destinationFolderId, 'q');
        expect(cubit.state.expandedFolders, <String>{'r', 'p', 'q'});
        expect(cubit.state.isDragging, isFalse);
        expect(cubit.state.dropIndicator, isNull);
      });
    });

    test('a cancelled drag closes every spring-opened folder', () {
      fakeAsync((async) {
        cubit
          ..dragStart(sourceFolderId: null, draggingIds: <String>{'w'})
          ..setHoverFolder('b');
        async.elapse(hoverExpandDelay);
        cubit.dragEnd();
        expect(cubit.state.isExpanded('b'), isFalse);
      });
    });

    test('equal indicators do not re-emit', () async {
      final emitted = <SidebarTreeState>[];
      final sub = cubit.stream.listen(emitted.add);
      const indicator = DropIndicator(
        targetId: 'w2',
        position: DropPosition.before,
        folderId: null,
      );
      cubit
        ..setIndicator(indicator, t.siblingsOf)
        ..setIndicator(indicator, t.siblingsOf);
      await Future<void>.delayed(Duration.zero);
      expect(emitted, hasLength(1));
      await sub.cancel();
    });
  });

  test('revealing the active workflow expands its path and selects it', () {
    cubit.revealActiveWorkflow(t, 'wa');
    expect(cubit.state.expandedFolders, <String>{'a'});
    expect(cubit.state.selectedWorkflows, <String>{'wa'});
    cubit
      ..toggleWorkflowSelection('w1')
      ..revealActiveWorkflow(t, 'wa');
    expect(cubit.state.selectedWorkflows, <String>{'wa', 'w1'});
  });

  group('7. chat selection', () {
    const ids = <String>['c1', 'c2', 'c3', 'c4'];

    test('Shift ranges from the anchor; on the anchor it toggles', () {
      cubit
        ..chatClick(ids, 'c2', shift: false)
        ..chatClick(ids, 'c4', shift: true);
      expect(cubit.state.selectedChats, <String>{'c2', 'c3', 'c4'});
      expect(cubit.state.lastSelectedChatId, 'c2');
      cubit.chatClick(ids, 'c2', shift: true);
      expect(cubit.state.selectedChats, <String>{'c3', 'c4'});
      expect(cubit.state.lastSelectedChatId, 'c3');
    });

    test('toggling a chat in moves the anchor to it', () {
      cubit
        ..selectChatOnly('c1')
        ..toggleChatSelection('c3');
      expect(cubit.state.lastSelectedChatId, 'c3');
      cubit.chatClick(ids, 'c4', shift: true);
      expect(cubit.state.selectedChats, <String>{'c3', 'c4'});
    });

    test('workflow and folder toggles clear the chats', () {
      cubit
        ..selectChatOnly('c1')
        ..toggleWorkflowSelection('w1');
      expect(cubit.state.selectedChats, isEmpty);
      expect(cubit.state.lastSelectedChatId, isNull);
      cubit
        ..selectChatOnly('c1')
        ..folderClick(t, 'a', shift: false, meta: true);
      expect(cubit.state.selectedChats, isEmpty);
      expect(cubit.state.selectedWorkflows, isEmpty);
    });
  });
}
