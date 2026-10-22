import 'package:meta/meta.dart';
import 'package:sim_workflow/src/realtime/json.dart';

/// A live-presence cursor position in flow coordinates.
@immutable
class CursorPosition {
  /// Creates a cursor at ([x], [y]).
  const CursorPosition(this.x, this.y);

  /// Decodes `{x, y}`.
  factory CursorPosition.fromJson(JsonMap json) =>
      CursorPosition(readNum(json, 'x'), readNum(json, 'y'));

  /// Horizontal flow coordinate.
  final num x;

  /// Vertical flow coordinate.
  final num y;

  /// Encodes as `{x, y}`.
  JsonMap toJson() => {'x': x, 'y': y};

  @override
  bool operator ==(Object other) =>
      other is CursorPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'CursorPosition($x, $y)';
}

/// What a collaborator has selected on the canvas.
enum SelectionType {
  /// A block is selected.
  block('block'),

  /// An edge is selected.
  edge('edge'),

  /// Nothing is selected.
  none('none')
  ;

  const SelectionType(this.wire);

  /// The wire token.
  final String wire;

  /// Resolves a wire token, throwing [ProtocolFormatException] when unknown.
  static SelectionType fromWire(String value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    throw ProtocolFormatException(
      'unknown selection type',
      path: 'type',
      payload: value,
    );
  }
}

/// A live-presence selection broadcast over the socket.
@immutable
class PresenceSelection {
  /// Creates a selection of [type], optionally naming the selected [id].
  const PresenceSelection(this.type, {this.id});

  /// Decodes `{type, id?}`.
  factory PresenceSelection.fromJson(JsonMap json) => PresenceSelection(
    SelectionType.fromWire(readString(json, 'type')),
    id: readOptionalString(json, 'id'),
  );

  /// The cleared selection.
  static const PresenceSelection none = PresenceSelection(SelectionType.none);

  /// What kind of entity is selected.
  final SelectionType type;

  /// The selected entity's id, when [type] is not [SelectionType.none].
  final String? id;

  /// Encodes as `{type, id?}` (the `id` key is omitted when `null`).
  JsonMap toJson() => {'type': type.wire, if (id != null) 'id': id};

  @override
  bool operator ==(Object other) =>
      other is PresenceSelection && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => 'PresenceSelection(${type.wire}, $id)';
}

/// A collaborator present in a workflow room.
///
/// Mirrors the presence payload broadcast by the realtime server
/// (`presence-update`, `join-workflow-success`), which is the server's
/// `UserPresence` record (`apps/realtime/src/rooms/types.ts`) minus `room`.
///
/// `cursor` is tri-state on the wire: absent (the server rebuilt the record on
/// a re-join and never knew the pointer), `null` (the pointer left the canvas)
/// or a position. [hasCursorField] distinguishes the first two, which is what
/// [mergePresenceRoster] needs to keep a peer's pointer from flickering.
class UserPresence {
  /// Creates a presence record.
  const UserPresence({
    required this.socketId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.hasAvatarUrlField = false,
    this.cursor,
    this.hasCursorField = false,
    this.selection,
    this.tabSessionId,
    this.role,
    this.joinedAt,
    this.lastActivity,
    this.extra = const {},
  });

  /// Decodes a presence record, keeping unknown keys in [extra].
  factory UserPresence.fromJson(JsonMap json) {
    final cursorValue = json['cursor'];
    final selectionValue = json['selection'];
    return UserPresence(
      socketId: readString(json, 'socketId'),
      userId: readString(json, 'userId'),
      userName: readString(json, 'userName'),
      avatarUrl: readOptionalString(json, 'avatarUrl'),
      hasAvatarUrlField: json.containsKey('avatarUrl'),
      cursor: cursorValue == null
          ? null
          : CursorPosition.fromJson(asJsonMap(cursorValue, path: 'cursor')),
      hasCursorField: json.containsKey('cursor'),
      selection: selectionValue == null
          ? null
          : PresenceSelection.fromJson(
              asJsonMap(selectionValue, path: 'selection'),
            ),
      tabSessionId: readOptionalString(json, 'tabSessionId'),
      role: readOptionalString(json, 'role'),
      joinedAt: readOptionalNum(json, 'joinedAt')?.toInt(),
      lastActivity: readOptionalNum(json, 'lastActivity')?.toInt(),
      extra: {
        for (final entry in json.entries)
          if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  static const Set<String> _knownKeys = {
    'socketId',
    'userId',
    'userName',
    'avatarUrl',
    'cursor',
    'selection',
    'tabSessionId',
    'role',
    'joinedAt',
    'lastActivity',
  };

  /// The collaborator's socket id (unique per tab connection).
  final String socketId;

  /// The collaborator's user id.
  final String userId;

  /// The collaborator's display name.
  final String userName;

  /// The collaborator's avatar URL, when resolved.
  final String? avatarUrl;

  /// Whether the wire record carried an `avatarUrl` key (possibly `null`).
  final bool hasAvatarUrlField;

  /// The pointer position; `null` when cleared or unknown.
  final CursorPosition? cursor;

  /// Whether the wire record carried a `cursor` key at all.
  final bool hasCursorField;

  /// The current selection, when known.
  final PresenceSelection? selection;

  /// The tab session that joined, when the server recorded one.
  final String? tabSessionId;

  /// The workspace role the server resolved (`read`, `write`, `admin`).
  final String? role;

  /// Epoch milliseconds of the join.
  final int? joinedAt;

  /// Epoch milliseconds of the last activity.
  final int? lastActivity;

  /// Keys the client does not model, preserved for round trips.
  final JsonMap extra;

  /// Encodes the record; `cursor` is emitted only when [hasCursorField].
  JsonMap toJson() => {
    ...extra,
    'socketId': socketId,
    'userId': userId,
    'userName': userName,
    if (hasAvatarUrlField || avatarUrl != null) 'avatarUrl': avatarUrl,
    if (hasCursorField) 'cursor': cursor?.toJson(),
    if (selection != null) 'selection': selection!.toJson(),
    if (tabSessionId != null) 'tabSessionId': tabSessionId,
    if (role != null) 'role': role,
    if (joinedAt != null) 'joinedAt': joinedAt,
    if (lastActivity != null) 'lastActivity': lastActivity,
  };

  /// Returns a copy with the cursor replaced (and the field marked present).
  UserPresence withCursor(CursorPosition? cursor) => _copy(
    cursor: cursor,
    hasCursorField: true,
    selection: selection,
  );

  /// Returns a copy with the selection replaced.
  UserPresence withSelection(PresenceSelection? selection) => _copy(
    cursor: cursor,
    hasCursorField: hasCursorField,
    selection: selection,
  );

  UserPresence _copy({
    required CursorPosition? cursor,
    required bool hasCursorField,
    required PresenceSelection? selection,
  }) => UserPresence(
    socketId: socketId,
    userId: userId,
    userName: userName,
    avatarUrl: avatarUrl,
    hasAvatarUrlField: hasAvatarUrlField,
    cursor: cursor,
    hasCursorField: hasCursorField,
    selection: selection,
    tabSessionId: tabSessionId,
    role: role,
    joinedAt: joinedAt,
    lastActivity: lastActivity,
    extra: extra,
  );

  @override
  String toString() => 'UserPresence($socketId, $userName)';
}

/// Folds a `presence-update` roster over the presence already held for each
/// socket. Port of `socket-presence-merge.ts`: an absent `cursor` carries the
/// previous value over, an explicit `null` clears it, and a missing
/// `selection` keeps the previous one.
List<UserPresence> mergePresenceRoster(
  List<UserPresence> previous,
  List<UserPresence> incoming,
) {
  final previousBySocketId = {for (final user in previous) user.socketId: user};
  return [
    for (final user in incoming)
      switch (previousBySocketId[user.socketId]) {
        null => user,
        final existing => user._copy(
          cursor: user.hasCursorField ? user.cursor : existing.cursor,
          hasCursorField: user.hasCursorField || existing.hasCursorField,
          selection: user.selection ?? existing.selection,
        ),
      },
  ];
}
