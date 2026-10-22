// Failure modes of ChatSessionCubit (spec chat-engine §4, §6 F1–F22),
// against a scripted client and a fake clock. Each failure mode is one test
// named after it:
// - send: optimistic pair, exact body, chat adoption from
//   `x-mothership-chat-id` with the route callback, detail seeded;
// - F1 network cut / 45 s idle → reconnect from the cursor → finalize;
// - F2 tail ends without terminal → batch → seed → tail again, 1 s pause on
//   an empty batch;
// - F3 `x-mothership-stream-replay: log` → cursor 0, rebuild, `source=log`;
// - F4 duplicate envelopes after reconnect are dropped;
// - F5 stream gone (404) → finalize without error;
// - F6 schema-invalid frame → error message, finalize error, no reconnect;
// - F7 stop during a tool call → local cancel, abort + stop-persist POSTs;
// - F8 abort not settled → retried once → "still shutting down" error;
// - F9 permission skip → `skipped` row, the turn continues;
// - F10 permission POST 404/error → covered in stores_test (decide);
// - F11 409 busy → rollback, queue retry, attach to the running turn;
// - F12 409 duplicate → batch check → reconnect own stream;
// - F13 other 4xx → body error, finalize(error), no retry;
// - F14 no response → rollback; online → retry, offline → hold;
// - F15 worker error mid-turn: inline tag; complete{complete} after an
//   error frame is a success verdict, complete{error} an error;
// - F16 chat deleted elsewhere → reload 404 → history error string;
// - F17 second tab: hydration with `activeStreamId` tails the stream;
// - F18 reconnect exhausted after 10 attempts → error, 30 s recheck;
// - F19 finished but unsaved transcript → stream-status polling;
// - F20 unmount mid-POST → withdrawn, handed off under the same id;
// - F21 usage limit → `<usage_upgrade>` text + complete;
// - F22 worker key missing → error tag + complete{error}, untitled;
// - queue: a send while streaming is queued and drains after finalize;
// - switching chats mid-stream detaches without a server cancel;
// - browser return re-attaches to the running stream.

import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/engine.dart';

import 'support/fake_client.dart';
import 'support/fixtures.dart';

class Harness {
  Harness({
    String? chatId,
    this.online = true,
    Map<String, MothershipChatHistory> histories = const {},
  }) {
    client.histories.addAll(histories);
    cubit = build(chatId: chatId);
    cubit.stream.listen((s) {
      final live = s.messages.where((m) => m.isLive).lastOrNull;
      if (live != null) this.live = live;
    });
  }

  /// The last live assistant message any state showed (the overlay goes
  /// once the refetched transcript replaces it).
  ChatMessage? live;

  final client = FakeMothershipClient();
  final queries = QueryClient(now: () => clock.now());
  final storages = ChatStorages.memory();
  late final queue = MothershipQueueStore(storages.session);
  late final effort = MothershipEffortStore(storages.local, plan: false);
  late final planEffort = MothershipEffortStore(storages.local, plan: true);
  late final handoffs = SendHandoffStore(
    session: storages.session,
    local: storages.local,
    nowMs: () => clock.now().millisecondsSinceEpoch,
  );
  final returns = StreamController<BrowserReturnReason>.broadcast();
  final routes = <String>[];
  final ended = <String>[];
  bool online;
  var _ids = 0;
  late ChatSessionCubit cubit;

  ChatSessionCubit build({String? chatId}) => ChatSessionCubit(
    client: client,
    queryClient: queries,
    queueStore: queue,
    effortStore: effort,
    planEffortStore: planEffort,
    handoffs: handoffs,
    workspaceId: 'ws',
    chatId: chatId,
    markChatRead: false,
    idGenerator: () => 'u-${_ids++}',
    isOnline: () => online,
    timeZone: () => 'Europe/Berlin',
    browserReturns: returns.stream,
    onlineEvents: const Stream.empty(),
    random: Random(7),
    callbacks: ChatSessionCallbacks(
      onChatResolved: (id, url) => routes.add(url),
      onStreamEnd: (id, _) => ended.add(id),
    ),
  );

  ChatSessionState get state => cubit.state;

  List<ToolCallInfo> get tools => [
    for (final b in live?.contentBlocks ?? const <ContentBlock>[])
      if (b.toolCall != null) b.toolCall!,
  ];
}

const hi = SendPayload(content: 'hi');

/// The rendered transcript as `role:content` rows.
List<String> transcript(Harness h) => [
  for (final m in h.state.messages) '${m.role.name}:${m.content}',
];

void main() {
  test('send: optimistic pair, React body, new chat adoption', () {
    fakeAsync((async) {
      final h = Harness();
      final sse = FakeSse();
      h.client.answerSend(sse, chatId: 'chat-1');
      h.client.histories['chat-1'] = const MothershipChatHistory(
        id: 'chat-1',
        messages: [],
        activeStreamId: 'u-1',
      );
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      expect(h.state.isSending, isTrue);
      expect(h.state.messages.map((m) => m.id), ['u-1', 'live-assistant:u-1']);
      final body = h.client.sends.single.toJson();
      expect(body, {
        'message': 'hi',
        'workspaceId': 'ws',
        'userMessageId': 'u-1',
        'createNewChat': true,
        'mode': 'agent',
        'userTimezone': 'Europe/Berlin',
      });
      expect(h.state.chatId, 'chat-1');
      expect(h.routes, ['/workspace/ws/chat/chat-1']);
      expect(h.queue.queues.containsKey('pending::u-0'), isFalse);
      sse.lines(loadFixture('plain_text_answer').envelopes);
      async.elapse(const Duration(milliseconds: 100));
      expect(h.state.isSending, isFalse);
      expect(h.live?.content, 'Hello there.');
      expect(h.ended, ['chat-1']);
      expect(h.state.error, isNull);
    });
  });

  test('F1 45 s of silence reconnects from the last cursor', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post
        ..envelope(text(1, 'Hello'))
        ..envelope(text(2, ' wor'));
      async.elapse(const Duration(seconds: 30));
      post.comment();
      async.elapse(const Duration(seconds: 30));
      expect(h.client.calls.where((c) => c.startsWith('batch')), isEmpty);
      final tail = FakeSse();
      h.client
        ..onBatch = ((id, after, {required fromLog}) async => batchOf([]))
        ..onTail = (id, after, {required fromLog, token}) async {
          tail.bindCancel(token);
          return MothershipTailStream(bytes: tail.bytes);
        };
      async.elapse(const Duration(seconds: 16));
      expect(h.client.calls, contains('batch u-1 after=2'));
      expect(h.client.calls, contains('tail u-1 after=2'));
      expect(h.state.isReconnecting, isFalse);
      tail
        ..envelope(text(3, 'ld'))
        ..envelope(complete(4));
      async.elapse(const Duration(milliseconds: 100));
      expect(h.live?.content, 'Hello world');
      expect(h.state.isSending, isFalse);
      expect(h.state.error, isNull);
    });
  });

  test('F2 tail without terminal → batch → seed; 1 s pause on empty', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post.envelope(text(1, 'a'));
      var tails = 0;
      var batches = 0;
      h.client
        ..onBatch = (id, after, {required fromLog}) async {
          batches++;
          if (batches == 3) {
            return batchOf([text(2, 'b'), complete(3)], status: 'complete');
          }
          return batchOf([]);
        }
        ..onTail = (id, after, {required fromLog, token}) async {
          tails++;
          final tail = FakeSse()..bindCancel(token);
          unawaited(tail.end());
          return MothershipTailStream(bytes: tail.bytes);
        };
      unawaited(post.end());
      async.flushMicrotasks();
      // resumeOrFinalize batch (1), tail (1) ends, batch (2) empty → 1 s.
      expect(tails, 1);
      expect(batches, 2);
      async.elapse(const Duration(milliseconds: 999));
      expect(tails, 1);
      async
        ..elapse(const Duration(milliseconds: 1))
        ..flushMicrotasks();
      expect(tails, 2);
      async.elapse(const Duration(seconds: 2));
      expect(h.live?.content, 'ab');
      expect(h.state.isSending, isFalse);
    });
  });

  test('F3 log resync resets the cursor and reads from the log', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post
        ..envelope(text(5, 'stale '))
        ..envelope(text(6, 'ring'));
      final tail = FakeSse();
      h.client
        ..onBatch = ((id, after, {required fromLog}) async => batchOf([]))
        ..onTail = (id, after, {required fromLog, token}) async {
          tail.bindCancel(token);
          return MothershipTailStream(bytes: tail.bytes, logResynced: true);
        };
      post.cut();
      async.flushMicrotasks();
      expect(h.client.calls, contains('tail u-1 after=6'));
      tail
        ..envelope(text(1, 'Rebuilt '))
        ..envelope(text(2, 'answer'))
        ..envelope(complete(3));
      async.elapse(const Duration(milliseconds: 100));
      expect(h.live?.content, 'Rebuilt answer');
      expect(h.state.isSending, isFalse);
    });
  });

  test('F4 duplicate envelopes after reconnect are dropped', () {
    fakeAsync((async) {
      final fixture = loadFixture('reconnect_duplicate_seq');
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post.lines(fixture.postEnvelopes);
      final tail = FakeSse();
      h.client
        ..onBatch = ((id, after, {required fromLog}) async => batchOf([]))
        ..onTail = (id, after, {required fromLog, token}) async {
          tail.bindCancel(token);
          return MothershipTailStream(bytes: tail.bytes);
        };
      post.cut();
      async.flushMicrotasks();
      expect(h.client.calls, contains('tail u-1 after=3'));
      tail.lines(fixture.tailEnvelopes);
      async.elapse(const Duration(milliseconds: 100));
      expect(h.live?.content, 'Part one. Part two. Part three.');
    });
  });

  test('F5 stream gone finalizes without an error', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      // No batch/tail handlers: both answer 404.
      post
        ..envelope(text(1, 'a'))
        ..cut();
      async.elapse(const Duration(seconds: 1));
      expect(h.state.isSending, isFalse);
      expect(h.state.error, isNull);
      expect(h.client.calls.where((c) => c.startsWith('tail')), isEmpty);
    });
  });

  test('F6 a schema-invalid frame errors without reconnecting', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post
        ..envelope(text(1, 'a'))
        ..envelope(envelope(2, 'mystery', {}));
      async.elapse(const Duration(seconds: 1));
      expect(h.state.isSending, isFalse);
      expect(
        h.state.error,
        startsWith('Client stream schema enforcement failed. Live SSE event.'),
      );
      expect(h.client.calls.where((c) => c.startsWith('batch')), isEmpty);
    });
  });

  test('F7 stop during a tool call', () {
    fakeAsync((async) {
      final fixture = loadFixture('stop_mid_stream');
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post, traceparent: '00-${'a' * 32}-${'b' * 16}-01');
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post.lines(fixture.postEnvelopes.take(3));
      async.elapse(const Duration(milliseconds: 100));
      expect(h.tools.single.status, ToolCallStatus.executing);
      // The server copy the stop invalidation refetches (after the
      // stop-persist POST) replaces the overlay.
      h.client.histories['chat-1'] = const MothershipChatHistory(
        id: 'chat-1',
        messages: [
          PersistedMessage(id: 'u-1', role: 'user', content: 'hi'),
          PersistedMessage(
            id: 'a-1',
            role: 'assistant',
            content: 'Working on it.',
            contentBlocks: [
              PersistedContentBlock(
                type: 'complete',
                raw: {'type': 'complete', 'status': 'cancelled'},
              ),
            ],
          ),
        ],
      );
      Object? stopError;
      unawaited(h.cubit.stop().catchError((Object e) => stopError = e));
      async.flushMicrotasks();
      expect(h.state.isSending, isFalse);
      expect(post.cancelled, isTrue);
      expect(h.tools.single.status, ToolCallStatus.cancelled);
      expect(h.tools.single.displayTitle, 'Stopped by user');
      expect(h.live?.contentBlocks?.last.type, ContentBlockType.stopped);
      expect(transcript(h), ['user:hi', 'assistant:Working on it.']);
      expect(
        h.state.messages.last.contentBlocks?.last.type,
        ContentBlockType.stopped,
      );
      async.elapse(const Duration(seconds: 1));
      expect(transcript(h), ['user:hi', 'assistant:Working on it.']);
      expect(h.state.messages.map((m) => m.id), ['u-1', 'a-1']);
      expect(stopError, isNull);
      expect(h.client.aborts.single, {
        'streamId': 'u-1',
        'workspaceId': 'ws',
        'chatId': 'chat-1',
      });
      expect(h.client.stops.single, {
        'chatId': 'chat-1',
        'streamId': 'u-1',
        'requestId': 'req-1',
      });
    });
  });

  test('F8 an unsettled abort is retried once, then fails', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client
        ..answerSend(post)
        ..onAbort = () async =>
            const MothershipAbortResult(aborted: true, settled: false);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post.envelope(text(1, 'a'));
      Object? stopError;
      unawaited(h.cubit.stop().catchError((Object e) => stopError = e));
      async.elapse(const Duration(seconds: 1));
      expect(h.client.aborts, hasLength(2));
      expect(stopError, isA<StateError>());
      expect(h.state.error, 'Previous response is still shutting down.');
    });
  });

  test('F9 a skipped permission prompt settles as skipped', () {
    fakeAsync((async) {
      final lines = loadFixture('permission_requested_then_allowed').envelopes;
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post.lines(lines.take(2));
      async.elapse(const Duration(milliseconds: 100));
      expect(h.tools.single.status, ToolCallStatus.awaitingApproval);
      unawaited(
        h.cubit.decideToolPermission(['t-perm'], ToolPermissionDecision.skip),
      );
      async.flushMicrotasks();
      expect(h.client.calls, contains('permission t-perm=skip'));
      post
        ..envelope(
          envelope(3, 'tool', {
            'phase': 'result',
            'toolCallId': 't-perm',
            'toolName': 'delete_workflow',
            'success': true,
            'status': 'skipped',
            'output': {'skipped': true, 'reason': 'user_declined'},
          }),
        )
        ..envelope(text(4, 'Skipped.'))
        ..envelope(complete(5));
      async.elapse(const Duration(milliseconds: 100));
      expect(h.tools.single.status, ToolCallStatus.skipped);
      expect(h.state.isSending, isFalse);
    });
  });

  test('F11 a busy 409 re-queues with a retry and attaches', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final http = loadFixture('busy_409').directive(r'$http')!.value! as Map;
      h.client.onSend = (request, token) async =>
          throw MothershipSendRejected.fromApiError(
            ApiClientError.fromResponse(
              status: http['status']! as int,
              body: http['body'],
            ),
          );
      final other = FakeSse();
      h.client
        ..onHistory = ((id) async => const MothershipChatHistory(
          id: 'chat-1',
          messages: [],
          activeStreamId: 'other-stream',
        ))
        ..onBatch = ((id, after, {required fromLog}) async => batchOf([]))
        ..onTail = (id, after, {required fromLog, token}) async {
          other.bindCancel(token);
          return MothershipTailStream(bytes: other.bytes);
        };
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      expect(h.state.messages, isEmpty);
      final queued = h.queue.queue('chat-1').single;
      expect(queued.resumeUserMessageId, 'u-1');
      expect(queued.retry?.attempt, 1);
      expect(queued.admissionUnknown, isFalse);
      expect(h.client.calls, contains('tail other-stream after=0'));
      expect(h.state.isSending, isTrue);
      expect(h.state.streamId, isNotNull);
      // The other turn ends; the queued message then drains under its id.
      final retry = FakeSse();
      h.client
        ..onHistory = ((id) async =>
            const MothershipChatHistory(id: 'chat-1', messages: []))
        ..answerSend(retry);
      other.envelope(complete(1, streamId: 'other-stream'));
      async.elapse(const Duration(seconds: 3));
      expect(h.client.sends.last.userMessageId, 'u-1');
      expect(h.queue.queue('chat-1'), isEmpty);
    });
  });

  test('F12 a duplicate 409 reconnects to its own stream', () {
    fakeAsync((async) {
      final h = Harness();
      h.client.onSend = (request, token) async => throw MothershipSendRejected(
        status: 409,
        error: 'This message was already sent.',
        activeStreamId: request.userMessageId,
        chatId: 'chat-9',
      );
      h.client.histories['chat-9'] = const MothershipChatHistory(
        id: 'chat-9',
        messages: [],
      );
      final tail = FakeSse();
      h.client
        ..onBatch = ((id, after, {required fromLog}) async =>
            batchOf([text(1, 'dup ')]))
        ..onTail = (id, after, {required fromLog, token}) async {
          tail.bindCancel(token);
          return MothershipTailStream(bytes: tail.bytes);
        };
      unawaited(h.cubit.sendMessage(hi, resumeUserMessageId: 'u-1'));
      async.flushMicrotasks();
      expect(h.state.chatId, 'chat-9');
      expect(h.client.calls, contains('tail u-1 after=1'));
      tail
        ..envelope(text(2, 'answer'))
        ..envelope(complete(3));
      async.elapse(const Duration(milliseconds: 100));
      expect(h.live?.content, 'dup answer');
      expect(h.state.isSending, isFalse);
    });
  });

  test('F13 another 4xx surfaces the body error without retry', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      h.client.onSend = (request, token) async =>
          throw const MothershipSendRejected(
            status: 403,
            error: 'Workspace access denied',
          );
      unawaited(h.cubit.sendMessage(hi));
      async.elapse(const Duration(seconds: 1));
      expect(h.state.error, 'Workspace access denied');
      expect(h.state.isSending, isFalse);
      expect(h.client.sends, hasLength(1));
      expect(h.queue.queue('chat-1'), isEmpty);
    });
  });

  test('F14 no response: online retries, offline holds', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      h.client.onSend = (request, token) async =>
          throw const ApiNetworkError('connection refused');
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      expect(h.state.messages, isEmpty);
      expect(
        h.state.error,
        'Message not sent: Sim could not be reached. Retrying.',
      );
      final online = h.queue.queue('chat-1').single;
      expect(online.retry?.attempt, 1);
      expect(online.resumeUserMessageId, 'u-1');
      expect(online.admissionUnknown, isTrue);

      h.queue.reset();
      h.online = false;
      unawaited(h.cubit.sendMessage(const SendPayload(content: 'later')));
      async.flushMicrotasks();
      expect(
        h.state.error,
        'Message not sent: Sim could not be reached. It will send when you are back online.',
      );
      expect(h.queue.queue('chat-1').single.hold, QueueHold.online);
    });
  });

  test('F15 verdict: complete{complete} after an error frame succeeds', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post
        ..envelope(text(1, 'Partial'))
        ..envelope(envelope(2, 'error', {'message': 'subagent hiccup'}))
        ..envelope(complete(3));
      async.elapse(const Duration(milliseconds: 100));
      expect(h.live?.content, contains('<mothership-error>'));
      expect(h.ended, ['chat-1']);
      expect(h.state.isSending, isFalse);
    });
  });

  test('F16 a deleted chat shows the history error', () {
    fakeAsync((async) {
      final h = Harness(chatId: 'gone');
      async.flushMicrotasks();
      expect(h.state.historyStatus, ChatHistoryStatus.error);
      expect(h.state.error, chatHistoryErrorMessage);
    });
  });

  test('F17 a second tab tails the running stream on load', () {
    fakeAsync((async) {
      final tail = FakeSse();
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(
            id: 'chat-1',
            messages: [PersistedMessage(id: 's-9', role: 'user', content: 'q')],
            activeStreamId: 's-9',
          ),
        },
      );
      h.client
        ..onBatch = ((id, after, {required fromLog}) async =>
            batchOf([text(1, 'Seen ', streamId: 's-9')]))
        ..onTail = (id, after, {required fromLog, token}) async {
          tail.bindCancel(token);
          return MothershipTailStream(bytes: tail.bytes);
        };
      async.flushMicrotasks();
      expect(h.client.calls, contains('batch s-9 after=0'));
      expect(h.client.calls, contains('tail s-9 after=1'));
      expect(h.state.isSending, isTrue);
      tail
        ..envelope(text(2, 'live', streamId: 's-9'))
        ..envelope(complete(3, streamId: 's-9'));
      async.elapse(const Duration(milliseconds: 100));
      expect(h.state.messages.map((m) => m.id), ['s-9', 'live-assistant:s-9']);
      expect(h.live?.content, 'Seen live');
      expect(h.state.isSending, isFalse);
    });
  });

  test('F18 reconnect exhausted surfaces the tail error and rechecks', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(
            id: 'chat-1',
            messages: [],
            activeStreamId: 's-1',
          ),
        },
      );
      h.client.onBatch = (id, after, {required fromLog}) async =>
          throw const ApiNetworkError('offline');
      async.flushMicrotasks();
      expect(h.state.isReconnecting, isTrue);
      // 1+2+4+8+16+30·5 s of backoff across 10 retries.
      async.elapse(const Duration(seconds: 181));
      final batches = h.client.calls.where((c) => c.startsWith('batch')).length;
      expect(batches, 11);
      expect(h.state.error, reconnectTailError);
      expect(h.state.isSending, isFalse);
      // streamTerminal:false keeps the stream recoverable: the 30 s recheck
      // reads the chat again and re-attaches.
      final historyReads = h.client.calls
          .where((c) => c == 'history chat-1')
          .length;
      h.client.onBatch = (id, after, {required fromLog}) async => batchOf([
        text(1, 'late', streamId: 's-1'),
        complete(2, streamId: 's-1'),
      ], status: 'complete');
      async.elapse(const Duration(seconds: 30));
      expect(
        h.client.calls.where((c) => c == 'history chat-1').length,
        greaterThan(historyReads),
      );
      expect(h.live?.content, 'late');
    });
  });

  test('F19 an unsaved finished turn polls stream-status', () {
    fakeAsync((async) {
      final h = Harness(chatId: 'chat-1');
      h.client
        ..onHistory = ((id) async =>
            const MothershipChatHistory(id: 'chat-1', messages: []))
        ..onStreamStatus = (id) async => 'u-1';
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      h.client.onHistory = (id) async => const MothershipChatHistory(
        id: 'chat-1',
        messages: [],
        activeStreamId: 'u-1',
      );
      post.lines(loadFixture('plain_text_answer').envelopes);
      async.elapse(const Duration(seconds: 3));
      expect(
        h.client.calls.where((c) => c == 'stream-status chat-1').length,
        greaterThanOrEqualTo(2),
      );
      h.client
        ..onStreamStatus = ((id) async => null)
        ..onHistory = (id) async => const MothershipChatHistory(
          id: 'chat-1',
          messages: [
            PersistedMessage(id: 'u-1', role: 'user', content: 'hi'),
            PersistedMessage(
              id: 'a-1',
              role: 'assistant',
              content: 'Hello there.',
            ),
          ],
        );
      async.elapse(const Duration(seconds: 6));
      expect(h.state.messages.map((m) => m.id), ['u-1', 'a-1']);
      final polls = h.client.calls.length;
      async.elapse(const Duration(seconds: 30));
      expect(h.client.calls.length, polls);
    });
  });

  test('F20 unmount mid-POST hands the send off under the same id', () {
    fakeAsync((async) {
      final h = Harness();
      final pending = Completer<MothershipSendStream>();
      h.client.onSend = (request, token) {
        unawaited(
          token!.whenCancel.then((_) {
            if (!pending.isCompleted) {
              pending.completeError(const ApiCancelledError('unmount'));
            }
          }),
        );
        return pending.future;
      };
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      unawaited(h.cubit.close());
      async.flushMicrotasks();
      final handoff = h.handoffs.consumeHandoff(workspaceId: 'ws');
      expect(handoff?.message, 'hi');
      expect(handoff?.resumeUserMessageId, 'u-1');
    });
  });

  test('F21 a usage limit arrives as text and completes', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post
        ..envelope(
          text(
            1,
            '<usage_upgrade>{"reason":"limit","action":"upgrade_plan","message":"Out of credits"}</usage_upgrade>',
          ),
        )
        ..envelope(complete(2));
      async.elapse(const Duration(milliseconds: 100));
      final segments = parseSpecialTags(h.live!.content);
      expect((segments.single as SpecialTagSegment).name, 'usage_upgrade');
      expect(h.state.error, isNull);
    });
  });

  test('F22 a missing worker key: error tag, error verdict, untitled', () {
    fakeAsync((async) {
      final h = Harness();
      final post = FakeSse();
      h.client
        ..answerSend(post, chatId: 'chat-1')
        ..histories['chat-1'] = const MothershipChatHistory(
          id: 'chat-1',
          messages: [],
          activeStreamId: 'u-1',
        );
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post.lines(loadFixture('error_after_session').envelopes);
      async.elapse(const Duration(milliseconds: 100));
      expect(h.state.isSending, isFalse);
      expect(
        h.state.error,
        'The agent service is temporarily unavailable. Please try again.',
      );
      final tag = parseSpecialTags(h.live!.content).single;
      expect((tag as SpecialTagSegment).name, 'mothership-error');
      expect(h.state.title, isNull);
      expect(h.ended, isEmpty);
    });
  });

  test('a send while streaming is queued and drains after finalize', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final first = FakeSse();
      h.client.answerSend(first);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      unawaited(h.cubit.sendMessage(const SendPayload(content: 'next')));
      async.flushMicrotasks();
      expect(h.state.queue.single.content, 'next');
      expect(h.client.sends, hasLength(1));
      final second = FakeSse();
      h.client.answerSend(second);
      // The server persists the first turn as it ends.
      h.client.histories['chat-1'] = const MothershipChatHistory(
        id: 'chat-1',
        messages: [
          PersistedMessage(id: 'u-1', role: 'user', content: 'hi'),
          PersistedMessage(
            id: 'a-1',
            role: 'assistant',
            content: 'Hello there.',
          ),
        ],
      );
      first.lines(loadFixture('plain_text_answer').envelopes);
      async.elapse(const Duration(seconds: 1));
      expect(h.client.sends, hasLength(2));
      expect(h.client.sends.last.message, 'next');
      expect(h.state.queue, isEmpty);
      expect(transcript(h), [
        'user:hi',
        'assistant:Hello there.',
        'user:next',
        'assistant:',
      ]);
    });
  });

  test('switching chats mid-stream detaches without a server cancel', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
          'chat-2': const MothershipChatHistory(id: 'chat-2', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post.envelope(text(1, 'a'));
      async.elapse(const Duration(milliseconds: 10));
      // A paced text flush is pending when the user switches.
      post.envelope(text(2, 'b'));
      async.flushMicrotasks();
      h.cubit.selectChat('chat-2');
      async.flushMicrotasks();
      expect(h.state.chatId, 'chat-2');
      expect(h.state.isSending, isFalse);
      expect(h.state.messages, isEmpty);
      expect(h.client.aborts, isEmpty);
      post.envelope(text(3, 'ignored'));
      async.elapse(const Duration(milliseconds: 200));
      expect(h.state.chatId, 'chat-2');
      expect(h.state.messages, isEmpty);
      expect(
        h.queries
            .getQueryData<MothershipChatHistory>(
              MothershipChatKeys.detail('chat-2'),
            )
            ?.messages,
        isEmpty,
      );
    });
  });

  test('a browser return re-attaches to the running stream', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final tail = FakeSse();
      h.client
        ..onHistory = ((id) async => const MothershipChatHistory(
          id: 'chat-1',
          messages: [],
          activeStreamId: 's-2',
        ))
        ..onBatch = ((id, after, {required fromLog}) async => batchOf([]))
        ..onTail = (id, after, {required fromLog, token}) async {
          tail.bindCancel(token);
          return MothershipTailStream(bytes: tail.bytes);
        };
      h.returns.add(BrowserReturnReason.visible);
      async.flushMicrotasks();
      expect(h.client.calls, contains('tail s-2 after=0'));
      tail
        ..envelope(text(1, 'resumed', streamId: 's-2'))
        ..envelope(complete(2, streamId: 's-2'));
      async.elapse(const Duration(milliseconds: 100));
      expect(h.live?.content, 'resumed');
      expect(h.state.isSending, isFalse);
    });
  });
  // Review regressions (R1-R4 and the traced findings). Each failed on the
  // pre-fix engine.

  test('R1 a pending flush of the old chat does not leak after a switch', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
          'chat-2': const MothershipChatHistory(id: 'chat-2', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post.envelope(text(1, 'a'));
      async
        ..flushMicrotasks()
        ..elapse(const Duration(milliseconds: 10));
      post.envelope(text(2, 'b'));
      async.flushMicrotasks();
      h.cubit.selectChat('chat-2');
      async
        ..flushMicrotasks()
        ..elapse(const Duration(milliseconds: 200));
      expect(h.state.chatId, 'chat-2');
      expect(transcript(h), isEmpty);
      // A send in the new chat starts a fresh turn, not the old one's text.
      final next = FakeSse();
      h.client.answerSend(next);
      unawaited(h.cubit.sendMessage(const SendPayload(content: 'new')));
      async
        ..flushMicrotasks()
        ..elapse(const Duration(milliseconds: 100));
      expect(transcript(h), ['user:new', 'assistant:']);
    });
  });

  test('R2 stop after a non-fatal error frame keeps the stopped state', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      // The server copy is still being written: refetches do not answer.
      h.client.onHistory = (id) => Completer<MothershipChatHistory>().future;
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post
        ..envelope(text(1, 'a'))
        ..envelope(
          envelope(2, 'tool', {
            'phase': 'call',
            'toolCallId': 't1',
            'toolName': 'grep',
            'executor': 'go',
            'mode': 'sync',
          }),
        )
        ..envelope(envelope(3, 'error', {'message': 'subagent hiccup'}));
      async.elapse(const Duration(milliseconds: 100));
      unawaited(h.cubit.stop().catchError((_) {}));
      async.flushMicrotasks();
      ToolCallInfo? tool(ChatMessage? m) =>
          m?.contentBlocks?.firstWhere((b) => b.toolCall != null).toolCall;
      expect(
        h.state.messages.last.contentBlocks?.last.type,
        ContentBlockType.stopped,
      );
      expect(tool(h.state.messages.last)?.status, ToolCallStatus.cancelled);
      async.elapse(const Duration(seconds: 1));
      expect(h.live?.contentBlocks?.last.type, ContentBlockType.stopped);
      expect(tool(h.live)?.status, ToolCallStatus.cancelled);
    });
  });

  test('R3 a queued follow-up keeps the previous answer (history pending)', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      h.client.onHistory = (id) => Completer<MothershipChatHistory>().future;
      final first = FakeSse();
      h.client.answerSend(first);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      unawaited(h.cubit.sendMessage(const SendPayload(content: 'next')));
      async.flushMicrotasks();
      final second = FakeSse();
      h.client.answerSend(second);
      first
        ..envelope(text(1, 'the answer'))
        ..envelope(complete(2));
      async.elapse(const Duration(seconds: 1));
      expect(h.client.sends, hasLength(2));
      final secondId = h.client.sends.last.userMessageId;
      expect(transcript(h), [
        'user:hi',
        'assistant:the answer',
        'user:next',
        'assistant:',
      ]);
      second
        ..envelope(text(1, 'second', streamId: secondId))
        ..envelope(complete(2, streamId: secondId));
      async.elapse(const Duration(seconds: 1));
      expect(transcript(h), [
        'user:hi',
        'assistant:the answer',
        'user:next',
        'assistant:second',
      ]);
    });
  });

  test('R3 send-now stops the turn and keeps its partial answer', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      h.client.onHistory = (id) => Completer<MothershipChatHistory>().future;
      final first = FakeSse();
      h.client.answerSend(first);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      first.envelope(text(1, 'partial'));
      async.elapse(const Duration(milliseconds: 100));
      unawaited(h.cubit.sendMessage(const SendPayload(content: 'next')));
      async.flushMicrotasks();
      final second = FakeSse();
      h.client.answerSend(second);
      unawaited(h.cubit.sendNow());
      async.elapse(const Duration(seconds: 1));
      expect(h.client.aborts.first['streamId'], 'u-1');
      expect(h.client.sends, hasLength(2));
      expect(transcript(h), [
        'user:hi',
        'assistant:partial',
        'user:next',
        'assistant:',
      ]);
      expect(
        h.state.messages[1].contentBlocks?.last.type,
        ContentBlockType.stopped,
      );
    });
  });

  test('R4 a 500 to a POST stopped before admission stays quiet', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final gate = Completer<MothershipSendStream>();
      h.client.onSend = (r, t) => gate.future;
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      unawaited(h.cubit.stop().catchError((_) {}));
      async.flushMicrotasks();
      gate.completeError(
        const MothershipSendRejected(status: 500, error: 'boom'),
      );
      async.elapse(const Duration(seconds: 2));
      expect(h.state.error, isNull);
      expect(h.state.isSending, isFalse);
    });
  });

  test('F16 a chat deleted while open refetches and shows the error', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(
            id: 'chat-1',
            messages: [PersistedMessage(id: 'u-9', role: 'user', content: 'x')],
          ),
        },
      );
      async.flushMicrotasks();
      expect(h.state.historyStatus, ChatHistoryStatus.ready);
      // What ChatEventsCubit does on a `deleted` task_status.
      h.client.histories.remove('chat-1');
      h.queries.removeQueries(MothershipChatKeys.detail('chat-1'));
      async.flushMicrotasks();
      expect(h.client.calls.where((c) => c == 'history chat-1'), hasLength(2));
      expect(h.state.historyStatus, ChatHistoryStatus.error);
      expect(h.state.error, chatHistoryErrorMessage);
    });
  });

  test('a POST in flight in the old chat does not hold the new chat', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
          'chat-2': const MothershipChatHistory(id: 'chat-2', messages: []),
        },
      );
      async.flushMicrotasks();
      final gate = Completer<MothershipSendStream>();
      h.client.onSend = (r, t) => gate.future;
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      h.cubit.selectChat('chat-2');
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(const SendPayload(content: 'there')));
      async.flushMicrotasks();
      expect(h.state.queue, isEmpty);
      expect(h.client.sends.map((s) => s.chatId), ['chat-1', 'chat-2']);
      final id = h.client.sends.last.userMessageId;
      expect(transcript(h), ['user:there', 'assistant:']);
      h.client.histories['chat-2'] = MothershipChatHistory(
        id: 'chat-2',
        messages: [
          PersistedMessage(id: id, role: 'user', content: 'there'),
          const PersistedMessage(id: 'a-2', role: 'assistant', content: 'ok'),
        ],
      );
      post
        ..envelope(text(1, 'ok', streamId: id))
        ..envelope(complete(2, streamId: id));
      async.elapse(const Duration(milliseconds: 100));
      expect(transcript(h), ['user:there', 'assistant:ok']);
    });
  });

  test('a POST in flight in the old chat does not block hydration', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
          'chat-2': const MothershipChatHistory(
            id: 'chat-2',
            messages: [PersistedMessage(id: 's-2', role: 'user', content: 'q')],
            activeStreamId: 's-2',
          ),
        },
      );
      async.flushMicrotasks();
      final gate = Completer<MothershipSendStream>();
      h.client.onSend = (r, t) => gate.future;
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      final tail = FakeSse();
      h.client
        ..onBatch = ((id, after, {required fromLog}) async => batchOf([]))
        ..onTail = (id, after, {required fromLog, token}) async {
          tail.bindCancel(token);
          return MothershipTailStream(bytes: tail.bytes);
        };
      h.cubit.selectChat('chat-2');
      async.flushMicrotasks();
      expect(h.client.calls, contains('tail s-2 after=0'));
    });
  });

  test('reconnect pauses do not pile up abort listeners', () {
    fakeAsync((async) {
      final h = Harness(
        chatId: 'chat-1',
        histories: {
          'chat-1': const MothershipChatHistory(id: 'chat-1', messages: []),
        },
      );
      async.flushMicrotasks();
      final post = FakeSse();
      h.client.answerSend(post);
      unawaited(h.cubit.sendMessage(hi));
      async.flushMicrotasks();
      post.envelope(text(1, 'a'));
      h.client
        ..onBatch = ((id, after, {required fromLog}) async => batchOf([]))
        ..onTail = (id, after, {required fromLog, token}) async {
          final tail = FakeSse()..bindCancel(token);
          unawaited(tail.end());
          return MothershipTailStream(bytes: tail.bytes);
        };
      unawaited(post.end());
      async.elapse(const Duration(seconds: 20));
      expect(
        h.client.calls.where((c) => c.startsWith('tail')).length,
        greaterThanOrEqualTo(19),
      );
      expect(h.cubit.debugAbortWaiters, lessThanOrEqualTo(1));
    });
  });
}
