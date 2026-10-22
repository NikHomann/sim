/// Wire shapes of `apps/sim/lib/api/contracts/workflows.ts` used by the
/// Phase 1 list and tree (`generated/contracts/workflows.schema.json`).
library;

import 'package:sim_api/src/contracts/json.dart';

/// `workflowListItemSchema` (`workflows.ts:245-258`). Dates stay strings on
/// the DTO; [createdAtDate] / [updatedAtDate] are the `mapWorkflow` views.
class WorkflowListItem extends ContractValue {
  const WorkflowListItem({
    required this.id,
    required this.name,
    required this.description,
    required this.workspaceId,
    required this.folderId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
    required this.locked,
    this.forkSyncExcluded = false,
    this.isDeployed,
  });

  factory WorkflowListItem.fromJson(JsonObject json) => WorkflowListItem(
    id: json.string('id'),
    name: json.string('name'),
    description: json.stringOrNull('description'),
    workspaceId: json.stringOrNull('workspaceId'),
    folderId: json.stringOrNull('folderId'),
    sortOrder: json.number('sortOrder'),
    createdAt: json.string('createdAt'),
    updatedAt: json.string('updatedAt'),
    archivedAt: json.stringOrNull('archivedAt'),
    locked: json.boolean('locked'),
    forkSyncExcluded: json.boolOr('forkSyncExcluded', fallback: false),
    isDeployed: json.boolOrNull('isDeployed'),
  );

  final String id;
  final String name;
  final String? description;
  final String? workspaceId;
  final String? folderId;
  final num sortOrder;
  final String createdAt;
  final String updatedAt;
  final String? archivedAt;
  final bool locked;
  final bool forkSyncExcluded;
  final bool? isDeployed;

  DateTime? get createdAtDate => DateTime.tryParse(createdAt);
  DateTime? get updatedAtDate => DateTime.tryParse(updatedAt);
  DateTime? get archivedAtDate =>
      archivedAt == null ? null : DateTime.tryParse(archivedAt!);

  WorkflowListItem copyWith({
    String? id,
    String? name,
    String? description,
    bool clearDescription = false,
    String? folderId,
    bool clearFolder = false,
    num? sortOrder,
    String? updatedAt,
    bool? locked,
    bool? forkSyncExcluded,
    bool? isDeployed,
  }) => WorkflowListItem(
    id: id ?? this.id,
    name: name ?? this.name,
    description: clearDescription ? null : (description ?? this.description),
    workspaceId: workspaceId,
    folderId: clearFolder ? null : (folderId ?? this.folderId),
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt,
    locked: locked ?? this.locked,
    forkSyncExcluded: forkSyncExcluded ?? this.forkSyncExcluded,
    isDeployed: isDeployed ?? this.isDeployed,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    workspaceId,
    folderId,
    sortOrder,
    createdAt,
    updatedAt,
    archivedAt,
    locked,
    forkSyncExcluded,
    isDeployed,
  ];

  @override
  JsonObject toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'workspaceId': workspaceId,
    'folderId': folderId,
    'sortOrder': sortOrder,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'archivedAt': archivedAt,
    'locked': locked,
    'forkSyncExcluded': forkSyncExcluded,
    'isDeployed': ?isDeployed,
  };
}

/// `POST /api/workflows` response (`workflows.ts:782-790`).
class CreatedWorkflow extends ContractValue {
  const CreatedWorkflow({
    required this.id,
    required this.name,
    required this.description,
    required this.workspaceId,
    required this.folderId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.startBlockId,
    required this.subBlockValues,
  });

  factory CreatedWorkflow.fromJson(JsonObject json) => CreatedWorkflow(
    id: json.string('id'),
    name: json.string('name'),
    description: json.string('description'),
    workspaceId: json.string('workspaceId'),
    folderId: json.stringOrNull('folderId'),
    sortOrder: json.number('sortOrder'),
    createdAt: json.string('createdAt'),
    updatedAt: json.string('updatedAt'),
    startBlockId: json.string('startBlockId'),
    subBlockValues: {
      for (final entry in json.object('subBlockValues').entries)
        entry.key: asJsonObject(
          entry.value,
          path: 'subBlockValues.${entry.key}',
        ),
    },
  );

  final String id;
  final String name;
  final String description;
  final String workspaceId;
  final String? folderId;
  final num sortOrder;
  final String createdAt;
  final String updatedAt;
  final String startBlockId;

  /// `Record<blockId, Record<subBlockId, unknown>>`.
  final Map<String, JsonObject> subBlockValues;

  /// The list row this workflow appears as, replacing the optimistic entry.
  WorkflowListItem toListItem() => WorkflowListItem(
    id: id,
    name: name,
    description: description,
    workspaceId: workspaceId,
    folderId: folderId,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: null,
    locked: false,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    workspaceId,
    folderId,
    sortOrder,
    createdAt,
    updatedAt,
    startBlockId,
    subBlockValues,
  ];

  @override
  JsonObject toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'workspaceId': workspaceId,
    'folderId': folderId,
    'sortOrder': sortOrder,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'startBlockId': startBlockId,
    'subBlockValues': subBlockValues,
  };
}

/// `POST /api/workflows/[id]/duplicate` response (`workflows.ts:792-801`).
class DuplicatedWorkflow extends ContractValue {
  const DuplicatedWorkflow({
    required this.id,
    required this.name,
    required this.description,
    required this.workspaceId,
    required this.folderId,
    required this.sortOrder,
    required this.locked,
    required this.blocksCount,
    required this.edgesCount,
    required this.subflowsCount,
  });

  factory DuplicatedWorkflow.fromJson(JsonObject json) => DuplicatedWorkflow(
    id: json.string('id'),
    name: json.string('name'),
    description: json.stringOrNull('description'),
    workspaceId: json.string('workspaceId'),
    folderId: json.stringOrNull('folderId'),
    sortOrder: json.number('sortOrder'),
    locked: json.boolean('locked'),
    blocksCount: json.number('blocksCount'),
    edgesCount: json.number('edgesCount'),
    subflowsCount: json.number('subflowsCount'),
  );

  final String id;
  final String name;
  final String? description;
  final String workspaceId;
  final String? folderId;
  final num sortOrder;
  final bool locked;
  final num blocksCount;
  final num edgesCount;
  final num subflowsCount;

  /// The list row for the duplicate; [now] stamps the dates the response
  /// does not carry.
  WorkflowListItem toListItem(DateTime now) => WorkflowListItem(
    id: id,
    name: name,
    description: description,
    workspaceId: workspaceId,
    folderId: folderId,
    sortOrder: sortOrder,
    createdAt: now.toIso8601String(),
    updatedAt: now.toIso8601String(),
    archivedAt: null,
    locked: locked,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    workspaceId,
    folderId,
    sortOrder,
    locked,
    blocksCount,
    edgesCount,
    subflowsCount,
  ];

  @override
  JsonObject toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'workspaceId': workspaceId,
    'folderId': folderId,
    'sortOrder': sortOrder,
    'locked': locked,
    'blocksCount': blocksCount,
    'edgesCount': edgesCount,
    'subflowsCount': subflowsCount,
  };
}

/// The `PUT /api/workflows/[id]` body: every field optional; `folderId` is
/// sent as `null` only when [clearFolder] is set.
class WorkflowUpdate extends ContractValue {
  const WorkflowUpdate({
    this.name,
    this.description,
    this.folderId,
    this.clearFolder = false,
    this.sortOrder,
    this.locked,
    this.forkSyncExcluded,
  });

  final String? name;
  final String? description;
  final String? folderId;
  final bool clearFolder;
  final int? sortOrder;
  final bool? locked;
  final bool? forkSyncExcluded;

  /// Whether `folderId` is part of the update (a move).
  bool get movesFolder => clearFolder || folderId != null;

  @override
  List<Object?> get props => [
    name,
    description,
    folderId,
    clearFolder,
    sortOrder,
    locked,
    forkSyncExcluded,
  ];

  @override
  JsonObject toJson() => {
    'name': ?name,
    'description': ?description,
    if (movesFolder) 'folderId': clearFolder ? null : folderId,
    'sortOrder': ?sortOrder,
    'locked': ?locked,
    'forkSyncExcluded': ?forkSyncExcluded,
  };
}

/// One entry of `PUT /api/workflows/reorder` `updates`.
class WorkflowReorderUpdate extends ContractValue {
  const WorkflowReorderUpdate({
    required this.id,
    required this.sortOrder,
    this.folderId,
    this.clearFolder = false,
  });

  final String id;
  final int sortOrder;
  final String? folderId;
  final bool clearFolder;

  bool get movesFolder => clearFolder || folderId != null;

  @override
  List<Object?> get props => [id, sortOrder, folderId, clearFolder];

  @override
  JsonObject toJson() => {
    'id': id,
    'sortOrder': sortOrder,
    if (movesFolder) 'folderId': clearFolder ? null : folderId,
  };
}

/// `{success: true, updated}` of the reorder endpoints.
class ReorderResult extends ContractValue {
  const ReorderResult({required this.updated});

  factory ReorderResult.fromJson(JsonObject json) =>
      ReorderResult(updated: json.number('updated'));

  final num updated;

  @override
  List<Object?> get props => [updated];

  @override
  JsonObject toJson() => {'success': true, 'updated': updated};
}

/// The part of `GET /api/workflows/[id]` → `{data}` the picker redirect
/// reads (`workspace/page.tsx:220-239`); the state payload is Phase 2.
class WorkflowSummary extends ContractValue {
  const WorkflowSummary({
    required this.id,
    required this.name,
    required this.workspaceId,
    required this.folderId,
  });

  factory WorkflowSummary.fromJson(JsonObject json) => WorkflowSummary(
    id: json.string('id'),
    name: json.string('name'),
    workspaceId: json.stringOrNull('workspaceId'),
    folderId: json.stringOrNull('folderId'),
  );

  final String id;
  final String name;
  final String? workspaceId;
  final String? folderId;

  @override
  List<Object?> get props => [id, name, workspaceId, folderId];

  @override
  JsonObject toJson() => {
    'id': id,
    'name': name,
    'workspaceId': workspaceId,
    'folderId': folderId,
  };
}
