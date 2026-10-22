// Failure modes for canonical basic/advanced pair resolution
// (port of apps/sim/lib/workflows/subblocks/visibility.ts):
//  buildCanonicalIndex
//   1. Sub-blocks without canonicalParamId are not indexed.
//   2. A trigger-mode member never overwrites a basicId claimed by a
//      non-trigger member, but claims it when nothing else has.
//   3. Advanced ids are deduplicated when a trigger spread repeats one.
//   4. A group with only advanced members is not a pair; one basic + one
//      advanced is.
//  resolveCanonicalMode
//   5. Override 'advanced' wins only when the group has advanced ids;
//      override 'basic' only when it has a basicId.
//   6. No override: basic when basic has a value or both empty; advanced only
//      when basic is empty and advanced is set; no basicId → advanced.
//   7. isNonEmptyValue: '', '  ', [], null → empty; 0, false, {} → non-empty.
//  getCanonicalValues / resolveActiveCanonicalValue
//   8. The first non-empty advanced member wins and is reported as source.
//   9. The active value is strict: a stale dormant-mode value never leaks.
//  resolveDependencyValue / resolveActiveDependencyValue
//  10. Dependency lookup by canonical id, by member id, and by plain key.
//  11. Permissive fallback across modes, then across other members, then the
//      raw key; active lookup has no fallback.
//  Visibility
//  12. isSubBlockVisibleForMode: pair members follow the resolved mode;
//      standalone `advanced` / `trigger-advanced` need the toggle; `basic`
//      hides when the toggle is on.
//  13. Trigger-mode visibility: `trigger-config` shows in trigger mode or on a
//      pure trigger block; trigger fields only in trigger mode; others only
//      outside it.
//  14. hasAdvancedValues sees pair advanced values and standalone advanced
//      values, but not basic ones.
//  15. buildDefaultCanonicalModes marks only pairs as 'basic'.
//  16. getCanonicalSubBlocksForSurface keeps only trigger members on the
//      trigger surface.
//  Tool-scoped overrides
//  17. scopeCanonicalModesForTool layers index-scoped over legacy type-scoped
//      keys per canonical id and returns null when nothing matches.
//  18. reindexCanonicalModesByPosition moves surviving keys, drops removed
//      ones, keeps legacy keys and returns null when unchanged.
import 'package:sim_workflow/sim_workflow.dart';
import 'package:test/test.dart';

SubBlockConfig _cfg(
  String id, {
  String? canonical,
  SubBlockMode? mode,
  String type = 'short-input',
}) => SubBlockConfig(
  id: id,
  type: type,
  canonicalParamId: canonical,
  mode: mode,
);

final List<SubBlockConfig> _pair = [
  _cfg('picker', canonical: 'tableId', type: 'table-selector'),
  _cfg('manualId', canonical: 'tableId', mode: SubBlockMode.advanced),
  _cfg('other'),
];

void main() {
  group('buildCanonicalIndex', () {
    test('1. non-canonical sub-blocks are not indexed', () {
      final index = buildCanonicalIndex(_pair);
      expect(index.canonicalIdBySubBlockId.containsKey('other'), isFalse);
      expect(index.groupsById.keys, ['tableId']);
    });

    test('2. trigger members never overwrite a non-trigger basicId', () {
      final index = buildCanonicalIndex([
        _cfg('siteSelector', canonical: 'siteId'),
        _cfg('triggerSiteId', canonical: 'siteId', mode: SubBlockMode.trigger),
      ]);
      expect(index.groupsById['siteId']!.basicId, 'siteSelector');
      final triggerFirst = buildCanonicalIndex([
        _cfg('triggerSiteId', canonical: 'siteId', mode: SubBlockMode.trigger),
        _cfg('siteSelector', canonical: 'siteId'),
      ]);
      expect(triggerFirst.groupsById['siteId']!.basicId, 'siteSelector');
      final onlyTrigger = buildCanonicalIndex([
        _cfg('triggerSiteId', canonical: 'siteId', mode: SubBlockMode.trigger),
      ]);
      expect(onlyTrigger.groupsById['siteId']!.basicId, 'triggerSiteId');
    });

    test('3. advanced ids are deduplicated', () {
      final index = buildCanonicalIndex([
        _cfg('p', canonical: 'c'),
        _cfg('m', canonical: 'c', mode: SubBlockMode.advanced),
        _cfg('m', canonical: 'c', mode: SubBlockMode.triggerAdvanced),
      ]);
      expect(index.groupsById['c']!.advancedIds, ['m']);
    });

    test('4. pair detection', () {
      final index = buildCanonicalIndex([
        _cfg('m', canonical: 'c', mode: SubBlockMode.advanced),
      ]);
      expect(isCanonicalPair(index.groupsById['c']), isFalse);
      expect(
        isCanonicalPair(buildCanonicalIndex(_pair).groupsById['tableId']),
        isTrue,
      );
      expect(isCanonicalPair(null), isFalse);
    });
  });

  group('resolveCanonicalMode', () {
    final group = buildCanonicalIndex(_pair).groupsById['tableId']!;

    test('5. overrides are honoured only when applicable', () {
      expect(
        resolveCanonicalMode(group, const {}, {
          'tableId': CanonicalMode.advanced,
        }),
        CanonicalMode.advanced,
      );
      final advancedOnly = buildCanonicalIndex([
        _cfg('m', canonical: 'c', mode: SubBlockMode.advanced),
      ]).groupsById['c']!;
      expect(
        resolveCanonicalMode(advancedOnly, const {}, {
          'c': CanonicalMode.basic,
        }),
        CanonicalMode.advanced,
      );
      final basicOnly = buildCanonicalIndex([
        _cfg('p', canonical: 'c'),
      ]).groupsById['c']!;
      expect(
        resolveCanonicalMode(basicOnly, const {}, {
          'c': CanonicalMode.advanced,
        }),
        CanonicalMode.basic,
      );
    });

    test('6. value heuristic', () {
      expect(resolveCanonicalMode(group, const {}), CanonicalMode.basic);
      expect(
        resolveCanonicalMode(group, const {'picker': 'a', 'manualId': 'b'}),
        CanonicalMode.basic,
      );
      expect(
        resolveCanonicalMode(group, const {'manualId': 'b'}),
        CanonicalMode.advanced,
      );
      expect(
        resolveCanonicalMode(group, const {'picker': '  ', 'manualId': 'b'}),
        CanonicalMode.advanced,
      );
    });

    test('7. isNonEmptyValue', () {
      expect(isNonEmptyValue(''), isFalse);
      expect(isNonEmptyValue('  '), isFalse);
      expect(isNonEmptyValue(const <Object?>[]), isFalse);
      expect(isNonEmptyValue(null), isFalse);
      expect(isNonEmptyValue(0), isTrue);
      expect(isNonEmptyValue(false), isTrue);
      expect(isNonEmptyValue(const <String, Object?>{}), isTrue);
    });
  });

  group('values', () {
    final index = buildCanonicalIndex([
      _cfg('p', canonical: 'c'),
      _cfg('a1', canonical: 'c', mode: SubBlockMode.advanced),
      _cfg('a2', canonical: 'c', mode: SubBlockMode.triggerAdvanced),
    ]);
    final group = index.groupsById['c']!;

    test('8. first non-empty advanced member wins', () {
      final selection = getCanonicalValues(group, const {'a1': '', 'a2': 'x'});
      expect(selection.advancedValue, 'x');
      expect(selection.advancedSourceId, 'a2');
      expect(selection.basicValue, isNull);
    });

    test('9. active value is strict', () {
      expect(
        resolveActiveCanonicalValue(
          group,
          const {'p': '', 'a1': 'stale'},
          {'c': CanonicalMode.basic},
        ),
        '',
      );
      expect(
        resolveActiveCanonicalValue(group, const {'p': 'live', 'a1': 'stale'}),
        'live',
      );
    });

    test('10. dependency lookup by canonical id, member id and plain key', () {
      const values = {'p': 'basic', 'other': 'o'};
      expect(resolveDependencyValue('c', values, index), 'basic');
      expect(resolveDependencyValue('a1', values, index), 'basic');
      expect(resolveDependencyValue('other', values, index), 'o');
      expect(resolveActiveDependencyValue('a1', values, index), 'basic');
    });

    test('11. permissive fallback vs strict active', () {
      const values = {'a2': 'deep'};
      expect(resolveDependencyValue('c', values, index), 'deep');
      expect(
        resolveDependencyValue('c', values, index, {'c': CanonicalMode.basic}),
        'deep',
      );
      expect(
        resolveActiveDependencyValue(
          'c',
          values,
          index,
          {'c': CanonicalMode.basic},
        ),
        isNull,
      );
      expect(resolveDependencyValue('c', const {'c': 'raw'}, index), 'raw');
    });
  });

  group('visibility', () {
    final index = buildCanonicalIndex(_pair);

    test('12. mode visibility', () {
      final picker = _pair[0];
      final manual = _pair[1];
      expect(
        isSubBlockVisibleForMode(picker, false, index, const {}),
        isTrue,
      );
      expect(
        isSubBlockVisibleForMode(manual, false, index, const {}),
        isFalse,
      );
      expect(
        isSubBlockVisibleForMode(manual, false, index, const {'manualId': 'x'}),
        isTrue,
      );
      expect(
        isSubBlockVisibleForMode(
          picker,
          true,
          index,
          const {},
          {'tableId': CanonicalMode.advanced},
        ),
        isFalse,
      );
      final standaloneAdvanced = _cfg('adv', mode: SubBlockMode.advanced);
      expect(
        isSubBlockVisibleForMode(standaloneAdvanced, false, index, const {}),
        isFalse,
      );
      expect(
        isSubBlockVisibleForMode(standaloneAdvanced, true, index, const {}),
        isTrue,
      );
      final basic = _cfg('b', mode: SubBlockMode.basic);
      expect(isSubBlockVisibleForMode(basic, true, index, const {}), isFalse);
      expect(isSubBlockVisibleForMode(basic, false, index, const {}), isTrue);
    });

    test('13. trigger-mode visibility', () {
      final triggerConfig = _cfg('tc', type: 'trigger-config');
      final triggerField = _cfg('tf', mode: SubBlockMode.trigger);
      final plain = _cfg('p');
      expect(isSubBlockVisibleForTriggerMode(triggerConfig, false), isFalse);
      expect(
        isSubBlockVisibleForTriggerMode(
          triggerConfig,
          false,
          const TriggerVisibilityBlockConfig(
            category: BlockCategory.triggers,
            triggersEnabled: true,
          ),
        ),
        isTrue,
      );
      expect(isSubBlockVisibleForTriggerMode(triggerConfig, true), isTrue);
      expect(isSubBlockVisibleForTriggerMode(triggerField, true), isTrue);
      expect(isSubBlockVisibleForTriggerMode(triggerField, false), isFalse);
      expect(isSubBlockVisibleForTriggerMode(plain, true), isFalse);
      expect(isSubBlockVisibleForTriggerMode(plain, false), isTrue);
    });

    test('14. hasAdvancedValues', () {
      final subBlocks = [..._pair, _cfg('adv', mode: SubBlockMode.advanced)];
      final idx = buildCanonicalIndex(subBlocks);
      expect(hasAdvancedValues(subBlocks, const {'picker': 'x'}, idx), isFalse);
      expect(
        hasAdvancedValues(subBlocks, const {'manualId': 'x'}, idx),
        isTrue,
      );
      expect(hasAdvancedValues(subBlocks, const {'adv': 'x'}, idx), isTrue);
    });

    test('15. default canonical modes', () {
      expect(buildDefaultCanonicalModes(_pair), {
        'tableId': CanonicalMode.basic,
      });
      expect(
        buildDefaultCanonicalModes([
          _cfg('m', canonical: 'c', mode: SubBlockMode.advanced),
        ]),
        isEmpty,
      );
    });

    test('16. trigger surface keeps trigger members only', () {
      final subBlocks = [
        ..._pair,
        _cfg('triggerSiteId', canonical: 'tableId', mode: SubBlockMode.trigger),
        _cfg('tc', type: 'trigger-config'),
      ];
      expect(
        getCanonicalSubBlocksForSurface(subBlocks, triggerSurface: false),
        same(subBlocks),
      );
      final scoped = getCanonicalSubBlocksForSurface(
        subBlocks,
        triggerSurface: true,
      );
      expect(scoped.map((s) => s.id), ['triggerSiteId', 'tc']);
      final index = buildCanonicalIndexForSurface(
        subBlocks,
        triggerSurface: true,
      );
      expect(index.groupsById['tableId']!.basicId, 'triggerSiteId');
    });
  });

  group('tool-scoped overrides', () {
    test('17. scopeCanonicalModesForTool', () {
      final overrides = {
        '0:credential': CanonicalMode.advanced,
        'table:credential': CanonicalMode.basic,
        'table:tableId': CanonicalMode.advanced,
        '1:tableId': CanonicalMode.basic,
      };
      expect(
        scopeCanonicalModesForTool(overrides, 0, 'table'),
        {
          'credential': CanonicalMode.advanced,
          'tableId': CanonicalMode.advanced,
        },
      );
      expect(
        scopeCanonicalModesForTool(overrides, 1),
        {'tableId': CanonicalMode.basic},
      );
      expect(scopeCanonicalModesForTool(overrides, 5), isNull);
      expect(scopeCanonicalModesForTool(null, 0, 'table'), isNull);
      expect(
        scopeCanonicalModesForTool(overrides, null, 'table'),
        {'credential': CanonicalMode.basic, 'tableId': CanonicalMode.advanced},
      );
    });

    test('18. reindexCanonicalModesByPosition', () {
      final overrides = {
        '0:a': CanonicalMode.advanced,
        '1:b': CanonicalMode.basic,
        'legacy:c': CanonicalMode.advanced,
      };
      expect(
        reindexCanonicalModesByPosition({0: 1, 1: 0}, overrides),
        {
          '1:a': CanonicalMode.advanced,
          '0:b': CanonicalMode.basic,
          'legacy:c': CanonicalMode.advanced,
        },
      );
      expect(
        reindexCanonicalModesByPosition({0: 0}, overrides),
        {'0:a': CanonicalMode.advanced, 'legacy:c': CanonicalMode.advanced},
      );
      expect(reindexCanonicalModesByPosition({0: 0, 1: 1}, overrides), isNull);
      expect(reindexCanonicalModesByPosition({}, null), isNull);
    });
  });
}
