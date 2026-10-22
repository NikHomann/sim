import 'package:sim_workflow/src/model/block_data.dart';
import 'package:sim_workflow/src/model/block_state.dart';
import 'package:sim_workflow/src/model/subflow.dart';

/// Ports of `packages/workflow-persistence/src/subflow-helpers.ts`.
const double _defaultLoopIterations = 5;
const double _defaultParallelCount = 5;
const double _defaultParallelBatchSize = 20;
const double _maxParallelBatchSize = 20;

/// Port of `clampParallelBatchSize`: 1..20, defaulting to 20 when the value is
/// not a number. A non-number goes through `parseInt(String(value), 10)`, so
/// `'12px'` is 12 and `'abc'` falls back; a number is used as is (3.9 stays
/// 3.9, as upstream does not floor it).
double clampParallelBatchSize(Object? batchSize) {
  final parsed = batchSize is num ? batchSize.toDouble() : _parseInt(batchSize);
  if (parsed == null) return _defaultParallelBatchSize;
  return parsed.clamp(1, _maxParallelBatchSize).toDouble();
}

/// JavaScript `parseInt(String(value), 10)`: leading whitespace, optional
/// sign, then as many decimal digits as possible; NaN otherwise.
double? _parseInt(Object? value) {
  final match = RegExp(r'^\s*([+-]?\d+)').firstMatch(value.toString());
  return match == null ? null : double.parse(match.group(1)!);
}

/// JavaScript falsiness for the `||` fallbacks upstream applies to block data.
bool _isFalsy(Object? value) =>
    value == null ||
    value == false ||
    value == '' ||
    (value is num && (value == 0 || value.isNaN));

/// Port of `findChildNodes`: direct children only.
List<String> _findChildNodes(
  String containerId,
  Map<String, BlockState> blocks,
) => [
  for (final block in blocks.values)
    if (block.data?.parentId == containerId) block.id,
];

/// Port of `convertLoopBlockToLoop`.
Loop? convertLoopBlockToLoop(
  String loopBlockId,
  Map<String, BlockState> blocks,
) {
  final loopBlock = blocks[loopBlockId];
  if (loopBlock == null || loopBlock.type != SubflowTypes.loop) return null;
  final data = loopBlock.data;
  final count = data?.count;
  return Loop(
    id: loopBlockId,
    nodes: _findChildNodes(loopBlockId, blocks),
    iterations: _isFalsy(count) ? _defaultLoopIterations : count!,
    loopType: data?.loopType ?? LoopType.forLoop,
    enabled: loopBlock.enabled,
    forEachItems: _isFalsy(data?.collection) ? '' : data!.collection,
    whileCondition: _isFalsy(data?.whileCondition) ? '' : data!.whileCondition,
    doWhileCondition: _isFalsy(data?.doWhileCondition)
        ? ''
        : data!.doWhileCondition,
  );
}

/// Port of `convertParallelBlockToParallel`.
Parallel? _convertParallelBlockToParallel(
  String parallelBlockId,
  Map<String, BlockState> blocks,
) {
  final parallelBlock = blocks[parallelBlockId];
  if (parallelBlock == null || parallelBlock.type != SubflowTypes.parallel) {
    return null;
  }
  final data = parallelBlock.data;
  final parallelType = data?.parallelType ?? ParallelType.count;
  final distribution = parallelType == ParallelType.collection
      ? (_isFalsy(data?.collection) ? '' : data!.collection)
      : null;
  final count = data?.count;
  return Parallel(
    id: parallelBlockId,
    nodes: _findChildNodes(parallelBlockId, blocks),
    distribution: distribution,
    count: _isFalsy(count) ? _defaultParallelCount : count,
    parallelType: parallelType,
    batchSize: clampParallelBatchSize(data?.batchSize),
    enabled: parallelBlock.enabled,
  );
}

/// Port of `generateLoopBlocks`: every `loop` block, keyed by id.
Map<String, Loop> generateLoopBlocks(Map<String, BlockState> blocks) => {
  for (final entry in blocks.entries)
    if (entry.value.type == SubflowTypes.loop)
      entry.key: ?convertLoopBlockToLoop(entry.key, blocks),
};

/// Port of `generateParallelBlocks`: every `parallel` block, keyed by id.
Map<String, Parallel> generateParallelBlocks(Map<String, BlockState> blocks) =>
    {
      for (final entry in blocks.entries)
        if (entry.value.type == SubflowTypes.parallel)
          entry.key: ?_convertParallelBlockToParallel(entry.key, blocks),
    };
