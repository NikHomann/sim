// Failure modes of the mounted sidebar (workspace-sidebar.md,
// sidebar-workflow-tree.md):
// 1. layout rhythm: 8px header inset, 30px rows with 1px gaps, the nav 16px
//    below the header, sections 16px apart, the tree's 20px indent, the
//    children's 2px offset and the 1px guide at level*20+12;
// 2. order: root rows interleaved by sortOrder; the route workflow row is
//    active; its folder path is expanded on load;
// 3. gating: Dashboard only with its flag; chat off removes Chats and
//    turns home into "New workflow"; read-only members get disabled
//    header buttons;
// 4. interactions: folder click toggles, double-click renames (Enter
//    saves through the cubit), right-click opens the menu in spec order;
// 5. DnD: dropping a root workflow into a folder's middle band sends one
//    workflow reorder with the folder as destination and no folder PUT;
// 6. footer: profile and help menus list their items in order; Contact
//    support opens the modal and submits through the help repository;
// 7. collapsed rail: 32px chips, the Workflows flyout opens on hover and
//    closes 150ms after the pointer leaves.

import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';

import 'support/harness.dart';

void main() {
  late SidebarHarness h;

  setUpAll(() {
    registerFallbackValue(const WorkflowUpdate());
    registerFallbackValue(const FolderUpdate());
    registerFallbackValue(
      const HelpRequest(
        subject: '',
        message: '',
        type: HelpRequestType.bug,
        userAgent: '',
      ),
    );
  });

  setUp(() => h = SidebarHarness());
  tearDown(() => h.dispose());

  Rect rectOf(WidgetTester tester, String id) =>
      tester.getRect(byParity(id).first);

  testWidgets('layout rhythm and tree geometry', (tester) async {
    await pumpSidebar(tester, h);
    final header = rectOf(tester, 'shell.sidebar.header.search');
    expect(header.top, 8);
    expect(header.height, 30);
    expect(rectOf(tester, 'shell.sidebar.header.actions').width, 65);
    final home = rectOf(tester, 'shell.sidebar.nav.home');
    expect(home.top, 54);
    expect(home.left, 8);
    expect(home.width, 208);
    final integrations = rectOf(tester, 'shell.sidebar.nav.integrations');
    expect(integrations.top, home.bottom + 1);

    final empty = rectOf(tester, 'sidebar.tree.workflow-row.w-empty');
    final folder = rectOf(tester, 'sidebar.tree.folder-row.f-e2e');
    expect(empty.height, 30);
    expect(folder.top, empty.bottom + 2);
    // The route workflow lives at the root; its folder path stays closed.
    expect(byParity('sidebar.tree.workflow-row.active'), findsOneWidget);

    await tester.tap(byParity('sidebar.tree.folder-row.f-e2e').first);
    await tester.pump();
    final nestedRow = rectOf(tester, 'sidebar.tree.folder-row.f-nested');
    final child = rectOf(tester, 'sidebar.tree.workflow-row.w-mixed');
    expect(nestedRow.top, folder.bottom + 2);
    expect(child.top, nestedRow.bottom + 2);
    expect(child.left, folder.left + 20 + 2);
    final guide = rectOf(tester, 'sidebar.tree.folder.guide');
    expect(guide.width, 1);
    expect(guide.left, folder.left + 12);
    final nested = rectOf(tester, 'sidebar.tree.folder-row.f-nested');
    expect(nested.left, folder.left + 22);
  });

  testWidgets('root rows interleave by order; route row active', (
    tester,
  ) async {
    await pumpSidebar(tester, h);
    final tops = <String, double>{
      for (final id in <String>[
        'workflow-row.w-empty',
        'folder-row.f-e2e',
        'workflow-row.w-bench',
        'folder-row.f-ops',
      ])
        id: rectOf(tester, 'sidebar.tree.$id').top,
    };
    final ordered = tops.keys.toList()
      ..sort((a, b) => tops[a]!.compareTo(tops[b]!));
    expect(ordered, <String>[
      'workflow-row.w-empty',
      'folder-row.f-e2e',
      'workflow-row.w-bench',
      'folder-row.f-ops',
    ]);
    expect(
      tester.getRect(byParity('sidebar.tree.workflow-row.active')),
      rectOf(tester, 'sidebar.tree.workflow-row.w-empty'),
    );
  });

  testWidgets('the route workflow folder path opens on load', (tester) async {
    h.navigator.location = '/workspace/$workspaceId/w/w-mixed';
    await pumpSidebar(tester, h);
    await tester.pump();
    expect(byParity('sidebar.tree.workflow-row.w-mixed'), findsOneWidget);
    expect(h.tree.state.selectedWorkflows, <String>{'w-mixed'});
  });

  testWidgets('flags and chat gating', (tester) async {
    h
      ..flags = const WorkspaceFeatureFlags(dashboards: true)
      ..shape = const DeploymentShape(chatEnabled: false);
    await pumpSidebar(tester, h);
    expect(byParity('shell.sidebar.nav.dashboards'), findsOneWidget);
    expect(byParity('shell.sidebar.nav.changelog'), findsNothing);
    expect(byParity('shell.sidebar.chats'), findsNothing);
    expect(find.text('New workflow'), findsOneWidget);
  });

  testWidgets('chats empty state with chat enabled', (tester) async {
    await pumpSidebar(tester, h);
    expect(byParity('shell.sidebar.chats'), findsOneWidget);
    expect(find.text('No chats yet'), findsOneWidget);
  });

  testWidgets('read-only members get disabled header buttons', (
    tester,
  ) async {
    h.permission = WorkspacePermission.read;
    await pumpSidebar(tester, h);
    final semantics = tester.getSemantics(
      find.bySemanticsLabel('New workflow').last,
    );
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('folder menu order; rename saves through the cubit', (
    tester,
  ) async {
    when(
      () => h.foldersRepo.update(
        any(),
        update: any(named: 'update'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => fd('f-ops', name: 'Platform', sortOrder: 3));
    await pumpSidebar(tester, h);
    final row = byParity('sidebar.tree.folder-row.f-ops').first;
    await tester.tap(row, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    final labels = <String>[
      'Rename',
      'Create workflow',
      'Create folder',
      'Lock',
      'Duplicate',
      'Export',
      'Delete',
    ];
    final tops = labels
        .map((l) => tester.getRect(find.text(l).last).top)
        .toList();
    expect(tops, List<double>.of(tops)..sort());
    expect(h.tree.state.menuOpenId, 'f-ops');
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    expect(byParity('sidebar.tree.folder-row.rename-input'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, '  Platform ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final captured = verify(
      () => h.foldersRepo.update(
        'f-ops',
        update: captureAny(named: 'update'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).captured;
    expect((captured.single as FolderUpdate).name, 'Platform');
    expect(byParity('sidebar.tree.folder-row.rename-input'), findsNothing);
  });

  testWidgets('double-click on a workflow label starts rename', (
    tester,
  ) async {
    await pumpSidebar(tester, h);
    final label = find.text('Benchmark 200 blocks');
    await tester.tap(label);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(label);
    await tester.pump();
    expect(byParity('sidebar.tree.workflow-row.rename-input'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(byParity('sidebar.tree.workflow-row.rename-input'), findsNothing);
  });

  testWidgets('dropping a root workflow into a folder reorders it there', (
    tester,
  ) async {
    when(
      () => h.workflowsRepo.reorder(
        workspaceId: any(named: 'workspaceId'),
        updates: any(named: 'updates'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const ReorderResult(updated: 1));
    await pumpSidebar(tester, h);
    final source = tester.getCenter(
      byParity('sidebar.tree.workflow-row.w-bench').first,
    );
    final target = rectOf(tester, 'sidebar.tree.folder-row.f-ops');
    final gesture = await tester.startGesture(
      source,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 6));
    await tester.pump();
    await gesture.moveTo(target.center);
    await tester.pump();
    await gesture.moveTo(target.center + const Offset(0, 1));
    await tester.pump();
    expect(byParity('sidebar.tree.drop-inside'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    final updates =
        verify(
              () => h.workflowsRepo.reorder(
                workspaceId: workspaceId,
                updates: captureAny(named: 'updates'),
                cancelToken: any(named: 'cancelToken'),
              ),
            ).captured.single
            as List<WorkflowReorderUpdate>;
    expect(updates.map((u) => u.toJson()), <Map<String, Object?>>[
      <String, Object?>{'id': 'w-bench', 'sortOrder': 0, 'folderId': 'f-ops'},
    ]);
    verifyNever(
      () => h.foldersRepo.reorder(
        workspaceId: any(named: 'workspaceId'),
        updates: any(named: 'updates'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
    expect(h.tree.state.isDragging, isFalse);
  });

  testWidgets('footer menus and the help modal', (tester) async {
    when(
      () => h.help.submit(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async {});
    await pumpSidebar(tester, h);
    await tester.tap(find.text('Flutter E2E'));
    await tester.pumpAndSettle();
    final profile = <String>[
      'Settings',
      'Teammates',
      'Recently deleted',
      'Sign out',
    ];
    final tops = profile.map((l) => tester.getRect(find.text(l)).top).toList();
    expect(tops, List<double>.of(tops)..sort());
    await tester.tap(find.text('Teammates'));
    await tester.pumpAndSettle();
    expect(
      h.navigator.visited.last,
      '/workspace/$workspaceId/settings/teammates',
    );

    await tester.tap(find.bySemanticsLabel('Help'));
    await tester.pumpAndSettle();
    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('Join Slack'), findsOneWidget);
    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();
    expect(byParity('shell.sidebar.help-modal'), findsOneWidget);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Subject is required'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(0), 'Broken');
    await tester.enterText(find.byType(EditableText).at(1), 'Details');
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Success'), findsOneWidget);
    final request =
        verify(
              () => h.help.submit(
                captureAny(),
                cancelToken: any(named: 'cancelToken'),
              ),
            ).captured.single
            as HelpRequest;
    expect(request.subject, 'Broken');
    // The Teammates link navigated away from the workflow route.
    expect(request.workflowId, isNull);
    expect(request.workspaceId, workspaceId);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('collapsed rail flyout opens on hover, closes after 150 ms', (
    tester,
  ) async {
    await pumpSidebar(tester, h, collapsed: true);
    final chip = rectOf(tester, 'sidebar.rail.workflows.chip');
    expect(chip.width, 32);
    expect(chip.left, 8);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 400));
    await mouse.moveTo(chip.center);
    await tester.pump();
    expect(byParity('sidebar.rail.workflows.flyout'), findsOneWidget);
    expect(rectOf(tester, 'sidebar.rail.workflows.flyout').width, 220);
    expect(find.text('New workflow'), findsOneWidget);
    await mouse.moveTo(const Offset(400, 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(byParity('sidebar.rail.workflows.flyout'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    expect(byParity('sidebar.rail.workflows.flyout'), findsNothing);
    await mouse.removePointer();
  });
}
