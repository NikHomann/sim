// Failure modes:
// - registrationDisabled replaces the page with the disabled header and the
//   sign-in chip carrying the callback
// - Enter in any field submits; validation copy lists every failing rule
// - the server's USER_ALREADY_EXISTS line renders under the email and the
//   border is marked
// - `?email=` pre-fills the field
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/signup/signup_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

void main() {
  late FakeAuthDeps deps;

  setUp(() => deps = FakeAuthDeps());

  Future<void> pumpSignup(
    WidgetTester tester, {
    Map<String, String> query = const {},
  }) async {
    await pumpAuthPage(tester, SignupPage(query: query), deps: deps);
    await tester.pumpAndSettle();
  }

  testWidgets('registration disabled page', (tester) async {
    deps.api.options = const AuthPageOptions(registrationDisabled: true);
    await pumpSignup(tester, query: const {'callbackUrl': '/invite/x'});
    expect(byParityId('auth.signup.disabled'), findsOneWidget);
    expect(find.text('Account creation is disabled'), findsOneWidget);
    expect(byParityId('auth.signup.form'), findsNothing);
    await tester.tap(byParityId('auth.signup.disabled.loginLink'));
    expect(deps.navigator.gone, [
      '/login?invite_flow=true&callbackUrl=%2Finvite%2Fx',
    ]);
  });

  testWidgets('Enter submits and validation copy lists every rule', (
    tester,
  ) async {
    await pumpSignup(tester, query: const {'email': 'ada@example.com'});
    expect(find.text('ada@example.com'), findsOneWidget);
    await tester.enterText(byParityId('auth.signup.name'), 'Ada  9');
    await tester.enterText(byParityId('auth.signup.password'), 'short');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(deps.api.callsNamed('signUpEmail'), isEmpty);
    expect(
      find.text('Name cannot contain consecutive spaces.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Name can only contain letters, spaces, hyphens, and apostrophes.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Password must be at least 8 characters long.'),
      findsOneWidget,
    );
    expect(
      find.text('Password must include at least one special character.'),
      findsOneWidget,
    );
  });

  testWidgets('server email line renders and submit succeeds afterwards', (
    tester,
  ) async {
    deps.api.signUpError = apiError(422, code: 'USER_ALREADY_EXISTS');
    await pumpSignup(tester);
    await tester.enterText(byParityId('auth.signup.name'), 'Ada');
    await tester.enterText(byParityId('auth.signup.email'), 'ada@example.com');
    await tester.enterText(byParityId('auth.signup.password'), 'Secret1!');
    await tester.pump();
    await tester.tap(byParityId('auth.signup.submit'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'An account with this email already exists. Please sign in instead.',
      ),
      findsOneWidget,
    );
    deps.api.signUpError = null;
    await tester.tap(byParityId('auth.signup.submit'));
    await tester.pumpAndSettle();
    expect(deps.navigator.gone, ['/verify?fromSignup=true']);
  });
}
