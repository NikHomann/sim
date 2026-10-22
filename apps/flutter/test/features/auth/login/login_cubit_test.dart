// Failure modes:
// - an invalid `?callbackUrl` must be replaced by `/home` and dropped from
//   the sign-up link; a valid one is kept and decides the destination
// - a signed-in visitor leaves on load, except for the OAuth authorize
//   callback (re-authentication)
// - option loading failures fall back to the permissive defaults
// - typing validates but hides errors; submit shows them and sends no request
// - `EMAIL_NOT_VERIFIED` stores the email and goes to `/verify` with no copy
// - a 403 with a message is a policy error, the password field stays clean
// - credential errors map to the two-line copy by code/message; an unknown
//   code shows the single line; a network failure shows the single line
// - `?resetSuccess=true` shows the green line until the next submit attempt
// - success navigates to the callback (top-level for the authorize endpoint)
//   or the entry route
// - social: the chip in flight resets even when the request fails
// - a 403 without a body `message` is a credential error, not a policy one
// - forgot modal: empty / invalid email refuse without a request; the server
//   message is mapped; success auto-closes after 2s; Send is disabled while
//   the field is empty or a request is in flight
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/login/login_cubit.dart';
import 'package:sim_app/features/auth/login/login_state.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';

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

  LoginCubit build([Map<String, String> query = const {}]) => LoginCubit(
    api: api,
    navigator: navigator,
    sessionStore: store,
    timers: timers,
    origin: testOrigin,
    query: query,
  );

  Future<LoginCubit> ready([Map<String, String> query = const {}]) async {
    final cubit = build(query);
    await cubit.load();
    return cubit;
  }

  group('query handling', () {
    test(
      'invalid callbackUrl is replaced by /home and dropped from signupHref',
      () {
        final cubit = build({
          'callbackUrl': 'https://evil.com/x',
          'invite_flow': 'true',
        });
        expect(cubit.state.callbackUrl, '/home');
        expect(cubit.state.callbackValid, isFalse);
        expect(cubit.signupHref, '/signup?invite_flow=true');
      },
    );

    test('valid callbackUrl is kept and carried to signup', () {
      final cubit = build({'callbackUrl': '/invite/abc?token=t'});
      expect(cubit.state.callbackUrl, '/invite/abc?token=t');
      expect(
        cubit.signupHref,
        '/signup?callbackUrl=%2Finvite%2Fabc%3Ftoken%3Dt',
      );
    });

    test('resetSuccess shows the green line', () {
      expect(
        build({'resetSuccess': 'true'}).state.resetSuccessMessage,
        'Password reset successful. Please sign in with your new password.',
      );
    });
  });

  group('load', () {
    test('signed-in visitor leaves for entry resolution', () async {
      api.session = testSession();
      final cubit = await ready();
      expect(navigator.gone, ['/home']);
      expect(cubit.state.loading, isTrue);
    });

    test('signed-in visitor stays for the OAuth authorize callback', () async {
      api.session = testSession();
      final cubit = await ready({
        'callbackUrl': '/api/auth/oauth2/authorize?client_id=x',
      });
      expect(navigator.gone, isEmpty);
      expect(cubit.state.loading, isFalse);
    });

    test(
      'option failures fall back to defaults; providers drive visibility',
      () async {
        api.optionsError = apiError(500);
        final cubit = await ready();
        expect(cubit.state.options.emailEnabled, isTrue);
        expect(cubit.state.options.hasSocial, isFalse);
        expect(api.callsNamed('loadOptions'), hasLength(1));
        expect(api.callsNamed('getSession'), hasLength(1));
      },
    );
  });

  group('validation', () {
    blocTest<LoginCubit, LoginState>(
      'typing validates silently; submit surfaces errors without a request',
      build: build,
      act: (cubit) async {
        cubit
          ..emailChanged('nope')
          ..passwordChanged('');
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.visibleEmailErrors, ['Invalid email format']);
        expect(cubit.state.visiblePasswordErrors, ['Password is required.']);
        expect(cubit.state.submitting, isFalse);
        expect(api.callsNamed('signInEmail'), isEmpty);
      },
    );

    test('errors shown after submit clear on the next keystroke', () async {
      final cubit = build()
        ..emailChanged('nope')
        ..passwordChanged('x');
      await cubit.submit();
      expect(cubit.state.visibleEmailErrors, isNotEmpty);
      cubit.emailChanged('nope2');
      expect(cubit.state.visibleEmailErrors, isEmpty);
      expect(cubit.state.emailErrors, isNotEmpty);
    });

    test('canSubmit needs both fields', () {
      final cubit = build()..emailChanged('  ');
      expect(cubit.state.canSubmit, isFalse);
      cubit
        ..emailChanged('a@b.co')
        ..passwordChanged('p');
      expect(cubit.state.canSubmit, isTrue);
    });
  });

  group('submit', () {
    Future<LoginCubit> filled([Map<String, String> query = const {}]) async {
      final cubit = await ready(query);
      cubit
        ..emailChanged(' Ada@Example.com ')
        ..passwordChanged('secret');
      return cubit;
    }

    test(
      'sends the normalised email and the callback, then navigates',
      () async {
        final cubit = await filled();
        await cubit.submit();
        final call = api.callsNamed('signInEmail').single;
        expect(call.args, {
          'email': 'ada@example.com',
          'password': 'secret',
          'callbackUrl': '/home',
        });
        expect(navigator.gone, ['/home']);
        expect(cubit.state.submitting, isFalse);
      },
    );

    test(
      'a valid callback is the destination; authorize goes top-level',
      () async {
        var cubit = await filled({'callbackUrl': '/invite/abc'});
        await cubit.submit();
        expect(navigator.gone, ['/invite/abc']);
        cubit = await filled({
          'callbackUrl': '/api/auth/oauth2/authorize?client_id=x',
        });
        api.session = null;
        await cubit.submit();
        expect(navigator.topLevel, ['/api/auth/oauth2/authorize?client_id=x']);
      },
    );

    test('EMAIL_NOT_VERIFIED stores the email and goes to /verify', () async {
      api.signInError = apiError(403, code: 'EMAIL_NOT_VERIFIED', message: 'x');
      final cubit = await filled();
      await cubit.submit();
      expect(store.read(AuthStorageKeys.verificationEmail), 'ada@example.com');
      expect(navigator.gone, ['/verify']);
      expect(cubit.state.visiblePasswordErrors, isEmpty);
      expect(cubit.state.policyError, isNull);
    });

    test(
      '403 with a message is a policy error; password field unmarked',
      () async {
        api.signInError = apiError(
          403,
          code: 'SSO_REQUIRED',
          message: 'Your organization requires single sign-on.',
          body: {
            'code': 'SSO_REQUIRED',
            'message': 'Your organization requires single sign-on.',
          },
        );
        final cubit = await filled({'resetSuccess': 'true'});
        await cubit.submit();
        expect(
          cubit.state.policyError,
          'Your organization requires single sign-on.',
        );
        expect(cubit.state.visiblePasswordErrors, isEmpty);
        expect(cubit.state.resetSuccessMessage, isNull);
        expect(cubit.state.submitting, isFalse);
      },
    );

    test('403 without a body message is a credential error', () async {
      api.signInError = apiError(
        403,
        message: 'Request failed with 403',
        body: {'error': 'Forbidden'},
      );
      final cubit = await filled();
      await cubit.submit();
      expect(cubit.state.policyError, isNull);
      expect(cubit.state.visiblePasswordErrors, ['Invalid email or password']);
    });

    test('policy error clears on the next submit', () async {
      api.signInError = apiError(
        403,
        message: 'Suspended',
        body: {'message': 'Suspended'},
      );
      final cubit = await filled();
      await cubit.submit();
      api.signInError = null;
      await cubit.submit();
      expect(cubit.state.policyError, isNull);
    });

    test('credential errors render the two-line copy', () async {
      api.signInError = apiError(401, code: 'INVALID_CREDENTIALS');
      final cubit = await filled();
      await cubit.submit();
      expect(cubit.state.visiblePasswordErrors, [
        'Invalid email or password',
        'Invalid email or password. Please try again.',
      ]);
      expect(cubit.state.showPasswordErrors, isTrue);
    });

    test(
      'an unknown code or a network failure shows the single line',
      () async {
        api.signInError = apiError(
          401,
          code: 'INVALID_EMAIL_OR_PASSWORD',
          message: 'Invalid email or password',
        );
        var cubit = await filled();
        await cubit.submit();
        expect(cubit.state.visiblePasswordErrors, [
          'Invalid email or password',
        ]);
        api.signInError = const ApiNetworkError('offline');
        cubit = await filled();
        await cubit.submit();
        expect(cubit.state.visiblePasswordErrors, [
          'Invalid email or password',
        ]);
        expect(cubit.state.submitting, isFalse);
      },
    );

    test(
      'a 429 whose body says "rate limit" gets the rate-limit line',
      () async {
        api.signInError = apiError(429, message: 'rate limit exceeded');
        final cubit = await filled();
        await cubit.submit();
        expect(
          cubit.state.visiblePasswordErrors.last,
          'Too many requests. Please wait a moment before trying again.',
        );
      },
    );
  });

  group('mapLoginError', () {
    test('every branch', () {
      String second(ApiClientError e) => mapLoginError(e).last;
      expect(
        second(apiError(400, code: 'BAD_REQUEST')),
        'Email sign in is currently disabled.',
      );
      expect(
        second(
          apiError(400, message: 'Email and password sign in is not enabled'),
        ),
        'Email sign in is currently disabled.',
      );
      expect(
        second(apiError(401, message: 'invalid password')),
        'Invalid email or password. Please try again.',
      );
      expect(
        second(apiError(404, code: 'USER_NOT_FOUND')),
        'No account found with this email. Please sign up first.',
      );
      expect(
        second(apiError(400, code: 'MISSING_CREDENTIALS')),
        'Please enter both email and password.',
      );
      expect(
        second(apiError(400, code: 'EMAIL_PASSWORD_DISABLED')),
        'Email and password login is disabled.',
      );
      expect(
        second(apiError(500, code: 'FAILED_TO_CREATE_SESSION')),
        'Failed to create session. Please try again later.',
      );
      expect(
        second(apiError(429, code: 'too many attempts')),
        'Too many login attempts. Please try again later or reset your password.',
      );
      expect(
        second(apiError(403, code: 'account locked')),
        'Your account has been locked for security. Please reset your password.',
      );
      expect(
        second(apiError(0, code: 'network')),
        'Network error. Please check your connection and try again.',
      );
      expect(mapLoginError(apiError(401)), ['Invalid email or password']);
    });
  });

  group('social and links', () {
    test(
      'social chip marks the provider in flight and opens the URL',
      () async {
        final cubit = await ready();
        final future = cubit.startSocial(SocialProvider.google);
        expect(cubit.state.socialInFlight, SocialProvider.google);
        await future;
        expect(api.callsNamed('startSocialSignIn').single.args, {
          'provider': 'google',
          'callbackUrl': '/home',
        });
        expect(navigator.topLevel, [api.socialUrl]);
        expect(cubit.state.socialInFlight, isNull);
      },
    );

    test('a failed social start resets the label', () async {
      api.socialError = apiError(500);
      final cubit = await ready();
      await cubit.startSocial(SocialProvider.github);
      expect(cubit.state.socialInFlight, isNull);
      expect(navigator.topLevel, isEmpty);
    });

    test('SSO chip carries the resolved callback', () async {
      final cubit = await ready({'callbackUrl': '/invite/x'});
      cubit.openSso();
      expect(navigator.gone, ['/sso?callbackUrl=%2Finvite%2Fx']);
    });

    test('legal links open a new tab; logo is a document navigation', () async {
      final cubit = await ready();
      cubit
        ..openLegal('/terms')
        ..goHome();
      expect(navigator.newTabs, ['/terms']);
      expect(navigator.topLevel, ['/']);
    });
  });

  group('forgot password', () {
    test('empty and invalid emails refuse without a request', () async {
      final cubit = await ready();
      cubit.openForgot();
      await cubit.sendReset();
      expect(cubit.state.forgot.message, 'Please enter your email address');
      cubit.forgotEmailChanged('nope');
      await cubit.sendReset();
      expect(cubit.state.forgot.message, 'Please enter a valid email address');
      expect(cubit.state.forgot.statusType, ForgotStatusType.error);
      expect(api.callsNamed('forgetPassword'), isEmpty);
    });

    test('success shows the line and auto-closes after 2s', () async {
      final cubit = await ready();
      cubit
        ..openForgot()
        ..forgotEmailChanged('ada@example.com');
      await cubit.sendReset();
      expect(api.callsNamed('forgetPassword').single.args, {
        'email': 'ada@example.com',
        'redirectTo': '$testOrigin/reset-password',
      });
      expect(cubit.state.forgot.statusType, ForgotStatusType.success);
      expect(
        cubit.state.forgot.message,
        'Password reset link sent to your email',
      );
      expect(cubit.state.forgot.open, isTrue);
      timers.elapse(const Duration(milliseconds: 1999));
      expect(cubit.state.forgot.open, isTrue);
      timers.elapse(const Duration(milliseconds: 1));
      expect(cubit.state.forgot.open, isFalse);
    });

    test('server messages are mapped', () async {
      final cubit = await ready();
      cubit
        ..openForgot()
        ..forgotEmailChanged('ada@example.com');
      api.forgetPasswordError = apiError(
        400,
        message: 'Invalid body parameters',
      );
      await cubit.sendReset();
      expect(cubit.state.forgot.message, 'Please enter a valid email address');
      api.forgetPasswordError = apiError(429, message: 'Too many requests');
      await cubit.sendReset();
      expect(cubit.state.forgot.message, 'Too many requests');
      api.forgetPasswordError = const ApiNetworkError('offline');
      await cubit.sendReset();
      expect(cubit.state.forgot.message, 'Failed to request password reset');
      expect(cubit.state.forgot.submitting, isFalse);
    });

    test(
      'canSend is false while sending and when the field is empty',
      () async {
        final cubit = await ready();
        cubit.openForgot();
        expect(cubit.state.forgot.canSend, isFalse);
        cubit.forgotEmailChanged('ada@example.com');
        expect(cubit.state.forgot.canSend, isTrue);
        final future = cubit.sendReset();
        expect(cubit.state.forgot.canSend, isFalse);
        await future;
      },
    );
  });
}
