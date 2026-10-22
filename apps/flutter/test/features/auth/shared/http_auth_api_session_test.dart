// Failure modes (live e2e regression, 2026-10-22):
// - a successful sign-in returns before the app-level session is refreshed,
//   so the router's signed-out guard still sees the session cached while the
//   login page was open and bounces the visitor back to /login
// - sign-up, OTP verification and sign-out likewise leave the app session
//   stale
// - a failed sign-in still triggers a session refresh (it must not: the
//   cookie did not change and the error must surface unchanged)
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockHttp extends Mock implements SimHttpClient {}

void main() {
  late _MockAuthRepository auth;
  late _MockHttp http;
  late List<String> calls;
  late HttpAuthApi api;

  setUp(() {
    auth = _MockAuthRepository();
    http = _MockHttp();
    calls = <String>[];
    api = HttpAuthApi(
      auth: auth,
      http: http,
      onSessionChanged: () async => calls.add('refresh'),
    );
  });

  test('sign-in refreshes the app session before returning', () async {
    when(
      () => auth.signInEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
        callbackUrl: any(named: 'callbackUrl'),
      ),
    ).thenAnswer((_) async {
      calls.add('sign-in');
      return null;
    });

    await api.signInEmail(email: 'a@b.c', password: 'x', callbackUrl: '/home');
    calls.add('navigate');

    expect(calls, ['sign-in', 'refresh', 'navigate']);
  });

  test('OTP verification and sign-out refresh the app session', () async {
    when(
      () => auth.verifyEmailOtp(
        email: any(named: 'email'),
        otp: any(named: 'otp'),
      ),
    ).thenAnswer((_) async => null);
    when(() => auth.signOut()).thenAnswer((_) async {});

    await api.verifyEmailOtp(email: 'a@b.c', otp: '123456');
    await api.signOut();

    expect(calls, ['refresh', 'refresh']);
  });

  test('a failed sign-in does not refresh and rethrows', () async {
    final error = ApiClientError(status: 401, message: 'Invalid');
    when(
      () => auth.signInEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
        callbackUrl: any(named: 'callbackUrl'),
      ),
    ).thenThrow(error);

    await expectLater(
      api.signInEmail(email: 'a@b.c', password: 'x', callbackUrl: '/home'),
      throwsA(same(error)),
    );
    expect(calls, isEmpty);
  });
}
