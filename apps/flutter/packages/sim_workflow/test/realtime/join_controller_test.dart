// Failure modes of JoinController (socket-join-controller.ts port):
// 1. A join is emitted while disconnected, or while another join is pending.
// 2. A late join-workflow-success for a room the app already left (or
//    switched away from) is applied instead of ignored.
// 3. A workflow switch A->B before A's ack: B must be joined once A's ack
//    arrives, and A's ack must not be applied.
// 4. A retryable join error does not schedule a retry with exponential
//    backoff (1, 2, 4, 8, 10, 10 s), or a non-retryable error does not block
//    the room and leave it.
// 5. A join error for a room no longer desired is not ignored.
// 6. Requesting a different workflow does not clear the block of the previous
//    one; requesting the blocked one again must stay blocked.
// 7. Deletion/revocation of the joined room does not clear it; of a pending
//    room does not drop the pending join.
// 8. Reconnect does not re-join the desired room.
// 9. forceRejoinWorkflow does not re-emit a join for an already joined room.

import 'package:sim_workflow/sim_workflow_realtime.dart';
import 'package:test/test.dart';

void main() {
  late JoinController controller;

  setUp(() => controller = JoinController());

  test('joins only once connected and only one at a time', () {
    expect(controller.requestWorkflow('a'), isEmpty);
    expect(controller.setConnected(connected: true), [
      const JoinRoomCommand('a'),
    ]);
    expect(controller.requestWorkflow('a'), isEmpty);
    expect(controller.pendingJoinWorkflowId, 'a');
  });

  test('a late success after leaving is ignored', () {
    controller
      ..setConnected(connected: true)
      ..requestWorkflow('a');
    expect(controller.requestWorkflow(null), isEmpty);
    final result = controller.handleJoinSuccess('a');
    expect(result.ignored, isTrue);
    expect(result.commands, [const LeaveRoomCommand()]);
    expect(controller.joinedWorkflowId, isNull);
  });

  test('a switch before the ack joins the new room after the stale ack', () {
    controller
      ..setConnected(connected: true)
      ..requestWorkflow('a');
    expect(controller.requestWorkflow('b'), isEmpty);
    final stale = controller.handleJoinSuccess('a');
    expect(stale.ignored, isTrue);
    expect(stale.commands, [const JoinRoomCommand('b')]);
    final fresh = controller.handleJoinSuccess('b');
    expect(fresh.apply, isTrue);
    expect(fresh.commands, isEmpty);
    expect(controller.joinedWorkflowId, 'b');
  });

  test('retryable errors back off exponentially up to 10 s', () {
    controller
      ..setConnected(connected: true)
      ..requestWorkflow('a');
    final delays = <int>[];
    for (var i = 0; i < 6; i++) {
      final result = controller.handleJoinError(
        workflowId: 'a',
        retryable: true,
      );
      expect(result.retryScheduled, isTrue);
      final retry = result.commands.whereType<ScheduleRetryCommand>().single;
      delays.add(retry.delay.inSeconds);
      expect(retry.attempt, i + 1);
      expect(controller.retryJoin('a'), [const JoinRoomCommand('a')]);
    }
    expect(delays, [1, 2, 4, 8, 10, 10]);
  });

  test('a non-retryable error blocks the room and leaves it', () {
    controller
      ..setConnected(connected: true)
      ..requestWorkflow('a')
      ..handleJoinSuccess('a');
    final result = controller.handleJoinError(
      workflowId: 'a',
      retryable: false,
    );
    expect(result.apply, isTrue);
    expect(result.commands, [const LeaveRoomCommand()]);
    expect(controller.blockedWorkflowId, 'a');
    expect(controller.requestWorkflow('a'), isEmpty);
    expect(controller.requestWorkflow('b'), [const JoinRoomCommand('b')]);
    expect(controller.blockedWorkflowId, isNull);
  });

  test('an error for a room no longer desired is ignored', () {
    controller
      ..setConnected(connected: true)
      ..requestWorkflow('a')
      ..requestWorkflow('b');
    final result = controller.handleJoinError(
      workflowId: 'a',
      retryable: false,
    );
    expect(result.ignored, isTrue);
    expect(result.commands, [const JoinRoomCommand('b')]);
    expect(controller.blockedWorkflowId, isNull);
  });

  test('an error without a workflow id resolves to the pending join', () {
    controller
      ..setConnected(connected: true)
      ..requestWorkflow('a');
    final result = controller.handleJoinError(
      workflowId: null,
      retryable: true,
    );
    expect(result.workflowId, 'a');
    expect(result.retryScheduled, isTrue);
  });

  test('deletion of the joined room clears it and blocks a re-join', () {
    controller
      ..setConnected(connected: true)
      ..requestWorkflow('a')
      ..handleJoinSuccess('a');
    final result = controller.handleWorkflowDeleted('a');
    expect(result.shouldClearCurrent, isTrue);
    expect(result.commands, isEmpty);
    expect(controller.joinedWorkflowId, isNull);
    expect(controller.blockedWorkflowId, 'a');
  });

  test('revocation of a pending room drops the pending join', () {
    controller
      ..setConnected(connected: true)
      ..requestWorkflow('a');
    final result = controller.handleAccessRevoked('a');
    expect(result.shouldClearCurrent, isFalse);
    expect(controller.pendingJoinWorkflowId, isNull);
    expect(controller.handleJoinSuccess('a').ignored, isTrue);
  });

  test('a pending retry is cancelled when the desired room changes', () {
    controller
      ..setConnected(connected: true)
      ..requestWorkflow('a')
      ..handleJoinError(workflowId: 'a', retryable: true);
    expect(controller.requestWorkflow('b'), [
      const CancelRetryCommand(),
      const JoinRoomCommand('b'),
    ]);
    expect(controller.retryJoin('a'), isEmpty);
  });

  test('reconnect re-joins the desired room', () {
    controller
      ..setConnected(connected: true)
      ..requestWorkflow('a')
      ..handleJoinSuccess('a');
    expect(controller.setConnected(connected: false), isEmpty);
    expect(controller.joinedWorkflowId, isNull);
    expect(controller.setConnected(connected: true), [
      const JoinRoomCommand('a'),
    ]);
  });

  test('forceRejoin re-joins a joined room exactly once', () {
    controller
      ..setConnected(connected: true)
      ..requestWorkflow('a')
      ..handleJoinSuccess('a');
    expect(controller.forceRejoinWorkflow('a'), [const JoinRoomCommand('a')]);
    expect(controller.forceRejoinWorkflow('a'), isEmpty);
    expect(controller.forceRejoinWorkflow(null), isEmpty);
    final stale = controller.handleJoinSuccess('a');
    expect(stale.ignored, isTrue);
    expect(stale.commands, [const LeaveRoomCommand()]);
  });
}
