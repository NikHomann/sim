// Failure modes (live run 2026-10-22: /workspace/<id>/home rendered the red
// "Stack Overflow" error screen right after sign-in, with nothing logged):
// - the real composition (SimApp + configureLocator + WorkspaceChrome + the
//   real WorkspaceSidebar, switcher chip, search palette layer and global
//   commands scope) overflows the stack or throws while building; the
//   original cause was the BrandingCubit wrapper in WorkspaceChrome closing
//   over the reassigned `shell` local and returning itself (the stub-sidebar
//   chrome tests never register BrandingCubit, so they could not see it)
// - the real sidebar does not show the seeded root folders and workflows,
//   or the home placeholder is missing
// - navigating /home -> /w -> /home inside the shell crashes, or /w does
//   not open the first workflow (w/page.tsx)
// - (live web run 2026-10-22: Ctrl+K, "empty", Enter stayed on /home) the
//   palette input is exposed as a split text field, an enabled wrapper
//   around the focused node, which has no enabled state. The web engine
//   never moves DOM focus to that node, the dialog route parks DOM focus on
//   the list scroller, and when the filtered list stops scrolling the view
//   reports a focus loss: keyboard focus drops to the root and Enter
//   reaches no handler. The VM cannot lose view focus, so the test checks
//   the input's semantics contract, then Enter and a row click navigate.
//
// Unlike the chrome and sidebar tests (stub sidebar, no chrome), this test
// runs the app's own locator wiring with only the repositories replaced by
// mocks answering like the seeded docker stack.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/app.dart';
import 'package:sim_app/app/config.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';

import '../../../data/support/mocks.dart';
import '../sidebar/support/harness.dart'
    show MockHelpRepository, seedFolders, seedWorkflows;

const String home = '/workspace/$workspaceId/home';
const String workflows = '/workspace/$workspaceId/w';

/// Replaces a lazily registered [T] (never instantiated yet) with [value].
Future<void> _override<T extends Object>(T value) async {
  if (locator.isRegistered<T>()) await locator.unregister<T>();
  locator.registerSingleton<T>(value);
}

Future<void> _configureRealLocator() async {
  await configureLocator(
    const AppConfig(surface: AppSurface.web, backendOrigin: null, e2e: true),
  );
  registerFallbackValue(ListScope.active);
  registerFallbackValue(FolderScope.active);
  registerFallbackValue(FolderResourceType.workflow);
  registerFallbackValue(ProviderName.values.first);

  final auth = MockAuthRepository();
  when(
    () => auth.getSession(
      disableCookieCache: any(named: 'disableCookieCache'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => session());

  final runtime = MockRuntimeConfigRepository();
  when(
    () => runtime.hostContext(any(), cancelToken: any(named: 'cancelToken')),
  ).thenAnswer((_) async => WorkspaceAccess.granted(hostContext()));
  when(
    () => runtime.featureFlags(any(), cancelToken: any(named: 'cancelToken')),
  ).thenAnswer((_) async => FeatureFlagsDenied(apiError(404)));
  when(
    () => runtime.publicEnv(cancelToken: any(named: 'cancelToken')),
  ).thenThrow(apiError(404));

  final workspacesRepo = MockWorkspacesRepository();
  when(
    () => workspacesRepo.list(
      scope: any(named: 'scope'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => workspaceList(workspaces: [workspace()]));
  when(
    () => workspacesRepo.permissions(
      any(),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => permissions(viewer: WorkspacePermission.admin));
  when(
    () => workspacesRepo.recordVisit(
      any(),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async {});

  final workflowsRepo = MockWorkflowsRepository();
  when(
    () => workflowsRepo.list(
      workspaceId: any(named: 'workspaceId'),
      scope: any(named: 'scope'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => seedWorkflows());

  final foldersRepo = MockFoldersRepository();
  when(
    () => foldersRepo.list(
      workspaceId: any(named: 'workspaceId'),
      scope: any(named: 'scope'),
      resourceType: any(named: 'resourceType'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => seedFolders());

  final pinnedRepo = MockPinnedItemsRepository();
  when(
    () => pinnedRepo.list(
      workspaceId: any(named: 'workspaceId'),
      resourceType: any(named: 'resourceType'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => <PinnedItem>[]);

  final invitationsRepo = MockInvitationsRepository();
  when(
    () => invitationsRepo.listMine(cancelToken: any(named: 'cancelToken')),
  ).thenAnswer((_) async => <InvitationDetails>[]);

  final usersRepo = MockUsersRepository();
  when(
    () => usersRepo.settings(cancelToken: any(named: 'cancelToken')),
  ).thenAnswer((_) async => const UserSettings());

  final blocksRepo = MockBlocksRepository();
  when(
    () =>
        blocksRepo.customBlocks(any(), cancelToken: any(named: 'cancelToken')),
  ).thenAnswer(
    (_) async => const CustomBlocksResponse(enabled: false, customBlocks: []),
  );
  when(
    () => blocksRepo.visibility(any(), cancelToken: any(named: 'cancelToken')),
  ).thenAnswer((_) async => const BlockVisibility());
  when(
    () => blocksRepo.providerModels(
      any(),
      workspaceId: any(named: 'workspaceId'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => const ProviderModels(models: []));

  // No HTTP client on the VM (the web surface has no backend origin):
  // everything that would reach the network is a mocked repository, and
  // the shell's permission-config source falls back to its fixed form.
  await locator.unregister<SimHttpClient>();
  await _override<QueryClient>(QueryClient());
  await _override<KeyValueStore>(InMemoryKeyValueStore());
  await _override<SharedWebState>(MemorySharedWebState());
  await _override<AuthSessionStore>(MemoryAuthSessionStore());
  await _override<AuthRepository>(auth);
  await _override<RuntimeConfigRepository>(runtime);
  await _override<WorkspacesRepository>(workspacesRepo);
  await _override<WorkflowsRepository>(workflowsRepo);
  await _override<FoldersRepository>(foldersRepo);
  await _override<PinnedItemsRepository>(pinnedRepo);
  await _override<InvitationsRepository>(invitationsRepo);
  await _override<UsersRepository>(usersRepo);
  await _override<OrganizationsRepository>(MockOrganizationsRepository());
  await _override<BlocksRepository>(blocksRepo);
  await _override<HelpRepository>(MockHelpRepository());
}

void main() {
  setUp(_configureRealLocator);
  tearDown(locator.reset);

  testWidgets(
    'the real shell renders /home with the seeded sidebar and survives '
    '/home -> /w -> /home',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      void dumpErrors() {
        for (final e in errors) {
          final frames = (e.stack ?? StackTrace.empty).toString().split('\n');
          // ignore: avoid_print, the trace is the diagnostic of this test.
          print(
            '${e.exceptionAsString()}\n'
            '${frames.take(60).join('\n')}',
          );
        }
      }

      Future<void> settle() async {
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      Future<void> go(String path) async {
        GoRouter.of(tester.element(find.byType(Navigator).first)).go(path);
        await settle();
      }

      await tester.pumpWidget(const SimApp());
      await settle();
      await go(home);
      dumpErrors();
      expect(errors, isEmpty, reason: 'the shell threw while rendering /home');

      expect(placeholder('Home'), findsOneWidget);
      expect(byParity('shell.sidebar'), findsOneWidget);
      for (final row in <String>[
        'E2E folder',
        'Ops',
        'Empty workflow',
        'Benchmark 200 blocks',
      ]) {
        expect(inSidebar(row), findsOneWidget, reason: row);
      }

      await go(workflows);
      dumpErrors();
      expect(errors, isEmpty, reason: 'navigating to /w crashed');
      expect(placeholder('Workflow'), findsOneWidget);
      expect(
        GoRouter.of(
          tester.element(find.byType(Navigator).first),
        ).routerDelegate.currentConfiguration.uri.path,
        '$workflows/w-empty',
        reason: '/w opens the first workflow of the workspace',
      );

      await go(home);
      dumpErrors();
      expect(errors, isEmpty, reason: 'navigating back to /home crashed');
      expect(placeholder('Home'), findsOneWidget);
      expect(inSidebar('E2E folder'), findsOneWidget);
    },
  );

  _paletteTests();
}

void _paletteTests() {
  Future<SemanticsHandle> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The live smoke run keeps semantics on (its finders are parity ids).
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const SimApp());
    await _settle(tester);
    await _settle(tester);
    expect(location(tester), home);
    expect(placeholder('Home'), findsOneWidget);
    return semantics;
  }

  Future<void> openAndType(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    expect(byParity('search.dialog'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, 'empty');
    await _settle(tester);
    expect(byParity('search.palette.row.workflows.w-empty'), findsOneWidget);
    expect(byParity('search.palette.row.selected'), findsOneWidget);
  }

  testWidgets(
    'palette: Ctrl+K, "empty", Enter opens the workflow, with the input '
    'exposed as one focused, enabled text field',
    (tester) async {
      final semantics = await boot(tester);
      await openAndType(tester);

      // On web the engine moves DOM focus only to a focused text field that
      // is also enabled. A split field (an enabled wrapper around a focused
      // node without an enabled state) left DOM focus on the list scroller;
      // when "empty" made the list stop scrolling that node went away, the
      // view reported a focus loss and Enter reached no handler.
      final input = tester.getSemantics(byParity('search.palette.input'));
      final data = input.getSemanticsData();
      expect(data.flagsCollection.isTextField, isTrue, reason: 'text field');
      expect(
        data.flagsCollection.isFocused,
        Tristate.isTrue,
        reason: 'the input node itself carries the keyboard focus',
      );
      expect(
        data.flagsCollection.isEnabled,
        Tristate.isTrue,
        reason: 'the focused text field has an enabled state',
      );
      var nestedTextFields = 0;
      input.visitChildren((child) {
        void visit(SemanticsNode node) {
          if (node.getSemanticsData().flagsCollection.isTextField) {
            nestedTextFields++;
          }
          node.visitChildren((c) {
            visit(c);
            return true;
          });
        }

        visit(child);
        return true;
      });
      expect(nestedTextFields, 0, reason: 'no text field inside the input');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(location(tester), '$workflows/w-empty');
      expect(byParity('search.dialog'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('palette: Ctrl+K, "empty", clicking the row opens the workflow', (
    tester,
  ) async {
    final semantics = await boot(tester);
    await openAndType(tester);
    await tester.tap(byParity('search.palette.row.workflows.w-empty'));
    await _settle(tester);
    expect(location(tester), '$workflows/w-empty');
    expect(byParity('search.dialog'), findsNothing);
    semantics.dispose();
  });
}

String location(WidgetTester tester) => GoRouter.of(
  tester.element(find.byType(Navigator).first),
).routerDelegate.currentConfiguration.uri.path;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder byParity(String identifier) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == identifier,
  description: 'parity id $identifier',
);

Finder placeholder(String title) => find.descendant(
  of: byParity('shell.placeholder'),
  matching: find.text(title),
);

Finder inSidebar(String text) =>
    find.descendant(of: byParity('shell.sidebar'), matching: find.text(text));
