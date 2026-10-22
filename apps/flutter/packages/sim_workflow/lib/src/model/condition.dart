import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/json.dart';

/// Port of `SubBlockCondition` from
/// `apps/sim/lib/workflows/subblocks/visibility.ts`, which is also the object
/// form of `SubBlockConfig.condition` / `SubBlockConfig.required` in
/// `apps/sim/blocks/types.ts`:
/// `{ field, value: scalar | scalar[], not?, and?: { field, value, not? } }`.
///
/// [value] is a scalar or a `List` of scalars. `and` is typed recursively like
/// upstream, but the evaluator only consults one level, exactly as
/// `evaluateSubBlockCondition` does.
@immutable
class SubBlockCondition {
  SubBlockCondition({
    required this.field,
    required Object? value,
    this.not = false,
    this.and,
  }) : value = freezeJson(value);

  factory SubBlockCondition.fromJson(
    Map<String, Object?> json, [
    String path = '',
  ]) {
    final reader = JsonReader(json, path);
    final andJson = reader.optionalChild('and');
    return SubBlockCondition(
      field: reader.string('field'),
      value: json['value'],
      not: reader.optionalBool('not') ?? false,
      and: andJson == null
          ? null
          : SubBlockCondition.fromJson(andJson.map, andJson.path),
    );
  }

  final String field;
  final Object? value;
  final bool not;
  final SubBlockCondition? and;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{'field': field, 'value': value};
    if (not) json['not'] = true;
    putIfNotNull(json, 'and', and?.toJson());
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is SubBlockCondition &&
      other.field == field &&
      deepEquality.equals(other.value, value) &&
      other.not == not &&
      other.and == and;

  @override
  int get hashCode => Object.hash(field, deepEquality.hash(value), not, and);
}

/// A condition that is either declared statically or computed from the
/// block's current values (the function form of `condition` / `required`).
///
/// Function-valued upstream conditions (6 files) are hand-ported as
/// [DynamicCondition]; a generated registry emits [StaticCondition].
@immutable
sealed class ConditionSpec {
  const ConditionSpec();

  SubBlockCondition resolve(Map<String, Object?> values);
}

class StaticCondition extends ConditionSpec {
  const StaticCondition(this.condition);

  final SubBlockCondition condition;

  @override
  SubBlockCondition resolve(Map<String, Object?> values) => condition;

  @override
  bool operator ==(Object other) =>
      other is StaticCondition && other.condition == condition;

  @override
  int get hashCode => condition.hashCode;
}

class DynamicCondition extends ConditionSpec {
  const DynamicCondition(this.builder, {this.name});

  final SubBlockCondition Function(Map<String, Object?> values) builder;

  /// Optional upstream identifier (`<blockType>.<subBlockId>.condition`) so a
  /// registry check can list which closures were hand-ported.
  final String? name;

  @override
  SubBlockCondition resolve(Map<String, Object?> values) => builder(values);
}

/// Port of `SubBlockConfig.required`: `boolean | condition | fn`.
@immutable
sealed class SubBlockRequired {
  const SubBlockRequired();

  const factory SubBlockRequired.when(ConditionSpec condition) = RequiredWhen;

  static const SubBlockRequired always = _RequiredAlways();
  static const SubBlockRequired never = _RequiredNever();

  /// Upstream truthiness: `false`/absent is not required; `true` is; an
  /// object is "required when the condition holds".
  bool get isDeclared;
}

class _RequiredAlways extends SubBlockRequired {
  const _RequiredAlways();

  @override
  bool get isDeclared => true;
}

class _RequiredNever extends SubBlockRequired {
  const _RequiredNever();

  @override
  bool get isDeclared => false;
}

class RequiredWhen extends SubBlockRequired {
  const RequiredWhen(this.condition);

  final ConditionSpec condition;

  @override
  bool get isDeclared => true;

  @override
  bool operator ==(Object other) =>
      other is RequiredWhen && other.condition == condition;

  @override
  int get hashCode => condition.hashCode;
}
