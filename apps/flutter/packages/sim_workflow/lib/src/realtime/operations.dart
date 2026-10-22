/// The `workflow-operation` vocabulary.
///
/// Port of `packages/realtime-protocol/src/constants.ts` (names) and
/// `schemas.ts` (payload shapes). Every operation keeps its wire payload as a
/// [JsonMap] so unknown keys the editor adds (`isUndo`, `originalOpId`, ...)
/// survive a round trip byte-for-byte; the typed constructors and getters are
/// views over that map, and [WorkflowOperation.fromJson] validates the shape
/// the server's zod schema requires.
library;

import 'package:meta/meta.dart';
import 'package:sim_workflow/src/realtime/json.dart';

/// The `target` values of a workflow operation.
abstract final class OperationTargets {
  /// A single block.
  static const String block = 'block';

  /// Several blocks.
  static const String blocks = 'blocks';

  /// A single edge.
  static const String edge = 'edge';

  /// Several edges.
  static const String edges = 'edges';

  /// A subblock value.
  static const String subblock = 'subblock';

  /// A loop or parallel container.
  static const String subflow = 'subflow';

  /// A workflow variable.
  static const String variable = 'variable';

  /// The whole workflow.
  static const String workflow = 'workflow';

  /// Every target, in constants.ts order.
  static const List<String> all = [
    block,
    blocks,
    edge,
    edges,
    subblock,
    subflow,
    variable,
    workflow,
  ];
}

/// Operation names for [OperationTargets.block].
abstract final class BlockOperations {
  /// Moves a block (per-frame when `commit` is false).
  static const String updatePosition = 'update-position';

  /// Renames a block.
  static const String updateName = 'update-name';

  /// Flips a block's enabled flag.
  static const String toggleEnabled = 'toggle-enabled';

  /// Re-parents a block into or out of a container.
  static const String updateParent = 'update-parent';

  /// Switches a block's advanced mode.
  static const String updateAdvancedMode = 'update-advanced-mode';

  /// Switches a block's error-output handle.
  static const String updateErrorEnabled = 'update-error-enabled';

  /// Replaces a block's retry policy.
  static const String updateRetry = 'update-retry';

  /// Sets one canonical field's basic/advanced mode.
  static const String updateCanonicalMode = 'update-canonical-mode';

  /// No longer sent by the editor; still accepted across a rolling deploy.
  static const String replaceCanonicalModes = 'replace-canonical-modes';

  /// Flips a block's horizontal-handles flag.
  static const String toggleHandles = 'toggle-handles';

  /// Every block operation name.
  static const List<String> all = [
    updatePosition,
    updateName,
    toggleEnabled,
    updateParent,
    updateAdvancedMode,
    updateErrorEnabled,
    updateRetry,
    updateCanonicalMode,
    replaceCanonicalModes,
    toggleHandles,
  ];
}

/// Operation names for [OperationTargets.blocks].
abstract final class BlocksOperations {
  /// Commits several block positions at once.
  static const String batchUpdatePositions = 'batch-update-positions';

  /// Adds blocks together with their edges, subflows and values.
  static const String batchAddBlocks = 'batch-add-blocks';

  /// Removes several blocks.
  static const String batchRemoveBlocks = 'batch-remove-blocks';

  /// Flips several blocks' enabled flag.
  static const String batchToggleEnabled = 'batch-toggle-enabled';

  /// Flips several blocks' horizontal-handles flag.
  static const String batchToggleHandles = 'batch-toggle-handles';

  /// Re-parents several blocks.
  static const String batchUpdateParent = 'batch-update-parent';

  /// Flips several blocks' locked flag.
  static const String batchToggleLocked = 'batch-toggle-locked';

  /// Every blocks operation name.
  static const List<String> all = [
    batchUpdatePositions,
    batchAddBlocks,
    batchRemoveBlocks,
    batchToggleEnabled,
    batchToggleHandles,
    batchUpdateParent,
    batchToggleLocked,
  ];
}

/// Operation names for [OperationTargets.edge].
abstract final class EdgeOperations {
  /// Adds one edge.
  static const String add = 'add';

  /// Removes one edge.
  static const String remove = 'remove';

  /// Every edge operation name.
  static const List<String> all = [add, remove];
}

/// Operation names for [OperationTargets.edges].
abstract final class EdgesOperations {
  /// Adds several edges.
  static const String batchAddEdges = 'batch-add-edges';

  /// Removes several edges.
  static const String batchRemoveEdges = 'batch-remove-edges';

  /// Every edges operation name.
  static const List<String> all = [batchAddEdges, batchRemoveEdges];
}

/// Operation names for [OperationTargets.subflow].
abstract final class SubflowOperations {
  /// Replaces a loop or parallel configuration.
  static const String update = 'update';

  /// Every subflow operation name.
  static const List<String> all = [update];
}

/// Operation names for [OperationTargets.variable].
abstract final class VariableOperations {
  /// Adds a variable.
  static const String add = 'add';

  /// Removes a variable.
  static const String remove = 'remove';

  /// Updates one field of a variable (sent over the `variable-update` event).
  static const String update = 'variable-update';

  /// Every variable operation name.
  static const List<String> all = [add, remove, update];
}

/// Operation names for [OperationTargets.workflow].
abstract final class WorkflowOperations {
  /// Replaces the whole workflow state.
  static const String replaceState = 'replace-state';

  /// Every workflow operation name.
  static const List<String> all = [replaceState];
}

/// Operation names for [OperationTargets.subblock].
abstract final class SubblockOperations {
  /// Writes one subblock value (sent over the `subblock-update` event).
  static const String update = 'subblock-update';

  /// Writes several subblock values in one transaction.
  static const String batchUpdate = 'subblock-batch-update';

  /// Writes one value and its block's canonical modes together.
  static const String updateWithCanonicalModes =
      'subblock-update-with-canonical-modes';

  /// Every subblock operation name.
  static const List<String> all = [
    update,
    batchUpdate,
    updateWithCanonicalModes,
  ];
}

/// All socket operations that require permission checks, in constants.ts
/// order (`ALL_SOCKET_OPERATIONS`).
const List<String> allSocketOperations = [
  ...BlockOperations.all,
  ...BlocksOperations.all,
  ...EdgeOperations.all,
  ...EdgesOperations.all,
  ...WorkflowOperations.all,
  ...SubblockOperations.all,
  ...VariableOperations.all,
  ...SubflowOperations.all,
];

/// A canvas position.
@immutable
class Position {
  /// Creates a position at ([x], [y]).
  const Position(this.x, this.y);

  /// Decodes `{x, y}`.
  factory Position.fromJson(JsonMap json) =>
      Position(readNum(json, 'x'), readNum(json, 'y'));

  /// Horizontal coordinate.
  final num x;

  /// Vertical coordinate.
  final num y;

  /// Encodes as `{x, y}`.
  JsonMap toJson() => {'x': x, 'y': y};

  @override
  bool operator ==(Object other) =>
      other is Position && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// A block's retry policy (`BlockRetrySchema`).
class BlockRetry {
  /// Creates a retry policy.
  const BlockRetry({
    required this.enabled,
    required this.maxTries,
    required this.waitBetweenTriesMs,
  });

  /// Decodes `{enabled, maxTries, waitBetweenTriesMs}`.
  factory BlockRetry.fromJson(JsonMap json) => BlockRetry(
    enabled: readBool(json, 'enabled'),
    maxTries: readInt(json, 'maxTries'),
    waitBetweenTriesMs: readInt(json, 'waitBetweenTriesMs'),
  );

  /// Whether retries are on.
  final bool enabled;

  /// Maximum attempts.
  final int maxTries;

  /// Delay between attempts.
  final int waitBetweenTriesMs;

  /// Encodes the policy.
  JsonMap toJson() => {
    'enabled': enabled,
    'maxTries': maxTries,
    'waitBetweenTriesMs': waitBetweenTriesMs,
  };
}

/// Basic/advanced mode of a canonical field.
enum CanonicalMode {
  /// The simple editor.
  basic('basic'),

  /// The expression editor.
  advanced('advanced')
  ;

  const CanonicalMode(this.wire);

  /// The wire token.
  final String wire;

  /// Resolves a wire token or throws [ProtocolFormatException].
  static CanonicalMode fromWire(String value) {
    for (final mode in values) {
      if (mode.wire == value) return mode;
    }
    throw ProtocolFormatException('unknown canonical mode', payload: value);
  }
}

/// An edge as carried by `batch-add-edges` and `batch-add-blocks`.
class EdgeData {
  /// Creates an edge between [source] and [target].
  const EdgeData({
    required this.id,
    required this.source,
    required this.target,
    this.sourceHandle,
    this.targetHandle,
    this.type,
    this.extra = const {},
  });

  /// Decodes an edge, keeping unknown keys in [extra].
  factory EdgeData.fromJson(JsonMap json) => EdgeData(
    id: readString(json, 'id'),
    source: readString(json, 'source'),
    target: readString(json, 'target'),
    sourceHandle: readOptionalString(json, 'sourceHandle'),
    targetHandle: readOptionalString(json, 'targetHandle'),
    type: readOptionalString(json, 'type'),
    extra: {
      for (final entry in json.entries)
        if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
    },
  );

  static const Set<String> _knownKeys = {
    'id',
    'source',
    'target',
    'sourceHandle',
    'targetHandle',
    'type',
  };

  /// The edge id.
  final String id;

  /// The source block id.
  final String source;

  /// The target block id.
  final String target;

  /// The source handle id.
  final String? sourceHandle;

  /// The target handle id.
  final String? targetHandle;

  /// The edge type, when set.
  final String? type;

  /// Keys the client does not model.
  final JsonMap extra;

  /// Encodes the edge. Handles are emitted as `null` when unset, which is what
  /// the editor sends for a default handle.
  JsonMap toJson() => {
    ...extra,
    'id': id,
    'source': source,
    'target': target,
    'sourceHandle': sourceHandle,
    'targetHandle': targetHandle,
    'type': ?type,
  };
}

/// One subblock write inside `subblock-batch-update`.
class SubblockValueUpdate {
  /// Creates a write of [value] to [blockId].[subblockId].
  const SubblockValueUpdate({
    required this.blockId,
    required this.subblockId,
    required this.value,
    this.expectedValue,
    this.hasExpectedValue = false,
  });

  /// Decodes `{blockId, subblockId, value, expectedValue?}`.
  factory SubblockValueUpdate.fromJson(JsonMap json) => SubblockValueUpdate(
    blockId: readString(json, 'blockId'),
    subblockId: readString(json, 'subblockId'),
    value: json['value'],
    expectedValue: json['expectedValue'],
    hasExpectedValue: json.containsKey('expectedValue'),
  );

  /// The block.
  final String blockId;

  /// The subblock.
  final String subblockId;

  /// The new value.
  final Object? value;

  /// The value the writer expects to replace (optimistic conflict check).
  final Object? expectedValue;

  /// Whether [expectedValue] is part of the payload.
  final bool hasExpectedValue;

  /// Encodes the write.
  JsonMap toJson() => {
    'blockId': blockId,
    'subblockId': subblockId,
    'value': value,
    if (hasExpectedValue) 'expectedValue': expectedValue,
  };
}

JsonMap _withId(String id, JsonMap fields, JsonMap extra) => {
  ...extra,
  'id': id,
  ...fields,
};

/// One operation of the `workflow-operation` vocabulary.
sealed class WorkflowOperation {
  const WorkflowOperation(this.payload);

  /// Decodes `{operation, target, payload}`.
  ///
  /// Unknown `operation`/`target` pairs decode to [UnknownWorkflowOperation];
  /// a known pair with a malformed payload throws [ProtocolFormatException].
  factory WorkflowOperation.fromJson(JsonMap json) =>
      WorkflowOperation.fromParts(
        operation: readString(json, 'operation'),
        target: readString(json, 'target'),
        payload: readMap(json, 'payload'),
      );

  /// Builds the typed operation for an `operation`/`target` pair.
  factory WorkflowOperation.fromParts({
    required String operation,
    required String target,
    required JsonMap payload,
  }) {
    switch (target) {
      case OperationTargets.block:
        return BlockOperation._decode(operation, payload);
      case OperationTargets.blocks:
        return BlocksOperation._decode(operation, payload);
      case OperationTargets.edge:
        return EdgeOperation._decode(operation, payload);
      case OperationTargets.edges:
        return EdgesOperation._decode(operation, payload);
      case OperationTargets.subblock:
        return SubblockOperation._decode(operation, payload);
      case OperationTargets.subflow:
        return SubflowOperation._decode(operation, payload);
      case OperationTargets.variable:
        return VariableOperation._decode(operation, payload);
      case OperationTargets.workflow:
        return WorkflowStateOperation._decode(operation, payload);
      default:
        return UnknownWorkflowOperation(
          operation: operation,
          target: target,
          payload: payload,
        );
    }
  }

  /// The wire payload.
  final JsonMap payload;

  /// The `operation` name.
  String get operation;

  /// The `target` name.
  String get target;

  /// Encodes as `{operation, target, payload}`.
  JsonMap toJson() => {
    'operation': operation,
    'target': target,
    'payload': payload,
  };

  @override
  String toString() => 'WorkflowOperation($operation on $target)';
}

/// An operation the client does not model, carried opaquely.
final class UnknownWorkflowOperation extends WorkflowOperation {
  /// Creates an opaque operation.
  const UnknownWorkflowOperation({
    required this.operation,
    required this.target,
    required JsonMap payload,
  }) : super(payload);

  @override
  final String operation;

  @override
  final String target;
}

/// Operations on a single block (`BlockOperationSchema`).
sealed class BlockOperation extends WorkflowOperation {
  const BlockOperation(super.payload);

  static WorkflowOperation _decode(String operation, JsonMap payload) {
    if (!BlockOperations.all.contains(operation)) {
      return UnknownWorkflowOperation(
        operation: operation,
        target: OperationTargets.block,
        payload: payload,
      );
    }
    readString(payload, 'id');
    if (payload['position'] case final Object position) {
      Position.fromJson(asJsonMap(position, path: 'position'));
    }
    readOptionalBool(payload, 'commit');
    readOptionalString(payload, 'name');
    readOptionalString(payload, 'parentId');
    readOptionalBool(payload, 'enabled');
    readOptionalBool(payload, 'advancedMode');
    readOptionalBool(payload, 'errorEnabled');
    readOptionalBool(payload, 'horizontalHandles');
    readOptionalBool(payload, 'triggerMode');
    readOptionalString(payload, 'canonicalId');
    if (payload['canonicalMode'] case final String mode) {
      CanonicalMode.fromWire(mode);
    }
    if (payload['retry'] case final Object retry) {
      BlockRetry.fromJson(asJsonMap(retry, path: 'retry'));
    }
    return switch (operation) {
      BlockOperations.updatePosition => UpdatePositionOperation._(payload),
      BlockOperations.updateName => UpdateNameOperation._(payload),
      BlockOperations.toggleEnabled => ToggleEnabledOperation._(payload),
      BlockOperations.updateParent => UpdateParentOperation._(payload),
      BlockOperations.updateAdvancedMode => UpdateAdvancedModeOperation._(
        payload,
      ),
      BlockOperations.updateErrorEnabled => UpdateErrorEnabledOperation._(
        payload,
      ),
      BlockOperations.updateRetry => UpdateRetryOperation._(payload),
      BlockOperations.updateCanonicalMode => UpdateCanonicalModeOperation._(
        payload,
      ),
      BlockOperations.replaceCanonicalModes => ReplaceCanonicalModesOperation._(
        payload,
      ),
      _ => ToggleHandlesOperation._(payload),
    };
  }

  @override
  String get target => OperationTargets.block;

  /// The block id.
  String get id => payload['id']! as String;
}

/// `update-position`: a move, committed or per-frame.
final class UpdatePositionOperation extends BlockOperation {
  /// Creates a move of block [id] to [position]. An uncommitted move
  /// (`commit: false`) is coalesced on the 33 ms timer and never persisted.
  UpdatePositionOperation({
    required String id,
    required Position position,
    bool? commit,
    JsonMap extra = const {},
  }) : super(
         _withId(id, {
           'position': position.toJson(),
           'commit': ?commit,
         }, extra),
       );

  const UpdatePositionOperation._(super.payload);

  @override
  String get operation => BlockOperations.updatePosition;

  /// The new position.
  Position get position => Position.fromJson(payload['position']! as JsonMap);

  /// Whether the move persists; absent means `true` (the server default).
  bool get commit => payload['commit'] as bool? ?? true;
}

/// `update-name`.
final class UpdateNameOperation extends BlockOperation {
  /// Renames block [id] to [name].
  UpdateNameOperation({
    required String id,
    required String name,
    JsonMap extra = const {},
  }) : super(_withId(id, {'name': name}, extra));

  const UpdateNameOperation._(super.payload);

  @override
  String get operation => BlockOperations.updateName;

  /// The new name.
  String get name => payload['name']! as String;
}

/// `toggle-enabled`.
final class ToggleEnabledOperation extends BlockOperation {
  /// Flips block [id]; [enabled] carries the resulting state when known.
  ToggleEnabledOperation({
    required String id,
    bool? enabled,
    JsonMap extra = const {},
  }) : super(_withId(id, {'enabled': ?enabled}, extra));

  const ToggleEnabledOperation._(super.payload);

  @override
  String get operation => BlockOperations.toggleEnabled;

  /// The resulting enabled state, when carried.
  bool? get enabled => payload['enabled'] as bool?;
}

/// `update-parent`.
final class UpdateParentOperation extends BlockOperation {
  /// Moves block [id] under [parentId] (`''` for the canvas root).
  UpdateParentOperation({
    required String id,
    required String parentId,
    String? extent = 'parent',
    Position? position,
    JsonMap extra = const {},
  }) : super(
         _withId(id, {
           'parentId': parentId,
           'extent': extent,
           'position': ?position?.toJson(),
         }, extra),
       );

  const UpdateParentOperation._(super.payload);

  @override
  String get operation => BlockOperations.updateParent;

  /// The new parent id (`''` or `null` for the canvas root).
  String? get parentId => payload['parentId'] as String?;

  /// The extent constraint (`'parent'` or `null`).
  String? get extent => payload['extent'] as String?;

  /// The position inside the new parent, when carried.
  Position? get position => switch (payload['position']) {
    final JsonMap map => Position.fromJson(map),
    _ => null,
  };
}

/// `update-advanced-mode`.
final class UpdateAdvancedModeOperation extends BlockOperation {
  /// Sets block [id]'s advanced mode.
  UpdateAdvancedModeOperation({
    required String id,
    required bool advancedMode,
    JsonMap extra = const {},
  }) : super(_withId(id, {'advancedMode': advancedMode}, extra));

  const UpdateAdvancedModeOperation._(super.payload);

  @override
  String get operation => BlockOperations.updateAdvancedMode;

  /// The new advanced mode.
  bool get advancedMode => payload['advancedMode']! as bool;
}

/// `update-error-enabled`.
final class UpdateErrorEnabledOperation extends BlockOperation {
  /// Sets block [id]'s error handle.
  UpdateErrorEnabledOperation({
    required String id,
    required bool errorEnabled,
    JsonMap extra = const {},
  }) : super(_withId(id, {'errorEnabled': errorEnabled}, extra));

  const UpdateErrorEnabledOperation._(super.payload);

  @override
  String get operation => BlockOperations.updateErrorEnabled;

  /// Whether the error handle is on.
  bool get errorEnabled => payload['errorEnabled']! as bool;
}

/// `update-retry`.
final class UpdateRetryOperation extends BlockOperation {
  /// Replaces block [id]'s retry policy.
  UpdateRetryOperation({
    required String id,
    required BlockRetry retry,
    JsonMap extra = const {},
  }) : super(_withId(id, {'retry': retry.toJson()}, extra));

  const UpdateRetryOperation._(super.payload);

  @override
  String get operation => BlockOperations.updateRetry;

  /// The new retry policy.
  BlockRetry get retry => BlockRetry.fromJson(payload['retry']! as JsonMap);
}

/// `update-canonical-mode`.
final class UpdateCanonicalModeOperation extends BlockOperation {
  /// Sets the mode of canonical field [canonicalId] on block [id].
  UpdateCanonicalModeOperation({
    required String id,
    required String canonicalId,
    required CanonicalMode canonicalMode,
    JsonMap extra = const {},
  }) : super(
         _withId(id, {
           'canonicalId': canonicalId,
           'canonicalMode': canonicalMode.wire,
         }, extra),
       );

  const UpdateCanonicalModeOperation._(super.payload);

  @override
  String get operation => BlockOperations.updateCanonicalMode;

  /// The canonical field.
  String get canonicalId => payload['canonicalId']! as String;

  /// The new mode.
  CanonicalMode get canonicalMode =>
      CanonicalMode.fromWire(payload['canonicalMode']! as String);
}

/// `replace-canonical-modes` (legacy; accepted but no longer sent).
final class ReplaceCanonicalModesOperation extends BlockOperation {
  /// Replaces every canonical mode of block [id].
  ReplaceCanonicalModesOperation({
    required String id,
    required Map<String, CanonicalMode> canonicalModes,
    JsonMap extra = const {},
  }) : super(
         _withId(id, {
           'canonicalModes': {
             for (final entry in canonicalModes.entries)
               entry.key: entry.value.wire,
           },
         }, extra),
       );

  const ReplaceCanonicalModesOperation._(super.payload);

  @override
  String get operation => BlockOperations.replaceCanonicalModes;

  /// The new modes by canonical id.
  Map<String, CanonicalMode> get canonicalModes => {
    for (final entry
        in (payload['canonicalModes'] as JsonMap? ?? const {}).entries)
      entry.key: CanonicalMode.fromWire(entry.value! as String),
  };
}

/// `toggle-handles`.
final class ToggleHandlesOperation extends BlockOperation {
  /// Flips block [id]'s handle orientation.
  ToggleHandlesOperation({
    required String id,
    bool? horizontalHandles,
    JsonMap extra = const {},
  }) : super(
         _withId(id, {
           'horizontalHandles': ?horizontalHandles,
         }, extra),
       );

  const ToggleHandlesOperation._(super.payload);

  @override
  String get operation => BlockOperations.toggleHandles;

  /// The resulting orientation, when carried.
  bool? get horizontalHandles => payload['horizontalHandles'] as bool?;
}

/// Operations on several blocks.
sealed class BlocksOperation extends WorkflowOperation {
  const BlocksOperation(super.payload);

  static WorkflowOperation _decode(String operation, JsonMap payload) {
    switch (operation) {
      case BlocksOperations.batchUpdatePositions:
        for (final update in readMapList(payload, 'updates')) {
          readString(update, 'id');
          Position.fromJson(readMap(update, 'position'));
        }
        return BatchUpdatePositionsOperation._(payload);
      case BlocksOperations.batchAddBlocks:
        readMapList(payload, 'blocks');
        for (final edge in readOptionalList(payload, 'edges') ?? const []) {
          EdgeData.fromJson(asJsonMap(edge, path: 'edges'));
        }
        readOptionalMap(payload, 'loops');
        readOptionalMap(payload, 'parallels');
        readOptionalMap(payload, 'subBlockValues');
        return BatchAddBlocksOperation._(payload);
      case BlocksOperations.batchRemoveBlocks:
        readStringList(payload, 'ids');
        return BatchRemoveBlocksOperation._(payload);
      case BlocksOperations.batchToggleEnabled:
        _validateToggle(payload);
        return BatchToggleEnabledOperation._(payload);
      case BlocksOperations.batchToggleHandles:
        _validateToggle(payload);
        return BatchToggleHandlesOperation._(payload);
      case BlocksOperations.batchToggleLocked:
        _validateToggle(payload);
        return BatchToggleLockedOperation._(payload);
      case BlocksOperations.batchUpdateParent:
        for (final update in readMapList(payload, 'updates')) {
          readString(update, 'id');
          readString(update, 'parentId');
          Position.fromJson(readMap(update, 'position'));
        }
        return BatchUpdateParentOperation._(payload);
      default:
        return UnknownWorkflowOperation(
          operation: operation,
          target: OperationTargets.blocks,
          payload: payload,
        );
    }
  }

  static void _validateToggle(JsonMap payload) {
    readStringList(payload, 'blockIds');
    for (final entry in readMap(payload, 'previousStates').entries) {
      if (entry.value is! bool) {
        throw ProtocolFormatException(
          'expected boolean',
          path: 'previousStates.${entry.key}',
          payload: payload,
        );
      }
    }
  }

  @override
  String get target => OperationTargets.blocks;
}

/// One entry of `batch-update-positions`.
class PositionUpdate {
  /// Moves block [id] to [position].
  const PositionUpdate({required this.id, required this.position});

  /// The block id.
  final String id;

  /// The committed position.
  final Position position;

  /// Encodes as `{id, position}`.
  JsonMap toJson() => {'id': id, 'position': position.toJson()};
}

/// `batch-update-positions`.
final class BatchUpdatePositionsOperation extends BlocksOperation {
  /// Commits [updates].
  BatchUpdatePositionsOperation({required List<PositionUpdate> updates})
    : super({
        'updates': [for (final update in updates) update.toJson()],
      });

  const BatchUpdatePositionsOperation._(super.payload);

  @override
  String get operation => BlocksOperations.batchUpdatePositions;

  /// The moves.
  List<PositionUpdate> get updates => [
    for (final update in payload['updates']! as List<Object?>)
      PositionUpdate(
        id: (update! as JsonMap)['id']! as String,
        position: Position.fromJson(
          (update as JsonMap)['position']! as JsonMap,
        ),
      ),
  ];
}

/// `batch-add-blocks`.
final class BatchAddBlocksOperation extends BlocksOperation {
  /// Adds [blocks] with their auto-connect [edges], subflows and values.
  BatchAddBlocksOperation({
    required List<JsonMap> blocks,
    List<EdgeData>? edges,
    JsonMap? loops,
    JsonMap? parallels,
    Map<String, JsonMap>? subBlockValues,
  }) : super({
         'blocks': blocks,
         if (edges != null) 'edges': [for (final e in edges) e.toJson()],
         'loops': ?loops,
         'parallels': ?parallels,
         'subBlockValues': ?subBlockValues,
       });

  const BatchAddBlocksOperation._(super.payload);

  @override
  String get operation => BlocksOperations.batchAddBlocks;

  /// The block records.
  List<JsonMap> get blocks => [
    for (final block in payload['blocks']! as List<Object?>) block! as JsonMap,
  ];

  /// The auto-connect edges.
  List<EdgeData> get edges => [
    for (final edge in payload['edges'] as List<Object?>? ?? const [])
      EdgeData.fromJson(edge! as JsonMap),
  ];

  /// The loop configurations by id.
  JsonMap get loops => payload['loops'] as JsonMap? ?? const {};

  /// The parallel configurations by id.
  JsonMap get parallels => payload['parallels'] as JsonMap? ?? const {};

  /// Subblock values by block id.
  JsonMap get subBlockValues =>
      payload['subBlockValues'] as JsonMap? ?? const {};
}

/// `batch-remove-blocks`.
final class BatchRemoveBlocksOperation extends BlocksOperation {
  /// Removes [ids].
  BatchRemoveBlocksOperation({required List<String> ids}) : super({'ids': ids});

  const BatchRemoveBlocksOperation._(super.payload);

  @override
  String get operation => BlocksOperations.batchRemoveBlocks;

  /// The removed block ids.
  List<String> get ids => [
    for (final id in payload['ids']! as List<Object?>) id! as String,
  ];
}

/// Shared shape of the batch toggle operations.
sealed class BatchToggleOperation extends BlocksOperation {
  const BatchToggleOperation(super.payload);

  static JsonMap _payload(List<String> blockIds, Map<String, bool> previous) =>
      {'blockIds': blockIds, 'previousStates': previous};

  /// The toggled block ids.
  List<String> get blockIds => [
    for (final id in payload['blockIds']! as List<Object?>) id! as String,
  ];

  /// Each block's state before the toggle (for undo).
  Map<String, bool> get previousStates => {
    for (final entry in (payload['previousStates']! as JsonMap).entries)
      entry.key: entry.value! as bool,
  };
}

/// `batch-toggle-enabled`.
final class BatchToggleEnabledOperation extends BatchToggleOperation {
  /// Flips [blockIds], remembering [previousStates].
  BatchToggleEnabledOperation({
    required List<String> blockIds,
    required Map<String, bool> previousStates,
  }) : super(BatchToggleOperation._payload(blockIds, previousStates));

  const BatchToggleEnabledOperation._(super.payload);

  @override
  String get operation => BlocksOperations.batchToggleEnabled;
}

/// `batch-toggle-handles`.
final class BatchToggleHandlesOperation extends BatchToggleOperation {
  /// Flips [blockIds], remembering [previousStates].
  BatchToggleHandlesOperation({
    required List<String> blockIds,
    required Map<String, bool> previousStates,
  }) : super(BatchToggleOperation._payload(blockIds, previousStates));

  const BatchToggleHandlesOperation._(super.payload);

  @override
  String get operation => BlocksOperations.batchToggleHandles;
}

/// `batch-toggle-locked`.
final class BatchToggleLockedOperation extends BatchToggleOperation {
  /// Flips [blockIds], remembering [previousStates].
  BatchToggleLockedOperation({
    required List<String> blockIds,
    required Map<String, bool> previousStates,
  }) : super(BatchToggleOperation._payload(blockIds, previousStates));

  const BatchToggleLockedOperation._(super.payload);

  @override
  String get operation => BlocksOperations.batchToggleLocked;
}

/// One entry of `batch-update-parent`.
class ParentUpdate {
  /// Moves block [id] under [parentId] at [position].
  const ParentUpdate({
    required this.id,
    required this.parentId,
    required this.position,
  });

  /// The block id.
  final String id;

  /// The new parent id.
  final String parentId;

  /// The position inside the new parent.
  final Position position;

  /// Encodes as `{id, parentId, position}`.
  JsonMap toJson() => {
    'id': id,
    'parentId': parentId,
    'position': position.toJson(),
  };
}

/// `batch-update-parent`.
final class BatchUpdateParentOperation extends BlocksOperation {
  /// Re-parents [updates].
  BatchUpdateParentOperation({required List<ParentUpdate> updates})
    : super({
        'updates': [for (final update in updates) update.toJson()],
      });

  const BatchUpdateParentOperation._(super.payload);

  @override
  String get operation => BlocksOperations.batchUpdateParent;

  /// The re-parent entries.
  List<ParentUpdate> get updates => [
    for (final update in payload['updates']! as List<Object?>)
      ParentUpdate(
        id: (update! as JsonMap)['id']! as String,
        parentId: (update as JsonMap)['parentId']! as String,
        position: Position.fromJson(update['position']! as JsonMap),
      ),
  ];
}

/// Operations on a single edge (`EdgeOperationSchema`).
sealed class EdgeOperation extends WorkflowOperation {
  const EdgeOperation(super.payload);

  static WorkflowOperation _decode(String operation, JsonMap payload) {
    if (!EdgeOperations.all.contains(operation)) {
      return UnknownWorkflowOperation(
        operation: operation,
        target: OperationTargets.edge,
        payload: payload,
      );
    }
    readString(payload, 'id');
    readOptionalString(payload, 'source');
    readOptionalString(payload, 'target');
    readOptionalString(payload, 'sourceHandle');
    readOptionalString(payload, 'targetHandle');
    return operation == EdgeOperations.add
        ? AddEdgeOperation._(payload)
        : RemoveEdgeOperation._(payload);
  }

  static JsonMap _payload({
    required String id,
    required String? source,
    required String? target,
    required String? sourceHandle,
    required String? targetHandle,
    required bool includeHandles,
  }) => {
    'id': id,
    'source': ?source,
    'target': ?target,
    if (includeHandles) 'sourceHandle': sourceHandle,
    if (includeHandles) 'targetHandle': targetHandle,
  };

  @override
  String get target => OperationTargets.edge;

  /// The edge id.
  String get id => payload['id']! as String;

  /// The source block id, when carried.
  String? get source => payload['source'] as String?;

  /// The target block id, when carried.
  String? get targetBlockId => payload['target'] as String?;

  /// The source handle, when carried.
  String? get sourceHandle => payload['sourceHandle'] as String?;

  /// The target handle, when carried.
  String? get targetHandle => payload['targetHandle'] as String?;
}

/// `add` on an edge.
final class AddEdgeOperation extends EdgeOperation {
  /// Adds edge [id] from [source] to [target].
  AddEdgeOperation({
    required String id,
    required String source,
    required String target,
    String? sourceHandle,
    String? targetHandle,
  }) : super(
         EdgeOperation._payload(
           id: id,
           source: source,
           target: target,
           sourceHandle: sourceHandle,
           targetHandle: targetHandle,
           includeHandles: true,
         ),
       );

  const AddEdgeOperation._(super.payload);

  @override
  String get operation => EdgeOperations.add;
}

/// `remove` on an edge.
final class RemoveEdgeOperation extends EdgeOperation {
  /// Removes edge [id].
  RemoveEdgeOperation({required String id})
    : super(
        EdgeOperation._payload(
          id: id,
          source: null,
          target: null,
          sourceHandle: null,
          targetHandle: null,
          includeHandles: false,
        ),
      );

  const RemoveEdgeOperation._(super.payload);

  @override
  String get operation => EdgeOperations.remove;
}

/// Operations on several edges.
sealed class EdgesOperation extends WorkflowOperation {
  const EdgesOperation(super.payload);

  static WorkflowOperation _decode(String operation, JsonMap payload) {
    switch (operation) {
      case EdgesOperations.batchAddEdges:
        for (final edge in readMapList(payload, 'edges')) {
          EdgeData.fromJson(edge);
        }
        return BatchAddEdgesOperation._(payload);
      case EdgesOperations.batchRemoveEdges:
        readStringList(payload, 'ids');
        return BatchRemoveEdgesOperation._(payload);
      default:
        return UnknownWorkflowOperation(
          operation: operation,
          target: OperationTargets.edges,
          payload: payload,
        );
    }
  }

  @override
  String get target => OperationTargets.edges;
}

/// `batch-add-edges`.
final class BatchAddEdgesOperation extends EdgesOperation {
  /// Adds [edges].
  BatchAddEdgesOperation({required List<EdgeData> edges})
    : super({
        'edges': [for (final edge in edges) edge.toJson()],
      });

  const BatchAddEdgesOperation._(super.payload);

  @override
  String get operation => EdgesOperations.batchAddEdges;

  /// The added edges.
  List<EdgeData> get edges => [
    for (final edge in payload['edges']! as List<Object?>)
      EdgeData.fromJson(edge! as JsonMap),
  ];
}

/// `batch-remove-edges`.
final class BatchRemoveEdgesOperation extends EdgesOperation {
  /// Removes [ids].
  BatchRemoveEdgesOperation({required List<String> ids}) : super({'ids': ids});

  const BatchRemoveEdgesOperation._(super.payload);

  @override
  String get operation => EdgesOperations.batchRemoveEdges;

  /// The removed edge ids.
  List<String> get ids => [
    for (final id in payload['ids']! as List<Object?>) id! as String,
  ];
}

/// Operations on subblock values.
sealed class SubblockOperation extends WorkflowOperation {
  const SubblockOperation(super.payload);

  static WorkflowOperation _decode(String operation, JsonMap payload) {
    switch (operation) {
      case SubblockOperations.update:
        readString(payload, 'blockId');
        readString(payload, 'subblockId');
        return SubblockUpdateOperation._(payload);
      case SubblockOperations.batchUpdate:
        for (final update in readMapList(payload, 'updates')) {
          SubblockValueUpdate.fromJson(update);
        }
        return SubblockBatchUpdateOperation._(payload);
      case SubblockOperations.updateWithCanonicalModes:
        readString(payload, 'blockId');
        readString(payload, 'subblockId');
        for (final entry in readMap(payload, 'canonicalModes').entries) {
          if (entry.value is! String) {
            throw ProtocolFormatException(
              'expected string',
              path: 'canonicalModes.${entry.key}',
              payload: payload,
            );
          }
          CanonicalMode.fromWire(entry.value! as String);
        }
        return SubblockUpdateWithCanonicalModesOperation._(payload);
      default:
        return UnknownWorkflowOperation(
          operation: operation,
          target: OperationTargets.subblock,
          payload: payload,
        );
    }
  }

  @override
  String get target => OperationTargets.subblock;
}

/// `subblock-update`: one value write, emitted over the `subblock-update`
/// socket event (not `workflow-operation`) and debounced 25 ms server-side.
final class SubblockUpdateOperation extends SubblockOperation {
  /// Writes [value] to [blockId].[subblockId].
  SubblockUpdateOperation({
    required String blockId,
    required String subblockId,
    required Object? value,
  }) : super({'blockId': blockId, 'subblockId': subblockId, 'value': value});

  const SubblockUpdateOperation._(super.payload);

  @override
  String get operation => SubblockOperations.update;

  /// The block.
  String get blockId => payload['blockId']! as String;

  /// The subblock.
  String get subblockId => payload['subblockId']! as String;

  /// The new value.
  Object? get value => payload['value'];
}

/// `subblock-batch-update`.
final class SubblockBatchUpdateOperation extends SubblockOperation {
  /// Writes [updates] in one transaction.
  SubblockBatchUpdateOperation({required List<SubblockValueUpdate> updates})
    : super({
        'updates': [for (final update in updates) update.toJson()],
      });

  const SubblockBatchUpdateOperation._(super.payload);

  @override
  String get operation => SubblockOperations.batchUpdate;

  /// The writes.
  List<SubblockValueUpdate> get updates => [
    for (final update in payload['updates']! as List<Object?>)
      SubblockValueUpdate.fromJson(update! as JsonMap),
  ];
}

/// `subblock-update-with-canonical-modes`.
final class SubblockUpdateWithCanonicalModesOperation
    extends SubblockOperation {
  /// Writes [value] and replaces the block's [canonicalModes] together.
  SubblockUpdateWithCanonicalModesOperation({
    required String blockId,
    required String subblockId,
    required Object? value,
    required Map<String, CanonicalMode> canonicalModes,
  }) : super({
         'blockId': blockId,
         'subblockId': subblockId,
         'value': value,
         'canonicalModes': {
           for (final entry in canonicalModes.entries)
             entry.key: entry.value.wire,
         },
       });

  const SubblockUpdateWithCanonicalModesOperation._(super.payload);

  @override
  String get operation => SubblockOperations.updateWithCanonicalModes;

  /// The block.
  String get blockId => payload['blockId']! as String;

  /// The subblock.
  String get subblockId => payload['subblockId']! as String;

  /// The new value.
  Object? get value => payload['value'];

  /// The new modes by canonical id.
  Map<String, CanonicalMode> get canonicalModes => {
    for (final entry in (payload['canonicalModes']! as JsonMap).entries)
      entry.key: CanonicalMode.fromWire(entry.value! as String),
  };
}

/// Operations on a loop or parallel container.
sealed class SubflowOperation extends WorkflowOperation {
  const SubflowOperation(super.payload);

  static WorkflowOperation _decode(String operation, JsonMap payload) {
    if (operation != SubflowOperations.update) {
      return UnknownWorkflowOperation(
        operation: operation,
        target: OperationTargets.subflow,
        payload: payload,
      );
    }
    readString(payload, 'id');
    final type = readOptionalString(payload, 'type');
    if (type != null && type != 'loop' && type != 'parallel') {
      throw ProtocolFormatException(
        'expected loop or parallel',
        path: 'type',
        payload: payload,
      );
    }
    readOptionalMap(payload, 'config');
    return SubflowUpdateOperation._(payload);
  }

  @override
  String get target => OperationTargets.subflow;
}

/// `update` on a subflow.
final class SubflowUpdateOperation extends SubflowOperation {
  /// Replaces container [id]'s [config]; [type] is `loop` or `parallel`.
  SubflowUpdateOperation({
    required String id,
    String? type,
    JsonMap? config,
  }) : super({
         'id': id,
         'type': ?type,
         'config': ?config,
       });

  const SubflowUpdateOperation._(super.payload);

  @override
  String get operation => SubflowOperations.update;

  /// The container id.
  String get id => payload['id']! as String;

  /// `loop` or `parallel`, when carried.
  String? get type => payload['type'] as String?;

  /// The new configuration, when carried.
  JsonMap? get config => payload['config'] as JsonMap?;
}

/// Operations on workflow variables.
sealed class VariableOperation extends WorkflowOperation {
  const VariableOperation(super.payload);

  static WorkflowOperation _decode(String operation, JsonMap payload) {
    switch (operation) {
      case VariableOperations.add:
        readString(payload, 'id');
        readString(payload, 'name');
        readString(payload, 'workflowId');
        return AddVariableOperation._(payload);
      case VariableOperations.remove:
        readString(payload, 'variableId');
        return RemoveVariableOperation._(payload);
      case VariableOperations.update:
        readString(payload, 'variableId');
        readString(payload, 'field');
        return VariableUpdateOperation._(payload);
      default:
        return UnknownWorkflowOperation(
          operation: operation,
          target: OperationTargets.variable,
          payload: payload,
        );
    }
  }

  @override
  String get target => OperationTargets.variable;
}

/// `add` on a variable.
final class AddVariableOperation extends VariableOperation {
  /// Adds variable [id].
  AddVariableOperation({
    required String id,
    required String name,
    required Object? type,
    required Object? value,
    required String workflowId,
    JsonMap extra = const {},
  }) : super({
         ...extra,
         'id': id,
         'name': name,
         'type': type,
         'value': value,
         'workflowId': workflowId,
       });

  const AddVariableOperation._(super.payload);

  @override
  String get operation => VariableOperations.add;

  /// The variable id.
  String get id => payload['id']! as String;

  /// The variable name.
  String get name => payload['name']! as String;

  /// The variable type token.
  Object? get type => payload['type'];

  /// The initial value.
  Object? get value => payload['value'];

  /// The owning workflow.
  String get workflowId => payload['workflowId']! as String;
}

/// `remove` on a variable.
final class RemoveVariableOperation extends VariableOperation {
  /// Removes [variableId].
  RemoveVariableOperation({required String variableId})
    : super({'variableId': variableId});

  const RemoveVariableOperation._(super.payload);

  @override
  String get operation => VariableOperations.remove;

  /// The removed variable id.
  String get variableId => payload['variableId']! as String;
}

/// `variable-update`: one field write, emitted over the `variable-update`
/// socket event (not `workflow-operation`) and debounced server-side.
final class VariableUpdateOperation extends VariableOperation {
  /// Writes [value] to [field] (`name`, `value` or `type`) of [variableId].
  VariableUpdateOperation({
    required String variableId,
    required String field,
    required Object? value,
  }) : super({'variableId': variableId, 'field': field, 'value': value});

  const VariableUpdateOperation._(super.payload);

  @override
  String get operation => VariableOperations.update;

  /// The variable.
  String get variableId => payload['variableId']! as String;

  /// The written field.
  String get field => payload['field']! as String;

  /// The new value.
  Object? get value => payload['value'];
}

/// Operations on the whole workflow.
sealed class WorkflowStateOperation extends WorkflowOperation {
  const WorkflowStateOperation(super.payload);

  static WorkflowOperation _decode(String operation, JsonMap payload) {
    if (operation != WorkflowOperations.replaceState) {
      return UnknownWorkflowOperation(
        operation: operation,
        target: OperationTargets.workflow,
        payload: payload,
      );
    }
    if (!payload.containsKey('state')) {
      throw ProtocolFormatException(
        'expected state',
        path: 'state',
        payload: payload,
      );
    }
    return ReplaceStateOperation._(payload);
  }

  @override
  String get target => OperationTargets.workflow;
}

/// `replace-state`.
final class ReplaceStateOperation extends WorkflowStateOperation {
  /// Replaces the workflow with [state].
  ReplaceStateOperation({required Object? state}) : super({'state': state});

  const ReplaceStateOperation._(super.payload);

  @override
  String get operation => WorkflowOperations.replaceState;

  /// The full workflow state.
  Object? get state => payload['state'];
}
