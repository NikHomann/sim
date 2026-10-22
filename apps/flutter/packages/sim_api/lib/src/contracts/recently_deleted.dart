/// Wire shapes of `apps/sim/lib/api/contracts/recently-deleted.ts`
/// (`generated/contracts/recently-deleted.schema.json`).
library;

import 'package:sim_api/src/contracts/json.dart';

/// `type` filter of the recently-deleted list.
enum RecentlyDeletedFilter {
  all,
  chat,
  table,
  file,
  knowledge,
  workflow,
  folder,
}

/// `sortBy` of the recently-deleted list.
enum RecentlyDeletedSort { deleted, name, type }

/// `sortOrder` of the recently-deleted list.
enum SortOrder { asc, desc }

/// `type` of a recently-deleted row.
enum RecentlyDeletedType implements WireNamed {
  workflow('workflow'),
  folder('folder'),
  table('table'),
  tableFolder('table_folder'),
  knowledge('knowledge'),
  knowledgeFolder('knowledge_folder'),
  file('file'),
  workspaceFolder('workspace_folder'),
  chat('chat')
  ;

  const RecentlyDeletedType(this.wireName);

  @override
  final String wireName;
}

/// One `items[]` row.
class RecentlyDeletedItem extends ContractValue {
  const RecentlyDeletedItem({
    required this.id,
    required this.name,
    required this.type,
    required this.deletedAt,
    required this.parentId,
  });

  factory RecentlyDeletedItem.fromJson(JsonObject json) => RecentlyDeletedItem(
    id: json.string('id'),
    name: json.string('name'),
    type: json.enumValue('type', RecentlyDeletedType.values),
    deletedAt: json.string('deletedAt'),
    parentId: json.stringOrNull('parentId'),
  );

  final String id;
  final String name;
  final RecentlyDeletedType type;
  final String deletedAt;
  final String? parentId;

  @override
  List<Object?> get props => [id, name, type, deletedAt, parentId];

  @override
  JsonObject toJson() => {
    'id': id,
    'name': name,
    'type': type.wireName,
    'deletedAt': deletedAt,
    'parentId': parentId,
  };
}

/// One cursor page: `{items (≤100), nextCursor}` (`recently-deleted.ts:48-91`).
class RecentlyDeletedPage extends ContractValue {
  const RecentlyDeletedPage({required this.items, required this.nextCursor});

  factory RecentlyDeletedPage.fromJson(JsonObject json) => RecentlyDeletedPage(
    items: json.objectList('items').map(RecentlyDeletedItem.fromJson).toList(),
    nextCursor: json.stringOrNull('nextCursor'),
  );

  final List<RecentlyDeletedItem> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [items, nextCursor];

  @override
  JsonObject toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
    'nextCursor': nextCursor,
  };
}
