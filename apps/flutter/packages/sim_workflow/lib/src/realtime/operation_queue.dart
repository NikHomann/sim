/// The collaborative operation queue.
///
/// Port of `apps/sim/stores/operation-queue/store.ts` plus the
/// `executeQueuedOperation` entry point and `isApplyingRemoteChange` guard of
/// `hooks/use-collaborative-workflow.ts`. One operation is in flight at a
/// time; the server confirms it by `operationId`, a timeout or failure retries
/// it with backoff, and a non-retryable failure (or exhausted retries) drops
/// the queue and enters offline mode.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:sim_workflow/src/realtime/clock.dart';
import 'package:sim_workflow/src/realtime/json.dart';
import 'package:sim_workflow/src/realtime/logger.dart';
import 'package:sim_workflow/src/realtime/operations.dart';
import 'package:sim_workflow/src/realtime/remote_apply_guard.dart';

/// Where a queued operation is in its lifecycle.
enum OperationStatus {
  /// Waiting for its turn (or for the room to become joinable).
  pending,

  /// Emitted; awaiting `operation-confirmed` / `operation-failed`.
  processing,

  /// Reserved by upstream's type; operations leave the queue on confirm.
  confirmed,

  /// Reserved by upstream's type; failures retry or enter offline mode.
  failed,
}

/// Result of [OperationQueue.waitForWorkflowOperations].
enum DrainResult {
  /// Every operation of the workflow left the queue.
  drained,

  /// Offline mode was entered or the wait timed out.
  failed,

  /// The queue was reset while waiting.
  cancelled,
}

/// An operation in the queue.
class QueuedOperation {
  /// Creates a queue entry.
  const QueuedOperation({
    required this.id,
    required this.operation,
    required this.workflowId,
    required this.userId,
    required this.timestamp,
    required this.retryCount,
    required this.status,
  });

  /// The `operationId` the server echoes in its ack.
  final String id;

  /// What to emit.
  final WorkflowOperation operation;

  /// The room the operation belongs to.
  final String workflowId;

  /// The local user.
  final String userId;

  /// Epoch milliseconds when queued.
  final int timestamp;

  /// Failed attempts so far.
  final int retryCount;

  /// Lifecycle state.
  final OperationStatus status;

  /// Returns a copy with [retryCount] and [status] replaced.
  QueuedOperation copyWith({int? retryCount, OperationStatus? status}) =>
      QueuedOperation(
        id: id,
        operation: operation,
        workflowId: workflowId,
        userId: userId,
        timestamp: timestamp,
        retryCount: retryCount ?? this.retryCount,
        status: status ?? this.status,
      );

  /// Subblock and variable field writes get the longer timeout, more retries
  /// and the linear backoff; everything else is structural.
  bool get isSubblockOrVariable =>
      operation is SubblockUpdateOperation ||
      operation is VariableUpdateOperation;

  @override
  String toString() => 'QueuedOperation($id, $operation, $status)';
}

/// Emits a structural operation. Returns whether it was actually sent; a
/// `false` leaves the operation pending until the room is joinable.
typedef WorkflowOperationEmit =
    bool Function(
      String workflowId,
      WorkflowOperation operation,
      String operationId,
    );

/// Emits a `subblock-update`.
typedef SubblockUpdateEmit =
    bool Function(
      String workflowId,
      String blockId,
      String subblockId,
      Object? value,
      String operationId,
    );

/// Emits a `variable-update`.
typedef VariableUpdateEmit =
    bool Function(
      String workflowId,
      String variableId,
      String field,
      Object? value,
      String operationId,
    );

/// Whether an entity (block or variable) still exists in local state.
typedef EntityPresenceCheck = bool Function(String id);

/// Pending subblock operations a newer one for the same field makes
/// redundant. A value-only update never supersedes one that also carries
/// canonical modes, or those modes would be lost.
const Map<String, List<String>> supersededSubblockOperations = {
  SubblockOperations.update: [SubblockOperations.update],
  SubblockOperations.updateWithCanonicalModes: [
    SubblockOperations.update,
    SubblockOperations.updateWithCanonicalModes,
  ],
};

/// Targets whose payload id refers to a canvas block.
const List<String> _blockScopedTargets = [
  OperationTargets.block,
  OperationTargets.subblock,
  OperationTargets.subflow,
];

bool _alwaysPresent(String id) => true;

/// The queue.
class OperationQueue {
  /// Creates a queue on [clock]. [isBlockPresent] and [isVariablePresent]
  /// answer whether a failed operation's target still exists locally; they
  /// default to `true`, which is upstream's behaviour when the stores cannot
  /// be reached.
  OperationQueue({
    required Clock clock,
    RealtimeLogger logger = noopRealtimeLogger,
    EntityPresenceCheck isBlockPresent = _alwaysPresent,
    EntityPresenceCheck isVariablePresent = _alwaysPresent,
  }) : _clock = clock,
       _log = logger,
       _isBlockPresent = isBlockPresent,
       _isVariablePresent = isVariablePresent;

  /// Timeout for subblock/variable operations before they count as failed.
  static const Duration subblockVariableTimeout = Duration(seconds: 15);

  /// Timeout for structural operations before they count as failed.
  static const Duration structuralTimeout = Duration(seconds: 5);

  /// Maximum retry attempts for subblock/variable operations.
  static const int subblockVariableMaxRetries = 5;

  /// Maximum retry attempts for structural operations.
  static const int structuralMaxRetries = 3;

  /// Cap of the subblock/variable retry delay.
  static const Duration subblockVariableMaxRetryDelay = Duration(seconds: 3);

  /// Base retry delay: linear `base * n` (capped) for subblock/variable,
  /// exponential `2^n * base` for structural operations.
  static const Duration retryDelayBase = Duration(seconds: 1);

  /// Default wait of [waitForWorkflowOperations].
  static const Duration defaultDrainTimeout = Duration(seconds: 20);

  final Clock _clock;
  final RealtimeLogger _log;
  final EntityPresenceCheck _isBlockPresent;
  final EntityPresenceCheck _isVariablePresent;

  final List<QueuedOperation> _operations = [];
  final Map<String, int> _workflowOperationVersions = {};
  final Map<String, int> _remoteApplyVersions = {};
  final Map<String, Timer> _retryTimeouts = {};
  final Map<String, Timer> _operationTimeouts = {};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  bool _isProcessing = false;
  bool _hasOperationError = false;
  int _resetVersion = 0;

  WorkflowOperationEmit? _emitWorkflowOperation;
  SubblockUpdateEmit? _emitSubblockUpdate;
  VariableUpdateEmit? _emitVariableUpdate;
  String? _registeredWorkflowId;

  /// The `isApplyingRemoteChange` guard: [execute] is a no-op while raised.
  final RemoteApplyGuard remoteApplyGuard = RemoteApplyGuard();

  /// The queued operations, oldest first.
  List<QueuedOperation> get operations => List.unmodifiable(_operations);

  /// Whether an operation is in flight.
  bool get isProcessing => _isProcessing;

  /// Whether the queue entered offline mode.
  bool get hasOperationError => _hasOperationError;

  /// Per-workflow count of local operations ever queued (snapshot guard).
  Map<String, int> get workflowOperationVersions =>
      Map.unmodifiable(_workflowOperationVersions);

  /// Per-workflow count of remote operations applied (snapshot guard).
  Map<String, int> get remoteApplyVersions =>
      Map.unmodifiable(_remoteApplyVersions);

  /// The room operations may currently be emitted for.
  String? get registeredWorkflowId => _registeredWorkflowId;

  /// Fires synchronously after every state change.
  Stream<void> get changes => _changes.stream;

  /// Registers the emit functions and the joined room; a non-null
  /// [workflowId] kicks the queue (flush on reconnect / re-join).
  void registerEmitters({
    required WorkflowOperationEmit workflowEmit,
    required SubblockUpdateEmit subblockEmit,
    required VariableUpdateEmit variableEmit,
    required String? workflowId,
  }) {
    _emitWorkflowOperation = workflowEmit;
    _emitSubblockUpdate = subblockEmit;
    _emitVariableUpdate = variableEmit;
    _registeredWorkflowId = workflowId;
    if (workflowId != null) {
      processNextOperation();
    }
  }

  /// Records that a remote collaborator's operation was applied locally.
  void markRemoteApplied(String workflowId) {
    _remoteApplyVersions[workflowId] =
        (_remoteApplyVersions[workflowId] ?? 0) + 1;
    _notify();
  }

  /// `executeQueuedOperation`: queues [operation] under [operationId] and then
  /// runs [localAction]. Returns `false` without doing either while a remote
  /// change is being applied.
  bool execute({
    required String operationId,
    required WorkflowOperation operation,
    required String workflowId,
    required String userId,
    void Function()? localAction,
  }) {
    if (remoteApplyGuard.isApplying) return false;
    addToQueue(
      id: operationId,
      operation: operation,
      workflowId: workflowId,
      userId: userId,
    );
    localAction?.call();
    return true;
  }

  /// Adds an operation. Drops it when its id is already queued or when an
  /// operation with the same content exists; supersedes pending writes to the
  /// same subblock or variable field.
  void addToQueue({
    required String id,
    required WorkflowOperation operation,
    required String workflowId,
    required String userId,
  }) {
    _workflowOperationVersions[workflowId] =
        (_workflowOperationVersions[workflowId] ?? 0) + 1;

    var shouldDropPendingOperation = (QueuedOperation _) => false;

    final superseded = supersededSubblockOperations[operation.operation];
    if (superseded != null && operation.target == OperationTargets.subblock) {
      final blockId = operation.payload['blockId'];
      final subblockId = operation.payload['subblockId'];
      shouldDropPendingOperation = (op) =>
          op.status == OperationStatus.pending &&
          op.workflowId == workflowId &&
          superseded.contains(op.operation.operation) &&
          op.operation.target == OperationTargets.subblock &&
          op.operation.payload['blockId'] == blockId &&
          op.operation.payload['subblockId'] == subblockId;
    }

    if (operation.operation == VariableOperations.update &&
        operation.target == OperationTargets.variable) {
      final variableId = operation.payload['variableId'];
      final field = operation.payload['field'];
      shouldDropPendingOperation = (op) =>
          op.status == OperationStatus.pending &&
          op.workflowId == workflowId &&
          op.operation.operation == VariableOperations.update &&
          op.operation.target == OperationTargets.variable &&
          op.operation.payload['variableId'] == variableId &&
          op.operation.payload['field'] == field;
    }

    for (final existing in _operations) {
      if (existing.id == id) {
        _log(RealtimeLogLevel.debug, 'Skipping duplicate operation ID', {
          'operationId': id,
          'existingStatus': existing.status.name,
        });
        return;
      }
    }

    final isReplaceStateWorkflowOp =
        operation.target == OperationTargets.workflow &&
        operation.operation == WorkflowOperations.replaceState;

    for (final existing in _operations) {
      if (shouldDropPendingOperation(existing)) continue;
      if (existing.operation.operation != operation.operation ||
          existing.operation.target != operation.target ||
          existing.workflowId != workflowId) {
        continue;
      }
      final sameContent = operation.target == OperationTargets.block
          ? existing.operation.payload['id'] == operation.payload['id']
          : jsonContentEquals(existing.operation.payload, operation.payload);
      if (sameContent && !isReplaceStateWorkflowOp) {
        _log(RealtimeLogLevel.debug, 'Skipping duplicate operation content', {
          'operationId': id,
          'existingOperationId': existing.id,
          'operation': operation.operation,
          'target': operation.target,
        });
        return;
      }
    }

    final queued = QueuedOperation(
      id: id,
      operation: operation,
      workflowId: workflowId,
      userId: userId,
      timestamp: _clock.nowMs,
      retryCount: 0,
      status: OperationStatus.pending,
    );
    _log(RealtimeLogLevel.debug, 'Adding operation to queue', {
      'operationId': id,
      'operation': operation.operation,
    });

    _operations
      ..removeWhere(shouldDropPendingOperation)
      ..add(queued);
    _notify();
    processNextOperation();
  }

  /// Handles `operation-confirmed`: removes the operation (whatever its
  /// status; an unknown or superseded id is a no-op) and moves on.
  void confirmOperation(String operationId) {
    _operations.removeWhere((op) => op.id == operationId);
    _retryTimeouts.remove(operationId)?.cancel();
    _operationTimeouts.remove(operationId)?.cancel();
    _log(RealtimeLogLevel.debug, 'Removing operation from queue', {
      'operationId': operationId,
      'remainingOps': _operations.length,
    });
    _isProcessing = false;
    _notify();
    processNextOperation();
  }

  /// Handles `operation-failed` (and timeouts). A retryable failure schedules
  /// a retry with backoff until the budget is spent; a non-retryable one
  /// enters offline mode unless the target entity no longer exists locally.
  void failOperation(String operationId, {bool retryable = true}) {
    final operation = _find(operationId);
    if (operation == null) {
      _log(
        RealtimeLogLevel.warn,
        'Attempted to fail operation that does not exist in queue',
        {'operationId': operationId},
      );
      return;
    }

    _operationTimeouts.remove(operationId)?.cancel();

    if (!retryable) {
      if (_dropOperationForMissingTarget(operation)) return;
      _log(
        RealtimeLogLevel.error,
        'Operation failed with non-retryable error - state out of sync, '
        'triggering offline mode',
        {
          'operationId': operationId,
          'operation': operation.operation.operation,
          'target': operation.operation.target,
        },
      );
      triggerOfflineMode();
      return;
    }

    final isSubblockOrVariable = operation.isSubblockOrVariable;
    final maxRetries = isSubblockOrVariable
        ? subblockVariableMaxRetries
        : structuralMaxRetries;

    if (operation.retryCount < maxRetries) {
      final newRetryCount = operation.retryCount + 1;
      final delayMs = isSubblockOrVariable
          ? math.min(
              retryDelayBase.inMilliseconds * newRetryCount,
              subblockVariableMaxRetryDelay.inMilliseconds,
            )
          : math.pow(2, newRetryCount).toInt() * retryDelayBase.inMilliseconds;

      _log(
        RealtimeLogLevel.warn,
        'Operation failed, retrying in ${delayMs}ms '
        '(attempt $newRetryCount/$maxRetries)',
        {
          'operationId': operationId,
          'retryCount': newRetryCount,
          'operation': operation.operation.operation,
        },
      );

      _replace(
        operationId,
        operation.copyWith(
          retryCount: newRetryCount,
          status: OperationStatus.pending,
        ),
      );
      _isProcessing = false;
      _notify();

      _retryTimeouts[operationId] = _clock.schedule(
        Duration(milliseconds: delayMs),
        () {
          _retryTimeouts.remove(operationId);
          processNextOperation();
        },
      );
      return;
    }

    if (_dropOperationForMissingTarget(operation)) return;
    _log(
      RealtimeLogLevel.error,
      'Operation failed after max retries, triggering offline mode',
      {
        'operationId': operationId,
        'operation': operation.operation.operation,
        'retryCount': operation.retryCount,
      },
    );
    triggerOfflineMode();
  }

  /// A confirmation that never arrived is treated as a retryable failure.
  void handleOperationTimeout(String operationId) {
    if (_find(operationId) == null) {
      _log(
        RealtimeLogLevel.debug,
        'Ignoring timeout for operation not in queue',
        {
          'operationId': operationId,
        },
      );
      return;
    }
    _log(
      RealtimeLogLevel.warn,
      'Operation timeout detected - treating as failure to trigger retries',
      {'operationId': operationId},
    );
    failOperation(operationId);
  }

  /// Emits the next pending operation of the registered room, if none is in
  /// flight. An emit that was skipped (room not joinable) leaves the
  /// operation pending without a timeout.
  void processNextOperation() {
    if (_isProcessing) return;
    final registered = _registeredWorkflowId;
    if (registered == null) return;

    QueuedOperation? next;
    for (final op in _operations) {
      if (op.status == OperationStatus.pending && op.workflowId == registered) {
        next = op;
        break;
      }
    }
    if (next == null) return;

    _replace(next.id, next.copyWith(status: OperationStatus.processing));
    _isProcessing = true;
    _notify();

    _log(RealtimeLogLevel.debug, 'Processing operation sequentially', {
      'operationId': next.id,
      'operation': next.operation.operation,
      'retryCount': next.retryCount,
    });

    final operation = next.operation;
    var emitted = false;
    if (operation is SubblockUpdateOperation) {
      emitted =
          _emitSubblockUpdate?.call(
            next.workflowId,
            operation.blockId,
            operation.subblockId,
            operation.value,
            next.id,
          ) ??
          false;
    } else if (operation is VariableUpdateOperation) {
      emitted =
          _emitVariableUpdate?.call(
            next.workflowId,
            operation.variableId,
            operation.field,
            operation.value,
            next.id,
          ) ??
          false;
    } else {
      emitted =
          _emitWorkflowOperation?.call(next.workflowId, operation, next.id) ??
          false;
    }

    if (!emitted) {
      _log(
        RealtimeLogLevel.debug,
        'Emit skipped for operation - leaving it pending until the room is '
        'joinable',
        {
          'operationId': next.id,
          'operation': operation.operation,
          'workflowId': next.workflowId,
        },
      );
      _replace(next.id, next.copyWith(status: OperationStatus.pending));
      _isProcessing = false;
      _notify();
      return;
    }

    final timeout = next.isSubblockOrVariable
        ? subblockVariableTimeout
        : structuralTimeout;
    final operationId = next.id;
    _operationTimeouts[operationId] = _clock.schedule(timeout, () {
      _log(
        RealtimeLogLevel.warn,
        'Operation timeout - no server response after '
        '${timeout.inMilliseconds}ms',
        {'operationId': operationId, 'operation': operation.operation},
      );
      _operationTimeouts.remove(operationId);
      handleOperationTimeout(operationId);
    });
  }

  /// Whether any operation of [workflowId] is still queued.
  bool hasPendingOperations(String workflowId) =>
      _operations.any((op) => op.workflowId == workflowId);

  /// Completes when [workflowId] has no queued operations, the queue enters
  /// offline mode, [timeout] elapses or the queue is reset.
  Future<DrainResult> waitForWorkflowOperations(
    String workflowId, {
    Duration timeout = defaultDrainTimeout,
  }) {
    final waitResetVersion = _resetVersion;
    if (!hasPendingOperations(workflowId)) {
      return Future.value(DrainResult.drained);
    }

    final completer = Completer<DrainResult>();
    late final StreamSubscription<void> subscription;
    late final Timer timer;

    void settle(DrainResult result) {
      if (completer.isCompleted) return;
      timer.cancel();
      unawaited(subscription.cancel());
      completer.complete(result);
    }

    timer = _clock.schedule(timeout, () => settle(DrainResult.failed));
    subscription = _changes.stream.listen((_) {
      if (_resetVersion != waitResetVersion) {
        settle(DrainResult.cancelled);
      } else if (_hasOperationError) {
        settle(DrainResult.failed);
      } else if (!hasPendingOperations(workflowId)) {
        settle(DrainResult.drained);
      }
    });
    return completer.future;
  }

  /// Drops every operation that touches [blockId] (the block was deleted).
  void cancelOperationsForBlock(String blockId) {
    _log(RealtimeLogLevel.debug, 'Canceling all operations for block', {
      'blockId': blockId,
    });
    _cancelWhere((op) => _touchesBlock(op.operation, blockId));
    _log(RealtimeLogLevel.debug, 'Cancelled operations for block', {
      'blockId': blockId,
    });
  }

  /// Drops every operation that touches [variableId].
  void cancelOperationsForVariable(String variableId) {
    _log(RealtimeLogLevel.debug, 'Canceling all operations for variable', {
      'variableId': variableId,
    });
    _cancelWhere((op) {
      final operation = op.operation;
      if (operation.target != OperationTargets.variable) return false;
      return operation.payload['variableId'] == variableId ||
          operation.payload['sourceVariableId'] == variableId;
    });
  }

  /// Drops every operation of [workflowId] without processing the next one
  /// (room left, join denied, workflow switch).
  void cancelOperationsForWorkflow(String workflowId) {
    for (final op in _operations) {
      if (op.workflowId != workflowId) continue;
      _retryTimeouts.remove(op.id)?.cancel();
      _operationTimeouts.remove(op.id)?.cancel();
    }
    _operations.removeWhere((op) => op.workflowId == workflowId);
    _isProcessing = false;
    _notify();
  }

  /// Enters offline mode: every operation and timer is dropped and
  /// [hasOperationError] is raised until [clearError].
  void triggerOfflineMode() {
    _log(
      RealtimeLogLevel.error,
      'Operation failed after retries - triggering offline mode',
    );
    _clearTimers();
    _operations.clear();
    _isProcessing = false;
    _hasOperationError = true;
    _notify();
  }

  /// Leaves offline mode (the app re-synced from the server).
  void clearError() {
    _hasOperationError = false;
    _notify();
  }

  /// Forgets everything, including the registered emitters.
  void reset() {
    _clearTimers();
    _resetVersion += 1;
    _emitWorkflowOperation = null;
    _emitSubblockUpdate = null;
    _emitVariableUpdate = null;
    _registeredWorkflowId = null;
    _operations.clear();
    _workflowOperationVersions.clear();
    _remoteApplyVersions.clear();
    _isProcessing = false;
    _hasOperationError = false;
    _notify();
  }

  /// Releases timers and the change stream.
  Future<void> dispose() async {
    _clearTimers();
    await _changes.close();
  }

  bool _dropOperationForMissingTarget(QueuedOperation operation) {
    final target = operation.operation.target;
    final payload = operation.operation.payload;
    final isVariableOperation = target == OperationTargets.variable;
    if (!isVariableOperation && !_blockScopedTargets.contains(target)) {
      return false;
    }
    final targetId = isVariableOperation
        ? payload['variableId'] ?? payload['id']
        : payload['blockId'] ?? payload['id'];
    if (targetId is! String || targetId.isEmpty) return false;
    final stillPresent = isVariableOperation
        ? _isVariablePresent(targetId)
        : _isBlockPresent(targetId);
    if (stillPresent) return false;

    _log(
      RealtimeLogLevel.debug,
      isVariableOperation
          ? 'Dropping failed operation for deleted variable'
          : 'Dropping failed operation for deleted block',
      {'operationId': operation.id, 'targetId': targetId},
    );
    _operations.removeWhere((op) => op.id == operation.id);
    _isProcessing = false;
    _notify();
    processNextOperation();
    return true;
  }

  static bool _touchesBlock(WorkflowOperation operation, String blockId) {
    final payload = operation.payload;
    switch (operation.target) {
      case OperationTargets.block:
        return payload['id'] == blockId;
      case OperationTargets.subblock:
        return payload['blockId'] == blockId;
      case OperationTargets.blocks:
        switch (operation.operation) {
          case BlocksOperations.batchAddBlocks:
            final blocks = payload['blocks'];
            return blocks is List &&
                blocks.any((b) => b is Map && b['id'] == blockId);
          case BlocksOperations.batchRemoveBlocks:
            final ids = payload['ids'];
            return ids is List && ids.contains(blockId);
          case BlocksOperations.batchUpdatePositions:
            final updates = payload['updates'];
            return updates is List &&
                updates.any((u) => u is Map && u['id'] == blockId);
          default:
            return false;
        }
      default:
        return false;
    }
  }

  void _cancelWhere(bool Function(QueuedOperation op) predicate) {
    for (final op in _operations) {
      if (!predicate(op)) continue;
      _retryTimeouts.remove(op.id)?.cancel();
      _operationTimeouts.remove(op.id)?.cancel();
    }
    _operations.removeWhere(predicate);
    _isProcessing = false;
    _notify();
    processNextOperation();
  }

  QueuedOperation? _find(String operationId) {
    for (final op in _operations) {
      if (op.id == operationId) return op;
    }
    return null;
  }

  void _replace(String operationId, QueuedOperation replacement) {
    final index = _operations.indexWhere((op) => op.id == operationId);
    if (index != -1) _operations[index] = replacement;
  }

  void _clearTimers() {
    for (final timer in _retryTimeouts.values) {
      timer.cancel();
    }
    _retryTimeouts.clear();
    for (final timer in _operationTimeouts.values) {
      timer.cancel();
    }
    _operationTimeouts.clear();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
