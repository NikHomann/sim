// Failure modes:
// - the email comes from the session, else sessionStorage; with neither,
//   verify and resend are no-ops
// - reaching 6 digits clears an error state and auto-verifies 300ms later,
//   but not while verifying, verified or resending; retyping cancels the
//   pending auto-verify
// - an API error shows the invalid-code copy (or the SSO_REQUIRED message)
//   and clears the OTP; a thrown error maps expired / invalid / attempts
// - success swaps the header, refetches the session, consumes the stored
//   keys and navigates after 1000ms to the resolved destination; a late
//   auto-verify or a second click after success verifies nothing again
// - destination: stored value evicted when unsafe; `?redirectAfter` wins
//   when valid, is ignored when not
// - resend starts the 30s countdown regardless of outcome; a failure sets
//   the message while status stays idle; resend is refused during cooldown
// - verification disabled: the verified header copy (the source sets
//   `verified` in the same effect, so the "disabled" sentence never paints),
//   immediate navigation after a session refetch, stored destination consumed
// - back to signup clears both keys
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/verify/verify_cubit.dart';

import '../support/fakes.dart';

void main() {
  late FakeAuthApi api;
  late FakeAuthNavigator navigator;
  late MemoryAuthSessionStore store;
  late FakeAuthTimers timers;

  setUp(() {
    api = FakeAuthApi();
    navigator = FakeAuthNavigator();
    store = MemoryAuthSessionStore();
    timers = FakeAuthTimers();
  });

  Future<VerifyCubit> ready([Map<String, String> query = const {}]) async {
    final cubit = VerifyCubit(
      api: api,
      navigator: navigator,
      sessionStore: store,
      timers: timers,
      origin: testOrigin,
      query: query,
    );
    await cubit.load();
    return cubit;
  }

  test(
    'email from the session, else storage; unknown email is a no-op',
    () async {
      api.session = testSession(email: 'session@example.com');
      store.write(AuthStorageKeys.verificationEmail, 'stored@example.com');
      var cubit = await ready();
      expect(cubit.state.email, 'session@example.com');
      expect(
        cubit.state.description,
        'A verification code has been sent to session@example.com',
      );
      api.session = null;
      cubit = await ready();
      expect(cubit.state.email, 'stored@example.com');
      store.remove(AuthStorageKeys.verificationEmail);
      cubit = await ready();
      expect(cubit.state.email, isNull);
      expect(
        cubit.state.description,
        'A verification code has been sent to your email',
      );
      cubit.otpChanged('123456');
      await cubit.verifyCode();
      timers.elapse(const Duration(seconds: 1));
      expect(api.callsNamed('verifyEmailOtp'), isEmpty);
    },
  );

  test('six digits auto-verify after 300ms; retyping cancels', () async {
    store.write(AuthStorageKeys.verificationEmail, 'Ada@Example.com');
    final cubit = (await ready())..otpChanged('123456');
    expect(cubit.state.isOtpComplete, isTrue);
    timers.elapse(const Duration(milliseconds: 299));
    expect(api.callsNamed('verifyEmailOtp'), isEmpty);
    cubit.otpChanged('12345');
    timers.elapse(const Duration(milliseconds: 300));
    expect(api.callsNamed('verifyEmailOtp'), isEmpty);
    cubit.otpChanged('123456');
    timers.elapse(const Duration(milliseconds: 300));
    await Future<void>.delayed(Duration.zero);
    expect(api.callsNamed('verifyEmailOtp').single.args, {
      'email': 'ada@example.com',
      'otp': '123456',
    });
  });

  test('API error shows the invalid copy and clears the OTP', () async {
    store.write(AuthStorageKeys.verificationEmail, 'ada@example.com');
    api.verifyOtpError = apiError(
      400,
      code: 'INVALID_OTP',
      message: 'Invalid OTP',
    );
    final cubit = (await ready())..otpChanged('123456');
    await cubit.verifyCode();
    expect(cubit.state.status, VerifyStatus.error);
    expect(
      cubit.state.errorMessage,
      'Invalid verification code. Please check and try again.',
    );
    expect(cubit.state.otp, '');
    cubit.otpChanged('654321');
    expect(cubit.state.status, VerifyStatus.idle);
    expect(cubit.state.errorMessage, '');
  });

  test(
    'SSO_REQUIRED keeps the server message; thrown errors map by text',
    () async {
      store.write(AuthStorageKeys.verificationEmail, 'ada@example.com');
      api.verifyOtpError = apiError(
        403,
        code: 'SSO_REQUIRED',
        message: 'Use SSO.',
      );
      var cubit = (await ready())..otpChanged('123456');
      await cubit.verifyCode();
      expect(cubit.state.errorMessage, 'Use SSO.');
      for (final (text, message) in [
        (
          'code expired',
          'The verification code has expired. Please request a new one.',
        ),
        (
          'invalid thing',
          'Invalid verification code. Please check and try again.',
        ),
        (
          'too many attempts',
          'Too many failed attempts. Please request a new code.',
        ),
        ('boom', 'Verification failed. Please check your code and try again.'),
      ]) {
        api.verifyOtpError = ApiNetworkError(text);
        cubit = (await ready())..otpChanged('123456');
        await cubit.verifyCode();
        expect(cubit.state.errorMessage, message);
      }
    },
  );

  test('success swaps the header and navigates after 1000ms', () async {
    store
      ..write(AuthStorageKeys.verificationEmail, 'ada@example.com')
      ..write(AuthStorageKeys.postAuthRedirectUrl, '/invite/abc');
    final cubit = (await ready())..otpChanged('123456');
    await cubit.verifyCode();
    expect(cubit.state.isVerified, isTrue);
    expect(cubit.state.title, 'Email Verified');
    expect(api.callsNamed('getSession'), hasLength(2));
    expect(store.read(AuthStorageKeys.verificationEmail), isNull);
    expect(store.read(AuthStorageKeys.postAuthRedirectUrl), isNull);
    timers.elapse(const Duration(milliseconds: 999));
    expect(navigator.gone, isEmpty);
    timers.elapse(const Duration(milliseconds: 1));
    expect(navigator.gone, ['/invite/abc']);
    await cubit.verifyCode();
    timers.elapse(const Duration(seconds: 2));
    expect(api.callsNamed('verifyEmailOtp'), hasLength(1));
    expect(navigator.gone, ['/invite/abc']);
  });

  test(
    'destination: unsafe stored value evicted; redirectAfter wins',
    () async {
      store
        ..write(AuthStorageKeys.verificationEmail, 'ada@example.com')
        ..write(AuthStorageKeys.postAuthRedirectUrl, 'https://evil.com');
      var cubit = (await ready())..otpChanged('123456');
      await cubit.verifyCode();
      timers.elapse(const Duration(seconds: 1));
      expect(navigator.gone, ['/home']);
      store
        ..write(AuthStorageKeys.verificationEmail, 'ada@example.com')
        ..write(AuthStorageKeys.postAuthRedirectUrl, '/workspace/stored');
      cubit = (await ready({'redirectAfter': '/cli/auth?x=1'}))
        ..otpChanged('123456');
      await cubit.verifyCode();
      timers.elapse(const Duration(seconds: 1));
      expect(navigator.topLevel, ['/cli/auth?x=1']);
      store
        ..write(AuthStorageKeys.verificationEmail, 'ada@example.com')
        ..write(AuthStorageKeys.postAuthRedirectUrl, '/workspace/stored');
      cubit = (await ready({'redirectAfter': 'https://evil.com'}))
        ..otpChanged('123456');
      await cubit.verifyCode();
      timers.elapse(const Duration(seconds: 1));
      expect(navigator.gone.last, '/workspace/stored');
    },
  );

  test('resend counts down from 30 and refuses during cooldown', () async {
    store.write(AuthStorageKeys.verificationEmail, 'ada@example.com');
    final cubit = await ready();
    await cubit.resend();
    expect(api.callsNamed('sendVerificationOtp').single.args, {
      'email': 'ada@example.com',
    });
    expect(cubit.state.countdown, 30);
    timers.elapse(const Duration(seconds: 1));
    expect(cubit.state.countdown, 29);
    await cubit.resend();
    expect(api.callsNamed('sendVerificationOtp'), hasLength(1));
    timers.elapse(const Duration(seconds: 29));
    expect(cubit.state.countdown, 0);
    expect(timers.pendingCount, 0);
    await cubit.resend();
    expect(api.callsNamed('sendVerificationOtp'), hasLength(2));
  });

  test(
    'resend failure sets the message, status stays idle, countdown runs',
    () async {
      store.write(AuthStorageKeys.verificationEmail, 'ada@example.com');
      api.resendError = apiError(429);
      final cubit = await ready();
      await cubit.resend();
      expect(
        cubit.state.errorMessage,
        'Failed to resend verification code. Please try again later.',
      );
      expect(cubit.state.status, VerifyStatus.idle);
      expect(cubit.state.isResending, isFalse);
      expect(cubit.state.countdown, 30);
    },
  );

  test('no auto-verify while resending', () async {
    store.write(AuthStorageKeys.verificationEmail, 'ada@example.com');
    final cubit = await ready();
    final resend = cubit.resend();
    cubit.otpChanged('123456');
    timers.elapse(const Duration(milliseconds: 300));
    await resend;
    expect(api.callsNamed('verifyEmailOtp'), isEmpty);
  });

  test(
    'verification disabled: copy, consumed destination, immediate leave',
    () async {
      api.options = const AuthPageOptions(emailVerificationEnabled: false);
      store.write(AuthStorageKeys.postAuthRedirectUrl, '/invite/abc');
      final cubit = await ready();
      expect(cubit.state.isVerified, isTrue);
      expect(cubit.state.title, 'Email Verified');
      expect(
        cubit.state.description,
        'Your email has been verified. Redirecting to dashboard...',
      );
      expect(store.read(AuthStorageKeys.postAuthRedirectUrl), isNull);
      expect(api.callsNamed('getSession'), hasLength(2));
      expect(navigator.gone, ['/invite/abc']);
    },
  );

  test('no mail service copy and resend hidden flag', () async {
    api.options = const AuthPageOptions(emailServiceConfigured: false);
    var cubit = await ready();
    expect(cubit.state.hasEmailService, isFalse);
    expect(
      cubit.state.description,
      'Development mode: Check your console logs for the verification code',
    );
    api.options = const AuthPageOptions(
      emailServiceConfigured: false,
      isProduction: true,
    );
    cubit = await ready();
    expect(
      cubit.state.description,
      'Error: Email verification is enabled but no email service is configured',
    );
  });

  test('back to signup clears both keys', () async {
    store
      ..write(AuthStorageKeys.verificationEmail, 'ada@example.com')
      ..write(AuthStorageKeys.postAuthRedirectUrl, '/x');
    final cubit = await ready();
    cubit.backToSignup();
    expect(store.values, isEmpty);
    expect(navigator.gone, ['/signup']);
  });
}
