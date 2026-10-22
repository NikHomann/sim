import 'package:sim_api/sim_api.dart';

/// `getTopInsertionSortOrder` (`hooks/queries/utils/top-insertion-sort-order.ts`):
/// the sort order that places a new item at the top of the mixed
/// folder/workflow list under [parentId] in [workspaceId]: one less than the
/// lowest sibling order, or `0` when there are no siblings.
num getTopInsertionSortOrder({
  required Iterable<WorkflowListItem> workflows,
  required Iterable<Folder> folders,
  required String workspaceId,
  required String? parentId,
}) {
  final siblingOrders = <num>[
    for (final workflow in workflows)
      if (workflow.workspaceId == workspaceId && workflow.folderId == parentId)
        workflow.sortOrder,
    for (final folder in folders)
      if (folder.workspaceId == workspaceId && folder.parentId == parentId)
        folder.sortOrder,
  ];
  if (siblingOrders.isEmpty) return 0;
  return siblingOrders.reduce((a, b) => a < b ? a : b) - 1;
}
