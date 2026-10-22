// Failure modes for dependsOn resolution
// (ports of apps/sim/lib/workflows/subblocks/dependencies.ts and
// parseDependsOn / normalizeDependencyValue in visibility.ts):
//  1. parseDependsOn: null → empty; list form → all; object form → all + any
//     concatenated in that order.
//  2. getSubBlocksDependingOnChange: a change to a canonical member notifies
//     dependants of the canonical id, the basic id and every advanced id.
//  3. A sub-block depending on an unrelated field is not returned.
//  4. getTransitiveSubBlockDependents walks chains (a → b → c) once each,
//     and reports the reason as `<id> depends on <changed>`.
//  5. A dependency cycle (a depends on b, b depends on a) terminates and does
//     not report the changed id itself.
//  6. Multiple changed ids are seeded together and not reported as dependents
//     of one another.
//  7. normalizeDependencyValue: null/undefined → null; [] → null; nested
//     arrays map; {value} unwraps; {id} picks id; other records pass through.
import 'package:sim_workflow/sim_workflow.dart';
import 'package:test/test.dart';

SubBlockConfig _cfg(
  String id, {
  String? canonical,
  SubBlockMode? mode,
  DependsOn? dependsOn,
}) => SubBlockConfig(
  id: id,
  type: 'short-input',
  canonicalParamId: canonical,
  mode: mode,
  dependsOn: dependsOn,
);

void main() {
  test('1. parseDependsOn forms', () {
    expect(parseDependsOn(null).allDependsOnFields, isEmpty);
    final list = parseDependsOn(DependsOn.fields(const ['a', 'b']));
    expect(list.allFields, ['a', 'b']);
    expect(list.anyFields, isEmpty);
    final object = parseDependsOn(
      DependsOn(all: const ['x'], any: const ['y', 'z']),
    );
    expect(object.allDependsOnFields, ['x', 'y', 'z']);
    expect(getDependsOnFields(DependsOn(any: const ['q'])), ['q']);
  });

  final subBlocks = [
    _cfg('credential', canonical: 'cred'),
    _cfg('manualCred', canonical: 'cred', mode: SubBlockMode.advanced),
    _cfg('byCanonical', dependsOn: DependsOn.fields(const ['cred'])),
    _cfg('byBasic', dependsOn: DependsOn.fields(const ['credential'])),
    _cfg('byAdvanced', dependsOn: DependsOn(any: const ['manualCred'])),
    _cfg('unrelated', dependsOn: DependsOn.fields(const ['other'])),
    _cfg('chained', dependsOn: DependsOn.fields(const ['byBasic'])),
  ];

  test('2. canonical siblings count as one field', () {
    final direct = getSubBlocksDependingOnChange(subBlocks, 'manualCred');
    expect(
      direct.map((s) => s.id),
      unorderedEquals(['byCanonical', 'byBasic', 'byAdvanced']),
    );
  });

  test('3. unrelated dependants are excluded', () {
    final direct = getSubBlocksDependingOnChange(subBlocks, 'credential');
    expect(direct.map((s) => s.id), isNot(contains('unrelated')));
  });

  test('4. transitive chains with reasons', () {
    final dependents = getTransitiveSubBlockDependents(subBlocks, [
      'credential',
    ]);
    expect(
      dependents.map((d) => d.subBlockId),
      ['byCanonical', 'byBasic', 'byAdvanced', 'chained'],
    );
    expect(
      dependents.firstWhere((d) => d.subBlockId == 'chained').reason,
      'chained depends on byBasic',
    );
  });

  test('5. cycles terminate', () {
    final cyclic = [
      _cfg('a', dependsOn: DependsOn.fields(const ['b'])),
      _cfg('b', dependsOn: DependsOn.fields(const ['a'])),
    ];
    final dependents = getTransitiveSubBlockDependents(cyclic, ['a']);
    expect(dependents.map((d) => d.subBlockId), ['b']);
  });

  test("6. multiple seeds are not each other's dependents", () {
    final dependents = getTransitiveSubBlockDependents(
      subBlocks,
      ['credential', 'byBasic'],
    );
    expect(dependents.map((d) => d.subBlockId), isNot(contains('byBasic')));
    expect(dependents.map((d) => d.subBlockId), contains('chained'));
  });

  test('7. normalizeDependencyValue', () {
    expect(normalizeDependencyValue(null), isNull);
    expect(normalizeDependencyValue(const <Object?>[]), isNull);
    expect(
      normalizeDependencyValue(const [
        {'value': 'v'},
        {'id': 'i'},
      ]),
      ['v', 'i'],
    );
    expect(normalizeDependencyValue(const {'value': null}), isNull);
    expect(normalizeDependencyValue(const {'id': 7, 'value': 'x'}), 'x');
    expect(normalizeDependencyValue(const {'k': 1}), {'k': 1});
    expect(normalizeDependencyValue('s'), 's');
  });
}
