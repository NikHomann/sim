// Failure modes:
// - every failing password rule is listed at once, in rule order
// - name rules: required, invalid characters (unicode letters allowed),
//   consecutive spaces; > 100 characters stops after the other rules pass
// - the email is trimmed and lower-cased before validation and the request
// - `?email=` pre-fills; `redirect` beats `callbackUrl`; an invalid
//   destination is dropped; `/invite/` implies the invite flow
// - server errors land on the right field (USER_ALREADY_EXISTS → email,
//   PASSWORD_TOO_SHORT → password with the prefix line, unknown → default)
//   and the email server line clears on typing
// - success with verification stores the hop state and goes to
//   `/verify?fromSignup=true`; without verification it navigates to the
//   destination; stale hop state is cleared first
// - the verification route is decided by the server flag only, never from
//   the sign-up response
// - registrationDisabled replaces the page
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/signup/signup_cubit.dart';

import '../support/fakes.dart';

void main() {
  late FakeAuthApi api;
  late FakeAuthNavigator navigator;
  late MemoryAuthSessionStore store;

  setUp(() {
    api = FakeAuthApi();
    navigator = FakeAuthNavigator();
    store = MemoryAuthSessionStore();
  });

  SignupCubit build([Map<String, String> query = const {}]) => SignupCubit(
    api: api,
    navigator: navigator,
    sessionStore: store,
    origin: testOrigin,
    query: query,
  );

  Future<SignupCubit> filled([Map<String, String> query = const {}]) async {
    final cubit = build(query);
    await cubit.load();
    cubit
      ..nameChanged('Ada Lovelace')
      ..emailChanged(' Ada@Example.com ')
      ..passwordChanged('Secret1!');
    return cubit;
  }

  group('validators', () {
    test('password lists every failing rule in order', () {
      expect(validateSignupPassword(''), [
        'Password must be at least 8 characters long.',
        'Password must include at least one uppercase letter.',
        'Password must include at least one lowercase letter.',
        'Password must include at least one number.',
        'Password must include at least one special character.',
      ]);
      expect(validateSignupPassword('Secret1!'), isEmpty);
      expect(validateSignupPassword('secret12'), [
        'Password must include at least one uppercase letter.',
        'Password must include at least one special character.',
      ]);
    });

    test('name rules', () {
      expect(validateSignupName(''), ['Name is required.']);
      expect(validateSignupName('  '), ['Name cannot be empty.']);
      expect(validateSignupName('Ada  Lovelace'), [
        'Name cannot contain consecutive spaces.',
      ]);
      expect(validateSignupName('Ada9'), [
        'Name can only contain letters, spaces, hyphens, and apostrophes.',
      ]);
      expect(validateSignupName("Zoë O'Brien-Søren"), isEmpty);
    });
  });

  group('query handling', () {
    test('email pre-fills; redirect beats callbackUrl; invite inferred', () {
      final cubit = build({
        'email': 'ada@example.com',
        'redirect': '/invite/abc',
        'callbackUrl': '/home',
      });
      expect(cubit.state.email, 'ada@example.com');
      expect(cubit.state.redirectUrl, '/invite/abc');
      expect(cubit.state.isInviteFlow, isTrue);
      expect(
        cubit.loginHref,
        '/login?invite_flow=true&callbackUrl=%2Finvite%2Fabc',
      );
    });

    test('invalid destination dropped; callback defaults to /home', () {
      final cubit = build({'callbackUrl': 'https://evil.com'});
      expect(cubit.state.redirectUrl, '');
      expect(cubit.state.callbackUrl, '/home');
      expect(cubit.loginHref, '/login');
    });
  });

  group('submit', () {
    test('surfaces all three error lists without a request', () async {
      final cubit = build();
      await cubit.load();
      cubit
        ..nameChanged('Ada  9')
        ..emailChanged('nope')
        ..passwordChanged('short');
      await cubit.submit();
      expect(cubit.state.visibleNameErrors, hasLength(2));
      expect(cubit.state.visibleEmailErrors, ['Invalid email format']);
      expect(cubit.state.visiblePasswordErrors, hasLength(4));
      expect(api.callsNamed('signUpEmail'), isEmpty);
      expect(cubit.state.submitting, isFalse);
    });

    test('a name over 100 characters stops after the rules pass', () async {
      final cubit = await filled();
      cubit.nameChanged('a' * 101);
      await cubit.submit();
      expect(cubit.state.visibleNameErrors, [
        'Name will be truncated to 100 characters. Please shorten your name.',
      ]);
      expect(api.callsNamed('signUpEmail'), isEmpty);
    });

    test('sends trimmed, lower-cased email and trimmed name', () async {
      api.options = const AuthPageOptions(emailVerificationEnabled: false);
      final cubit = await filled();
      cubit.nameChanged('  Ada Lovelace ');
      await cubit.submit();
      expect(api.callsNamed('signUpEmail').single.args, {
        'email': 'ada@example.com',
        'password': 'Secret1!',
        'name': 'Ada Lovelace',
        'captchaToken': null,
      });
    });

    test(
      'verification enabled: stores hop state and goes to /verify',
      () async {
        store
          ..write(AuthStorageKeys.verificationEmail, 'old@example.com')
          ..write(AuthStorageKeys.postAuthRedirectUrl, '/cli/auth?old');
        final cubit = await filled({'callbackUrl': '/invite/abc'});
        await cubit.submit();
        expect(api.callsNamed('getSession'), hasLength(2));
        expect(
          store.read(AuthStorageKeys.verificationEmail),
          'ada@example.com',
        );
        expect(store.read(AuthStorageKeys.postAuthRedirectUrl), '/invite/abc');
        expect(navigator.gone, ['/verify?fromSignup=true']);
      },
    );

    test(
      'verification disabled: navigates to the destination, hop state cleared',
      () async {
        api.options = const AuthPageOptions(emailVerificationEnabled: false);
        store.write(AuthStorageKeys.verificationEmail, 'old@example.com');
        final cubit = await filled({'callbackUrl': '/invite/abc'});
        await cubit.submit();
        expect(store.read(AuthStorageKeys.verificationEmail), isNull);
        expect(navigator.gone, ['/invite/abc']);
        final plain = await filled();
        await plain.submit();
        expect(navigator.gone.last, '/home');
      },
    );

    test('an absent server flag means no verification route', () async {
      api
        ..options = AuthPageOptions.fromResponses(
          publicEnv: null,
          providers: const AuthProviders(
            githubAvailable: false,
            googleAvailable: false,
            microsoftAvailable: false,
            registrationDisabled: false,
          ),
        )
        ..session = null;
      final cubit = await filled();
      await cubit.submit();
      expect(navigator.gone, ['/home']);
      expect(store.read(AuthStorageKeys.verificationEmail), isNull);
    });

    test(
      'USER_ALREADY_EXISTS lands on the email field and clears on typing',
      () async {
        api.signUpError = apiError(422, code: 'USER_ALREADY_EXISTS');
        final cubit = await filled();
        await cubit.submit();
        expect(cubit.state.visibleEmailErrors, [
          'An account with this email already exists. Please sign in instead.',
        ]);
        expect(cubit.state.emailHasError, isTrue);
        expect(cubit.state.submitting, isFalse);
        cubit.emailChanged('ada2@example.com');
        expect(cubit.state.visibleEmailErrors, isEmpty);
      },
    );

    test(
      'PASSWORD_TOO_SHORT and unknown errors land on the password field',
      () async {
        api.signUpError = apiError(400, code: 'PASSWORD_TOO_SHORT');
        var cubit = await filled();
        await cubit.submit();
        expect(cubit.state.visiblePasswordErrors, [
          'Failed to create account',
          'Password must be at least 8 characters long.',
        ]);
        api.signUpError = const ApiNetworkError('offline');
        cubit = await filled();
        await cubit.submit();
        expect(cubit.state.visiblePasswordErrors, ['Failed to create account']);
        api.signUpError = apiError(
          403,
          message: 'Registration is disabled, please contact your admin.',
        );
        cubit = await filled();
        await cubit.submit();
        expect(cubit.state.visiblePasswordErrors, ['Failed to create account']);
      },
    );

    test('BAD_REQUEST and INVALID_EMAIL mark the email field', () {
      expect(
        mapSignupError(apiError(400, code: 'BAD_REQUEST')).emailError,
        'Failed to create account',
      );
      expect(
        mapSignupError(apiError(400, code: 'INVALID_EMAIL')).emailError,
        'Failed to create account',
      );
      expect(
        mapSignupError(
          apiError(400, code: 'PASSWORD_TOO_LONG'),
        ).passwordErrors!.last,
        'Password must be less than 128 characters long.',
      );
    });
  });

  test(
    'registrationDisabled replaces the page; signed-in visitor leaves',
    () async {
      api.options = const AuthPageOptions(registrationDisabled: true);
      var cubit = build();
      await cubit.load();
      expect(cubit.state.options.registrationDisabled, isTrue);
      api.session = testSession();
      cubit = build();
      await cubit.load();
      expect(navigator.gone, ['/home']);
    },
  );

  test('social and SSO use redirectUrl || /home', () async {
    final cubit = build({'callbackUrl': '/invite/abc'});
    await cubit.load();
    cubit.openSso();
    expect(navigator.gone, ['/sso?callbackUrl=%2Finvite%2Fabc']);
  });
}
