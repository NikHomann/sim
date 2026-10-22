// Failure modes of the palette found by the Phase 1 review, each a test:
// 1. the selection is an index: a list update while the palette is open
//    moves it onto whatever row now sits there, so Enter opens a different
//    item [finding 14];
// 2. every arrow, hover and Tab re-ranks every section (the ranking runs
//    in build) [finding 14];
// 3. the list draws a scrollbar (`scrollbar-none` upstream) [finding 13];
// 4. "Create folder" / "Import workflow" never appear unless the mounting
//    chrome passes handlers; the sidebar's own flows must back them
//    [finding 7];
// 5. "Copy workflow link" copies `Uri.base` (a nested or `file:` URL)
//    instead of the route under the app base [finding 1].
//
// Parity sweep (2026-10-22, the parity tool against React):
// 6. with the sidebar mounted but no import parser, "Import workflow" is
//    missing from Sim (React always lists it); it shows disabled instead,
//    skipped by the arrows and inert on click;
// 7. a row box is `w-full` plus `mx-0.5`: as wide as the group and 2px in,
//    so it overhangs the group by 2px on the right; the port shrank it;
// 8. the input id sits on the text line, not on the 32px `h-8` input box
//    that starts 4px left of the text (`-ml-1 indent-1`);
// 9. a group the list scrolls partly out of view reports its clipped
//    height, and one below the list that the screen edge cuts reports the
//    part on screen; React reports the element box either way;
// 10. the shortcut hint is one inherited `text-sm` line (13px at the
//     20/14 ratio, 18.57px), not 13px at 1.5.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_app/features/workspace_shell/chrome/search_palette_controller.dart';
import 'package:sim_app/features/workspace_shell/search/palette_content.dart';
import 'package:sim_app/features/workspace_shell/search/palette_models.dart';
import 'package:sim_app/features/workspace_shell/search/search_palette.dart';
import 'package:sim_app/features/workspace_shell/shared/app_links.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_events.dart';

import 'support/semantics_geometry.dart';
import 'support/shell_fixtures.dart';

/// A source list that counts how often the ranking walks it.
class _CountingList<T> extends ListBase<T> {
  _CountingList(this._items);

  final List<T> _items;
  int reads = 0;

  @override
  int get length => _items.length;

  @override
  set length(int value) => _items.length = value;

  @override
  T operator [](int index) => _items[index];

  @override
  void operator []=(int index, T value) => _items[index] = value;

  @override
  Iterator<T> get iterator {
    reads++;
    return _items.iterator;
  }
}

void main() {
  late ShellFixture fixture;
  late SearchPaletteController controller;

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
  });

  tearDown(() async {
    controller.dispose();
    await fixture.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    PaletteSources sources = const PaletteSources(),
    String? workflowId,
    bool sidebarHandlers = false,
    AppLinks? links,
    Size size = shellViewport,
  }) async {
    await pumpShell(
      tester,
      size: size,
      SearchPaletteLayer(
        controller: controller,
        workspaceId: workspaceId,
        pathname: workflowId == null
            ? '/workspace/$workspaceId/home'
            : '/workspace/$workspaceId/w/$workflowId',
        currentWorkflowId: workflowId,
        sidebarWidth: 224,
        links: links,
        sources: sources,
        dependencies: SearchPaletteDependencies(
          workspaces: fixture.workspaces,
          workflows: fixture.workflows,
          folders: fixture.folders,
          deploymentShape: fixture.deploymentShape,
          permissions: fixture.permissions,
        ),
        onNavigate: (_) {},
        onCreateWorkflow: () {},
        child: const SizedBox.expand(),
      ),
    );
    controller.open();
    await tester.pumpAndSettle();
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
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

  testWidgets('1. a list update keeps the selection on the same item', (
    tester,
  ) async {
    await pump(tester);
    await key(tester, LogicalKeyboardKey.end);
    expect(selectedLabel(tester), 'Beta');
    when(
      () => fixture.workflowsRepo.list(
        workspaceId: any(named: 'workspaceId'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => [
        workflow(id: 'wf-0', name: 'Alpha'),
        workflow(id: 'wf-1', name: 'Onboarding'),
      ],
    );
    await tester.runAsync(
      () => fixture.workflows.onWorkspaceWorkflowsChanged(workspaceId),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(selectedLabel(tester), 'Beta');
  });

  testWidgets('2. arrows and hover do not re-rank', (tester) async {
    final files = _CountingList<PaletteFolderedItem>([
      for (var i = 0; i < 3; i++)
        PaletteFolderedItem(
          id: 'f$i',
          name: 'File $i',
          href: '/workspace/$workspaceId/files/f$i',
        ),
    ]);
    await pump(tester, sources: PaletteSources(files: files));
    final before = files.reads;
    for (var i = 0; i < 4; i++) {
      await key(tester, LogicalKeyboardKey.arrowDown);
    }
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(files.reads, before);
    await tester.enterText(find.byType(EditableText), 'file');
    await tester.pumpAndSettle();
    expect(files.reads, greaterThan(before), reason: 'a query re-ranks');
  });

  testWidgets(
    '3. the list draws no scrollbar',
    (tester) async {
      final files = [
        for (var i = 0; i < 40; i++)
          PaletteFolderedItem(
            id: 'f$i',
            name: 'File $i',
            href: '/workspace/$workspaceId/files/f$i',
          ),
      ];
      await pump(tester, sources: PaletteSources(files: files));
      expect(
        find.descendant(
          of: byParityId('search.palette.list'),
          matching: find.byWidgetPredicate((w) => w is RawScrollbar),
        ),
        findsNothing,
      );
      // Desktop scroll behaviour (Windows, web on desktop) adds scrollbars.
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('4. the sidebar backs Create folder / Import workflow', (
    tester,
  ) async {
    final calls = <String>[];
    final unregister = SidebarEvents.registerSidebarActions(
      createFolder: () => calls.add('folder'),
      importWorkflow: () => calls.add('import'),
    );
    addTearDown(unregister);
    await pump(tester);
    expect(find.text('Create folder'), findsOneWidget);
    expect(find.text('Import workflow'), findsOneWidget);
    await tester.tap(find.text('Create folder'));
    await tester.pumpAndSettle();
    expect(calls, <String>['folder']);

    unregister();
    await pump(tester);
    expect(find.text('Create folder'), findsNothing);
  });

  testWidgets('5. Copy workflow link copies the route under the app base', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(
      tester,
      workflowId: 'wf-1',
      links: AppLinks(Uri.parse('http://localhost:3001/app/')),
    );
    await tester.enterText(find.byType(EditableText), 'copy');
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.enter);
    expect(copied, <String>[
      'http://localhost:3001/app/workspace/$workspaceId/w/wf-1',
    ]);
  });

  testWidgets('6. Import workflow shows disabled without the parser', (
    tester,
  ) async {
    final calls = <String>[];
    final unregister = SidebarEvents.registerSidebarActions(
      createFolder: () => calls.add('folder'),
    );
    addTearDown(unregister);
    await pump(tester);
    final row = byParityId('search.palette.row.actions.import-workflow');
    expect(row, findsOneWidget);
    expect(
      tester.widget<Semantics>(row).properties.enabled,
      isFalse,
      reason: 'cmdk data-disabled',
    );
    await tester.tap(find.text('Import workflow'));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue, reason: 'a disabled item is inert');

    // New chat, Create workflow, Create folder, then Invite teammates.
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(selectedLabel(tester), 'Create folder');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(selectedLabel(tester), 'Invite teammates');
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(selectedLabel(tester), 'Create folder');
    expect(calls, isEmpty);
  });

  testWidgets('7-10. palette boxes match the React elements', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final unregister = SidebarEvents.registerSidebarActions(
      createFolder: () {},
    );
    addTearDown(unregister);
    await pump(tester);

    // 7. Rows: the group width, 2px in.
    final group = semanticsRectOf(tester, 'search.palette.group.sim');
    final row = semanticsRectOf(tester, 'search.palette.row.actions.new-chat');
    expect(row.left, group.left + 2);
    expect(row.width, group.width);
    expect(row.height, 30);

    // 8. The input box: 32px tall, 4px left of the text.
    final input = semanticsRectOf(tester, 'search.palette.input');
    final icon = semanticsRectOf(tester, 'search.palette.input.icon');
    final text = tester.getRect(find.byType(EditableText));
    expect(input.height, 32);
    expect(input.left, icon.right + 8 - 4);
    expect(input.left, text.left - 4);

    // 9. A group running past the list keeps its full box.
    final list = semanticsRectOf(tester, 'search.palette.list');
    final pagesBox = tester.getRect(byParityId('search.palette.group.pages'));
    expect(
      pagesBox.top < list.bottom && pagesBox.bottom > list.bottom,
      isTrue,
      reason: 'the fixture scrolls Pages partly out of view',
    );
    expect(semanticsRectOf(tester, 'search.palette.group.pages'), pagesBox);

    // 10. The shortcut hint: one 13px line at the inherited 20/14 ratio.
    final hint = semanticsRectOf(tester, 'search.palette.row.shortcut');
    expect(hint.width, 40);
    // The test font rounds the line to whole pixels.
    expect(hint.height, closeTo(13 * 20 / 14, 0.5));
    handle.dispose();
  });

  testWidgets('9. a row past the list and the screen keeps its box', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final unregister = SidebarEvents.registerSidebarActions(
      createFolder: () {},
    );
    addTearDown(unregister);
    await pump(tester, size: const Size(1280, 620));
    const id = 'search.palette.row.pages.settings';
    final box = tester.getRect(byParityId(id));
    final list = semanticsRectOf(tester, 'search.palette.list');
    expect(
      box.top > list.bottom && box.top < 620 && box.bottom > 620,
      isTrue,
      reason: 'below the list, cut by the screen edge',
    );
    expect(semanticsRectOf(tester, id).top, box.top);
    expect(semanticsRectOf(tester, id).size, box.size);
    handle.dispose();
  });
}
