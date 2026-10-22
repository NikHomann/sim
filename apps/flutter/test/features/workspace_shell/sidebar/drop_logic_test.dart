// Failure modes of drag and drop resolution (use-drag-drop.ts):
// 1. bands: a workflow row splits at its midpoint; a folder row is
//    25/50/25 (before / inside / after) with the boundaries exclusive the
//    way `<`/`>` are upstream;
// 2. scope: over a row of another folder the drop goes "inside" that
//    folder (its end) instead of drawing a line; only a folder's middle
//    band (or any band when out of scope) arms hover-expand;
// 3. normalisation rewrites "after X" to "before next sibling", but never
//    after the last sibling or for the root target;
// 4. insert index resolves against the full sibling list, so a line drawn
//    against a dragged row still lands where it was drawn;
// 5. the plan re-indexes the WHOLE destination level 0..n-1, rows already
//    there first, and splits folder vs workflow payloads (parentId /
//    folderId = destination, null at root);
// 6. invalid drops: a folder into itself or a descendant is dropped from
//    the selection; nothing valid left → no plan; empty selection → none.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/drop_logic.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_model.dart';

import 'support/harness.dart';

SidebarTree tree(List<Object> rows) => SidebarTree(
  workspaceId: workspaceId,
  folders: rows.whereType<Folder>().toList(),
  workflows: rows.whereType<WorkflowListItem>().toList(),
);

DropIndicator ind(String target, DropPosition p, [String? folder]) =>
    DropIndicator(targetId: target, position: p, folderId: folder);

void main() {
  group('bands', () {
    test('workflow rows split at the midpoint', () {
      expect(workflowRowBand(14.9, 30), DropPosition.before);
      expect(workflowRowBand(15, 30), DropPosition.after);
    });

    test('folder rows are 25 / 50 / 25', () {
      expect(folderRowBand(7.4, 30), DropPosition.before);
      expect(folderRowBand(7.5, 30), DropPosition.inside);
      expect(folderRowBand(22.5, 30), DropPosition.inside);
      expect(folderRowBand(22.6, 30), DropPosition.after);
    });

    test('out-of-scope workflow rows target their folder, inside', () {
      final same = workflowRowIndicator(
        workflowId: 'w',
        folderId: 'f',
        sourceFolderId: 'f',
        dy: 1,
        height: 30,
      );
      expect(same, ind('w', DropPosition.before, 'f'));
      final other = workflowRowIndicator(
        workflowId: 'w',
        folderId: 'f',
        sourceFolderId: null,
        dy: 1,
        height: 30,
      );
      expect(other, ind('f', DropPosition.inside));
      final rootRow = workflowRowIndicator(
        workflowId: 'w',
        folderId: null,
        sourceFolderId: 'f',
        dy: 1,
        height: 30,
      );
      expect(rootRow, ind(rootDropTarget, DropPosition.inside));
    });

    test('folder rows arm hover only for "inside"', () {
      final edge = folderRowIndicator(
        folderId: 'f',
        parentFolderId: null,
        sourceFolderId: null,
        dy: 2,
        height: 30,
      );
      expect(edge.indicator, ind('f', DropPosition.before));
      expect(edge.hover, isFalse);
      final middle = folderRowIndicator(
        folderId: 'f',
        parentFolderId: null,
        sourceFolderId: null,
        dy: 15,
        height: 30,
      );
      expect(middle.hover, isTrue);
      final foreign = folderRowIndicator(
        folderId: 'f',
        parentFolderId: null,
        sourceFolderId: 'elsewhere',
        dy: 2,
        height: 30,
      );
      expect(foreign.indicator, ind('f', DropPosition.inside));
      expect(foreign.hover, isTrue);
    });
  });

  group('normalisation', () {
    final t = tree(<Object>[
      wf('a'),
      fd('b', sortOrder: 1),
      wf('c', sortOrder: 2),
    ]);

    test('"after X" becomes "before next sibling"', () {
      expect(
        normalizeIndicator(ind('a', DropPosition.after), t.siblingsOf),
        ind('b', DropPosition.before),
      );
    });

    test('the last sibling and the root keep "after"/"inside"', () {
      expect(
        normalizeIndicator(ind('c', DropPosition.after), t.siblingsOf),
        ind('c', DropPosition.after),
      );
      final root = ind(rootDropTarget, DropPosition.inside);
      expect(normalizeIndicator(root, t.siblingsOf), root);
    });
  });

  group('insert index', () {
    final siblings = <SiblingItem>[
      for (final (i, id) in <String>['a', 'b', 'c', 'd'].indexed)
        SiblingItem(
          kind: SiblingKind.workflow,
          id: id,
          sortOrder: i,
          createdAt: null,
        ),
    ];

    test('a line against the dragged row resolves on the full list', () {
      expect(
        insertIndexInRemaining(siblings, <String>{
          'b',
        }, ind('b', DropPosition.before)),
        1,
      );
      expect(
        insertIndexInRemaining(siblings, <String>{
          'b',
        }, ind('c', DropPosition.after)),
        2,
      );
      expect(
        insertIndexInRemaining(siblings, <String>{
          'a',
        }, ind('x', DropPosition.before)),
        3,
      );
      expect(
        insertIndexInRemaining(siblings, <String>{
          'a',
        }, ind('d', DropPosition.inside)),
        3,
      );
    });
  });

  group('plan', () {
    test('re-indexes the whole level and splits the payloads', () {
      final t = tree(<Object>[
        fd('f1'),
        wf('w1', sortOrder: 1),
        fd('f2', sortOrder: 2),
        wf('w2', sortOrder: 3),
        fd('inner', parentId: 'f1'),
        wf('child', folderId: 'f1', sortOrder: 5),
      ]);
      final plan = planDrop(
        tree: t,
        selection: const DragSelection(
          workflowIds: <String>['child', 'w2'],
          folderIds: <String>[],
        ),
        indicator: ind('w1', DropPosition.before),
      )!;
      expect(plan.destinationFolderId, isNull);
      expect(plan.order.map((s) => s.id), <String>[
        'f1',
        'w2',
        'child',
        'w1',
        'f2',
      ]);
      expect(
        plan.folderUpdates.map((u) => u.toJson()),
        <Map<String, Object?>>[
          <String, Object?>{'id': 'f1', 'sortOrder': 0, 'parentId': null},
          <String, Object?>{'id': 'f2', 'sortOrder': 4, 'parentId': null},
        ],
      );
      expect(
        plan.workflowUpdates.map((u) => u.toJson()),
        <Map<String, Object?>>[
          <String, Object?>{'id': 'w2', 'sortOrder': 1, 'folderId': null},
          <String, Object?>{'id': 'child', 'sortOrder': 2, 'folderId': null},
          <String, Object?>{'id': 'w1', 'sortOrder': 3, 'folderId': null},
        ],
      );
    });

    test('dropping inside a folder appends and targets that folder', () {
      final t = tree(<Object>[
        fd('f1'),
        wf('a', folderId: 'f1'),
        wf('loose', sortOrder: 4),
      ]);
      final plan = planDrop(
        tree: t,
        selection: const DragSelection(
          workflowIds: <String>['loose'],
          folderIds: <String>[],
        ),
        indicator: ind('f1', DropPosition.inside),
      )!;
      expect(plan.destinationFolderId, 'f1');
      expect(plan.order.map((s) => s.id), <String>['a', 'loose']);
      expect(plan.folderUpdates, isEmpty);
      expect(plan.workflowUpdates.last.toJson(), <String, Object?>{
        'id': 'loose',
        'sortOrder': 1,
        'folderId': 'f1',
      });
    });

    test('a folder into itself or a descendant is refused', () {
      final t = tree(<Object>[
        fd('a'),
        fd('b', parentId: 'a'),
        fd('c', parentId: 'b'),
        wf('w'),
      ]);
      expect(canMoveFolderTo(t, 'a', 'a'), isFalse);
      expect(canMoveFolderTo(t, 'a', 'c'), isFalse);
      expect(canMoveFolderTo(t, 'c', 'a'), isTrue);
      expect(canMoveFolderTo(t, 'c', null), isTrue);
      expect(
        planDrop(
          tree: t,
          selection: const DragSelection(
            workflowIds: <String>[],
            folderIds: <String>['a'],
          ),
          indicator: ind('c', DropPosition.inside),
        ),
        isNull,
      );
      final mixed = planDrop(
        tree: t,
        selection: const DragSelection(
          workflowIds: <String>['w'],
          folderIds: <String>['a'],
        ),
        indicator: ind('c', DropPosition.inside),
      )!;
      expect(mixed.folderUpdates, isEmpty);
      expect(mixed.workflowUpdates.single.id, 'w');
      expect(
        planDrop(
          tree: t,
          selection: const DragSelection(
            workflowIds: <String>[],
            folderIds: <String>[],
          ),
          indicator: ind('a', DropPosition.inside),
        ),
        isNull,
      );
    });
  });
}
