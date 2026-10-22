// Failure modes of ExecutionStreamClient (execute / reconnect / cancel):
// 1. the execution id comes from `X-Execution-Id`, and is null when absent;
// 2. events are typed by `type`, keep `eventId`, and the stream ends at [DONE];
// 3. a 4xx from the execute endpoint becomes ExecutionStreamHttpError with
//    the body's `error` message and the body itself;
// 4. a 202 (`X-Execution-Mode: async`) yields the accepted body and no events;
// 5. a connection cut before a terminal event raises
//    ExecutionStreamInterruptedError carrying the execution id;
// 6. a connection cut after the terminal event is not an error;
// 7. reconnect requests `?from=<eventId>` and replays from there;
// 8. an unknown event type is passed through as UnknownExecutionEvent;
// 9. cancel() closes the stream without an error.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import 'support/fake_server.dart';

void main() {
  late FakeServer server;
  late ExecutionStreamClient client;

  setUp(() async {
    server = await FakeServer.start();
    client = ExecutionStreamClient(SimHttpClient(baseUrl: server.url));
  });

  tearDown(() => server.close());

  Map<String, Object?> event(
    String type,
    int eventId,
    Map<String, Object?> data,
  ) => {
    'type': type,
    'timestamp': 't',
    'executionId': 'exec-1',
    'eventId': eventId,
    'workflowId': 'wf',
    'data': data,
  };

  test('execution id from the header; typed events; ends at [DONE]', () async {
    server.handler = (request, body) async {
      final writer = await FakeServer.sse(
        request,
        headers: {'X-Execution-Id': 'exec-1'},
      );
      await writer.data(event('execution:started', 1, {'startTime': 't0'}));
      await writer.data(
        event('block:started', 2, {
          'blockId': 'b1',
          'blockName': 'Agent',
          'executionOrder': 1,
        }),
      );
      await writer.data(
        event('stream:chunk', 3, {'blockId': 'b1', 'chunk': 'hi'}),
      );
      await writer.data(
        event('execution:completed', 4, {
          'success': true,
          'output': {},
          'duration': 5,
        }),
      );
      await writer.write('data: [DONE]\n\n');
      await writer.data(event('execution:started', 9, {}));
      await writer.close();
    };
    final stream = await client.execute(workflowId: 'wf', body: {'input': {}});
    expect(stream.executionId, 'exec-1');
    expect(server.requests.single.json, {
      'input': <String, Object?>{},
      'stream': true,
    });

    final events = await stream.events.toList();
    expect(events.map((e) => e.eventId), [1, 2, 3, 4]);
    expect(events[0], isA<ExecutionStarted>());
    expect((events[1] as BlockStarted).invocationKey, 'b1:1:::');
    expect((events[2] as StreamChunk).chunk, 'hi');
    expect(events[3].isTerminal, isTrue);
  });

  test('a 4xx becomes ExecutionStreamHttpError with the body', () async {
    server.handler = (request, body) => FakeServer.json(request, 402, {
      'error': 'Usage limit exceeded',
      'limit': 1,
    });
    await expectLater(
      client.execute(workflowId: 'wf'),
      throwsA(
        isA<ExecutionStreamHttpError>()
            .having((e) => e.httpStatus, 'status', 402)
            .having((e) => e.message, 'message', 'Usage limit exceeded')
            .having((e) => e.executionResult?['limit'], 'body', 1),
      ),
    );
  });

  test('a 202 yields the accepted body and no events', () async {
    server.handler = (request, body) => FakeServer.json(
      request,
      202,
      {'executionId': 'exec-9', 'status': 'queued'},
      headers: {'X-Execution-Id': 'exec-9'},
    );
    final stream = await client.execute(
      workflowId: 'wf',
      headers: {executionModeHeader: 'async'},
    );
    expect(stream.executionId, 'exec-9');
    expect(stream.asyncAccepted?['status'], 'queued');
    expect(await stream.events.toList(), isEmpty);
    expect(server.requests.single.headers['x-execution-mode'], 'async');
  });

  test('a cut before the terminal event is an interruption', () async {
    server.handler = (request, body) async {
      final writer = await FakeServer.sse(
        request,
        cuttable: true,
        headers: {'X-Execution-Id': 'exec-1'},
      );
      await writer.data(event('execution:started', 1, {}));
      await writer.cut();
    };
    final stream = await client.execute(workflowId: 'wf');
    final received = <ExecutionStreamEvent>[];
    await expectLater(
      stream.events.forEach(received.add),
      throwsA(
        isA<ExecutionStreamInterruptedError>().having(
          (e) => e.executionId,
          'executionId',
          'exec-1',
        ),
      ),
    );
    expect(received, hasLength(1));
  });

  test('a cut after the terminal event is not an error', () async {
    server.handler = (request, body) async {
      final writer = await FakeServer.sse(request);
      await writer.data(
        event('execution:error', 1, {'error': 'boom', 'duration': 1}),
      );
      await writer.cut();
    };
    final stream = await client.execute(workflowId: 'wf');
    final events = await stream.events.toList();
    expect(events.single, isA<ExecutionError>());
  });

  test('reconnect requests ?from= and replays', () async {
    server.handler = (request, body) async {
      final writer = await FakeServer.sse(request);
      await writer.data(
        event('block:completed', 3, {'blockId': 'b1', 'output': 1}),
      );
      await writer.data(event('execution:completed', 4, {'success': true}));
      await writer.write('data: [DONE]\n\n');
      await writer.close();
    };
    final stream = await client.reconnect(
      workflowId: 'wf',
      executionId: 'exec-1',
      fromEventId: 2,
    );
    final request = server.requests.single;
    expect(request.path, '/api/workflows/wf/executions/exec-1/stream');
    expect(request.query, {'from': '2'});
    final events = await stream.events.toList();
    expect(events.map((e) => e.eventId), [3, 4]);
  });

  test('an unknown event type passes through', () async {
    server.handler = (request, body) async {
      final writer = await FakeServer.sse(request);
      await writer.data(event('execution:future', 1, {}));
      await writer.write('data: [DONE]\n\n');
      await writer.close();
    };
    final stream = await client.execute(workflowId: 'wf');
    final events = await stream.events.toList();
    expect(events.single, isA<UnknownExecutionEvent>());
    expect(events.single.type, 'execution:future');
  });

  test('cancel closes the stream without an error', () async {
    final opened = Completer<void>();
    server.handler = (request, body) async {
      final writer = await FakeServer.sse(request);
      await writer.data(event('execution:started', 1, {}));
      opened.complete();
      await Future<void>.delayed(const Duration(seconds: 5));
      await writer.close();
    };
    final stream = await client.execute(workflowId: 'wf');
    final received = <ExecutionStreamEvent>[];
    final errors = <Object>[];
    final done = Completer<void>();
    final subscription = stream.events.listen(
      received.add,
      onError: errors.add,
      onDone: done.complete,
    );
    await opened.future;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    stream.cancel();
    await subscription.cancel();
    expect(received, hasLength(1));
    expect(errors, isEmpty);
  });
}
