// Failure modes:
// - `?error=` copy is rendered in the form slot and disappears on typing
// - Enter submits: resolve then sign-in, leaving top-level
// - email disabled hides the divider, the email button and the prompt;
//   registration disabled hides only the prompt
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/sso/sso_cubit.dart';
import 'package:sim_app/features/auth/sso/sso_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

void main() {
  late FakeAuthDeps deps;

  setUp(() {
    deps = FakeAuthDeps()
      ..api.options = const AuthPageOptions(ssoEnabled: true);
  });

  Future<void> pumpSso(
    WidgetTester tester, {
    Map<String, String> query = const {},
  }) async {
    await pumpAuthPage(tester, SsoPage(query: query), deps: deps);
    await tester.pumpAndSettle();
  }

  testWidgets('error copy from the query, cleared on typing; Enter submits', (
    tester,
  ) async {
    await pumpSso(tester, query: const {'error': 'account_not_found'});
    expect(
      find.text(SsoCopy.errorMessages['account_not_found']!),
      findsOneWidget,
    );
    await tester.enterText(byParityId('auth.sso.email'), 'ada@example.com');
    await tester.pump();
    expect(byParityId('auth.sso.formError'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(deps.api.callsNamed('resolveSsoProvider'), hasLength(1));
    expect(deps.api.callsNamed('startSsoSignIn'), hasLength(1));
    expect(deps.navigator.topLevel, [deps.api.ssoUrl]);
  });

  testWidgets('email and registration gating', (tester) async {
    await pumpSso(tester);
    expect(byParityId('auth.sso.divider'), findsOneWidget);
    expect(byParityId('auth.sso.emailLink'), findsOneWidget);
    expect(byParityId('auth.sso.signupPrompt'), findsOneWidget);
    expect(byParityId('auth.sso.legal'), findsOneWidget);

    deps = FakeAuthDeps()
      ..api.options = const AuthPageOptions(
        ssoEnabled: true,
        registrationDisabled: true,
      );
    await pumpSso(tester);
    expect(byParityId('auth.sso.emailLink'), findsOneWidget);
    expect(byParityId('auth.sso.signupPrompt'), findsNothing);

    deps = FakeAuthDeps()
      ..api.options = const AuthPageOptions(
        ssoEnabled: true,
        emailEnabled: false,
      );
    await pumpSso(tester);
    expect(byParityId('auth.sso.divider'), findsNothing);
    expect(byParityId('auth.sso.emailLink'), findsNothing);
    expect(byParityId('auth.sso.signupPrompt'), findsNothing);
  });
}
