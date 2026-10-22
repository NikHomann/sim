// Failure modes (entry-resolution.md §1-§9, one test per row with a page):
// - `/` or `/home`: a signed-out visitor is not sent to /login; a signed-in
//   one does not reach the picker and from there a workspace; a session
//   error is treated as signed out
// - app surfaces are not gated for signed-out visitors, or a session error
//   bounces to /login
// - picker: lastActiveWorkspaceId is ignored; `?redirect=settings|upgrade`
//   and a known `?reason=` are dropped (or an unknown reason kept);
//   `?redirect_workflow=` does not resolve the workflow's workspace or has
//   no fallback
// - picker: an empty list with creation blocked does not show the blocked
//   card (with the copy for its reason) or creation allowed does not create
//   "My Workspace"; a 409 retries more than once; another failure does not
//   go to /login
// - picker: a 401 on the list or a clean null session does not recover
//   (sign out + wipe + /login); a failed recovery has no error card
// - `/workspace/:id` ignores chatEnabled; `/home` stays reachable with chat
//   disabled
// - settings: legacy sections do not redirect, aliases redirect instead of
//   resolving in place, unknown sections render
// - the real app router: `/` does not land in the shell, or the stored dark
//   theme is not applied there; a redirect landing (signed-out deep link →
//   /login) keeps the pre-redirect theme instead of forcing light
// - entry decisions push history entries (Back from the workspace lands
//   on /home or /workspace, which redirect forward again)
// - a clean null session on the bare picker is bounced to /login by the
//   gate instead of signing the stale cookies out
// - "Try again" on the /home error card does nothing off the web
// - /workspace/:id/w does not open the first workflow

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/app.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/entry/entry_support.dart';

import '../workspace_shell/chrome/support/shell_harness.dart';

class MockUsersRepository extends Mock implements UsersRepository {}

const WorkspaceCreationPolicy blockedPolicy = WorkspaceCreationPolicy(
  canCreate: false,
  workspaceMode: WorkspaceMode.organization,
  organizationId: 'org-1',
  maxWorkspaces: 1,
  currentWorkspaceCount: 0,
  reason: 'blocked',
  blockedReasonCode: CreationBlockedReason.permissionGroupDenied,
);

void main() {
  late ShellHarness h;

  setUp(() async {
    h = ShellHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  void signedOut() => when(
    () => h.auth.getSession(
      disableCookieCache: any(named: 'disableCookieCache'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => null);

  void listReturns(WorkspaceList list) => when(
    () => h.workspacesRepo.list(
      scope: any(named: 'scope'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => list);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pumpAndSettle();
    }
  }

  group('root and /home', () {
    testWidgets('signed out goes to /login', (tester) async {
      signedOut();
      await h.pump(tester, '/');
      await settle(tester);
      expect(h.location, '/login');
    });

    testWidgets('signed in lands in the last active workspace home', (
      tester,
    ) async {
      listReturns(workspaceList(lastActiveWorkspaceId: otherWorkspaceId));
      await h.pump(tester, '/home');
      await settle(tester);
      expect(h.location, '/workspace/$otherWorkspaceId/home');
      expect(byParityId('shell.chrome'), findsOneWidget);
    });

    testWidgets('a session error shows the error card', (tester) async {
      when(
        () => h.auth.getSession(
          disableCookieCache: any(named: 'disableCookieCache'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(apiError(500));
      await h.pump(tester, '/');
      await settle(tester);
      expect(h.location, '/');
      expect(find.text('Could not load your workspaces'), findsOneWidget);

      // Regression (review finding 18): off the web "Try again" retries in
      // the app instead of a no-op browser reload.
      when(
        () => h.auth.getSession(
          disableCookieCache: any(named: 'disableCookieCache'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => session());
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(h.settledLocation, '/workspace/$workspaceId/home');
    });
  });

  testWidgets('app surfaces gate signed-out visitors to /login', (
    tester,
  ) async {
    signedOut();
    await h.pump(tester, '/workspace/$workspaceId/logs');
    await settle(tester);
    expect(h.location, '/login');
  });

  group('picker', () {
    testWidgets('?redirect=settings keeps the destination', (tester) async {
      await h.pump(tester, '/workspace?redirect=settings');
      await settle(tester);
      expect(h.location, '/workspace/$workspaceId/settings/general');
    });

    testWidgets('?redirect=upgrade keeps a known reason only', (tester) async {
      await h.pump(tester, '/workspace?redirect=upgrade&reason=credits');
      await settle(tester);
      expect(h.location, '/workspace/$workspaceId/upgrade?reason=credits');
      expect(
        workspaceDestination(
          'w',
          target: EntryRedirectTarget.upgrade,
          upgradeReason: 'bogus',
        ),
        '/workspace/w/upgrade',
      );
    });

    testWidgets('?redirect_workflow resolves the workflow workspace', (
      tester,
    ) async {
      when(
        () => h.workflowsRepo.summary(
          'wf-1',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => const WorkflowSummary(
          id: 'wf-1',
          name: 'Flow',
          workspaceId: otherWorkspaceId,
          folderId: null,
        ),
      );
      when(
        () => h.workflowsRepo.summary(
          'gone',
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(apiError(404));
      await h.pump(tester, '/workspace?redirect_workflow=wf-1');
      await settle(tester);
      expect(h.location, '/workspace/$otherWorkspaceId/w/wf-1');

      h.router.go('/workspace?redirect_workflow=gone');
      await settle(tester);
      expect(
        h.location,
        '/workspace/$otherWorkspaceId/home',
        reason: 'falls back to the (now last active) target workspace',
      );
    });

    testWidgets('empty list with creation blocked shows the blocked card', (
      tester,
    ) async {
      listReturns(
        const WorkspaceList(
          workspaces: [],
          lastActiveWorkspaceId: null,
          creationPolicy: blockedPolicy,
        ),
      );
      await h.pump(tester, '/workspace');
      await settle(tester);
      expect(byParityId('entry.workspace.card'), findsOneWidget);
      expect(find.text('No workspace access yet'), findsOneWidget);
      expect(
        find.textContaining("Your permission group doesn't allow"),
        findsOneWidget,
      );
      verifyNever(
        () => h.workspacesRepo.create(
          name: any(named: 'name'),
          skipDefaultWorkflow: any(named: 'skipDefaultWorkflow'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    testWidgets('empty list creates "My Workspace" and enters it', (
      tester,
    ) async {
      listReturns(
        const WorkspaceList(workspaces: [], lastActiveWorkspaceId: null),
      );
      when(
        () => h.workspacesRepo.create(
          name: 'My Workspace',
          skipDefaultWorkflow: any(named: 'skipDefaultWorkflow'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => workspace(id: 'fresh'));
      await h.pump(tester, '/workspace');
      await settle(tester);
      expect(h.location, '/workspace/fresh/home');
    });

    testWidgets('a 409 re-resolves once, a second 409 is the error card', (
      tester,
    ) async {
      listReturns(
        const WorkspaceList(workspaces: [], lastActiveWorkspaceId: null),
      );
      when(
        () => h.workspacesRepo.create(
          name: any(named: 'name'),
          skipDefaultWorkflow: any(named: 'skipDefaultWorkflow'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(apiError(409));
      await h.pump(tester, '/workspace');
      await settle(tester);
      verify(
        () => h.workspacesRepo.create(
          name: any(named: 'name'),
          skipDefaultWorkflow: any(named: 'skipDefaultWorkflow'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(2);
      expect(find.text('Could not load your workspaces'), findsOneWidget);
      expect(h.sessionStore.read(workspaceRaceRetryKey), isNull);
    });

    testWidgets('another creation failure goes to /login', (tester) async {
      listReturns(
        const WorkspaceList(workspaces: [], lastActiveWorkspaceId: null),
      );
      when(
        () => h.workspacesRepo.create(
          name: any(named: 'name'),
          skipDefaultWorkflow: any(named: 'skipDefaultWorkflow'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(apiError(500));
      await h.pump(tester, '/workspace');
      await settle(tester);
      expect(h.location, '/login');
    });

    testWidgets('a 401 on the list recovers the stale session', (
      tester,
    ) async {
      when(
        () => h.workspacesRepo.list(
          scope: any(named: 'scope'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => throw apiError(401));
      await h.pump(tester, '/workspace');
      await settle(tester);
      expect(h.actionsLog.signOuts, 1);
      expect(h.actionsLog.clears, 1);
      expect(h.location, '/login');
    });

    // Regression (review finding 16): the gate lets the bare picker through
    // on a null session so it signs stale cookies out (React's recovery).
    testWidgets('a clean null session recovers; failure shows the error card', (
      tester,
    ) async {
      signedOut();
      h.actionsLog.signOutFails = true;
      await h.pump(tester, '/workspace');
      await settle(tester);
      expect(h.actionsLog.signOuts, 1);
      expect(find.text('Could not load your workspaces'), findsOneWidget);
    });
  });

  group('workspace index', () {
    testWidgets('chat disabled sends /workspace/:id and /home to /w', (
      tester,
    ) async {
      when(
        () => h.runtime.publicEnv(cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => const PublicEnv({'NEXT_PUBLIC_CHAT_DISABLED': 'true'}),
      );
      when(
        () => h.runtime.hostContext(
          any(),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => WorkspaceAccess.granted(
          hostContext(deployment: const DeploymentShape(chatEnabled: false)),
        ),
      );
      await h.pump(tester, '/workspace/$workspaceId');
      await settle(tester);
      expect(h.location, '/workspace/$workspaceId/w');
      h.router.go('/workspace/$workspaceId/home');
      await settle(tester);
      expect(h.location, '/workspace/$workspaceId/w');
    });

    testWidgets('chat enabled sends /workspace/:id to home', (tester) async {
      await h.pump(tester, '/workspace/$workspaceId');
      await settle(tester);
      expect(h.location, '/workspace/$workspaceId/home');
    });
  });

  testWidgets('settings: legacy redirects, aliases in place, unknown 404', (
    tester,
  ) async {
    await h.pump(tester, '/workspace/$workspaceId/settings/integrations');
    await settle(tester);
    expect(h.location, '/workspace/$workspaceId/integrations');
    h.router.go('/workspace/$workspaceId/settings/privacy');
    await settle(tester);
    expect(h.location, '/workspace/$workspaceId/settings/general?view=privacy');
    h.router.go('/workspace/$workspaceId/settings/subscription');
    await settle(tester);
    expect(h.location, '/workspace/$workspaceId/settings/subscription');
    expect(find.text('Settings: billing'), findsOneWidget);
    h.router.go('/workspace/$workspaceId/settings/nope');
    await settle(tester);
    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets('the app router lands `/` in the shell in the settings theme', (
    tester,
  ) async {
    final users = MockUsersRepository();
    when(
      () => users.settings(cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => const UserSettings(theme: ThemeSetting.dark));
    locator.registerSingleton<SettingsCubit>(
      SettingsCubit(
        users: users,
        queryClient: h.queries,
        sharedState: h.storage,
      ),
    );
    tester.view.physicalSize = shellViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SimApp());
    await settle(tester);
    expect(byParityId('shell.chrome'), findsOneWidget);
    expect(
      Theme.of(tester.element(byParityId('shell.chrome'))).brightness,
      Brightness.dark,
    );
    expect(h.storage.readTheme(), 'dark', reason: 'synced to sim-theme');
  });

  // Regression (review finding 5): React's entry decisions are
  // `router.replace`; a pushed /home or /workspace entry traps Back.
  group('history', () {
    late List<Map<Object?, Object?>> reports;

    void recordHistory(WidgetTester tester) {
      reports = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (call) async {
          if (call.method == 'routeInformationUpdated') {
            reports.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.navigation,
          null,
        ),
      );
    }

    List<String> pushed() => [
      for (final r in reports)
        if (r['replace'] != true) '${r['uri'] ?? r['location']}',
    ];

    testWidgets('/home → picker → workspace leaves one history entry', (
      tester,
    ) async {
      recordHistory(tester);
      await h.pump(tester, '/workspace/$workspaceId/logs');
      await settle(tester);
      h.router.go('/home');
      await settle(tester);
      expect(h.settledLocation, '/workspace/$workspaceId/home');
      expect(
        pushed().where((uri) => uri == '/home' || uri == '/workspace'),
        isEmpty,
        reason: 'only the destination is in the history',
      );
    });

    testWidgets('the default workspace replaces the picker entry', (
      tester,
    ) async {
      recordHistory(tester);
      await h.pump(tester, '/workspace/$workspaceId/logs');
      await settle(tester);
      listReturns(
        const WorkspaceList(workspaces: [], lastActiveWorkspaceId: null),
      );
      await h.workspaces.refetch();
      when(
        () => h.workspacesRepo.create(
          name: 'My Workspace',
          skipDefaultWorkflow: any(named: 'skipDefaultWorkflow'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => workspace(id: 'fresh'));
      h.router.go('/workspace');
      await settle(tester);
      expect(h.settledLocation, '/workspace/fresh/home');
      expect(reports.last['replace'], isTrue);
    });
  });

  // Regression (review finding 2): the theme follows the location the
  // redirect settled on, not the requested one.
  testWidgets('a signed-out deep link lands on /login in light', (
    tester,
  ) async {
    signedOut();
    h.storage.writeTheme('dark');
    final users = MockUsersRepository();
    when(
      () => users.settings(cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => const UserSettings());
    locator.registerSingleton<SettingsCubit>(
      SettingsCubit(
        users: users,
        queryClient: h.queries,
        sharedState: h.storage,
      ),
    );
    tester.view.physicalSize = shellViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SimApp(
        routerBuilder: () => h.buildRouter('/workspace/$workspaceId/home'),
      ),
    );
    await settle(tester);
    expect(find.text('Login page'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('Login page'))).brightness,
      Brightness.light,
    );
  });

  testWidgets('/workspace/:id/w opens the first workflow of the workspace', (
    tester,
  ) async {
    when(
      () => h.workflowsRepo.list(
        workspaceId: any(named: 'workspaceId'),
        scope: any(named: 'scope'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => [
        workflow(id: 'elsewhere', inWorkspace: otherWorkspaceId),
        workflow(id: 'first'),
      ],
    );
    await h.pump(tester, '/workspace/$workspaceId/w');
    await settle(tester);
    expect(h.settledLocation, '/workspace/$workspaceId/w/first');
  });
}
