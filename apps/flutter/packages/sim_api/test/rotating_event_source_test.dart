// Failure modes of RotatingEventSource against a dart:io fake server:
// 1. on `rotate` the current connection stays open until the replacement is
//    open; events from both are delivered; the open reason is `rotation`;
// 2. when opening the replacement fails, the current connection is kept;
// 3. a dropped connection reconnects and resumes with the last event id;
// 4. close() during a rotation closes both connections;
// 5. an HTTP rejection gives up (no retry) and reports the error;
// 6. the rotate frame itself is never delivered as an event.
//
// The server is real (loopback sockets), so every step waits for the
// observable condition it depends on instead of a fixed wall-clock delay:
// fixed delays raced the socket round trips and failed under CPU load.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import 'support/fake_server.dart';

/// Upper bound for one socket round trip under heavy load; only reached
/// when the condition never holds (a real failure).
const Duration _patience = Duration(seconds: 10);

/// Lets anything that should NOT happen (a retry, a third request) surface
/// before the test asserts its absence; well above the 50ms `retryDelay` the sources use.
const Duration _quietPeriod = Duration(milliseconds: 200);

/// Resolves once [condition] holds; fails the test after [_patience].
Future<void> until(bool Function() condition, String what) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > _patience) fail('Timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

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
  }) {
    // A test that fails midway must not leave its source reconnecting into
    // the next test's server (through the reassigned `http`): bind the
    // client now and close the source on teardown.
    final client = http;
    final events = RotatingEventSource(
      retryDelay: retryDelay,
      open: ({required cancelToken, lastEventId}) => client.stream(
        method: 'GET',
        path: '/api/events',
        query: {'from': lastEventId},
        cancelToken: cancelToken,
      ),
    );
    addTearDown(events.close);
    return events;
  }

  /// Opens an SSE response and lists its writer once the `: connected`
  /// flush is done: the client counts as open when the headers arrive,
  /// which is before that flush settles, and a test writing during it
  /// would hit "StreamSink is bound to a stream".
  Future<SseWriter> openWriter(HttpRequest request) async {
    final writer = await FakeServer.sse(request);
    await writer.write(': connected\n\n');
    writers.add(writer);
    return writer;
  }

  test(
    'rotation keeps the current connection until the replacement is open',
    () async {
      server.handler = (request, body) async {
        await openWriter(request);
      };
      final events = source();
      final reasons = <EventSourceOpenReason>[];
      events.opens.listen(reasons.add);
      final received = <NamedSseEvent>[];
      events.events.listen(received.add);
      events.start();

      await until(
        () => reasons.isNotEmpty && writers.isNotEmpty,
        'the initial open',
      );
      expect(reasons, [EventSourceOpenReason.initial]);
      await writers[0].write('event: task_status\ndata: {"n":1}\n\n');
      await writers[0].write('event: rotate\ndata: {}\n\n');
      await until(
        () => reasons.length == 2 && writers.length == 2,
        'the rotation open',
      );
      expect(reasons, [
        EventSourceOpenReason.initial,
        EventSourceOpenReason.rotation,
      ]);
      expect(writers, hasLength(2));
      await writers[1].write('event: task_status\ndata: {"n":2}\n\n');
      await until(() => received.length == 2, 'the second event');
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
    await until(
      () => events.isOpen && writers.isNotEmpty,
      'the initial open',
    );
    await writers[0].write('event: rotate\ndata: {}\n\n');
    await until(() => errors.isNotEmpty, 'the failed replacement');
    expect(errors, hasLength(1));
    expect(events.isOpen, isTrue);
    await writers[0].write('data: {"still":true}\n\n');
    await until(() => received.isNotEmpty, 'an event on the kept connection');
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
    final received = <NamedSseEvent>[];
    events.events.listen(received.add);
    events.start();
    await until(() => reasons.length == 2, 'the reconnect');
    expect(received.single.id, '41');
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
    server.handler = (request, body) async {
      final writer = await openWriter(request);
      if (writers.length == 1) {
        await writer.write('event: rotate\ndata: {}\n\n');
      }
    };
    final events = source()..start();
    await until(() => writers.length == 2, 'the replacement request');
    await events.close();
    expect(events.isClosed, isTrue);
    expect(events.isOpen, isFalse);
    // The dart:io fake server does not observe a client-side close of an
    // idle SSE response, so the client's view is what is asserted: closed,
    // nothing open, and no further connection attempt.
    await Future<void>.delayed(_quietPeriod);
    expect(server.requests, hasLength(2));
  });

  test('an HTTP rejection gives up and reports the error', () async {
    server.handler = (request, body) =>
        FakeServer.json(request, 403, {'error': 'Access denied'});
    final events = source();
    final errors = <Object>[];
    events.errors.listen(errors.add);
    events.start();
    await until(() => errors.isNotEmpty, 'the rejection');
    // No retry follows (one would come after retryDelay).
    await Future<void>.delayed(_quietPeriod);
    expect(errors.single, isA<ApiClientError>());
    expect(server.requests, hasLength(1));
    expect(events.isOpen, isFalse);
    await events.close();
  });
}
