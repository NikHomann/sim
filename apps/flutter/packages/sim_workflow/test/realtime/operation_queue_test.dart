// Failure modes of OperationQueue (stores/operation-queue/store.ts port):
// 1. Ordering: operations are emitted out of queue order.
// 2. Single in-flight: a second operation is emitted before the first is
//    confirmed.
// 3. Structural timeout: no retry at 4999 ms, a retry at 5000 ms with
//    exponential backoff (2 s, 4 s, 8 s).
// 4. Subblock/variable timeout: no retry at 14999 ms, a retry at 15000 ms with
//    linear backoff capped at 3 s (1, 2, 3, 3, 3 s).
// 5. Retry exhaustion: a 4th structural failure (6th subblock) must drop the
//    queue and enter offline mode, not retry forever.
// 6. Superseding: a newer pending write to the same subblock field or variable
//    field replaces the older pending one, but never an in-flight one, and a
//    value-only write never replaces one carrying canonical modes.
// 7. Duplicate drop: a queued id, a non-block payload with identical JSON, or
//    a block operation of the same name for the same block id is dropped;
//    replace-state is never dropped.
// 8. Offline transition and recovery: a non-retryable failure clears every
//    operation and timer and raises hasOperationError; clearError lets new
//    operations flow again; a failure whose block no longer exists is dropped
//    instead of tripping offline mode.
// 9. Confirmation for an unknown or superseded id must not throw or remove
//    other operations; failing an unknown id is a no-op.
// 10. Remote-apply guard: execute() while a remote change is applied queues
//     nothing and runs no local action.
// 11. Emit refused (room not joinable): the operation stays pending without a
//     timeout and is flushed when a room is registered (reconnect).
// 12. cancelOperationsForWorkflow/Block/Variable must drop timers so a
//     cancelled operation never retries.
// 13. waitForWorkflowOperations resolves drained/failed/cancelled correctly
//     and never hangs past its timeout.
// 14. Version counters: every addToQueue (even a dropped duplicate) bumps the
//     workflow version; markRemoteApplied bumps the remote version.

import 'package:sim_workflow/sim_workflow_realtime.dart';
import 'package:test/test.dart';

class EmitLog {
  final List<(String workflowId, WorkflowOperation op, String id)> workflow =
      [];
  final List<
    (
      String workflowId,
      String blockId,
      String subblockId,
      Object? value,
      String id,
    )
  >
  subblock = [];
  final List<
    (
      String workflowId,
      String variableId,
      String field,
      Object? value,
      String id,
    )
  >
  variable = [];
  bool accept = true;

  int get total => workflow.length + subblock.length + variable.length;

  List<String> get ids => [
    for (final e in workflow) e.$3,
    for (final e in subblock) e.$5,
    for (final e in variable) e.$5,
  ];

  void register(OperationQueue queue, String? workflowId) {
    queue.registerEmitters(
      workflowEmit: (wf, op, id) {
        if (!accept) return false;
        workflow.add((wf, op, id));
        return true;
      },
      subblockEmit: (wf, blockId, subblockId, value, id) {
        if (!accept) return false;
        subblock.add((wf, blockId, subblockId, value, id));
        return true;
      },
      variableEmit: (wf, variableId, field, value, id) {
        if (!accept) return false;
        variable.add((wf, variableId, field, value, id));
        return true;
      },
      workflowId: workflowId,
    );
  }
}

void main() {
  late FakeClock clock;
  late OperationQueue queue;
  late EmitLog log;

  setUp(() {
    clock = FakeClock();
    queue = OperationQueue(clock: clock);
    log = EmitLog()..register(queue, 'wf');
  });

  void add(String id, WorkflowOperation op, {String workflowId = 'wf'}) {
    queue.addToQueue(
      id: id,
      operation: op,
      workflowId: workflowId,
      userId: 'u',
    );
  }

  WorkflowOperation rename(String block, String name) =>
      UpdateNameOperation(id: block, name: name);

  WorkflowOperation subblock(String block, String field, Object? value) =>
      SubblockUpdateOperation(blockId: block, subblockId: field, value: value);

  group('ordering and single in-flight', () {
    test('emits in queue order, one at a time, driven by confirmations', () {
      add('a', rename('b1', 'A'));
      add('b', rename('b2', 'B'));
      add('c', BatchRemoveBlocksOperation(ids: const ['b3']));

      expect(log.ids, ['a']);
      expect(queue.isProcessing, isTrue);
      expect(
        queue.operations.map((o) => o.status),
        [
          OperationStatus.processing,
          OperationStatus.pending,
          OperationStatus.pending,
        ],
      );

      queue.confirmOperation('a');
      expect(log.ids, ['a', 'b']);
      queue.confirmOperation('b');
      expect(log.ids, ['a', 'b', 'c']);
      queue.confirmOperation('c');
      expect(queue.operations, isEmpty);
      expect(queue.isProcessing, isFalse);
    });

    test('routes subblock and variable writes to their own emitters', () {
      add('s', subblock('b1', 'prompt', 'hi'));
      queue.confirmOperation('s');
      add(
        'v',
        VariableUpdateOperation(variableId: 'v1', field: 'name', value: 'n'),
      );
      expect(log.subblock.single, ('wf', 'b1', 'prompt', 'hi', 's'));
      expect(log.variable.single, ('wf', 'v1', 'name', 'n', 'v'));
      expect(log.workflow, isEmpty);
    });
  });

  group('timeouts and retries', () {
    test('structural: 5 s timeout, exponential backoff, offline after 3', () {
      add('a', rename('b1', 'A'));
      clock.elapse(const Duration(milliseconds: 4999));
      expect(queue.operations.single.retryCount, 0);
      expect(queue.operations.single.status, OperationStatus.processing);

      clock.elapse(const Duration(milliseconds: 1));
      expect(queue.operations.single.retryCount, 1);
      expect(queue.operations.single.status, OperationStatus.pending);
      expect(queue.isProcessing, isFalse);
      expect(log.ids, ['a']);

      clock.elapse(const Duration(milliseconds: 1999));
      expect(log.ids, ['a']);
      clock.elapse(const Duration(milliseconds: 1));
      expect(log.ids, ['a', 'a']);

      clock.elapse(const Duration(seconds: 5));
      expect(queue.operations.single.retryCount, 2);
      clock.elapse(const Duration(seconds: 4));
      expect(log.ids.length, 3);

      clock.elapse(const Duration(seconds: 5));
      expect(queue.operations.single.retryCount, 3);
      clock.elapse(const Duration(seconds: 8));
      expect(log.ids.length, 4);

      clock.elapse(const Duration(seconds: 5));
      expect(queue.hasOperationError, isTrue);
      expect(queue.operations, isEmpty);
      expect(clock.pendingTimerCount, 0);
      clock.elapse(const Duration(minutes: 1));
      expect(log.ids.length, 4);
    });

    test(
      'subblock: 15 s timeout, linear backoff capped at 3 s, offline after 5',
      () {
        add('s', subblock('b1', 'prompt', 'v'));
        clock.elapse(const Duration(milliseconds: 14999));
        expect(queue.operations.single.retryCount, 0);
        clock.elapse(const Duration(milliseconds: 1));
        expect(queue.operations.single.retryCount, 1);

        final expectedDelays = [1000, 2000, 3000, 3000, 3000];
        for (var attempt = 1; attempt <= 5; attempt++) {
          final emitsBefore = log.subblock.length;
          clock.elapse(Duration(milliseconds: expectedDelays[attempt - 1] - 1));
          expect(
            log.subblock.length,
            emitsBefore,
            reason: 'attempt $attempt early',
          );
          clock.elapse(const Duration(milliseconds: 1));
          expect(
            log.subblock.length,
            emitsBefore + 1,
            reason: 'attempt $attempt',
          );
          clock.elapse(const Duration(seconds: 15));
        }
        expect(queue.hasOperationError, isTrue);
        expect(log.subblock.length, 6);
      },
    );

    test('variable field writes use the subblock budget', () {
      add(
        'v',
        VariableUpdateOperation(variableId: 'v1', field: 'value', value: 1),
      );
      queue.failOperation('v');
      clock.elapse(const Duration(milliseconds: 999));
      expect(log.variable.length, 1);
      clock.elapse(const Duration(milliseconds: 1));
      expect(log.variable.length, 2);
    });

    test('a confirmation cancels the pending timeout', () {
      add('a', rename('b1', 'A'));
      queue.confirmOperation('a');
      expect(clock.pendingTimerCount, 0);
      clock.elapse(const Duration(seconds: 10));
      expect(queue.hasOperationError, isFalse);
    });
  });

  group('superseding', () {
    test('a newer pending subblock write replaces the older one', () {
      add('x', rename('b9', 'hold'));
      add('s1', subblock('b1', 'prompt', 'v1'));
      add('s2', subblock('b1', 'prompt', 'v2'));
      add('s3', subblock('b1', 'other', 'o'));
      expect(queue.operations.map((o) => o.id), ['x', 's2', 's3']);
    });

    test('an in-flight subblock write is never superseded', () {
      add('s1', subblock('b1', 'prompt', 'v1'));
      add('s2', subblock('b1', 'prompt', 'v2'));
      expect(queue.operations.map((o) => o.id), ['s1', 's2']);
      queue.confirmOperation('s1');
      expect(log.subblock.map((e) => e.$5), ['s1', 's2']);
    });

    test(
      'value-only never supersedes canonical modes; modes supersede both',
      () {
        add('x', rename('b9', 'hold'));
        add(
          'm1',
          SubblockUpdateWithCanonicalModesOperation(
            blockId: 'b1',
            subblockId: 'tools',
            value: 1,
            canonicalModes: const {'tools.0': CanonicalMode.basic},
          ),
        );
        add('s1', subblock('b1', 'tools', 2));
        expect(queue.operations.map((o) => o.id), ['x', 'm1', 's1']);
        add(
          'm2',
          SubblockUpdateWithCanonicalModesOperation(
            blockId: 'b1',
            subblockId: 'tools',
            value: 3,
            canonicalModes: const {'tools.0': CanonicalMode.advanced},
          ),
        );
        expect(queue.operations.map((o) => o.id), ['x', 'm2']);
      },
    );

    test('a newer pending variable field write replaces the older one', () {
      add('x', rename('b9', 'hold'));
      add(
        'v1',
        VariableUpdateOperation(variableId: 'v', field: 'value', value: 1),
      );
      add(
        'v2',
        VariableUpdateOperation(variableId: 'v', field: 'value', value: 2),
      );
      add(
        'v3',
        VariableUpdateOperation(variableId: 'v', field: 'name', value: 'n'),
      );
      expect(queue.operations.map((o) => o.id), ['x', 'v2', 'v3']);
    });
  });

  group('duplicate drop', () {
    test('a queued id is not added twice', () {
      add('a', rename('b1', 'A'));
      add('a', rename('b2', 'Other'));
      expect(queue.operations.map((o) => o.id), ['a']);
    });

    test('identical non-block content is dropped', () {
      add('a', BatchRemoveBlocksOperation(ids: const ['b1']));
      add('b', BatchRemoveBlocksOperation(ids: const ['b1']));
      add('c', BatchRemoveBlocksOperation(ids: const ['b2']));
      expect(queue.operations.map((o) => o.id), ['a', 'c']);
    });

    test(
      'a block operation of the same name for the same block is dropped',
      () {
        add('a', rename('b1', 'A'));
        add('b', rename('b1', 'B'));
        add('c', UpdateAdvancedModeOperation(id: 'b1', advancedMode: true));
        expect(queue.operations.map((o) => o.id), ['a', 'c']);
      },
    );

    test('replace-state is never dropped as a duplicate', () {
      add(
        'a',
        ReplaceStateOperation(state: const {'blocks': <String, Object?>{}}),
      );
      add(
        'b',
        ReplaceStateOperation(state: const {'blocks': <String, Object?>{}}),
      );
      expect(queue.operations.map((o) => o.id), ['a', 'b']);
    });
  });

  group('offline mode', () {
    test('a non-retryable failure clears the queue and raises the error', () {
      add('a', rename('b1', 'A'));
      add('b', rename('b2', 'B'));
      queue.failOperation('a', retryable: false);
      expect(queue.hasOperationError, isTrue);
      expect(queue.operations, isEmpty);
      expect(queue.isProcessing, isFalse);
      expect(clock.pendingTimerCount, 0);
    });

    test('clearError lets new operations flow again', () {
      add('a', rename('b1', 'A'));
      queue
        ..failOperation('a', retryable: false)
        ..clearError();
      expect(queue.hasOperationError, isFalse);
      add('b', rename('b2', 'B'));
      expect(log.ids, ['a', 'b']);
    });

    test('a failure for a block that no longer exists is dropped silently', () {
      final gone = <String>{'b1'};
      queue = OperationQueue(
        clock: clock,
        isBlockPresent: (id) => !gone.contains(id),
      );
      log = EmitLog()..register(queue, 'wf');
      add('a', rename('b1', 'A'));
      add('b', rename('b2', 'B'));
      queue.failOperation('a', retryable: false);
      expect(queue.hasOperationError, isFalse);
      expect(queue.operations.map((o) => o.id), ['b']);
      expect(log.ids, ['a', 'b']);
    });

    test('a failure for a deleted variable is dropped after retries too', () {
      queue = OperationQueue(clock: clock, isVariablePresent: (_) => false);
      log = EmitLog()..register(queue, 'wf');
      add('v', RemoveVariableOperation(variableId: 'v1'));
      for (var i = 0; i < 3; i++) {
        queue.failOperation('v');
        clock.elapse(const Duration(seconds: 8));
      }
      queue.failOperation('v');
      expect(queue.hasOperationError, isFalse);
      expect(queue.operations, isEmpty);
    });

    test('structural failures without a single target always go offline', () {
      queue = OperationQueue(clock: clock, isBlockPresent: (_) => false);
      log = EmitLog()..register(queue, 'wf');
      add('a', BatchRemoveBlocksOperation(ids: const ['b1']));
      queue.failOperation('a', retryable: false);
      expect(queue.hasOperationError, isTrue);
    });
  });

  group('unknown and superseded ids', () {
    test('confirming an unknown id keeps the others', () {
      add('a', rename('b1', 'A'));
      add('b', rename('b2', 'B'));
      queue.confirmOperation('nope');
      expect(queue.operations.map((o) => o.id), ['a', 'b']);
    });

    test('confirming a superseded id keeps its replacement', () {
      add('x', rename('b9', 'hold'));
      add('s1', subblock('b1', 'prompt', 'v1'));
      add('s2', subblock('b1', 'prompt', 'v2'));
      queue.confirmOperation('s1');
      expect(queue.operations.map((o) => o.id), contains('s2'));
    });

    test('failing an unknown id is a no-op', () {
      add('a', rename('b1', 'A'));
      queue.failOperation('nope', retryable: false);
      expect(queue.hasOperationError, isFalse);
      expect(queue.operations.single.id, 'a');
    });
  });

  group('remote-apply guard', () {
    test('execute queues nothing while a remote change is applied', () {
      var localRan = false;
      queue.remoteApplyGuard.run(() {
        final queued = queue.execute(
          operationId: 'a',
          operation: rename('b1', 'A'),
          workflowId: 'wf',
          userId: 'u',
          localAction: () => localRan = true,
        );
        expect(queued, isFalse);
      });
      expect(localRan, isFalse);
      expect(queue.operations, isEmpty);
      expect(queue.remoteApplyGuard.isApplying, isFalse);
    });

    test('execute queues then runs the local action otherwise', () {
      final order = <String>[];
      queue
        ..changes.listen((_) => order.add('queued'))
        ..execute(
          operationId: 'a',
          operation: rename('b1', 'A'),
          workflowId: 'wf',
          userId: 'u',
          localAction: () => order.add('local'),
        );
      expect(order.first, 'queued');
      expect(order.last, 'local');
      expect(log.ids, ['a']);
    });

    test('the guard is lowered even when apply throws', () {
      expect(
        () => queue.remoteApplyGuard.run(() => throw StateError('boom')),
        throwsStateError,
      );
      expect(queue.remoteApplyGuard.isApplying, isFalse);
    });
  });

  group('room gating and flush on reconnect', () {
    test('an operation for an unregistered room stays pending', () {
      log.register(queue, null);
      add('a', rename('b1', 'A'));
      expect(log.total, 0);
      expect(queue.operations.single.status, OperationStatus.pending);
      expect(clock.pendingTimerCount, 0);
      log.register(queue, 'wf');
      expect(log.ids, ['a']);
    });

    test('a refused emit leaves the operation pending without a timeout', () {
      log.accept = false;
      add('a', rename('b1', 'A'));
      expect(queue.operations.single.status, OperationStatus.pending);
      expect(queue.isProcessing, isFalse);
      expect(clock.pendingTimerCount, 0);
      log.accept = true;
      queue.processNextOperation();
      expect(log.ids, ['a']);
    });

    test('operations of another room wait until that room is registered', () {
      add('other', rename('b1', 'A'), workflowId: 'wf2');
      expect(log.total, 0);
      log.register(queue, 'wf2');
      expect(log.workflow.single.$1, 'wf2');
    });
  });

  group('cancellation', () {
    test('cancelOperationsForWorkflow drops operations and timers', () {
      add('a', rename('b1', 'A'));
      add('b', rename('b2', 'B'));
      add('other', rename('b1', 'A'), workflowId: 'wf2');
      queue.cancelOperationsForWorkflow('wf');
      expect(queue.operations.map((o) => o.id), ['other']);
      expect(clock.pendingTimerCount, 0);
      expect(queue.isProcessing, isFalse);
    });

    test(
      'cancelOperationsForBlock drops every operation touching the block',
      () {
        add('a', rename('b1', 'A'));
        add('s', subblock('b1', 'prompt', 'v'));
        add(
          'p',
          BatchUpdatePositionsOperation(
            updates: const [PositionUpdate(id: 'b1', position: Position(0, 0))],
          ),
        );
        add('keep', rename('b2', 'B'));
        queue.cancelOperationsForBlock('b1');
        expect(queue.operations.map((o) => o.id), ['keep']);
        expect(log.ids, ['a', 'keep']);
      },
    );

    test('cancelOperationsForVariable drops the variable writes', () {
      add(
        'v',
        VariableUpdateOperation(variableId: 'v1', field: 'name', value: 'n'),
      );
      add('r', RemoveVariableOperation(variableId: 'v1'));
      add(
        'keep',
        VariableUpdateOperation(variableId: 'v2', field: 'name', value: 'n'),
      );
      queue.cancelOperationsForVariable('v1');
      expect(queue.operations.map((o) => o.id), ['keep']);
    });
  });

  group('waitForWorkflowOperations', () {
    test('drains on confirmation', () async {
      add('a', rename('b1', 'A'));
      final wait = queue.waitForWorkflowOperations('wf');
      queue.confirmOperation('a');
      expect(await wait, DrainResult.drained);
    });

    test('resolves drained at once when nothing is queued', () async {
      expect(await queue.waitForWorkflowOperations('wf'), DrainResult.drained);
    });

    test('fails on offline mode and on timeout', () async {
      add('a', rename('b1', 'A'));
      final offline = queue.waitForWorkflowOperations('wf');
      queue.failOperation('a', retryable: false);
      expect(await offline, DrainResult.failed);

      queue.clearError();
      add('b', rename('b1', 'A'));
      final timedOut = queue.waitForWorkflowOperations(
        'wf',
        timeout: const Duration(seconds: 1),
      );
      clock.elapse(const Duration(seconds: 1));
      expect(await timedOut, DrainResult.failed);
    });

    test('is cancelled by reset', () async {
      add('a', rename('b1', 'A'));
      final wait = queue.waitForWorkflowOperations('wf');
      queue.reset();
      expect(await wait, DrainResult.cancelled);
      expect(queue.registeredWorkflowId, isNull);
    });
  });

  group('version counters', () {
    test('local versions bump on every add, remote on markRemoteApplied', () {
      add('a', rename('b1', 'A'));
      add('a', rename('b1', 'A'));
      expect(queue.workflowOperationVersions['wf'], 2);
      queue.markRemoteApplied('wf');
      expect(queue.remoteApplyVersions['wf'], 1);
      expect(queue.remoteApplyVersions['other'], isNull);
    });
  });
}
