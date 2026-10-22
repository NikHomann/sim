import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/json.dart';
import 'package:sim_workflow/src/model/sub_block_type.dart';

/// Port of `SubBlockState` from `packages/workflow-types/src/workflow.ts`.
///
/// Upstream types `value` as `string | number | string[][] | null` but every
/// editor stores richer JSON (arrays of records for `messages-input`,
/// records for `checkbox-list`, booleans for `switch`), so [value] is any
/// JSON value. `null` is a real value ("cleared") and is always written out,
/// which the two-store merge (`mergeSubblockState`) depends on.
@immutable
class SubBlockState {
  SubBlockState({
    required this.id,
    required this.type,
    required Object? value,
    Map<String, Object?> extra = const {},
  }) : value = freezeJson(value),
       extra = freezeMap(extra);

  factory SubBlockState.fromJson(
    Map<String, Object?> json, [
    String path = '',
  ]) {
    final reader = JsonReader(json, path);
    return SubBlockState(
      id: reader.string('id'),
      type: reader.string('type'),
      value: json['value'],
      extra: reader.extra(_knownKeys),
    );
  }

  static const _knownKeys = {'id', 'type', 'value'};

  final String id;

  /// The raw sub-block type id; see [subBlockType] for the typed view.
  final String type;
  final Object? value;
  final Map<String, Object?> extra;

  SubBlockType? get subBlockType => SubBlockType.fromId(type);

  SubBlockState copyWith({
    String? id,
    String? type,
    Object? value = _unset,
    Map<String, Object?>? extra,
  }) => SubBlockState(
    id: id ?? this.id,
    type: type ?? this.type,
    value: identical(value, _unset) ? this.value : value,
    extra: extra ?? this.extra,
  );

  Map<String, Object?> toJson() => {
    ...extra,
    'id': id,
    'type': type,
    'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is SubBlockState &&
      other.id == id &&
      other.type == type &&
      deepEquality.equals(other.value, value) &&
      deepEquality.equals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    id,
    type,
    deepEquality.hash(value),
    deepEquality.hash(extra),
  );

  @override
  String toString() => 'SubBlockState($id: $type = $value)';
}

const _unset = Object();
