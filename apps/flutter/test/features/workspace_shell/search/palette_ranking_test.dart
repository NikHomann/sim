// Failure modes of the palette ranking (`search-modal/utils.ts`), each a
// test below:
// 1. an empty query must match everything (score 1) and browse lists are
//    never capped (`filterAndCap`);
// 2. substring scoring: exact > prefix > other, boundary bonuses, earlier
//    and shorter candidates first;
// 3. a scattered subsequence must start at a hard boundary ("oge" must not
//    match "Postgres"; "slk" must match "Slack");
// 4. multi-word queries match order-independently ("sheets google");
// 5. secondary text never scatter-matches across unrelated words
//    ("whatsapp" vs "Wealthbox Write Contact match snap up"), but matches
//    by substring and whole tokens;
// 6. a name match always outranks a secondary-text match (NAME tier);
// 7. a query that fuzzy-matches a section label fills the section with its
//    remaining rows below the matches; equality lifts the section to the
//    SECTION tier in natural order; tool operations are exempt;
// 8. actions: word-start matches get +500 000, a mid-word name hit does not,
//    `exactQueries` rank at the PAGE tier;
// 9. the flat results are a stable sort: ties keep section order, then
//    in-section order; the per-section cap is 50;
// 10. the new matcher is a strict superset of the old substring matcher
//     and keeps its top result (upstream's no-regression corpus).

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/workspace_shell/search/palette_models.dart';
import 'package:sim_app/features/workspace_shell/search/palette_ranking.dart';
import 'package:sim_design/sim_design.dart';

PaletteAction action(
  String name, {
  String? keywords,
  List<String> exactQueries = const [],
  String? id,
}) => PaletteAction(
  id: id ?? name.toLowerCase().replaceAll(' ', '-'),
  name: name,
  keywords: keywords,
  exactQueries: exactQueries,
  icon: SimEmcnIcons.plus,
  run: () {},
);

String _id(String s) => s;

void main() {
  group('1. empty query', () {
    test('matches everything with score 1', () {
      final result = fuzzyMatch('anything', '');
      expect(result.matched, isTrue);
      expect(result.score, 1);
    });

    test('browse is never capped, search is capped at 50', () {
      final items = [
        for (var i = 0; i < maxResultsPerGroup + 25; i++) 'item $i',
      ];
      expect(filterAndCap(items, _id, ''), same(items));
      expect(filterAndCap(items, _id, 'item'), hasLength(maxResultsPerGroup));
    });
  });

  group('2. substring scoring', () {
    test('exact beats prefix beats mid-string', () {
      final exact = fuzzyMatch('Slack', 'slack').score;
      final prefix = fuzzyMatch('Slack Send', 'slack').score;
      final inner = fuzzyMatch('Big Slack', 'slack').score;
      expect(exact, greaterThan(prefix));
      expect(prefix, greaterThan(inner));
    });

    test('scores follow the upstream constants', () {
      // index 0: 1 + 10 + 24 + 120 - 0 - 0.6 - 0.5
      expect(fuzzyMatch('Slack', 'slack').score, closeTo(153.9, 1e-9));
      // after a separator at 4: 1 + 8 + 24 + 25 - 2 - 0.6 - 0.9
      expect(fuzzyMatch('Big Slack', 'slack').score, closeTo(54.5, 1e-9));
      // camelCase hump at 4: 1 + 6 + 6 + 25 - 2 - 0.15 - 0.9
      expect(fuzzyMatch('PageSpeed', 'sp').score, closeTo(34.95, 1e-9));
    });

    test('positions are the substring indices', () {
      expect(fuzzyMatch('Big Slack', 'sla').positions, [4, 5, 6]);
    });
  });

  group('3. scattered subsequence', () {
    test('must start at a hard boundary', () {
      expect(fuzzyMatch('Postgres', 'oge').matched, isFalse);
      expect(fuzzyMatch('Google PageSpeed', 'slack').matched, isFalse);
    });

    test('initialisms match from a word start', () {
      final result = fuzzyMatch('Slack', 'slk');
      expect(result.matched, isTrue);
      expect(result.positions, [0, 1, 4]);
      expect(fuzzyMatch('create-workflow', 'crwf').matched, isTrue);
    });

    test('scatter can be disabled', () {
      expect(fuzzyMatch('Slack', 'slk', scatter: false).matched, isFalse);
    });
  });

  test('4. multi-word queries match in any order', () {
    final result = fuzzyMatch('Google Sheets', 'sheets google');
    expect(result.matched, isTrue);
    expect(result.score, closeTo(10 - 13 * 0.1, 1e-9));
    expect(fuzzyMatch('Google Sheets', 'sheets').matched, isTrue);
    expect(fuzzyMatch('Sheets', 'sheets google').matched, isFalse);
  });

  group('5. secondary text', () {
    test('never scatter-matches across unrelated words', () {
      final items = [
        (name: 'Write Contact', extra: 'Wealthbox Write Contact match snap up'),
      ];
      expect(fuzzyMatch(items.first.extra, 'whatsapp').matched, isTrue);
      expect(
        filterAndSort(
          items,
          (i) => i.name,
          'whatsapp',
          toExtra: (i) => i.extra,
        ),
        isEmpty,
      );
    });

    test('matches by substring and by whole tokens', () {
      final items = [
        (name: 'Send Message', extra: 'Slack Send Message dm chat'),
      ];
      String extra(({String name, String extra}) i) => i.extra;
      expect(
        filterAndSort(items, (i) => i.name, 'slack', toExtra: extra),
        hasLength(1),
      );
      expect(
        filterAndSort(items, (i) => i.name, 'slack chat', toExtra: extra),
        hasLength(1),
      );
    });

    test('scatters within one kebab token', () {
      final items = [(name: 'Op', extra: 'slack send-message')];
      expect(
        filterAndSort(items, (i) => i.name, 'sndmsg', toExtra: (i) => i.extra),
        hasLength(1),
      );
    });
  });

  test('6. an exact name beats a long secondary string', () {
    final items = [
      (name: 'Pi Coding Agent', extra: 'Pi Coding Agent pi ${'model-x ' * 60}'),
      (name: 'Agent', extra: 'Agent agent ${'claude gpt ' * 60}'),
    ];
    final sorted = filterAndSort(
      items,
      (i) => i.name,
      'agent',
      toExtra: (i) => i.extra,
    );
    expect(sorted.first.name, 'Agent');
    final scored = scoreAndSort(items, (i) => i.name, 'agent');
    expect(scored.first.score, greaterThan(nameMatchTier));
  });

  group('7. section label matching', () {
    final workflows = ['Alpha', 'Beta flow', 'Gamma'];

    test('a partial label match fills the section below its matches', () {
      final ranked = scoreSectionItems(
        SearchSection.workflows,
        workflows,
        _id,
        'flow',
      );
      expect(ranked.map((s) => s.item), ['Beta flow', 'Alpha', 'Gamma']);
      // min(label score, lowest match - 1): the label score here.
      expect(ranked[1].score, fuzzyMatch('Workflows', 'flow').score);
      expect(ranked[1].score, ranked[2].score);
    });

    test('the fill stops at the cap', () {
      final ranked = scoreSectionItems(
        SearchSection.workflows,
        workflows,
        _id,
        'flow',
        maxResults: 2,
      );
      expect(ranked.map((s) => s.item), ['Beta flow', 'Alpha']);
    });

    test('a label-equal query lifts the section in natural order', () {
      final ranked = scoreSectionItems(
        SearchSection.workflows,
        workflows,
        _id,
        'Workflows',
      );
      expect(ranked.map((s) => s.item), workflows);
      expect(ranked.map((s) => s.score), [
        sectionMatchTier,
        sectionMatchTier - 1,
        sectionMatchTier - 2,
      ]);
    });

    test('tool operations never fill or lift from their label', () {
      final ops = ['Send Message', 'Create Row'];
      expect(
        scoreSectionItems(
          SearchSection.toolOperations,
          ops,
          _id,
          'tool operations',
        ),
        isEmpty,
      );
      expect(
        scoreSectionItems(SearchSection.toolOperations, ops, _id, 'tool'),
        isEmpty,
      );
      expect(
        scoreSectionItems(
          SearchSection.toolOperations,
          ops,
          _id,
          'send',
        ).map((s) => s.item),
        ['Send Message'],
      );
    });
  });

  group('8. actions', () {
    test('a word-start match carries the bias over an equal entity', () {
      final newChat = action('New chat', keywords: 'message conversation');
      final [match] = scoreActions([newChat], 'new c');
      final [entity] = scoreAndSort(['New chat'], _id, 'new c');
      expect(match.score, entity.score + actionMatchBias);
    });

    test('a mid-word name hit keeps its honest score', () {
      final newChat = action('New chat');
      final [match] = scoreActions([newChat], 'hat');
      final [entity] = scoreAndSort(['New chat'], _id, 'hat');
      expect(match.score, entity.score);
    });

    test('exactQueries rank at the page tier', () {
      final deploy = action('Deploy workflow', exactQueries: ['deploy']);
      expect(scoreActions([deploy], 'Deploy ').single.score, pageMatchTier);
    });

    test('the group label lifts every action, bias included', () {
      final list = [action('Create folder'), action('Import workflow')];
      final ranked = scoreActions(list, 'sim');
      expect(ranked.map((s) => s.score), [
        sectionMatchTier + actionMatchBias,
        sectionMatchTier - 1 + actionMatchBias,
      ]);
    });

    test('keywords match as secondary text', () {
      final invite = action('Invite teammates', keywords: 'members people');
      final [match] = scoreActions([invite], 'people');
      expect(match.score, lessThan(nameMatchTier + actionMatchBias));
      expect(match.score, greaterThan(actionMatchBias));
    });
  });

  group('9. flat results', () {
    PaletteEntry entry(SearchSection section, String id, double score) =>
        PaletteEntry(
          section,
          PaletteTaskItem(id: id, name: id, href: '/$id'),
          score,
        );

    test('merge-ranks by score, ties in section then natural order', () {
      final results = globalSearchResults(
        {
          SearchSection.chats: [entry(SearchSection.chats, 'c1', 5)],
          SearchSection.workflows: [
            entry(SearchSection.workflows, 'w1', 5),
            entry(SearchSection.workflows, 'w2', 5),
          ],
          SearchSection.actions: [entry(SearchSection.actions, 'a1', 9)],
        },
        [SearchSection.actions, SearchSection.workflows, SearchSection.chats],
      );
      expect(results.map((e) => e.id), ['a1', 'w1', 'w2', 'c1']);
    });

    test('ties keep the given section order (a hoisted section first)', () {
      final results = globalSearchResults(
        {
          SearchSection.pages: [entry(SearchSection.pages, 'p', 1)],
          SearchSection.tables: [entry(SearchSection.tables, 't', 1)],
        },
        [SearchSection.actions, SearchSection.tables, SearchSection.pages],
      );
      expect(results.map((e) => e.id), ['t', 'p']);
    });
  });

  group('10. no regression against the old substring matcher', () {
    double oldScore(String value, String search) {
      if (search.isEmpty) return 1;
      final v = value.toLowerCase();
      final s = search.toLowerCase();
      if (v == s) return 1;
      if (v.startsWith(s)) return 0.9;
      if (v.contains(s)) return 0.7;
      final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      if (words.length > 1 && words.every(v.contains)) return 0.5;
      return 0;
    }

    List<String> oldFilter(List<(String, String)> items, String search) {
      final scored = [
        for (final item in items)
          if (oldScore(item.$2, search) > 0)
            (item.$1, oldScore(item.$2, search)),
      ];
      final sorted = [...scored];
      for (var i = 1; i < sorted.length; i++) {
        final current = sorted[i];
        var j = i - 1;
        while (j >= 0 && sorted[j].$2 < current.$2) {
          sorted[j + 1] = sorted[j];
          j--;
        }
        sorted[j + 1] = current;
      }
      return [for (final s in sorted) s.$1];
    }

    (String, String) block(String label, String slug) =>
        (label, '$label $slug block-$slug');
    (String, String) workflow(String label, String folder) => (
      label,
      '$label $folder workflow-${label.toLowerCase().replaceAll(' ', '')}-9f2a3b4c5d6e',
    );
    (String, String) act(String label, String keywords) => (
      label,
      '$label $keywords action-${label.toLowerCase().replaceAll(' ', '-')}',
    );

    final corpus = [
      block('Slack', 'slack'),
      block('Gmail', 'gmail'),
      block('Google Sheets', 'google_sheets'),
      block('Google PageSpeed', 'google_pagespeed'),
      block('GitHub', 'github'),
      block('Notion', 'notion'),
      block('Postgres', 'postgresql'),
      block('OpenAI', 'openai'),
      block('Airtable', 'airtable'),
      block('HubSpot', 'hubspot'),
      block('Linear', 'linear'),
      block('Discord', 'discord'),
      block('Microsoft Teams', 'microsoft_teams'),
      block('Webhook', 'webhook'),
      block('Schedule', 'schedule'),
      block('Agent', 'agent'),
      block('Function', 'function'),
      block('Condition', 'condition'),
      block('Router', 'router'),
      block('Knowledge Base', 'knowledge'),
      workflow('Customer Onboarding Flow', 'Sales'),
      workflow('Daily Report', 'Ops'),
      workflow('Lead Enrichment', 'Sales'),
      act('Create workflow', 'new add build'),
      act('Create folder', 'new add group'),
      act('Import workflow', 'upload add'),
      act('Toggle theme', 'dark light mode appearance color'),
    ];
    const queries = [
      's',
      'g',
      'a',
      'w',
      'slack',
      'gmail',
      'github',
      'notion',
      'postgres',
      'openai',
      'agent',
      'goog',
      'micro',
      'know',
      'cond',
      'rout',
      'sched',
      'hook',
      'table',
      'spot',
      'mail',
      'google sheets',
      'sheets google',
      'create workflow',
      'workflow create',
      'customer onboarding',
      'slk',
      'gps',
      'msteams',
      'crwf',
      'cwf',
      'kb',
      'githb',
      'postgrs',
      'zzz',
      'qqqq',
    ];

    List<String> newFilter(String query) => [
      for (final item in filterAndSort(corpus, (e) => e.$2, query)) item.$1,
    ];

    test('every old result is still returned', () {
      for (final query in queries) {
        final fresh = newFilter(query).toSet();
        for (final label in oldFilter(corpus, query)) {
          expect(fresh, contains(label), reason: 'query "$query" lost $label');
        }
      }
    });

    test('exact/prefix/contains queries keep the old top result', () {
      const exactish = [
        'slack',
        'gmail',
        'github',
        'notion',
        'postgres',
        'openai',
        'agent',
        'goog',
        'micro',
        'know',
        'cond',
        'rout',
        'sched',
      ];
      for (final query in exactish) {
        final oldTop = oldFilter(corpus, query);
        if (oldTop.isEmpty) continue;
        expect(newFilter(query).first, oldTop.first, reason: query);
      }
    });

    test('every g-prefixed result outranks inner g matches', () {
      final labels = newFilter('g');
      final firstNonPrefix = labels.indexWhere(
        (l) => !l.toLowerCase().startsWith('g'),
      );
      final lastPrefix = labels.lastIndexWhere(
        (l) => l.toLowerCase().startsWith('g'),
      );
      expect(lastPrefix, lessThan(firstNonPrefix));
    });
  });

  test('toSearchToken kebab-cases a phrase', () {
    expect(toSearchToken('  Send  Message '), 'Send-Message');
    expect(toSearchToken('Sales'), 'Sales');
  });
}
