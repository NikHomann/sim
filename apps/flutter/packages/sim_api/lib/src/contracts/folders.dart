/// Wire shapes of `apps/sim/lib/api/contracts/folders.ts`
/// (`generated/contracts/folders.schema.json`).
library;

import 'package:sim_api/src/contracts/json.dart';

/// `resourceType` of a folder. `file` exists on rows but is rejected by the
/// list/mutation routes (`servedFolderResourceType`).
enum FolderResourceType implements WireNamed {
  workflow('workflow'),
  file('file'),
  knowledgeBase('knowledge_base'),
  table('table')
  ;

  const FolderResourceType(this.wireName);

  @override
  final String wireName;
}

/// `scope` of `GET /api/folders`.
enum FolderScope { active, archived }

/// `folderApiSchema` (`folders.ts:36-52`). Dates are kept as the wire
/// strings; [createdAtDate] etc. are the `mapFolder` views.
class Folder extends ContractValue {
  const Folder({
    required this.id,
    required this.resourceType,
    required this.name,
    required this.userId,
    required this.workspaceId,
    required this.parentId,
    required this.locked,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  factory Folder.fromJson(JsonObject json) => Folder(
    id: json.string('id'),
    resourceType: json.enumValue('resourceType', FolderResourceType.values),
    name: json.string('name'),
    userId: json.string('userId'),
    workspaceId: json.string('workspaceId'),
    parentId: json.stringOrNull('parentId'),
    locked: json.boolean('locked'),
    sortOrder: json.number('sortOrder'),
    createdAt: json.string('createdAt'),
    updatedAt: json.string('updatedAt'),
    deletedAt: json.stringOrNull('deletedAt'),
  );

  final String id;
  final FolderResourceType resourceType;
  final String name;
  final String userId;
  final String workspaceId;
  final String? parentId;
  final bool locked;
  final num sortOrder;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  DateTime? get createdAtDate => DateTime.tryParse(createdAt);
  DateTime? get updatedAtDate => DateTime.tryParse(updatedAt);
  DateTime? get deletedAtDate =>
      deletedAt == null ? null : DateTime.tryParse(deletedAt!);

  Folder copyWith({
    String? name,
    String? parentId,
    bool clearParent = false,
    num? sortOrder,
    bool? locked,
    String? updatedAt,
  }) => Folder(
    id: id,
    resourceType: resourceType,
    name: name ?? this.name,
    userId: userId,
    workspaceId: workspaceId,
    parentId: clearParent ? null : (parentId ?? this.parentId),
    locked: locked ?? this.locked,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt,
  );

  @override
  List<Object?> get props => [
    id,
    resourceType,
    name,
    userId,
    workspaceId,
    parentId,
    locked,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  ];

  @override
  JsonObject toJson() => {
    'id': id,
    'resourceType': resourceType.wireName,
    'name': name,
    'userId': userId,
    'workspaceId': workspaceId,
    'parentId': parentId,
    'locked': locked,
    'sortOrder': sortOrder,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'deletedAt': deletedAt,
  };
}

/// The `PUT /api/folders/[id]` body; `parentId` goes out as `null` only
/// with [clearParent].
class FolderUpdate extends ContractValue {
  const FolderUpdate({
    this.name,
    this.locked,
    this.parentId,
    this.clearParent = false,
    this.sortOrder,
  });

  final String? name;
  final bool? locked;
  final String? parentId;
  final bool clearParent;
  final int? sortOrder;

  bool get movesParent => clearParent || parentId != null;

  @override
  List<Object?> get props => [name, locked, parentId, clearParent, sortOrder];

  @override
  JsonObject toJson() => {
    'name': ?name,
    'locked': ?locked,
    if (movesParent) 'parentId': clearParent ? null : parentId,
    'sortOrder': ?sortOrder,
  };
}

/// One entry of `PUT /api/folders/reorder` `updates`.
class FolderReorderUpdate extends ContractValue {
  const FolderReorderUpdate({
    required this.id,
    required this.sortOrder,
    this.parentId,
    this.clearParent = false,
  });

  final String id;
  final int sortOrder;
  final String? parentId;
  final bool clearParent;

  bool get movesParent => clearParent || parentId != null;

  @override
  List<Object?> get props => [id, sortOrder, parentId, clearParent];

  @override
  JsonObject toJson() => {
    'id': id,
    'sortOrder': sortOrder,
    if (movesParent) 'parentId': clearParent ? null : parentId,
  };
}

/// `deletedItems` / `restoredItems` counts of the folder delete and restore
/// endpoints.
class FolderCascadeCounts extends ContractValue {
  const FolderCascadeCounts({
    required this.folders,
    this.workflows,
    this.files,
    this.knowledgeBases,
    this.tables,
  });

  factory FolderCascadeCounts.fromJson(JsonObject json) => FolderCascadeCounts(
    folders: json.integer('folders'),
    workflows: json.intOrNull('workflows'),
    files: json.intOrNull('files'),
    knowledgeBases: json.intOrNull('knowledgeBases'),
    tables: json.intOrNull('tables'),
  );

  final int folders;
  final int? workflows;
  final int? files;
  final int? knowledgeBases;
  final int? tables;

  @override
  List<Object?> get props => [
    folders,
    workflows,
    files,
    knowledgeBases,
    tables,
  ];

  @override
  JsonObject toJson() => {
    'folders': folders,
    'workflows': ?workflows,
    'files': ?files,
    'knowledgeBases': ?knowledgeBases,
    'tables': ?tables,
  };
}
