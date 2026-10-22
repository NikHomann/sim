// Failure modes:
// - consent: a refusal renders only the header; a ready request renders
//   the app name, visible scopes, destination and account line; Allow
//   leaves top-level with the consent URL; the CLI client hides the
//   description and destination
// - oauth-error maps `?error=` and appends the close-tab suffix; an unknown
//   code gets the generic copy
// - credential-connected: connected vs failed copy by `result`/`error`
// - chat-complete: the attempt record is updated, the window closed, and
//   the fallback `replace` fires after 400ms to the same-origin returnTo only
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/oauth/consent_page.dart';
import 'package:sim_app/features/auth/oauth/status_pages.dart';

import '../support/fakes.dart';
import '../support/pump.dart';

void main() {
  late FakeAuthDeps deps;

  setUp(() => deps = FakeAuthDeps()..api.session = testSession());

  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;

  testWidgets('consent refusal and ready views', (tester) async {
    await pumpAuthPage(
      tester,
      OAuthConsentPage(
        uri: Uri.parse('/oauth/consent?client_id=app-1&exp=$exp'),
      ),
      deps: deps,
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to connect'), findsOneWidget);
    expect(
      find.text('This authorization request did not come from Sim.'),
      findsOneWidget,
    );
    expect(byParityId('oauth.consent.allow'), findsNothing);

    deps = FakeAuthDeps()..api.session = testSession();
    await pumpAuthPage(
      tester,
      OAuthConsentPage(
        uri: Uri.parse(
          '/oauth/consent?client_id=app-1&scope=api:write%20api:read&redirect_uri=http://127.0.0.1:9/cb&sig=s&exp=$exp',
        ),
      ),
      deps: deps,
    );
    await tester.pumpAndSettle();
    expect(find.text('Authorize Acme CLI'), findsOneWidget);
    expect(
      find.text('Only continue if you started this yourself.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Read, create, change, run, and delete resources in your workspaces',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Read your workspaces, workflows, files, tables, and logs'),
      findsNothing,
    );
    expect(find.text('Returns to this computer.'), findsOneWidget);
    expect(
      find.textContaining('Continuing as ada@example.com.'),
      findsOneWidget,
    );
    await tester.tap(byParityId('oauth.consent.allow'));
    await tester.pumpAndSettle();
    expect(deps.navigator.topLevel, [deps.api.consentUrl]);
  });

  testWidgets('consent CLI client hides description and destination', (
    tester,
  ) async {
    await pumpAuthPage(
      tester,
      OAuthConsentPage(
        uri: Uri.parse('/oauth/consent?client_id=sim-cli&sig=s&exp=$exp'),
      ),
      deps: deps,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Only continue if you started this yourself.'),
      findsNothing,
    );
    expect(byParityId('oauth.consent.destination'), findsNothing);
    expect(byParityId('oauth.consent.deny'), findsOneWidget);
  });

  testWidgets('oauth-error copy', (tester) async {
    await pumpAuthPage(
      tester,
      const OAuthErrorPage(query: {'error': 'access_denied'}),
      deps: deps,
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign-in couldn’t be completed'), findsOneWidget);
    expect(
      find.text(
        'You declined the request at the provider, so nothing was connected. You can close this tab and return to Sim.',
      ),
      findsOneWidget,
    );
    expect(
      oauthErrorMessage('???'),
      'The sign-in couldn’t be completed. Please try again.',
    );
  });

  testWidgets('credential-connected copy', (tester) async {
    await pumpAuthPage(
      tester,
      const CredentialConnectedPage(query: {'result': 'connected'}),
      deps: deps,
    );
    await tester.pumpAndSettle();
    expect(find.text('Credential connected'), findsOneWidget);
    expect(byParityId('oauth.credentialConnected.open'), findsOneWidget);
    deps = FakeAuthDeps();
    await pumpAuthPage(
      tester,
      const CredentialConnectedPage(
        query: {'result': 'connected', 'error': 'x'},
      ),
      deps: deps,
    );
    await tester.pumpAndSettle();
    expect(find.text('Connection failed'), findsOneWidget);
  });

  testWidgets('chat-complete publishes the verdict and falls back', (
    tester,
  ) async {
    deps.localStore.write(
      'sim.oauth-chat-attempt.a1',
      jsonEncode({'id': 'a1', 'status': 'pending'}),
    );
    await pumpAuthPage(
      tester,
      const OAuthChatCompletePage(
        query: {'oauthAttempt': 'a1', 'returnTo': 'https://evil.com/x'},
      ),
      deps: deps,
    );
    await tester.pumpAndSettle();
    expect(find.text('Finishing the connection'), findsOneWidget);
    final record =
        jsonDecode(deps.localStore.read('sim.oauth-chat-attempt.a1')!) as Map;
    expect(record['status'], 'connected');
    expect(deps.navigator.closes, 1);
    deps.timers.elapse(const Duration(milliseconds: 400));
    expect(deps.navigator.replaced, ['/home']);
    expect(deps.navigator.topLevel, isEmpty);

    deps = FakeAuthDeps();
    await pumpAuthPage(
      tester,
      const OAuthChatCompletePage(
        query: {
          'oauthAttempt': 'a1',
          'error': 'x',
          'returnTo': '/workspace/1/home',
        },
      ),
      deps: deps,
    );
    await tester.pumpAndSettle();
    expect(deps.localStore.read('sim.oauth-chat-attempt.a1'), isNull);
    deps.timers.elapse(const Duration(milliseconds: 400));
    expect(deps.navigator.replaced, ['$testOrigin/workspace/1/home']);
  });
}
