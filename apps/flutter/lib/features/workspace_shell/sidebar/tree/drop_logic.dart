import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_model.dart';

/// Where a drop lands relative to its target.
enum DropPosition { before, after, inside }

/// The id the root scope uses as a drop target.
const String rootDropTarget = 'root';

/// `DropIndicator` of `use-drag-drop.ts`: the target row (or [rootDropTarget]),
/// the position, and the folder scope the target sits in.
@immutable
class DropIndicator {
  const DropIndicator({
    required this.targetId,
    required this.position,
    required this.folderId,
  });

  final String targetId;
  final DropPosition position;
  final String? folderId;

  /// `getDestinationFolderId`: the target itself when dropping inside one,
  /// otherwise its scope.
  String? get destinationFolderId => position == DropPosition.inside
      ? (targetId == rootDropTarget ? null : targetId)
      : folderId;

  @override
  bool operator ==(Object other) =>
      other is DropIndicator &&
      other.targetId == targetId &&
      other.position == position &&
      other.folderId == folderId;

  @override
  int get hashCode => Object.hash(targetId, position, folderId);

  @override
  String toString() =>
      'DropIndicator($targetId, ${position.name}, folder: $folderId)';
}

/// `calculateDropPosition`: which half of a workflow row the pointer is in.
DropPosition workflowRowBand(double dy, double height) =>
    dy < height / 2 ? DropPosition.before : DropPosition.after;

/// `calculateFolderDropPosition`: top 25 % before, bottom 25 % after, the
/// middle 50 % inside.
DropPosition folderRowBand(double dy, double height) {
  if (dy < height * 0.25) return DropPosition.before;
  if (dy > height * 0.75) return DropPosition.after;
  return DropPosition.inside;
}

/// The indicator a workflow row produces (`createWorkflowDragHandlers`):
/// a line by midpoint inside the drag's own scope, otherwise "inside" the
/// row's folder (its end).
DropIndicator workflowRowIndicator({
  required String workflowId,
  required String? folderId,
  required String? sourceFolderId,
  required double dy,
  required double height,
}) {
  if (sourceFolderId == folderId) {
    return DropIndicator(
      targetId: workflowId,
      position: workflowRowBand(dy, height),
      folderId: folderId,
    );
  }
  return DropIndicator(
    targetId: folderId ?? rootDropTarget,
    position: DropPosition.inside,
    folderId: null,
  );
}

/// The indicator a folder row produces (`createFolderDragHandlers`) and
/// whether it arms the hover-expand timer.
({DropIndicator indicator, bool hover}) folderRowIndicator({
  required String folderId,
  required String? parentFolderId,
  required String? sourceFolderId,
  required double dy,
  required double height,
}) {
  if (sourceFolderId == parentFolderId) {
    final position = folderRowBand(dy, height);
    return (
      indicator: DropIndicator(
        targetId: folderId,
        position: position,
        folderId: parentFolderId,
      ),
      hover: position == DropPosition.inside,
    );
  }
  return (
    indicator: DropIndicator(
      targetId: folderId,
      position: DropPosition.inside,
      folderId: parentFolderId,
    ),
    hover: true,
  );
}

/// `setNormalizedDropIndicator`: "after X" becomes "before next sibling of X"
/// when X has a next sibling, so the line is always drawn above a row except
/// after the last sibling.
DropIndicator normalizeIndicator(
  DropIndicator indicator,
  List<SiblingItem> Function(String? folderId) siblingsOf,
) {
  if (indicator.position != DropPosition.after ||
      indicator.targetId == rootDropTarget) {
    return indicator;
  }
  final siblings = siblingsOf(indicator.folderId);
  final index = siblings.indexWhere((s) => s.id == indicator.targetId);
  if (index == -1 || index + 1 >= siblings.length) return indicator;
  return DropIndicator(
    targetId: siblings[index + 1].id,
    position: DropPosition.before,
    folderId: indicator.folderId,
  );
}

/// `getInsertIndexInRemaining`: the insert index into the siblings left
/// once the moving items are removed. The lookup runs on the full list so a
/// line drawn against a dragged row still resolves.
int insertIndexInRemaining(
  List<SiblingItem> siblings,
  Set<String> movingIds,
  DropIndicator indicator,
) {
  int remainingBefore(int end) =>
      siblings.take(end).where((s) => !movingIds.contains(s.id)).length;
  if (indicator.position == DropPosition.inside) {
    return remainingBefore(siblings.length);
  }
  final target = siblings.indexWhere((s) => s.id == indicator.targetId);
  if (target == -1) return remainingBefore(siblings.length);
  if (indicator.position == DropPosition.before) return remainingBefore(target);
  return remainingBefore(target + 1);
}

/// `canMoveFolderTo`: never into itself or one of its descendants.
bool canMoveFolderTo(
  SidebarTree tree,
  String folderId,
  String? destinationFolderId,
) {
  if (folderId == destinationFolderId) return false;
  if (destinationFolderId == null) return true;
  return !tree.folderPath(destinationFolderId).any((f) => f.id == folderId);
}

/// The two reorder payloads of one drop: every sibling of the destination
/// level re-indexed `0..n-1`, split by kind (`buildAndSubmitUpdates`).
@immutable
class ReorderPlan {
  const ReorderPlan({
    required this.destinationFolderId,
    required this.order,
    required this.folderUpdates,
    required this.workflowUpdates,
  });

  final String? destinationFolderId;

  /// The new sibling order of the destination level.
  final List<SiblingItem> order;
  final List<FolderReorderUpdate> folderUpdates;
  final List<WorkflowReorderUpdate> workflowUpdates;
}

/// A drag payload: the rows that move (`sidebar-selection`).
@immutable
class DragSelection {
  const DragSelection({required this.workflowIds, required this.folderIds});

  final List<String> workflowIds;
  final List<String> folderIds;

  int get total => workflowIds.length + folderIds.length;
}

/// `handleSelectionDrop` up to the requests: resolves the destination,
/// drops folders that cannot move there, interleaves the moving rows at the
/// insert index (rows already in the destination first, then the rest, each
/// group in sibling order) and re-indexes the level. `null` when nothing
/// valid moves.
ReorderPlan? planDrop({
  required SidebarTree tree,
  required DragSelection selection,
  required DropIndicator indicator,
}) {
  if (selection.total == 0) return null;
  final destination = indicator.destinationFolderId;
  final validFolders = selection.folderIds
      .where((id) => canMoveFolderTo(tree, id, destination))
      .toList();
  if (selection.workflowIds.isEmpty && validFolders.isEmpty) return null;

  final siblings = tree.siblingsOf(destination);
  final movingIds = <String>{...selection.workflowIds, ...validFolders};
  final remaining = [
    for (final s in siblings)
      if (!movingIds.contains(s.id)) s,
  ];

  final fromDestination = <SiblingItem>[];
  final fromOther = <SiblingItem>[];
  for (final id in selection.workflowIds) {
    final workflow = tree.workflow(id);
    if (workflow == null) continue;
    final item = SiblingItem(
      kind: SiblingKind.workflow,
      id: id,
      sortOrder: workflow.sortOrder,
      createdAt: workflow.createdAtDate,
    );
    (workflow.folderId == destination ? fromDestination : fromOther).add(item);
  }
  for (final id in validFolders) {
    final folder = tree.folders[id];
    if (folder == null) continue;
    final item = SiblingItem(
      kind: SiblingKind.folder,
      id: id,
      sortOrder: folder.sortOrder,
      createdAt: folder.createdAtDate,
    );
    (folder.parentId == destination ? fromDestination : fromOther).add(item);
  }
  int byOrder(SiblingItem a, SiblingItem b) =>
      compareByOrder(a.orderKey, b.orderKey);
  fromDestination.sort(byOrder);
  fromOther.sort(byOrder);

  final insertAt = insertIndexInRemaining(siblings, movingIds, indicator);
  final order = <SiblingItem>[
    ...remaining.take(insertAt),
    ...fromDestination,
    ...fromOther,
    ...remaining.skip(insertAt),
  ];

  final folderUpdates = <FolderReorderUpdate>[];
  final workflowUpdates = <WorkflowReorderUpdate>[];
  for (var i = 0; i < order.length; i++) {
    final item = order[i];
    if (item.kind == SiblingKind.folder) {
      folderUpdates.add(
        FolderReorderUpdate(
          id: item.id,
          sortOrder: i,
          parentId: destination,
          clearParent: destination == null,
        ),
      );
    } else {
      workflowUpdates.add(
        WorkflowReorderUpdate(
          id: item.id,
          sortOrder: i,
          folderId: destination,
          clearFolder: destination == null,
        ),
      );
    }
  }
  return ReorderPlan(
    destinationFolderId: destination,
    order: order,
    folderUpdates: folderUpdates,
    workflowUpdates: workflowUpdates,
  );
}
