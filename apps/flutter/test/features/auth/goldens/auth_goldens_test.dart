// Failure modes (what a golden diff must catch):
// - the shell: header height, logo position, column width and centring
// - per page: section order, 24px rhythm, field/button heights, divider,
//   social grid, prompt chip, legal line; the SSO page's own type scale and
//   bottom legal line; the invite card's action block; the status pages'
//   410px card
// Goldens render with the test font (no real faces), so they capture
// structure and tokens, not glyphs (the CI-golden stance of the test plan).
// Vertical centring is asserted explicitly: the shell column's centre must
// sit at header + max(viewport - header - 64, column height) / 2 (a column
// taller than the free area starts right under the header and the page
// scrolls, as `min-h-screen` + `flex-1 items-center` behave), so a
// top-aligned column fails before the golden is compared.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/invite/invite_page.dart';
import 'package:sim_app/features/auth/login/login_page.dart';
import 'package:sim_app/features/auth/oauth/consent_page.dart';
import 'package:sim_app/features/auth/oauth/status_pages.dart';
import 'package:sim_app/features/auth/reset_password/reset_password_page.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/shared/brand_icons.dart';
import 'package:sim_app/features/auth/signup/signup_page.dart';
import 'package:sim_app/features/auth/sso/sso_page.dart';
import 'package:sim_app/features/auth/verify/verify_page.dart';

import '../support/fakes.dart';
import '../support/invite_fixtures.dart';
import '../support/pump.dart';

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

  /// The centre the spec gives for the shell column at 1440x900
  /// (`auth-login.md` Shell): 62 + (900 - 62 - 64) / 2 while the column fits
  /// the free area; a taller column fills a taller area.
  void expectCentred(WidgetTester tester, String rootId) {
    final rect = tester.getRect(byParityId(rootId));
    const header = 62.0;
    const free = 900 - header - 64;
    final area = rect.height > free ? rect.height : free;
    expect(rect.center.dy, closeTo(header + area / 2, 1));
    expect(rect.center.dx, closeTo(720, 1));
    expect(rect.width, 400);
  }

  Future<void> golden(
    WidgetTester tester,
    Widget page,
    String name, {
    String? centredRoot,
  }) async {
    await pumpAuthPage(tester, page, deps: deps);
    // Brand PNG and SVG icons decode off the fake clock.
    await tester.runAsync(() async {
      await precacheImage(
        MemoryImage(googleIconPng),
        tester.element(find.byType(MaterialApp)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    if (centredRoot != null) expectCentred(tester, centredRoot);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('ci/$name.png'),
    );
  }

  testWidgets('login', (tester) async {
    await golden(
      tester,
      const LoginPage(query: {}),
      'auth_login',
      centredRoot: 'auth.login.root',
    );
  });

  testWidgets('signup', (tester) async {
    await golden(
      tester,
      const SignupPage(query: {}),
      'auth_signup',
      centredRoot: 'auth.signup.root',
    );
  });

  testWidgets('verify', (tester) async {
    deps.sessionStore.write(
      AuthStorageKeys.verificationEmail,
      'ada@example.com',
    );
    await golden(
      tester,
      const VerifyPage(query: {}),
      'auth_verify',
      centredRoot: 'auth.verify.root',
    );
  });

  testWidgets('reset password', (tester) async {
    await golden(
      tester,
      const ResetPasswordPage(query: {'token': 'tok'}),
      'auth_reset_password',
      centredRoot: 'auth.reset.root',
    );
  });

  testWidgets('sso', (tester) async {
    await golden(
      tester,
      const SsoPage(query: {}),
      'auth_sso',
      centredRoot: 'auth.sso.root',
    );
  });

  testWidgets('oauth consent', (tester) async {
    deps.api.session = testSession();
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
    await golden(
      tester,
      OAuthConsentPage(
        uri: Uri.parse(
          '/oauth/consent?client_id=app-1&scope=api:write%20offline_access&redirect_uri=http://127.0.0.1:9/cb&sig=s&exp=$exp',
        ),
      ),
      'oauth_consent',
      centredRoot: 'oauth.consent',
    );
  });

  testWidgets('oauth error', (tester) async {
    await golden(
      tester,
      const OAuthErrorPage(query: {'error': 'access_denied'}),
      'oauth_error',
    );
  });

  testWidgets('credential connected', (tester) async {
    await golden(
      tester,
      const CredentialConnectedPage(query: {'result': 'connected'}),
      'oauth_credential_connected',
    );
  });

  testWidgets('invite', (tester) async {
    deps.api
      ..session = testSession()
      ..inviteResponse = InviteResponse(
        invitation: invitation(kind: 'organization', org: 'Acme'),
        joinPreview: preview,
      );
    await golden(
      tester,
      const InvitePage(inviteId: 'inv-1', query: {'token': 'tok'}),
      'invite_accept',
    );
  });
}
