// Failure modes of WorkspaceWorkflowsRoom (spec §4.6, §10 #65-66), with
// fake timers:
// 1. join is emitted on start when connected, and again on every reconnect;
// 2. a retryable join error retries with 1 s · n up to three times and no
//    fourth time; a non-retryable one never retries;
// 3. `workspace-workflows-changed` for another workspace is ignored, for
//    this one it invalidates through the callback;
// 4. dispose emits leave and stops reacting.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';

import 'support/mocks.dart';

void main() {
  late MockRealtimeTransport transport;
  late StreamController<RealtimeEvent> events;
  late StreamController<RealtimeConnectionState> states;
  late List<(String, String?)> emitted;

  setUp(() {
    transport = MockRealtimeTransport();
    events = StreamController<RealtimeEvent>.broadcast(sync: true);
    states = StreamController<RealtimeConnectionState>.broadcast(sync: true);
    emitted = [];
    when(() => transport.events).thenAnswer((_) => events.stream);
    when(() => transport.states).thenAnswer((_) => states.stream);
    when(() => transport.state).thenReturn(RealtimeConnectionState.connected);
    when(() => transport.emit(any(), any())).thenAnswer((invocation) {
      final payload = invocation.positionalArguments[1];
      emitted.add((
        invocation.positionalArguments[0] as String,
        payload is Map ? payload['workspaceId'] as String? : null,
      ));
    });
  });

  RealtimeEvent joinError({required bool retryable}) => RealtimeEvent(
    WorkspaceWorkflowsRoom.joinErrorEvent,
    {
      'workspaceId': workspaceId,
      'error': 'busy',
      'code': 'E',
      'retryable': retryable,
    },
  );

  test('join, reconnect, retry policy, changed filter, leave', () {
    fakeAsync((async) {
      final changed = <String>[];
      final room = WorkspaceWorkflowsRoom(
        transport: transport,
        workspaceId: workspaceId,
        onChanged: changed.add,
      )..start();
      expect(emitted, [(WorkspaceWorkflowsRoom.joinEvent, workspaceId)]);

      events.add(joinError(retryable: true));
      async.elapse(const Duration(milliseconds: 999));
      expect(emitted.length, 1);
      async.elapse(const Duration(milliseconds: 1));
      expect(emitted.length, 2, reason: 'first retry after 1 s');
      events.add(joinError(retryable: true));
      async.elapse(const Duration(seconds: 2));
      expect(emitted.length, 3, reason: 'second retry after 2 s');
      events.add(joinError(retryable: true));
      async.elapse(const Duration(seconds: 3));
      expect(emitted.length, 4, reason: 'third retry after 3 s');
      events.add(joinError(retryable: true));
      async.elapse(const Duration(seconds: 10));
      expect(emitted.length, 4, reason: 'no fourth retry');
      expect(room.retries, 3);

      events.add(
        const RealtimeEvent(WorkspaceWorkflowsRoom.joinSuccessEvent, {
          'workspaceId': workspaceId,
        }),
      );
      expect(room.isJoined, isTrue);
      events
        ..add(
          const RealtimeEvent(WorkspaceWorkflowsRoom.changedEvent, {
            'workspaceId': otherWorkspaceId,
          }),
        )
        ..add(
          const RealtimeEvent(WorkspaceWorkflowsRoom.changedEvent, {
            'workspaceId': workspaceId,
          }),
        );
      async.flushMicrotasks();
      expect(changed, [workspaceId]);

      states.add(RealtimeConnectionState.reconnecting);
      expect(room.isJoined, isFalse);
      states.add(RealtimeConnectionState.connected);
      expect(emitted.last, (WorkspaceWorkflowsRoom.joinEvent, workspaceId));
      events.add(joinError(retryable: false));
      final before = emitted.length;
      async.elapse(const Duration(seconds: 5));
      expect(emitted.length, before, reason: 'non-retryable: no retry');

      unawaited(room.dispose());
      async.flushMicrotasks();
      expect(emitted.last, (WorkspaceWorkflowsRoom.leaveEvent, workspaceId));
      events.add(joinError(retryable: true));
      async.elapse(const Duration(seconds: 5));
      expect(emitted.last, (WorkspaceWorkflowsRoom.leaveEvent, workspaceId));
      unawaited(events.close());
      unawaited(states.close());
    });
  });
}
