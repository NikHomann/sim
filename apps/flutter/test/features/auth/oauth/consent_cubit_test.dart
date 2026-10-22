// Failure modes:
// - a signed-out visitor is bounced to the login bridge with every
//   single-valued param, never shown the request
// - a repeated key (other than ba_param) is tampered; no `sig` is unsigned;
//   a missing or past `exp` is expired; refusals precede the client lookup
// - no `client_id` refuses as missing
// - a lookup failure shows its message or the fallback; an empty registered
//   name refuses with the "asking for access" copy
// - `api:read` is hidden under `api:write`; `search:read` hidden when
//   `api:read` is satisfied; declaration order
// - loopback redirect hosts read "this computer"; unparsable → no line
// - Allow/Deny forward the raw signed query and leave top-level; a failure
//   shows its message or the fallback and re-enables the buttons
// - switch account signs out then restarts the bridge with
//   `prompt=login consent`
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/auth/oauth/consent_cubit.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';

import '../support/fakes.dart';

void main() {
  late FakeAuthApi api;
  late FakeAuthNavigator navigator;
  final now = DateTime.utc(2026, 10, 21, 12);
  final futureExp = '${now.millisecondsSinceEpoch ~/ 1000 + 600}';

  setUp(() {
    api = FakeAuthApi()..session = testSession();
    navigator = FakeAuthNavigator();
  });

  Future<ConsentCubit> ready(String rawQuery) async {
    final uri = Uri.parse('/oauth/consent?$rawQuery');
    final cubit = ConsentCubit(
      api: api,
      navigator: navigator,
      queryAll: uri.queryParametersAll,
      rawQuery: uri.query,
      now: () => now,
    );
    await cubit.load();
    return cubit;
  }

  String signed({
    String clientId = 'app-1',
    String scope = 'api:write offline_access',
    String redirect = 'http://127.0.0.1:8123/cb',
  }) =>
      'client_id=$clientId&scope=${Uri.encodeQueryComponent(scope)}&redirect_uri=${Uri.encodeQueryComponent(redirect)}&sig=abc&exp=$futureExp';

  test('signed out: bounced to the login bridge', () async {
    api.session = null;
    final cubit = await ready(
      'client_id=app-1&sig=x&exp=$futureExp&ba_param=a&ba_param=b',
    );
    expect(navigator.topLevel, [
      '/oauth/sign-in?client_id=app-1&sig=x&exp=$futureExp',
    ]);
    expect(cubit.state.phase, ConsentPhase.loading);
    expect(api.callsNamed('oauthPublicClient'), isEmpty);
  });

  test('refusals: tampered, unsigned, expired, missing', () async {
    expect(
      (await ready(
        'client_id=a&client_id=b&sig=x&exp=$futureExp',
      )).state.refusalMessage,
      consentRefusalMessages['tampered'],
    );
    expect(
      (await ready('client_id=a&exp=$futureExp')).state.refusalMessage,
      consentRefusalMessages['unsigned'],
    );
    expect(
      (await ready('client_id=a&sig=x&exp=1')).state.refusalMessage,
      consentRefusalMessages['expired'],
    );
    expect(
      (await ready('client_id=a&sig=x')).state.refusalMessage,
      consentRefusalMessages['expired'],
    );
    expect(
      (await ready('sig=x&exp=$futureExp')).state.refusalMessage,
      consentRefusalMessages['missing'],
    );
    expect(api.callsNamed('oauthPublicClient'), isEmpty);
  });

  test('lookup failure and empty name', () async {
    api.publicClientError = apiError(
      404,
      message: 'This app could not be found.',
    );
    var cubit = await ready(signed());
    expect(cubit.state.phase, ConsentPhase.refusal);
    expect(cubit.state.refusalMessage, 'This app could not be found.');
    api.publicClientError = const ApiNetworkError('offline');
    cubit = await ready(signed());
    expect(
      cubit.state.refusalMessage,
      'Sim could not identify the app. Start again from the app.',
    );
    api
      ..publicClientError = null
      ..publicClient = const OAuthPublicClient(clientId: 'app-1', name: '  ');
    cubit = await ready(signed());
    expect(
      cubit.state.refusalMessage,
      'Sim could not identify the app. Start again from the app asking for access.',
    );
  });

  test('ready state: scopes, destination, CLI flag', () async {
    var cubit = await ready(signed());
    expect(cubit.state.phase, ConsentPhase.ready);
    expect(cubit.state.appName, 'Acme CLI');
    expect(cubit.state.scopes, ['offline_access', 'api:write']);
    expect(cubit.state.destination, 'this computer');
    expect(cubit.state.email, 'ada@example.com');
    expect(cubit.state.isCli, isFalse);
    cubit = await ready(
      signed(
        clientId: 'sim-cli',
        scope: 'search:read api:read',
        redirect: 'https://app.example.com/cb',
      ),
    );
    expect(cubit.state.isCli, isTrue);
    expect(cubit.state.scopes, ['api:read']);
    expect(cubit.state.destination, 'app.example.com');
    expect(visibleOAuthScopes(['search:read']), ['search:read']);
    expect(describeConsentDestination('not a url'), isNull);
    expect(describeConsentDestination('http://[::1]:5/cb'), 'this computer');
  });

  test('allow forwards the raw query and leaves; deny declines', () async {
    final query = signed();
    final cubit = await ready(query);
    await cubit.decide(accept: true);
    expect(api.callsNamed('oauthConsent').single.args, {
      'accept': true,
      'oauthQuery': query,
    });
    expect(navigator.topLevel, [api.consentUrl]);
    // The page is leaving: the buttons stay disabled after success.
    expect(cubit.state.isPending, isTrue);
    await cubit.decide(accept: false);
    expect(api.callsNamed('oauthConsent'), hasLength(1));
    final deny = await ready(query);
    await deny.decide(accept: false);
    expect(api.callsNamed('oauthConsent').last.args['accept'], isFalse);
  });

  test(
    'consent failure shows the message or fallback and re-enables',
    () async {
      api.consentError = apiError(403, message: 'Not allowed');
      final cubit = await ready(signed());
      final future = cubit.decide(accept: true);
      expect(cubit.state.deciding, isTrue);
      expect(cubit.state.isPending, isTrue);
      await future;
      expect(cubit.state.errorMessage, 'Not allowed');
      expect(cubit.state.isPending, isFalse);
      api.consentError = const ApiNetworkError('offline');
      await cubit.decide(accept: false);
      expect(
        cubit.state.errorMessage,
        'Something went wrong. Please try again.',
      );
      expect(navigator.topLevel, isEmpty);
    },
  );

  test('switch account signs out then restarts the bridge', () async {
    final cubit = await ready(signed());
    await cubit.switchAccount();
    expect(api.callsNamed('signOut'), hasLength(1));
    expect(
      navigator.topLevel.single,
      startsWith('/oauth/sign-in?client_id=app-1&'),
    );
    expect(navigator.topLevel.single, endsWith('&prompt=login+consent'));
    api.signOutError = apiError(500, message: 'nope');
    final failing = await ready(signed());
    await failing.switchAccount();
    expect(failing.state.errorMessage, 'nope');
    expect(failing.state.switching, isFalse);
  });
}
