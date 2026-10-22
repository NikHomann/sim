// Failure modes for the condition DSL evaluator
// (port of evaluateSubBlockCondition in
// apps/sim/lib/workflows/subblocks/visibility.ts):
//  1. No condition → true.
//  2. Scalar equality uses strict equality: 'true' (string) != true (bool),
//     1 == 1.0, and a missing field never equals a non-null value.
//  3. `not` inverts scalar equality, and a missing field satisfies
//     `{value: 'x', not: true}` (undefined !== 'x').
//  4. Array value: membership; a missing/null field is false even with `not`
//     (upstream guards `fieldValue != null` before `includes`).
//  5. `and` clause must also hold; a failing `and` fails the whole condition.
//  6. `and` with an array value and `not`.
//  7. Nested `and.and` is ignored (upstream reads one level only).
//  8. Dynamic (function) conditions receive the values map.
//  9. A `required` declaration: never → false, always → true, when → evaluated.
// 10. Scalar equality against an array field value is false (no deep equality
//     in JS `===`).
import 'package:sim_workflow/sim_workflow.dart';
import 'package:test/test.dart';

void main() {
  test('1. no condition is true', () {
    expect(evaluateSubBlockCondition(null, const {}), isTrue);
  });

  test('2. strict scalar equality', () {
    final cond = StaticCondition(
      SubBlockCondition(field: 'enabled', value: true),
    );
    expect(evaluateSubBlockCondition(cond, const {'enabled': 'true'}), isFalse);
    expect(evaluateSubBlockCondition(cond, const {'enabled': true}), isTrue);
    expect(evaluateSubBlockCondition(cond, const {}), isFalse);
    final numeric = StaticCondition(
      SubBlockCondition(field: 'n', value: 1),
    );
    expect(evaluateSubBlockCondition(numeric, const {'n': 1.0}), isTrue);
    expect(evaluateSubBlockCondition(numeric, const {'n': '1'}), isFalse);
  });

  test('3. not with scalar', () {
    final cond = StaticCondition(
      SubBlockCondition(field: 'op', value: 'x', not: true),
    );
    expect(evaluateSubBlockCondition(cond, const {'op': 'x'}), isFalse);
    expect(evaluateSubBlockCondition(cond, const {'op': 'y'}), isTrue);
    expect(evaluateSubBlockCondition(cond, const {}), isTrue);
  });

  test('4. array membership with null guard', () {
    final cond = StaticCondition(
      SubBlockCondition(field: 'op', value: const ['a', 'b']),
    );
    expect(evaluateSubBlockCondition(cond, const {'op': 'b'}), isTrue);
    expect(evaluateSubBlockCondition(cond, const {'op': 'c'}), isFalse);
    expect(evaluateSubBlockCondition(cond, const {'op': null}), isFalse);
    final negated = StaticCondition(
      SubBlockCondition(field: 'op', value: const ['a'], not: true),
    );
    expect(evaluateSubBlockCondition(negated, const {'op': 'z'}), isTrue);
    expect(evaluateSubBlockCondition(negated, const {}), isFalse);
  });

  test('5. and clause must hold', () {
    final cond = StaticCondition(
      SubBlockCondition(
        field: 'op',
        value: 'send',
        and: SubBlockCondition(field: 'mode', value: 'basic'),
      ),
    );
    expect(
      evaluateSubBlockCondition(cond, const {'op': 'send', 'mode': 'basic'}),
      isTrue,
    );
    expect(
      evaluateSubBlockCondition(cond, const {'op': 'send', 'mode': 'adv'}),
      isFalse,
    );
  });

  test('6. and with array and not', () {
    final cond = StaticCondition(
      SubBlockCondition(
        field: 'op',
        value: 'send',
        and: SubBlockCondition(
          field: 'kind',
          value: const ['x', 'y'],
          not: true,
        ),
      ),
    );
    expect(
      evaluateSubBlockCondition(cond, const {'op': 'send', 'kind': 'z'}),
      isTrue,
    );
    expect(
      evaluateSubBlockCondition(cond, const {'op': 'send', 'kind': 'x'}),
      isFalse,
    );
    expect(evaluateSubBlockCondition(cond, const {'op': 'send'}), isFalse);
  });

  test('7. nested and.and is ignored', () {
    final cond = StaticCondition(
      SubBlockCondition(
        field: 'a',
        value: 1,
        and: SubBlockCondition(
          field: 'b',
          value: 2,
          and: SubBlockCondition(field: 'c', value: 3),
        ),
      ),
    );
    expect(
      evaluateSubBlockCondition(cond, const {'a': 1, 'b': 2, 'c': 99}),
      isTrue,
    );
  });

  test('8. dynamic conditions see the values', () {
    final cond = DynamicCondition(
      (values) => SubBlockCondition(
        field: 'op',
        value: values['expected'] ?? 'none',
      ),
    );
    expect(
      evaluateSubBlockCondition(cond, const {'op': 'go', 'expected': 'go'}),
      isTrue,
    );
    expect(evaluateSubBlockCondition(cond, const {'op': 'go'}), isFalse);
  });

  test('9. required declarations', () {
    expect(isSubBlockRequired(SubBlockRequired.never, const {}), isFalse);
    expect(isSubBlockRequired(SubBlockRequired.always, const {}), isTrue);
    final when = SubBlockRequired.when(
      StaticCondition(SubBlockCondition(field: 'op', value: 'a')),
    );
    expect(isSubBlockRequired(when, const {'op': 'a'}), isTrue);
    expect(isSubBlockRequired(when, const {'op': 'b'}), isFalse);
  });

  test('10. scalar against array field value is false', () {
    final cond = StaticCondition(SubBlockCondition(field: 'v', value: 'a'));
    expect(
      evaluateSubBlockCondition(cond, const {
        'v': ['a'],
      }),
      isFalse,
    );
  });
}
