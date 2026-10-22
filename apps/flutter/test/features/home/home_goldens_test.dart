// Failure modes (what a golden diff must catch, home-page.md Layout and
// colour anchors H1-H7 at 1440×900):
// - the hero cluster: heading size/position, the 704px composer box at
//   y 338..442, the suggested section 28px below it with four 37px rows
//   and separators (H1, H2, H4)
// - the hero without the suggestion rows (section collapsed): the composer
//   must not move
// - the conversation with the panel open: 50% panel with its 1px left
//   border, the 41px tab strip with floating tabs, the add control and the
//   collapse toggle in the panel corner, the footer composer and the queue
//   tray tucked under it (H5, H6, H7)
// The sidebar slot is a stub (the sidebar has its own goldens); the
// composer and transcript are the Phase 1.5 placeholder slots.

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/placeholder_slots.dart';

import 'support/home_harness.dart';

void homeGoldens(
  String description, {
  required String fileName,
  required String location,
  Future<void> Function(WidgetTester tester, HomeHarness h)? act,
}) {
  group(description, () {
    late HomeHarness h;

    setUp(() async {
      h = HomeHarness();
      await h.setUp();
      h.signInAs('Ada Lovelace');
    });

    tearDown(() => h.tearDown());

    for (final dark in <bool>[false, true]) {
      final suffix = dark ? 'dark' : 'light';
      // ignore: discarded_futures, goldenTest registers the test synchronously
      goldenTest(
        '$description ($suffix)',
        fileName: '${fileName}_$suffix',
        constraints: BoxConstraints.tight(shellViewport),
        pumpWidget: (tester, widget) async {
          tester.view.physicalSize = shellViewport;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(widget);
        },
        pumpBeforeTest: (tester) async {
          await settle(tester);
          if (act != null) {
            await act(tester, h);
            await settle(tester);
          }
        },
        builder: () => h.app(
          location,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        ),
      );
    }
  });
}

void main() {
  homeGoldens(
    'home hero with suggestions',
    fileName: 'home_hero_suggestions',
    location: homePath,
  );

  homeGoldens(
    'home hero without suggestion rows',
    fileName: 'home_hero_collapsed',
    location: homePath,
    act: (tester, h) async {
      await tester.tap(find.text('Suggested actions'));
    },
  );

  homeGoldens(
    'conversation with the resource panel open',
    fileName: 'home_conversation_panel',
    location: chatPath,
    act: (tester, h) async {
      h.session
        ..setMessages(const <PlaceholderMessage>[
          PlaceholderMessage(
            role: 'user',
            content: 'Summarise the seeded workspace for me.',
          ),
          PlaceholderMessage(
            role: 'assistant',
            content: 'Flutter E2E workspace: 3 workflows, 1 table.',
          ),
        ])
        ..setQueue(const <HomeQueuedMessage>[
          HomeQueuedMessage(id: 'q1', content: 'Then chart the table'),
        ])
        ..setResources(const <HomeResource>[
          HomeResource(
            type: HomeResourceType.table,
            id: 'table-1',
            title: 'E2E table',
          ),
          HomeResource(
            type: HomeResourceType.file,
            id: 'file-1',
            title: 'notes.md',
          ),
          HomeResource(
            type: HomeResourceType.generic,
            id: 'results',
            title: 'Results',
          ),
        ]);
    },
  );
}
