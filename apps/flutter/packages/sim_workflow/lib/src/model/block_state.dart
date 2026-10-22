import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/block_data.dart';
import 'package:sim_workflow/src/model/block_retry.dart';
import 'package:sim_workflow/src/model/json.dart';
import 'package:sim_workflow/src/model/position.dart';
import 'package:sim_workflow/src/model/sub_block_state.dart';

/// Port of `BlockLayoutState` from `packages/workflow-types/src/workflow.ts`.
@immutable
class BlockLayoutState {
  const BlockLayoutState({this.measuredWidth, this.measuredHeight});

  factory BlockLayoutState.fromJson(
    Map<String, Object?> json, [
    String path = '',
  ]) {
    final reader = JsonReader(json, path);
    return BlockLayoutState(
      measuredWidth: reader.optionalNumber('measuredWidth'),
      measuredHeight: reader.optionalNumber('measuredHeight'),
    );
  }

  final double? measuredWidth;
  final double? measuredHeight;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{};
    putIfNotNull(
      json,
      'measuredWidth',
      measuredWidth == null ? null : jsonNumber(measuredWidth!),
    );
    putIfNotNull(
      json,
      'measuredHeight',
      measuredHeight == null ? null : jsonNumber(measuredHeight!),
    );
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is BlockLayoutState &&
      other.measuredWidth == measuredWidth &&
      other.measuredHeight == measuredHeight;

  @override
  int get hashCode => Object.hash(measuredWidth, measuredHeight);
}

/// Port of `BlockState` from `packages/workflow-types/src/workflow.ts`.
///
/// `outputs` is kept as raw JSON (`Record<string, OutputFieldDefinition>`
/// upstream, but persisted rows carry legacy nested shapes); use
/// `OutputFieldDefinition.tryParse` on an entry when a typed view is needed.
@immutable
class BlockState {
  BlockState({
    required this.id,
    required this.type,
    required this.name,
    required this.position,
    required Map<String, SubBlockState> subBlocks,
    required Map<String, Object?> outputs,
    required this.enabled,
    this.horizontalHandles,
    this.errorEnabled,
    this.retry,
    this.height,
    this.advancedMode,
    this.triggerMode,
    this.data,
    this.layout,
    this.locked,
    Map<String, Object?> extra = const {},
  }) : subBlocks = Map<String, SubBlockState>.unmodifiable(subBlocks),
       outputs = freezeMap(outputs),
       extra = freezeMap(extra);

  factory BlockState.fromJson(Map<String, Object?> json, [String path = '']) {
    final reader = JsonReader(json, path);
    final subBlocksJson = reader.optionalObject('subBlocks') ?? const {};
    final subBlocksPath = path.isEmpty ? 'subBlocks' : '$path.subBlocks';
    final retryJson = reader.optionalChild('retry');
    final dataJson = reader.optionalChild('data');
    final layoutJson = reader.optionalChild('layout');
    return BlockState(
      id: reader.string('id'),
      type: reader.string('type'),
      name: reader.string('name'),
      position: Position.fromJson(
        reader.object('position'),
        path.isEmpty ? 'position' : '$path.position',
      ),
      subBlocks: {
        for (final entry in subBlocksJson.entries)
          entry.key: SubBlockState.fromJson(
            JsonReader(subBlocksJson, subBlocksPath).object(entry.key),
            '$subBlocksPath.${entry.key}',
          ),
      },
      outputs: reader.optionalObject('outputs') ?? const {},
      enabled: reader.optionalBool('enabled') ?? true,
      horizontalHandles: reader.optionalBool('horizontalHandles'),
      errorEnabled: reader.optionalBool('errorEnabled'),
      retry: retryJson == null
          ? null
          : BlockRetryConfig.fromJson(retryJson.map, retryJson.path),
      height: reader.optionalNumber('height'),
      advancedMode: reader.optionalBool('advancedMode'),
      triggerMode: reader.optionalBool('triggerMode'),
      data: dataJson == null
          ? null
          : BlockData.fromJson(dataJson.map, dataJson.path),
      layout: layoutJson == null
          ? null
          : BlockLayoutState.fromJson(layoutJson.map, layoutJson.path),
      locked: reader.optionalBool('locked'),
      extra: reader.extra(_knownKeys),
    );
  }

  static const _knownKeys = {
    'id',
    'type',
    'name',
    'position',
    'subBlocks',
    'outputs',
    'enabled',
    'horizontalHandles',
    'errorEnabled',
    'retry',
    'height',
    'advancedMode',
    'triggerMode',
    'data',
    'layout',
    'locked',
  };

  final String id;
  final String type;
  final String name;
  final Position position;
  final Map<String, SubBlockState> subBlocks;
  final Map<String, Object?> outputs;
  final bool enabled;
  final bool? horizontalHandles;
  final bool? errorEnabled;
  final BlockRetryConfig? retry;
  final double? height;
  final bool? advancedMode;
  final bool? triggerMode;
  final BlockData? data;
  final BlockLayoutState? layout;
  final bool? locked;
  final Map<String, Object?> extra;

  /// The container this block sits in, per `getWorkflowBlockParentId`.
  String? get parentId => data?.effectiveParentId;

  BlockState copyWith({
    String? id,
    String? type,
    String? name,
    Position? position,
    Map<String, SubBlockState>? subBlocks,
    Map<String, Object?>? outputs,
    bool? enabled,
    Object? horizontalHandles = _unset,
    Object? errorEnabled = _unset,
    Object? retry = _unset,
    Object? height = _unset,
    Object? advancedMode = _unset,
    Object? triggerMode = _unset,
    Object? data = _unset,
    Object? layout = _unset,
    Object? locked = _unset,
    Map<String, Object?>? extra,
  }) => BlockState(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    position: position ?? this.position,
    subBlocks: subBlocks ?? this.subBlocks,
    outputs: outputs ?? this.outputs,
    enabled: enabled ?? this.enabled,
    horizontalHandles: _pick(horizontalHandles, this.horizontalHandles),
    errorEnabled: _pick(errorEnabled, this.errorEnabled),
    retry: _pick(retry, this.retry),
    height: _pick(height, this.height),
    advancedMode: _pick(advancedMode, this.advancedMode),
    triggerMode: _pick(triggerMode, this.triggerMode),
    data: _pick(data, this.data),
    layout: _pick(layout, this.layout),
    locked: _pick(locked, this.locked),
    extra: extra ?? this.extra,
  );

  Map<String, Object?> toJson() {
    final json = <String, Object?>{...extra};
    json['id'] = id;
    json['type'] = type;
    json['name'] = name;
    json['position'] = position.toJson();
    json['subBlocks'] = {
      for (final entry in subBlocks.entries) entry.key: entry.value.toJson(),
    };
    json['outputs'] = outputs;
    json['enabled'] = enabled;
    putIfNotNull(json, 'horizontalHandles', horizontalHandles);
    putIfNotNull(json, 'errorEnabled', errorEnabled);
    putIfNotNull(json, 'retry', retry?.toJson());
    putIfNotNull(json, 'height', height == null ? null : jsonNumber(height!));
    putIfNotNull(json, 'advancedMode', advancedMode);
    putIfNotNull(json, 'triggerMode', triggerMode);
    putIfNotNull(json, 'data', data?.toJson());
    putIfNotNull(json, 'layout', layout?.toJson());
    putIfNotNull(json, 'locked', locked);
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is BlockState &&
      other.id == id &&
      other.type == type &&
      other.name == name &&
      other.position == position &&
      deepEquality.equals(other.subBlocks, subBlocks) &&
      deepEquality.equals(other.outputs, outputs) &&
      other.enabled == enabled &&
      other.horizontalHandles == horizontalHandles &&
      other.errorEnabled == errorEnabled &&
      other.retry == retry &&
      other.height == height &&
      other.advancedMode == advancedMode &&
      other.triggerMode == triggerMode &&
      other.data == data &&
      other.layout == layout &&
      other.locked == locked &&
      deepEquality.equals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    position,
    deepEquality.hash(subBlocks),
    deepEquality.hash(outputs),
    enabled,
    horizontalHandles,
    errorEnabled,
    retry,
    height,
    advancedMode,
    triggerMode,
    data,
    layout,
    locked,
    deepEquality.hash(extra),
  );

  @override
  String toString() => 'BlockState($id: $type "$name")';
}

const _unset = Object();

T _pick<T>(Object? candidate, T current) =>
    identical(candidate, _unset) ? current : candidate as T;
