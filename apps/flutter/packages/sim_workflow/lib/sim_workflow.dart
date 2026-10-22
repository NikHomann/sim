/// Pure-Dart workflow domain for the Sim Flutter port: workflow state types,
/// block registry contracts, editor rules (merge, subflows, edges, handles,
/// dimensions, canonical pairs, condition DSL, dependsOn), the reference-token
/// tokenizer and the serializer.
///
/// Every exported symbol names the upstream TypeScript file it ports in its
/// doc comment (baseline commit in `docs/port/UPSTREAM_COMMIT`).
library;

export 'src/model/block_config.dart';
export 'src/model/block_data.dart';
export 'src/model/block_registry.dart';
export 'src/model/block_retry.dart';
export 'src/model/block_state.dart';
export 'src/model/condition.dart';
export 'src/model/edge.dart';
export 'src/model/output_field.dart';
export 'src/model/position.dart';
export 'src/model/sub_block_state.dart';
export 'src/model/sub_block_type.dart';
export 'src/model/subflow.dart';
export 'src/model/variable.dart';
export 'src/model/workflow_state.dart';
export 'src/rules/block_names.dart';
export 'src/rules/canonical.dart';
export 'src/rules/condition.dart';
export 'src/rules/depends_on.dart';
export 'src/rules/dimensions.dart';
export 'src/rules/edge_rules.dart';
export 'src/rules/environment.dart';
export 'src/rules/handles.dart';
export 'src/rules/locks.dart';
export 'src/rules/merge_subblock_state.dart';
export 'src/rules/subflow_helpers.dart';
export 'src/serializer/serialized_types.dart';
export 'src/serializer/serializer.dart';
export 'src/text/reference_tokens.dart';
