import 'package:sim_workflow/src/model/block_state.dart';

/// Port of `isWorkflowBlockAncestorLocked` from
/// `packages/workflow-types/src/workflow.ts`: walks `data.parentId` upward,
/// stopping on a cycle or a missing parent.
bool isWorkflowBlockAncestorLocked(
  String blockId,
  Map<String, BlockState> blocks,
) {
  final visited = <String>{};
  var parentId = blocks[blockId]?.parentId;

  while (parentId != null && !visited.contains(parentId)) {
    visited.add(parentId);
    final parent = blocks[parentId];
    if (parent == null) return false;
    if (parent.locked ?? false) return true;
    parentId = parent.parentId;
  }

  return false;
}

/// Port of `isWorkflowBlockProtected`: locked directly or by an ancestor.
bool isWorkflowBlockProtected(String blockId, Map<String, BlockState> blocks) {
  final block = blocks[blockId];
  if (block == null) return false;
  return (block.locked ?? false) ||
      isWorkflowBlockAncestorLocked(blockId, blocks);
}
