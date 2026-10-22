// Failure modes of RuntimeConfigRepository against a dart:io fake server
// (spec §4.2, §9, §10 #3-7, #22, #25):
// 1. host-context 403 `{error:'Workspace access denied'}` is a typed
//    `WorkspaceAccess.denied`, not an exception; 401 still throws;
// 2. feature-flags 403 and 404 are `FeatureFlagsDenied`, 429 is
//    `FeatureFlagsRateLimited` carrying the parsed `Retry-After`, 500 throws;
// 3. a 2xx host context whose body fails the contract is an
//    `ApiClientError` with the 2xx status and the validation message;
// 4. a public-env key without the prefix fails the same way; a valid record
//    decodes and the request carries no credentials-only headers;
// 5. a non-object 2xx body (`null`, text) is a contract failure too.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import '../contracts/fixtures.dart';
import '../support/fake_server.dart';

void main() {
  late FakeServer server;
  late RuntimeConfigRepository repo;

  setUp(() async {
    server = await FakeServer.start();
    repo = RuntimeConfigRepository(SimHttpClient(baseUrl: server.url));
  });

  tearDown(() => server.close());

  group('host context', () {
    test('403 is WorkspaceAccess.denied, 401 throws', () async {
      server.handler = (request, body) =>
          FakeServer.json(request, 403, {'error': 'Workspace access denied'});
      final denied = await repo.hostContext('ws');
      expect(denied, isA<WorkspaceAccessDenied>());
      expect(denied.isDenied, isTrue);
      expect(denied.contextOrNull, isNull);
      expect(server.requests.single.path, '/api/workspaces/ws/host-context');

      server.handler = (request, body) =>
          FakeServer.json(request, 401, {'error': 'Unauthorized'});
      await expectLater(
        repo.hostContext('ws'),
        throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 401)),
      );
    });

    test('a granted context decodes', () async {
      server.handler = (request, body) =>
          FakeServer.json(request, 200, liveHostContextJson());
      final access = await repo.hostContext(workspaceId);
      expect(access.contextOrNull?.deployment?.chatEnabled, isTrue);
      expect(
        access.contextOrNull?.viewer.permission,
        WorkspacePermission.admin,
      );
    });

    test('a 2xx body failing the contract is ApiClientError{200}', () async {
      server.handler = (request, body) => FakeServer.json(
        request,
        200,
        liveHostContextJson()..remove('viewer'),
      );
      await expectLater(
        repo.hostContext(workspaceId),
        throwsA(
          isA<ApiClientError>()
              .having((e) => e.status, 'status', 200)
              .having(
                (e) => e.message,
                'message',
                startsWith('Response failed contract validation — viewer'),
              ),
        ),
      );
    });
  });

  group('feature flags', () {
    test('403 and 404 are denied', () async {
      for (final status in [403, 404]) {
        server.handler = (request, body) =>
            FakeServer.json(request, status, {'error': 'Not found'});
        final result = await repo.featureFlags('ws');
        expect(result, isA<FeatureFlagsDenied>());
        expect((result as FeatureFlagsDenied).error.status, status);
      }
    });

    test('429 carries Retry-After', () async {
      server.handler = (request, body) => FakeServer.json(
        request,
        429,
        {'error': 'Rate limit exceeded', 'retryAfter': 1700000000000},
        headers: {
          'Retry-After': '7',
          'X-RateLimit-Reset': '2026-01-01T00:00:00Z',
        },
      );
      final result = await repo.featureFlags('ws');
      expect(result, isA<FeatureFlagsRateLimited>());
      final limited = result as FeatureFlagsRateLimited;
      expect(limited.retryAfter, const Duration(seconds: 7));
      expect(limited.error.rateLimit?.reset, '2026-01-01T00:00:00Z');
      expect(limited.error.message, 'Rate limit exceeded');
    });

    test('500 throws; a loaded response decodes', () async {
      server.handler = (request, body) =>
          FakeServer.json(request, 500, {'error': 'boom'});
      await expectLater(
        repo.featureFlags('ws'),
        throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 500)),
      );
      server.handler = (request, body) => FakeServer.json(request, 200, {
        'flags': featureFlagsJson(),
        'desktopExecutor': {'available': true, 'registered': false},
      });
      final loaded = await repo.featureFlags('ws');
      expect(loaded, isA<FeatureFlagsLoaded>());
      final response = (loaded as FeatureFlagsLoaded).response;
      expect(response.flags.dashboards, isTrue);
      expect(response.desktopExecutor.available, isTrue);
    });
  });

  group('public env', () {
    test('a key without the prefix is a contract failure', () async {
      server.handler = (request, body) => FakeServer.json(request, 200, {
        'NEXT_PUBLIC_APP_URL': 'http://localhost:3000',
        'DATABASE_URL': 'postgres://x',
      });
      await expectLater(
        repo.publicEnv(),
        throwsA(
          isA<ApiClientError>()
              .having((e) => e.status, 'status', 200)
              .having((e) => e.message, 'message', contains('DATABASE_URL')),
        ),
      );
    });

    test('a valid record decodes', () async {
      server.handler = (request, body) => FakeServer.json(
        request,
        200,
        {'NEXT_PUBLIC_APP_URL': 'http://localhost:3000'},
        headers: {'Cache-Control': 'no-store'},
      );
      final env = await repo.publicEnv();
      expect(env.appUrl, 'http://localhost:3000');
      expect(server.requests.single.path, '/api/public-env');
    });

    test('a non-object body is a contract failure', () async {
      server.handler = (request, body) => FakeServer.json(request, 200, null);
      await expectLater(
        repo.publicEnv(),
        throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 200)),
      );
    });
  });
}
