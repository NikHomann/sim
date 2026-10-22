// Failure modes of the mounted tree found by the Phase 1 review
// (docs/port/reviews/phase1-sidebar-review-v1.md), each a test below:
// 1. a right-click held past the tap deadline (100 ms) on a row opens the
//    row menu AND the empty-area menu (two secondary-tap recognizers in one
//    arena both fire on the deadline) [finding 3];
// 2. a right-click on a gap between rows must still open the empty-area
//    menu (the hit-position resolution must not swallow it) [finding 3];
// 3. a second click on a row's "…" reopens the menu its own pointer-down
//    just closed (the open state is read at tap-up, after the outside press
//    dismissed it) [finding 18];
// 4. Escape during a drag does nothing: the drag goes on, drops, and the
//    folder it spring-opened stays open [finding 23];
// 5. Enter / Space on the focused tree container does not reset the
//    selection (the container cannot take focus) [finding 23];
// 6. the active workflow's path is only revealed again when the active id,
//    its folder id or the folder count change, so a folder list update
//    after the selection was cleared leaves it unselected and collapsed
//    [finding 19];
// 7. row geometry: the label fills the row and the "…" / lock slot sits
//    8px after it instead of the chip's 6px [finding 22];
// 8. the row context menu, its items and separator, and the rail flyout's
//    New / folder rows carry no parity ids [finding 26];
// 9. the browser's own context menu is never switched off on web, so it
//    opens over the Flutter menus [finding 4].

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/shared/browser_context_menu.dart';

import 'support/harness.dart';

void main() {
  late SidebarHarness h;

  setUpAll(() {
    registerFallbackValue(const WorkflowUpdate());
    registerFallbackValue(const FolderUpdate());
  });

  setUp(() => h = SidebarHarness());
  tearDown(() => h.dispose());

  Rect rectOf(WidgetTester tester, String id) =>
      tester.getRect(byParity(id).first);

  Finder inRow(String rowId, String id) =>
      find.descendant(of: byParity(rowId), matching: byParity(id));

  testWidgets('1. a held right-click on a row opens only the row menu', (
    tester,
  ) async {
    await pumpSidebar(tester, h);
    final row = rectOf(tester, 'sidebar.tree.workflow-row.w-bench');
    final gesture = await tester.startGesture(
      row.center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(byParity('sidebar.tree.context-menu'), findsOneWidget);
    expect(byParity('sidebar.tree.empty-menu'), findsNothing);
  });

  testWidgets('2. a right-click on a row gap opens the empty-area menu', (
    tester,
  ) async {
    await pumpSidebar(tester, h);
    final empty = rectOf(tester, 'sidebar.tree.workflow-row.w-empty');
    await tester.tapAt(
      Offset(empty.center.dx, empty.bottom + 1),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(byParity('sidebar.tree.empty-menu'), findsOneWidget);
    expect(byParity('sidebar.tree.context-menu'), findsNothing);
  });

  testWidgets('3. a second "…" click closes the menu instead of reopening', (
    tester,
  ) async {
    await pumpSidebar(tester, h);
    final row = rectOf(tester, 'sidebar.tree.workflow-row.w-bench');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: row.center);
    await tester.pump();
    final more = find.bySemanticsLabel('Workflow options');
    expect(more, findsOneWidget);
    final at = tester.getCenter(more);
    await tester.tapAt(at, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(byParity('sidebar.tree.context-menu'), findsOneWidget);
    await tester.tapAt(at, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(byParity('sidebar.tree.context-menu'), findsNothing);
    expect(h.tree.state.menuOpenId, isNull);
    await mouse.removePointer();
  });

  testWidgets('4. Escape cancels a drag: no drop, spring-open undone', (
    tester,
  ) async {
    await pumpSidebar(tester, h);
    final source = rectOf(tester, 'sidebar.tree.workflow-row.w-bench').center;
    final folder = rectOf(tester, 'sidebar.tree.folder-row.f-ops');
    final gesture = await tester.startGesture(
      source,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 6));
    await tester.pump();
    await gesture.moveTo(folder.center);
    await tester.pump();
    await gesture.moveTo(folder.center + const Offset(0, 1));
    await tester.pump();
    expect(h.tree.state.isDragging, isTrue);
    await tester.pump(const Duration(milliseconds: 450));
    expect(h.tree.state.isExpanded('f-ops'), isTrue, reason: 'spring-open');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(h.tree.state.isDragging, isFalse);
    expect(h.tree.state.isExpanded('f-ops'), isFalse);
    expect(byParity('sidebar.tree.drag-ghost'), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    verifyNever(
      () => h.workflowsRepo.reorder(
        workspaceId: any(named: 'workspaceId'),
        updates: any(named: 'updates'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
    expect(h.tree.state.isDragging, isFalse);
  });

  testWidgets('5. Enter on the focused tree container resets the selection', (
    tester,
  ) async {
    await pumpSidebar(tester, h);
    h.tree.selectOnly('w-bench');
    await tester.pump();
    final tree = tester.widget<Focus>(
      find.byWidgetPredicate(
        (w) => w is Focus && w.focusNode?.debugLabel == 'sidebar.tree',
      ),
    );
    tree.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(h.tree.state.selectedWorkflows, <String>{'w-empty'});
    expect(tree.focusNode!.skipTraversal, isTrue, reason: 'not a tab stop');
  });

  testWidgets('6. a folder list update re-reveals the active workflow', (
    tester,
  ) async {
    h.navigator.location = '/workspace/$workspaceId/w/w-mixed';
    await pumpSidebar(tester, h);
    await tester.pump();
    expect(h.tree.state.selectedWorkflows, <String>{'w-mixed'});
    h.tree
      ..clearAllSelection()
      ..toggleExpanded('f-e2e');
    await tester.pump();
    expect(h.tree.state.isExpanded('f-e2e'), isFalse);

    h.serverFolders = <Folder>[
      for (final f in seedFolders())
        f.id == 'f-ops' ? fd('f-ops', name: 'Platform', sortOrder: 3) : f,
    ];
    await tester.runAsync(
      () => h.workflows.onWorkspaceWorkflowsChanged(workspaceId),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Platform'), findsOneWidget);
    expect(h.tree.state.isExpanded('f-e2e'), isTrue);
    expect(h.tree.state.selectedWorkflows, <String>{'w-mixed'});
  });

  testWidgets('7. the label hugs its text; the action slot sits 6px after', (
    tester,
  ) async {
    h.serverWorkflows = <WorkflowListItem>[
      ...seedWorkflows(),
      wf(
        'w-long',
        name: 'A workflow name far too long for the sidebar row',
        sortOrder: 9,
        locked: true,
      ),
      wf('w-short', name: 'Ab', sortOrder: 10),
    ];
    await pumpSidebar(tester, h);
    const row = 'sidebar.tree.workflow-row.w-long';
    final label = tester.getRect(
      inRow(row, 'sidebar.tree.workflow-row.label'),
    );
    final actions = tester.getRect(
      inRow(row, 'sidebar.tree.workflow-row.actions'),
    );
    expect(actions.left - label.right, 6);
    expect(actions.right, rectOf(tester, row).right - 8);

    final short = tester.getRect(
      inRow(
        'sidebar.tree.workflow-row.w-short',
        'sidebar.tree.workflow-row.label',
      ),
    );
    final shortRow = rectOf(tester, 'sidebar.tree.workflow-row.w-short');
    expect(short.width, lessThan(shortRow.width / 2));
  });

  testWidgets('8. parity ids on the row menu and the rail flyout', (
    tester,
  ) async {
    await pumpSidebar(tester, h);
    await tester.tap(
      byParity('sidebar.tree.workflow-row.w-bench').first,
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(byParity('sidebar.tree.context-menu'), findsOneWidget);
    for (final id in <String>[
      'open-new-tab',
      'rename',
      'duplicate',
      'delete',
    ]) {
      expect(
        byParity('sidebar.tree.context-menu.item.$id'),
        findsOneWidget,
        reason: id,
      );
    }
    expect(byParity('sidebar.tree.context-menu.separator'), findsOneWidget);
    expect(byParity('sidebar.workflows.section'), findsOneWidget);
    expect(byParity('sidebar.workflows.header'), findsOneWidget);
    expect(byParity('sidebar.workflows.header.title'), findsOneWidget);
    // The header's icon buttons keep their 20×20 box in the 18px row.
    expect(
      rectOf(tester, 'sidebar.workflows.header.new').size,
      const Size(20, 20),
    );
    expect(
      rectOf(tester, 'sidebar.workflows.header.more').size,
      const Size(20, 20),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await pumpSidebar(tester, h, collapsed: true);
    final chip = rectOf(tester, 'sidebar.rail.workflows.chip');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 400));
    await mouse.moveTo(chip.center);
    await tester.pump();
    expect(byParity('sidebar.rail.workflows.flyout.new'), findsOneWidget);
    expect(
      byParity('sidebar.rail.workflows.flyout.folder.f-e2e'),
      findsOneWidget,
    );
    await mouse.removePointer();
  });

  testWidgets('9. the browser context menu is off while the sidebar lives', (
    tester,
  ) async {
    final calls = <bool>[];
    final original = SuppressBrowserContextMenu.setEnabled;
    SuppressBrowserContextMenu.setEnabled = ({required enabled}) async =>
        calls.add(enabled);
    addTearDown(() => SuppressBrowserContextMenu.setEnabled = original);
    await pumpSidebar(tester, h);
    expect(calls, <bool>[false]);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(calls, <bool>[false, true]);
  });
}
