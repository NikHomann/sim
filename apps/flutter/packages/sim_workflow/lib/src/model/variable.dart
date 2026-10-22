import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/json.dart';

/// Port of `Variable['type']` from `packages/workflow-types/src/workflow.ts`.
enum VariableType {
  string('string'),
  number('number'),
  boolean('boolean'),
  object('object'),
  array('array'),
  plain('plain')
  ;

  const VariableType(this.id);

  final String id;

  static VariableType? fromId(String? id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// Port of `Variable` from `packages/workflow-types/src/workflow.ts`.
@immutable
class Variable {
  Variable({
    required this.id,
    required this.name,
    required this.type,
    required Object? value,
    Map<String, Object?> extra = const {},
  }) : value = freezeJson(value),
       extra = freezeMap(extra);

  factory Variable.fromJson(Map<String, Object?> json, [String path = '']) {
    final reader = JsonReader(json, path);
    final typeId = reader.string('type');
    final type = VariableType.fromId(typeId);
    if (type == null) {
      throw FormatException('Unknown variable type "$typeId" at $path.type');
    }
    return Variable(
      id: reader.string('id'),
      name: reader.string('name'),
      type: type,
      value: json['value'],
      extra: reader.extra(_knownKeys),
    );
  }

  static const _knownKeys = {'id', 'name', 'type', 'value'};

  final String id;
  final String name;
  final VariableType type;
  final Object? value;
  final Map<String, Object?> extra;

  Variable copyWith({
    String? id,
    String? name,
    VariableType? type,
    Object? value = _unset,
    Map<String, Object?>? extra,
  }) => Variable(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    value: identical(value, _unset) ? this.value : value,
    extra: extra ?? this.extra,
  );

  Map<String, Object?> toJson() => {
    ...extra,
    'id': id,
    'name': name,
    'type': type.id,
    'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is Variable &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      deepEquality.equals(other.value, value) &&
      deepEquality.equals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    deepEquality.hash(value),
    deepEquality.hash(extra),
  );
}

const _unset = Object();
