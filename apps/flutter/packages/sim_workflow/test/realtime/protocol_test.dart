// Failure modes of the protocol vocabulary (events.dart, operations.dart,
// presence.dart, rooms.dart):
// 1. An operation that round-trips through toJson/fromJson changes a key name
//    or loses an extra key the editor attached (isUndo, originalOpId).
// 2. A known operation/target pair with a malformed payload (missing id, wrong
//    type, bad enum) is accepted instead of raising ProtocolFormatException.
// 3. An operation name or target outside the vocabulary throws instead of
//    decoding to UnknownWorkflowOperation.
// 4. A client event emits a payload whose keys differ from socket-provider.tsx
//    (leave-workflow must carry no payload).
// 5. A server event name outside the vocabulary (Yjs file-doc rooms on the
//    shared socket) throws instead of decoding to UnknownEvent.
// 6. A known server event with a malformed payload throws instead of decoding
//    to MalformedEvent (presence-update that is not an array, join success
//    that is a string, operation-confirmed missing its id).
// 7. The presence merge resurrects a cleared cursor (null) or blanks a cursor
//    the roster simply did not carry (absent).
// 8. Room names: a workflow room gets a prefix, a prefixed name parses to the
//    wrong type, an unknown prefix is not treated as a workflow id, a project
//    document identity with '/' or ':' is accepted.
// 9. allSocketOperations drifts from constants.ts (order or membership).
// 10. selection id is emitted as an explicit null instead of being omitted.

import 'dart:convert';

import 'package:sim_workflow/sim_workflow_realtime.dart';
import 'package:test/test.dart';

void expectRoundTrip(WorkflowOperation operation, Type type) {
  final json = operation.toJson();
  final decoded = WorkflowOperation.fromJson(
    jsonDecode(jsonEncode(json)) as JsonMap,
  );
  expect(decoded.runtimeType, type);
  expect(jsonEncode(decoded.toJson()), jsonEncode(json));
}

void main() {
  group('workflow-operation vocabulary', () {
    test('every typed operation round-trips byte-for-byte', () {
      const retry = BlockRetry(
        enabled: true,
        maxTries: 3,
        waitBetweenTriesMs: 500,
      );
      final cases = <(WorkflowOperation, Type)>[
        (
          UpdatePositionOperation(
            id: 'b1',
            position: const Position(1, 2),
            commit: false,
          ),
          UpdatePositionOperation,
        ),
        (
          UpdatePositionOperation(
            id: 'b1',
            position: const Position(1, 2),
            commit: true,
            extra: const {'isUndo': true, 'originalOpId': 'u1'},
          ),
          UpdatePositionOperation,
        ),
        (UpdateNameOperation(id: 'b1', name: 'Agent 2'), UpdateNameOperation),
        (
          ToggleEnabledOperation(id: 'b1', enabled: false),
          ToggleEnabledOperation,
        ),
        (
          UpdateParentOperation(
            id: 'b1',
            parentId: 'loop1',
            position: const Position(10, 20),
          ),
          UpdateParentOperation,
        ),
        (
          UpdateAdvancedModeOperation(id: 'b1', advancedMode: true),
          UpdateAdvancedModeOperation,
        ),
        (
          UpdateErrorEnabledOperation(id: 'b1', errorEnabled: true),
          UpdateErrorEnabledOperation,
        ),
        (UpdateRetryOperation(id: 'b1', retry: retry), UpdateRetryOperation),
        (
          UpdateCanonicalModeOperation(
            id: 'b1',
            canonicalId: 'model',
            canonicalMode: CanonicalMode.advanced,
          ),
          UpdateCanonicalModeOperation,
        ),
        (
          ReplaceCanonicalModesOperation(
            id: 'b1',
            canonicalModes: const {'tools.0': CanonicalMode.basic},
          ),
          ReplaceCanonicalModesOperation,
        ),
        (
          ToggleHandlesOperation(id: 'b1', horizontalHandles: true),
          ToggleHandlesOperation,
        ),
        (
          BatchUpdatePositionsOperation(
            updates: const [
              PositionUpdate(id: 'b1', position: Position(1, 1)),
              PositionUpdate(id: 'b2', position: Position(2.5, -3)),
            ],
          ),
          BatchUpdatePositionsOperation,
        ),
        (
          BatchAddBlocksOperation(
            blocks: const [
              {'id': 'b1', 'type': 'agent', 'name': 'Agent 1'},
            ],
            edges: const [
              EdgeData(id: 'e1', source: 'start', target: 'b1'),
            ],
            loops: const {},
            parallels: const {},
            subBlockValues: const {
              'b1': {'model': 'gpt-4o'},
            },
          ),
          BatchAddBlocksOperation,
        ),
        (
          BatchRemoveBlocksOperation(ids: const ['b1', 'b2']),
          BatchRemoveBlocksOperation,
        ),
        (
          BatchToggleEnabledOperation(
            blockIds: const ['b1'],
            previousStates: const {'b1': true},
          ),
          BatchToggleEnabledOperation,
        ),
        (
          BatchToggleHandlesOperation(
            blockIds: const ['b1'],
            previousStates: const {'b1': false},
          ),
          BatchToggleHandlesOperation,
        ),
        (
          BatchToggleLockedOperation(
            blockIds: const ['b1'],
            previousStates: const {'b1': false},
          ),
          BatchToggleLockedOperation,
        ),
        (
          BatchUpdateParentOperation(
            updates: const [
              ParentUpdate(
                id: 'b1',
                parentId: 'loop1',
                position: Position(0, 0),
              ),
            ],
          ),
          BatchUpdateParentOperation,
        ),
        (
          AddEdgeOperation(
            id: 'e1',
            source: 'b1',
            target: 'b2',
            sourceHandle: 'source',
          ),
          AddEdgeOperation,
        ),
        (RemoveEdgeOperation(id: 'e1'), RemoveEdgeOperation),
        (
          BatchAddEdgesOperation(
            edges: const [
              EdgeData(
                id: 'e1',
                source: 'b1',
                target: 'b2',
                targetHandle: 'target',
              ),
            ],
          ),
          BatchAddEdgesOperation,
        ),
        (
          BatchRemoveEdgesOperation(ids: const ['e1']),
          BatchRemoveEdgesOperation,
        ),
        (
          SubblockUpdateOperation(
            blockId: 'b1',
            subblockId: 'prompt',
            value: 'hello',
          ),
          SubblockUpdateOperation,
        ),
        (
          SubblockBatchUpdateOperation(
            updates: const [
              SubblockValueUpdate(
                blockId: 'b1',
                subblockId: 'prompt',
                value: 'v2',
                expectedValue: 'v1',
                hasExpectedValue: true,
              ),
              SubblockValueUpdate(
                blockId: 'b1',
                subblockId: 'model',
                value: null,
              ),
            ],
          ),
          SubblockBatchUpdateOperation,
        ),
        (
          SubblockUpdateWithCanonicalModesOperation(
            blockId: 'b1',
            subblockId: 'tools',
            value: const [1, 2],
            canonicalModes: const {'tools.0': CanonicalMode.advanced},
          ),
          SubblockUpdateWithCanonicalModesOperation,
        ),
        (
          SubflowUpdateOperation(
            id: 'loop1',
            type: 'loop',
            config: const {'iterations': 3},
          ),
          SubflowUpdateOperation,
        ),
        (
          AddVariableOperation(
            id: 'v1',
            name: 'count',
            type: 'number',
            value: 1,
            workflowId: 'wf',
          ),
          AddVariableOperation,
        ),
        (RemoveVariableOperation(variableId: 'v1'), RemoveVariableOperation),
        (
          VariableUpdateOperation(variableId: 'v1', field: 'value', value: 2),
          VariableUpdateOperation,
        ),
        (
          ReplaceStateOperation(state: const {'blocks': <String, Object?>{}}),
          ReplaceStateOperation,
        ),
      ];
      for (final (operation, type) in cases) {
        expectRoundTrip(operation, type);
      }
    });

    test('an extra payload key survives the round trip', () {
      final decoded = WorkflowOperation.fromJson({
        'operation': 'update-parent',
        'target': 'block',
        'payload': {
          'id': 'b1',
          'parentId': '',
          'extent': 'parent',
          'isUndo': true,
          'originalOpId': 'entry-1',
        },
      });
      expect(decoded, isA<UpdateParentOperation>());
      expect(decoded.payload['isUndo'], isTrue);
      expect(decoded.payload['originalOpId'], 'entry-1');
      expect((decoded as UpdateParentOperation).parentId, '');
    });

    test('a malformed payload raises ProtocolFormatException', () {
      JsonMap op(String operation, String target, JsonMap payload) => {
        'operation': operation,
        'target': target,
        'payload': payload,
      };
      final malformed = [
        op('update-name', 'block', {'name': 'x'}),
        op('update-position', 'block', {'id': 'b', 'position': 'nope'}),
        op('update-canonical-mode', 'block', {
          'id': 'b',
          'canonicalMode': 'weird',
        }),
        op('update-retry', 'block', {
          'id': 'b',
          'retry': {'enabled': true},
        }),
        op('batch-remove-blocks', 'blocks', {'ids': 'b1'}),
        op('batch-toggle-enabled', 'blocks', {
          'blockIds': ['b'],
          'previousStates': {'b': 'yes'},
        }),
        op('batch-update-parent', 'blocks', {
          'updates': [
            {'id': 'b', 'parentId': 'p'},
          ],
        }),
        op('add', 'edge', {'source': 'a'}),
        op('batch-add-edges', 'edges', {
          'edges': [
            {'id': 'e'},
          ],
        }),
        op('subblock-batch-update', 'subblock', {
          'updates': [1],
        }),
        op('subblock-update-with-canonical-modes', 'subblock', {
          'blockId': 'b',
          'subblockId': 's',
          'value': 1,
          'canonicalModes': {'x': 'nope'},
        }),
        op('update', 'subflow', {'id': 'l', 'type': 'sequential'}),
        op('add', 'variable', {'id': 'v', 'name': 'n'}),
        op('variable-update', 'variable', {'variableId': 'v'}),
        op('replace-state', 'workflow', <String, Object?>{}),
        {'operation': 'update-name', 'target': 'block'},
        {'operation': 'update-name', 'payload': <String, Object?>{}},
      ];
      for (final json in malformed) {
        expect(
          () => WorkflowOperation.fromJson(json),
          throwsA(isA<ProtocolFormatException>()),
          reason: jsonEncode(json),
        );
      }
    });

    test('an unknown operation or target decodes opaquely', () {
      final unknownName = WorkflowOperation.fromJson({
        'operation': 'teleport',
        'target': 'block',
        'payload': {'id': 'b1'},
      });
      expect(unknownName, isA<UnknownWorkflowOperation>());
      expect(unknownName.operation, 'teleport');
      expect(unknownName.target, 'block');

      final unknownTarget = WorkflowOperation.fromJson({
        'operation': 'add',
        'target': 'comments',
        'payload': {'text': 'hi'},
      });
      expect(unknownTarget, isA<UnknownWorkflowOperation>());
      expect(jsonEncode(unknownTarget.toJson()), contains('"comments"'));
    });

    test('allSocketOperations matches constants.ts order', () {
      expect(allSocketOperations, [
        'update-position',
        'update-name',
        'toggle-enabled',
        'update-parent',
        'update-advanced-mode',
        'update-error-enabled',
        'update-retry',
        'update-canonical-mode',
        'replace-canonical-modes',
        'toggle-handles',
        'batch-update-positions',
        'batch-add-blocks',
        'batch-remove-blocks',
        'batch-toggle-enabled',
        'batch-toggle-handles',
        'batch-update-parent',
        'batch-toggle-locked',
        'add',
        'remove',
        'batch-add-edges',
        'batch-remove-edges',
        'replace-state',
        'subblock-update',
        'subblock-batch-update',
        'subblock-update-with-canonical-modes',
        'add',
        'remove',
        'variable-update',
        'update',
      ]);
      expect(OperationTargets.all, [
        'block',
        'blocks',
        'edge',
        'edges',
        'subblock',
        'subflow',
        'variable',
        'workflow',
      ]);
    });
  });

  group('client events', () {
    test('payload keys match socket-provider.tsx', () {
      const join = JoinWorkflowEvent(workflowId: 'wf', tabSessionId: 'tab');
      expect(join.name, 'join-workflow');
      expect(join.toJson(), {'workflowId': 'wf', 'tabSessionId': 'tab'});

      const leave = LeaveWorkflowEvent();
      expect(leave.name, 'leave-workflow');
      expect(leave.toJson(), isNull);

      final operation = WorkflowOperationEvent(
        workflowId: 'wf',
        operation: UpdateNameOperation(id: 'b1', name: 'n'),
        timestamp: 123,
        operationId: 'op1',
      );
      expect(operation.toJson().keys.toList(), [
        'workflowId',
        'operation',
        'target',
        'payload',
        'timestamp',
        'operationId',
      ]);
      expect(operation.toJson()['operation'], 'update-name');

      const subblock = SubblockUpdateEvent(
        workflowId: 'wf',
        blockId: 'b1',
        subblockId: 's',
        value: 'v',
        timestamp: 1,
        operationId: 'op2',
      );
      expect(subblock.toJson().keys.toList(), [
        'workflowId',
        'blockId',
        'subblockId',
        'value',
        'timestamp',
        'operationId',
      ]);

      const variable = VariableUpdateEvent(
        workflowId: 'wf',
        variableId: 'v1',
        field: 'name',
        value: 'n',
        timestamp: 1,
        operationId: 'op3',
      );
      expect(variable.toJson().keys.toList(), [
        'workflowId',
        'variableId',
        'field',
        'value',
        'timestamp',
        'operationId',
      ]);

      expect(const CursorUpdateEvent(null).toJson(), {'cursor': null});
      expect(const CursorUpdateEvent(CursorPosition(1, 2)).toJson(), {
        'cursor': {'x': 1, 'y': 2},
      });
      expect(
        const SelectionUpdateEvent(
          PresenceSelection(SelectionType.block, id: 'b1'),
        ).toJson(),
        {
          'selection': {'type': 'block', 'id': 'b1'},
        },
      );
      expect(const SelectionUpdateEvent(PresenceSelection.none).toJson(), {
        'selection': {'type': 'none'},
      });
    });

    test('every client event decodes back from its wire form', () {
      final events = <ClientEvent>[
        const JoinWorkflowEvent(workflowId: 'wf', tabSessionId: 'tab'),
        const LeaveWorkflowEvent(),
        WorkflowOperationEvent(
          workflowId: 'wf',
          operation: BatchRemoveBlocksOperation(ids: const ['b1']),
          timestamp: 5,
          operationId: 'op',
        ),
        const SubblockUpdateEvent(
          workflowId: 'wf',
          blockId: 'b',
          subblockId: 's',
          value: 1,
          timestamp: 5,
        ),
        const VariableUpdateEvent(
          workflowId: 'wf',
          variableId: 'v',
          field: 'value',
          value: null,
          timestamp: 5,
        ),
        const CursorUpdateEvent(CursorPosition(0.5, 9)),
        const SelectionUpdateEvent(
          PresenceSelection(SelectionType.edge, id: 'e'),
        ),
      ];
      for (final event in events) {
        final decoded = ClientEvent.decode(event.name, event.toJson());
        expect(decoded.runtimeType, event.runtimeType);
        expect(jsonEncode(decoded.toJson()), jsonEncode(event.toJson()));
      }
      expect(
        () => ClientEvent.decode('warp', null),
        throwsA(isA<ProtocolFormatException>()),
      );
    });
  });

  group('server events', () {
    final samples = <String, Object?>{
      'join-workflow-success': {
        'workflowId': 'wf',
        'socketId': 's1',
        'presenceUsers': [
          {
            'userId': 'u1',
            'userName': 'Ada',
            'socketId': 's1',
            'tabSessionId': 'tab',
            'joinedAt': 1,
            'lastActivity': 2,
            'role': 'admin',
            'avatarUrl': null,
            'room': {'type': 'workflow', 'id': 'wf'},
          },
        ],
      },
      'join-workflow-error': {
        'workflowId': 'wf',
        'error': 'Access denied to workflow',
        'code': 'ACCESS_DENIED',
        'retryable': false,
      },
      'workflow-state': {
        'id': 'wf',
        'name': 'My flow',
        'state': {
          'hasActiveWebhook': false,
          'blocks': <String, Object?>{},
          'edges': <Object?>[],
          'loops': <String, Object?>{},
          'parallels': <String, Object?>{},
          'lastSaved': 10,
          'isDeployed': false,
          'deployedAt': null,
        },
        'lastModified': 11,
      },
      'presence-update': [
        {'userId': 'u1', 'userName': 'Ada', 'socketId': 's1', 'cursor': null},
      ],
      'workflow-operation': {
        'operation': 'update-name',
        'target': 'block',
        'payload': {'id': 'b1', 'name': 'n'},
        'timestamp': 1,
        'senderId': 's2',
        'userId': 'u2',
        'userName': 'Bob',
        'metadata': {'workflowId': 'wf', 'operationId': 'srv-1'},
      },
      'subblock-update': {
        'workflowId': 'wf',
        'blockId': 'b1',
        'subblockId': 's',
        'value': 'v',
        'timestamp': 1,
      },
      'variable-update': {
        'workflowId': 'wf',
        'variableId': 'v1',
        'field': 'name',
        'value': 'n',
        'timestamp': 1,
      },
      'cursor-update': {
        'socketId': 's2',
        'userId': 'u2',
        'userName': 'Bob',
        'cursor': {'x': 1, 'y': 2},
      },
      'selection-update': {
        'socketId': 's2',
        'userId': 'u2',
        'userName': 'Bob',
        'avatarUrl': 'https://x/y.png',
        'selection': {'type': 'block', 'id': 'b1'},
      },
      'operation-confirmed': {'operationId': 'op1', 'serverTimestamp': 5},
      'operation-failed': {
        'operationId': 'op1',
        'error': 'Session expired',
      },
      'operation-error': {
        'type': 'VALIDATION_ERROR',
        'message': 'Invalid operation data',
        'errors': [
          {
            'path': <Object?>['payload', 'id'],
          },
        ],
        'operation': 'update-name',
        'target': 'block',
      },
      'operation-forbidden': {
        'type': 'SESSION_ERROR',
        'message': 'Session expired, please rejoin workflow',
      },
      'workflow-deleted': {
        'workflowId': 'wf',
        'message': 'gone',
        'timestamp': 1,
      },
      'workflow-reverted': {'workflowId': 'wf', 'message': 'r', 'timestamp': 1},
      'workflow-updated': {'workflowId': 'wf', 'message': 'u', 'timestamp': 1},
      'workflow-deployed': {'workflowId': 'wf', 'timestamp': 1},
      'access-revoked': {'workflowId': 'wf', 'message': 'a', 'timestamp': 1},
      'room-access-revoked': {
        'room': {'type': 'table', 'id': 't1'},
        'message': 'r',
        'timestamp': 1,
      },
    };

    test('every name decodes to its typed event and re-encodes equally', () {
      final expectedTypes = <String, Type>{
        'join-workflow-success': JoinWorkflowSuccessEvent,
        'join-workflow-error': JoinWorkflowErrorEvent,
        'workflow-state': WorkflowStateEvent,
        'presence-update': PresenceUpdateEvent,
        'workflow-operation': WorkflowOperationBroadcast,
        'subblock-update': SubblockUpdateBroadcast,
        'variable-update': VariableUpdateBroadcast,
        'cursor-update': CursorUpdateBroadcast,
        'selection-update': SelectionUpdateBroadcast,
        'operation-confirmed': OperationConfirmedEvent,
        'operation-failed': OperationFailedEvent,
        'operation-error': OperationErrorEvent,
        'operation-forbidden': OperationForbiddenEvent,
        'workflow-deleted': WorkflowDeletedEvent,
        'workflow-reverted': WorkflowRevertedEvent,
        'workflow-updated': WorkflowUpdatedEvent,
        'workflow-deployed': WorkflowDeployedEvent,
        'access-revoked': AccessRevokedEvent,
        'room-access-revoked': RoomAccessRevokedEvent,
      };
      for (final entry in samples.entries) {
        final event = ServerEvent.decode(entry.key, entry.value);
        expect(event.runtimeType, expectedTypes[entry.key], reason: entry.key);
        expect(event.name, entry.key);
        expect(
          jsonDecode(jsonEncode(event.toJson())),
          jsonDecode(jsonEncode(entry.value)),
          reason: entry.key,
        );
      }
    });

    test('typed fields read the upstream shapes', () {
      final success =
          ServerEvent.decode(
                'join-workflow-success',
                samples['join-workflow-success'],
              )
              as JoinWorkflowSuccessEvent;
      expect(success.presenceUsers.single.role, 'admin');
      expect(success.presenceUsers.single.hasCursorField, isFalse);

      final presence =
          ServerEvent.decode('presence-update', samples['presence-update'])
              as PresenceUpdateEvent;
      expect(presence.users.single.hasCursorField, isTrue);
      expect(presence.users.single.cursor, isNull);

      final failed =
          ServerEvent.decode('operation-failed', samples['operation-failed'])
              as OperationFailedEvent;
      expect(failed.retryable, isNull);

      final broadcast =
          ServerEvent.decode(
                'workflow-operation',
                samples['workflow-operation'],
              )
              as WorkflowOperationBroadcast;
      expect(broadcast.operation, isA<UpdateNameOperation>());
      expect(broadcast.metadata.isPositionUpdate, isNull);

      final revoked =
          ServerEvent.decode(
                'room-access-revoked',
                samples['room-access-revoked'],
              )
              as RoomAccessRevokedEvent;
      expect(revoked.room, const RoomRef(RoomType.table, 't1'));

      final state =
          ServerEvent.decode('workflow-state', samples['workflow-state'])
              as WorkflowStateEvent;
      expect(state.state?['lastSaved'], 10);
      expect(state.raw['name'], 'My flow');
    });

    test('an unknown event name decodes to UnknownEvent', () {
      final event = ServerEvent.decode('workspace-file-doc:presence-update', [
        1,
      ]);
      expect(event, isA<UnknownEvent>());
      expect(event.name, 'workspace-file-doc:presence-update');
      expect(event.toJson(), [1]);
    });

    test('a malformed known payload decodes to MalformedEvent', () {
      final cases = <String, Object?>{
        'join-workflow-success': 'garbage',
        'presence-update': {'not': 'a list'},
        'operation-confirmed': <String, Object?>{},
        'operation-failed': {'operationId': 1, 'error': 'x'},
        'workflow-operation': {
          'operation': 'update-name',
          'target': 'block',
          'payload': {'id': 'b'},
          'timestamp': 1,
          'senderId': 's',
          'userId': 'u',
          'userName': 'n',
        },
        'workflow-operation ': null,
        'room-access-revoked': {
          'room': {'type': 'spaceship', 'id': 'x'},
          'message': 'm',
          'timestamp': 1,
        },
        'workflow-deployed': {'workflowId': 'wf', 'timestamp': 'soon'},
        'cursor-update': {
          'socketId': 's',
          'userId': 'u',
          'userName': 'n',
          'cursor': {'x': 'left'},
        },
        'selection-update': {
          'socketId': 's',
          'userId': 'u',
          'userName': 'n',
          'selection': {'type': 'group'},
        },
      };
      for (final entry in cases.entries) {
        final name = entry.key.trim();
        final event = ServerEvent.decode(name, entry.value);
        expect(event, isA<MalformedEvent>(), reason: entry.key);
        expect((event as MalformedEvent).data, entry.value);
        expect(event.name, name);
      }
    });
  });

  group('presence', () {
    test('merge keeps an absent cursor and honours an explicit null', () {
      const previous = [
        UserPresence(
          socketId: 's1',
          userId: 'u1',
          userName: 'Ada',
          cursor: CursorPosition(1, 1),
          hasCursorField: true,
          selection: PresenceSelection(SelectionType.block, id: 'b'),
        ),
        UserPresence(
          socketId: 's2',
          userId: 'u2',
          userName: 'Bob',
          cursor: CursorPosition(2, 2),
          hasCursorField: true,
        ),
      ];
      const incoming = [
        UserPresence(socketId: 's1', userId: 'u1', userName: 'Ada'),
        UserPresence(
          socketId: 's2',
          userId: 'u2',
          userName: 'Bob',
          hasCursorField: true,
        ),
        UserPresence(socketId: 's3', userId: 'u3', userName: 'Cy'),
      ];
      final merged = mergePresenceRoster(previous, incoming);
      expect(merged.map((u) => u.socketId), ['s1', 's2', 's3']);
      expect(merged[0].cursor, const CursorPosition(1, 1));
      expect(merged[0].selection?.id, 'b');
      expect(merged[1].cursor, isNull);
      expect(merged[1].hasCursorField, isTrue);
      expect(merged[2].cursor, isNull);
    });

    test('a presence record emits cursor only when the field was present', () {
      const absent = UserPresence(socketId: 's', userId: 'u', userName: 'n');
      expect(absent.toJson().containsKey('cursor'), isFalse);
      final cleared = absent.withCursor(null);
      expect(cleared.toJson()['cursor'], isNull);
      expect(cleared.toJson().containsKey('cursor'), isTrue);
      expect(PresenceSelection.none.toJson(), {
        'type': 'none',
      });
    });
  });

  group('rooms', () {
    test('workflow rooms are bare ids, others are prefixed', () {
      expect(roomName(const RoomRef(RoomType.workflow, 'wf-1')), 'wf-1');
      expect(
        roomName(const RoomRef(RoomType.workspaceFiles, 'ws')),
        'workspace-files:ws',
      );
      expect(parseRoomName('wf-1'), const RoomRef(RoomType.workflow, 'wf-1'));
      expect(
        parseRoomName('table:t1'),
        const RoomRef(RoomType.table, 't1'),
      );
      expect(
        parseRoomName('project-file-doc:p/f'),
        const RoomRef(RoomType.projectFileDoc, 'p/f'),
      );
      expect(
        parseRoomName('unknown:x'),
        const RoomRef(RoomType.workflow, 'unknown:x'),
      );
      expect(
        parseRoomName('workflow:x'),
        const RoomRef(RoomType.workflow, 'workflow:x'),
      );
      expect(parseRoomName(''), isNull);
      expect(presenceEventName(RoomType.workflow), 'presence-update');
      expect(presenceEventName(RoomType.table), 'table:presence-update');
    });

    test('project document identities reject separators', () {
      expect(
        projectFileDocRoom('p', 'f'),
        const RoomRef(RoomType.projectFileDoc, 'p/f'),
      );
      expect(() => projectFileDocRoom('p/x', 'f'), throwsArgumentError);
      expect(() => projectFileDocRoom('p', ''), throwsArgumentError);
      expect(
        projectFileDocTarget(const RoomRef(RoomType.projectFileDoc, 'p/f')),
        (projectId: 'p', fileId: 'f'),
      );
      expect(
        projectFileDocTarget(const RoomRef(RoomType.projectFileDoc, 'p/f/g')),
        isNull,
      );
      expect(
        projectFileDocTarget(const RoomRef(RoomType.table, 'p/f')),
        isNull,
      );
      expect(isProjectRoom(const RoomRef(RoomType.projectFiles, 'p')), isTrue);
      expect(isProjectRoom(const RoomRef(RoomType.workflow, 'w')), isFalse);
      expect(invalidationRoomIdKey(RoomType.projectFiles), 'projectId');
      expect(invalidationRoomIdKey(RoomType.workspaceTables), 'workspaceId');
      expect(
        () => invalidationRoomIdKey(RoomType.workflow),
        throwsArgumentError,
      );
      expect(
        () => RoomRef.fromJson(const {'type': 'nope', 'id': 'x'}),
        throwsFormatException,
      );
    });
  });
}
