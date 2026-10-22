/// Room identity for the realtime layer.
///
/// Port of `packages/realtime-protocol/src/rooms.ts`. A [RoomRef] is the
/// universal address shared by every realtime mechanism; each value of
/// [RoomType] is a stable wire token (renaming one renames Socket.IO rooms and
/// Redis keys).
library;

import 'package:meta/meta.dart';

/// The kinds of realtime room, with their wire tokens.
enum RoomType {
  /// The collaborative workflow editor canvas (one room per workflow).
  workflow('workflow', RoomOwner.workspace),

  /// The workspace file browser (one room per workspace).
  workspaceFiles('workspace-files', RoomOwner.workspace),

  /// The project file browser (one room per project).
  projectFiles('project-files', RoomOwner.project),

  /// A single collaborative file document (Yjs sync + awareness).
  workspaceFileDoc('workspace-file-doc', RoomOwner.workspace),

  /// A single collaborative project file document.
  projectFileDoc('project-file-doc', RoomOwner.project),

  /// A single table's grid (cell-selection presence).
  table('table', RoomOwner.workspace),

  /// The workspace tables browser (invalidation only, no presence).
  workspaceTables('workspace-tables', RoomOwner.workspace),

  /// The workspace workflow registry (invalidation only, no presence).
  workspaceWorkflows('workspace-workflows', RoomOwner.workspace)
  ;

  const RoomType(this.wire, this.owner);

  /// The token that ships to clients.
  final String wire;

  /// The authority that admission and revalidation consult.
  final RoomOwner owner;

  /// Resolves a wire token to a [RoomType], or `null` when unknown.
  static RoomType? fromWire(String value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}

/// The permission authority a room is authorized against.
enum RoomOwner {
  /// Authorized through workspace permissions.
  workspace,

  /// Authorized through project permissions.
  project,
}

/// Universal address of a realtime room.
@immutable
class RoomRef {
  /// Creates a reference to the room of [type] with [id].
  const RoomRef(this.type, this.id);

  /// Decodes `{type, id}` as carried by `room-access-revoked`.
  factory RoomRef.fromJson(Map<String, Object?> json) {
    final typeValue = json['type'];
    final id = json['id'];
    if (typeValue is! String || id is! String) {
      throw const FormatException('RoomRef requires string type and id');
    }
    final type = RoomType.fromWire(typeValue);
    if (type == null) {
      throw FormatException('Unknown room type: $typeValue');
    }
    return RoomRef(type, id);
  }

  /// The kind of room.
  final RoomType type;

  /// The room's id within its type's id space.
  final String id;

  /// Encodes as `{type, id}`.
  Map<String, Object?> toJson() => {'type': type.wire, 'id': id};

  @override
  bool operator ==(Object other) =>
      other is RoomRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => 'RoomRef(${type.wire}, $id)';
}

/// Room types that carry a list-invalidation signal, with their payload key.
const Map<RoomType, String> invalidationRoomIdKeys = {
  RoomType.workspaceFiles: 'workspaceId',
  RoomType.workspaceTables: 'workspaceId',
  RoomType.workspaceWorkflows: 'workspaceId',
  RoomType.projectFiles: 'projectId',
};

/// The payload key naming the owner id for an invalidation room.
///
/// Throws [ArgumentError] for a room that does not support list invalidation.
String invalidationRoomIdKey(RoomType type) {
  final key = invalidationRoomIdKeys[type];
  if (key == null) {
    throw ArgumentError.value(
      type,
      'type',
      'Room does not support list invalidation',
    );
  }
  return key;
}

/// Whether [room] is authorized through a project rather than a workspace.
bool isProjectRoom(RoomRef room) => room.type.owner == RoomOwner.project;

/// The Socket.IO room name for a room.
///
/// [RoomType.workflow] maps to the bare id; every other type is namespaced
/// `${type}:${id}` so a new id space can never collide with a workflow UUID.
String roomName(RoomRef room) =>
    room.type == RoomType.workflow ? room.id : '${room.type.wire}:${room.id}';

/// Inverse of [roomName]. An unprefixed name is a workflow room; a name with a
/// known `${type}:` prefix parses to that type. Returns `null` only for the
/// empty string.
RoomRef? parseRoomName(String name) {
  if (name.isEmpty) return null;
  final separatorIndex = name.indexOf(':');
  if (separatorIndex > 0) {
    final maybeType = RoomType.fromWire(name.substring(0, separatorIndex));
    if (maybeType != null && maybeType != RoomType.workflow) {
      return RoomRef(maybeType, name.substring(separatorIndex + 1));
    }
  }
  return RoomRef(RoomType.workflow, name);
}

/// The `presence-update` event name for a room type: bare for workflows,
/// `${type}:presence-update` for every other type.
String presenceEventName(RoomType type) => type == RoomType.workflow
    ? 'presence-update'
    : '${type.wire}:presence-update';

final RegExp _invalidIdentityChars = RegExp('[/:]');

/// Owner-qualified identity for shared project document rooms.
RoomRef projectFileDocRoom(String projectId, String fileId) {
  for (final id in [projectId, fileId]) {
    if (id.isEmpty || _invalidIdentityChars.hasMatch(id)) {
      throw ArgumentError('Invalid Project document identity');
    }
  }
  return RoomRef(RoomType.projectFileDoc, '$projectId/$fileId');
}

/// The project and file encoded in a project document room address.
({String projectId, String fileId})? projectFileDocTarget(RoomRef room) {
  if (room.type != RoomType.projectFileDoc) return null;
  final parts = room.id.split('/');
  if (parts.length != 2) return null;
  for (final part in parts) {
    if (part.isEmpty || part.contains(':')) return null;
  }
  return (projectId: parts[0], fileId: parts[1]);
}
