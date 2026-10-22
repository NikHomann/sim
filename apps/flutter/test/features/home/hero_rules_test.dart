// Failure modes (home-page.md States "Credits value", "Suggested: ...";
// credits-chip.tsx, conversion.ts, suggested-actions.tsx):
// - credits use the raw dollars, lose the en-US grouping, round wrongly, or
//   show a number at/over the unlimited threshold instead of "∞"; a null
//   remainder is not "Available"
// - billing management is decided on the wrong field (org admin for an
//   org-hosted workspace, the billed account otherwise)
// - the initial rows drift from upstream (Slack, Gmail, CRM starter, the
//   first featured GitHub template), or the hardcoded GitHub template no
//   longer matches the generated catalog
// - a connected workspace gets more or fewer than one connect row + three
//   prompts, two prompts from the same block, a connect row for an already
//   connected provider, or a non-connected provider prompt outweighing a
//   connected one
// - weighted sampling picks zero-weight items or repeats an item

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/home/hero/credits_chip.dart';
import 'package:sim_app/features/home/hero/suggested_actions.dart';
import 'package:sim_app/features/home/hero/suggestion_types.dart';

import '../../data/support/mocks.dart';

void main() {
  group('credits', () {
    test('label rules', () {
      expect(creditsLabel(null), 'Available');
      expect(creditsLabel(10), '2,000');
      expect(creditsLabel(0.004), '1');
      expect(creditsLabel(12345.67), '2,469,134');
      expect(creditsLabel(999998.99), '199,999,798');
      expect(creditsLabel(999999), '∞');
      expect(creditsLabel(5000000), '∞');
      expect(creditsLabel(0), '0');
    });

    test('who manages billing', () {
      final own = hostContext();
      expect(canManageWorkspaceBilling(own, userId), isTrue);
      expect(canManageWorkspaceBilling(own, 'someone-else'), isFalse);
      expect(
        creditsUnavailableMessage(own),
        'Only the workspace owner can manage billing.',
      );
      final org = hostContext(hostOrganizationId: 'org-1', isMember: true);
      expect(canManageWorkspaceBilling(org, userId), isFalse);
      expect(
        creditsUnavailableMessage(org),
        'Contact an organization admin to manage this workspace’s billing.',
      );
      final admin = WorkspaceHostContext(
        workspace: org.workspace,
        hostOrganizationId: 'org-1',
        ownerBilling: org.ownerBilling,
        viewer: const HostViewer(
          permission: WorkspacePermission.admin,
          isHostOrganizationMember: true,
          isHostOrganizationAdmin: true,
        ),
      );
      expect(canManageWorkspaceBilling(admin, 'not-the-payer'), isTrue);
    });
  });

  group('suggested actions', () {
    test('initial rows', () {
      expect(
        <String>[for (final a in initialSuggestedActions) a.label],
        <String>[
          'Integrate with Slack',
          'Integrate with Gmail',
          'Create a CRM with sample data',
          'Link GitHub pull requests to Jira tickets',
        ],
      );
    });

    test("the hardcoded GitHub row is the catalog's first featured GitHub "
        'template', () async {
      final catalog = await loadSuggestionCatalog();
      final first = catalog.templates.firstWhere(
        (t) => t.blockType == 'github' && t.featured,
      );
      expect(first.id, firstFeaturedGithubTemplate.id);
      expect(first.label, firstFeaturedGithubTemplate.label);
      expect(first.prompt, firstFeaturedGithubTemplate.prompt);
    });

    test('a connected workspace: one connect row for an unconnected '
        'service, three prompts from distinct blocks', () async {
      final catalog = await loadSuggestionCatalog();
      const signals = SuggestionSignals(
        connectedProviders: <String>{'google-email'},
        servicesLoaded: true,
      );
      for (var seed = 0; seed < 25; seed++) {
        final actions = computeSuggestedActions(
          catalog,
          signals,
          math.Random(seed),
        );
        expect(actions, hasLength(4));
        final connects = actions.whereType<IntegrationAction>().toList();
        expect(connects, hasLength(1));
        expect(connects.single.providerId, isNot('google-email'));
        final prompts = actions.whereType<PromptAction>().toList();
        expect(prompts, hasLength(3));
        final blocks = <String>{
          for (final p in prompts)
            catalog.templates.firstWhere((t) => t.id == p.id).blockType,
        };
        expect(blocks, hasLength(3));
      }
    });

    test('scoring boosts connected providers over unconnected ones', () {
      const connected = SuggestionTemplate(
        id: 'a',
        blockType: 'a',
        label: 'a',
        prompt: 'a',
        modules: <String>[],
        providerId: 'p1',
      );
      const unconnected = SuggestionTemplate(
        id: 'b',
        blockType: 'b',
        label: 'b',
        prompt: 'b',
        modules: <String>[],
        providerId: 'p2',
      );
      const signals = SuggestionSignals(connectedProviders: <String>{'p1'});
      expect(scoreSuggestion(connected, signals), 4);
      expect(scoreSuggestion(unconnected, signals), closeTo(0.4, 1e-9));
      const tableStarter = SuggestionTemplate(
        id: 't',
        blockType: 't',
        label: 't',
        prompt: 't',
        modules: <String>['tables'],
        popular: true,
      );
      expect(scoreSuggestion(tableStarter, const SuggestionSignals()), 2.25);
      expect(
        scoreSuggestion(
          tableStarter,
          const SuggestionSignals(hasTables: true),
        ),
        1.5,
      );
    });

    test('weighted sampling never picks zero weights or repeats', () {
      final random = math.Random(1);
      for (var i = 0; i < 50; i++) {
        final picked = weightedSample<int>(
          <int>[0, 1, 2, 3],
          3,
          (n) => n == 0 ? 0 : 1,
          random,
        );
        expect(picked, isNot(contains(0)));
        expect(picked.toSet(), hasLength(picked.length));
        expect(picked, hasLength(3));
      }
      expect(
        weightedSample<int>(<int>[1], 2, (_) => 0, random),
        isEmpty,
      );
    });

    test('personalisation needs both loaded services and a connection', () {
      expect(const SuggestionSignals().personalized, isFalse);
      expect(
        const SuggestionSignals(servicesLoaded: true).personalized,
        isFalse,
      );
      expect(
        const SuggestionSignals(
          connectedProviders: <String>{'x'},
        ).personalized,
        isFalse,
      );
      expect(
        const SuggestionSignals(
          connectedProviders: <String>{'x'},
          servicesLoaded: true,
        ).personalized,
        isTrue,
      );
    });
  });
}
