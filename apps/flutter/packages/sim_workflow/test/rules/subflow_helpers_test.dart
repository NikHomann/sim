// Failure modes for generateLoopBlocks / generateParallelBlocks
// (port of packages/workflow-persistence/src/subflow-helpers.ts):
//  1. A loop with no `data` falls back to `for`, 5 iterations, '' items.
//  2. Only direct children (`data.parentId == loop`) are listed as nodes;
//     grandchildren inside a nested container are not.
//  3. A block of type `loop` is skipped by generateParallelBlocks and vice
//     versa; non-container blocks produce nothing.
//  4. `data.count` of 0 falls back to 5 (JS `||`), as does a missing count.
//  5. Parallel with an unknown `parallelType`-free data defaults to `count`,
//     and `distribution` is only set for `collection`.
//  6. clampParallelBatchSize: non-numeric → 20, '7' → 7, 0 → 1, 99 → 20,
//     3.9 → 3.9 (numbers pass through; parseInt only on strings).
//  7. Loop `enabled` mirrors the block's flag.
//  8. Empty blocks map → empty results.
//  9. Loop output keys are exactly the upstream set (no stray `locked`).
import 'package:sim_workflow/sim_workflow.dart';
import 'package:test/test.dart';

BlockState _block(
  String id,
  String type, {
  BlockData? data,
  bool enabled = true,
}) => BlockState(
  id: id,
  type: type,
  name: id,
  position: Position.zero,
  subBlocks: const {},
  outputs: const {},
  enabled: enabled,
  data: data,
);

void main() {
  test('1. loop without data uses defaults', () {
    final loops = generateLoopBlocks({'l': _block('l', 'loop')});
    final loop = loops['l']!;
    expect(loop.loopType, LoopType.forLoop);
    expect(loop.iterations, 5);
    expect(loop.forEachItems, '');
    expect(loop.whileCondition, '');
    expect(loop.doWhileCondition, '');
    expect(loop.nodes, isEmpty);
  });

  test('2. only direct children are nodes', () {
    final blocks = {
      'outer': _block('outer', 'loop'),
      'inner': _block('inner', 'loop', data: BlockData(parentId: 'outer')),
      'leaf': _block('leaf', 'agent', data: BlockData(parentId: 'inner')),
      'sibling': _block('sibling', 'agent', data: BlockData(parentId: 'outer')),
    };
    final loops = generateLoopBlocks(blocks);
    expect(loops['outer']!.nodes, unorderedEquals(['inner', 'sibling']));
    expect(loops['inner']!.nodes, ['leaf']);
  });

  test('3. container kinds do not cross over', () {
    final blocks = {
      'l': _block('l', 'loop'),
      'p': _block('p', 'parallel'),
      'a': _block('a', 'agent'),
    };
    expect(generateLoopBlocks(blocks).keys, ['l']);
    expect(generateParallelBlocks(blocks).keys, ['p']);
  });

  test('4. zero or missing count falls back to 5', () {
    final loops = generateLoopBlocks({
      'l': _block('l', 'loop', data: BlockData(count: 0)),
    });
    expect(loops['l']!.iterations, 5);
    final parallels = generateParallelBlocks({
      'p': _block('p', 'parallel', data: BlockData(count: 0)),
    });
    expect(parallels['p']!.count, 5);
  });

  test('5. parallel type defaults and distribution gating', () {
    final parallels = generateParallelBlocks({
      'p': _block('p', 'parallel', data: BlockData(collection: '<a.b>')),
      'c': _block(
        'c',
        'parallel',
        data: BlockData(
          parallelType: ParallelType.collection,
          collection: const ['x'],
        ),
      ),
    });
    expect(parallels['p']!.parallelType, ParallelType.count);
    expect(parallels['p']!.distribution, isNull);
    expect(parallels['c']!.parallelType, ParallelType.collection);
    expect(parallels['c']!.distribution, ['x']);
  });

  test('6. clampParallelBatchSize', () {
    expect(clampParallelBatchSize(null), 20);
    expect(clampParallelBatchSize('abc'), 20);
    expect(clampParallelBatchSize('7'), 7);
    expect(clampParallelBatchSize(0), 1);
    expect(clampParallelBatchSize(99), 20);
    expect(clampParallelBatchSize(3.9), 3.9);
    expect(clampParallelBatchSize('12px'), 12);
  });

  test('7. enabled mirrors the block', () {
    final loops = generateLoopBlocks({
      'l': _block('l', 'loop', enabled: false),
    });
    expect(loops['l']!.enabled, isFalse);
  });

  test('8. empty input', () {
    expect(generateLoopBlocks(const {}), isEmpty);
    expect(generateParallelBlocks(const {}), isEmpty);
  });

  test('9. loop JSON keys match upstream', () {
    final loop = generateLoopBlocks({'l': _block('l', 'loop')})['l']!;
    expect(
      loop.toJson().keys,
      unorderedEquals([
        'id',
        'nodes',
        'iterations',
        'loopType',
        'enabled',
        'forEachItems',
        'whileCondition',
        'doWhileCondition',
      ]),
    );
  });
}
