/// Coordinates desired workflow room membership with async socket join
/// results. Port of `socket-join-controller.ts`: a pure state machine that
/// returns commands for the transport layer to execute.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Base delay of the join retry backoff.
const Duration socketJoinRetryBaseDelay = Duration(seconds: 1);

/// Cap of the join retry backoff.
const Duration socketJoinRetryMaxDelay = Duration(seconds: 10);

/// Something the transport layer must do after a controller transition.
sealed class JoinCommand {
  const JoinCommand();
}

/// Cancel a scheduled join retry.
@immutable
final class CancelRetryCommand extends JoinCommand {
  /// Creates the command.
  const CancelRetryCommand();

  @override
  bool operator ==(Object other) => other is CancelRetryCommand;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'CancelRetryCommand()';
}

/// Emit `join-workflow` for [workflowId].
@immutable
final class JoinRoomCommand extends JoinCommand {
  /// Creates the command.
  const JoinRoomCommand(this.workflowId);

  /// The workflow to join.
  final String workflowId;

  @override
  bool operator ==(Object other) =>
      other is JoinRoomCommand && other.workflowId == workflowId;

  @override
  int get hashCode => workflowId.hashCode;

  @override
  String toString() => 'JoinRoomCommand($workflowId)';
}

/// Emit `leave-workflow` and clear the joined state.
@immutable
final class LeaveRoomCommand extends JoinCommand {
  /// Creates the command.
  const LeaveRoomCommand();

  @override
  bool operator ==(Object other) => other is LeaveRoomCommand;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'LeaveRoomCommand()';
}

/// Retry the join of [workflowId] after [delay].
@immutable
final class ScheduleRetryCommand extends JoinCommand {
  /// Creates the command.
  const ScheduleRetryCommand({
    required this.workflowId,
    required this.attempt,
    required this.delay,
  });

  /// The workflow to retry.
  final String workflowId;

  /// 1-based attempt number.
  final int attempt;

  /// Backoff before the retry.
  final Duration delay;

  @override
  bool operator ==(Object other) =>
      other is ScheduleRetryCommand &&
      other.workflowId == workflowId &&
      other.attempt == attempt &&
      other.delay == delay;

  @override
  int get hashCode => Object.hash(workflowId, attempt, delay);

  @override
  String toString() => 'ScheduleRetryCommand($workflowId, $attempt, $delay)';
}

/// Outcome of a `join-workflow-success`.
class JoinSuccessResult {
  /// Creates the result.
  const JoinSuccessResult({
    required this.apply,
    required this.commands,
    required this.workflowId,
  });

  /// Whether the success is for the desired, unblocked workflow.
  final bool apply;

  /// Follow-up commands.
  final List<JoinCommand> commands;

  /// The joined workflow.
  final String workflowId;

  /// A stale success (room already left or superseded) is ignored.
  bool get ignored => !apply;
}

/// Outcome of a `join-workflow-error`.
class JoinErrorResult {
  /// Creates the result.
  const JoinErrorResult({
    required this.apply,
    required this.commands,
    required this.ignored,
    required this.retryScheduled,
    required this.workflowId,
  });

  /// Whether the error blocks the desired workflow.
  final bool apply;

  /// Follow-up commands.
  final List<JoinCommand> commands;

  /// Whether the error concerns a workflow no longer desired.
  final bool ignored;

  /// Whether a retry was scheduled instead of blocking.
  final bool retryScheduled;

  /// The workflow the error resolved to.
  final String? workflowId;
}

/// Outcome of a `workflow-deleted` or `access-revoked` eviction.
class JoinEvictResult {
  /// Creates the result.
  const JoinEvictResult({
    required this.commands,
    required this.shouldClearCurrent,
  });

  /// Follow-up commands.
  final List<JoinCommand> commands;

  /// Whether the evicted workflow was the joined one.
  final bool shouldClearCurrent;
}

/// The join state machine.
class JoinController {
  String? _desiredWorkflowId;
  String? _joinedWorkflowId;
  String? _pendingJoinWorkflowId;
  String? _blockedWorkflowId;
  String? _retryWorkflowId;
  int _retryAttempt = 0;
  bool _isConnected = false;

  /// The room the server acknowledged, until left or disconnected.
  String? get joinedWorkflowId => _joinedWorkflowId;

  /// The room the app wants.
  String? get desiredWorkflowId => _desiredWorkflowId;

  /// The room whose join is awaiting an ack.
  String? get pendingJoinWorkflowId => _pendingJoinWorkflowId;

  /// A room denied non-retryably until the app targets another one.
  String? get blockedWorkflowId => _blockedWorkflowId;

  /// Whether the socket is connected.
  bool get isConnected => _isConnected;

  /// Records the socket state. A disconnect forgets pending and joined
  /// rooms; a connect flushes the desired room.
  List<JoinCommand> setConnected({required bool connected}) {
    _isConnected = connected;
    if (!connected) {
      _pendingJoinWorkflowId = null;
      _joinedWorkflowId = null;
      return _clearRetryCommands();
    }
    return _flush();
  }

  /// Sets the room the app wants (`null` to leave).
  List<JoinCommand> requestWorkflow(String? workflowId) {
    final commands = _takeRetryResetCommands(workflowId, explicit: true);
    _desiredWorkflowId = workflowId;
    if (workflowId != _blockedWorkflowId) {
      _blockedWorkflowId = null;
    }
    return [...commands, ..._flush()];
  }

  /// Re-joins [workflowId] even though it is already joined (session error).
  List<JoinCommand> forceRejoinWorkflow(String? workflowId) {
    final commands = requestWorkflow(workflowId);
    final alreadyChangingRooms = commands.any(
      (command) => command is JoinRoomCommand || command is LeaveRoomCommand,
    );
    if (alreadyChangingRooms ||
        !_isConnected ||
        _desiredWorkflowId == null ||
        _pendingJoinWorkflowId == _desiredWorkflowId ||
        _blockedWorkflowId == _desiredWorkflowId) {
      return commands;
    }
    _joinedWorkflowId = null;
    return [...commands, ..._flush()];
  }

  /// Handles `workflow-deleted`.
  JoinEvictResult handleWorkflowDeleted(String workflowId) =>
      _evictFromWorkflow(workflowId);

  /// Handles `access-revoked`: same control flow as a deletion.
  JoinEvictResult handleAccessRevoked(String workflowId) =>
      _evictFromWorkflow(workflowId);

  JoinEvictResult _evictFromWorkflow(String workflowId) {
    final commands = _takeRetryResetCommands(
      _retryWorkflowId == workflowId ? null : _retryWorkflowId,
      explicit: true,
    );
    if (_desiredWorkflowId == workflowId) {
      _blockedWorkflowId = workflowId;
    }
    if (_pendingJoinWorkflowId == workflowId) {
      _pendingJoinWorkflowId = null;
    }
    final shouldClearCurrent = _joinedWorkflowId == workflowId;
    if (shouldClearCurrent) {
      _joinedWorkflowId = null;
    }
    return JoinEvictResult(
      commands: [...commands, ..._flush()],
      shouldClearCurrent: shouldClearCurrent,
    );
  }

  /// Handles `join-workflow-success`.
  JoinSuccessResult handleJoinSuccess(String workflowId) {
    final commands = _clearRetryCommands(workflowId);
    _pendingJoinWorkflowId = null;
    _joinedWorkflowId = workflowId;
    final apply =
        _desiredWorkflowId == workflowId && _blockedWorkflowId != workflowId;
    return JoinSuccessResult(
      apply: apply,
      commands: [...commands, ..._flush()],
      workflowId: workflowId,
    );
  }

  /// Handles `join-workflow-error`.
  JoinErrorResult handleJoinError({
    required String? workflowId,
    required bool retryable,
  }) {
    final resolvedWorkflowId = workflowId ?? _pendingJoinWorkflowId;

    if (resolvedWorkflowId != null &&
        _pendingJoinWorkflowId == resolvedWorkflowId) {
      _pendingJoinWorkflowId = null;
      if (_joinedWorkflowId == resolvedWorkflowId) {
        _joinedWorkflowId = null;
      }
    }

    final isCurrentDesired =
        resolvedWorkflowId != null &&
        _desiredWorkflowId == resolvedWorkflowId &&
        _blockedWorkflowId != resolvedWorkflowId;

    final baseCommands = resolvedWorkflowId != null
        ? _takeRetryResetCommands(resolvedWorkflowId, explicit: true)
        : _clearRetryCommands();

    if (!isCurrentDesired) {
      return JoinErrorResult(
        apply: false,
        commands: [...baseCommands, ..._flush()],
        ignored: true,
        retryScheduled: false,
        workflowId: resolvedWorkflowId,
      );
    }

    if (retryable) {
      return JoinErrorResult(
        apply: false,
        commands: [...baseCommands, ..._scheduleRetry(resolvedWorkflowId)],
        ignored: false,
        retryScheduled: true,
        workflowId: resolvedWorkflowId,
      );
    }

    final leaveCommands = _blockWorkflow(resolvedWorkflowId);
    return JoinErrorResult(
      apply: true,
      commands: [..._clearRetryCommands(), ...leaveCommands, ..._flush()],
      ignored: false,
      retryScheduled: false,
      workflowId: resolvedWorkflowId,
    );
  }

  /// Fires a scheduled retry.
  List<JoinCommand> retryJoin(String workflowId) {
    if (_retryWorkflowId != workflowId ||
        _desiredWorkflowId != workflowId ||
        _blockedWorkflowId == workflowId) {
      return const [];
    }
    return _flush();
  }

  List<JoinCommand> _flush() {
    if (!_isConnected || _pendingJoinWorkflowId != null) return const [];

    final desired = _desiredWorkflowId;
    if (desired == null) {
      if (_joinedWorkflowId == null) return const [];
      _joinedWorkflowId = null;
      return const [LeaveRoomCommand()];
    }
    if (_blockedWorkflowId == desired) return const [];
    if (_joinedWorkflowId == desired) return const [];

    _pendingJoinWorkflowId = desired;
    return [JoinRoomCommand(desired)];
  }

  List<JoinCommand> _scheduleRetry(String workflowId) {
    final nextAttempt = _retryWorkflowId == workflowId ? _retryAttempt + 1 : 1;
    final delayMs = math.min(
      socketJoinRetryBaseDelay.inMilliseconds *
          math.pow(2, math.max(0, nextAttempt - 1)).toInt(),
      socketJoinRetryMaxDelay.inMilliseconds,
    );
    _retryWorkflowId = workflowId;
    _retryAttempt = nextAttempt;
    return [
      ScheduleRetryCommand(
        workflowId: workflowId,
        attempt: nextAttempt,
        delay: Duration(milliseconds: delayMs),
      ),
    ];
  }

  /// Clears the retry when the next desired workflow differs from the one
  /// being retried. `explicit` distinguishes "next is null" from the
  /// upstream `undefined` argument, which always clears.
  List<JoinCommand> _takeRetryResetCommands(
    String? nextWorkflowId, {
    required bool explicit,
  }) {
    final shouldClearRetry =
        _retryWorkflowId != null &&
        (!explicit || _retryWorkflowId != nextWorkflowId);
    if (!shouldClearRetry) return const [];
    _retryWorkflowId = null;
    _retryAttempt = 0;
    return const [CancelRetryCommand()];
  }

  List<JoinCommand> _clearRetryCommands([String? workflowId]) {
    final shouldClear =
        _retryWorkflowId != null &&
        (workflowId == null || _retryWorkflowId == workflowId);
    if (!shouldClear) return const [];
    _retryWorkflowId = null;
    _retryAttempt = 0;
    return const [CancelRetryCommand()];
  }

  List<JoinCommand> _blockWorkflow(String? workflowId) {
    if (workflowId != null) {
      _blockedWorkflowId = workflowId;
    }
    if (_joinedWorkflowId == null) return const [];
    _joinedWorkflowId = null;
    return const [LeaveRoomCommand()];
  }
}
