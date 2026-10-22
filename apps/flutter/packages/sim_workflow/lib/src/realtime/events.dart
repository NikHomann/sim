/// Wire events of the realtime workflow protocol.
///
/// Client → server events are the object literals emitted by
/// `apps/sim/app/workspace/providers/socket-provider.tsx`; server → client
/// events are typed in `packages/realtime-protocol/src/events.ts` and emitted
/// by `apps/realtime/src/handlers/**`. Key names match upstream exactly.
library;

import 'package:sim_workflow/src/realtime/json.dart';
import 'package:sim_workflow/src/realtime/operations.dart';
import 'package:sim_workflow/src/realtime/presence.dart';
import 'package:sim_workflow/src/realtime/rooms.dart';

/// Socket event names the client emits.
abstract final class ClientEventNames {
  /// Join a workflow room.
  static const String joinWorkflow = 'join-workflow';

  /// Leave the current workflow room (no payload).
  static const String leaveWorkflow = 'leave-workflow';

  /// A structural operation.
  static const String workflowOperation = 'workflow-operation';

  /// A subblock value write.
  static const String subblockUpdate = 'subblock-update';

  /// A variable field write.
  static const String variableUpdate = 'variable-update';

  /// The local pointer moved (throttled to 33 ms).
  static const String cursorUpdate = 'cursor-update';

  /// The local selection changed.
  static const String selectionUpdate = 'selection-update';
}

/// Socket event names the server emits.
abstract final class ServerEventNames {
  /// The room was joined.
  static const String joinWorkflowSuccess = 'join-workflow-success';

  /// The room could not be joined.
  static const String joinWorkflowError = 'join-workflow-error';

  /// Raw workflow state, sent right after a successful join.
  static const String workflowState = 'workflow-state';

  /// The room's full presence roster.
  static const String presenceUpdate = 'presence-update';

  /// A collaborator's structural operation.
  static const String workflowOperation = 'workflow-operation';

  /// A collaborator's subblock write.
  static const String subblockUpdate = 'subblock-update';

  /// A collaborator's variable write.
  static const String variableUpdate = 'variable-update';

  /// A collaborator's pointer moved.
  static const String cursorUpdate = 'cursor-update';

  /// A collaborator's selection changed.
  static const String selectionUpdate = 'selection-update';

  /// A local operation was persisted.
  static const String operationConfirmed = 'operation-confirmed';

  /// A local operation was rejected.
  static const String operationFailed = 'operation-failed';

  /// Diagnostic for a failed operation.
  static const String operationError = 'operation-error';

  /// The operation was not allowed.
  static const String operationForbidden = 'operation-forbidden';

  /// The workflow was deleted.
  static const String workflowDeleted = 'workflow-deleted';

  /// The workflow was reverted to its deployed state.
  static const String workflowReverted = 'workflow-reverted';

  /// The workflow was updated outside the editor.
  static const String workflowUpdated = 'workflow-updated';

  /// The workflow's deployment state changed.
  static const String workflowDeployed = 'workflow-deployed';

  /// This socket lost access to the workflow.
  static const String accessRevoked = 'access-revoked';

  /// This socket lost access to a non-workflow room.
  static const String roomAccessRevoked = 'room-access-revoked';
}

/// An event the client emits.
sealed class ClientEvent {
  const ClientEvent();

  /// Decodes an emitted `(name, payload)` pair, for fake servers and the
  /// parity emit log. Throws [ProtocolFormatException] on an unknown name.
  factory ClientEvent.decode(String name, Object? payload) {
    switch (name) {
      case ClientEventNames.joinWorkflow:
        return JoinWorkflowEvent.fromJson(asJsonMap(payload));
      case ClientEventNames.leaveWorkflow:
        return const LeaveWorkflowEvent();
      case ClientEventNames.workflowOperation:
        return WorkflowOperationEvent.fromJson(asJsonMap(payload));
      case ClientEventNames.subblockUpdate:
        return SubblockUpdateEvent.fromJson(asJsonMap(payload));
      case ClientEventNames.variableUpdate:
        return VariableUpdateEvent.fromJson(asJsonMap(payload));
      case ClientEventNames.cursorUpdate:
        return CursorUpdateEvent.fromJson(asJsonMap(payload));
      case ClientEventNames.selectionUpdate:
        return SelectionUpdateEvent.fromJson(asJsonMap(payload));
      default:
        throw ProtocolFormatException(
          'unknown client event',
          path: name,
          payload: payload,
        );
    }
  }

  /// The socket event name.
  String get name;

  /// The wire payload (`null` for a payload-less event).
  Object? toJson();
}

/// `join-workflow {workflowId, tabSessionId}`.
final class JoinWorkflowEvent extends ClientEvent {
  /// Requests the room of [workflowId] for the tab [tabSessionId].
  const JoinWorkflowEvent({
    required this.workflowId,
    required this.tabSessionId,
  });

  /// Decodes the payload.
  factory JoinWorkflowEvent.fromJson(JsonMap json) => JoinWorkflowEvent(
    workflowId: readString(json, 'workflowId'),
    tabSessionId: readString(json, 'tabSessionId'),
  );

  /// The workflow to join.
  final String workflowId;

  /// The tab identity, so the server evicts this tab's stale sockets.
  final String tabSessionId;

  @override
  String get name => ClientEventNames.joinWorkflow;

  @override
  JsonMap toJson() => {'workflowId': workflowId, 'tabSessionId': tabSessionId};
}

/// `leave-workflow` (no payload).
final class LeaveWorkflowEvent extends ClientEvent {
  /// Leaves the current room.
  const LeaveWorkflowEvent();

  @override
  String get name => ClientEventNames.leaveWorkflow;

  @override
  Object? toJson() => null;
}

/// `workflow-operation {workflowId, operation, target, payload, timestamp,
/// operationId}`.
final class WorkflowOperationEvent extends ClientEvent {
  /// Emits [operation] for [workflowId].
  const WorkflowOperationEvent({
    required this.workflowId,
    required this.operation,
    required this.timestamp,
    this.operationId,
  });

  /// Decodes the payload.
  factory WorkflowOperationEvent.fromJson(JsonMap json) =>
      WorkflowOperationEvent(
        workflowId: readString(json, 'workflowId'),
        operation: WorkflowOperation.fromJson(json),
        timestamp: readInt(json, 'timestamp'),
        operationId: readOptionalString(json, 'operationId'),
      );

  /// The target workflow.
  final String workflowId;

  /// The operation (its `operation`, `target` and `payload` are flattened).
  final WorkflowOperation operation;

  /// Client epoch milliseconds.
  final int timestamp;

  /// Queue id the server confirms; absent for fire-and-forget emits.
  final String? operationId;

  @override
  String get name => ClientEventNames.workflowOperation;

  @override
  JsonMap toJson() => {
    'workflowId': workflowId,
    'operation': operation.operation,
    'target': operation.target,
    'payload': operation.payload,
    'timestamp': timestamp,
    'operationId': operationId,
  };
}

/// `subblock-update {workflowId, blockId, subblockId, value, timestamp,
/// operationId}`.
final class SubblockUpdateEvent extends ClientEvent {
  /// Writes [value] to [blockId].[subblockId].
  const SubblockUpdateEvent({
    required this.workflowId,
    required this.blockId,
    required this.subblockId,
    required this.value,
    required this.timestamp,
    this.operationId,
  });

  /// Decodes the payload.
  factory SubblockUpdateEvent.fromJson(JsonMap json) => SubblockUpdateEvent(
    workflowId: readString(json, 'workflowId'),
    blockId: readString(json, 'blockId'),
    subblockId: readString(json, 'subblockId'),
    value: json['value'],
    timestamp: readInt(json, 'timestamp'),
    operationId: readOptionalString(json, 'operationId'),
  );

  /// The target workflow.
  final String workflowId;

  /// The block.
  final String blockId;

  /// The subblock.
  final String subblockId;

  /// The new value.
  final Object? value;

  /// Client epoch milliseconds.
  final int timestamp;

  /// Queue id the server confirms.
  final String? operationId;

  @override
  String get name => ClientEventNames.subblockUpdate;

  @override
  JsonMap toJson() => {
    'workflowId': workflowId,
    'blockId': blockId,
    'subblockId': subblockId,
    'value': value,
    'timestamp': timestamp,
    'operationId': operationId,
  };
}

/// `variable-update {workflowId, variableId, field, value, timestamp,
/// operationId}`.
final class VariableUpdateEvent extends ClientEvent {
  /// Writes [value] to [field] of [variableId].
  const VariableUpdateEvent({
    required this.workflowId,
    required this.variableId,
    required this.field,
    required this.value,
    required this.timestamp,
    this.operationId,
  });

  /// Decodes the payload.
  factory VariableUpdateEvent.fromJson(JsonMap json) => VariableUpdateEvent(
    workflowId: readString(json, 'workflowId'),
    variableId: readString(json, 'variableId'),
    field: readString(json, 'field'),
    value: json['value'],
    timestamp: readInt(json, 'timestamp'),
    operationId: readOptionalString(json, 'operationId'),
  );

  /// The target workflow.
  final String workflowId;

  /// The variable.
  final String variableId;

  /// `name`, `value` or `type`.
  final String field;

  /// The new value.
  final Object? value;

  /// Client epoch milliseconds.
  final int timestamp;

  /// Queue id the server confirms.
  final String? operationId;

  @override
  String get name => ClientEventNames.variableUpdate;

  @override
  JsonMap toJson() => {
    'workflowId': workflowId,
    'variableId': variableId,
    'field': field,
    'value': value,
    'timestamp': timestamp,
    'operationId': operationId,
  };
}

/// `cursor-update {cursor}`; `cursor: null` when the pointer leaves the canvas.
final class CursorUpdateEvent extends ClientEvent {
  /// Reports the pointer at [cursor].
  const CursorUpdateEvent(this.cursor);

  /// Decodes the payload.
  factory CursorUpdateEvent.fromJson(JsonMap json) => CursorUpdateEvent(
    switch (json['cursor']) {
      null => null,
      final Object value => CursorPosition.fromJson(
        asJsonMap(value, path: 'cursor'),
      ),
    },
  );

  /// The pointer position in flow coordinates.
  final CursorPosition? cursor;

  @override
  String get name => ClientEventNames.cursorUpdate;

  @override
  JsonMap toJson() => {'cursor': cursor?.toJson()};
}

/// `selection-update {selection}`.
final class SelectionUpdateEvent extends ClientEvent {
  /// Reports [selection].
  const SelectionUpdateEvent(this.selection);

  /// Decodes the payload.
  factory SelectionUpdateEvent.fromJson(JsonMap json) => SelectionUpdateEvent(
    PresenceSelection.fromJson(readMap(json, 'selection')),
  );

  /// The local selection.
  final PresenceSelection selection;

  @override
  String get name => ClientEventNames.selectionUpdate;

  @override
  JsonMap toJson() => {'selection': selection.toJson()};
}

/// An event the server emits.
sealed class ServerEvent {
  const ServerEvent();

  /// Decodes a `(name, data)` pair received from the transport.
  ///
  /// Names outside the vocabulary (for example Yjs file-doc room events on a
  /// shared socket) decode to [UnknownEvent]; a known name whose payload does
  /// not validate decodes to [MalformedEvent]. Neither throws.
  factory ServerEvent.decode(String name, Object? data) {
    try {
      return _decodeStrict(name, data);
    } on ProtocolFormatException catch (error) {
      return MalformedEvent(name: name, data: data, error: error);
    } on FormatException catch (error) {
      return MalformedEvent(
        name: name,
        data: data,
        error: ProtocolFormatException(error.message, payload: data),
      );
    }
  }

  static ServerEvent _decodeStrict(String name, Object? data) {
    switch (name) {
      case ServerEventNames.joinWorkflowSuccess:
        return JoinWorkflowSuccessEvent.fromJson(asJsonMap(data));
      case ServerEventNames.joinWorkflowError:
        return JoinWorkflowErrorEvent.fromJson(asJsonMap(data));
      case ServerEventNames.workflowState:
        return WorkflowStateEvent.fromJson(asJsonMap(data));
      case ServerEventNames.presenceUpdate:
        return PresenceUpdateEvent.fromJson(data);
      case ServerEventNames.workflowOperation:
        return WorkflowOperationBroadcast.fromJson(asJsonMap(data));
      case ServerEventNames.subblockUpdate:
        return SubblockUpdateBroadcast.fromJson(asJsonMap(data));
      case ServerEventNames.variableUpdate:
        return VariableUpdateBroadcast.fromJson(asJsonMap(data));
      case ServerEventNames.cursorUpdate:
        return CursorUpdateBroadcast.fromJson(asJsonMap(data));
      case ServerEventNames.selectionUpdate:
        return SelectionUpdateBroadcast.fromJson(asJsonMap(data));
      case ServerEventNames.operationConfirmed:
        return OperationConfirmedEvent.fromJson(asJsonMap(data));
      case ServerEventNames.operationFailed:
        return OperationFailedEvent.fromJson(asJsonMap(data));
      case ServerEventNames.operationError:
        return OperationErrorEvent.fromJson(asJsonMap(data));
      case ServerEventNames.operationForbidden:
        return OperationForbiddenEvent.fromJson(asJsonMap(data));
      case ServerEventNames.workflowDeleted:
        return WorkflowDeletedEvent.fromJson(asJsonMap(data));
      case ServerEventNames.workflowReverted:
        return WorkflowRevertedEvent.fromJson(asJsonMap(data));
      case ServerEventNames.workflowUpdated:
        return WorkflowUpdatedEvent.fromJson(asJsonMap(data));
      case ServerEventNames.workflowDeployed:
        return WorkflowDeployedEvent.fromJson(asJsonMap(data));
      case ServerEventNames.accessRevoked:
        return AccessRevokedEvent.fromJson(asJsonMap(data));
      case ServerEventNames.roomAccessRevoked:
        return RoomAccessRevokedEvent.fromJson(asJsonMap(data));
      default:
        return UnknownEvent(name: name, data: data);
    }
  }

  /// The socket event name.
  String get name;

  /// The wire payload.
  Object? toJson();
}

/// An event name outside the vocabulary, carried opaquely.
final class UnknownEvent extends ServerEvent {
  /// Creates an opaque event.
  const UnknownEvent({required this.name, required this.data});

  @override
  final String name;

  /// The raw payload.
  final Object? data;

  @override
  Object? toJson() => data;
}

/// A known event whose payload failed validation.
final class MalformedEvent extends ServerEvent {
  /// Creates a record of the malformed payload.
  const MalformedEvent({
    required this.name,
    required this.data,
    required this.error,
  });

  @override
  final String name;

  /// The raw payload.
  final Object? data;

  /// Why validation failed.
  final ProtocolFormatException error;

  @override
  Object? toJson() => data;
}

/// `join-workflow-success {workflowId, socketId, presenceUsers}`.
final class JoinWorkflowSuccessEvent extends ServerEvent {
  /// Creates the ack.
  const JoinWorkflowSuccessEvent({
    required this.workflowId,
    required this.socketId,
    required this.presenceUsers,
  });

  /// Decodes the payload.
  factory JoinWorkflowSuccessEvent.fromJson(JsonMap json) =>
      JoinWorkflowSuccessEvent(
        workflowId: readString(json, 'workflowId'),
        socketId: readString(json, 'socketId'),
        presenceUsers: [
          for (final user
              in readOptionalList(json, 'presenceUsers') ?? const [])
            UserPresence.fromJson(asJsonMap(user, path: 'presenceUsers')),
        ],
      );

  /// The joined workflow.
  final String workflowId;

  /// This socket's id.
  final String socketId;

  /// The room's live members, this socket included.
  final List<UserPresence> presenceUsers;

  @override
  String get name => ServerEventNames.joinWorkflowSuccess;

  @override
  JsonMap toJson() => {
    'workflowId': workflowId,
    'socketId': socketId,
    'presenceUsers': [for (final user in presenceUsers) user.toJson()],
  };
}

/// `join-workflow-error {workflowId, error, code, retryable}`.
final class JoinWorkflowErrorEvent extends ServerEvent {
  /// Creates the rejection.
  const JoinWorkflowErrorEvent({
    required this.workflowId,
    required this.error,
    required this.code,
    required this.retryable,
  });

  /// Decodes the payload.
  factory JoinWorkflowErrorEvent.fromJson(JsonMap json) =>
      JoinWorkflowErrorEvent(
        workflowId: readString(json, 'workflowId'),
        error: readString(json, 'error'),
        code: readOptionalString(json, 'code'),
        retryable: readOptionalBool(json, 'retryable') ?? false,
      );

  /// The workflow that could not be joined (`''` for an invalid id).
  final String workflowId;

  /// Human readable reason.
  final String error;

  /// `ACCESS_DENIED`, `ROOM_MANAGER_UNAVAILABLE`, `JOIN_WORKFLOW_FAILED`, ...
  final String? code;

  /// Whether the client should retry with backoff.
  final bool retryable;

  @override
  String get name => ServerEventNames.joinWorkflowError;

  @override
  JsonMap toJson() => {
    'workflowId': workflowId,
    'error': error,
    'code': code,
    'retryable': retryable,
  };
}

/// `workflow-state`: the workflow row plus a raw `state` snapshot.
///
/// The realtime server loads state without the app's block migrations, so
/// this payload is only a trigger (re-sync over HTTP) and a fallback.
final class WorkflowStateEvent extends ServerEvent {
  /// Creates the snapshot event.
  const WorkflowStateEvent({
    required this.id,
    required this.state,
    required this.raw,
  });

  /// Decodes the payload, keeping the whole row in [raw].
  factory WorkflowStateEvent.fromJson(JsonMap json) => WorkflowStateEvent(
    id: readString(json, 'id'),
    state: readOptionalMap(json, 'state'),
    raw: json,
  );

  /// The workflow id.
  final String id;

  /// `{blocks, edges, loops, parallels, lastSaved, isDeployed, deployedAt,
  /// hasActiveWebhook}`, or `null` when the normalized tables are empty.
  final JsonMap? state;

  /// The full payload (workflow row, `state`, `lastModified`).
  final JsonMap raw;

  @override
  String get name => ServerEventNames.workflowState;

  @override
  JsonMap toJson() => raw;
}

/// `presence-update UserPresence[]`.
final class PresenceUpdateEvent extends ServerEvent {
  /// Creates the roster event.
  const PresenceUpdateEvent(this.users);

  /// Decodes the array payload.
  factory PresenceUpdateEvent.fromJson(Object? data) {
    if (data is! List) {
      throw ProtocolFormatException('expected array', payload: data);
    }
    return PresenceUpdateEvent([
      for (final user in data) UserPresence.fromJson(asJsonMap(user)),
    ]);
  }

  /// The full roster.
  final List<UserPresence> users;

  @override
  String get name => ServerEventNames.presenceUpdate;

  @override
  List<JsonMap> toJson() => [for (final user in users) user.toJson()];
}

/// The `metadata` of a `workflow-operation` broadcast.
class OperationMetadata {
  /// Creates the metadata.
  const OperationMetadata({
    required this.workflowId,
    required this.operationId,
    this.isPositionUpdate,
    this.isBatchPositionUpdate,
  });

  /// Decodes the metadata.
  factory OperationMetadata.fromJson(JsonMap json) => OperationMetadata(
    workflowId: readString(json, 'workflowId'),
    operationId: readString(json, 'operationId'),
    isPositionUpdate: readOptionalBool(json, 'isPositionUpdate'),
    isBatchPositionUpdate: readOptionalBool(json, 'isBatchPositionUpdate'),
  );

  /// The room the operation applies to.
  final String workflowId;

  /// A server-generated id for the broadcast (not the sender's queue id).
  final String operationId;

  /// Set on per-frame `update-position` broadcasts.
  final bool? isPositionUpdate;

  /// Set on `batch-update-positions` broadcasts.
  final bool? isBatchPositionUpdate;

  /// Encodes the metadata.
  JsonMap toJson() => {
    'workflowId': workflowId,
    'operationId': operationId,
    if (isPositionUpdate != null) 'isPositionUpdate': isPositionUpdate,
    if (isBatchPositionUpdate != null)
      'isBatchPositionUpdate': isBatchPositionUpdate,
  };
}

/// `workflow-operation` broadcast: the sender's envelope plus identity.
final class WorkflowOperationBroadcast extends ServerEvent {
  /// Creates the broadcast.
  const WorkflowOperationBroadcast({
    required this.operation,
    required this.timestamp,
    required this.senderId,
    required this.userId,
    required this.userName,
    required this.metadata,
  });

  /// Decodes the payload.
  factory WorkflowOperationBroadcast.fromJson(JsonMap json) =>
      WorkflowOperationBroadcast(
        operation: WorkflowOperation.fromJson(json),
        timestamp: readInt(json, 'timestamp'),
        senderId: readString(json, 'senderId'),
        userId: readString(json, 'userId'),
        userName: readString(json, 'userName'),
        metadata: OperationMetadata.fromJson(readMap(json, 'metadata')),
      );

  /// The operation to apply.
  final WorkflowOperation operation;

  /// The sender's timestamp.
  final int timestamp;

  /// The sender's socket id.
  final String senderId;

  /// The sender's user id.
  final String userId;

  /// The sender's display name.
  final String userName;

  /// Room and broadcast ids.
  final OperationMetadata metadata;

  @override
  String get name => ServerEventNames.workflowOperation;

  @override
  JsonMap toJson() => {
    'operation': operation.operation,
    'target': operation.target,
    'payload': operation.payload,
    'timestamp': timestamp,
    'senderId': senderId,
    'userId': userId,
    'userName': userName,
    'metadata': metadata.toJson(),
  };
}

/// `subblock-update` broadcast.
final class SubblockUpdateBroadcast extends ServerEvent {
  /// Creates the broadcast.
  const SubblockUpdateBroadcast({
    required this.workflowId,
    required this.blockId,
    required this.subblockId,
    required this.value,
    required this.timestamp,
  });

  /// Decodes the payload.
  factory SubblockUpdateBroadcast.fromJson(JsonMap json) =>
      SubblockUpdateBroadcast(
        workflowId: readString(json, 'workflowId'),
        blockId: readString(json, 'blockId'),
        subblockId: readString(json, 'subblockId'),
        value: json['value'],
        timestamp: readInt(json, 'timestamp'),
      );

  /// The room.
  final String workflowId;

  /// The block.
  final String blockId;

  /// The subblock.
  final String subblockId;

  /// The persisted value.
  final Object? value;

  /// The writer's timestamp.
  final int timestamp;

  @override
  String get name => ServerEventNames.subblockUpdate;

  @override
  JsonMap toJson() => {
    'workflowId': workflowId,
    'blockId': blockId,
    'subblockId': subblockId,
    'value': value,
    'timestamp': timestamp,
  };
}

/// `variable-update` broadcast.
final class VariableUpdateBroadcast extends ServerEvent {
  /// Creates the broadcast.
  const VariableUpdateBroadcast({
    required this.workflowId,
    required this.variableId,
    required this.field,
    required this.value,
    required this.timestamp,
  });

  /// Decodes the payload.
  factory VariableUpdateBroadcast.fromJson(JsonMap json) =>
      VariableUpdateBroadcast(
        workflowId: readString(json, 'workflowId'),
        variableId: readString(json, 'variableId'),
        field: readString(json, 'field'),
        value: json['value'],
        timestamp: readInt(json, 'timestamp'),
      );

  /// The room.
  final String workflowId;

  /// The variable.
  final String variableId;

  /// The written field.
  final String field;

  /// The persisted value.
  final Object? value;

  /// The writer's timestamp.
  final int timestamp;

  @override
  String get name => ServerEventNames.variableUpdate;

  @override
  JsonMap toJson() => {
    'workflowId': workflowId,
    'variableId': variableId,
    'field': field,
    'value': value,
    'timestamp': timestamp,
  };
}

/// `cursor-update` broadcast for one remote user.
final class CursorUpdateBroadcast extends ServerEvent {
  /// Creates the broadcast.
  const CursorUpdateBroadcast({
    required this.socketId,
    required this.userId,
    required this.userName,
    required this.cursor,
    this.avatarUrl,
  });

  /// Decodes the payload.
  factory CursorUpdateBroadcast.fromJson(JsonMap json) => CursorUpdateBroadcast(
    socketId: readString(json, 'socketId'),
    userId: readString(json, 'userId'),
    userName: readString(json, 'userName'),
    avatarUrl: readOptionalString(json, 'avatarUrl'),
    cursor: switch (json['cursor']) {
      null => null,
      final Object value => CursorPosition.fromJson(
        asJsonMap(value, path: 'cursor'),
      ),
    },
  );

  /// The remote socket.
  final String socketId;

  /// The remote user.
  final String userId;

  /// The remote display name.
  final String userName;

  /// The remote avatar.
  final String? avatarUrl;

  /// The pointer, `null` when it left the canvas.
  final CursorPosition? cursor;

  @override
  String get name => ServerEventNames.cursorUpdate;

  @override
  JsonMap toJson() => {
    'socketId': socketId,
    'userId': userId,
    'userName': userName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'cursor': cursor?.toJson(),
  };
}

/// `selection-update` broadcast for one remote user.
final class SelectionUpdateBroadcast extends ServerEvent {
  /// Creates the broadcast.
  const SelectionUpdateBroadcast({
    required this.socketId,
    required this.userId,
    required this.userName,
    required this.selection,
    this.avatarUrl,
  });

  /// Decodes the payload.
  factory SelectionUpdateBroadcast.fromJson(JsonMap json) =>
      SelectionUpdateBroadcast(
        socketId: readString(json, 'socketId'),
        userId: readString(json, 'userId'),
        userName: readString(json, 'userName'),
        avatarUrl: readOptionalString(json, 'avatarUrl'),
        selection: PresenceSelection.fromJson(readMap(json, 'selection')),
      );

  /// The remote socket.
  final String socketId;

  /// The remote user.
  final String userId;

  /// The remote display name.
  final String userName;

  /// The remote avatar.
  final String? avatarUrl;

  /// The remote selection.
  final PresenceSelection selection;

  @override
  String get name => ServerEventNames.selectionUpdate;

  @override
  JsonMap toJson() => {
    'socketId': socketId,
    'userId': userId,
    'userName': userName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'selection': selection.toJson(),
  };
}

/// `operation-confirmed {operationId, serverTimestamp}`.
final class OperationConfirmedEvent extends ServerEvent {
  /// Creates the ack.
  const OperationConfirmedEvent({
    required this.operationId,
    required this.serverTimestamp,
  });

  /// Decodes the payload.
  factory OperationConfirmedEvent.fromJson(JsonMap json) =>
      OperationConfirmedEvent(
        operationId: readString(json, 'operationId'),
        serverTimestamp: readInt(json, 'serverTimestamp'),
      );

  /// The confirmed queue id.
  final String operationId;

  /// Server epoch milliseconds.
  final int serverTimestamp;

  @override
  String get name => ServerEventNames.operationConfirmed;

  @override
  JsonMap toJson() => {
    'operationId': operationId,
    'serverTimestamp': serverTimestamp,
  };
}

/// `operation-failed {operationId, error, retryable?}`.
final class OperationFailedEvent extends ServerEvent {
  /// Creates the rejection.
  const OperationFailedEvent({
    required this.operationId,
    required this.error,
    this.retryable,
  });

  /// Decodes the payload.
  factory OperationFailedEvent.fromJson(JsonMap json) => OperationFailedEvent(
    operationId: readString(json, 'operationId'),
    error: readString(json, 'error'),
    retryable: readOptionalBool(json, 'retryable'),
  );

  /// The rejected queue id.
  final String operationId;

  /// Human readable reason.
  final String error;

  /// Absent means retryable (the queue's default).
  final bool? retryable;

  @override
  String get name => ServerEventNames.operationFailed;

  @override
  JsonMap toJson() => {
    'operationId': operationId,
    'error': error,
    if (retryable != null) 'retryable': retryable,
  };
}

/// `operation-error {type, message, operation?, target?, errors?}`.
final class OperationErrorEvent extends ServerEvent {
  /// Creates the diagnostic.
  const OperationErrorEvent({
    required this.type,
    required this.message,
    this.operation,
    this.target,
    this.errors,
  });

  /// Decodes the payload.
  factory OperationErrorEvent.fromJson(JsonMap json) => OperationErrorEvent(
    type: readString(json, 'type'),
    message: readString(json, 'message'),
    operation: readOptionalString(json, 'operation'),
    target: readOptionalString(json, 'target'),
    errors: readOptionalList(json, 'errors'),
  );

  /// `VALIDATION_ERROR`, `RESOURCE_NOT_FOUND`, `DUPLICATE_RESOURCE`, ...
  final String type;

  /// Human readable reason.
  final String message;

  /// The failed operation name.
  final String? operation;

  /// The failed operation target.
  final String? target;

  /// zod issues for `VALIDATION_ERROR`.
  final List<Object?>? errors;

  @override
  String get name => ServerEventNames.operationError;

  @override
  JsonMap toJson() => {
    'type': type,
    'message': message,
    if (operation != null) 'operation': operation,
    if (target != null) 'target': target,
    if (errors != null) 'errors': errors,
  };
}

/// `operation-forbidden {type, message, operation?, target?}`.
final class OperationForbiddenEvent extends ServerEvent {
  /// Creates the denial.
  const OperationForbiddenEvent({
    required this.type,
    required this.message,
    this.operation,
    this.target,
  });

  /// Decodes the payload.
  factory OperationForbiddenEvent.fromJson(JsonMap json) =>
      OperationForbiddenEvent(
        type: readString(json, 'type'),
        message: readString(json, 'message'),
        operation: readOptionalString(json, 'operation'),
        target: readOptionalString(json, 'target'),
      );

  /// A `type` that makes the client rejoin the room.
  static const String sessionErrorType = 'SESSION_ERROR';

  /// `SESSION_ERROR`, `INSUFFICIENT_PERMISSIONS`, `WORKFLOW_LOCKED`,
  /// `ROOM_MANAGER_UNAVAILABLE`.
  final String type;

  /// Human readable reason.
  final String message;

  /// The denied operation name.
  final String? operation;

  /// The denied operation target.
  final String? target;

  @override
  String get name => ServerEventNames.operationForbidden;

  @override
  JsonMap toJson() => {
    'type': type,
    'message': message,
    if (operation != null) 'operation': operation,
    if (target != null) 'target': target,
  };
}

/// Shared shape of the `{workflowId, message, timestamp}` lifecycle events.
sealed class WorkflowLifecycleEvent extends ServerEvent {
  const WorkflowLifecycleEvent({
    required this.workflowId,
    required this.message,
    required this.timestamp,
  });

  /// The affected workflow.
  final String workflowId;

  /// Human readable notice.
  final String message;

  /// Server epoch milliseconds.
  final int timestamp;

  @override
  JsonMap toJson() => {
    'workflowId': workflowId,
    'message': message,
    'timestamp': timestamp,
  };
}

/// `workflow-deleted`.
final class WorkflowDeletedEvent extends WorkflowLifecycleEvent {
  /// Creates the notice.
  const WorkflowDeletedEvent({
    required super.workflowId,
    required super.message,
    required super.timestamp,
  });

  /// Decodes the payload.
  factory WorkflowDeletedEvent.fromJson(JsonMap json) => WorkflowDeletedEvent(
    workflowId: readString(json, 'workflowId'),
    message: readString(json, 'message'),
    timestamp: readInt(json, 'timestamp'),
  );

  @override
  String get name => ServerEventNames.workflowDeleted;
}

/// `workflow-reverted`.
final class WorkflowRevertedEvent extends WorkflowLifecycleEvent {
  /// Creates the notice.
  const WorkflowRevertedEvent({
    required super.workflowId,
    required super.message,
    required super.timestamp,
  });

  /// Decodes the payload.
  factory WorkflowRevertedEvent.fromJson(JsonMap json) => WorkflowRevertedEvent(
    workflowId: readString(json, 'workflowId'),
    message: readString(json, 'message'),
    timestamp: readInt(json, 'timestamp'),
  );

  @override
  String get name => ServerEventNames.workflowReverted;
}

/// `workflow-updated`.
final class WorkflowUpdatedEvent extends WorkflowLifecycleEvent {
  /// Creates the notice.
  const WorkflowUpdatedEvent({
    required super.workflowId,
    required super.message,
    required super.timestamp,
  });

  /// Decodes the payload.
  factory WorkflowUpdatedEvent.fromJson(JsonMap json) => WorkflowUpdatedEvent(
    workflowId: readString(json, 'workflowId'),
    message: readString(json, 'message'),
    timestamp: readInt(json, 'timestamp'),
  );

  @override
  String get name => ServerEventNames.workflowUpdated;
}

/// `access-revoked`: this socket alone was evicted from the workflow.
final class AccessRevokedEvent extends WorkflowLifecycleEvent {
  /// Creates the notice.
  const AccessRevokedEvent({
    required super.workflowId,
    required super.message,
    required super.timestamp,
  });

  /// Decodes the payload.
  factory AccessRevokedEvent.fromJson(JsonMap json) => AccessRevokedEvent(
    workflowId: readString(json, 'workflowId'),
    message: readString(json, 'message'),
    timestamp: readInt(json, 'timestamp'),
  );

  @override
  String get name => ServerEventNames.accessRevoked;
}

/// `workflow-deployed {workflowId, timestamp}`.
final class WorkflowDeployedEvent extends ServerEvent {
  /// Creates the notice.
  const WorkflowDeployedEvent({
    required this.workflowId,
    required this.timestamp,
  });

  /// Decodes the payload.
  factory WorkflowDeployedEvent.fromJson(JsonMap json) => WorkflowDeployedEvent(
    workflowId: readString(json, 'workflowId'),
    timestamp: readInt(json, 'timestamp'),
  );

  /// The affected workflow.
  final String workflowId;

  /// Server epoch milliseconds.
  final int timestamp;

  @override
  String get name => ServerEventNames.workflowDeployed;

  @override
  JsonMap toJson() => {'workflowId': workflowId, 'timestamp': timestamp};
}

/// `room-access-revoked {room, message, timestamp}`.
final class RoomAccessRevokedEvent extends ServerEvent {
  /// Creates the notice.
  const RoomAccessRevokedEvent({
    required this.room,
    required this.message,
    required this.timestamp,
  });

  /// Decodes the payload.
  factory RoomAccessRevokedEvent.fromJson(JsonMap json) =>
      RoomAccessRevokedEvent(
        room: RoomRef.fromJson(readMap(json, 'room')),
        message: readString(json, 'message'),
        timestamp: readInt(json, 'timestamp'),
      );

  /// The room this socket lost.
  final RoomRef room;

  /// Human readable notice.
  final String message;

  /// Server epoch milliseconds.
  final int timestamp;

  @override
  String get name => ServerEventNames.roomAccessRevoked;

  @override
  JsonMap toJson() => {
    'room': room.toJson(),
    'message': message,
    'timestamp': timestamp,
  };
}
