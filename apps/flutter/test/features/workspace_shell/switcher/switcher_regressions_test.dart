// Failure modes of the switcher found by the Phase 1 review, each a test:
// 1. the row context menu is modal: another row's "…" is unreachable while
//    it is open, so the handoff closes the whole switcher [finding 9];
// 2. middle-click on a row does nothing (and on Windows no Ctrl/middle
//    click opened anything) [finding 10];
// 3. an arrow press scrolls the highlighted row to the top of the list
//    even when it is visible; React scrolls to the nearest edge only
//    [finding 12];
// 4. keyboard: ArrowDown on the trigger does not open the menu, a
//    keyboard-opened menu has no focused item so Enter is ignored, and
//    typing a letter does not move to the matching item [finding 27];
// 5. Escape during a rename cancels it and keeps the switcher open (the
//    switcher now reads the overlay's dismissal reason; the reason itself
//    is guarded in sim_design's overlay_test) [finding 27];
// 6. through the sidebar slot, "Invite teammates", "View invitations" and
//    "Upload logo" do nothing (no handlers wired) [finding 8];
// 7. the list box (`-mx-1.5`) bleeds 1px past the 256px menu on each side
//    in React; the menu scroll view clipped its box to the menu (parity
//    sweep, 2026-10-22).

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/sidebar/seams.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/platform/sidebar_browser.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/switcher/workspace_switcher.dart';

import '../search/support/semantics_geometry.dart';
import '../search/support/shell_fixtures.dart';
import '../sidebar/support/harness.dart' show SidebarHarness;

class _PickerBrowser extends SidebarBrowser {
  _PickerBrowser(this.picks);

  final List<String> picks;

  @override
  Future<List<PickedFile>> pickFiles({
    required String accept,
    bool multiple = false,
  }) async {
    picks.add(accept);
    return const <PickedFile>[];
  }
}

void main() {
  late ShellFixture fixture;
  late InertSidebarNavigator navigator;

  setUp(() {
    navigator = InertSidebarNavigator('/workspace/$workspaceId/home');
  });

  tearDown(() => fixture.dispose());

  WorkspaceSwitcherDependencies deps() => WorkspaceSwitcherDependencies(
    workspaces: fixture.workspaces,
    invitations: fixture.invitationsCubit,
    permissions: fixture.permissions,
    session: fixture.session,
    deploymentShape: fixture.deploymentShape,
  );

  Future<void> pumpChip(WidgetTester tester) async {
    await fixture.load();
    await pumpShell(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 143,
            child: WorkspaceSwitcherChip(
              workspaceId: workspaceId,
              collapsed: false,
              navigator: navigator,
              dependencies: deps(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(byParityId('workspace.switcher.trigger'));
    await tester.pumpAndSettle();
  }

  List<Workspace> many(int n) => [
    ws(workspaceId, name: 'Acme'),
    for (var i = 1; i < n; i++) ws('w$i', name: 'Team $i'),
  ];

  testWidgets('1. another row\'s "…" hands the switcher over', (
    tester,
  ) async {
    fixture = ShellFixture(workspaces: many(3));
    await pumpChip(tester);
    await openMenu(tester);
    await tester.tapAt(
      tester.getCenter(byParityId('workspace.switcher.menu.row.w2')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(byParityId('workspace.switcher.context-menu'), findsOneWidget);

    // Hover the row above so its "…" shows, then press it.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(600, 600));
    await mouse.moveTo(
      tester.getCenter(byParityId('workspace.switcher.menu.row.w1')),
    );
    await tester.pump();
    final more = find.descendant(
      of: byParityId('workspace.switcher.menu.row.w1'),
      matching: byParityId('workspace.switcher.menu.row.more'),
    );
    expect(more, findsOneWidget);
    await tester.tapAt(tester.getCenter(more), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(byParityId('workspace.switcher.menu'), findsOneWidget);
    expect(byParityId('workspace.switcher.context-menu'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('2. middle-click opens the workspace in a new tab', (
    tester,
  ) async {
    fixture = ShellFixture(workspaces: many(2));
    await pumpChip(tester);
    await openMenu(tester);
    await tester.tapAt(
      tester.getCenter(byParityId('workspace.switcher.menu.row.w1')),
      buttons: kMiddleMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(navigator.openedInNewTab, <String>['/workspace/w1']);
    expect(navigator.visited, isEmpty);
  });

  testWidgets('7. the list box bleeds past the menu', (tester) async {
    final handle = tester.ensureSemantics();
    fixture = ShellFixture(workspaces: many(1));
    await pumpChip(tester);
    await openMenu(tester);
    final menu = semanticsRectOf(tester, 'workspace.switcher.menu');
    final list = semanticsRectOf(tester, 'workspace.switcher.menu.list');
    expect(menu.width, 256);
    expect(list.left, menu.left - 1);
    expect(list.width, 258);
    expect(list, tester.getRect(byParityId('workspace.switcher.menu.list')));
    handle.dispose();
  });

  testWidgets('3. arrows scroll to the nearest edge only', (tester) async {
    fixture = ShellFixture(workspaces: many(9));
    await pumpChip(tester);
    await openMenu(tester);
    final list = find.descendant(
      of: byParityId('workspace.switcher.menu.list'),
      matching: find.byType(Scrollable),
    );
    ScrollPosition position() =>
        tester.state<ScrollableState>(list.first).position;
    // Search is on (≥ 6): the first ArrowDown highlights row 2, visible.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(position().pixels, 0);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    // The highlighted row is now below the fold: it aligns to the bottom,
    // so it is fully visible at the list's end edge.
    final scrolled = position().pixels;
    expect(scrolled, greaterThan(0));
    final viewport = tester.getRect(list.first);
    final row = tester.getRect(byParityId('workspace.switcher.menu.row.w7'));
    expect(row.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
    expect(row.top, greaterThan(viewport.top), reason: 'not snapped to top');
    // Moving back up by one keeps the (visible) row where it is.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(position().pixels, scrolled);
  });

  testWidgets('4. ArrowDown opens with the first item; typeahead; Enter', (
    tester,
  ) async {
    fixture = ShellFixture(
      workspaces: [
        ws(workspaceId, name: 'Acme'),
        ws('b', name: 'Beta'),
        ws('g', name: 'Gamma'),
      ],
    );
    await pumpChip(tester);
    // Tab moves focus onto the trigger chip, the only focusable control.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(byParityId('workspace.switcher.menu'), findsOneWidget);
    // The first item has focus: Enter activates it (the current workspace
    // only closes the menu).
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(byParityId('workspace.switcher.menu'), findsNothing);
    expect(navigator.visited, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(byParityId('workspace.switcher.menu'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(navigator.visited, <String>['/workspace/g']);
  });

  testWidgets('5. Escape cancels a rename and keeps the switcher', (
    tester,
  ) async {
    fixture = ShellFixture(workspaces: many(2));
    when(
      () => fixture.workspacesRepo.update(
        any(),
        name: any(named: 'name'),
        logoUrl: any(named: 'logoUrl'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => ws('w1', name: 'Renamed'));
    await pumpChip(tester);
    await openMenu(tester);
    await tester.tapAt(
      tester.getCenter(byParityId('workspace.switcher.menu.row.w1')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(byParityId('workspace.switcher.menu.row.rename'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(byParityId('workspace.switcher.menu.row.rename'), findsNothing);
    expect(byParityId('workspace.switcher.menu'), findsOneWidget);
  });

  group('6. through the sidebar slot', () {
    late SidebarHarness h;
    late List<String> picks;

    setUp(() {
      h = SidebarHarness();
      picks = <String>[];
    });

    tearDown(() async {
      await locator.reset();
      await h.dispose();
    });

    Future<void> pumpSlot(WidgetTester tester) async {
      await fixture.load();
      locator
        ..registerSingleton<InvitationsCubit>(fixture.invitationsCubit)
        ..registerSingleton<WorkspacesCubit>(fixture.workspaces)
        ..registerSingleton<PermissionsCubit>(fixture.permissions)
        ..registerSingleton<SessionCubit>(fixture.session)
        ..registerSingleton<DeploymentShapeCubit>(fixture.deploymentShape);
      final services = SidebarServices(
        workflows: h.workflows,
        folders: h.folders,
        permissions: fixture.permissions,
        featureFlags: h.featureFlags,
        deploymentShape: fixture.deploymentShape,
        session: fixture.session,
        workspaces: fixture.workspaces,
        navigator: navigator,
        browser: _PickerBrowser(picks),
      );
      await pumpShell(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 143,
              child: SidebarEnvironment(
                services: services,
                child: const WorkspaceSwitcherSlot(
                  workspaceId: workspaceId,
                  collapsed: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Invite teammates opens the invite modal', (tester) async {
      fixture = ShellFixture(workspaces: many(2));
      await pumpSlot(tester);
      await openMenu(tester);
      await tester.tap(find.text('Invite teammates'));
      await tester.pumpAndSettle();
      expect(byParityId('modal.invite'), findsOneWidget);
    });

    testWidgets('View invitations opens the invitations modal', (
      tester,
    ) async {
      fixture = ShellFixture(
        workspaces: many(2),
        invitations: const [
          InvitationDetails(
            id: 'inv-1',
            kind: InvitationKind.workspace,
            email: 'flutter-e2e@example.com',
            organizationId: null,
            organizationName: null,
            membershipIntent: MembershipIntent.external,
            role: 'member',
            status: 'pending',
            expiresAt: '2026-11-01T00:00:00.000Z',
            createdAt: '2026-10-21T00:00:00.000Z',
            inviterName: 'Ada',
            inviterEmail: 'ada@acme.io',
            grants: [
              InvitationGrant(
                workspaceId: otherWorkspaceId,
                workspaceName: 'Other',
                permission: WorkspacePermission.write,
              ),
            ],
          ),
        ],
      );
      await tester.runAsync(fixture.invitationsCubit.loadMine);
      await pumpSlot(tester);
      await openMenu(tester);
      await tester.tap(find.text('View invitations'));
      await tester.pumpAndSettle();
      expect(byParityId('modal.invitations'), findsOneWidget);
    });

    testWidgets('Upload logo opens the image picker', (tester) async {
      fixture = ShellFixture(workspaces: many(2));
      await pumpSlot(tester);
      await openMenu(tester);
      await tester.tapAt(
        tester.getCenter(
          byParityId('workspace.switcher.menu.row.$workspaceId'),
        ),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload logo'));
      await tester.pumpAndSettle();
      expect(picks, hasLength(1));
      expect(picks.single, contains('image/png'));
    });
  });
}
