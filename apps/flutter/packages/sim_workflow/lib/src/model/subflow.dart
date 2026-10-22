import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/block_data.dart';
import 'package:sim_workflow/src/model/json.dart';

/// Port of `SUBFLOW_TYPES` from `packages/workflow-types/src/workflow.ts`.
abstract final class SubflowTypes {
  static const String loop = 'loop';
  static const String parallel = 'parallel';
  static const Set<String> all = {loop, parallel};
}

/// Port of `Loop` from `packages/workflow-types/src/workflow.ts`.
@immutable
class Loop {
  Loop({
    required this.id,
    required List<String> nodes,
    required this.iterations,
    required this.loopType,
    required this.enabled,
    Object? forEachItems,
    this.whileCondition,
    this.doWhileCondition,
    this.locked,
    Map<String, Object?> extra = const {},
  }) : nodes = List<String>.unmodifiable(nodes),
       forEachItems = freezeJson(forEachItems),
       extra = freezeMap(extra);

  factory Loop.fromJson(Map<String, Object?> json, [String path = '']) {
    final reader = JsonReader(json, path);
    final loopTypeId = reader.string('loopType');
    final loopType = LoopType.fromId(loopTypeId);
    if (loopType == null) {
      throw FormatException('Unknown loopType "$loopTypeId" at $path.loopType');
    }
    return Loop(
      id: reader.string('id'),
      nodes: reader.stringList('nodes'),
      iterations: reader.number('iterations'),
      loopType: loopType,
      forEachItems: json['forEachItems'],
      whileCondition: reader.optionalString('whileCondition'),
      doWhileCondition: reader.optionalString('doWhileCondition'),
      enabled: reader.optionalBool('enabled') ?? true,
      locked: reader.optionalBool('locked'),
      extra: reader.extra(_knownKeys),
    );
  }

  static const _knownKeys = {
    'id',
    'nodes',
    'iterations',
    'loopType',
    'forEachItems',
    'whileCondition',
    'doWhileCondition',
    'enabled',
    'locked',
  };

  final String id;
  final List<String> nodes;
  final double iterations;
  final LoopType loopType;
  final Object? forEachItems;
  final String? whileCondition;
  final String? doWhileCondition;
  final bool enabled;
  final bool? locked;
  final Map<String, Object?> extra;

  Loop copyWith({
    String? id,
    List<String>? nodes,
    double? iterations,
    LoopType? loopType,
    Object? forEachItems = _unset,
    Object? whileCondition = _unset,
    Object? doWhileCondition = _unset,
    bool? enabled,
    Object? locked = _unset,
    Map<String, Object?>? extra,
  }) => Loop(
    id: id ?? this.id,
    nodes: nodes ?? this.nodes,
    iterations: iterations ?? this.iterations,
    loopType: loopType ?? this.loopType,
    forEachItems: _pick(forEachItems, this.forEachItems),
    whileCondition: _pick(whileCondition, this.whileCondition),
    doWhileCondition: _pick(doWhileCondition, this.doWhileCondition),
    enabled: enabled ?? this.enabled,
    locked: _pick(locked, this.locked),
    extra: extra ?? this.extra,
  );

  Map<String, Object?> toJson() {
    final json = <String, Object?>{...extra};
    json['id'] = id;
    json['nodes'] = nodes;
    json['iterations'] = jsonNumber(iterations);
    json['loopType'] = loopType.id;
    putIfNotNull(json, 'forEachItems', forEachItems);
    putIfNotNull(json, 'whileCondition', whileCondition);
    putIfNotNull(json, 'doWhileCondition', doWhileCondition);
    json['enabled'] = enabled;
    putIfNotNull(json, 'locked', locked);
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is Loop && deepEquality.equals(other.toJson(), toJson());

  @override
  int get hashCode => deepEquality.hash(toJson());
}

/// Port of `Parallel` from `packages/workflow-types/src/workflow.ts`.
@immutable
class Parallel {
  Parallel({
    required this.id,
    required List<String> nodes,
    required this.enabled,
    Object? distribution,
    this.count,
    this.parallelType,
    this.batchSize,
    this.locked,
    Map<String, Object?> extra = const {},
  }) : nodes = List<String>.unmodifiable(nodes),
       distribution = freezeJson(distribution),
       extra = freezeMap(extra);

  factory Parallel.fromJson(Map<String, Object?> json, [String path = '']) {
    final reader = JsonReader(json, path);
    final typeId = reader.optionalString('parallelType');
    final parallelType = ParallelType.fromId(typeId);
    if (typeId != null && parallelType == null) {
      throw FormatException(
        'Unknown parallelType "$typeId" at $path.parallelType',
      );
    }
    return Parallel(
      id: reader.string('id'),
      nodes: reader.stringList('nodes'),
      distribution: json['distribution'],
      count: reader.optionalNumber('count'),
      parallelType: parallelType,
      batchSize: reader.optionalNumber('batchSize'),
      enabled: reader.optionalBool('enabled') ?? true,
      locked: reader.optionalBool('locked'),
      extra: reader.extra(_knownKeys),
    );
  }

  static const _knownKeys = {
    'id',
    'nodes',
    'distribution',
    'count',
    'parallelType',
    'batchSize',
    'enabled',
    'locked',
  };

  final String id;
  final List<String> nodes;
  final Object? distribution;
  final double? count;
  final ParallelType? parallelType;
  final double? batchSize;
  final bool enabled;
  final bool? locked;
  final Map<String, Object?> extra;

  Parallel copyWith({
    String? id,
    List<String>? nodes,
    Object? distribution = _unset,
    Object? count = _unset,
    Object? parallelType = _unset,
    Object? batchSize = _unset,
    bool? enabled,
    Object? locked = _unset,
    Map<String, Object?>? extra,
  }) => Parallel(
    id: id ?? this.id,
    nodes: nodes ?? this.nodes,
    distribution: _pick(distribution, this.distribution),
    count: _pick(count, this.count),
    parallelType: _pick(parallelType, this.parallelType),
    batchSize: _pick(batchSize, this.batchSize),
    enabled: enabled ?? this.enabled,
    locked: _pick(locked, this.locked),
    extra: extra ?? this.extra,
  );

  Map<String, Object?> toJson() {
    final json = <String, Object?>{...extra};
    json['id'] = id;
    json['nodes'] = nodes;
    putIfNotNull(json, 'distribution', distribution);
    putIfNotNull(json, 'count', count == null ? null : jsonNumber(count!));
    putIfNotNull(json, 'parallelType', parallelType?.id);
    putIfNotNull(
      json,
      'batchSize',
      batchSize == null ? null : jsonNumber(batchSize!),
    );
    json['enabled'] = enabled;
    putIfNotNull(json, 'locked', locked);
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is Parallel && deepEquality.equals(other.toJson(), toJson());

  @override
  int get hashCode => deepEquality.hash(toJson());
}

const _unset = Object();

T _pick<T>(Object? candidate, T current) =>
    identical(candidate, _unset) ? current : candidate as T;
