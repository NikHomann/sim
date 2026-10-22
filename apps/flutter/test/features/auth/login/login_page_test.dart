// Failure modes:
// - the skeleton shows until options and session resolve
// - social chips appear only for available providers, in Google /
//   Microsoft / GitHub order; the SSO chip only when SSO is enabled
// - the sign-up prompt disappears under registrationDisabled; the form
//   disappears when email sign-in is disabled (no divider without email)
// - Enter in the password field submits with the typed values
// - the server's credential copy renders under the password field and the
//   policy copy in the form slot
// - EMAIL_NOT_VERIFIED navigates to /verify without rendering copy
// - "Forgot password?" opens the modal; Escape closes it and the cubit
//   agrees
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/login/login_cubit.dart';
import 'package:sim_app/features/auth/login/login_page.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

void main() {
  late FakeAuthDeps deps;

  setUp(() => deps = FakeAuthDeps());

  Future<void> pumpLogin(
    WidgetTester tester, {
    Map<String, String> query = const {},
  }) async {
    await pumpAuthPage(tester, LoginPage(query: query), deps: deps);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(byParityId('auth.login.email'), 'ada@example.com');
    await tester.enterText(byParityId('auth.login.password'), 'secret');
    await tester.pump();
  }

  testWidgets('skeleton until loaded, then the full column', (tester) async {
    deps.api.options = const AuthPageOptions(
      googleAvailable: true,
      githubAvailable: true,
      ssoEnabled: true,
    );
    deps.api.gate = Completer<void>();
    await pumpAuthPage(tester, const LoginPage(query: {}), deps: deps);
    await tester.pump();
    expect(byParityId('auth.login.loading'), findsOneWidget);
    deps.api.gate!.complete();
    await tester.pumpAndSettle();
    expect(byParityId('auth.login.loading'), findsNothing);
    expect(byParityId('auth.login.social.google'), findsOneWidget);
    expect(byParityId('auth.login.social.microsoft'), findsNothing);
    expect(byParityId('auth.login.social.github'), findsOneWidget);
    expect(byParityId('auth.login.sso'), findsOneWidget);
    expect(byParityId('auth.login.divider'), findsOneWidget);
    expect(byParityId('auth.login.signupPrompt'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('visibility matrix', (tester) async {
    deps.api.options = const AuthPageOptions(registrationDisabled: true);
    await pumpLogin(tester);
    expect(byParityId('auth.login.signupPrompt'), findsNothing);
    expect(byParityId('auth.login.social'), findsNothing);
    expect(byParityId('auth.login.divider'), findsNothing);
    expect(byParityId('auth.login.form'), findsOneWidget);

    deps = FakeAuthDeps()
      ..api.options = const AuthPageOptions(
        emailEnabled: false,
        microsoftAvailable: true,
      );
    await pumpLogin(tester);
    expect(byParityId('auth.login.form'), findsNothing);
    expect(byParityId('auth.login.divider'), findsNothing);
    expect(byParityId('auth.login.social.microsoft'), findsOneWidget);

    deps = FakeAuthDeps()
      ..api.options = const AuthPageOptions(
        emailEnabled: false,
        ssoEnabled: true,
      );
    await pumpLogin(tester);
    expect(byParityId('auth.login.ssoTop'), findsOneWidget);
    expect(byParityId('auth.login.social'), findsNothing);
  });

  testWidgets('Enter in the password field submits', (tester) async {
    await pumpLogin(tester, query: const {'callbackUrl': '/invite/abc'});
    await fill(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(deps.api.callsNamed('signInEmail').single.args, {
      'email': 'ada@example.com',
      'password': 'secret',
      'callbackUrl': '/invite/abc',
    });
    expect(deps.navigator.gone, ['/invite/abc']);
  });

  testWidgets('credential and policy copy render', (tester) async {
    deps.api.signInError = apiError(401, code: 'USER_NOT_FOUND');
    await pumpLogin(tester);
    await fill(tester);
    await tester.tap(byParityId('auth.login.submit'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(
      find.text('No account found with this email. Please sign up first.'),
      findsOneWidget,
    );
    expect(byParityId('auth.login.password.errors'), findsOneWidget);

    deps.api.signInError = apiError(
      403,
      message: 'Account suspended.',
      body: {'message': 'Account suspended.'},
    );
    await tester.tap(byParityId('auth.login.submit'));
    await tester.pumpAndSettle();
    expect(byParityId('auth.login.policyError'), findsOneWidget);
    expect(find.text('Account suspended.'), findsOneWidget);
    expect(byParityId('auth.login.password.errors'), findsNothing);
  });

  testWidgets('EMAIL_NOT_VERIFIED leaves for /verify silently', (tester) async {
    deps.api.signInError = apiError(
      403,
      code: 'EMAIL_NOT_VERIFIED',
      message: 'x',
    );
    await pumpLogin(tester);
    await fill(tester);
    await tester.tap(byParityId('auth.login.submit'));
    await tester.pumpAndSettle();
    expect(deps.navigator.gone, ['/verify']);
    expect(byParityId('auth.login.policyError'), findsNothing);
    expect(byParityId('auth.login.password.errors'), findsNothing);
  });

  testWidgets('submit is disabled until both fields are filled', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.tap(byParityId('auth.login.submit'));
    await tester.pumpAndSettle();
    expect(deps.api.callsNamed('signInEmail'), isEmpty);
  });

  testWidgets('forgot modal opens on the link and closes on Escape', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.tap(byParityId('auth.login.forgot'));
    await tester.pumpAndSettle();
    expect(byParityId('auth.login.forgotModal'), findsOneWidget);
    expect(find.text('Reset Password'), findsOneWidget);
    expect(deps.api.gate, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(byParityId('auth.login.forgotModal'), findsNothing);
    final cubit = tester
        .state<State<LoginView>>(find.byType(LoginView))
        .context
        .read<LoginCubit>();
    expect(cubit.state.forgot.open, isFalse);
    await tester.tap(byParityId('auth.login.forgot'));
    await tester.pumpAndSettle();
    await tester.tap(byParityId('auth.login.forgotModal.cancel'));
    await tester.pumpAndSettle();
    expect(byParityId('auth.login.forgotModal'), findsNothing);
  });

  testWidgets('forgot modal sends the reset request on Enter', (tester) async {
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
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(deps.api.callsNamed('forgetPassword'), hasLength(1));
    expect(find.text('Password reset link sent to your email'), findsOneWidget);
  });
}
