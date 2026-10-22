import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/json.dart';
import 'package:sim_workflow/src/model/sub_block_type.dart';

/// Port of `OutputCondition` from `packages/workflow-types/src/blocks.ts`.
@immutable
class OutputCondition {
  OutputCondition({
    required this.field,
    required Object? value,
    this.allowReference,
    this.not = false,
    this.and,
  }) : value = freezeJson(value);

  factory OutputCondition.fromJson(
    Map<String, Object?> json, [
    String path = '',
  ]) {
    final reader = JsonReader(json, path);
    final andJson = reader.optionalChild('and');
    return OutputCondition(
      allowReference: reader.optionalBool('allowReference'),
      field: reader.string('field'),
      value: json['value'],
      not: reader.optionalBool('not') ?? false,
      and: andJson == null
          ? null
          : OutputConditionClause.fromJson(andJson.map, andJson.path),
    );
  }

  final bool? allowReference;
  final String field;
  final Object? value;
  final bool not;
  final OutputConditionClause? and;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{};
    putIfNotNull(json, 'allowReference', allowReference);
    json['field'] = field;
    json['value'] = value;
    if (not) json['not'] = true;
    putIfNotNull(json, 'and', and?.toJson());
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is OutputCondition && deepEquality.equals(other.toJson(), toJson());

  @override
  int get hashCode => deepEquality.hash(toJson());
}

/// The `and` clause of an [OutputCondition].
@immutable
class OutputConditionClause {
  OutputConditionClause({
    required this.field,
    required Object? value,
    this.not = false,
  }) : value = freezeJson(value);

  factory OutputConditionClause.fromJson(
    Map<String, Object?> json, [
    String path = '',
  ]) {
    final reader = JsonReader(json, path);
    return OutputConditionClause(
      field: reader.string('field'),
      value: json['value'],
      not: reader.optionalBool('not') ?? false,
    );
  }

  final String field;
  final Object? value;
  final bool not;

  Map<String, Object?> toJson() => {
    'field': field,
    'value': value,
    if (not) 'not': true,
  };

  @override
  bool operator ==(Object other) =>
      other is OutputConditionClause &&
      other.field == field &&
      deepEquality.equals(other.value, value) &&
      other.not == not;

  @override
  int get hashCode => Object.hash(field, deepEquality.hash(value), not);
}

/// Port of `OutputFieldDefinition` from
/// `packages/workflow-types/src/blocks.ts`: either a bare primitive type id or
/// `{ type, description?, condition?, hiddenFromDisplay? }`.
///
/// [tryParse] returns null for any other shape (persisted rows carry legacy
/// nested outputs), so callers keep the raw JSON and read it defensively.
@immutable
class OutputFieldDefinition {
  const OutputFieldDefinition({
    required this.type,
    this.description,
    this.condition,
    this.hiddenFromDisplay,
    this.isShorthand = false,
  });

  /// Parses the shorthand (`'string'`) or object form; null when neither.
  static OutputFieldDefinition? tryParse(Object? json, [String path = '']) {
    if (json is String) {
      final type = PrimitiveValueType.fromId(json);
      return type == null
          ? null
          : OutputFieldDefinition(type: type, isShorthand: true);
    }
    if (json is Map<String, Object?>) {
      final reader = JsonReader(json, path);
      final type = PrimitiveValueType.fromId(reader.optionalString('type'));
      if (type == null) return null;
      final conditionJson = reader.optionalChild('condition');
      return OutputFieldDefinition(
        type: type,
        description: reader.optionalString('description'),
        condition: conditionJson == null
            ? null
            : OutputCondition.fromJson(conditionJson.map, conditionJson.path),
        hiddenFromDisplay: reader.optionalBool('hiddenFromDisplay'),
      );
    }
    return null;
  }

  final PrimitiveValueType type;
  final String? description;
  final OutputCondition? condition;
  final bool? hiddenFromDisplay;

  /// Whether the source used the bare-string form, so [toJson] round-trips.
  final bool isShorthand;

  Object toJson() {
    if (isShorthand &&
        description == null &&
        condition == null &&
        hiddenFromDisplay == null) {
      return type.id;
    }
    final json = <String, Object?>{'type': type.id};
    putIfNotNull(json, 'description', description);
    putIfNotNull(json, 'condition', condition?.toJson());
    putIfNotNull(json, 'hiddenFromDisplay', hiddenFromDisplay);
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is OutputFieldDefinition &&
      other.type == type &&
      other.description == description &&
      other.condition == condition &&
      other.hiddenFromDisplay == hiddenFromDisplay;

  @override
  int get hashCode =>
      Object.hash(type, description, condition, hiddenFromDisplay);
}

/// Port of `isHiddenFromDisplay` from `packages/workflow-types/src/blocks.ts`.
bool isHiddenFromDisplay(Object? definition) =>
    definition is Map &&
    definition.containsKey('hiddenFromDisplay') &&
    _truthy(definition['hiddenFromDisplay']);

/// JavaScript `Boolean(x)` for JSON values.
bool _truthy(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0 && !value.isNaN;
  if (value is String) return value.isNotEmpty;
  return true;
}
