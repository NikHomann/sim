// Phase 1.5 L5 chat flow (docs/port/04-test-plan.md, chat-engine and
// chat-messages specs) against the live stack whose agent service is the
// mock copilot (tools/mock_copilot, scenarios picked by a message starting
// with `#scenario:<name> speed=fast`):
//   sign in -> workspace home -> plain answer (table + code block, actions,
//   URL becomes /chat/<id>) -> tool scenario in the same chat (tool row, then
//   the answer) -> new chat with the long scenario, Stop mid-stream (stopped
//   row) -> the seeded "E2E conversation" chat route shows its history.
// Every check is recorded in `binding.reportData`; the driver
// (test_driver/integration_test.dart) writes it to E2E_REPORT_PATH.
//
// Waits poll a condition with a timeout (no pumpAndSettle, no sleeps).
//
// Run (web, profile, chromedriver on 4444, proxy routing /app/* to 8088), as
// for phase1_smoke_test.dart, with the mock copilot wired into the stack
// (tools/mock_copilot/README.md):
//   flutter drive --driver=test_driver/integration_test.dart
//     --target=integration_test/phase15_chat_test.dart -d web-server --profile
//     --web-port 8088 --web-launch-url http://localhost:3005/app/login
//     --browser-dimension 1440x900@1 --chrome-binary <chrome> --driver-port 4444
//     --dart-define=SIM_E2E=true --dart-define=SIM_E2E_SIGN_IN=ui
//     --dart-define=SIM_E2E_PASSWORD=<seed password>
//   (or SIM_E2E_SIGN_IN=cookie with SIM_E2E_COOKIE=<seed session.cookieHeader>)
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sim_app/main_web.dart' as app;

import 'support/browser.dart';

const _suite = 'phase15-chat';

const _cookie = String.fromEnvironment('SIM_E2E_COOKIE');

/// `ui` (default here) signs in through the login form; `cookie` sets the
/// minted session cookie.
const _signIn = String.fromEnvironment('SIM_E2E_SIGN_IN', defaultValue: 'ui');
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

/// The seeded "E2E conversation" (`tools/seed`, seed.json `chatId`).
const _seededChatId = String.fromEnvironment(
  'SIM_E2E_CHAT_ID',
  defaultValue: 'b65b240b-1fbe-5ea9-bd3c-16a12311cbf6',
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
        'chatId': _seededChatId,
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

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey logical,
  PhysicalKeyboardKey physical,
) async {
  await tester.sendKeyDownEvent(logical, physicalKey: physical);
  await tester.sendKeyUpEvent(logical, physicalKey: physical);
}

Finder _id(String identifier) => find.bySemanticsIdentifier(identifier);

Finder _text(String value) => find.textContaining(value, findRichText: true);

/// Types [message] into the composer and presses Enter.
Future<void> _send(WidgetTester tester, String message) async {
  final editor = find.descendant(
    of: _id('chat-input.root'),
    matching: find.byType(EditableText),
  );
  await _waitFor(tester, editor, what: 'the composer editor');
  await tester.tap(editor.first);
  await tester.pump();
  await tester.enterText(editor.first, message);
  await tester.pump();
  await _key(tester, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
}

Future<void> _waitForCount(
  WidgetTester tester,
  Finder finder,
  int count, {
  Duration timeout = const Duration(seconds: 60),
  String? what,
}) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().length >= count) return;
  }
  throw TestFailure(
    'timed out after ${timeout.inSeconds}s waiting for $count x '
    '${what ?? finder} (found ${finder.evaluate().length})',
  );
}

void _go(WidgetTester tester, String path) =>
    GoRouter.of(tester.element(find.byType(Navigator).first)).go(path);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('phase 1.5 chat: mock copilot scenarios and the seeded chat', (
    tester,
  ) async {
    final report = _Report(binding)..publish();
    final semantics = tester.ensureSemantics();

    if (_signIn == 'cookie') {
      expect(_cookie, isNotEmpty, reason: 'pass --dart-define=SIM_E2E_COOKIE');
      setDocumentCookie(_cookie);
    }
    tester.testTextInput.register();

    final testOnError = FlutterError.onError;
    await app.main();
    final appOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      appOnError?.call(details);
      testOnError?.call(details);
    };

    if (_signIn == 'ui') {
      await report.check('sign in through the form', () async {
        expect(_password, isNotEmpty, reason: 'pass SIM_E2E_PASSWORD');
        await _waitFor(tester, _id('auth.login.email.field'));
        final fields = find.byType(EditableText);
        await _waitFor(tester, fields);
        await tester.enterText(fields.at(0), _email);
        await tester.enterText(fields.at(1), _password);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      });
    }

    await report.check('lands on the workspace home', () async {
      await _waitForPath(
        tester,
        (path) => path.endsWith('/workspace/$_workspaceId/home'),
        timeout: const Duration(seconds: 60),
      );
      await _waitFor(tester, _id('home.page'), what: 'home.page');
      await _waitFor(tester, _id('chat-input.root'), what: 'chat-input.root');
    });

    await report.check(
      'plain answer: table and code block stream in',
      () async {
        await _send(tester, '#scenario:plain speed=fast');
        await _waitFor(tester, _id('chat.message.user'), what: 'the user row');
        await _waitFor(tester, _id('chat.table'), what: 'chat.table');
        await _waitFor(tester, _id('chat.code'), what: 'chat.code');
        await _waitFor(
          tester,
          _id('chat.message.actions'),
          what: 'the settled actions row',
        );
      },
    );

    var chatPath = '';
    await report.check('the URL becomes /chat/<id>', () async {
      await _waitForPath(
        tester,
        (path) => path.contains('/workspace/$_workspaceId/chat/'),
      );
      chatPath = currentPath() ?? '';
      report.notes['chatPath'] = chatPath;
    });

    await report.check('tool scenario: tool row, then the answer', () async {
      await _send(tester, '#scenario:tool speed=fast');
      await _waitForCount(tester, _id('chat.message.user'), 2);
      await _waitFor(tester, _id('chat.tool.call'), what: 'chat.tool.call');
      await _waitForCount(
        tester,
        _id('chat.message.actions'),
        2,
        what: 'the second settled actions row',
      );
      expect(currentPath(), chatPath, reason: 'same chat');
    });

    await report.check('long scenario: Stop shows the stopped row', () async {
      _go(tester, '/workspace/$_workspaceId/home');
      await _waitForPath(
        tester,
        (path) => path.endsWith('/workspace/$_workspaceId/home'),
      );
      await _waitFor(tester, _id('chat.message.user'), absent: true);
      await _send(tester, '#scenario:long speed=fast');
      await _waitFor(tester, _id('chat.markdown'), what: 'streamed text');
      await tester.tap(_id('chat-input.send'));
      await _waitFor(
        tester,
        _id('chat.message.stopped'),
        what: 'chat.message.stopped',
      );
      expect(_text('Stopped by user'), findsWidgets);
    });

    await report.check('the seeded chat route shows its history', () async {
      _go(tester, '/workspace/$_workspaceId/chat/$_seededChatId');
      await _waitFor(
        tester,
        _text('Summarise the seeded workspace for me.'),
        what: 'the seeded user message',
      );
      await _waitFor(tester, _id('chat.table'), what: 'the seeded table');
      await _waitFor(tester, _id('chat.code'), what: 'the seeded code block');
      expect(_id('chat.message.actions'), findsWidgets);
    });

    semantics.dispose();
  });
}
