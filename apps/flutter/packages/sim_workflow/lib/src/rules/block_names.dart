import 'package:meta/meta.dart';

/// Port of `RESERVED_WORKFLOW_BLOCK_NAMES` from
/// `packages/workflow-types/src/workflow.ts`.
const List<String> reservedWorkflowBlockNames = [
  'loop',
  'parallel',
  'variable',
];

/// Port of `normalizeWorkflowBlockName`: lowercased, whitespace and dots
/// stripped, so `Trigger.dev 1` → `triggerdev1`.
String normalizeWorkflowBlockName(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'\s+'), '').replaceAll('.', '');

enum WorkflowBlockNameConflictReason { empty, reserved, duplicate }

/// Port of `WorkflowBlockNameConflict`.
@immutable
class WorkflowBlockNameConflict {
  const WorkflowBlockNameConflict(this.reason, {this.conflictingBlockId});

  final WorkflowBlockNameConflictReason reason;
  final String? conflictingBlockId;

  @override
  bool operator ==(Object other) =>
      other is WorkflowBlockNameConflict &&
      other.reason == reason &&
      other.conflictingBlockId == conflictingBlockId;

  @override
  int get hashCode => Object.hash(reason, conflictingBlockId);
}

/// Port of `getWorkflowBlockNameConflict`: empty, duplicate (checked before
/// reserved, as upstream does) or reserved; null when the name is usable.
WorkflowBlockNameConflict? getWorkflowBlockNameConflict(
  String blockId,
  String name,
  Map<String, String> siblingNamesById,
) {
  final normalized = normalizeWorkflowBlockName(name);
  if (normalized.isEmpty) {
    return const WorkflowBlockNameConflict(
      WorkflowBlockNameConflictReason.empty,
    );
  }

  for (final entry in siblingNamesById.entries) {
    if (entry.key != blockId &&
        normalizeWorkflowBlockName(entry.value) == normalized) {
      return WorkflowBlockNameConflict(
        WorkflowBlockNameConflictReason.duplicate,
        conflictingBlockId: entry.key,
      );
    }
  }

  if (reservedWorkflowBlockNames.contains(normalized)) {
    return const WorkflowBlockNameConflict(
      WorkflowBlockNameConflictReason.reserved,
    );
  }

  return null;
}
