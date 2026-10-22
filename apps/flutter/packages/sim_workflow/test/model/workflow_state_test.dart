// Failure modes for the workflow state model (lib/src/model/**):
//  1. Fixture round trip: decoding the hand-copied upstream shape and
//     re-encoding yields the same JSON structure (unknown keys included).
//  2. Missing required scalar on a block (`name`) throws a FormatException
//     naming the path, instead of producing a half-built block.
//  3. Wrong type for a field (`position.x` as a string) throws FormatException.
//  4. Unknown keys at every level (state, block, data, edge, loop, parallel,
//     variable) survive a round trip.
//  5. Null vs missing: a cleared sub-block value is emitted as `"value": null`;
//     an absent optional block flag stays absent; an explicit `"retry": null`
//     is read as absent.
//  6. Integral doubles are emitted as JSON integers (position 100 stays 100).
//  7. Empty sub-block/output maps are kept as `{}` rather than dropped.
//  8. `SubBlockType.fromId` returns null for an unknown id while the state
//     keeps the raw type string.
//  9. `copyWith` can clear an optional field to absent (sentinel semantics).
// 10. Value equality: equal JSON produces equal values; a changed leaf breaks
//     equality and `hashCode` agrees.
// 11. Collections exposed by the model are unmodifiable.
// 12. Loop `forEachItems` accepts an array, a record, and a string.
// 13. An edge whose handles are explicitly null omits them on output, and
//     foreign @xyflow fields (`selected`) are preserved.
// 14. A variable with an unknown `type` throws FormatException.
// 15. Top-level `blocks`/`edges`/`loops`/`parallels` missing decode to empty.
// 16. Retry normalisation clamps out-of-range and non-numeric tries/waits and
//     `resolveBlockRetryConfig` returns null when disabled or absent.
// 17. `getWorkflowBlockNameConflict` reports empty, reserved and duplicate
//     names and ignores the block's own current name.
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:sim_workflow/sim_workflow.dart';
import 'package:test/test.dart';

const _deep = DeepCollectionEquality();

Map<String, Object?> _fixture() {
  final raw = File(
    'test/model/fixtures/workflow_state.json',
  ).readAsStringSync();
  return jsonDecode(raw) as Map<String, Object?>;
}

Map<String, Object?> _roundTrip(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(WorkflowState.fromJson(json).toJson()))
        as Map<String, Object?>;

Map<String, Object?> _blocks(Map<String, Object?> json) =>
    json['blocks']! as Map<String, Object?>;

void main() {
  group('WorkflowState JSON', () {
    test('1. fixture round trip is structurally identical', () {
      final json = _fixture();
      expect(_deep.equals(_roundTrip(json), json), isTrue);
    });

    test('2. missing required block field throws with a path', () {
      final json = _fixture();
      final start = Map.of(_blocks(json)['start-1']! as Map<String, Object?>)
        ..remove('name');
      _blocks(json)['start-1'] = start;
      expect(
        () => WorkflowState.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('name'),
          ),
        ),
      );
    });

    test('3. wrong type for position.x throws FormatException', () {
      final json = _fixture();
      final block = Map.of(_blocks(json)['agent-1']! as Map<String, Object?>);
      block['position'] = const {'x': 'nope', 'y': 0};
      _blocks(json)['agent-1'] = block;
      expect(() => WorkflowState.fromJson(json), throwsFormatException);
    });

    test('4. unknown keys survive at every level', () {
      final out = _roundTrip(_fixture());
      expect(out['unknownTopLevel'], 'kept');
      final agent = _blocks(out)['agent-1']! as Map<String, Object?>;
      expect(agent['someFutureKey'], {'nested': true});
      expect((agent['data']! as Map<String, Object?>)['futureFlag'], 1);
      final edges = out['edges']! as List<Object?>;
      expect((edges[1]! as Map<String, Object?>)['selected'], true);
    });

    test('5. null vs missing is preserved', () {
      final out = _roundTrip(_fixture());
      final start = _blocks(out)['start-1']! as Map<String, Object?>;
      final subBlocks = start['subBlocks']! as Map<String, Object?>;
      final webhook = subBlocks['webhookId']! as Map<String, Object?>;
      expect(webhook.containsKey('value'), isTrue);
      expect(webhook['value'], isNull);
      expect(start.containsKey('retry'), isFalse);
      expect(start.containsKey('locked'), isFalse);

      final json = _fixture();
      final block = Map.of(_blocks(json)['agent-1']! as Map<String, Object?>)
        ..['retry'] = null;
      _blocks(json)['agent-1'] = block;
      final state = WorkflowState.fromJson(json);
      expect(state.blocks['agent-1']!.retry, isNull);
      expect(state.blocks['agent-1']!.toJson().containsKey('retry'), isFalse);
    });

    test('6. integral doubles are emitted as integers', () {
      final encoded = jsonEncode(const Position(x: 100, y: -20.5).toJson());
      expect(encoded, '{"x":100,"y":-20.5}');
    });

    test('7. empty maps are kept', () {
      final out = _roundTrip(_fixture());
      final loop = _blocks(out)['loop-1']! as Map<String, Object?>;
      expect(loop['subBlocks'], isEmpty);
      expect(loop.containsKey('subBlocks'), isTrue);
      expect(loop['outputs'], isEmpty);
    });

    test('8. unknown sub-block type id is kept raw', () {
      expect(SubBlockType.fromId('trigger-config'), isNull);
      expect(SubBlockType.fromId('short-input'), SubBlockType.shortInput);
      expect(SubBlockType.values, hasLength(48));
      final sub = SubBlockState.fromJson(const {
        'id': 'x',
        'type': 'trigger-config',
        'value': 1,
      });
      expect(sub.type, 'trigger-config');
      expect(sub.subBlockType, isNull);
    });

    test('9. copyWith can clear optional fields', () {
      final state = WorkflowState.fromJson(_fixture());
      final agent = state.blocks['agent-1']!;
      expect(agent.data, isNotNull);
      final cleared = agent.copyWith(data: null, retry: null);
      expect(cleared.data, isNull);
      expect(cleared.retry, isNull);
      expect(cleared.name, agent.name);
      final untouched = agent.copyWith(name: 'Renamed');
      expect(untouched.data, agent.data);
      expect(untouched.retry, agent.retry);
    });

    test('10. value equality and hashCode agree', () {
      final a = WorkflowState.fromJson(_fixture());
      final b = WorkflowState.fromJson(_fixture());
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      final changed = b.copyWith(
        blocks: {
          ...b.blocks,
          'agent-1': b.blocks['agent-1']!.copyWith(enabled: true),
        },
      );
      expect(a, isNot(equals(changed)));
    });

    test('11. exposed collections are unmodifiable', () {
      final state = WorkflowState.fromJson(_fixture());
      expect(
        () => state.blocks['x'] = state.blocks['agent-1']!,
        throwsUnsupportedError,
      );
      expect(() => state.edges.add(state.edges.first), throwsUnsupportedError);
      expect(
        () => state.blocks['agent-1']!.subBlocks.remove('model'),
        throwsUnsupportedError,
      );
      expect(
        () => state.loops['loop-1']!.nodes.add('z'),
        throwsUnsupportedError,
      );
    });

    test('12. forEachItems accepts array, record and string', () {
      for (final items in <Object>[
        ['a', 1],
        {'k': 'v'},
        '<start.input>',
      ]) {
        final loop = Loop.fromJson({
          'id': 'l',
          'nodes': const <String>[],
          'iterations': 1,
          'loopType': 'forEach',
          'forEachItems': items,
          'enabled': true,
        });
        expect(_deep.equals(loop.forEachItems, items), isTrue);
        expect(_deep.equals(loop.toJson()['forEachItems'], items), isTrue);
      }
    });

    test('13. explicit null handles are omitted; foreign fields kept', () {
      final edge = Edge.fromJson(const {
        'id': 'e',
        'source': 'a',
        'target': 'b',
        'sourceHandle': null,
        'targetHandle': null,
        'selected': true,
        'label': 'x',
      });
      expect(edge.sourceHandle, isNull);
      final json = edge.toJson();
      expect(json.containsKey('sourceHandle'), isFalse);
      expect(json['selected'], true);
      expect(json['label'], 'x');
    });

    test('14. unknown variable type throws', () {
      expect(
        () => Variable.fromJson(const {
          'id': 'v',
          'name': 'n',
          'type': 'tuple',
          'value': null,
        }),
        throwsFormatException,
      );
    });

    test('15. missing top-level collections decode to empty', () {
      final state = WorkflowState.fromJson(const {});
      expect(state.blocks, isEmpty);
      expect(state.edges, isEmpty);
      expect(state.loops, isEmpty);
      expect(state.parallels, isEmpty);
      expect(state.variables, isNull);
    });

    test('16. retry normalisation clamps and resolves', () {
      expect(normalizeBlockRetryTries(null), blockRetryDefaultTries);
      expect(normalizeBlockRetryTries(''), blockRetryMinTries);
      expect(normalizeBlockRetryTries('abc'), blockRetryDefaultTries);
      expect(normalizeBlockRetryTries(99), blockRetryMaxTries);
      expect(normalizeBlockRetryTries(0), blockRetryMinTries);
      expect(normalizeBlockRetryTries(2.9), 2);
      expect(normalizeBlockRetryTries('4'), 4);
      expect(normalizeBlockRetryWaitMs(-5), blockRetryMinWaitMs);
      expect(
        normalizeBlockRetryWaitMs(double.infinity),
        blockRetryDefaultWaitMs,
      );
      expect(resolveBlockRetryConfig(null), isNull);
      expect(
        resolveBlockRetryConfig(
          const BlockRetryConfig(
            enabled: false,
            maxTries: 3,
            waitBetweenTriesMs: 1,
          ),
        ),
        isNull,
      );
      expect(
        resolveBlockRetryConfig(
          const BlockRetryConfig(
            enabled: true,
            maxTries: 50,
            waitBetweenTriesMs: 9999,
          ),
        ),
        const BlockRetryConfig(
          enabled: true,
          maxTries: blockRetryMaxTries,
          waitBetweenTriesMs: blockRetryMaxWaitMs,
        ),
      );
      expect(
        blockRetryEquals(
          null,
          const BlockRetryConfig(
            enabled: true,
            maxTries: 2,
            waitBetweenTriesMs: 0,
          ),
        ),
        isFalse,
      );
      expect(blockRetryEquals(null, null), isTrue);
    });

    test('17. block name conflicts', () {
      final siblings = {'a': 'Agent 1', 'b': 'Loop', 'c': 'My.Block 2'};
      expect(
        getWorkflowBlockNameConflict('a', '  ', siblings)?.reason,
        WorkflowBlockNameConflictReason.empty,
      );
      expect(
        getWorkflowBlockNameConflict('a', 'Variable', siblings)?.reason,
        WorkflowBlockNameConflictReason.reserved,
      );
      final dup = getWorkflowBlockNameConflict('a', 'myblock2', siblings);
      expect(dup?.reason, WorkflowBlockNameConflictReason.duplicate);
      expect(dup?.conflictingBlockId, 'c');
      expect(getWorkflowBlockNameConflict('a', 'agent 1', siblings), isNull);
      expect(normalizeWorkflowBlockName('Trigger.dev 1'), 'triggerdev1');
    });
  });
}
