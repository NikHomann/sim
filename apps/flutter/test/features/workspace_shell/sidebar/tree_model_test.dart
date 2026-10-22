// Failure modes of the tree model (sidebar-workflow-tree.md §Ordering,
// §Rows, §States):
// 1. compareByOrder: sortOrder first, then createdAt, then id — a tie on
//    sortOrder must not fall back to name or list order;
// 2. folders and workflows interleave in ONE sibling list (folders are not
//    hoisted above workflows);
// 3. rows of other workspaces never render; a workflow in an unknown folder
//    never renders; a folder whose parent is missing never renders;
// 4. the DFS orders the selection ranges walk follow the rendered order;
// 5. effective lock: own flag or any ancestor; inherited lock excludes own;
// 6. folderPath survives a cycle written by an optimistic reorder;
// 7. canDelete refuses removing every workflow; empty folders always go;
// 8. naming: "Folder N"/"Subfolder N" one past the highest, "X Copy",
//    "X Copy 2"…; selection labels pluralise as "N items".

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_model.dart';

import 'support/harness.dart';

SidebarTree tree(List<Object> rows) => SidebarTree(
  workspaceId: workspaceId,
  folders: rows.whereType<Folder>().toList(),
  workflows: rows.whereType<WorkflowListItem>().toList(),
);

void main() {
  group('ordering', () {
    test('sortOrder, then createdAt, then id', () {
      final t = tree(<Object>[
        wf('b', sortOrder: 1, createdAt: '2026-01-02T00:00:00Z'),
        wf('a', sortOrder: 1, createdAt: '2026-01-02T00:00:00Z'),
        wf('c', sortOrder: 1, createdAt: '2026-01-01T00:00:00Z'),
        wf('z', sortOrder: -1),
      ]);
      expect(t.rootEntries.map((e) => e.id), <String>['z', 'c', 'a', 'b']);
    });

    test('folders and workflows interleave by order', () {
      final t = tree(<Object>[
        fd('f1', sortOrder: 2),
        wf('w1', sortOrder: 1),
        wf('w2', sortOrder: 3),
        fd('f0'),
      ]);
      expect(t.rootEntries.map((e) => e.id), <String>['f0', 'w1', 'f1', 'w2']);
    });

    test('foreign workspace rows, orphans and missing parents are dropped', () {
      final t = SidebarTree(
        workspaceId: workspaceId,
        folders: <Folder>[
          fd('f1'),
          fd('child', parentId: 'gone'),
        ],
        workflows: <WorkflowListItem>[
          wf('w1'),
          wf('w-orphan', folderId: 'gone'),
          const WorkflowListItem(
            id: 'other',
            name: 'other',
            description: '',
            workspaceId: otherWorkspaceId,
            folderId: null,
            sortOrder: 0,
            createdAt: created,
            updatedAt: created,
            archivedAt: null,
            locked: false,
          ),
        ],
      );
      expect(t.rootEntries.map((e) => e.id), <String>['f1', 'w1']);
      expect(t.orderedWorkflowIds, <String>['w1']);
      expect(t.node('child'), isNull);
    });

    test('DFS orders follow the rendered tree', () {
      final t = tree(<Object>[
        fd('a'),
        fd('a1', parentId: 'a', sortOrder: 1),
        wf('wa', folderId: 'a'),
        wf('wa1', folderId: 'a1'),
        wf('root', sortOrder: 5),
        fd('b', sortOrder: 9),
      ]);
      expect(t.orderedWorkflowIds, <String>['wa', 'wa1', 'root']);
      expect(t.orderedFolderIds, <String>['a', 'a1', 'b']);
      expect(t.folderAncestors['a1'], <String>['a']);
      expect(t.folderDescendants['a'], <String>['a1']);
      expect(t.folderDescendantWorkflows['a'], <String>['wa', 'wa1']);
      expect(t.workflowAncestors['wa1'], <String>['a1', 'a']);
    });
  });

  group('locks', () {
    test('effective lock is own or inherited; inherited excludes own', () {
      final t = tree(<Object>[
        fd('top', locked: true),
        fd('mid', parentId: 'top'),
        fd('own', locked: true),
        wf('deep', folderId: 'mid'),
      ]);
      expect(t.folderEffectivelyLocked(t.folders['mid']!), isTrue);
      expect(t.folderInheritedLocked(t.folders['mid']!), isTrue);
      expect(t.folderEffectivelyLocked(t.folders['own']!), isTrue);
      expect(t.folderInheritedLocked(t.folders['own']!), isFalse);
      expect(t.workflowEffectivelyLocked(t.workflow('deep')!), isTrue);
    });

    test('folderPath stops on a cycle', () {
      final t = tree(<Object>[
        fd('x', parentId: 'y'),
        fd('y', parentId: 'x'),
      ]);
      expect(t.folderPath('x').map((f) => f.id), <String>['y', 'x']);
      expect(t.isFolderOrAncestorLocked('x'), isFalse);
    });
  });

  group('can delete', () {
    test('refuses removing every workflow of the workspace', () {
      final t = tree(<Object>[
        fd('f'),
        fd('empty'),
        wf('a', folderId: 'f'),
        wf('b'),
      ]);
      expect(t.canDeleteWorkflows(<String>['a']), isTrue);
      expect(t.canDeleteWorkflows(<String>['a', 'b']), isFalse);
      expect(t.canDeleteFolder('f'), isTrue);
      expect(t.canDeleteFolder('empty'), isTrue);
      final all = tree(<Object>[fd('f'), wf('a', folderId: 'f')]);
      expect(all.canDeleteFolder('f'), isFalse);
      expect(tree(<Object>[]).canDeleteWorkflows(<String>[]), isFalse);
    });
  });

  group('naming', () {
    test('incremental names go one past the highest match', () {
      expect(nextIncrementalName(<String>[], 'Folder'), 'Folder 1');
      expect(
        nextIncrementalName(<String>[
          'Folder 2',
          'Folder 9x',
          'Folder 7',
        ], 'Folder'),
        'Folder 8',
      );
      expect(
        nextIncrementalName(<String>['Subfolder 1', 'Folder 4'], 'Subfolder'),
        'Subfolder 2',
      );
    });

    test('folder duplicates avoid sibling names', () {
      expect(duplicateFolderName('Ops', <String>{'Ops'}), 'Ops Copy');
      expect(
        duplicateFolderName(' Ops ', <String>{'Ops', 'Ops Copy', 'Ops Copy 2'}),
        'Ops Copy 3',
      );
      expect(duplicateFolderName('', <String>{}), 'Untitled Folder Copy');
    });

    test('selection labels', () {
      expect(selectionActionLabel('Delete', 1), 'Delete');
      expect(selectionActionLabel('Delete', 0), 'Delete');
      expect(selectionActionLabel('Export', 3), 'Export 3 items');
    });
  });
}
