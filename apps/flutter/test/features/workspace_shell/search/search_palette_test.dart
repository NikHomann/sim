// Failure modes of the palette widget (`search-modal.tsx`), each a test:
// 1. nothing is mounted while closed; opening mounts it, Escape and an
//    outside press close it, a press inside does not;
// 2. closing unmounts the content: query and ask mode never persist;
// 3. arrows move the selection and wrap at both ends; Home/End jump;
//    typing re-anchors the selection on the first row;
// 4. Enter activates the selected row: a workspace navigates to
//    `/workspace/{id}/w` and closes; the current workspace / workflow only
//    closes; an action closes first, then runs;
// 5. Tab with chat enabled toggles ask mode (single "New chat: q" row,
//    placeholder and hint flip, text kept); Enter there hands the query
//    off; Tab with chat disabled steps the selection (Shift+Tab back);
// 6. canvas rows dispatch an add-block request and close;
// 7. the empty state shows "No results found." and nothing is selected;
// 8. geometry: 15% from the top, min(500, vw - 32) wide, centred over the
//    content pane and clamped to 16px gutters.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/chrome/search_palette_controller.dart';
import 'package:sim_app/features/workspace_shell/search/palette_catalog.dart';
import 'package:sim_app/features/workspace_shell/search/palette_models.dart';
import 'package:sim_app/features/workspace_shell/search/palette_rows.dart';
import 'package:sim_app/features/workspace_shell/search/search_palette.dart';

import 'support/shell_fixtures.dart';

void main() {
  late ShellFixture fixture;
  late SearchPaletteController controller;
  late List<String> navigated;
  late List<String> asked;
  late List<String> events;

  setUp(() async {
    fixture = ShellFixture(
      workspaces: [
        ws(workspaceId, name: 'Acme'),
        ws('ws-2', name: 'Beta'),
      ],
      workflows: [workflow(id: 'wf-1', name: 'Onboarding')],
    );
    await fixture.load();
    controller = SearchPaletteController();
    navigated = [];
    asked = [];
    events = [];
  });

  tearDown(() async {
    controller.dispose();
    await fixture.dispose();
  });

  Future<void> pumpPalette(
    WidgetTester tester, {
    String? workflowId,
    PaletteCatalog catalog = const PaletteCatalog.empty(),
    AddBlockBus? bus,
    double sidebarWidth = 224,
  }) async {
    await pumpShell(
      tester,
      SearchPaletteLayer(
        controller: controller,
        workspaceId: workspaceId,
        pathname: workflowId == null
            ? '/workspace/$workspaceId/home'
            : '/workspace/$workspaceId/w/$workflowId',
        currentWorkflowId: workflowId,
        sidebarWidth: sidebarWidth,
        dependencies: SearchPaletteDependencies(
          workspaces: fixture.workspaces,
          workflows: fixture.workflows,
          folders: fixture.folders,
          deploymentShape: fixture.deploymentShape,
          permissions: fixture.permissions,
        ),
        catalog: catalog,
        addBlockBus: bus,
        onNavigate: navigated.add,
        onAskSim: asked.add,
        onCreateWorkflow: () {},
        onImportWorkflow: () {},
        onCreateFolder: () => events.add('create-folder:${controller.isOpen}'),
        child: const SizedBox.expand(),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    controller.open();
    await tester.pumpAndSettle();
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
    await tester.pumpAndSettle();
  }

  String? selectedLabel(WidgetTester tester) {
    final selected = find.ancestor(
      of: byParityId('search.palette.row.selected'),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.selected ?? false),
      ),
    );
    if (selected.evaluate().isEmpty) return null;
    return tester.widget<Semantics>(selected.first).properties.label;
  }

  group('1. open and close', () {
    testWidgets('closed renders nothing; open mounts the dialog', (
      tester,
    ) async {
      await pumpPalette(tester);
      expect(byParityId('search.dialog'), findsNothing);
      await open(tester);
      expect(byParityId('search.dialog'), findsOneWidget);
      expect(byParityId('search.palette.group.sim'), findsOneWidget);
    });

    testWidgets('Escape closes', (tester) async {
      await pumpPalette(tester);
      await open(tester);
      await key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
      expect(byParityId('search.dialog'), findsNothing);
    });

    testWidgets('an outside press closes, an inside press does not', (
      tester,
    ) async {
      await pumpPalette(tester);
      await open(tester);
      await tester.tapAt(
        tester.getCenter(byParityId('search.palette.input')),
      );
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);
      await tester.tapAt(const Offset(20, 880));
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
    });
  });

  testWidgets('2. the query does not survive a close', (tester) async {
    await pumpPalette(tester);
    await open(tester);
    await type(tester, 'beta');
    controller.close();
    await tester.pumpAndSettle();
    await open(tester);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.controller.text, isEmpty);
  });

  group('3. keyboard selection', () {
    testWidgets('arrows wrap, Home/End jump, typing re-anchors', (
      tester,
    ) async {
      await pumpPalette(tester);
      await open(tester);
      expect(selectedLabel(tester), 'New chat');
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(selectedLabel(tester), 'Beta');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(selectedLabel(tester), 'New chat');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(selectedLabel(tester), 'Create workflow');
      await key(tester, LogicalKeyboardKey.end);
      expect(selectedLabel(tester), 'Beta');
      await key(tester, LogicalKeyboardKey.home);
      expect(selectedLabel(tester), 'New chat');
      await key(tester, LogicalKeyboardKey.arrowDown);
      await type(tester, 'acme');
      expect(selectedLabel(tester), 'Acme');
    });
  });

  group('4. selection routing', () {
    testWidgets('a workspace navigates to /w and closes', (tester) async {
      await pumpPalette(tester);
      await open(tester);
      await type(tester, 'beta');
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(navigated, ['/workspace/ws-2/w']);
      expect(controller.isOpen, isFalse);
    });

    testWidgets('the current workspace and workflow only close', (
      tester,
    ) async {
      await pumpPalette(tester, workflowId: 'wf-1');
      await open(tester);
      await type(tester, 'acme');
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await open(tester);
      await type(tester, 'onboarding');
      expect(find.text(' (current)'), findsOneWidget);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(navigated, isEmpty);
      expect(controller.isOpen, isFalse);
    });

    testWidgets('a workflow opens its route', (tester) async {
      await pumpPalette(tester);
      await open(tester);
      await type(tester, 'onboarding');
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(navigated, ['/workspace/$workspaceId/w/wf-1']);
    });

    testWidgets('an action closes the palette before it runs', (
      tester,
    ) async {
      await pumpPalette(tester);
      await open(tester);
      await type(tester, 'create folder');
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(events, ['create-folder:false']);
    });

    testWidgets('a page click navigates', (tester) async {
      await pumpPalette(tester);
      await open(tester);
      await type(tester, 'logs');
      await tester.tap(byParityId('search.palette.row.pages.logs'));
      await tester.pumpAndSettle();
      expect(navigated, ['/workspace/$workspaceId/logs']);
    });
  });

  group('5. Tab', () {
    testWidgets('chat enabled: toggles ask mode and keeps the text', (
      tester,
    ) async {
      await pumpPalette(tester);
      await open(tester);
      expect(find.text('⇥ Ask Sim'), findsOneWidget);
      await type(tester, 'summarise logs');
      await key(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(byParityId('search.palette.ask-row'), findsOneWidget);
      expect(find.text('New chat: summarise logs'), findsOneWidget);
      expect(find.text('⇥ Search'), findsOneWidget);
      expect(find.text('Ask Sim anything...'), findsNothing);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(asked, ['summarise logs']);
      expect(controller.isOpen, isFalse);
    });

    testWidgets('ask mode with no text opens Home', (tester) async {
      await pumpPalette(tester);
      await open(tester);
      await key(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text('Start a new chat'), findsOneWidget);
      expect(find.text('Ask Sim anything...'), findsOneWidget);
      await key(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(byParityId('search.palette.ask-row'), findsNothing);
      await key(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(asked, isEmpty);
      expect(navigated, ['/workspace/$workspaceId/home']);
    });

    testWidgets('chat disabled: Tab steps, Shift+Tab steps back', (
      tester,
    ) async {
      fixture.deploymentShape.seed(const DeploymentShape(chatEnabled: false));
      await pumpPalette(tester);
      await open(tester);
      expect(find.text('⇥ Ask Sim'), findsNothing);
      expect(selectedLabel(tester), 'Create workflow');
      await key(tester, LogicalKeyboardKey.tab);
      expect(selectedLabel(tester), 'Create folder');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await key(tester, LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(selectedLabel(tester), 'Create workflow');
    });
  });

  testWidgets('6. canvas rows dispatch add-block requests', (tester) async {
    final bus = AddBlockBus();
    final requests = <AddBlockRequest>[];
    final sub = bus.requests.listen(requests.add);
    addTearDown(sub.cancel);
    await pumpPalette(
      tester,
      workflowId: 'wf-1',
      bus: bus,
      catalog: const InMemoryPaletteCatalog(
        blocks: [
          PaletteBlockItem(
            id: 'agent',
            type: 'agent',
            name: 'Agent',
            bgColor: Color(0xFF6F3DFA),
          ),
        ],
        triggers: [
          PaletteBlockItem(
            id: 'schedule',
            type: 'schedule',
            name: 'Schedule',
            bgColor: Color(0xFF6F3DFA),
            triggerCapable: true,
          ),
        ],
        toolOperations: [
          PaletteToolOperationItem(
            id: 'slack.send',
            blockType: 'slack',
            operationId: 'send',
            name: 'Send Message',
            serviceName: 'Slack',
            bgColor: Color(0xFF611F69),
          ),
        ],
      ),
    );
    for (final query in ['agent', 'schedule', 'send message']) {
      await open(tester);
      await type(tester, query);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
    }
    expect(requests, const [
      AddBlockRequest(type: 'agent'),
      AddBlockRequest(type: 'schedule', enableTriggerMode: true),
      AddBlockRequest(type: 'slack', presetOperation: 'send'),
    ]);
    expect(navigated, isEmpty);
  });

  testWidgets('7. no results', (tester) async {
    await pumpPalette(tester);
    await open(tester);
    await type(tester, 'zzzzqqqq');
    expect(byParityId('search.palette.empty'), findsOneWidget);
    expect(find.text('No results found.'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
    expect(navigated, isEmpty);
  });

  group('8. geometry', () {
    testWidgets('centred over the content pane, 15% from the top', (
      tester,
    ) async {
      await pumpPalette(tester);
      await open(tester);
      final rect = tester.getRect(byParityId('search.dialog'));
      expect(rect.width, 500);
      expect(rect.top, closeTo(900 * 0.15, 0.01));
      expect(rect.center.dx, closeTo(720 + 112, 0.01));
    });

    test('the centre clamps to the 16px gutters', () {
      expect(
        paletteCenterX(
          viewportWidth: 600,
          sidebarWidth: 400,
          panelWidth: 0,
          onCanvas: false,
        ),
        600 - 16 - 250,
      );
      expect(
        paletteCenterX(
          viewportWidth: 300,
          sidebarWidth: 224,
          panelWidth: 0,
          onCanvas: false,
        ),
        150,
      );
      expect(
        paletteCenterX(
          viewportWidth: 1440,
          sidebarWidth: 224,
          panelWidth: 320,
          onCanvas: true,
        ),
        720 + (224 - 320) / 2,
      );
    });
  });

  test('dates format like Intl en-US short', () {
    expect(formatPaletteDate(DateTime(2026, 10, 21, 15, 5)), 'Oct 21, 3:05 PM');
    expect(formatPaletteDate(DateTime(2026, 1, 2)), 'Jan 2, 12:00 AM');
  });
}
