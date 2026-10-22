// Failure modes for handle ids and dimensions
// (ports of packages/workflow-types/src/workflow.ts handle constants,
// apps/sim/lib/workflows/dynamic-handle-topology.ts and
// packages/workflow-renderer/src/dimensions.ts):
//  1. Condition rows: a JSON *string* value is parsed; a non-array string or
//     malformed JSON falls back to the default if/else pair.
//  2. Condition rows: an empty array falls back to the default pair.
//  3. Condition row titles: first `if`, last `else`, middle `else if`; a
//     single row is titled `if`.
//  4. A row without an `id` gets `${blockId}-cond-${index}`; without a string
//     `value` gets ''.
//  5. Router rows default to one `${blockId}-route1`; missing ids are
//     numbered from 1; titles are `Route N`.
//  6. Dynamic handle rows: a block of any other type has none; handle ids are
//     prefixed `condition-` / `router-`.
//  7. Subflow handle ids are `${kind}-start-source` / `${kind}-end-source`.
//  8. Condition handle y positions follow 58 + 28·row.
//  9. Note height clamps: empty content → min; many lines → max; two lines
//     estimated between; measured content is clamped with the header added.
// 10. SUBFLOW_CONNECTION_Y is derived (40 + 12 + 17 = 69).
import 'package:sim_workflow/sim_workflow.dart';
import 'package:test/test.dart';

BlockState _block(String id, String type, Map<String, Object?> values) =>
    BlockState(
      id: id,
      type: type,
      name: id,
      position: Position.zero,
      subBlocks: {
        for (final entry in values.entries)
          entry.key: SubBlockState(
            id: entry.key,
            type: 'condition-input',
            value: entry.value,
          ),
      },
      outputs: const {},
      enabled: true,
    );

void main() {
  test('1. JSON string values are parsed; garbage falls back', () {
    final parsed = getConditionRows(
      'b',
      '[{"id":"x","value":"a > 1"},{"id":"y","value":""}]',
    );
    expect(parsed.map((r) => r.id), ['x', 'y']);
    expect(parsed.first.value, 'a > 1');
    expect(getConditionRows('b', '{"id":"x"}').map((r) => r.id), [
      'b-if',
      'b-else',
    ]);
    expect(getConditionRows('b', 'not json').map((r) => r.id), [
      'b-if',
      'b-else',
    ]);
  });

  test('2. empty array falls back to the default pair', () {
    final rows = getConditionRows('b', const <Object?>[]);
    expect(rows.map((r) => r.id), ['b-if', 'b-else']);
    expect(rows.map((r) => r.title), ['if', 'else']);
  });

  test('3. titles by position', () {
    final rows = getConditionRows('b', [
      {'id': '1'},
      {'id': '2'},
      {'id': '3'},
    ]);
    expect(rows.map((r) => r.title), ['if', 'else if', 'else']);
    expect(
      getConditionRows('b', [
        {'id': 'only'},
      ]).single.title,
      'if',
    );
  });

  test('4. missing id and non-string value', () {
    final rows = getConditionRows('b', [
      {'value': 5},
      {'id': 'z', 'value': 'ok'},
    ]);
    expect(rows.first.id, 'b-cond-0');
    expect(rows.first.value, '');
    expect(rows.last.value, 'ok');
  });

  test('5. router rows', () {
    expect(getRouterRows('b', null).single.id, 'b-route1');
    final rows = getRouterRows('b', [
      {'value': 'a'},
      {'id': 'r', 'value': 'b'},
      <String, Object?>{},
    ]);
    expect(rows.map((r) => r.id), ['b-route1', 'r', 'b-route3']);
    expect(rows.map((r) => r.value), ['a', 'b', '']);
    final handles = getDynamicHandleRows(
      _block('b', 'router_v2', {
        'routes': [
          {'id': 'r1', 'value': 'x'},
        ],
      }),
    );
    expect(handles.single.handleId, 'router-r1');
    expect(handles.single.title, 'Route 1');
  });

  test('6. dynamic handle rows per block type', () {
    expect(getDynamicHandleRows(_block('b', 'agent', const {})), isEmpty);
    final rows = getDynamicHandleRows(
      _block('b', 'condition', {
        'conditions': [
          {'id': 'c1', 'value': 'v'},
          {'id': 'c2'},
        ],
      }),
    );
    expect(rows.map((r) => r.handleId), ['condition-c1', 'condition-c2']);
    expect(conditionHandleId('c1'), 'condition-c1');
    expect(routerHandleId('r1'), 'router-r1');
    expect(getDynamicHandleSubblockId('condition'), 'conditions');
    expect(getDynamicHandleSubblockId('router_v2'), 'routes');
    expect(getDynamicHandleSubblockId('agent'), isNull);
    expect(isDynamicHandleSubblock('condition', 'conditions'), isTrue);
    expect(isDynamicHandleSubblock('condition', 'routes'), isFalse);
  });

  test('7. subflow handle ids', () {
    final loop = getWorkflowSubflowHandleIds(SubflowTypes.loop);
    expect(loop.start, 'loop-start-source');
    expect(loop.end, 'loop-end-source');
    final parallel = getWorkflowSubflowHandleIds(SubflowTypes.parallel);
    expect(parallel.start, 'parallel-start-source');
    expect(parallel.end, 'parallel-end-source');
    expect(workflowSourceHandleId, 'source');
    expect(workflowTargetHandleId, 'target');
    expect(workflowErrorHandleId, 'error');
  });

  test('8. condition handle y positions', () {
    expect(conditionHandleY(0), 58);
    expect(conditionHandleY(1), 86);
    expect(conditionHandleY(3), 58 + 3 * 28);
  });

  test('9. note height clamps', () {
    expect(getNoteBlockHeight(isEmpty: true), 70);
    expect(getNoteBlockHeight(isEmpty: false), 240);
    expect(estimateNoteBlockHeight('   '), 70);
    expect(estimateNoteBlockHeight('a\nb'), 40 + 10 + 2 * 20);
    expect(estimateNoteBlockHeight(List.filled(30, 'x').join('\n')), 240);
    expect(clampNoteBlockHeight(5), 70);
    expect(clampNoteBlockHeight(1000), 240);
    expect(clampNoteBlockTotalHeight(100), 100);
  });

  test('10. SUBFLOW_CONNECTION_Y is derived', () {
    expect(HandlePositions.subflowConnectionY, 69);
    expect(
      HandlePositions.subflowConnectionY,
      BlockDimensions.headerHeight +
          BlockDimensions.subflowStartTopOffset +
          BlockDimensions.subflowStartHeight / 2,
    );
  });
}
