// Failure modes of SimHttpClient against a dart:io fake server:
// 1. every request carries `x-sim-client-id` and a JSON body goes out with
//    exactly `application/json`; a GET sends no body;
// 2. a non-2xx response becomes ApiClientError with status, body and headers;
// 3. a refused connection becomes ApiNetworkError, not a DioException;
// 4. cancelling through the token becomes ApiCancelledError;
// 5. a streaming request resolves with headers before the body ends and
//    delivers chunks as they arrive;
// 6. a streaming request with a non-2xx status reads the body and throws
//    ApiClientError;
// 7. a stream cut mid-body surfaces ApiNetworkError on the byte stream;
// 8. with a cookie storage, Set-Cookie is persisted and sent back, survives a
//    new client on the same storage, and clearCookies drops it.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import 'support/fake_server.dart';

void main() {
  late FakeServer server;

  setUp(() async {
    server = await FakeServer.start();
  });

  tearDown(() => server.close());

  test(
    'client id header and exact JSON content type; GET has no body',
    () async {
      server.handler = (request, body) =>
          FakeServer.json(request, 200, {'ok': true});
      final client = SimHttpClient(baseUrl: server.url, clientId: 'tab-1');
      await client.send(method: 'POST', path: '/api/x', body: {'a': 1});
      await client.send(method: 'GET', path: '/api/y', body: {'ignored': true});

      final post = server.requests[0];
      expect(post.headers['x-sim-client-id'], 'tab-1');
      expect(post.headers['content-type'], 'application/json');
      expect(post.json, {'a': 1});
      final get = server.requests[1];
      expect(get.body, isEmpty);
      expect(get.headers.containsKey('content-type'), isFalse);
    },
  );

  test('a non-2xx response becomes ApiClientError', () async {
    server.handler = (request, body) => FakeServer.json(
      request,
      403,
      {'error': 'Forbidden', 'requestId': 'r1'},
      headers: {'x-ratelimit-remaining': '3'},
    );
    final client = SimHttpClient(baseUrl: server.url);
    await expectLater(
      client.send(method: 'GET', path: '/api/x'),
      throwsA(
        isA<ApiClientError>()
            .having((e) => e.status, 'status', 403)
            .having((e) => e.message, 'message', 'Forbidden')
            .having((e) => e.requestId, 'requestId', 'r1')
            .having((e) => e.rateLimit?.remaining, 'remaining', 3),
      ),
    );
  });

  test('a refused connection becomes ApiNetworkError', () async {
    final port = server.url.split(':').last;
    await server.close();
    final client = SimHttpClient(baseUrl: 'http://127.0.0.1:$port');
    await expectLater(
      client.send(method: 'GET', path: '/api/x'),
      throwsA(isA<ApiNetworkError>()),
    );
  });

  test('cancelling becomes ApiCancelledError', () async {
    final gate = Completer<void>();
    server.handler = (request, body) async {
      await gate.future;
      await FakeServer.json(request, 200, {});
    };
    final client = SimHttpClient(baseUrl: server.url);
    final token = CancelToken();
    final pending = client.send(
      method: 'GET',
      path: '/api/x',
      cancelToken: token,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    token.cancel();
    await expectLater(pending, throwsA(isA<ApiCancelledError>()));
    gate.complete();
  });

  test(
    'a stream resolves on headers and delivers chunks as they arrive',
    () async {
      final secondChunk = Completer<void>();
      server.handler = (request, body) async {
        final writer = await FakeServer.sse(
          request,
          headers: {'x-execution-id': 'exec-1'},
        );
        await writer.write('data: 1\n\n');
        await secondChunk.future;
        await writer.write('data: 2\n\n');
        await writer.close();
      };
      final client = SimHttpClient(baseUrl: server.url);
      final response = await client.stream(
        method: 'POST',
        path: '/api/stream',
        body: {},
      );
      expect(response.header('x-execution-id'), 'exec-1');

      final received = <String>[];
      final done = Completer<void>();
      response.bytes.listen(
        (chunk) {
          received.add(utf8.decode(chunk));
          if (received.length == 1) secondChunk.complete();
        },
        onDone: done.complete,
      );
      await done.future;
      expect(received.join(), 'data: 1\n\ndata: 2\n\n');
      expect(received.length, greaterThanOrEqualTo(2));
    },
  );

  test('a stream with a non-2xx status reads the body and throws', () async {
    server.handler = (request, body) =>
        FakeServer.json(request, 402, {'error': 'Usage limit exceeded'});
    final client = SimHttpClient(baseUrl: server.url);
    await expectLater(
      client.stream(method: 'POST', path: '/api/stream', body: {}),
      throwsA(
        isA<ApiClientError>()
            .having((e) => e.status, 'status', 402)
            .having((e) => e.message, 'message', 'Usage limit exceeded'),
      ),
    );
  });

  test('a stream cut mid-body surfaces ApiNetworkError', () async {
    server.handler = (request, body) async {
      final writer = await FakeServer.sse(request, cuttable: true);
      await writer.write('data: 1\n\n');
      await writer.cut();
    };
    final client = SimHttpClient(baseUrl: server.url);
    final response = await client.stream(method: 'GET', path: '/api/stream');
    await expectLater(response.bytes.toList(), throwsA(isA<ApiNetworkError>()));
  });

  test(
    'desktop cookies persist across requests and clients; clearCookies drops them',
    () async {
      server.handler = (request, body) async {
        if (request.uri.path == '/login') {
          request.response.headers.set(
            'set-cookie',
            'better-auth.session_token=tok.sig; Path=/; HttpOnly; SameSite=Lax',
          );
        }
        await FakeServer.json(request, 200, {});
      };
      final storage = MemoryCookieStorage();
      final client = SimHttpClient(baseUrl: server.url, cookieStorage: storage);
      await client.send(method: 'POST', path: '/login', body: {});
      await client.send(method: 'GET', path: '/session');
      expect(
        server.requests[1].headers['cookie'],
        contains('better-auth.session_token=tok.sig'),
      );

      final again = SimHttpClient(baseUrl: server.url, cookieStorage: storage);
      await again.send(method: 'GET', path: '/session');
      expect(
        server.requests[2].headers['cookie'],
        contains('better-auth.session_token=tok.sig'),
      );

      await again.clearCookies();
      final fresh = SimHttpClient(baseUrl: server.url, cookieStorage: storage);
      await fresh.send(method: 'GET', path: '/session');
      expect(server.requests[3].headers.containsKey('cookie'), isFalse);
    },
  );

  test('the path and query reach the server as serialised', () async {
    server.handler = (request, body) => FakeServer.json(request, 200, {});
    final client = SimHttpClient(baseUrl: server.url);
    await client.send(
      method: 'GET',
      path: '/api/workflows/[id]/state',
      params: {'id': 'wf 1'},
      query: {
        'tags': ['a', 'b'],
        'q': 'x y',
      },
    );
    final request = server.requests.single;
    expect(request.path, '/api/workflows/wf%201/state');
    expect(request.query, {'tags': 'b', 'q': 'x y'});
  });
}
