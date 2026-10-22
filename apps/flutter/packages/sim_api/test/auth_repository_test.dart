// Failure modes of AuthRepository against a dart:io fake server:
// 1. sign-in with an unverified email surfaces `EMAIL_NOT_VERIFIED`;
// 2. a 403 with a message is a policy refusal, a 401 without one is not;
// 3. get-session with a `null` body is "signed out"; `disableCookieCache`
//    is sent only when asked;
// 4. socket-token 401 is "authentication required", a 429 with Retry-After is
//    "unavailable" carrying the delay, a 5xx is "unavailable" without one;
// 5. social sign-in without a URL in the response is an error;
// 6. sign-out drops the desktop cookies even when the request fails;
// 7. the one-time-token redeem stores the cookie the server sets.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import 'support/fake_server.dart';

void main() {
  late FakeServer server;
  late MemoryCookieStorage cookies;
  late AuthRepository auth;

  setUp(() async {
    server = await FakeServer.start();
    cookies = MemoryCookieStorage();
    auth = AuthRepository(
      SimHttpClient(baseUrl: server.url, cookieStorage: cookies),
    );
  });

  tearDown(() => server.close());

  test('an unverified email surfaces EMAIL_NOT_VERIFIED', () async {
    server.handler = (request, body) => FakeServer.json(request, 403, {
      'code': 'EMAIL_NOT_VERIFIED',
      'message': 'Email not verified',
    });
    await expectLater(
      auth.signInEmail(email: 'a@b.c', password: 'pw', callbackUrl: '/home'),
      throwsA(
        isA<ApiClientError>().having(
          (e) => e.isEmailNotVerified,
          'notVerified',
          true,
        ),
      ),
    );
    expect(server.requests.single.json, {
      'email': 'a@b.c',
      'password': 'pw',
      'callbackURL': '/home',
    });
  });

  test('a 403 with a message is a policy refusal; a 401 is not', () async {
    server.handler = (request, body) => FakeServer.json(request, 403, {
      'message': 'Your organization requires single sign-on',
    });
    await expectLater(
      auth.signInEmail(email: 'a@b.c', password: 'pw'),
      throwsA(
        isA<ApiClientError>()
            .having((e) => e.isPolicyRefusal, 'policy', true)
            .having(
              (e) => e.message,
              'message',
              'Your organization requires single sign-on',
            ),
      ),
    );
    server.handler = (request, body) => FakeServer.json(request, 401, {
      'code': 'INVALID_EMAIL_OR_PASSWORD',
      'message': 'x',
    });
    await expectLater(
      auth.signInEmail(email: 'a@b.c', password: 'pw'),
      throwsA(
        isA<ApiClientError>().having((e) => e.isPolicyRefusal, 'policy', false),
      ),
    );
  });

  test(
    'get-session: null body is signed out; disableCookieCache only when asked',
    () async {
      server.handler = (request, body) => FakeServer.json(request, 200, null);
      expect(await auth.getSession(), isNull);
      expect(server.requests[0].query, isEmpty);

      server.handler = (request, body) => FakeServer.json(request, 200, {
        'user': {'id': 'u1', 'email': 'a@b.c'},
        'session': {'id': 's1', 'impersonatedBy': 'admin'},
      });
      final session = await auth.getSession(disableCookieCache: true);
      expect(server.requests[1].query, {'disableCookieCache': 'true'});
      expect(session?.user.id, 'u1');
      expect(session?.isImpersonated, isTrue);
    },
  );

  test(
    'socket-token: 401 is auth required, 429 carries Retry-After, 5xx none',
    () async {
      server.handler = (request, body) =>
          FakeServer.json(request, 401, {'error': 'Authentication required'});
      await expectLater(
        auth.socketToken(),
        throwsA(isA<SocketTokenAuthRequiredError>()),
      );

      server.handler = (request, body) => FakeServer.json(
        request,
        429,
        {'error': 'Too many'},
        headers: {'retry-after': '7'},
      );
      await expectLater(
        auth.socketToken(),
        throwsA(
          isA<SocketTokenUnavailableError>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 7),
          ),
        ),
      );

      server.handler = (request, body) =>
          FakeServer.json(request, 500, {'error': 'Failed'});
      await expectLater(
        auth.socketToken(),
        throwsA(
          isA<SocketTokenUnavailableError>().having(
            (e) => e.retryAfter,
            'retryAfter',
            isNull,
          ),
        ),
      );

      server.handler = (request, body) =>
          FakeServer.json(request, 200, {'token': 'one-time'});
      expect(await auth.socketToken(), 'one-time');
      expect(server.requests.last.headers['cache-control'], 'no-store');
    },
  );

  test('social sign-in without a URL is an error', () async {
    server.handler = (request, body) =>
        FakeServer.json(request, 200, {'redirect': true});
    await expectLater(
      auth.signInSocial(provider: 'github', callbackUrl: '/home'),
      throwsA(isA<ApiClientError>()),
    );
    server.handler = (request, body) => FakeServer.json(request, 200, {
      'url': 'https://github.com/login',
      'redirect': true,
    });
    final start = await auth.signInSocial(
      provider: 'github',
      callbackUrl: '/home',
    );
    expect(start.url, 'https://github.com/login');
  });

  test('sign-out drops the cookies even when the request fails', () async {
    server.handler = (request, body) async {
      if (request.uri.path == '/api/auth/sign-in/email') {
        request.response.headers.set(
          'set-cookie',
          'better-auth.session_token=t.s; Path=/',
        );
        await FakeServer.json(request, 200, {
          'user': {'id': 'u1', 'email': 'a@b.c'},
        });
        return;
      }
      await FakeServer.json(request, 500, {'error': 'down'});
    };
    await auth.signInEmail(email: 'a@b.c', password: 'pw');
    await expectLater(auth.signOut(), throwsA(isA<ApiClientError>()));
    await auth.getSession().catchError((_) => null);
    expect(server.requests.last.headers.containsKey('cookie'), isFalse);
  });

  test(
    'redeeming a one-time token stores the cookie the server sets',
    () async {
      server.handler = (request, body) async {
        if (request.uri.path == '/api/auth/one-time-token/verify') {
          request.response.headers.set(
            'set-cookie',
            'better-auth.session_token=desk.sig; Path=/',
          );
          await FakeServer.json(request, 200, {
            'user': {'id': 'u1', 'email': 'a@b.c'},
            'session': {'id': 's1'},
          });
          return;
        }
        await FakeServer.json(request, 200, null);
      };
      final session = await auth.redeemOneTimeToken('ott');
      expect(session?.user.id, 'u1');
      expect(server.requests.first.json, {'token': 'ott'});
      await auth.getSession();
      expect(
        server.requests.last.headers['cookie'],
        contains('better-auth.session_token=desk.sig'),
      );
    },
  );
}
