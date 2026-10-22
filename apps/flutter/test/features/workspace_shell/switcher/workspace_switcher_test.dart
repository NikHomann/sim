// Failure modes of the switcher widget (`workspace-header.tsx` and the
// workspace hooks), each a test below:
// 1. the chip shows the current workspace without recording a second
//    visit (the chrome records it); the collapsed rail expands instead of
//    opening;
// 2. the menu lists pinned workspaces first in server order, marks the
//    current row, shows the pin indicator, and has the footer actions with
//    role gating (invite admin-only, view invitations only when pending,
//    New workspace disabled by the creation policy);
// 3. search appears at six workspaces, filters, says `No results for "q"`,
//    and Enter switches only after keyboard navigation;
// 4. selecting another workspace navigates to `/workspace/{id}` (through
//    the settings guard), the current one only closes;
// 5. the context menu offers Pin, Rename, Upload logo, Leave, Delete with
//    the role gating, and closes the switcher except after Pin / Rename;
// 6. pin toggling is optimistic, treats 409 (pin) and 404 (unpin) as
//    success, and reverts on other errors without surfacing them;
// 7. inline rename: Enter saves the trimmed name through PATCH, Escape
//    cancels without a request;
// 8. create: the modal's Create is disabled for a blank name, a failure
//    stays in the modal, success switches to the new workspace;
// 9. delete: confirm is disabled until the exact name is typed; deleting
//    the current workspace moves to the next one;
// 10. leave: a refusal toasts the server reason and keeps the modal; a
//     success closes it.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/switcher/switcher_actions.dart';
import 'package:sim_app/features/workspace_shell/switcher/workspace_switcher.dart';
import 'package:sim_design/sim_design.dart';

import '../search/support/shell_fixtures.dart';

class FakeNavigator implements SidebarNavigator {
  FakeNavigator([String location = '/workspace/$workspaceId/home'])
    : _location = ValueNotifier<String>(location);

  final ValueNotifier<String> _location;
  final List<String> went = [];
  final List<String> tabs = [];

  /// Every in-app move passes the settings guard first.
  final List<String> guarded = [];

  // ignore: use_setters_to_change_properties, mirrors a route change
  void moveTo(String path) => _location.value = path;

  @override
  String get location => _location.value;

  @override
  Listenable get changes => _location;

  @override
  void go(String path) {
    guarded.add('guard');
    went.add(path);
  }

  @override
  bool get canOpenInNewTab => true;

  @override
  void openInNewTab(String path) => tabs.add(path);

  @override
  void openExternal(String url) {}

  @override
  String? absoluteUrl(String path) => 'http://localhost:3001/app$path';
}

ApiClientError apiError(int status, [String message = 'Request failed']) =>
    ApiClientError(status: status, message: message);

void main() {
  late ShellFixture fixture;
  late FakeNavigator navigator;

  ShellFixture make({
    List<Workspace>? workspaces,
    List<String> pinned = const [],
    WorkspaceCreationPolicy? policy,
    WorkspacePermission viewer = WorkspacePermission.admin,
    PinnedItemsRepository? pins,
  }) => ShellFixture(
    workspaces: workspaces,
    pinned: pinned,
    policy: policy,
    viewer: viewer,
    pinnedItems: pins,
  );

  setUp(() {
    navigator = FakeNavigator();
    SimToasts.instance.dismissAll();
  });

  tearDown(() => fixture.dispose());

  Future<void> pumpChip(
    WidgetTester tester, {
    bool collapsed = false,
    VoidCallback? onExpand,
    String id = workspaceId,
  }) async {
    await fixture.load();
    await pumpShell(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: collapsed ? 32 : 143,
            child: WorkspaceSwitcherChip(
              workspaceId: id,
              collapsed: collapsed,
              onExpandSidebar: onExpand,
              navigator: navigator,
              dependencies: WorkspaceSwitcherDependencies(
                workspaces: fixture.workspaces,
                invitations: fixture.invitationsCubit,
                permissions: fixture.permissions,
                session: fixture.session,
                deploymentShape: fixture.deploymentShape,
              ),
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

  List<String> rowIds(WidgetTester tester) => [
    for (final element
        in find
            .byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  (w.properties.identifier ?? '').startsWith(
                    'workspace.switcher.menu.row.',
                  ) &&
                  !{
                    'active',
                    'pin',
                    'more',
                    'rename',
                  }.contains(w.properties.identifier!.split('.').last),
            )
            .evaluate())
      (element.widget as Semantics).properties.identifier!.split('.').last,
  ];

  Future<void> openContext(WidgetTester tester, String id) async {
    final row = byParityId('workspace.switcher.menu.row.$id');
    await tester.tapAt(tester.getCenter(row), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  group('1. chip', () {
    testWidgets("names the workspace; the visit is the chrome's", (
      tester,
    ) async {
      fixture = make();
      await pumpChip(tester);
      // The chrome records the visit on workspace entry; the chip must not
      // record it a second time.
      expect(fixture.visits, isEmpty);
      expect(find.text('Acme'), findsOneWidget);
      expect(byParityId('workspace.switcher.trigger.chevron'), findsOneWidget);
    });

    testWidgets('collapsed: the rail chip expands, no menu', (tester) async {
      fixture = make();
      var expanded = 0;
      await pumpChip(tester, collapsed: true, onExpand: () => expanded++);
      await tester.tap(byParityId('workspace.switcher.trigger.collapsed'));
      await tester.pumpAndSettle();
      expect(expanded, 1);
      expect(byParityId('workspace.switcher.menu'), findsNothing);
    });
  });

  group('2. menu content', () {
    testWidgets('pinned first, current active, pin indicator, footer', (
      tester,
    ) async {
      fixture = make(
        workspaces: [
          ws(workspaceId, name: 'Acme'),
          ws('b'),
          ws('c'),
        ],
        pinned: ['c'],
      );
      await pumpChip(tester);
      await openMenu(tester);
      expect(byParityId('workspace.switcher.menu'), findsOneWidget);
      expect(rowIds(tester), ['c', workspaceId, 'b']);
      expect(byParityId('workspace.switcher.menu.row.active'), findsOneWidget);
      expect(byParityId('workspace.switcher.menu.row.pin'), findsOneWidget);
      expect(byParityId('workspace.switcher.menu.search'), findsNothing);
      expect(byParityId('workspace.switcher.menu.new'), findsOneWidget);
      expect(byParityId('workspace.switcher.menu.invite'), findsOneWidget);
      expect(byParityId('workspace.switcher.menu.invitations'), findsNothing);
      final menu = tester.getRect(byParityId('workspace.switcher.menu'));
      final trigger = tester.getRect(byParityId('workspace.switcher.trigger'));
      expect(menu.width, 256);
      expect(menu.left, trigger.left);
      expect(menu.top, trigger.bottom + 8);
    });

    testWidgets('non-admins get no Invite; a refused policy disables New', (
      tester,
    ) async {
      fixture = make(
        viewer: WorkspacePermission.write,
        policy: const WorkspaceCreationPolicy(
          canCreate: false,
          workspaceMode: WorkspaceMode.personal,
          organizationId: null,
          maxWorkspaces: 1,
          currentWorkspaceCount: 1,
          reason: 'Workspace limit reached',
        ),
      );
      await pumpChip(tester);
      await openMenu(tester);
      expect(byParityId('workspace.switcher.menu.invite'), findsNothing);
      await tester.tap(find.text('New workspace'));
      await tester.pumpAndSettle();
      expect(byParityId('modal.create-workspace'), findsNothing);
      expect(byParityId('workspace.switcher.menu'), findsOneWidget);
    });
  });

  group('3. search', () {
    final six = [
      ws(workspaceId, name: 'Acme'),
      for (final n in ['Beta', 'Gamma', 'Delta', 'Epsilon', 'Zeta'])
        ws(n, name: n),
    ];

    testWidgets('appears at six, filters, reports no results', (
      tester,
    ) async {
      fixture = make(workspaces: six);
      await pumpChip(tester);
      await openMenu(tester);
      expect(byParityId('workspace.switcher.menu.search'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'eta');
      await tester.pumpAndSettle();
      expect(rowIds(tester), ['Beta', 'Zeta']);
      await tester.enterText(find.byType(EditableText), 'qq');
      await tester.pumpAndSettle();
      expect(find.text('No results for "qq"'), findsOneWidget);
    });

    testWidgets('Enter is armed only by keyboard navigation', (tester) async {
      fixture = make(workspaces: six);
      await pumpChip(tester);
      await openMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(navigator.went, isEmpty);
      expect(byParityId('workspace.switcher.menu'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(navigator.went, ['/workspace/Beta']);
      expect(byParityId('workspace.switcher.menu'), findsNothing);
    });
  });

  group('4. switching', () {
    testWidgets('another workspace goes through the guard', (tester) async {
      fixture = make(
        workspaces: [
          ws(workspaceId, name: 'Acme'),
          ws('b'),
        ],
      );
      navigator.moveTo('/workspace/$workspaceId/settings/secrets/x');
      await pumpChip(tester);
      await openMenu(tester);
      await tester.tap(find.text('Workspace b'));
      await tester.pumpAndSettle();
      expect(navigator.guarded, ['guard']);
      expect(navigator.went, ['/workspace/b/settings/secrets']);
      expect(byParityId('workspace.switcher.menu'), findsNothing);
    });

    testWidgets('the current workspace only closes', (tester) async {
      fixture = make();
      await pumpChip(tester);
      await openMenu(tester);
      await tester.tap(find.text('Acme').last);
      await tester.pumpAndSettle();
      expect(navigator.went, isEmpty);
      expect(byParityId('workspace.switcher.menu'), findsNothing);
    });

    testWidgets('Ctrl-click opens a new tab', (tester) async {
      fixture = make(
        workspaces: [
          ws(workspaceId, name: 'Acme'),
          ws('b'),
        ],
      );
      await pumpChip(tester);
      await openMenu(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Workspace b'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(navigator.tabs, ['/workspace/b']);
      expect(navigator.went, isEmpty);
    });
  });

  group('5. context menu', () {
    List<String> items() => [
      for (final key in ['pin', 'rename', 'upload-logo', 'leave', 'delete'])
        if (byParityId(
          'workspace.switcher.context-menu.item.$key',
        ).evaluate().isNotEmpty)
          key,
    ];

    bool enabled(WidgetTester tester, String key) => tester
        .widget<SimMenuRow>(
          find.ancestor(
            of: byParityId('workspace.switcher.context-menu.item.$key'),
            matching: find.byType(SimMenuRow),
          ),
        )
        .enabled;

    testWidgets('owner admin: no Leave, everything enabled', (tester) async {
      fixture = make(
        workspaces: [
          ws(workspaceId, name: 'Acme'),
          ws('b'),
        ],
      );
      await pumpChip(tester);
      await openMenu(tester);
      await openContext(tester, workspaceId);
      expect(items(), ['pin', 'rename', 'upload-logo', 'delete']);
      expect(enabled(tester, 'delete'), isTrue);
      expect(enabled(tester, 'rename'), isTrue);
    });

    testWidgets('reader member: Leave shown, mutations disabled', (
      tester,
    ) async {
      fixture = make(
        workspaces: [
          ws(workspaceId, name: 'Acme'),
          ws('b', permissions: WorkspacePermission.read, ownerId: 'other'),
        ],
      );
      await pumpChip(tester);
      await openMenu(tester);
      await openContext(tester, 'b');
      expect(items(), ['pin', 'rename', 'upload-logo', 'leave', 'delete']);
      expect(enabled(tester, 'rename'), isFalse);
      expect(enabled(tester, 'upload-logo'), isFalse);
      expect(enabled(tester, 'delete'), isFalse);
      // A disabled item does nothing.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(byParityId('modal.delete-workspace'), findsNothing);
    });

    testWidgets('the only workspace cannot be deleted', (tester) async {
      fixture = make();
      await pumpChip(tester);
      await openMenu(tester);
      await openContext(tester, workspaceId);
      expect(enabled(tester, 'delete'), isFalse);
    });

    testWidgets('Escape closes the context menu and the switcher', (
      tester,
    ) async {
      fixture = make();
      await pumpChip(tester);
      await openMenu(tester);
      await openContext(tester, workspaceId);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(byParityId('workspace.switcher.context-menu'), findsNothing);
      expect(byParityId('workspace.switcher.menu'), findsNothing);
    });

    testWidgets('right-click on the trigger targets the active workspace', (
      tester,
    ) async {
      fixture = make();
      await pumpChip(tester);
      await tester.tapAt(
        tester.getCenter(byParityId('workspace.switcher.trigger')),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      expect(byParityId('workspace.switcher.context-menu'), findsOneWidget);
      expect(byParityId('workspace.switcher.menu'), findsNothing);
    });
  });

  group('6. pin toggling', () {
    for (final (label, pinned, status) in [
      ('pin tolerates 409', <String>[], 409),
      ('unpin tolerates 404', ['b'], 404),
    ]) {
      testWidgets(label, (tester) async {
        fixture = make(
          workspaces: [
            ws(workspaceId, name: 'Acme'),
            ws('b'),
          ],
          pinned: pinned,
          pins: PinnedItemsRepository(_FailingHttp(status)),
        );
        await pumpChip(tester);
        await openMenu(tester);
        await openContext(tester, 'b');
        fixture.serverList = fixture.serverList.copyWith(
          pinnedWorkspaceIds: pinned.isEmpty ? ['b'] : [],
        );
        await tester.tap(find.text(pinned.isEmpty ? 'Pin' : 'Unpin'));
        await tester.pumpAndSettle();
        // The switcher stays open and the row moved.
        expect(byParityId('workspace.switcher.menu'), findsOneWidget);
        expect(
          rowIds(tester),
          pinned.isEmpty ? ['b', workspaceId] : [workspaceId, 'b'],
        );
        expect(SimToasts.instance.toasts, isEmpty);
      });
    }

    testWidgets('another failure reverts silently', (tester) async {
      fixture = make(
        workspaces: [
          ws(workspaceId, name: 'Acme'),
          ws('b'),
        ],
      );
      when(
        () => fixture.pinsRepo.toggleWorkspacePin(
          workspaceId: any(named: 'workspaceId'),
          pinned: any(named: 'pinned'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(apiError(500));
      await pumpChip(tester);
      await openMenu(tester);
      await openContext(tester, 'b');
      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();
      expect(rowIds(tester), [workspaceId, 'b']);
      expect(fixture.workspaces.state.pinnedIds, isEmpty);
      expect(SimToasts.instance.toasts, isEmpty);
    });
  });

  group('7. rename', () {
    testWidgets('Enter saves the trimmed name; the menu stays open', (
      tester,
    ) async {
      fixture = make();
      when(
        () => fixture.workspacesRepo.update(
          any(),
          name: any(named: 'name'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => ws(workspaceId, name: 'Renamed'));
      await pumpChip(tester);
      await openMenu(tester);
      await openContext(tester, workspaceId);
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(byParityId('workspace.switcher.menu.row.rename'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '  Renamed  ');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      verify(
        () => fixture.workspacesRepo.update(
          workspaceId,
          name: 'Renamed',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
      expect(byParityId('workspace.switcher.menu.row.rename'), findsNothing);
      expect(byParityId('workspace.switcher.menu'), findsOneWidget);
    });

    testWidgets('Escape cancels without a request', (tester) async {
      fixture = make();
      await pumpChip(tester);
      await openMenu(tester);
      await openContext(tester, workspaceId);
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Other');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(byParityId('workspace.switcher.menu.row.rename'), findsNothing);
      expect(byParityId('workspace.switcher.menu'), findsOneWidget);
      verifyNever(
        () => fixture.workspacesRepo.update(
          any(),
          name: any(named: 'name'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });
  });

  group('8. create', () {
    testWidgets('blank disabled, failure inline, success switches', (
      tester,
    ) async {
      fixture = make();
      var attempts = 0;
      when(
        () => fixture.workspacesRepo.create(
          name: any(named: 'name'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        attempts++;
        if (attempts == 1) throw apiError(403, 'Workspace limit reached');
        return ws('new', name: invocation.namedArguments[#name] as String);
      });
      await pumpChip(tester);
      await openMenu(tester);
      await tester.tap(find.text('New workspace'));
      await tester.pumpAndSettle();
      expect(byParityId('workspace.switcher.menu'), findsNothing);
      expect(byParityId('modal.create-workspace'), findsOneWidget);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(attempts, 0);
      await tester.enterText(find.byType(EditableText), ' Team ');
      await tester.pump();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Workspace limit reached'), findsOneWidget);
      expect(byParityId('modal.create-workspace'), findsOneWidget);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(byParityId('modal.create-workspace'), findsNothing);
      expect(navigator.went, ['/workspace/new']);
      verify(
        () => fixture.workspacesRepo.create(
          name: 'Team',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(2);
    });
  });

  group('9. delete', () {
    testWidgets('needs the exact name; deleting the current moves on', (
      tester,
    ) async {
      fixture = make(
        workspaces: [
          ws(workspaceId, name: 'Acme'),
          ws('b'),
        ],
      );
      when(
        () => fixture.workspacesRepo.delete(
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async {});
      await pumpChip(tester);
      await openMenu(tester);
      await openContext(tester, workspaceId);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(byParityId('workspace.switcher.menu'), findsNothing);
      expect(byParityId('modal.delete-workspace'), findsOneWidget);
      final confirm = find.descendant(
        of: byParityId('modal.delete-workspace'),
        matching: find.widgetWithText(SimChip, 'Delete'),
      );
      expect(tester.widget<SimChip>(confirm).enabled, isFalse);
      await tester.enterText(find.byType(EditableText), 'acme');
      await tester.pump();
      expect(tester.widget<SimChip>(confirm).enabled, isFalse);
      // Enter never confirms.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.enterText(find.byType(EditableText), 'Acme');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      verifyNever(
        () => fixture.workspacesRepo.delete(
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
      expect(tester.widget<SimChip>(confirm).enabled, isTrue);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      verify(
        () => fixture.workspacesRepo.delete(
          workspaceId,
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
      expect(navigator.went, ['/workspace/b']);
      expect(byParityId('modal.delete-workspace'), findsNothing);
    });
  });

  group('10. leave', () {
    testWidgets('a refusal toasts and keeps the modal; success closes', (
      tester,
    ) async {
      fixture = make(
        workspaces: [
          ws(workspaceId, name: 'Acme'),
          ws('b', name: 'Beta', ownerId: 'other'),
        ],
      );
      var attempts = 0;
      when(
        () => fixture.invitationsRepo.removeMember(
          userId: any(named: 'userId'),
          workspaceId: any(named: 'workspaceId'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw apiError(400, 'You are the last admin');
        return true;
      });
      await pumpChip(tester);
      await openMenu(tester);
      await openContext(tester, 'b');
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(byParityId('modal.leave-workspace'), findsOneWidget);
      await tester.tap(find.text('Leave workspace').last);
      await tester.pumpAndSettle();
      expect(
        SimToasts.instance.toasts.single.message,
        "Couldn't leave workspace",
      );
      expect(
        SimToasts.instance.toasts.single.description,
        'You are the last admin',
      );
      expect(byParityId('modal.leave-workspace'), findsOneWidget);
      await tester.tap(find.text('Leave workspace').last);
      await tester.pumpAndSettle();
      expect(byParityId('modal.leave-workspace'), findsNothing);
      verify(
        () => fixture.invitationsRepo.removeMember(
          userId: userId,
          workspaceId: 'b',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(2);
      // Leaving another workspace does not navigate.
      expect(navigator.went, isEmpty);
      SimToasts.instance.dismissAll();
    });
  });

  test('errorMessage falls back for non-API errors', () {
    expect(errorMessage(apiError(400, 'Nope'), 'x'), 'Nope');
    expect(errorMessage(apiError(400, '  '), 'x'), 'x');
    expect(errorMessage(StateError('boom'), 'x'), 'x');
  });
}

/// An HTTP client whose every request fails with [status], so the real
/// [PinnedItemsRepository] decides whether the status is the end state.
class _FailingHttp implements SimHttpClient {
  _FailingHttp(this.status);

  final int status;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(ApiClientError(status: status, message: 'failed'));
}
