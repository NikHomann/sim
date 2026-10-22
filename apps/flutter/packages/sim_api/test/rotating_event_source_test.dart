// Failure modes of RotatingEventSource against a dart:io fake server:
// 1. on `rotate` the current connection stays open until the replacement is
//    open; events from both are delivered; the open reason is `rotation`;
// 2. when opening the replacement fails, the current connection is kept;
// 3. a dropped connection reconnects and resumes with the last event id;
// 4. close() during a rotation closes both connections;
// 5. an HTTP rejection gives up (no retry) and reports the error;
// 6. the rotate frame itself is never delivered as an event.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import 'support/fake_server.dart';

void main() {
  late FakeServer server;
  late SimHttpClient http;
  final writers = <SseWriter>[];

  setUp(() async {
    server = await FakeServer.start();
    http = SimHttpClient(baseUrl: server.url);
    writers.clear();
  });

  tearDown(() => server.close());

  RotatingEventSource source({
    Duration retryDelay = const Duration(milliseconds: 50),
  }) => RotatingEventSource(
    retryDelay: retryDelay,
    open: ({required cancelToken, lastEventId}) => http.stream(
      method: 'GET',
      path: '/api/events',
      query: {'from': lastEventId},
      cancelToken: cancelToken,
    ),
  );

  Future<SseWriter> openWriter(HttpRequest request) async {
    final writer = await FakeServer.sse(request);
    writers.add(writer);
    await writer.write(': connected\n\n');
    return writer;
  }

  Future<T> next<T>(Stream<T> stream) =>
      stream.first.timeout(const Duration(seconds: 5));

  test(
    'rotation keeps the current connection until the replacement is open',
    () async {
      final secondOpened = Completer<void>();
      server.handler = (request, body) async {
        await openWriter(request);
        if (writers.length == 2) secondOpened.complete();
      };
      final events = source();
      final reasons = <EventSourceOpenReason>[];
      events.opens.listen(reasons.add);
      final received = <NamedSseEvent>[];
      events.events.listen(received.add);
      events.start();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(reasons, [EventSourceOpenReason.initial]);
      await writers[0].write('event: task_status\ndata: {"n":1}\n\n');
      await writers[0].write('event: rotate\ndata: {}\n\n');
      await secondOpened.future;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(reasons, [
        EventSourceOpenReason.initial,
        EventSourceOpenReason.rotation,
      ]);
      await writers[1].write('event: task_status\ndata: {"n":2}\n\n');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(received.map((e) => e.json), [
        {'n': 1},
        {'n': 2},
      ]);
      expect(received.every((e) => e.name == 'task_status'), isTrue);
      await events.close();
    },
  );

  test('a failed replacement keeps the current connection', () async {
    server.handler = (request, body) async {
      if (server.requests.length == 2) {
        await FakeServer.json(request, 500, {'error': 'no'});
        return;
      }
      await openWriter(request);
    };
    final events = source();
    final errors = <Object>[];
    events.errors.listen(errors.add);
    final received = <NamedSseEvent>[];
    events.events.listen(received.add);
    events.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await writers[0].write('event: rotate\ndata: {}\n\n');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(errors, hasLength(1));
    expect(events.isOpen, isTrue);
    await writers[0].write('data: {"still":true}\n\n');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received.single.json, {'still': true});
    expect(server.requests, hasLength(2));
    await events.close();
  });

  test('a dropped connection reconnects with the last event id', () async {
    server.handler = (request, body) async {
      final writer = await openWriter(request);
      if (writers.length == 1) {
        await writer.write('id: 41\ndata: {"n":41}\n\n');
        await writer.cut();
      }
    };
    final events = source();
    final reasons = <EventSourceOpenReason>[];
    events.opens.listen(reasons.add);
    events.start();
    await next(events.events);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(server.requests, hasLength(2));
    expect(server.requests[0].query, isEmpty);
    expect(server.requests[1].query, {'from': '41'});
    expect(reasons, [
      EventSourceOpenReason.initial,
      EventSourceOpenReason.reconnect,
    ]);
    await events.close();
  });

  test('close() during a rotation closes both connections', () async {
    final closed = <int>[];
    server.handler = (request, body) async {
      final index = writers.length;
      final writer = await openWriter(request);
      unawaited(
        request.response.done.then(
          (_) => closed.add(index),
          onError: (_) => closed.add(index),
        ),
      );
      if (index == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await writer.write('event: rotate\ndata: {}\n\n');
      }
    };
    final events = source()..start();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(writers, hasLength(2));
    await events.close();
    expect(events.isClosed, isTrue);
    expect(events.isOpen, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.requests, hasLength(2));
  });

  test('an HTTP rejection gives up and reports the error', () async {
    server.handler = (request, body) =>
        FakeServer.json(request, 403, {'error': 'Access denied'});
    final events = source();
    final errors = <Object>[];
    events.errors.listen(errors.add);
    events.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(errors.single, isA<ApiClientError>());
    expect(server.requests, hasLength(1));
    expect(events.isOpen, isFalse);
    await events.close();
  });
}
