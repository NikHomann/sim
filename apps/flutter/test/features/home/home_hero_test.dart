// Failure modes (home-page.md Layout "Empty state (hero)", "Suggested
// actions", States "Credits ...", parity rows 24-41):
// - the heading uses the full name, or shows ", " without a name
// - the cluster is not centred in the 2vh/22vh padded column, or the
//   composer is not 704px at x 480.5..1184.5, y 338..442 at 1440×900
// - expanding/collapsing the suggestions moves the composer
// - the suggested section does not sit 28px under the composer, or has
//   other than four rows, or its rows are not 36px (+1px border) tall
// - the collapsed panel loses its parity box at the row's right edge
// - a prompt row sends instead of populating the composer
// - signals from a connected workspace do not personalise the rows, or a
//   workspace without connections loses the fixed rows
// - the credits chip shows without billing, for an enterprise owner, while
//   loading or after a failure; requests credit availability when hidden
//   by billing/enterprise; shows the clickable chip to a non-manager or the
//   tag to the manager; links anywhere but the upgrade page
// - the chip does not sit beside the collapsed toggle (right 57) and at
//   the standard inset (right 16) once the panel is open
// - the hero shows while a routed chat's history is pending

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/placeholder_slots.dart';
import 'package:sim_design/sim_design.dart';

import 'support/home_harness.dart';

Finder _rowLabels() => find.descendant(
  of: byParityId('home.suggested'),
  matching: find.byType(SimOverflowText),
);

List<String> _labels(WidgetTester tester) => <String>[
  for (final w in tester.widgetList<SimOverflowText>(_rowLabels())) w.label,
];

void main() {
  late HomeHarness h;

  setUp(() async {
    h = HomeHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  group('heading', () {
    testWidgets('greets the first word of the name', (tester) async {
      h.signInAs('Ada Lovelace');
      await h.pump(tester, homePath);
      expect(find.text('What should we get done, Ada?'), findsOneWidget);
    });

    testWidgets('no name: no greeting', (tester) async {
      h.signInAs(null);
      await h.pump(tester, homePath);
      expect(find.text('What should we get done?'), findsOneWidget);
    });
  });

  testWidgets('hero geometry at 1440×900 and the out-of-flow suggestions', (
    tester,
  ) async {
    await h.pump(tester, homePath);
    expect(
      rectOf(tester, 'chat-input.root'),
      const Rect.fromLTRB(
        480.5,
        338,
        1184.5,
        442,
      ),
    );
    expect(rectOf(tester, 'home.hero.heading').top, 278);
    expect(rectOf(tester, 'home.suggested').top, 470);
    expect(rectOf(tester, 'home.suggested').left, 480.5);
    expect(rectOf(tester, 'home.suggested').width, 704);
    expect(rectOf(tester, 'home.suggested.row').top, 470 + 18 + 6);
    // Rows are 8 + 20 (`text-sm` line) + 8, the later three +1px border:
    // 18 + 6 + 36 + 3 × 37 = 171 (React capture).
    expect(rectOf(tester, 'home.suggested.row').height, 36);
    expect(rectOf(tester, 'home.suggested').height, 171);
    // The collapsed panel's id stays at the row's right edge (React: 0px box
    // at x 1440).
    expect(rectOf(tester, 'home.panel').left, closeTo(1440, 0.01));
    expect(
      rectOf(tester, 'home.panel.toggle'),
      const Rect.fromLTRB(
        1394,
        5,
        1424,
        35,
      ),
    );
    // Collapsing the suggestions never moves the composer.
    await tester.tap(find.text('Suggested actions'));
    await settle(tester);
    expect(_labels(tester), isEmpty);
    expect(rectOf(tester, 'chat-input.root').top, 338);
  });

  testWidgets('initial rows; a prompt row populates without sending', (
    tester,
  ) async {
    await h.pump(tester, homePath);
    expect(_labels(tester), <String>[
      'Integrate with Slack',
      'Integrate with Gmail',
      'Create a CRM with sample data',
      'Link GitHub pull requests to Jira tickets',
    ]);
    await tester.tap(find.text('Create a CRM with sample data'));
    await settle(tester);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(PlaceholderComposer),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, 'Create a CRM with sample data.');
    expect(h.session.sent, isEmpty);
    expect(byParityId('home.empty'), findsOneWidget);
  });

  testWidgets('a connected workspace gets one connect row and three prompts', (
    tester,
  ) async {
    h.http.answer('/api/credentials', <String, Object?>{
      'credentials': <Object?>[
        <String, Object?>{'type': 'oauth', 'providerId': 'google-email'},
      ],
    });
    await tester.runAsync(() async {
      await h.pump(tester, homePath);
      // The deferred catalog loads outside the fake clock.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
    final labels = _labels(tester);
    expect(labels, hasLength(4));
    expect(labels.where((l) => l.startsWith('Integrate with ')), hasLength(1));
    expect(labels, isNot(contains('Integrate with Gmail')));
    expect(h.http.count('/api/credentials'), 1);
    expect(h.http.count('/api/auth/oauth/connections'), 1);
    expect(h.http.count('/api/knowledge'), 1);
  });

  group('credits chip', () {
    testWidgets('hidden without billing, and not requested', (tester) async {
      await h.pump(tester, homePath);
      expect(find.byType(SimChip), findsNothing);
      expect(find.byType(SimChipTag), findsNothing);
      expect(
        h.http.count('/api/workspaces/$workspaceId/credit-availability'),
        0,
      );
    });

    testWidgets('owner: clickable chip to the upgrade page, beside the '
        'collapsed toggle', (tester) async {
      h
        ..billingEnabled = true
        ..stubDeployment();
      await h.pump(tester, homePath);
      final chip = find.descendant(
        of: byParityId('home.credits'),
        matching: find.byType(SimChip),
      );
      expect(chip, findsOneWidget);
      expect(find.text('2,000'), findsOneWidget);
      expect(rectOf(tester, 'home.credits').right, 1440 - 57);
      await tester.tap(chip);
      await settle(tester);
      expect(h.location, '/workspace/$workspaceId/upgrade?reason=credits');
    });

    testWidgets('moves to the standard inset when the panel opens', (
      tester,
    ) async {
      h
        ..billingEnabled = true
        ..stubDeployment();
      await h.pump(tester, homePath);
      await tester.tap(byParityId('home.panel.toggle'));
      await settle(tester);
      expect(rectOf(tester, 'home.credits').right, 1440 - 607.5 - 16);
    });

    testWidgets('non-manager: tag with the admin tooltip', (tester) async {
      h
        ..billingEnabled = true
        ..stubDeployment(hostOrganizationId: 'org-1');
      await h.pump(tester, homePath);
      expect(find.byType(SimChipTag), findsOneWidget);
      expect(
        find.descendant(
          of: byParityId('home.credits'),
          matching: find.byType(SimChip),
        ),
        findsNothing,
      );
      final tooltip = tester.widget<SimTooltip>(
        find.ancestor(
          of: find.byType(SimChipTag),
          matching: find.byType(SimTooltip),
        ),
      );
      expect(
        tooltip.message,
        'Contact an organization admin to manage this workspace’s billing.',
      );
    });

    testWidgets('"Available" for an unknown remainder', (tester) async {
      h
        ..billingEnabled = true
        ..stubDeployment();
      h.http.answer(
        '/api/workspaces/$workspaceId/credit-availability',
        <String, Object?>{'remainingDollars': null, 'scope': 'payer'},
      );
      await h.pump(tester, homePath);
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('enterprise owner: hidden and not requested', (tester) async {
      h
        ..billingEnabled = true
        ..stubDeployment(enterprise: true);
      await h.pump(tester, homePath);
      expect(find.byType(SimChip), findsNothing);
      expect(
        h.http.count('/api/workspaces/$workspaceId/credit-availability'),
        0,
      );
    });

    testWidgets('loading or failed: hidden', (tester) async {
      h
        ..billingEnabled = true
        ..stubDeployment();
      final gate = Completer<Object?>();
      h.http.handlers['/api/workspaces/$workspaceId/credit-availability'] =
          (_) => gate.future;
      await h.pump(tester, homePath);
      expect(find.byType(SimChip), findsNothing);
      gate.completeError(apiError(500));
      await settle(tester);
      expect(find.byType(SimChip), findsNothing);
      expect(find.byType(SimChipTag), findsNothing);
    });
  });

  testWidgets('a routed chat with pending history shows the skeleton, no '
      'hero, no composer', (tester) async {
    await h.pump(tester, chatPath);
    h.session.setHistoryPending(pending: true);
    await settle(tester);
    expect(byParityId('home.empty'), findsNothing);
    expect(byParityId('home.chat.skeleton'), findsOneWidget);
    expect(byParityId('chat-input.root'), findsNothing);
    h.session
      ..setMessages(const <PlaceholderMessage>[
        PlaceholderMessage(role: 'user', content: 'Summarise'),
      ])
      ..setHistoryPending(pending: false);
    await settle(tester);
    expect(byParityId('home.chat.skeleton'), findsNothing);
    expect(byParityId('home.chat'), findsOneWidget);
    expect(byParityId('chat-input.root'), findsOneWidget);
  });

  testWidgets('submit rules: trimmed, empty ignored, files-only gets the '
      'default text, request mode only for a new chat', (tester) async {
    await h.pump(tester, homePath);
    PlaceholderComposer composer() =>
        tester.widget<PlaceholderComposer>(find.byType(PlaceholderComposer));
    composer().props.onSubmit(const HomeOutgoingMessage(text: '   '));
    expect(h.session.sent, isEmpty);
    composer().props.onSubmit(
      const HomeOutgoingMessage(
        text: ' ',
        attachments: <HomeAttachment>[HomeAttachment(filename: 'a.csv')],
      ),
    );
    expect(h.session.sent.single.$1.text, 'Analyze the attached file(s).');
    expect(h.session.sent.single.$2, HomeRequestMode.agent);
    await settle(tester);
    expect(byParityId('home.chat'), findsOneWidget);
    composer().props.onSubmit(const HomeOutgoingMessage(text: '  next  '));
    expect(h.session.sent.last.$1.text, 'next');
  });

  testWidgets('the request mode is not sent for a routed chat', (
    tester,
  ) async {
    await h.pump(tester, chatPath);
    final composer = tester.widget<PlaceholderComposer>(
      find.byType(PlaceholderComposer),
    );
    expect(composer.props.requestMode, isNull);
    composer.props.onSubmit(const HomeOutgoingMessage(text: 'hi'));
    expect(h.session.sent.single.$2, isNull);
  });
}
