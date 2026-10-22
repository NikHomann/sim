// Failure modes (what the parity capture cannot measure when this breaks):
// - a `Semantics(identifier:)` without `container: true` merges into its
//   parent, so the id never reaches the semantics DOM and every row of
//   `auth-login.md`'s parity list reads "id-missing"
// - an identified node that exists but has an empty rect (zero-size wrapper,
//   offstage child) measures as a 0x0 box
// - the logo link's tap target stretches across the header row instead of
//   hugging the 37px wordmark (`auth.shell.logo` 1344px wide at 1440)
// - conditional ids (reset success, policy error, SSO-only, forgot modal,
//   loading skeleton) lose their node only in the state that shows them
import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/login/login_page.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

/// Every parity id `auth-login.md` lists for the default page with all
/// alternate sign-in methods enabled and `?resetSuccess=true`.
const List<String> _pageIds = <String>[
  'auth.shell',
  'auth.shell.header',
  'auth.shell.logo',
  'auth.shell.column',
  'auth.login.root',
  'auth.login.header',
  'auth.login.title',
  'auth.login.description',
  'auth.login.form',
  'auth.login.fields',
  'auth.login.email.field',
  'auth.login.email.label',
  'auth.login.email',
  'auth.login.password.field',
  'auth.login.password',
  'auth.login.password.toggle',
  'auth.login.forgot',
  'auth.login.resetSuccess',
  'auth.login.submit',
  'auth.login.divider',
  'auth.login.social',
  'auth.login.social.google',
  'auth.login.social.microsoft',
  'auth.login.social.github',
  'auth.login.sso',
  'auth.login.signupPrompt',
  'auth.login.signupLink',
  'auth.login.legal',
  'auth.login.legal.terms',
  'auth.login.legal.privacy',
];

const List<String> _forgotModalIds = <String>[
  'auth.login.forgotModal',
  'auth.login.forgotModal.header',
  'auth.login.forgotModal.email',
  'auth.login.forgotModal.error',
  'auth.login.forgotModal.footer',
  'auth.login.forgotModal.cancel',
  'auth.login.forgotModal.submit',
];

void main() {
  late FakeAuthDeps deps;

  setUp(() {
    deps = FakeAuthDeps()
      ..api.options = const AuthPageOptions(
        googleAvailable: true,
        microsoftAvailable: true,
        githubAvailable: true,
        ssoEnabled: true,
      );
  });

  /// The semantics node that owns [id], asserting there is exactly one and
  /// that it has an area.
  SemanticsNode node(WidgetTester tester, String id) {
    final finder = find.bySemanticsIdentifier(id);
    expect(finder, findsOneWidget, reason: '$id is not its own node');
    final semantics = tester.getSemantics(finder);
    expect(
      semantics.rect.isEmpty,
      isFalse,
      reason: '$id has an empty rect ${semantics.rect}',
    );
    return semantics;
  }

  void expectIds(WidgetTester tester, List<String> ids) {
    for (final id in ids) {
      node(tester, id);
    }
  }

  Future<void> pumpLogin(
    WidgetTester tester, {
    Map<String, String> query = const {},
  }) async {
    await pumpAuthPage(tester, LoginPage(query: query), deps: deps);
    await tester.pumpAndSettle();
  }

  testWidgets('every page id is its own semantics node with an area', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpLogin(tester, query: const {'resetSuccess': 'true'});
    expectIds(tester, _pageIds);
    handle.dispose();
  });

  testWidgets('the logo node hugs the wordmark', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLogin(tester);
    final rect = tester.getRect(find.bySemanticsIdentifier('auth.shell.logo'));
    expect(rect.left, 48);
    expect(rect.top, 16);
    expect(rect.width, closeTo(37, 1));
    expect(rect.height, 30);
    handle.dispose();
  });

  testWidgets('policy error id after a 403', (tester) async {
    final handle = tester.ensureSemantics();
    deps.api.signInError = apiError(
      403,
      message: 'Account suspended.',
      body: {'message': 'Account suspended.'},
    );
    await pumpLogin(tester);
    await tester.enterText(byParityId('auth.login.email'), 'ada@example.com');
    await tester.enterText(byParityId('auth.login.password'), 'secret');
    await tester.pump();
    await tester.tap(byParityId('auth.login.submit'));
    await tester.pumpAndSettle();
    node(tester, 'auth.login.policyError');
    handle.dispose();
  });

  testWidgets('SSO-only top chip id', (tester) async {
    final handle = tester.ensureSemantics();
    deps.api.options = const AuthPageOptions(
      emailEnabled: false,
      ssoEnabled: true,
    );
    await pumpLogin(tester);
    node(tester, 'auth.login.ssoTop');
    handle.dispose();
  });

  testWidgets('forgot modal ids, error included', (tester) async {
    final handle = tester.ensureSemantics();
    deps.api.forgetPasswordError = apiError(
      500,
      message: 'Failed to send password reset email. Please try again later.',
    );
    await pumpLogin(tester);
    await tester.tap(byParityId('auth.login.forgot'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: byParityId('auth.login.forgotModal.email'),
        matching: find.byType(EditableText),
      ),
      'ada@example.com',
    );
    await tester.pump();
    await tester.tap(byParityId('auth.login.forgotModal.submit'));
    await tester.pumpAndSettle();
    expectIds(tester, _forgotModalIds);
    handle.dispose();
  });

  testWidgets('loading skeleton id', (tester) async {
    final handle = tester.ensureSemantics();
    deps.api.gate = Completer<void>();
    await pumpAuthPage(tester, const LoginPage(query: {}), deps: deps);
    await tester.pump();
    node(tester, 'auth.login.loading');
    deps.api.gate!.complete();
    await tester.pumpAndSettle();
    handle.dispose();
  });
}
