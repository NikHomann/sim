import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/json.dart';

/// Port of `LoopConfig['loopType']` from
/// `packages/workflow-types/src/workflow.ts`.
enum LoopType {
  forLoop('for'),
  forEach('forEach'),
  whileLoop('while'),
  doWhile('doWhile')
  ;

  const LoopType(this.id);

  final String id;

  static LoopType? fromId(String? id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// Port of `ParallelConfig['parallelType']`.
enum ParallelType {
  count('count'),
  collection('collection')
  ;

  const ParallelType(this.id);

  final String id;

  static ParallelType? fromId(String? id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// Port of `CanonicalMode` from
/// `apps/sim/lib/workflows/subblocks/visibility.ts`.
enum CanonicalMode {
  basic('basic'),
  advanced('advanced')
  ;

  const CanonicalMode(this.id);

  final String id;

  static CanonicalMode? fromId(String? id) {
    for (final mode in values) {
      if (mode.id == id) return mode;
    }
    return null;
  }
}

/// Port of `BlockData` from `packages/workflow-types/src/workflow.ts`.
///
/// `extent` is only ever `'parent'` upstream; it is kept as a string so an
/// unexpected value still round-trips. Enum-typed fields (`loopType`,
/// `parallelType`, `canonicalModes` values) drop an unknown wire value on
/// read; every other unknown key is preserved in [extra].
@immutable
class BlockData {
  BlockData({
    this.parentId,
    this.extent,
    this.width,
    this.height,
    Object? collection,
    this.count,
    this.loopType,
    this.whileCondition,
    this.doWhileCondition,
    this.parallelType,
    this.batchSize,
    this.type,
    Map<String, CanonicalMode>? canonicalModes,
    Map<String, Object?> extra = const {},
  }) : collection = freezeJson(collection),
       canonicalModes = canonicalModes == null
           ? null
           : Map<String, CanonicalMode>.unmodifiable(canonicalModes),
       extra = freezeMap(extra);

  factory BlockData.fromJson(Map<String, Object?> json, [String path = '']) {
    final reader = JsonReader(json, path);
    final modesJson = reader.optionalObject('canonicalModes');
    return BlockData(
      parentId: reader.optionalString('parentId'),
      extent: reader.optionalString('extent'),
      width: reader.optionalNumber('width'),
      height: reader.optionalNumber('height'),
      collection: json['collection'],
      count: reader.optionalNumber('count'),
      loopType: LoopType.fromId(reader.optionalString('loopType')),
      whileCondition: reader.optionalString('whileCondition'),
      doWhileCondition: reader.optionalString('doWhileCondition'),
      parallelType: ParallelType.fromId(reader.optionalString('parallelType')),
      batchSize: reader.optionalNumber('batchSize'),
      type: reader.optionalString('type'),
      canonicalModes: modesJson == null
          ? null
          : {
              for (final entry in modesJson.entries)
                if (CanonicalMode.fromId(entry.value as String?) != null)
                  entry.key: CanonicalMode.fromId(entry.value! as String)!,
            },
      extra: reader.extra(_knownKeys),
    );
  }

  static const _knownKeys = {
    'parentId',
    'extent',
    'width',
    'height',
    'collection',
    'count',
    'loopType',
    'whileCondition',
    'doWhileCondition',
    'parallelType',
    'batchSize',
    'type',
    'canonicalModes',
  };

  final String? parentId;
  final String? extent;
  final double? width;
  final double? height;
  final Object? collection;
  final double? count;
  final LoopType? loopType;
  final String? whileCondition;
  final String? doWhileCondition;
  final ParallelType? parallelType;
  final double? batchSize;
  final String? type;
  final Map<String, CanonicalMode>? canonicalModes;
  final Map<String, Object?> extra;

  /// Port of `getWorkflowBlockParentId`: a non-empty string, else null.
  String? get effectiveParentId {
    final id = parentId;
    return id != null && id.isNotEmpty ? id : null;
  }

  BlockData copyWith({
    Object? parentId = _unset,
    Object? extent = _unset,
    Object? width = _unset,
    Object? height = _unset,
    Object? collection = _unset,
    Object? count = _unset,
    Object? loopType = _unset,
    Object? whileCondition = _unset,
    Object? doWhileCondition = _unset,
    Object? parallelType = _unset,
    Object? batchSize = _unset,
    Object? type = _unset,
    Object? canonicalModes = _unset,
    Map<String, Object?>? extra,
  }) => BlockData(
    parentId: _pick(parentId, this.parentId),
    extent: _pick(extent, this.extent),
    width: _pick(width, this.width),
    height: _pick(height, this.height),
    collection: _pick(collection, this.collection),
    count: _pick(count, this.count),
    loopType: _pick(loopType, this.loopType),
    whileCondition: _pick(whileCondition, this.whileCondition),
    doWhileCondition: _pick(doWhileCondition, this.doWhileCondition),
    parallelType: _pick(parallelType, this.parallelType),
    batchSize: _pick(batchSize, this.batchSize),
    type: _pick(type, this.type),
    canonicalModes: _pick(canonicalModes, this.canonicalModes),
    extra: extra ?? this.extra,
  );

  Map<String, Object?> toJson() {
    final json = <String, Object?>{...extra};
    putIfNotNull(json, 'parentId', parentId);
    putIfNotNull(json, 'extent', extent);
    putIfNotNull(json, 'width', width == null ? null : jsonNumber(width!));
    putIfNotNull(json, 'height', height == null ? null : jsonNumber(height!));
    putIfNotNull(json, 'collection', collection);
    putIfNotNull(json, 'count', count == null ? null : jsonNumber(count!));
    putIfNotNull(json, 'loopType', loopType?.id);
    putIfNotNull(json, 'whileCondition', whileCondition);
    putIfNotNull(json, 'doWhileCondition', doWhileCondition);
    putIfNotNull(json, 'parallelType', parallelType?.id);
    putIfNotNull(
      json,
      'batchSize',
      batchSize == null ? null : jsonNumber(batchSize!),
    );
    putIfNotNull(json, 'type', type);
    putIfNotNull(
      json,
      'canonicalModes',
      canonicalModes == null
          ? null
          : {
              for (final entry in canonicalModes!.entries)
                entry.key: entry.value.id,
            },
    );
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is BlockData && deepEquality.equals(other.toJson(), toJson());

  @override
  int get hashCode => deepEquality.hash(toJson());
}

const _unset = Object();

T _pick<T>(Object? candidate, T current) =>
    identical(candidate, _unset) ? current : candidate as T;
