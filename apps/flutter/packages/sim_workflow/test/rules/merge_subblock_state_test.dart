// Failure modes for mergeSubblockState
// (port of packages/workflow-persistence/src/subblocks.ts):
//  1. Explicit null in the values map overrides the structure value (cleared).
//  2. A key absent from the values map leaves the structure value alone.
//  3. A null value for a sub-block missing from the structure creates nothing.
//  4. A non-null value for a sub-block missing from the structure creates a
//     default `short-input` entry (runtime ids like `webhookId`).
//  5. Merging a single `blockId` returns only that block.
//  6. A `blockId` that does not exist returns an empty map, not a crash.
//  7. Blocks without any stored values are returned structurally unchanged.
//  8. Values for a block id not in `blocks` are ignored.
//  9. The structure's sub-block `type` and unknown keys survive a merge.
// 10. The inputs are not mutated.
import 'package:sim_workflow/sim_workflow.dart';
import 'package:test/test.dart';

BlockState _block(String id, Map<String, SubBlockState> subBlocks) =>
    BlockState(
      id: id,
      type: 'api',
      name: 'API',
      position: Position.zero,
      subBlocks: subBlocks,
      outputs: const {},
      enabled: true,
    );

SubBlockState _sub(String id, Object? value) =>
    SubBlockState(id: id, type: 'short-input', value: value);

void main() {
  final blocks = {
    'b1': _block('b1', {'channel': _sub('channel', 'old')}),
    'b2': _block('b2', {'channel': _sub('channel', 'other')}),
  };

  test('1. explicit null clears the structure value', () {
    final merged = mergeSubblockState(blocks, {
      'b1': {'channel': null},
    });
    expect(merged['b1']!.subBlocks['channel']!.value, isNull);
  });

  test('2. absent key keeps the structure value', () {
    final merged = mergeSubblockState(blocks, {'b1': <String, Object?>{}});
    expect(merged['b1']!.subBlocks['channel']!.value, 'old');
  });

  test('3. null for a structure-less sub-block creates nothing', () {
    final merged = mergeSubblockState(blocks, {
      'b1': {'webhookId': null},
    });
    expect(merged['b1']!.subBlocks.containsKey('webhookId'), isFalse);
  });

  test('4. non-null structure-less value gets a default shape', () {
    final merged = mergeSubblockState(blocks, {
      'b1': {'webhookId': 'wh_1'},
    });
    final created = merged['b1']!.subBlocks['webhookId']!;
    expect(created.id, 'webhookId');
    expect(created.type, defaultSubBlockType);
    expect(created.value, 'wh_1');
  });

  test('5. merging one block returns only that block', () {
    final merged = mergeSubblockState(
      blocks,
      {
        'b1': {'channel': null},
        'b2': {'channel': null},
      },
      blockId: 'b1',
    );
    expect(merged.keys, ['b1']);
    expect(merged['b1']!.subBlocks['channel']!.value, isNull);
  });

  test('6. unknown blockId yields an empty map', () {
    expect(mergeSubblockState(blocks, const {}, blockId: 'nope'), isEmpty);
  });

  test('7. blocks without stored values are unchanged', () {
    final merged = mergeSubblockState(blocks, const {});
    expect(merged['b2'], equals(blocks['b2']));
  });

  test('8. values for an unknown block are ignored', () {
    final merged = mergeSubblockState(blocks, {
      'ghost': {'channel': 'x'},
    });
    expect(merged.keys, unorderedEquals(['b1', 'b2']));
  });

  test('9. type and unknown keys survive', () {
    final withExtra = {
      'b1': _block('b1', {
        'channel': SubBlockState(
          id: 'channel',
          type: 'channel-selector',
          value: 'old',
          extra: const {'future': 1},
        ),
      }),
    };
    final merged = mergeSubblockState(withExtra, {
      'b1': {'channel': 'new'},
    });
    final sub = merged['b1']!.subBlocks['channel']!;
    expect(sub.type, 'channel-selector');
    expect(sub.extra, {'future': 1});
    expect(sub.value, 'new');
  });

  test('10. inputs are not mutated', () {
    final values = {
      'b1': {'channel': 'new'},
    };
    mergeSubblockState(blocks, values);
    expect(blocks['b1']!.subBlocks['channel']!.value, 'old');
    expect(values['b1'], {'channel': 'new'});
  });
}
