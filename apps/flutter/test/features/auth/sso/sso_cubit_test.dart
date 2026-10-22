// Failure modes:
// - `?error=` codes map to their copy; an unknown code to the generic one;
//   the pre-filled error clears on the first keystroke
// - an invalid `?callbackUrl` falls back to `/home`; the links always carry
//   the encoded callback
// - SSO disabled sends the visitor to `/login`
// - submit validates (errors shown after submit, hidden on typing) and
//   sends no request when invalid
// - resolver 404 → no-provider copy (test-link copy with `?provider`);
//   any other resolver failure → sign-in error
// - a failed sign-in start → sign-in error; success leaves top-level with
//   the IdP URL; the error callback carries provider before callbackUrl
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/sso/sso_cubit.dart';

import '../support/fakes.dart';

void main() {
  late FakeAuthApi api;
  late FakeAuthNavigator navigator;

  setUp(() {
    api = FakeAuthApi()..options = const AuthPageOptions(ssoEnabled: true);
    navigator = FakeAuthNavigator();
  });

  SsoCubit build([Map<String, String> query = const {}]) => SsoCubit(
    api: api,
    navigator: navigator,
    origin: testOrigin,
    query: query,
  );

  test('error codes and the generic fallback; cleared on typing', () {
    expect(
      build({'error': 'sso_no_seats'}).state.formError,
      SsoCopy.errorMessages['sso_no_seats'],
    );
    final cubit = build({'error': 'whatever'});
    expect(
      cubit.state.formError,
      'SSO authentication failed. Please try again.',
    );
    cubit.emailChanged('a');
    expect(cubit.state.formError, isNull);
    expect(build().state.formError, isNull);
  });

  test('callback validation and link encoding', () {
    final bad = build({'callbackUrl': 'https://evil.com'});
    expect(bad.state.callbackUrl, '/home');
    expect(bad.loginHref, '/login?callbackUrl=%2Fhome');
    final good = build({
      'callbackUrl': '/invite/a?token=t',
      'provider': 'okta',
    });
    expect(good.signupHref, '/signup?callbackUrl=%2Finvite%2Fa%3Ftoken%3Dt');
    expect(
      good.errorCallbackUrl,
      '/sso?error=sso_failed&provider=okta&callbackUrl=%2Finvite%2Fa%3Ftoken%3Dt',
    );
    expect(build({'email': 'x@y.co'}).state.email, 'x@y.co');
  });

  test('SSO disabled redirects to /login', () async {
    api.options = const AuthPageOptions();
    final cubit = build();
    await cubit.load();
    expect(navigator.gone, ['/login']);
    expect(cubit.state.loading, isTrue);
  });

  test(
    'invalid email: errors after submit, hidden on typing, no request',
    () async {
      final cubit = build()..emailChanged('nope');
      expect(cubit.state.visibleEmailErrors, isEmpty);
      await cubit.submit();
      expect(cubit.state.visibleEmailErrors, ['Invalid email format']);
      expect(api.callsNamed('resolveSsoProvider'), isEmpty);
      cubit.emailChanged('nope2');
      expect(cubit.state.visibleEmailErrors, isEmpty);
      expect(cubit.state.submitting, isFalse);
    },
  );

  test('resolver 404 copy, test-link copy, other failures', () async {
    api.resolveSsoError = apiError(404, code: 'SSO_NO_PROVIDER');
    var cubit = build()..emailChanged(' Ada@Example.com ');
    await cubit.submit();
    expect(api.callsNamed('resolveSsoProvider').single.args, {
      'email': 'ada@example.com',
      'providerId': null,
    });
    expect(cubit.state.formError, SsoCopy.noProviderError);
    cubit = build({'provider': 'okta'})..emailChanged('ada@example.com');
    await cubit.submit();
    expect(cubit.state.formError, SsoCopy.testLinkError);
    expect(
      api.callsNamed('resolveSsoProvider').last.args['providerId'],
      'okta',
    );
    api.resolveSsoError = apiError(429);
    cubit = build()..emailChanged('ada@example.com');
    await cubit.submit();
    expect(cubit.state.formError, SsoCopy.signInError);
    expect(api.callsNamed('startSsoSignIn'), isEmpty);
  });

  test('sign-in start: failure copy; success leaves top-level', () async {
    api.ssoSignInError = const ApiNetworkError('offline');
    var cubit = build()..emailChanged('ada@example.com');
    await cubit.submit();
    expect(cubit.state.formError, SsoCopy.signInError);
    expect(cubit.state.submitting, isFalse);
    api.ssoSignInError = null;
    cubit = build({'callbackUrl': '/invite/a'})
      ..emailChanged('ada@example.com');
    await cubit.submit();
    expect(api.callsNamed('startSsoSignIn').last.args, {
      'email': 'ada@example.com',
      'providerId': 'okta-1',
      'callbackUrl': '/invite/a',
      'errorCallbackUrl': '/sso?error=sso_failed&callbackUrl=%2Finvite%2Fa',
    });
    expect(navigator.topLevel, [api.ssoUrl]);
  });
}
