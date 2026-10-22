// Failure modes (home-page.md Layout "Row", "Panel width rules", "Resource
// header / tab strip", "Add-resource menu", States "Panel ...", Resource
// types in Phase 1.5; parity rows 4-23, 57-64, 70):
// - the panel opens at a fixed or viewport-relative width instead of 50%
//   of the row; its 1px left border or the 8px divider is missing; the
//   divider exists while collapsed
// - a drag ignores the clamps (280 / 735 at 1440), writes more than once
//   per frame, persists on pointercancel, or forgets to persist on release
// - keys move the divider the wrong way, by the wrong step, ignore Home /
//   End, or act with a modifier held
// - a stored width is not restored (or not re-clamped on a narrower
//   window), or is cached per chat only so a user who loads (or changes)
//   after the first build keeps the wrong width; without a user nothing is
//   persisted
// - the panel does not auto-open for a chat's first resources, auto-opens
//   after the user collapsed it or on a narrow (<768px) viewport, or stays
//   open on an empty list
// - the collapsed toggle shows no dot for background activity
// - tabs: a plain click does not single-select, Shift does not select the
//   range from the anchor, Ctrl/Cmd does not toggle; closing the active tab
//   jumps somewhere other than the nearest same-kind neighbour; closing a
//   member of a multi-selection leaves the others; middle click does not
//   close; a drag does not reorder; a drag out carries no payload or the
//   wrong MIME type
// - the + menu fetches lists before it opens, offers sources / folders /
//   chats / integrations, offers dashboards or tests without their flags,
//   orders families wrongly, or the search does not filter, move with
//   arrows, select with Enter / Tab, or say "No results"
// - placeholder types render their real (unported) surfaces, the blank
//   types render something, generic / folder / sources / empty panel
//   render the wrong copy

import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/home/home_page.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/panel/chat_panel_layout.dart';
import 'package:sim_app/features/home/panel/resource_tabs.dart';
import 'package:sim_app/features/home/placeholder_slots.dart';
import 'package:sim_app/features/home/slots.dart';
import 'package:sim_design/sim_design.dart';

import 'support/home_harness.dart';

const HomeResource tableA = HomeResource(
  type: HomeResourceType.table,
  id: 'table-a',
  title: 'Table A',
);
const HomeResource tableB = HomeResource(
  type: HomeResourceType.table,
  id: 'table-b',
  title: 'Table B',
);
const HomeResource fileC = HomeResource(
  type: HomeResourceType.file,
  id: 'file-c',
  title: 'notes.md',
);
const HomeResource tableD = HomeResource(
  type: HomeResourceType.table,
  id: 'table-d',
  title: 'Table D',
);

/// A tab's label in the strip (the panel body may repeat the title).
Finder tabLabel(String title) => find.descendant(
  of: find.byType(ResourceTabStrip),
  matching: find.text(title),
);

HomeContentState _content(WidgetTester tester) =>
    tester.state<HomeContentState>(find.byType(HomeContent));

double _panelWidth(WidgetTester tester) => rectOf(tester, 'home.panel').width;

Future<void> _openPanelWith(
  HomeHarness h,
  WidgetTester tester,
  List<HomeResource> resources,
) async {
  h.session.setResources(resources);
  await settle(tester);
}

void main() {
  late HomeHarness h;

  setUp(() async {
    h = HomeHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  group('layout and resizing', () {
    testWidgets('collapsed by default; the toggle opens 50% of the row with '
        'a divider and a left border', (tester) async {
      await h.pump(tester, homePath);
      // The collapsed panel keeps its id on a hair-wide stand-in at the row's
      // right edge (React reports the 0px box there).
      expect(_panelWidth(tester), closeTo(0, 0.01));
      expect(
        rectOf(tester, 'home.panel').right,
        rectOf(tester, 'home.row').right,
      );
      expect(byParityId('home.panel'), findsOneWidget);
      expect(byParityId('home.panel.resize-handle'), findsNothing);
      await tester.tap(byParityId('home.panel.toggle'));
      await settle(tester);
      final row = rectOf(tester, 'home.row');
      expect(_panelWidth(tester), row.width / 2);
      final handle = rectOf(tester, 'home.panel.resize-handle');
      expect(handle.width, 8);
      expect(handle.center.dx, row.right - row.width / 2);
      expect(byParityId('home.panel.empty'), findsOneWidget);
      expect(find.text('Click "+" above to add a resource'), findsOneWidget);
      expect(byParityId('home.panel'), findsOneWidget);
      final border = tester.widget<PixelSnappedLeftBorder>(
        find.descendant(
          of: byParityId('home.panel'),
          matching: find.byType(PixelSnappedLeftBorder),
        ),
      );
      expect(border.color, SimColors.light.border);
    });

    testWidgets('a floating tab hugs its title; + sits right after it', (
      tester,
    ) async {
      await h.pump(tester, chatPath);
      await _openPanelWith(h, tester, <HomeResource>[tableA]);
      final tab = rectOf(tester, 'home.panel.tabs.tab');
      expect(tab.left, rectOf(tester, 'home.panel.tabs').left + 16);
      expect(tab.width, greaterThanOrEqualTo(112));
      expect(tab.width, lessThan(200), reason: 'content width, not the cap');
      expect(rectOf(tester, 'home.panel.tabs.add').left, tab.right + 4);
    });

    test('tab widths: content width capped at 200, CSS-like shrink to 112', () {
      expect(fitResourceTabWidths(<double>[90, 150, 260], 1000), <double>[
        112,
        150,
        200,
      ]);
      // 3 × 200 + 2 × 8 = 616 into 416: each loses 200 × (200 / 600).
      final shrunk = fitResourceTabWidths(<double>[200, 200, 200], 416);
      for (final w in shrunk) {
        expect(w, closeTo(400 / 3, 1e-9));
      }
      // A tab that would fall under 112 freezes there; the rest absorb it.
      final mixed = fitResourceTabWidths(<double>[120, 200], 250);
      expect(mixed[0], 112);
      expect(mixed[1], closeTo(250 - 8 - 112, 1e-9));
      // Never below the minimum: the row scrolls instead.
      expect(fitResourceTabWidths(<double>[200, 200], 100), <double>[112, 112]);
    });

    testWidgets('drag clamps, persists on release only, per user and chat', (
      tester,
    ) async {
      await h.pump(tester, chatPath);
      await _openPanelWith(h, tester, <HomeResource>[tableA]);
      final start = _panelWidth(tester);
      expect(start, rectOf(tester, 'home.row').width / 2);
      final handle = rectOf(tester, 'home.panel.resize-handle').center;
      final gesture = await tester.startGesture(handle);
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();
      expect(_panelWidth(tester), start + 50);
      expect(h.widths.widths, isEmpty, reason: 'nothing persists mid-drag');
      await gesture.moveBy(const Offset(-1000, 0));
      await tester.pump();
      expect(_panelWidth(tester), 735);
      await gesture.moveBy(const Offset(2000, 0));
      await tester.pump();
      expect(_panelWidth(tester), 280);
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();
      await gesture.up();
      await settle(tester);
      final committed = _panelWidth(tester);
      expect(h.widths.preferred(userId, seededChatId), committed);
      expect(
        jsonDecode(h.storage.read('chat-panel-widths')!),
        <String, Object?>{
          'state': <String, Object?>{
            'widths': <String, Object?>{'$userId:$seededChatId': committed},
          },
          'version': 0,
        },
      );
    });

    testWidgets('a cancelled drag restores and persists nothing', (
      tester,
    ) async {
      await h.pump(tester, chatPath);
      await _openPanelWith(h, tester, <HomeResource>[tableA]);
      final start = _panelWidth(tester);
      final gesture = await tester.startGesture(
        rectOf(tester, 'home.panel.resize-handle').center,
      );
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      await gesture.cancel();
      await settle(tester);
      expect(_panelWidth(tester), start);
      expect(h.widths.widths, isEmpty);
    });

    testWidgets('keyboard: ←/→ ±32, Home/End, modifiers ignored', (
      tester,
    ) async {
      await h.pump(tester, chatPath);
      await _openPanelWith(h, tester, <HomeResource>[tableA]);
      final start = _panelWidth(tester);
      tester
          .widgetList<Focus>(
            find.descendant(
              of: byParityId('home.panel.resize-handle'),
              matching: find.byType(Focus),
            ),
          )
          .first
          .focusNode!
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settle(tester);
      expect(_panelWidth(tester), start + 32);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(_panelWidth(tester), start - 32);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settle(tester);
      expect(_panelWidth(tester), start - 32);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await settle(tester);
      expect(_panelWidth(tester), 280);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await settle(tester);
      expect(_panelWidth(tester), 735);
      expect(h.widths.preferred(userId, seededChatId), 735);
    });

    testWidgets('a stored width is restored and re-clamped to a narrower '
        'window', (tester) async {
      h.widths.setWidth(userId, seededChatId, 700);
      await h.pump(tester, chatPath);
      await _openPanelWith(h, tester, <HomeResource>[tableA]);
      expect(_panelWidth(tester), 700);
      tester.view.physicalSize = const Size(1280, 800);
      await settle(tester);
      expect(_panelWidth(tester), 575);
      expect(h.widths.preferred(userId, seededChatId), 700);
    });

    testWidgets('the stored width is read per user and scope: a user who '
        'arrives (or changes) after the first build gets their own width', (
      tester,
    ) async {
      h.widths
        ..setWidth(userId, seededChatId, 700)
        ..setWidth('other-user', seededChatId, 500);
      await h.pump(tester, chatPath);
      await _openPanelWith(h, tester, <HomeResource>[tableA]);
      expect(_panelWidth(tester), 700);
      h.shell.sessionCubit.setSession(
        const AuthSession(
          user: AuthUser(id: 'other-user', email: 'other@example.com'),
          session: SessionInfo(id: 's2', userId: 'other-user'),
        ),
      );
      await settle(tester);
      expect(_panelWidth(tester), 500);
    });

    testWidgets(
      "a new chat's width moves from its pending scope to the chat",
      (tester) async {
        await h.pump(tester, homePath);
        await tester.tap(byParityId('home.panel.toggle'));
        await settle(tester);
        final focus =
            tester
                  .widgetList<Focus>(
                    find.descendant(
                      of: byParityId('home.panel.resize-handle'),
                      matching: find.byType(Focus),
                    ),
                  )
                  .first
                  .focusNode!
              ..requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await settle(tester);
        expect(focus.hasFocus, isTrue);
        final pending = h.widths.widths.keys.single;
        expect(pending, startsWith('$userId:pending:'));
        h.session.adoptChatId('chat-new');
        await settle(tester);
        expect(h.widths.widths, <String, double>{'$userId:chat-new': 735});
      },
    );
  });

  group('auto-open, auto-close, activity', () {
    testWidgets('first resources open the panel; emptied list closes it', (
      tester,
    ) async {
      await h.pump(tester, chatPath);
      expect(_content(tester).panel.isCollapsed, isTrue);
      await _openPanelWith(h, tester, <HomeResource>[tableA]);
      expect(_content(tester).panel.isCollapsed, isFalse);
      expect(_panelWidth(tester), greaterThan(0));
      await _openPanelWith(h, tester, const <HomeResource>[]);
      expect(_content(tester).panel.isCollapsed, isTrue);
      expect(_panelWidth(tester), closeTo(0, 0.01));
    });

    testWidgets('a narrow (<768px) viewport does not auto-open; widening '
        'it does', (tester) async {
      await h.pump(tester, chatPath, size: const Size(700, 900));
      await _openPanelWith(h, tester, <HomeResource>[tableA]);
      expect(_content(tester).panel.isCollapsed, isTrue);
      tester.view.physicalSize = shellViewport;
      await settle(tester);
      expect(_content(tester).panel.isCollapsed, isFalse);
    });

    testWidgets('after a user collapse new resources only mark activity', (
      tester,
    ) async {
      await h.pump(tester, chatPath);
      await _openPanelWith(h, tester, <HomeResource>[tableA]);
      await tester.tap(byParityId('home.panel.toggle'));
      await settle(tester);
      expect(byParityId('home.panel.toggle.dot'), findsNothing);
      h.session.emitResourceEvent(tableB);
      await settle(tester);
      expect(_content(tester).panel.isCollapsed, isTrue);
      expect(byParityId('home.panel.toggle.dot'), findsOneWidget);
      await tester.tap(byParityId('home.panel.toggle'));
      await settle(tester);
      expect(_content(tester).panel.isCollapsed, isFalse);
      expect(byParityId('home.panel.toggle.dot'), findsNothing);
    });
  });

  group('tabs', () {
    Future<void> openTabs(HomeHarness h, WidgetTester tester) async {
      await h.pump(tester, chatPath);
      await _openPanelWith(h, tester, <HomeResource>[
        tableA,
        tableB,
        fileC,
        tableD,
      ]);
    }

    ResourceTabStripState strip(WidgetTester tester) =>
        tester.state<ResourceTabStripState>(find.byType(ResourceTabStrip));

    String? active(WidgetTester tester) =>
        _content(tester).panel.activeResourceId;

    testWidgets('click, Shift range, Ctrl toggle; the URL follows', (
      tester,
    ) async {
      await openTabs(h, tester);
      expect(active(tester), 'table-d', reason: 'falls back to the last');
      await tester.tap(tabLabel('Table A'));
      await settle(tester);
      expect(active(tester), 'table-a');
      expect(h.location, '$chatPath?resource=table-a');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(tabLabel('notes.md'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settle(tester);
      expect(strip(tester).selectedIds, <String>{
        'table-a',
        'table-b',
        'file-c',
      });
      expect(active(tester), 'file-c');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(tabLabel('Table B'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(strip(tester).selectedIds, <String>{'table-a', 'file-c'});
    });

    testWidgets('closing the active tab moves to the nearest same-kind tab', (
      tester,
    ) async {
      await openTabs(h, tester);
      await tester.tap(tabLabel('Table B'));
      await settle(tester);
      // At distance 1 the right neighbour is a file, the left one a table:
      // the same-kind left neighbour wins (right first only among equals).
      strip(tester).close('table-b');
      await settle(tester);
      expect(h.session.resources.map((r) => r.id), <String>[
        'table-a',
        'file-c',
        'table-d',
      ]);
      expect(active(tester), 'table-a');
      // From the file, the nearest file does not exist: any neighbour,
      // right first.
      await tester.tap(tabLabel('notes.md'));
      await settle(tester);
      strip(tester).close('file-c');
      await settle(tester);
      expect(active(tester), 'table-d');
    });

    testWidgets('closing a member of a multi-selection closes them all', (
      tester,
    ) async {
      await openTabs(h, tester);
      await tester.tap(tabLabel('Table A'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(tabLabel('Table D'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      strip(tester).close('table-a');
      await settle(tester);
      expect(h.session.resources.map((r) => r.id), <String>[
        'table-b',
        'file-c',
      ]);
    });

    testWidgets('middle click closes; the close button closes', (
      tester,
    ) async {
      await openTabs(h, tester);
      final center = tester.getCenter(tabLabel('Table B'));
      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await gesture.up();
      await settle(tester);
      expect(
        h.session.resources.map((r) => r.id),
        isNot(contains('table-b')),
      );
      // The active tab always shows its close button.
      await tester.tap(find.bySemanticsLabel('Close Table D'));
      await settle(tester);
      expect(h.session.resources.map((r) => r.id), <String>[
        'table-a',
        'file-c',
      ]);
    });

    testWidgets('dragging a tab reorders the strip', (tester) async {
      await openTabs(h, tester);
      final from = tester.getCenter(tabLabel('Table A'));
      final to = tester
          .getRect(
            find.ancestor(
              of: tabLabel('Table D'),
              matching: find.byType(Draggable<HomeResourceDragData>),
            ),
          )
          .centerRight;
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(to - const Offset(10, 0));
      await tester.pump();
      await gesture.up();
      await settle(tester);
      expect(h.session.resources.map((r) => r.id), <String>[
        'table-b',
        'file-c',
        'table-d',
        'table-a',
      ]);
    });

    testWidgets('dragging out carries one tab, or the whole selection', (
      tester,
    ) async {
      await openTabs(h, tester);
      final drops = <HomeResourceDragData>[];
      // A composer-like drop target outside the strip.
      final strip = tester.state<ResourceTabStripState>(
        find.byType(ResourceTabStrip),
      );
      await tester.tap(tabLabel('Table A'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(tabLabel('Table B'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(strip.selectedIds, hasLength(2));
      final overlay = tester.state<OverlayState>(find.byType(Overlay).first);
      final entry = OverlayEntry(
        builder: (context) => Positioned(
          left: 0,
          top: 600,
          width: 300,
          height: 200,
          child: DragTarget<HomeResourceDragData>(
            onAcceptWithDetails: (d) => drops.add(d.data),
            builder: (context, _, _) =>
                const ColoredBox(color: Color(0x01000000)),
          ),
        ),
      );
      overlay.insert(entry);
      addTearDown(entry.remove);
      await tester.pump();
      final gesture = await tester.startGesture(
        tester.getCenter(tabLabel('Table B')),
      );
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.moveTo(const Offset(150, 700));
      await tester.pump();
      await gesture.up();
      await settle(tester);
      expect(drops, hasLength(1));
      expect(drops.single.mimeType, 'application/x-sim-resources');
      expect(
        jsonDecode(drops.single.encode()),
        <Object?>[
          <String, Object?>{
            'type': 'table',
            'id': 'table-a',
            'title': 'Table A',
          },
          <String, Object?>{
            'type': 'table',
            'id': 'table-b',
            'title': 'Table B',
          },
        ],
      );
      // Not a reorder.
      expect(h.session.resources.first.id, 'table-a');
      expect(
        const HomeResourceDragData(<HomeResource>[fileC]).mimeType,
        'application/x-sim-resource',
      );
    });
  });

  group('add-resource menu', () {
    void stubInventory(HomeHarness h) {
      h.http
        ..answer('/api/table', <String, Object?>{
          'data': <String, Object?>{
            'tables': <Object?>[
              <String, Object?>{'id': 't1', 'name': 'E2E table'},
            ],
          },
        })
        ..answer('/api/knowledge', <String, Object?>{
          'data': <Object?>[
            <String, Object?>{'id': 'k1', 'name': 'E2E knowledge base'},
          ],
        })
        ..answer('/api/mothership/chats', <String, Object?>{
          'data': <Object?>[
            <String, Object?>{'id': 'c1', 'title': 'E2E conversation'},
          ],
        })
        ..answer('/api/logs', <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'l1',
              'workflow': <String, Object?>{'name': 'Mixed 20 blocks'},
              'createdAt': '2026-10-22T11:58:00.000Z',
              'status': 'failed',
            },
          ],
        })
        ..answer('/api/workspaces/$workspaceId/files', <String, Object?>{
          'files': <Object?>[
            <String, Object?>{'id': 'f1', 'name': 'E2E notes.md'},
          ],
        });
      when(
        () => h.shell.workflowsRepo.list(
          workspaceId: any(named: 'workspaceId'),
          scope: any(named: 'scope'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => <WorkflowListItem>[workflow(id: 'w1', name: 'E2E flow')],
      );
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(byParityId('home.panel.tabs.add'));
      await settle(tester);
    }

    List<String> menuLabels(WidgetTester tester) => <String>[
      for (final row in tester.widgetList<SimMenuRow>(
        find.descendant(
          of: byParityId('home.panel.add-menu'),
          matching: find.byType(SimMenuRow),
        ),
      ))
        row.label,
    ];

    testWidgets('lists load on open only; families in product order without '
        'excluded or unflagged ones', (tester) async {
      stubInventory(h);
      await h.pump(tester, homePath);
      await tester.tap(byParityId('home.panel.toggle'));
      await settle(tester);
      expect(h.http.count('/api/logs'), 0);
      expect(h.http.count('/api/mothership/chats'), 0);
      expect(h.http.count('/api/workspaces/$workspaceId/files/folders'), 0);
      await openMenu(tester);
      expect(byParityId('home.panel.add-menu'), findsOneWidget);
      expect(h.http.count('/api/logs'), 1);
      expect(h.http.count('/api/mothership/chats'), 1);
      expect(h.http.count('/api/workspaces/$workspaceId/dashboard'), 0);
      expect(h.http.count('/api/workspaces/$workspaceId/tests'), 0);
      final rows = menuLabels(tester);
      expect(rows, <String>[
        'Tables',
        'Files',
        'Knowledge Bases',
        'Workflows',
        'Logs',
      ]);
      expect(rows, isNot(contains('Chats')));
      expect(rows, isNot(contains('Folders')));
      expect(rows, isNot(contains('Integrations')));
    });

    testWidgets('search filters across families; ↓ and Enter select', (
      tester,
    ) async {
      stubInventory(h);
      await h.pump(tester, homePath);
      await tester.tap(byParityId('home.panel.toggle'));
      await settle(tester);
      await openMenu(tester);
      await tester.enterText(find.byType(EditableText).last, 'e2e');
      await settle(tester);
      expect(
        menuLabels(tester),
        containsAll(<String>[
          'E2E table',
          'E2E notes.md',
          'E2E knowledge base',
          'E2E flow',
        ]),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(byParityId('home.panel.add-menu'), findsNothing);
      final added = h.session.resources.single;
      // Filtered rows follow the family order: table, file, KB, workflow.
      expect(added.title, 'E2E notes.md');
      expect(added.workspaceId, workspaceId);
      expect(_content(tester).panel.activeResourceId, added.selectionId);
      expect(_content(tester).panel.isCollapsed, isFalse);
    });

    testWidgets('Tab selects the cursor row; no match says "No results"', (
      tester,
    ) async {
      stubInventory(h);
      await h.pump(tester, homePath);
      await tester.tap(byParityId('home.panel.toggle'));
      await settle(tester);
      await openMenu(tester);
      await tester.enterText(find.byType(EditableText).last, 'zzz');
      await settle(tester);
      expect(find.text('No results'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, 'mixed');
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settle(tester);
      final added = h.session.resources.single;
      expect(added.type, HomeResourceType.log);
      expect(added.id, 'l1');
    });

    testWidgets('dashboards and tests appear with their flags', (
      tester,
    ) async {
      stubInventory(h);
      h.http
        ..answer('/api/workspaces/$workspaceId/dashboard', <String, Object?>{
          'dashboard': <String, Object?>{'id': 'd1', 'name': 'Ops'},
        })
        ..answer('/api/workspaces/$workspaceId/tests', <String, Object?>{
          'tests': <Object?>[
            <String, Object?>{'name': 'smoke', 'title': 'Smoke'},
          ],
        });
      when(
        () => h.shell.runtime.featureFlags(
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => const FeatureFlagsLoaded(
          WorkspaceFeatureFlagsResponse(
            flags: WorkspaceFeatureFlags(dashboards: true, workflowTests: true),
            desktopExecutor: DesktopExecutorStatus(),
          ),
        ),
      );
      await h.pump(tester, homePath);
      await tester.tap(byParityId('home.panel.toggle'));
      await settle(tester);
      await openMenu(tester);
      expect(menuLabels(tester), <String>[
        'Dashboards',
        'Tests',
        'Tables',
        'Files',
        'Knowledge Bases',
        'Workflows',
        'Logs',
      ]);
    });
  });

  group('content per type', () {
    Future<void> show(
      HomeHarness h,
      WidgetTester tester,
      HomeResource resource,
    ) async {
      await h.pump(tester, chatPath);
      await _openPanelWith(h, tester, <HomeResource>[resource]);
    }

    testWidgets('generic: "No results yet"', (tester) async {
      await show(
        h,
        tester,
        const HomeResource(
          type: HomeResourceType.generic,
          id: 'g',
          title: 'Results',
        ),
      );
      expect(find.text('No results yet'), findsOneWidget);
    });

    for (final type in <HomeResourceType>[
      HomeResourceType.workflow,
      HomeResourceType.table,
      HomeResourceType.file,
      HomeResourceType.knowledgebase,
      HomeResourceType.log,
      HomeResourceType.dashboard,
      HomeResourceType.test,
    ]) {
      testWidgets('${type.wire}: later-phase placeholder', (tester) async {
        await show(
          h,
          tester,
          HomeResource(type: type, id: 'x', title: 'My ${type.wire}'),
        );
        expect(find.text('Available in a later phase'), findsOneWidget);
        expect(
          find.descendant(
            of: byParityId('home.panel.content'),
            matching: find.text('My ${type.wire}'),
          ),
          findsOneWidget,
        );
      });
    }

    for (final type in <HomeResourceType>[
      HomeResourceType.filefolder,
      HomeResourceType.task,
      HomeResourceType.integration,
    ]) {
      testWidgets('${type.wire}: blank', (tester) async {
        await show(h, tester, HomeResource(type: type, id: 'x', title: 'X'));
        expect(
          find.descendant(
            of: byParityId('home.panel.content'),
            matching: find.byType(Text),
          ),
          findsNothing,
        );
      });
    }

    testWidgets('folder: its workflows open the editor; unknown folder', (
      tester,
    ) async {
      when(
        () => h.shell.foldersRepo.list(
          workspaceId: any(named: 'workspaceId'),
          scope: any(named: 'scope'),
          resourceType: any(named: 'resourceType'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => <Folder>[folder(id: 'fo1', name: 'Ops')]);
      when(
        () => h.shell.workflowsRepo.list(
          workspaceId: any(named: 'workspaceId'),
          scope: any(named: 'scope'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => <WorkflowListItem>[
          workflow(id: 'w1', name: 'Nightly', folderId: 'fo1'),
        ],
      );
      await show(
        h,
        tester,
        const HomeResource(
          type: HomeResourceType.folder,
          id: 'fo1',
          title: 'Ops',
        ),
      );
      expect(
        find.descendant(
          of: byParityId('home.panel.content'),
          matching: find.text('Ops'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Nightly'));
      await settle(tester);
      expect(h.location, '/workspace/$workspaceId/w/w1');
    });

    testWidgets('folder not found', (tester) async {
      await show(
        h,
        tester,
        const HomeResource(
          type: HomeResourceType.folder,
          id: 'gone',
          title: 'Gone',
        ),
      );
      expect(find.text('Folder not found'), findsOneWidget);
    });

    testWidgets('sources: header count and the three status texts', (
      tester,
    ) async {
      await h.pump(tester, chatPath);
      h.session.setMessages(const <PlaceholderMessage>[
        PlaceholderMessage(role: 'assistant', content: 'cited'),
      ]);
      await settle(tester);
      // "View sources" from the transcript opens the tab.
      h.transcriptProps!.onViewSources('m1', 'r1');
      await settle(tester);
      expect(
        find.text('No cited sources are available for this response.'),
        findsOneWidget,
      );
      h.session
        ..sources = const HomeCitedSources(loading: true)
        ..setSending(sending: false);
      await settle(tester);
      expect(find.text('Loading sources'), findsOneWidget);
      h.session
        ..sources = const HomeCitedSources(failed: true)
        ..setSending(sending: false);
      await settle(tester);
      expect(
        find.text('Unable to load sources. Try reopening this conversation.'),
        findsOneWidget,
      );
      h.session
        ..sources = const HomeCitedSources(
          sources: <HomeSource>[
            HomeSource(url: 'https://a.example/x', title: 'A'),
            HomeSource(url: 'https://b.example/y', title: 'B'),
          ],
        )
        ..setSending(sending: false);
      await settle(tester);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Sources · 2', findRichText: true), findsOneWidget);
    });
  });
}
