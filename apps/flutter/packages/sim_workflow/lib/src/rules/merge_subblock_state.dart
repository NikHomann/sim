import 'package:sim_workflow/src/model/block_state.dart';
import 'package:sim_workflow/src/model/sub_block_state.dart';

/// Port of `DEFAULT_SUBBLOCK_TYPE` from
/// `packages/workflow-persistence/src/subblocks.ts`.
const String defaultSubBlockType = 'short-input';

/// Port of `mergeSubBlockValues` from
/// `packages/workflow-persistence/src/subblocks.ts`: every entry of [values]
/// overrides the matching structure's value; a value with no structure gets
/// the default `short-input` shape.
Map<String, SubBlockState> mergeSubBlockValues(
  Map<String, SubBlockState> subBlocks,
  Map<String, Object?> values,
) {
  final merged = Map<String, SubBlockState>.of(subBlocks);
  for (final entry in values.entries) {
    final existing = merged[entry.key];
    merged[entry.key] = existing != null
        ? existing.copyWith(value: entry.value)
        : SubBlockState(
            id: entry.key,
            type: defaultSubBlockType,
            value: entry.value,
          );
  }
  return merged;
}

/// Port of `mergeSubblockStateWithValues` from
/// `packages/workflow-persistence/src/subblocks.ts`, which
/// `mergeSubblockState` in `apps/sim/stores/workflows/utils.ts` wraps with the
/// active workflow's sub-block store.
///
/// [subBlockValues] is keyed `blockId -> subBlockId -> value`. A key present
/// with `null` means "cleared" and overrides the structure; a key that is
/// absent (upstream `undefined`) never overrides. `null` never creates an
/// entry for a sub-block missing from the structure; a non-null structure-less
/// value (runtime ids such as `webhookId`) is added with the default shape.
///
/// With [blockId] only that block is merged; an unknown id yields `{}`.
Map<String, BlockState> mergeSubblockState(
  Map<String, BlockState> blocks,
  Map<String, Map<String, Object?>> subBlockValues, {
  String? blockId,
}) {
  final toProcess = blockId == null ? blocks : {blockId: ?blocks[blockId]};

  final result = <String, BlockState>{};
  for (final entry in toProcess.entries) {
    final block = entry.value;
    final structure = block.subBlocks;
    final stored = subBlockValues[entry.key] ?? const {};
    final mergeable = <String, Object?>{
      for (final value in stored.entries)
        if (value.value != null || structure.containsKey(value.key))
          value.key: value.value,
    };
    result[entry.key] = block.copyWith(
      subBlocks: mergeSubBlockValues(structure, mergeable),
    );
  }
  return result;
}
