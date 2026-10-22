/// Wire shapes of `apps/sim/lib/api/contracts/pinned-items.ts`
/// (`generated/contracts/pinned-items.schema.json`).
library;

import 'package:sim_api/src/contracts/json.dart';

/// `resourceType` of a pinned item.
enum PinnedResourceType implements WireNamed {
  workflow('workflow'),
  file('file'),
  knowledgeBase('knowledge_base'),
  table('table'),
  folder('folder'),
  workspace('workspace')
  ;

  const PinnedResourceType(this.wireName);

  @override
  final String wireName;
}

/// `pinnedItemApiSchema` (`pinned-items.ts:22-41`).
class PinnedItem extends ContractValue {
  const PinnedItem({
    required this.id,
    required this.userId,
    required this.workspaceId,
    required this.resourceType,
    required this.resourceId,
    required this.pinnedAt,
  });

  factory PinnedItem.fromJson(JsonObject json) => PinnedItem(
    id: json.string('id'),
    userId: json.string('userId'),
    workspaceId: json.string('workspaceId'),
    resourceType: json.enumValue('resourceType', PinnedResourceType.values),
    resourceId: json.string('resourceId'),
    pinnedAt: json.string('pinnedAt'),
  );

  final String id;
  final String userId;
  final String workspaceId;
  final PinnedResourceType resourceType;
  final String resourceId;
  final String pinnedAt;

  @override
  List<Object?> get props => [
    id,
    userId,
    workspaceId,
    resourceType,
    resourceId,
    pinnedAt,
  ];

  @override
  JsonObject toJson() => {
    'id': id,
    'userId': userId,
    'workspaceId': workspaceId,
    'resourceType': resourceType.wireName,
    'resourceId': resourceId,
    'pinnedAt': pinnedAt,
  };
}
