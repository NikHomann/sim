import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/json.dart';

/// Port of `WorkflowEdgeEndpoints`: the shape the graph rules need.
abstract interface class EdgeEndpoints {
  String get source;
  String get target;
}

/// Port of `WorkflowEdgeHandles`: endpoints plus the handle on each side.
abstract interface class EdgeHandles implements EdgeEndpoints {
  String? get sourceHandle;
  String? get targetHandle;
}

/// The subset of the `@xyflow/react` `Edge` that upstream reads and writes
/// (`packages/workflow-persistence/src/load.ts`,
/// `packages/realtime-protocol/src/schemas.ts`, `apps/sim/serializer/index.ts`):
/// `id`, `source`, `target`, `sourceHandle`, `targetHandle`, `type`, `data`.
///
/// Every other React Flow field (`selected`, `animated`, `label`, ...) is kept
/// verbatim in [extra] so a state loaded from the server round-trips.
///
/// A handle that is `null` or `''` means "no specific handle"; persistence
/// normalises both to `null` (`edge.sourceHandle || null`), so [toJson] omits
/// null handles the way the serializer does (`edge.sourceHandle || undefined`).
@immutable
class Edge implements EdgeHandles {
  Edge({
    required this.id,
    required this.source,
    required this.target,
    this.sourceHandle,
    this.targetHandle,
    this.type,
    Map<String, Object?>? data,
    Map<String, Object?> extra = const {},
  }) : data = data == null ? null : freezeMap(data),
       extra = freezeMap(extra);

  factory Edge.fromJson(Map<String, Object?> json, [String path = '']) {
    final reader = JsonReader(json, path);
    return Edge(
      id: reader.string('id'),
      source: reader.string('source'),
      target: reader.string('target'),
      sourceHandle: reader.optionalString('sourceHandle'),
      targetHandle: reader.optionalString('targetHandle'),
      type: reader.optionalString('type'),
      data: reader.optionalObject('data'),
      extra: reader.extra(_knownKeys),
    );
  }

  static const _knownKeys = {
    'id',
    'source',
    'target',
    'sourceHandle',
    'targetHandle',
    'type',
    'data',
  };

  final String id;
  @override
  final String source;
  @override
  final String target;
  @override
  final String? sourceHandle;
  @override
  final String? targetHandle;
  final String? type;
  final Map<String, Object?>? data;
  final Map<String, Object?> extra;

  Edge copyWith({
    String? id,
    String? source,
    String? target,
    Object? sourceHandle = _unset,
    Object? targetHandle = _unset,
    Object? type = _unset,
    Object? data = _unset,
    Map<String, Object?>? extra,
  }) => Edge(
    id: id ?? this.id,
    source: source ?? this.source,
    target: target ?? this.target,
    sourceHandle: identical(sourceHandle, _unset)
        ? this.sourceHandle
        : sourceHandle as String?,
    targetHandle: identical(targetHandle, _unset)
        ? this.targetHandle
        : targetHandle as String?,
    type: identical(type, _unset) ? this.type : type as String?,
    data: identical(data, _unset) ? this.data : data as Map<String, Object?>?,
    extra: extra ?? this.extra,
  );

  Map<String, Object?> toJson() {
    final json = <String, Object?>{...extra};
    json['id'] = id;
    json['source'] = source;
    json['target'] = target;
    putIfNotNull(json, 'sourceHandle', sourceHandle);
    putIfNotNull(json, 'targetHandle', targetHandle);
    putIfNotNull(json, 'type', type);
    putIfNotNull(json, 'data', data);
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is Edge &&
      other.id == id &&
      other.source == source &&
      other.target == target &&
      other.sourceHandle == sourceHandle &&
      other.targetHandle == targetHandle &&
      other.type == type &&
      deepEquality.equals(other.data, data) &&
      deepEquality.equals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    id,
    source,
    target,
    sourceHandle,
    targetHandle,
    type,
    deepEquality.hash(data),
    deepEquality.hash(extra),
  );

  @override
  String toString() =>
      'Edge($id: $source[$sourceHandle] -> $target[$targetHandle])';
}

const _unset = Object();
