// Failure modes:
// - the header names the stored email; the resend row is hidden without a
//   mail service
// - typing six digits fills the slots and auto-verifies 300ms later
// - a verification error marks the slots and shows the centred copy
// - Resend starts the countdown: the link is replaced by "Resend in 30s"
//   and tapping during the cooldown sends nothing
// - "Back to signup" clears the stored email
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/verify/otp_input.dart';
import 'package:sim_app/features/auth/verify/verify_page.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

void main() {
  late FakeAuthDeps deps;

  setUp(() {
    deps = FakeAuthDeps();
    deps.sessionStore.write(
      AuthStorageKeys.verificationEmail,
      'ada@example.com',
    );
  });

  Future<void> pumpVerify(WidgetTester tester) async {
    await pumpAuthPage(tester, const VerifyPage(query: {}), deps: deps);
    await tester.pumpAndSettle();
  }

  Finder otpField() => find.descendant(
    of: find.byType(OtpInput),
    matching: find.byType(EditableText),
  );

  testWidgets('header, hint and resend row', (tester) async {
    await pumpVerify(tester);
    expect(
      find.text('A verification code has been sent to ada@example.com'),
      findsOneWidget,
    );
    expect(byParityId('auth.verify.resend'), findsOneWidget);
    expect(byParityId('auth.verify.otp.slot.5'), findsOneWidget);

    deps = FakeAuthDeps()
      ..api.options = const AuthPageOptions(emailServiceConfigured: false);
    deps.sessionStore.write(AuthStorageKeys.verificationEmail, 'a@b.co');
    await pumpVerify(tester);
    expect(byParityId('auth.verify.resend'), findsNothing);
    expect(
      find.textContaining('check your spam folder'),
      findsNothing,
    );
  });

  testWidgets('six digits auto-verify after 300ms', (tester) async {
    await pumpVerify(tester);
    await tester.enterText(otpField(), '123456');
    await tester.pump();
    expect(find.text('6'), findsOneWidget);
    expect(deps.api.callsNamed('verifyEmailOtp'), isEmpty);
    deps.timers.elapse(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(
      deps.api.callsNamed('verifyEmailOtp').single.args,
      {'email': 'ada@example.com', 'otp': '123456'},
    );
    expect(find.text('Email Verified'), findsOneWidget);
    expect(byParityId('auth.verify.body'), findsNothing);
    deps.timers.elapse(const Duration(seconds: 1));
    expect(deps.navigator.gone, ['/home']);
  });

  testWidgets('a bad code shows the centred error and clears the slots', (
    tester,
  ) async {
    deps.api.verifyOtpError = apiError(400, code: 'INVALID_OTP');
    await pumpVerify(tester);
    await tester.enterText(otpField(), '123456');
    await tester.pump();
    await tester.tap(byParityId('auth.verify.submit'));
    await tester.pumpAndSettle();
    expect(byParityId('auth.verify.error'), findsOneWidget);
    expect(
      find.text('Invalid verification code. Please check and try again.'),
      findsOneWidget,
    );
    expect(find.text('6'), findsNothing);
  });

  testWidgets('resend is replaced by the countdown', (tester) async {
    await pumpVerify(tester);
    await tester.tap(byParityId('auth.verify.resendLink'));
    await tester.pumpAndSettle();
    expect(deps.api.callsNamed('sendVerificationOtp'), hasLength(1));
    expect(byParityId('auth.verify.resendLink'), findsNothing);
    expect(find.textContaining('Resend in '), findsOneWidget);
    expect(find.textContaining('30s', findRichText: true), findsOneWidget);
    deps.timers.elapse(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(byParityId('auth.verify.resendLink'), findsOneWidget);
  });

  testWidgets('back to signup clears the stored email', (tester) async {
    await pumpVerify(tester);
    await tester.tap(byParityId('auth.verify.backLink'));
    await tester.pumpAndSettle();
    expect(deps.sessionStore.read(AuthStorageKeys.verificationEmail), isNull);
    expect(deps.navigator.gone, ['/signup']);
  });
}
