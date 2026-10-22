// Failure modes of MothershipClient over real HTTP (fake loopback server),
// spec chat-engine §3:
// 1. send posts exactly the React body (no `model`, no `clientCapabilities`,
//    `createNewChat = !chatId`, owner exclusive, modelSelection/effort only
//    outside assistant mode, optional fields omitted, not null);
// 2. send exposes `x-mothership-chat-id` and `traceparent` before the body;
// 3. a 409 is read from the body: `activeStreamId`, `chatId`, `error`;
//    other non-2xx keep the status and `error`;
// 4. tail sends `streamId`, `after` and `source=log` only when asked, the
//    traceparent header, reports `x-mothership-stream-replay: log`, and a
//    404 is MothershipStreamGoneError;
// 5. batch sends `batch=true`, parses events, and an invalid event throws
//    MothershipStreamSchemaError; 404 → gone;
// 6. abort posts to `/api/copilot/chat/abort` (not the mothership shim)
//    and reads `settled`; persistStop surfaces `payload.error`;
// 7. tool-permission posts `{decisions:[{toolCallId, decision}]}` with the
//    wire names and reads `applied`;
// 8. stream-status returns null for a finished stream;
// 9. chatEvents delivers `task_status` frames and parses them.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import '../support/fake_server.dart';

Map<String, Object?> envelope(int seq, String type, Map<String, Object?> p) => {
  'v': 1,
  'type': type,
  'seq': seq,
  'ts': '2026-10-22T10:00:00.000Z',
  'stream': {'streamId': 'u1', 'cursor': '$seq'},
  'payload': p,
};

void main() {
  late FakeServer server;
  late SimHttpClient http;
  late MothershipClient client;

  setUp(() async {
    server = await FakeServer.start();
    http = SimHttpClient(baseUrl: server.url);
    client = MothershipClient(http);
  });

  tearDown(() async {
    http.close(force: true);
    await server.close();
  });

  test('send posts the React body and exposes headers', () async {
    server.handler = (request, body) async {
      final sse = await FakeServer.sse(
        request,
        headers: {
          'x-mothership-chat-id': 'chat-9',
          'traceparent':
              '00-0123456789abcdef0123456789abcdef-0123456789abcdef-01',
        },
      );
      await sse.data(envelope(1, 'session', {'kind': 'chat', 'chatId': 'c'}));
      await sse.close();
    };
    final stream = await client.send(
      const MothershipSendRequest(
        message: 'hi',
        userMessageId: 'u1',
        userTimezone: 'UTC',
        workspaceId: 'ws',
        mode: 'agent',
        effort: 'high',
      ),
    );
    expect(stream.chatId, 'chat-9');
    expect(stream.traceId, '0123456789abcdef0123456789abcdef');
    final text = await utf8.decodeStream(stream.bytes);
    expect(text, contains('"kind":"chat"'));
    final sent = server.requests.single;
    expect(sent.method, 'POST');
    expect(sent.path, '/api/mothership/chat');
    expect(sent.json, {
      'message': 'hi',
      'workspaceId': 'ws',
      'userMessageId': 'u1',
      'createNewChat': true,
      'mode': 'agent',
      'userTimezone': 'UTC',
      'effort': 'high',
    });
  });

  test('assistant mode sends no modelSelection/effort/workflowId', () {
    const request = MothershipSendRequest(
      message: 'q',
      userMessageId: 'u',
      userTimezone: 'UTC',
      workspaceId: 'ws',
      chatId: 'c1',
      mode: 'assistant',
      assistantSearchLevel: 'fast',
      workflowId: 'wf',
      modelSelection: {'model': 'gpt-6-astra', 'fastMode': false},
      effort: 'low',
    );
    final json = request.toJson();
    expect(json['createNewChat'], isFalse);
    expect(json['chatId'], 'c1');
    expect(json['assistantSearchLevel'], 'fast');
    expect(
      json.keys,
      isNot(containsAll(['modelSelection', 'effort', 'workflowId'])),
    );
    expect(json.containsKey('model'), isFalse);
    expect(json.containsKey('clientCapabilities'), isFalse);
  });

  test('409 is read from the body', () async {
    server.handler = (request, body) => FakeServer.json(request, 409, {
      'error': 'A response is already in progress for this chat.',
      'activeStreamId': 'other',
    });
    await expectLater(
      client.send(
        const MothershipSendRequest(
          message: 'x',
          userMessageId: 'u2',
          userTimezone: 'UTC',
          workspaceId: 'ws',
          chatId: 'c',
        ),
      ),
      throwsA(
        isA<MothershipSendRejected>()
            .having((e) => e.isConflict, 'conflict', isTrue)
            .having((e) => e.activeStreamId, 'activeStreamId', 'other'),
      ),
    );
    server.handler = (request, body) => FakeServer.json(request, 429, {});
    await expectLater(
      client.send(
        const MothershipSendRequest(
          message: 'x',
          userMessageId: 'u3',
          userTimezone: 'UTC',
          workspaceId: 'ws',
        ),
      ),
      throwsA(
        isA<MothershipSendRejected>().having(
          (e) => e.displayMessage,
          'message',
          'Request failed: 429',
        ),
      ),
    );
  });

  test('tail query, log header and 404', () async {
    server.handler = (request, body) async {
      final sse = await FakeServer.sse(
        request,
        headers: {'x-mothership-stream-replay': 'log'},
      );
      await sse.write(': accepted\n\n');
      await sse.close();
    };
    final tail = await client.tail(
      'u1',
      '7',
      fromLog: true,
      traceparent: 'tp',
    );
    expect(tail.logResynced, isTrue);
    await tail.bytes.drain<void>();
    final sent = server.requests.single;
    expect(sent.query, {'streamId': 'u1', 'after': '7', 'source': 'log'});
    expect(sent.headers['traceparent'], 'tp');

    server.handler = (request, body) =>
        FakeServer.json(request, 404, {'error': 'Stream not found'});
    await expectLater(
      client.tail('u1', '0'),
      throwsA(isA<MothershipStreamGoneError>()),
    );
    expect(server.requests.last.query.containsKey('source'), isFalse);
  });

  test('batch parses, validates and maps 404', () async {
    server.handler = (request, body) => FakeServer.json(request, 200, {
      'success': true,
      'status': 'active',
      'events': [
        {
          'eventId': 4,
          'streamId': 'u1',
          'event': envelope(4, 'text', {'channel': 'assistant', 'text': 'a'}),
        },
      ],
      'previewSessions': <Object?>[],
    });
    final batch = await client.batch('u1', '3');
    expect(server.requests.last.query['batch'], 'true');
    expect(batch.events.single.eventId, 4);
    expect(batch.isTerminal, isFalse);

    server.handler = (request, body) => FakeServer.json(request, 200, {
      'success': true,
      'status': 'active',
      'events': [
        {
          'eventId': 5,
          'streamId': 'u1',
          'event': envelope(5, 'bogus', {}),
        },
      ],
    });
    await expectLater(
      client.batch('u1', '4'),
      throwsA(
        isA<MothershipStreamSchemaError>().having(
          (e) => e.message,
          'message',
          contains('Reconnect batch event 1.'),
        ),
      ),
    );

    server.handler = (request, body) => FakeServer.json(request, 404, {});
    await expectLater(
      client.batch('u1', '0'),
      throwsA(isA<MothershipStreamGoneError>()),
    );
  });

  test('abort and stop-persist', () async {
    server.handler = (request, body) => request.uri.path.endsWith('/abort')
        ? FakeServer.json(request, 200, {'aborted': true, 'settled': false})
        : FakeServer.json(request, 500, {'error': 'boom'});
    final result = await client.abort(
      streamId: 's',
      workspaceId: 'ws',
      chatId: 'c',
    );
    expect(result.settled, isFalse);
    expect(server.requests.last.path, '/api/copilot/chat/abort');
    expect(server.requests.last.json, {
      'streamId': 's',
      'workspaceId': 'ws',
      'chatId': 'c',
    });
    await expectLater(
      client.persistStop(chatId: 'c', streamId: 's'),
      throwsA(
        isA<MothershipStopFailed>().having((e) => e.message, 'm', 'boom'),
      ),
    );
    expect(server.requests.last.json, {'chatId': 'c', 'streamId': 's'});
  });

  test('tool permission body and results', () async {
    server.handler = (request, body) => FakeServer.json(request, 200, {
      'success': true,
      'results': [
        {'toolCallId': 't1', 'decision': 'allow_chat', 'applied': false},
      ],
    });
    final results = await client.decideToolPermissions({
      't1': ToolPermissionDecision.allowChat,
    });
    expect(results.single.applied, isFalse);
    expect(server.requests.last.json, {
      'decisions': [
        {'toolCallId': 't1', 'decision': 'allow_chat'},
      ],
    });
  });

  test('stream-status null', () async {
    server.handler = (request, body) => FakeServer.json(request, 200, {
      'success': true,
      'activeStreamId': null,
    });
    expect(await client.streamStatus('c'), isNull);
    expect(server.requests.last.path, '/api/mothership/chats/c/stream-status');
  });

  test('chatEvents delivers task_status', () async {
    final writers = <SseWriter>[];
    server.handler = (request, body) async {
      final sse = await FakeServer.sse(request);
      writers.add(sse);
      await sse.write(': connected\n\n');
      await sse.write(
        'event: task_status\ndata: ${jsonEncode({'chatId': 'c', 'type': 'started', 'streamId': 's', 'timestamp': 1})}\n\n',
      );
    };
    final source = client.chatEvents(workspaceId: 'ws');
    final first = source.events.first;
    source.start();
    final event = await first.timeout(const Duration(seconds: 5));
    expect(event.name, 'task_status');
    final parsed = TaskStatusEvent.parse(event.json);
    expect(parsed?.type, TaskStatusType.started);
    expect(server.requests.single.query, {'workspaceId': 'ws'});
    await source.close();
    for (final w in writers) {
      try {
        await w.close();
      } on Object {
        // The client already dropped the connection.
      }
    }
  });
}
