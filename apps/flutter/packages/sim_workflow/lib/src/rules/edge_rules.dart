/// Ports of the edge rules in `packages/workflow-types/src/workflow.ts`,
/// shared upstream between the client store, the collaborative queue and
/// the realtime persistence layer so all three agree on the same edges.
library;

import 'package:sim_workflow/src/model/block_state.dart';
import 'package:sim_workflow/src/model/edge.dart';
import 'package:sim_workflow/src/model/subflow.dart';
import 'package:sim_workflow/src/rules/handles.dart';

/// Port of `wouldCreateCycle`: DFS reachability from the proposed target back
/// to the proposed source; a self-loop is always a cycle.
bool wouldCreateCycle(
  Iterable<EdgeEndpoints> edges,
  String sourceId,
  String targetId,
) {
  if (sourceId == targetId) return true;

  final adjacency = <String, List<String>>{};
  for (final edge in edges) {
    adjacency.putIfAbsent(edge.source, () => []).add(edge.target);
  }

  final visited = <String>{};
  bool canReachSource(String current) {
    if (current == sourceId) return true;
    if (!visited.add(current)) return false;
    for (final neighbor in adjacency[current] ?? const <String>[]) {
      if (canReachSource(neighbor)) return true;
    }
    return false;
  }

  return canReachSource(targetId);
}

/// Port of `filterAcyclicEdges`: incremental, so edges within one batch that
/// chain into a cycle are also rejected.
List<T> filterAcyclicEdges<T extends EdgeEndpoints>(
  List<T> edgesToAdd,
  Iterable<EdgeEndpoints> currentEdges,
) {
  final working = <EdgeEndpoints>[...currentEdges];
  final acyclic = <T>[];
  for (final edge in edgesToAdd) {
    if (wouldCreateCycle(working, edge.source, edge.target)) continue;
    working.add(edge);
    acyclic.add(edge);
  }
  return acyclic;
}

/// Port of `isDuplicateWorkflowEdge`.
bool _isDuplicateWorkflowEdge(EdgeHandles edge, EdgeHandles existing) =>
    edge.source == existing.source &&
    normalizeWorkflowEdgeSourceHandle(edge.sourceHandle) ==
        normalizeWorkflowEdgeSourceHandle(existing.sourceHandle) &&
    edge.target == existing.target &&
    normalizeWorkflowEdgeTargetHandle(edge.targetHandle) ==
        normalizeWorkflowEdgeTargetHandle(existing.targetHandle);

/// Port of `filterUniqueWorkflowEdges`: drops self-loops and edges that
/// duplicate an existing one (same source, target and canonical handles),
/// evaluated incrementally so only the first of two in-batch duplicates
/// survives.
List<T> filterUniqueWorkflowEdges<T extends EdgeHandles>(
  List<T> edgesToAdd,
  Iterable<EdgeHandles> currentEdges,
) {
  final working = <EdgeHandles>[...currentEdges];
  final unique = <T>[];
  for (final edge in edgesToAdd) {
    if (edge.source == edge.target) continue;
    if (working.any((existing) => _isDuplicateWorkflowEdge(edge, existing))) {
      continue;
    }
    working.add(edge);
    unique.add(edge);
  }
  return unique;
}

/// Port of `collectErrorSourceBlockIds`: blocks an `error` edge leaves,
/// after handle healing.
Set<String> collectErrorSourceBlockIds(Iterable<EdgeHandles>? edges) => {
  for (final edge in edges ?? const <EdgeHandles>[])
    if (normalizeWorkflowEdgeSourceHandle(edge.sourceHandle) ==
        workflowErrorHandleId)
      edge.source,
};

/// Port of `resolveEffectiveErrorEnabled`: the flag, or a connected error
/// edge, which the executor alone treats as the port being live.
bool resolveEffectiveErrorEnabled(
  BlockState block,
  String blockId,
  Set<String> errorSourceBlockIds,
) => (block.errorEnabled ?? false) || errorSourceBlockIds.contains(blockId);

/// Port of `normalizeWorkflowEdgeHandles`: heals legacy side-anchored handle
/// ids on a whole list. Returns the same list instance when nothing changed
/// so callers can keep memoizing on identity; `[]` for null or empty.
List<Edge> normalizeWorkflowEdgeHandles(List<Edge>? edges) {
  if (edges == null || edges.isEmpty) return const [];
  var changed = false;
  final normalized = [
    for (final edge in edges)
      () {
        final sourceHandle = normalizeWorkflowEdgeSourceHandle(
          edge.sourceHandle,
        );
        final targetHandle = normalizeWorkflowEdgeTargetHandle(
          edge.targetHandle,
        );
        if (sourceHandle == edge.sourceHandle &&
            targetHandle == edge.targetHandle) {
          return edge;
        }
        changed = true;
        return edge.copyWith(
          sourceHandle: sourceHandle,
          targetHandle: targetHandle,
        );
      }(),
  ];
  return changed ? normalized : edges;
}

/// Port of `getWorkflowEdgeScopeDropReason`: an edge is only valid within the
/// same container, or between a loop/parallel container and its direct child.
/// Returns the upstream reason string, or null when the edge is allowed.
String? getWorkflowEdgeScopeDropReason(
  EdgeEndpoints edge,
  Map<String, BlockState> blocks,
) {
  final sourceBlock = blocks[edge.source];
  final targetBlock = blocks[edge.target];
  if (sourceBlock == null || targetBlock == null) {
    return 'edge references a missing block';
  }

  final sourceParent = sourceBlock.parentId;
  final targetParent = targetBlock.parentId;

  if (sourceParent == targetParent) return null;
  if (targetParent == edge.source &&
      SubflowTypes.all.contains(sourceBlock.type)) {
    return null;
  }
  if (sourceParent == edge.target &&
      SubflowTypes.all.contains(targetBlock.type)) {
    return null;
  }

  return 'blocks are in different scopes '
      '(${sourceParent ?? 'root'} -> ${targetParent ?? 'root'})';
}

/// Port of `isWorkflowAnnotationOnlyBlockType`: notes take no edges.
bool isWorkflowAnnotationOnlyBlockType(String? blockType) =>
    blockType == 'note';

/// Port of `isKnownWorkflowTriggerBlock`: the portable subset (explicit
/// `triggerMode` or the legacy `starter` type); registry-category triggers
/// are client-only and need the block registry.
bool isKnownWorkflowTriggerBlock(BlockState block) =>
    (block.triggerMode ?? false) || block.type == 'starter';
