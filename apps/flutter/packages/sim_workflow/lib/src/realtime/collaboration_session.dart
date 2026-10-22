/// The collaborative editing session facade.
///
/// Port of the room, presence and acknowledgement handling of
/// `apps/sim/app/workspace/providers/socket-provider.tsx` and the remote-apply
/// dispatch of `hooks/use-collaborative-workflow.ts`, over a
/// [RealtimeTransport]. Socket creation, authentication and reconnection
/// backoff belong to the transport (`sim_api`); this class owns room
/// membership, the operation queue wiring, presence and the notices.
library;

import 'dart:async';

import 'package:sim_workflow/src/realtime/clock.dart';
import 'package:sim_workflow/src/realtime/events.dart';
import 'package:sim_workflow/src/realtime/join_controller.dart';
import 'package:sim_workflow/src/realtime/json.dart';
import 'package:sim_workflow/src/realtime/logger.dart';
import 'package:sim_workflow/src/realtime/operation_queue.dart';
import 'package:sim_workflow/src/realtime/operations.dart';
import 'package:sim_workflow/src/realtime/position_coalescer.dart';
import 'package:sim_workflow/src/realtime/presence.dart';
import 'package:sim_workflow/src/realtime/remote_apply_guard.dart';
import 'package:sim_workflow/src/realtime/transport.dart';

/// Re-syncs the editor from `GET /api/workflows/[id]/state` (the migrated
/// state). Returns whether the snapshot was applied; throws when the fetch
/// itself fails, which is the only case the raw socket payload is used.
typedef ResyncWorkflow = Future<bool> Function(String workflowId);

/// Applies the raw `workflow-state` payload to local state (the degraded
/// fallback). Returns whether it was applied.
typedef ApplyRawWorkflowState =
    FutureOr<bool> Function(String workflowId, JsonMap state);

/// How a [CollaborationSession.join] request ended.
enum JoinOutcome {
  /// The room was joined and is visible.
  joined,

  /// The server denied the join non-retryably (access denied, deleted).
  blocked,

  /// Another [CollaborationSession.join] or [CollaborationSession.leave]
  /// replaced the request before it was acknowledged.
  superseded,
}

/// A lifecycle notice from the server, for the app to surface or act on.
sealed class CollaborationNotice {
  const CollaborationNotice();
}

/// The workflow was deleted; the room was left and further edits are blocked.
final class WorkflowDeletedNotice extends CollaborationNotice {
  /// Wraps the event.
  const WorkflowDeletedNotice(this.event);

  /// The wire event.
  final WorkflowDeletedEvent event;
}

/// The workflow was reverted; the app reloads it over HTTP.
final class WorkflowRevertedNotice extends CollaborationNotice {
  /// Wraps the event.
  const WorkflowRevertedNotice(this.event);

  /// The wire event.
  final WorkflowRevertedEvent event;
}

/// The workflow was updated externally; the app reloads it over HTTP.
final class WorkflowUpdatedNotice extends CollaborationNotice {
  /// Wraps the event.
  const WorkflowUpdatedNotice(this.event);

  /// The wire event.
  final WorkflowUpdatedEvent event;
}

/// The deployment state changed; the app invalidates deployment queries.
final class WorkflowDeployedNotice extends CollaborationNotice {
  /// Wraps the event.
  const WorkflowDeployedNotice(this.event);

  /// The wire event.
  final WorkflowDeployedEvent event;
}

/// This user lost access; the room was left and edits are blocked.
final class AccessRevokedNotice extends CollaborationNotice {
  /// Wraps the event.
  const AccessRevokedNotice(this.event);

  /// The wire event.
  final AccessRevokedEvent event;
}

/// This socket lost a non-workflow room.
final class RoomAccessRevokedNotice extends CollaborationNotice {
  /// Wraps the event.
  const RoomAccessRevokedNotice(this.event);

  /// The wire event.
  final RoomAccessRevokedEvent event;
}

/// The session.
class CollaborationSession {
  /// Creates a session over [transport].
  ///
  /// [tabSessionId] identifies this tab to the server (so a reload evicts the
  /// tab's stale socket). [resync] runs on every `workflow-state`; its raw
  /// payload reaches [applyRawState] only when [resync] throws and nothing
  /// changed locally meanwhile. [generateId] mints operation ids for
  /// [execute] (the app passes its UUID v4 generator).
  CollaborationSession({
    required RealtimeTransport transport,
    required Clock clock,
    required String tabSessionId,
    required ResyncWorkflow resync,
    ApplyRawWorkflowState? applyRawState,
    OperationQueue? queue,
    String Function()? generateId,
    RealtimeLogger logger = noopRealtimeLogger,
  }) : _transport = transport,
       _clock = clock,
       _tabSessionId = tabSessionId,
       _resync = resync,
       _applyRawState = applyRawState,
       _generateId = generateId,
       _log = logger,
       queue = queue ?? OperationQueue(clock: clock, logger: logger) {
    _coalescer = PositionUpdateCoalescer(clock: clock, send: _transport.send);
    _connectionSubscription = _transport.connectionStates.listen(
      _onConnectionState,
    );
    _eventSubscription = _transport.events.listen(_onServerEvent);
    _onConnectionState(_transport.state);
  }

  /// Minimum interval between `cursor-update` emits.
  static const Duration cursorThrottle = Duration(milliseconds: 33);

  final RealtimeTransport _transport;
  final Clock _clock;
  final String _tabSessionId;
  final ResyncWorkflow _resync;
  final ApplyRawWorkflowState? _applyRawState;
  final String Function()? _generateId;
  final RealtimeLogger _log;

  /// The operation queue this session feeds and drains.
  final OperationQueue queue;

  final JoinController _joinController = JoinController();
  late final PositionUpdateCoalescer _coalescer;
  late final StreamSubscription<ConnectionState> _connectionSubscription;
  late final StreamSubscription<ServerEvent> _eventSubscription;

  final StreamController<List<UserPresence>> _presenceController =
      StreamController<List<UserPresence>>.broadcast(sync: true);
  final StreamController<CollaborationNotice> _noticeController =
      StreamController<CollaborationNotice>.broadcast(sync: true);
  final StreamController<WorkflowStateEvent> _workflowStateController =
      StreamController<WorkflowStateEvent>.broadcast(sync: true);
  final StreamController<String?> _joinedWorkflowController =
      StreamController<String?>.broadcast(sync: true);

  final Map<String, Completer<JoinOutcome>> _joinCompleters = {};
  List<UserPresence> _presenceUsers = const [];
  String? _requestedWorkflowId;
  String? _currentWorkflowId;
  String? _blockedJoinWorkflowId;
  bool _isRetryingWorkflowJoin = false;
  bool _isConnected = false;
  Timer? _joinRetryTimer;
  int? _lastCursorEmitMs;
  int _idCounter = 0;

  /// Handler for a collaborator's structural operation, run under the
  /// remote-apply guard. Per-frame `update-position` broadcasts are delivered
  /// too but do not count as applied remote state.
  void Function(WorkflowOperationBroadcast broadcast)? onWorkflowOperation;

  /// Handler for a collaborator's subblock write, run under the guard.
  void Function(SubblockUpdateBroadcast broadcast)? onSubblockUpdate;

  /// Handler for a collaborator's variable write, run under the guard.
  void Function(VariableUpdateBroadcast broadcast)? onVariableUpdate;

  /// Handler for a collaborator's cursor move (presence is updated first).
  void Function(CursorUpdateBroadcast broadcast)? onCursorUpdate;

  /// Handler for a collaborator's selection change (presence updated first).
  void Function(SelectionUpdateBroadcast broadcast)? onSelectionUpdate;

  /// Handler for `operation-error` diagnostics.
  void Function(OperationErrorEvent event)? onOperationError;

  /// Handler for `operation-forbidden` (a `SESSION_ERROR` also rejoins).
  void Function(OperationForbiddenEvent event)? onOperationForbidden;

  /// The guard shared with the queue.
  RemoteApplyGuard get remoteApplyGuard => queue.remoteApplyGuard;

  /// The room the app asked for.
  String? get requestedWorkflowId => _requestedWorkflowId;

  /// The room the server acknowledged and that is still requested.
  String? get joinedWorkflowId => _currentWorkflowId;

  /// The workflow whose join was denied non-retryably.
  String? get blockedJoinWorkflowId => _blockedJoinWorkflowId;

  /// Whether a retryable join failure is waiting for its backoff.
  bool get isRetryingWorkflowJoin => _isRetryingWorkflowJoin;

  /// Whether the transport is connected.
  bool get isConnected => _isConnected;

  /// Whether operations may be emitted for the requested room.
  bool get isWorkflowVisible => _isVisible(_currentWorkflowId);

  /// The current roster.
  List<UserPresence> get presenceUsers => _presenceUsers;

  /// Every roster change.
  Stream<List<UserPresence>> get presence => _presenceController.stream;

  /// Lifecycle notices.
  Stream<CollaborationNotice> get notices => _noticeController.stream;

  /// Every `workflow-state` for the visible room, before the re-sync starts.
  Stream<WorkflowStateEvent> get workflowStates =>
      _workflowStateController.stream;

  /// Every change of [joinedWorkflowId].
  Stream<String?> get joinedWorkflows => _joinedWorkflowController.stream;

  /// Requests the room of [workflowId]. Completes when the server
  /// acknowledges the join, denies it non-retryably, or the request is
  /// replaced. The join is (re)sent automatically on every reconnect.
  Future<JoinOutcome> join(String workflowId) {
    if (_requestedWorkflowId != workflowId) {
      _completePendingJoins(JoinOutcome.superseded);
    }
    _requestedWorkflowId = workflowId;
    if (_blockedJoinWorkflowId != null &&
        _blockedJoinWorkflowId != workflowId) {
      _blockedJoinWorkflowId = null;
    }
    final completer = _joinCompleters.putIfAbsent(
      workflowId,
      Completer<JoinOutcome>.new,
    );
    _executeJoinCommands(_joinController.requestWorkflow(workflowId));
    _syncRegisteredWorkflow();
    if (_currentWorkflowId == workflowId && !completer.isCompleted) {
      completer.complete(JoinOutcome.joined);
    }
    return completer.future;
  }

  /// Leaves the current room (if any) and stops rejoining.
  void leave() {
    _completePendingJoins(JoinOutcome.superseded);
    _requestedWorkflowId = null;
    _executeJoinCommands(_joinController.requestWorkflow(null));
    _syncRegisteredWorkflow();
  }

  /// `executeQueuedOperation`: queues [operation] for the requested room and
  /// runs [localAction]. Returns the operation id, or `null` when skipped
  /// (no requested room, or a remote change is being applied).
  String? execute(
    WorkflowOperation operation, {
    required String userId,
    void Function()? localAction,
  }) {
    final workflowId = _requestedWorkflowId;
    if (workflowId == null) {
      _log(RealtimeLogLevel.debug, 'Skipping operation - no active workflow', {
        'operation': operation.operation,
        'target': operation.target,
      });
      return null;
    }
    final operationId = _nextId();
    final queued = queue.execute(
      operationId: operationId,
      operation: operation,
      workflowId: workflowId,
      userId: userId,
      localAction: localAction,
    );
    return queued ? operationId : null;
  }

  /// Emits the local pointer, throttled to [cursorThrottle]; `null` (pointer
  /// left the canvas) is always sent.
  void emitCursor(CursorPosition? cursor) {
    if (!isWorkflowVisible) return;
    final now = _clock.nowMs;
    if (cursor == null) {
      _transport.send(const CursorUpdateEvent(null));
      _lastCursorEmitMs = now;
      return;
    }
    final last = _lastCursorEmitMs;
    if (last == null || now - last >= cursorThrottle.inMilliseconds) {
      _transport.send(CursorUpdateEvent(cursor));
      _lastCursorEmitMs = now;
    }
  }

  /// Emits the local selection.
  void emitSelection(PresenceSelection selection) {
    if (!isWorkflowVisible) return;
    _transport.send(SelectionUpdateEvent(selection));
  }

  /// Stops listening to the transport and releases timers and streams. The
  /// transport itself stays open for its owner.
  Future<void> dispose() async {
    _joinRetryTimer?.cancel();
    _coalescer.clear();
    _completePendingJoins(JoinOutcome.superseded);
    await _connectionSubscription.cancel();
    await _eventSubscription.cancel();
    await _presenceController.close();
    await _noticeController.close();
    await _workflowStateController.close();
    await _joinedWorkflowController.close();
  }

  bool _isVisible(String? workflowId) =>
      workflowId != null && workflowId == _requestedWorkflowId;

  String _nextId() {
    final generate = _generateId;
    if (generate != null) return generate();
    _idCounter += 1;
    return 'op-${_clock.nowMs}-$_idCounter';
  }

  void _onConnectionState(ConnectionState state) {
    final connected = state == ConnectionState.connected;
    if (connected == _isConnected) return;
    _isConnected = connected;
    if (connected) {
      _executeJoinCommands(_joinController.setConnected(connected: true));
    } else {
      _isRetryingWorkflowJoin = false;
      _executeJoinCommands(_joinController.setConnected(connected: false));
      _clearJoinedWorkflowState(cancelOperations: false);
    }
    _syncRegisteredWorkflow();
  }

  void _executeJoinCommands(List<JoinCommand> commands) {
    for (final command in commands) {
      switch (command) {
        case CancelRetryCommand():
          _joinRetryTimer?.cancel();
          _joinRetryTimer = null;
          _isRetryingWorkflowJoin = false;
        case LeaveRoomCommand():
          _isRetryingWorkflowJoin = false;
          _clearJoinedWorkflowState(cancelOperations: true);
          _log(RealtimeLogLevel.info, 'Leaving current workflow room');
          _transport.send(const LeaveWorkflowEvent());
        case JoinRoomCommand(:final workflowId):
          final current = _currentWorkflowId;
          final isWorkflowSwitch = current != null && current != workflowId;
          _resetVisibleWorkflowState(isWorkflowSwitch ? current : null);
          _log(RealtimeLogLevel.info, 'Joining workflow room: $workflowId');
          _transport.send(
            JoinWorkflowEvent(
              workflowId: workflowId,
              tabSessionId: _tabSessionId,
            ),
          );
        case ScheduleRetryCommand(
          :final workflowId,
          :final attempt,
          :final delay,
        ):
          _joinRetryTimer?.cancel();
          _isRetryingWorkflowJoin = true;
          _joinRetryTimer = _clock.schedule(delay, () {
            _joinRetryTimer = null;
            _executeJoinCommands(_joinController.retryJoin(workflowId));
          });
          _log(
            RealtimeLogLevel.warn,
            'Realtime unavailable while joining workflow, scheduling retry',
            {
              'workflowId': workflowId,
              'attempt': attempt,
              'delayMs': delay.inMilliseconds,
            },
          );
      }
    }
  }

  void _resetVisibleWorkflowState(String? workflowId) {
    if (workflowId != null) {
      queue.cancelOperationsForWorkflow(workflowId);
    }
    _coalescer.clear();
  }

  void _clearJoinedWorkflowState({required bool cancelOperations}) {
    final previous = _currentWorkflowId;
    _resetVisibleWorkflowState(cancelOperations ? previous : null);
    _setPresence(const []);
    _setVisibleWorkflowId(null);
  }

  void _setVisibleWorkflowId(String? workflowId) {
    if (_currentWorkflowId == workflowId) return;
    _currentWorkflowId = workflowId;
    _joinedWorkflowController.add(workflowId);
    _syncRegisteredWorkflow();
  }

  void _setPresence(List<UserPresence> users) {
    _presenceUsers = List.unmodifiable(users);
    _presenceController.add(_presenceUsers);
  }

  void _syncRegisteredWorkflow() {
    final registered =
        _isConnected && _currentWorkflowId == _requestedWorkflowId
        ? _currentWorkflowId
        : null;
    if (registered == queue.registeredWorkflowId && registered == null) return;
    queue.registerEmitters(
      workflowEmit: _emitWorkflowOperation,
      subblockEmit: _emitSubblockUpdate,
      variableEmit: _emitVariableUpdate,
      workflowId: registered,
    );
  }

  bool _emitWorkflowOperation(
    String workflowId,
    WorkflowOperation operation,
    String operationId,
  ) {
    final current = _currentWorkflowId;
    if (current == null || workflowId != current || !_isVisible(workflowId)) {
      _log(
        RealtimeLogLevel.debug,
        'Skipping workflow operation emit for inactive room',
        {
          'workflowId': workflowId,
          'currentWorkflowId': current,
          'operation': operation.operation,
          'target': operation.target,
        },
      );
      return false;
    }
    return _coalescer.emit(
      WorkflowOperationEvent(
        workflowId: workflowId,
        operation: operation,
        timestamp: _clock.nowMs,
        operationId: operationId,
      ),
    );
  }

  bool _emitSubblockUpdate(
    String workflowId,
    String blockId,
    String subblockId,
    Object? value,
    String operationId,
  ) {
    if (workflowId != _currentWorkflowId || !_isVisible(workflowId)) {
      _log(RealtimeLogLevel.debug, 'Skipping subblock update emit', {
        'workflowId': workflowId,
        'blockId': blockId,
        'subblockId': subblockId,
        'currentWorkflowId': _currentWorkflowId,
      });
      return false;
    }
    return _transport.send(
      SubblockUpdateEvent(
        workflowId: workflowId,
        blockId: blockId,
        subblockId: subblockId,
        value: value,
        timestamp: _clock.nowMs,
        operationId: operationId,
      ),
    );
  }

  bool _emitVariableUpdate(
    String workflowId,
    String variableId,
    String field,
    Object? value,
    String operationId,
  ) {
    if (workflowId != _currentWorkflowId || !_isVisible(workflowId)) {
      _log(RealtimeLogLevel.debug, 'Skipping variable update emit', {
        'workflowId': workflowId,
        'variableId': variableId,
        'field': field,
        'currentWorkflowId': _currentWorkflowId,
      });
      return false;
    }
    return _transport.send(
      VariableUpdateEvent(
        workflowId: workflowId,
        variableId: variableId,
        field: field,
        value: value,
        timestamp: _clock.nowMs,
        operationId: operationId,
      ),
    );
  }

  void _completePendingJoins(JoinOutcome outcome, {String? only}) {
    final ids = only == null ? _joinCompleters.keys.toList() : [only];
    for (final id in ids) {
      final completer = _joinCompleters.remove(id);
      if (completer != null && !completer.isCompleted) {
        completer.complete(outcome);
      }
    }
  }

  void _onServerEvent(ServerEvent event) {
    switch (event) {
      case JoinWorkflowSuccessEvent():
        _onJoinSuccess(event);
      case JoinWorkflowErrorEvent():
        _onJoinError(event);
      case WorkflowStateEvent():
        _onWorkflowState(event);
      case PresenceUpdateEvent(:final users):
        if (!isWorkflowVisible) return;
        _setPresence(mergePresenceRoster(_presenceUsers, users));
      case WorkflowOperationBroadcast():
        _onWorkflowOperation(event);
      case SubblockUpdateBroadcast():
        _onSubblockUpdate(event);
      case VariableUpdateBroadcast():
        _onVariableUpdate(event);
      case CursorUpdateBroadcast():
        if (!isWorkflowVisible) return;
        _updatePresenceUser(
          event.socketId,
          (user) => user.withCursor(event.cursor),
        );
        onCursorUpdate?.call(event);
      case SelectionUpdateBroadcast():
        if (!isWorkflowVisible) return;
        _updatePresenceUser(
          event.socketId,
          (user) => user.withSelection(event.selection),
        );
        onSelectionUpdate?.call(event);
      case OperationConfirmedEvent(:final operationId):
        _log(RealtimeLogLevel.debug, 'Operation confirmed', {
          'operationId': operationId,
        });
        queue.confirmOperation(operationId);
      case OperationFailedEvent(
        :final operationId,
        :final error,
        :final retryable,
      ):
        _log(RealtimeLogLevel.warn, 'Operation failed', {
          'operationId': operationId,
          'error': error,
          'retryable': retryable,
        });
        queue.failOperation(operationId, retryable: retryable ?? true);
      case OperationErrorEvent():
        _log(RealtimeLogLevel.error, 'Operation error: ${event.message}');
        onOperationError?.call(event);
      case OperationForbiddenEvent():
        _log(RealtimeLogLevel.warn, 'Operation forbidden: ${event.message}');
        onOperationForbidden?.call(event);
        if (event.type == OperationForbiddenEvent.sessionErrorType) {
          final workflowId = _requestedWorkflowId;
          if (workflowId != null) {
            _log(
              RealtimeLogLevel.info,
              'Session expired, rejoining workflow: $workflowId',
            );
            _executeJoinCommands(
              _joinController.forceRejoinWorkflow(workflowId),
            );
          }
        }
      case WorkflowDeletedEvent():
        _evict(event.workflowId, _joinController.handleWorkflowDeleted);
        _noticeController.add(WorkflowDeletedNotice(event));
      case AccessRevokedEvent():
        _evict(event.workflowId, _joinController.handleAccessRevoked);
        _noticeController.add(AccessRevokedNotice(event));
      case WorkflowRevertedEvent():
        _noticeController.add(WorkflowRevertedNotice(event));
      case WorkflowUpdatedEvent():
        _noticeController.add(WorkflowUpdatedNotice(event));
      case WorkflowDeployedEvent():
        _noticeController.add(WorkflowDeployedNotice(event));
      case RoomAccessRevokedEvent():
        _noticeController.add(RoomAccessRevokedNotice(event));
      case UnknownEvent(:final name):
        _log(RealtimeLogLevel.debug, 'Ignoring unknown socket event', {
          'event': name,
        });
      case MalformedEvent(:final name, :final error):
        _log(RealtimeLogLevel.warn, 'Ignoring malformed socket event', {
          'event': name,
          'error': error.toString(),
        });
    }
  }

  void _onJoinSuccess(JoinWorkflowSuccessEvent event) {
    final result = _joinController.handleJoinSuccess(event.workflowId);
    if (result.ignored) {
      _log(
        RealtimeLogLevel.debug,
        'Ignoring stale join-workflow-success for ${event.workflowId}',
      );
    } else {
      _isRetryingWorkflowJoin = false;
      _blockedJoinWorkflowId = null;
      _setVisibleWorkflowId(event.workflowId);
      _setPresence(event.presenceUsers);
      _log(
        RealtimeLogLevel.info,
        'Successfully joined workflow room: ${event.workflowId}',
        {'presenceCount': event.presenceUsers.length},
      );
      _completePendingJoins(JoinOutcome.joined, only: event.workflowId);
    }
    _executeJoinCommands(result.commands);
    _syncRegisteredWorkflow();
  }

  void _onJoinError(JoinWorkflowErrorEvent event) {
    final result = _joinController.handleJoinError(
      workflowId: event.workflowId.isEmpty ? null : event.workflowId,
      retryable: event.retryable,
    );
    if (result.ignored) {
      _log(RealtimeLogLevel.debug, 'Ignoring stale join-workflow-error', {
        'workflowId': result.workflowId,
        'error': event.error,
        'code': event.code,
      });
    } else if (result.retryScheduled) {
      _log(
        RealtimeLogLevel.warn,
        'Retryable workflow join failure, waiting to retry',
        {
          'workflowId': result.workflowId,
          'error': event.error,
          'code': event.code,
        },
      );
    } else if (result.apply) {
      _isRetryingWorkflowJoin = false;
      final workflowId = result.workflowId;
      if (workflowId != null) {
        queue.cancelOperationsForWorkflow(workflowId);
      }
      _blockedJoinWorkflowId = workflowId;
      _log(RealtimeLogLevel.error, 'Failed to join workflow', {
        'workflowId': workflowId,
        'error': event.error,
        'code': event.code,
      });
      if (workflowId != null) {
        _completePendingJoins(JoinOutcome.blocked, only: workflowId);
      }
    }
    _executeJoinCommands(result.commands);
    _syncRegisteredWorkflow();
  }

  void _evict(
    String workflowId,
    JoinEvictResult Function(String workflowId) handle,
  ) {
    final result = handle(workflowId);
    if (result.shouldClearCurrent) {
      _clearJoinedWorkflowState(cancelOperations: true);
      _blockedJoinWorkflowId = workflowId;
    }
    _executeJoinCommands(result.commands);
    if (_requestedWorkflowId == workflowId) {
      remoteApplyGuard.release();
      _completePendingJoins(JoinOutcome.blocked, only: workflowId);
    }
    _syncRegisteredWorkflow();
  }

  void _onWorkflowState(WorkflowStateEvent event) {
    _log(RealtimeLogLevel.info, 'Received workflow state from server');
    if (_currentWorkflowId != event.id || !isWorkflowVisible) {
      _log(RealtimeLogLevel.info, 'Ignoring workflow state for inactive room', {
        'workflowId': event.id,
        'currentWorkflowId': _currentWorkflowId,
        'requestedWorkflowId': _requestedWorkflowId,
      });
      return;
    }
    _workflowStateController.add(event);
    final state = event.state;
    if (state == null) return;
    unawaited(_resyncAfterJoin(event.id, state));
  }

  Future<void> _resyncAfterJoin(String workflowId, JsonMap state) async {
    final localVersionAtJoin = queue.workflowOperationVersions[workflowId] ?? 0;
    final remoteVersionAtJoin = queue.remoteApplyVersions[workflowId] ?? 0;
    try {
      final synced = await _resync(workflowId);
      if (!synced) {
        _log(
          RealtimeLogLevel.info,
          'Join-state sync skipped; keeping local state',
          {
            'workflowId': workflowId,
          },
        );
      }
    } on Object catch (error) {
      _log(
        RealtimeLogLevel.warn,
        'Join-state sync failed; falling back to raw socket state',
        {'error': error.toString()},
      );
      final unchanged =
          _currentWorkflowId == workflowId &&
          !queue.hasPendingOperations(workflowId) &&
          (queue.workflowOperationVersions[workflowId] ?? 0) ==
              localVersionAtJoin &&
          (queue.remoteApplyVersions[workflowId] ?? 0) == remoteVersionAtJoin;
      if (!unchanged) {
        _log(
          RealtimeLogLevel.info,
          'Skipping raw join-state fallback; stores changed since join',
          {'workflowId': workflowId},
        );
        return;
      }
      final apply = _applyRawState;
      if (apply == null) return;
      try {
        final applied = await apply(workflowId, state);
        if (applied) {
          _log(
            RealtimeLogLevel.info,
            'Successfully rehydrated workflow stores',
          );
        }
      } on Object catch (rehydrateError) {
        _log(RealtimeLogLevel.error, 'Error rehydrating workflow state', {
          'error': rehydrateError.toString(),
        });
      }
    }
  }

  void _onWorkflowOperation(WorkflowOperationBroadcast broadcast) {
    final handler = onWorkflowOperation;
    final workflowId = broadcast.metadata.workflowId;
    if (remoteApplyGuard.isApplying) return;
    if (workflowId != _requestedWorkflowId) {
      _log(
        RealtimeLogLevel.debug,
        'Ignoring workflow operation for different workflow',
        {
          'broadcastWorkflowId': workflowId,
          'activeWorkflowId': _requestedWorkflowId,
        },
      );
      return;
    }
    final operation = broadcast.operation;
    final isUnappliedPositionFrame = operation is UpdatePositionOperation;
    remoteApplyGuard.run(() {
      try {
        handler?.call(broadcast);
        if (!isUnappliedPositionFrame) {
          queue.markRemoteApplied(workflowId);
        }
      } on Object catch (error) {
        _log(RealtimeLogLevel.error, 'Error applying remote operation', {
          'error': error.toString(),
        });
      }
    });
  }

  void _onSubblockUpdate(SubblockUpdateBroadcast broadcast) {
    final handler = onSubblockUpdate;
    if (remoteApplyGuard.isApplying) return;
    if (broadcast.workflowId != _requestedWorkflowId) {
      _log(
        RealtimeLogLevel.debug,
        'Ignoring subblock update for different workflow',
        {
          'broadcastWorkflowId': broadcast.workflowId,
          'activeWorkflowId': _requestedWorkflowId,
        },
      );
      return;
    }
    remoteApplyGuard.run(() {
      try {
        handler?.call(broadcast);
        queue.markRemoteApplied(broadcast.workflowId);
      } on Object catch (error) {
        _log(RealtimeLogLevel.error, 'Error applying remote subblock update', {
          'error': error.toString(),
        });
      }
    });
  }

  void _onVariableUpdate(VariableUpdateBroadcast broadcast) {
    final handler = onVariableUpdate;
    if (remoteApplyGuard.isApplying) return;
    if (broadcast.workflowId != _requestedWorkflowId) {
      _log(
        RealtimeLogLevel.debug,
        'Ignoring variable update for different workflow',
        {
          'broadcastWorkflowId': broadcast.workflowId,
          'activeWorkflowId': _requestedWorkflowId,
        },
      );
      return;
    }
    const knownFields = {'name', 'value', 'type'};
    remoteApplyGuard.run(() {
      try {
        handler?.call(broadcast);
        if (knownFields.contains(broadcast.field)) {
          queue.markRemoteApplied(broadcast.workflowId);
        }
      } on Object catch (error) {
        _log(RealtimeLogLevel.error, 'Error applying remote variable update', {
          'error': error.toString(),
        });
      }
    });
  }

  void _updatePresenceUser(
    String socketId,
    UserPresence Function(UserPresence user) update,
  ) {
    final index = _presenceUsers.indexWhere((u) => u.socketId == socketId);
    if (index == -1) {
      _log(RealtimeLogLevel.debug, 'Received presence delta for unknown user', {
        'socketId': socketId,
      });
      return;
    }
    final users = [..._presenceUsers];
    users[index] = update(users[index]);
    _setPresence(users);
  }
}
