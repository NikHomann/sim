// Phase 1 L5 smoke flow (docs/port/04-test-plan.md §1, §3 Phase 1) against the
// live stack through the same-origin proxy:
//   /app/login -> signed in (minted session cookie, or the login form with
//   SIM_E2E_SIGN_IN=ui) -> workspace home -> sidebar tree shows the seeded rows
//   -> Ctrl+K opens the palette -> type "empty" -> Enter opens the workflow route.
// Every check is recorded in `binding.reportData` (report schema §5); the
// driver (test_driver/integration_test.dart) writes it to E2E_REPORT_PATH.
//
// Waits poll a condition with a timeout (no pumpAndSettle: the live backend
// never settles; no sleeps, no retries).
//
// Run (web, profile, chromedriver on 4444, proxy routing /app/* to 8088):
//   flutter drive --driver=test_driver/integration_test.dart
//     --target=integration_test/phase1_smoke_test.dart -d web-server --profile
//     --web-port 8088 --web-launch-url http://localhost:3005/app/login
//     --browser-dimension 1440x900@1 --chrome-binary <chrome> --driver-port 4444
//     --dart-define=SIM_E2E=true --dart-define=SIM_E2E_COOKIE=<cookieHeader>
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sim_app/main_web.dart' as app;

import 'support/browser.dart';

const _suite = 'phase1-smoke';

/// `name=value` of the minted session cookie (seed.json `session.cookieHeader`).
const _cookie = String.fromEnvironment('SIM_E2E_COOKIE');

/// `cookie` (default) or `ui`: `ui` signs in through the login form, which
/// Better Auth only accepts from a trusted origin (TRUSTED_ORIGINS).
const _signIn = String.fromEnvironment(
  'SIM_E2E_SIGN_IN',
  defaultValue: 'cookie',
);
const _email = String.fromEnvironment(
  'SIM_E2E_EMAIL',
  defaultValue: 'flutter-e2e@example.com',
);
const _password = String.fromEnvironment('SIM_E2E_PASSWORD');
const _userId = String.fromEnvironment(
  'SIM_E2E_USER_ID',
  defaultValue: '74ec8a68-36ee-5159-a49a-3fb9d373ba32',
);
const _workspaceId = String.fromEnvironment(
  'SIM_E2E_WORKSPACE_ID',
  defaultValue: '44098e20-360c-53b2-adb0-efed21a7919c',
);
const _emptyWorkflowId = String.fromEnvironment(
  'SIM_E2E_EMPTY_WORKFLOW_ID',
  defaultValue: '94cb2172-79b9-5f9b-a15e-210e57132b5c',
);
const _benchmarkWorkflowId = String.fromEnvironment(
  'SIM_E2E_BENCHMARK_WORKFLOW_ID',
  defaultValue: '551aa797-397c-5edc-958b-bd768958c92e',
);
const _rootFolderId = String.fromEnvironment(
  'SIM_E2E_FOLDER_ID',
  defaultValue: 'a21eb9d7-7350-580a-bd4b-5f96e6796149',
);

class _Report {
  _Report(this.binding) : startedAt = DateTime.now().toUtc();

  final IntegrationTestWidgetsFlutterBinding binding;
  final DateTime startedAt;
  final List<Map<String, Object?>> checks = [];
  final Map<String, Object?> notes = {};

  Future<void> check(String name, Future<void> Function() body) async {
    final watch = Stopwatch()..start();
    try {
      await body();
      checks.add({
        'name': name,
        'status': 'passed',
        'durationMs': watch.elapsedMilliseconds,
      });
    } catch (error, stack) {
      checks.add({
        'name': name,
        'status': 'failed',
        'durationMs': watch.elapsedMilliseconds,
        'error': '$error'.split('\n').take(6).join('\n'),
        'stack': '$stack'.split('\n').take(8).join('\n'),
      });
      publish();
      rethrow;
    }
    publish();
  }

  void publish() {
    final timings = resourceTimings();
    final failed = checks.any((c) => c['status'] == 'failed');
    binding.reportData = <String, dynamic>{
      'suite': _suite,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': DateTime.now().toUtc().toIso8601String(),
      'status': failed ? 'failed' : 'passed',
      'transport': 'web',
      'baseUrl': Uri.base.origin,
      'signIn': _signIn,
      'buildMode': kProfileMode
          ? 'profile'
          : (kReleaseMode ? 'release' : 'debug'),
      'seed': {
        'userId': _userId,
        'workspaceId': _workspaceId,
        'workflowIds': [_emptyWorkflowId, _benchmarkWorkflowId],
      },
      'requestCount': timings.length,
      'checks': checks,
      'notes': notes,
      'httpErrors': [
        for (final t in timings)
          if (t.status >= 400) {'path': t.path, 'status': t.status},
      ],
    };
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  bool absent = false,
  String? what,
}) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty != absent) return;
  }
  throw TestFailure(
    'timed out after ${timeout.inSeconds}s waiting for '
    '${absent ? 'absence of ' : ''}${what ?? finder}',
  );
}

Future<void> _waitForPath(
  WidgetTester tester,
  bool Function(String path) matches, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 100));
    final path = currentPath();
    if (path != null && matches(path)) return;
  }
  throw TestFailure(
    'timed out after ${timeout.inSeconds}s; location is ${currentPath()}',
  );
}

/// Sends a key with an explicit physical key: the simulator otherwise derives
/// it from `LogicalKeyboardKey.debugName`, which is null outside debug builds
/// (L5 runs in profile).
Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey logical,
  PhysicalKeyboardKey physical, {
  bool down = true,
  bool up = true,
}) async {
  if (down) await tester.sendKeyDownEvent(logical, physicalKey: physical);
  if (up) await tester.sendKeyUpEvent(logical, physicalKey: physical);
}

Finder _id(String identifier) => find.bySemanticsIdentifier(identifier);

/// Semantics identifiers currently in the tree that start with [prefix]
/// (failure context for the report).
List<String> _identifiers(WidgetTester tester, String prefix) {
  final found = <String>[];
  void visit(SemanticsNode node) {
    if (node.identifier.startsWith(prefix)) found.add(node.identifier);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  final root =
      tester.binding.rootPipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root != null) visit(root);
  for (final view in tester.binding.renderViews) {
    final viewRoot = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (viewRoot != null) visit(viewRoot);
  }
  return found;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('phase 1 smoke: login, sidebar tree, palette to workflow', (
    tester,
  ) async {
    final report = _Report(binding)..publish();
    final semantics = tester.ensureSemantics();

    if (_signIn == 'cookie') {
      expect(
        _cookie,
        isNotEmpty,
        reason: 'pass --dart-define=SIM_E2E_COOKIE=<seed session.cookieHeader>',
      );
      setDocumentCookie(_cookie);
    }

    // The integration binding keeps the platform text input; route text entry
    // through TestTextInput so enterText reaches the app (the plan's
    // registerFakeKeyboard seam). Registered before any field takes focus.
    tester.testTextInput.register();

    // bootstrap() installs the app's FlutterError.onError; chain the test
    // binding's handler behind it so framework errors still fail the test.
    final testOnError = FlutterError.onError;
    await app.main();
    final appOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      appOnError?.call(details);
      testOnError?.call(details);
    };

    if (_signIn == 'ui') {
      await report.check('login form renders', () async {
        await _waitFor(tester, _id('auth.login.email.field'));
      });
      await report.check('sign in through the form', () async {
        expect(_password, isNotEmpty, reason: 'pass SIM_E2E_PASSWORD');
        final fields = find.byType(EditableText);
        await _waitFor(tester, fields);
        await tester.enterText(fields.at(0), _email);
        await tester.enterText(fields.at(1), _password);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      });
    }

    await report.check(
      'signed-in visitor lands on the workspace home',
      () async {
        await _waitForPath(
          tester,
          (path) => path.endsWith('/workspace/$_workspaceId/home'),
          timeout: const Duration(seconds: 60),
        );
        await _waitFor(tester, _id('shell.sidebar'), what: 'shell.sidebar');
      },
    );

    await report.check('sidebar tree shows the seeded rows', () async {
      await _waitFor(
        tester,
        _id('sidebar.tree.workflow-row.$_emptyWorkflowId'),
      );
      expect(_id('sidebar.tree.folder-row.$_rootFolderId'), findsOneWidget);
      expect(
        _id('sidebar.tree.workflow-row.$_benchmarkWorkflowId'),
        findsOneWidget,
      );
      expect(find.text('Empty workflow'), findsWidgets);
      expect(find.text('E2E folder'), findsWidgets);
    });

    await report.check('Ctrl+K opens the search palette', () async {
      await _key(
        tester,
        LogicalKeyboardKey.controlLeft,
        PhysicalKeyboardKey.controlLeft,
        up: false,
      );
      await _key(tester, LogicalKeyboardKey.keyK, PhysicalKeyboardKey.keyK);
      await _key(
        tester,
        LogicalKeyboardKey.controlLeft,
        PhysicalKeyboardKey.controlLeft,
        down: false,
      );
      await _waitFor(tester, _id('search.dialog'), what: 'search.dialog');
    });

    await report.check('typing "empty" narrows to the workflow row', () async {
      // The palette input is the only text field on the workspace home.
      final input = find.byType(EditableText);
      await _waitFor(tester, input, what: 'the palette input');
      await tester.enterText(input.last, 'empty');
      // A query switches the palette to the ranked `results` group.
      final results = _id('search.palette.group.results');
      Finder inResults(String text) =>
          find.descendant(of: results, matching: find.text(text));
      try {
        await _waitFor(
          tester,
          inResults('Empty workflow'),
          what: 'results row',
        );
        await _waitFor(
          tester,
          inResults('Benchmark 200 blocks'),
          absent: true,
          what: 'the benchmark row (filtered out by "empty")',
        );
      } on TestFailure catch (failure) {
        final typed = tester.widget<EditableText>(input.last).controller.text;
        throw TestFailure(
          '${failure.message}; input "$typed"; identifiers: '
          '${_identifiers(tester, 'search.')}',
        );
      }
      // Spec ids are `search.palette.row.<section>.<id>` in results mode too;
      // record what the ranked rows expose for the parity follow-up.
      report.notes['resultsRowIdentifiers'] = _identifiers(
        tester,
        'search.palette.row',
      );
    });

    await report.check('Enter opens the workflow route', () async {
      await _key(tester, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
      await _waitForPath(
        tester,
        (path) => path.endsWith('/workspace/$_workspaceId/w/$_emptyWorkflowId'),
      );
      await _waitFor(
        tester,
        _id('shell.placeholder'),
        what: 'shell.placeholder',
      );
      expect(_id('search.dialog'), findsNothing);
    });

    semantics.dispose();
  });
}
