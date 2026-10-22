import 'package:sim_workflow/src/model/condition.dart';

/// Port of `evaluateSubBlockCondition` from
/// `apps/sim/lib/workflows/subblocks/visibility.ts`.
///
/// JavaScript semantics kept: scalar comparison is strict (`'true' !== true`),
/// array values test membership and require a non-null field value even when
/// negated, and only one `and` level is read. The one divergence: upstream
/// distinguishes a missing field (`undefined`) from an explicit `null`
/// condition value; Dart has a single `null`, so `{value: null}` matches a
/// missing field here. No upstream block declares a null condition value.
bool evaluateSubBlockCondition(
  ConditionSpec? condition,
  Map<String, Object?> values,
) {
  if (condition == null) return true;
  final actual = condition.resolve(values);
  final valueMatch = _clauseMatches(actual, values);
  final and = actual.and;
  final andMatch = and == null || _clauseMatches(and, values);
  return valueMatch && andMatch;
}

bool _clauseMatches(SubBlockCondition clause, Map<String, Object?> values) {
  final fieldValue = values[clause.field];
  final expected = clause.value;
  if (expected is List) {
    if (fieldValue == null) return false;
    final included = expected.contains(fieldValue);
    return clause.not ? !included : included;
  }
  final equal = fieldValue == expected;
  return clause.not ? !equal : equal;
}

/// The `required` check as `collectBlockFieldIssues` performs it: `false` →
/// not required, `true` → required, an object/function → evaluated against
/// the params.
bool isSubBlockRequired(
  SubBlockRequired required,
  Map<String, Object?> values,
) => switch (required) {
  RequiredWhen(:final condition) => evaluateSubBlockCondition(
    condition,
    values,
  ),
  _ => required.isDeclared,
};
