// Failure modes of CollaborationSession (socket-provider.tsx port):
// 1. Join handshake: join-workflow is emitted without the tabSessionId, or the
//    join future does not complete on join-workflow-success, or the queue is
//    not registered for the joined room.
// 2. Late join success after leave: a join-workflow-success for a room the app
//    left is applied (presence set, room marked joined, queue registered).
// 3. Join generation: switching rooms before the ack applies the stale ack.
// 4. workflow-state before re-sync completes: a local edit made while the
//    HTTP re-sync is in flight is clobbered by the raw payload when the
//    re-sync then fails.
// 5. Re-sync failure applies the raw payload when nothing changed; a
//    successful re-sync never applies the raw payload; a workflow-state for an
//    inactive room triggers no re-sync.
// 6. Transport disconnect mid-operation: the in-flight operation is lost, or a
//    stale timeout trips offline mode, instead of being re-sent after the
//    automatic re-join (flush on reconnect).
// 7. Non-retryable join error: edits are not cancelled or the future hangs;
//    retryable error: no retry after the backoff.
// 8. Malformed server payloads: a bad operation-confirmed, join success,
//    workflow-operation or unknown event throws or reaches a handler.
// 9. Remote broadcasts: applied without the guard, applied for another room,
//    counted as remote state for a per-frame position update, or a local
//    execute inside the handler is queued.
// 10. Cursor emits are not throttled to 33 ms, or a null cursor is throttled.
// 11. Uncommitted position frames are emitted per frame instead of coalesced,
//     or a commit does not flush the pending frame.
// 12. Notices: deleted/revoked do not leave the room and block edits;
//     reverted/updated/deployed/room-access-revoked are not surfaced.
// 13. operation-forbidden SESSION_ERROR does not re-join the room.
// 14. Presence deltas for unknown sockets create users, or a presence-update
//     blanks a cursor it did not carry.

import 'dart:async';

import 'package:sim_workflow/sim_workflow_realtime.dart';
import 'package:test/test.dart';

void main() {
  late FakeClock clock;
  late FakeTransport transport;
  late CollaborationSession session;
  late List<String> resyncCalls;
  late Completer<bool> Function(String workflowId) resyncHandler;
  late List<(String, JsonMap)> rawApplied;

  JsonMap presence(String socketId, String name) => {
    'socketId': socketId,
    'userId': 'user-$socketId',
    'userName': name,
  };

  JsonMap workflowState(String id) => {
    'id': id,
    'state': {
      'blocks': <String, Object?>{},
      'edges': <Object?>[],
      'loops': <String, Object?>{},
      'parallels': <String, Object?>{},
      'lastSaved': 1,
    },
    'lastModified': 2,
  };

  void serverJoinSuccess(String workflowId, {List<JsonMap>? users}) {
    transport.receive('join-workflow-success', {
      'workflowId': workflowId,
      'socketId': 'socket-1',
      'presenceUsers': users ?? [presence('socket-1', 'Me')],
    });
  }

  setUp(() {
    clock = FakeClock(startMs: 0);
    transport = FakeTransport();
    resyncCalls = [];
    rawApplied = [];
    resyncHandler = (_) => Completer<bool>()..complete(true);
    session = CollaborationSession(
      transport: transport,
      clock: clock,
      tabSessionId: 'tab-1',
      resync: (workflowId) {
        resyncCalls.add(workflowId);
        return resyncHandler(workflowId).future;
      },
      applyRawState: (workflowId, state) {
        rawApplied.add((workflowId, state));
        return true;
      },
    );
  });

  tearDown(() async {
    await session.dispose();
    await transport.dispose();
  });

  Future<JoinOutcome> connectAndJoin(String workflowId) async {
    await transport.connect();
    final outcome = session.join(workflowId);
    serverJoinSuccess(workflowId);
    return outcome;
  }

  group('join handshake', () {
    test(
      'emits join-workflow with the tab id and completes on success',
      () async {
        await transport.connect();
        final outcome = session.join('wf');
        expect(transport.emitted.single.name, 'join-workflow');
        expect(transport.emitted.single.payload, {
          'workflowId': 'wf',
          'tabSessionId': 'tab-1',
        });
        expect(session.joinedWorkflowId, isNull);

        serverJoinSuccess(
          'wf',
          users: [presence('socket-1', 'Me'), presence('s2', 'Ada')],
        );
        expect(await outcome, JoinOutcome.joined);
        expect(session.joinedWorkflowId, 'wf');
        expect(session.isWorkflowVisible, isTrue);
        expect(session.presenceUsers.map((u) => u.userName), ['Me', 'Ada']);
        expect(session.queue.registeredWorkflowId, 'wf');
      },
    );

    test('a join before connect is sent once the transport connects', () async {
      final outcome = session.join('wf');
      expect(transport.emitted, isEmpty);
      await transport.connect();
      expect(transport.emittedNamed('join-workflow').length, 1);
      serverJoinSuccess('wf');
      expect(await outcome, JoinOutcome.joined);
    });
  });

  group('join generation guard', () {
    test('a late success after leave is ignored', () async {
      await transport.connect();
      final outcome = session.join('wf');
      session.leave();
      expect(await outcome, JoinOutcome.superseded);
      expect(transport.emittedNamed('leave-workflow'), isEmpty);

      serverJoinSuccess('wf');
      expect(session.joinedWorkflowId, isNull);
      expect(session.presenceUsers, isEmpty);
      expect(session.queue.registeredWorkflowId, isNull);
      expect(transport.emittedNamed('leave-workflow').length, 1);
    });

    test(
      'switching rooms before the ack ignores the stale ack and joins the new room',
      () async {
        await transport.connect();
        final first = session.join('a');
        final second = session.join('b');
        expect(await first, JoinOutcome.superseded);

        serverJoinSuccess('a');
        expect(session.joinedWorkflowId, isNull);
        expect(
          transport
              .emittedNamed('join-workflow')
              .map((e) => (e.payload! as JsonMap)['workflowId']),
          ['a', 'b'],
        );

        serverJoinSuccess('b');
        expect(await second, JoinOutcome.joined);
        expect(session.joinedWorkflowId, 'b');
      },
    );

    test('a workflow switch cancels the previous room operations', () async {
      await connectAndJoin('a');
      session.execute(
        UpdateNameOperation(id: 'b1', name: 'n'),
        userId: 'u',
      );
      expect(session.queue.operations.length, 1);
      final second = session.join('b');
      expect(session.queue.hasPendingOperations('a'), isFalse);
      serverJoinSuccess('b');
      expect(await second, JoinOutcome.joined);
    });
  });

  group('workflow-state and re-sync', () {
    test(
      'exposes the state then re-syncs; raw payload not applied on success',
      () async {
        await connectAndJoin('wf');
        final states = <WorkflowStateEvent>[];
        session.workflowStates.listen(states.add);
        transport.receive('workflow-state', workflowState('wf'));
        expect(states.single.id, 'wf');
        expect(resyncCalls, ['wf']);
        await pumpEventQueue();
        expect(rawApplied, isEmpty);
      },
    );

    test('a local edit during the re-sync blocks the raw fallback', () async {
      await connectAndJoin('wf');
      final pending = Completer<bool>();
      resyncHandler = (_) => pending;
      transport.receive('workflow-state', workflowState('wf'));
      expect(resyncCalls, ['wf']);

      session.execute(
        UpdateNameOperation(id: 'b1', name: 'n'),
        userId: 'u',
      );
      transport.receive('operation-confirmed', {
        'operationId':
            transport.emittedNamed('workflow-operation').single.payload!
                is JsonMap
            ? (transport.emittedNamed('workflow-operation').single.payload!
                  as JsonMap)['operationId']
            : '',
        'serverTimestamp': 1,
      });
      expect(session.queue.hasPendingOperations('wf'), isFalse);

      pending.completeError(StateError('fetch failed'));
      await pumpEventQueue();
      expect(rawApplied, isEmpty);
    });

    test('a remote edit during the re-sync blocks the raw fallback', () async {
      await connectAndJoin('wf');
      final pending = Completer<bool>();
      resyncHandler = (_) => pending;
      transport
        ..receive('workflow-state', workflowState('wf'))
        ..receive('subblock-update', {
          'workflowId': 'wf',
          'blockId': 'b1',
          'subblockId': 's',
          'value': 1,
          'timestamp': 1,
        });
      pending.completeError(StateError('fetch failed'));
      await pumpEventQueue();
      expect(rawApplied, isEmpty);
    });

    test('a failed re-sync with no changes applies the raw payload', () async {
      await connectAndJoin('wf');
      resyncHandler = (_) =>
          Completer<bool>()..completeError(StateError('down'));
      transport.receive('workflow-state', workflowState('wf'));
      await pumpEventQueue();
      expect(rawApplied.single.$1, 'wf');
      expect(rawApplied.single.$2['lastSaved'], 1);
    });

    test('a workflow-state for an inactive room is ignored', () async {
      await connectAndJoin('wf');
      transport.receive('workflow-state', workflowState('other'));
      expect(resyncCalls, isEmpty);
      session.leave();
      transport.receive('workflow-state', workflowState('wf'));
      expect(resyncCalls, isEmpty);
    });
  });

  group('transport disconnect mid-operation', () {
    test(
      'the in-flight operation is re-sent after the automatic re-join',
      () async {
        await connectAndJoin('wf');
        final id = session.execute(
          UpdateNameOperation(id: 'b1', name: 'n'),
          userId: 'u',
        );
        expect(transport.emittedNamed('workflow-operation').length, 1);

        transport.setState(ConnectionState.reconnecting);
        expect(session.joinedWorkflowId, isNull);
        expect(session.queue.operations.single.id, id);
        expect(session.queue.registeredWorkflowId, isNull);

        clock.elapse(const Duration(seconds: 5));
        expect(session.queue.operations.single.status, OperationStatus.pending);
        expect(session.queue.hasOperationError, isFalse);
        clock.elapse(const Duration(seconds: 2));
        expect(transport.emittedNamed('workflow-operation').length, 1);

        transport.setState(ConnectionState.connected);
        expect(transport.emittedNamed('join-workflow').length, 2);
        serverJoinSuccess('wf');
        expect(transport.emittedNamed('workflow-operation').length, 2);
        final resent =
            transport.emittedNamed('workflow-operation').last.payload!
                as JsonMap;
        expect(resent['operationId'], id);
        transport.receive('operation-confirmed', {
          'operationId': id,
          'serverTimestamp': 1,
        });
        expect(session.queue.operations, isEmpty);
      },
    );

    test('an operation queued while offline is sent after reconnect', () async {
      await connectAndJoin('wf');
      transport.setState(ConnectionState.reconnecting);
      session.execute(
        SubblockUpdateOperation(blockId: 'b', subblockId: 's', value: 1),
        userId: 'u',
      );
      expect(transport.emittedNamed('subblock-update'), isEmpty);
      transport.setState(ConnectionState.connected);
      serverJoinSuccess('wf');
      expect(transport.emittedNamed('subblock-update').length, 1);
    });
  });

  group('join errors', () {
    test('a non-retryable error blocks the room and cancels edits', () async {
      await transport.connect();
      final outcome = session.join('wf');
      session.execute(
        UpdateNameOperation(id: 'b1', name: 'n'),
        userId: 'u',
      );
      transport.receive('join-workflow-error', {
        'workflowId': 'wf',
        'error': 'Access denied to workflow',
        'code': 'ACCESS_DENIED',
        'retryable': false,
      });
      expect(await outcome, JoinOutcome.blocked);
      expect(session.blockedJoinWorkflowId, 'wf');
      expect(session.queue.operations, isEmpty);
      expect(session.join('wf'), completion(JoinOutcome.superseded));
      await session.dispose();
    });

    test('a retryable error re-joins after the backoff', () async {
      await transport.connect();
      final outcome = session.join('wf');
      transport.receive('join-workflow-error', {
        'workflowId': 'wf',
        'error': 'Realtime unavailable',
        'code': 'ROOM_MANAGER_UNAVAILABLE',
        'retryable': true,
      });
      expect(session.isRetryingWorkflowJoin, isTrue);
      expect(transport.emittedNamed('join-workflow').length, 1);
      clock.elapse(const Duration(milliseconds: 999));
      expect(transport.emittedNamed('join-workflow').length, 1);
      clock.elapse(const Duration(milliseconds: 1));
      expect(transport.emittedNamed('join-workflow').length, 2);
      serverJoinSuccess('wf');
      expect(await outcome, JoinOutcome.joined);
      expect(session.isRetryingWorkflowJoin, isFalse);
    });
  });

  group('malformed and unknown server payloads', () {
    test('are ignored without reaching handlers or throwing', () async {
      await connectAndJoin('wf');
      var handlerCalls = 0;
      session
        ..onWorkflowOperation = ((_) => handlerCalls++)
        ..execute(
          UpdateNameOperation(id: 'b1', name: 'n'),
          userId: 'u',
        );

      transport
        ..receive('operation-confirmed', <String, Object?>{})
        ..receive('operation-failed', {'operationId': 1})
        ..receive('join-workflow-success', 'garbage')
        ..receive('workflow-operation', {'operation': 'update-name'})
        ..receive('presence-update', {'not': 'a list'})
        ..receive('workspace-file-doc:sync', [1, 2, 3])
        ..receive('workflow-deleted', {'workflowId': 'wf'});

      expect(handlerCalls, 0);
      expect(session.queue.operations.length, 1);
      expect(session.joinedWorkflowId, 'wf');
      expect(session.presenceUsers.length, 1);
    });
  });

  group('remote broadcasts', () {
    test('are applied under the guard and counted as remote state', () async {
      await connectAndJoin('wf');
      var guardedInside = false;
      String? nestedExecute;
      session.onWorkflowOperation = (broadcast) {
        guardedInside = session.remoteApplyGuard.isApplying;
        nestedExecute = session.execute(
          UpdateNameOperation(id: 'echo', name: 'x'),
          userId: 'u',
        );
      };
      transport.receive('workflow-operation', {
        'operation': 'update-name',
        'target': 'block',
        'payload': {'id': 'b1', 'name': 'n'},
        'timestamp': 1,
        'senderId': 's2',
        'userId': 'u2',
        'userName': 'Bob',
        'metadata': {'workflowId': 'wf', 'operationId': 'srv'},
      });
      expect(guardedInside, isTrue);
      expect(nestedExecute, isNull);
      expect(session.queue.operations, isEmpty);
      expect(session.queue.remoteApplyVersions['wf'], 1);
      expect(session.remoteApplyGuard.isApplying, isFalse);
    });

    test('per-frame position updates are delivered but not counted', () async {
      await connectAndJoin('wf');
      var calls = 0;
      session.onWorkflowOperation = (_) => calls++;
      transport.receive('workflow-operation', {
        'operation': 'update-position',
        'target': 'block',
        'payload': {
          'id': 'b1',
          'position': {'x': 1, 'y': 2},
          'commit': false,
        },
        'timestamp': 1,
        'senderId': 's2',
        'userId': 'u2',
        'userName': 'Bob',
        'metadata': {
          'workflowId': 'wf',
          'operationId': 'srv',
          'isPositionUpdate': true,
        },
      });
      expect(calls, 1);
      expect(session.queue.remoteApplyVersions['wf'], isNull);
    });

    test('broadcasts for another room are ignored', () async {
      await connectAndJoin('wf');
      var calls = 0;
      session
        ..onSubblockUpdate = ((_) => calls++)
        ..onVariableUpdate = ((_) => calls++);
      transport
        ..receive('subblock-update', {
          'workflowId': 'other',
          'blockId': 'b',
          'subblockId': 's',
          'value': 1,
          'timestamp': 1,
        })
        ..receive('variable-update', {
          'workflowId': 'other',
          'variableId': 'v',
          'field': 'name',
          'value': 'n',
          'timestamp': 1,
        });
      expect(calls, 0);
      transport.receive('variable-update', {
        'workflowId': 'wf',
        'variableId': 'v',
        'field': 'colour',
        'value': 'n',
        'timestamp': 1,
      });
      expect(calls, 1);
      expect(session.queue.remoteApplyVersions['wf'], isNull);
    });

    test('a handler that throws lowers the guard', () async {
      await connectAndJoin('wf');
      session.onSubblockUpdate = (_) => throw StateError('boom');
      transport.receive('subblock-update', {
        'workflowId': 'wf',
        'blockId': 'b',
        'subblockId': 's',
        'value': 1,
        'timestamp': 1,
      });
      expect(session.remoteApplyGuard.isApplying, isFalse);
    });
  });

  group('cursor and selection', () {
    test('cursor emits are throttled to 33 ms, null always sent', () async {
      await connectAndJoin('wf');
      session.emitCursor(const CursorPosition(1, 1));
      clock.elapse(const Duration(milliseconds: 10));
      session.emitCursor(const CursorPosition(2, 2));
      clock.elapse(const Duration(milliseconds: 23));
      session.emitCursor(const CursorPosition(3, 3));
      clock.elapse(const Duration(milliseconds: 1));
      session.emitCursor(null);
      final cursors = transport
          .emittedNamed('cursor-update')
          .map((e) => e.payload);
      expect(cursors, [
        {
          'cursor': {'x': 1, 'y': 1},
        },
        {
          'cursor': {'x': 3, 'y': 3},
        },
        {'cursor': null},
      ]);
    });

    test('nothing is emitted while no room is visible', () async {
      await transport.connect();
      session
        ..emitCursor(const CursorPosition(1, 1))
        ..emitSelection(
          const PresenceSelection(SelectionType.block, id: 'b'),
        );
      expect(transport.emittedNamed('cursor-update'), isEmpty);
      expect(transport.emittedNamed('selection-update'), isEmpty);
      await connectAndJoin('wf');
      session.emitSelection(
        const PresenceSelection(SelectionType.block, id: 'b'),
      );
      expect(transport.emittedNamed('selection-update').single.payload, {
        'selection': {'type': 'block', 'id': 'b'},
      });
    });
  });

  group('position coalescing', () {
    test(
      'uncommitted frames coalesce on the 33 ms timer; commit flushes',
      () async {
        await connectAndJoin('wf');
        session.queue.addToQueue(
          id: 'f1',
          operation: UpdatePositionOperation(
            id: 'b1',
            position: const Position(1, 1),
            commit: false,
          ),
          workflowId: 'wf',
          userId: 'u',
        );
        expect(transport.emittedNamed('workflow-operation'), isEmpty);
        clock.elapse(const Duration(milliseconds: 32));
        expect(transport.emittedNamed('workflow-operation'), isEmpty);
        clock.elapse(const Duration(milliseconds: 1));
        final frame =
            transport.emittedNamed('workflow-operation').single.payload!
                as JsonMap;
        expect((frame['payload']! as JsonMap)['position'], {'x': 1, 'y': 1});

        transport.receive('operation-confirmed', {
          'operationId': 'f1',
          'serverTimestamp': 1,
        });
        final coalescer = PositionUpdateCoalescer(
          clock: clock,
          send: (event) => transport.send(event),
        );
        WorkflowOperationEvent frameEvent(num x, {bool? commit}) =>
            WorkflowOperationEvent(
              workflowId: 'wf',
              operation: UpdatePositionOperation(
                id: 'b2',
                position: Position(x, 0),
                commit: commit,
              ),
              timestamp: clock.nowMs,
            );
        coalescer
          ..emit(frameEvent(1, commit: false))
          ..emit(frameEvent(2, commit: false));
        clock.elapse(const Duration(milliseconds: 33));
        coalescer
          ..emit(frameEvent(3, commit: false))
          ..emit(frameEvent(4, commit: true));
        clock.elapse(const Duration(seconds: 1));
        final xs = transport
            .emittedNamed('workflow-operation')
            .skip(1)
            .map(
              (e) =>
                  (((e.payload! as JsonMap)['payload']! as JsonMap)['position']!
                      as JsonMap)['x'],
            );
        expect(xs, [2, 4]);
        expect(coalescer.pendingBlockIds, isEmpty);
      },
    );
  });

  group('notices', () {
    test(
      'deleted leaves the room, blocks edits and surfaces a notice',
      () async {
        await connectAndJoin('wf');
        final notices = <CollaborationNotice>[];
        session
          ..notices.listen(notices.add)
          ..execute(
            UpdateNameOperation(id: 'b1', name: 'n'),
            userId: 'u',
          );
        transport.receive('workflow-deleted', {
          'workflowId': 'wf',
          'message': 'gone',
          'timestamp': 1,
        });
        expect(notices.single, isA<WorkflowDeletedNotice>());
        expect(session.joinedWorkflowId, isNull);
        expect(session.blockedJoinWorkflowId, 'wf');
        expect(session.queue.operations, isEmpty);
        expect(session.presenceUsers, isEmpty);
        expect(transport.emittedNamed('join-workflow').length, 1);
      },
    );

    test('access-revoked leaves the room and blocks it', () async {
      await connectAndJoin('wf');
      final notices = <CollaborationNotice>[];
      session.notices.listen(notices.add);
      transport.receive('access-revoked', {
        'workflowId': 'wf',
        'message': 'no',
        'timestamp': 1,
      });
      expect(notices.single, isA<AccessRevokedNotice>());
      expect(session.joinedWorkflowId, isNull);
      expect(session.blockedJoinWorkflowId, 'wf');
    });

    test(
      'reverted, updated, deployed and room revocations are surfaced',
      () async {
        await connectAndJoin('wf');
        final notices = <CollaborationNotice>[];
        session.notices.listen(notices.add);
        transport
          ..receive('workflow-reverted', {
            'workflowId': 'wf',
            'message': 'r',
            'timestamp': 1,
          })
          ..receive('workflow-updated', {
            'workflowId': 'wf',
            'message': 'u',
            'timestamp': 1,
          })
          ..receive('workflow-deployed', {
            'workflowId': 'wf',
            'timestamp': 1,
          })
          ..receive('room-access-revoked', {
            'room': {'type': 'table', 'id': 't'},
            'message': 'm',
            'timestamp': 1,
          });
        expect(notices.map((n) => n.runtimeType), [
          WorkflowRevertedNotice,
          WorkflowUpdatedNotice,
          WorkflowDeployedNotice,
          RoomAccessRevokedNotice,
        ]);
        expect(session.joinedWorkflowId, 'wf');
      },
    );

    test('a SESSION_ERROR re-joins the room', () async {
      await connectAndJoin('wf');
      OperationForbiddenEvent? seen;
      session.onOperationForbidden = (event) => seen = event;
      transport.receive('operation-forbidden', {
        'type': 'SESSION_ERROR',
        'message': 'Session expired, please rejoin workflow',
      });
      expect(seen?.type, 'SESSION_ERROR');
      expect(transport.emittedNamed('join-workflow').length, 2);
      transport.receive('operation-forbidden', {
        'type': 'INSUFFICIENT_PERMISSIONS',
        'message': 'nope',
      });
      expect(transport.emittedNamed('join-workflow').length, 2);
    });
  });

  group('presence deltas', () {
    test('update known sockets only and merge rosters', () async {
      await connectAndJoin('wf');
      transport
        ..receive('presence-update', [
          presence('socket-1', 'Me'),
          presence('s2', 'Ada'),
        ])
        ..receive('cursor-update', {
          'socketId': 's2',
          'userId': 'user-s2',
          'userName': 'Ada',
          'cursor': {'x': 5, 'y': 6},
        })
        ..receive('cursor-update', {
          'socketId': 'ghost',
          'userId': 'g',
          'userName': 'Ghost',
          'cursor': null,
        })
        ..receive('selection-update', {
          'socketId': 's2',
          'userId': 'user-s2',
          'userName': 'Ada',
          'selection': {'type': 'edge', 'id': 'e1'},
        });
      expect(session.presenceUsers.length, 2);
      final ada = session.presenceUsers.firstWhere((u) => u.socketId == 's2');
      expect(ada.cursor, const CursorPosition(5, 6));
      expect(ada.selection?.id, 'e1');

      transport.receive('presence-update', [
        presence('socket-1', 'Me'),
        presence('s2', 'Ada'),
      ]);
      final merged = session.presenceUsers.firstWhere(
        (u) => u.socketId == 's2',
      );
      expect(merged.cursor, const CursorPosition(5, 6));
      expect(merged.selection?.id, 'e1');
    });
  });
}
