/// Canonical handle ids from `packages/workflow-types/src/workflow.ts` and
/// the dynamic condition/router handles from
/// `apps/sim/lib/workflows/dynamic-handle-topology.ts`.
library;

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/block_state.dart';
import 'package:sim_workflow/src/rules/dimensions.dart';

/// `WORKFLOW_SOURCE_HANDLE_ID`: the one output handle of a non-branching block.
const String workflowSourceHandleId = 'source';

/// `WORKFLOW_TARGET_HANDLE_ID`: the one input handle of a block.
const String workflowTargetHandleId = 'target';

/// `WORKFLOW_ERROR_HANDLE_ID`: the error-branch output handle.
const String workflowErrorHandleId = 'error';

const List<String> _cardSides = ['top', 'right', 'bottom', 'left'];

final Set<String> _sideAnchoredSourceHandleIds = {
  for (final side in _cardSides) 'source-$side',
};
final Set<String> _sideAnchoredTargetHandleIds = {
  for (final side in _cardSides) 'target-$side',
};

/// Port of `getWorkflowSubflowHandleIds`: `loop-start-source` /
/// `loop-end-source` and the parallel equivalents.
({String start, String end}) getWorkflowSubflowHandleIds(String kind) =>
    (start: '$kind-start-source', end: '$kind-end-source');

/// Port of `normalizeWorkflowEdgeSourceHandle`: falsy-coalesces (`''` → null,
/// as persistence writes both the same) and heals the retired side-anchored
/// ids (`source-right`) back to `source`.
String? normalizeWorkflowEdgeSourceHandle(String? handle) {
  final canonical = handle == null || handle.isEmpty ? null : handle;
  if (canonical != null && _sideAnchoredSourceHandleIds.contains(canonical)) {
    return workflowSourceHandleId;
  }
  return canonical;
}

/// Port of `normalizeWorkflowEdgeTargetHandle`.
String? normalizeWorkflowEdgeTargetHandle(String? handle) {
  final canonical = handle == null || handle.isEmpty ? null : handle;
  if (canonical != null && _sideAnchoredTargetHandleIds.contains(canonical)) {
    return workflowTargetHandleId;
  }
  return canonical;
}

/// The per-row source handle of a condition block (`condition-${row.id}`).
String conditionHandleId(String rowId) => 'condition-$rowId';

/// The per-row source handle of a router block (`router-${row.id}`).
String routerHandleId(String rowId) => 'router-$rowId';

/// Y of the handle for condition/router row [row] (0-based):
/// `CONDITION_START_Y + row * CONDITION_ROW_HEIGHT`.
double conditionHandleY(int row) =>
    HandlePositions.conditionStartY + row * HandlePositions.conditionRowHeight;

/// Port of `ConditionRow`.
@immutable
class ConditionRow {
  const ConditionRow({
    required this.id,
    required this.title,
    required this.value,
  });

  final String id;
  final String title;
  final String value;
}

/// Port of `RouterRow`.
@immutable
class RouterRow {
  const RouterRow({required this.id, required this.value});

  final String id;
  final String value;
}

/// Port of `DynamicHandleRow`: a branch's persisted source handle and the row
/// that names it.
@immutable
class DynamicHandleRow {
  const DynamicHandleRow({
    required this.handleId,
    required this.title,
    required this.value,
  });

  final String handleId;
  final String title;
  final String value;
}

/// Port of `parseStructuredValue`: a JSON string is decoded; only arrays pass.
List<Object?>? _parseStructuredValue(Object? value) {
  if (value is String) {
    try {
      final parsed = jsonDecode(value);
      return parsed is List ? parsed : null;
    } on FormatException {
      return null;
    }
  }
  return value is List ? value : null;
}

/// Port of `getDynamicHandleSubblockId`.
String? getDynamicHandleSubblockId(String? blockType) => switch (blockType) {
  'condition' => 'conditions',
  'router_v2' => 'routes',
  _ => null,
};

/// Port of `getDynamicHandleSubblockType`.
String? getDynamicHandleSubblockType(String? blockType) => switch (blockType) {
  'condition' => 'condition-input',
  'router_v2' => 'router-input',
  _ => null,
};

/// Port of `isDynamicHandleSubblock`.
bool isDynamicHandleSubblock(String? blockType, String subblockId) =>
    getDynamicHandleSubblockId(blockType) == subblockId;

/// Port of `getConditionRows`: rows from the stored `conditions` value, or the
/// default `if` / `else` pair when the value is missing, malformed or empty.
List<ConditionRow> getConditionRows(String blockId, Object? value) {
  final parsed = _parseStructuredValue(value);
  if (parsed != null && parsed.isNotEmpty) {
    return [
      for (var index = 0; index < parsed.length; index++)
        () {
          final item = parsed[index];
          final record = item is Map ? item : const <Object?, Object?>{};
          final id = record['id'];
          final rowValue = record['value'];
          return ConditionRow(
            id: id is String ? id : '$blockId-cond-$index',
            title: index == 0
                ? 'if'
                : index == parsed.length - 1
                ? 'else'
                : 'else if',
            value: rowValue is String ? rowValue : '',
          );
        }(),
    ];
  }
  return [
    ConditionRow(id: '$blockId-if', title: 'if', value: ''),
    ConditionRow(id: '$blockId-else', title: 'else', value: ''),
  ];
}

/// Port of `getRouterRows`.
List<RouterRow> getRouterRows(String blockId, Object? value) {
  final parsed = _parseStructuredValue(value);
  if (parsed != null && parsed.isNotEmpty) {
    return [
      for (var index = 0; index < parsed.length; index++)
        () {
          final item = parsed[index];
          final record = item is Map ? item : const <Object?, Object?>{};
          final id = record['id'];
          final rowValue = record['value'];
          return RouterRow(
            id: id is String ? id : '$blockId-route${index + 1}',
            value: rowValue is String ? rowValue : '',
          );
        }(),
    ];
  }
  return [RouterRow(id: '$blockId-route1', value: '')];
}

/// Port of `getDynamicHandleRows`: branch handles and labels for a condition
/// or router block; empty for every other type.
List<DynamicHandleRow> getDynamicHandleRows(BlockState block) {
  if (block.type == 'condition') {
    return [
      for (final row in getConditionRows(
        block.id,
        block.subBlocks['conditions']?.value,
      ))
        DynamicHandleRow(
          handleId: conditionHandleId(row.id),
          title: row.title,
          value: row.value,
        ),
    ];
  }
  if (block.type == 'router_v2') {
    final rows = getRouterRows(block.id, block.subBlocks['routes']?.value);
    return [
      for (var index = 0; index < rows.length; index++)
        DynamicHandleRow(
          handleId: routerHandleId(rows[index].id),
          title: 'Route ${index + 1}',
          value: rows[index].value,
        ),
    ];
  }
  return const [];
}

/// Port of `getDynamicHandleTopologySignature`: a string that changes
/// exactly when the set of dynamic handles changes.
String? getDynamicHandleTopologySignature(BlockState block) {
  if (block.type == 'condition') {
    final rows = getConditionRows(
      block.id,
      block.subBlocks['conditions']?.value,
    );
    return 'condition:${rows.map((row) => row.id).join('|')}';
  }
  if (block.type == 'router_v2') {
    final rows = getRouterRows(block.id, block.subBlocks['routes']?.value);
    return 'router:${rows.map((row) => row.id).join('|')}';
  }
  return null;
}
