// Failure modes of ChatEventsCubit (spec chat-engine §3.9, F16, parity
// rows 86-88), over a real RotatingEventSource fed by a fake connection:
// 1. Chat disabled → no connection is opened;
// 2. every task_status invalidates the workspace lists (listGeneration)
//    and refetches an observed list query;
// 3. `deleted` removes the detail and clears + blocks the chat's queue;
//    `created` lifts the block;
// 4. `renamed` marks the detail stale without refetching it;
// 5. `started` of the cached live stream does not invalidate the detail; a
//    `completed` of it only marks it stale; another stream refetches;
// 6. `started`/`completed` drive the running set (the sidebar dot seam);
// 7. a reconnect re-syncs the lists; the first open of a workspace already
//    subscribed in this process does too;
// 8. a non-object payload is ignored.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/engine.dart';

import 'support/fake_client.dart';

class _Conn {
  final controller = StreamController<Uint8List>();
  void event(String name, Object? data) => controller.add(
    Uint8List.fromList(
      utf8.encode('event: $name\ndata: ${jsonEncode(data)}\n\n'),
    ),
  );
}

void main() {
  late QueryClient queries;
  late MothershipQueueStore queue;
  late List<_Conn> conns;
  late RotatingEventSource source;

  RotatingEventSource buildSource() => RotatingEventSource(
    retryDelay: const Duration(milliseconds: 1),
    open: ({required cancelToken, lastEventId}) async {
      final conn = _Conn();
      conns.add(conn);
      return ApiStreamResponse(
        status: 200,
        headers: const {},
        bytes: conn.controller.stream,
      );
    },
  );

  ChatEventsCubit build({bool enabled = true}) => ChatEventsCubit(
    client: FakeMothershipClient(),
    queryClient: queries,
    queueStore: queue,
    workspaceId: 'ws',
    chatEnabled: enabled,
    source: source,
  );

  setUp(() {
    ChatEventsCubit.resetSubscriptionHistory();
    queries = QueryClient();
    queue = MothershipQueueStore(MemoryChatStorage());
    conns = [];
    source = buildSource();
  });

  Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 5));

  test('chat disabled opens nothing', () async {
    final cubit = build(enabled: false)..start();
    await pump();
    expect(conns, isEmpty);
    await cubit.close();
  });

  test('events invalidate lists, delete and restore the queue', () async {
    var listFetches = 0;
    final list = queries.query<int>(
      MothershipChatKeys.list('ws'),
      (_) async => ++listFetches,
    );
    await list.fetch();
    queue.enqueue('c1', const QueuedMessage(id: 'q', content: 'x'));
    queries.setQueryData(
      MothershipChatKeys.detail('c1'),
      const MothershipChatHistory(id: 'c1', messages: []),
    );
    final cubit = build()..start();
    await pump();
    conns.single.event('task_status', {'chatId': 'c1', 'type': 'deleted'});
    await pump();
    expect(cubit.state.listGeneration, 1);
    expect(listFetches, 2);
    expect(
      queries.getQueryData<MothershipChatHistory>(
        MothershipChatKeys.detail('c1'),
      ),
      isNull,
    );
    expect(queue.queue('c1'), isEmpty);
    queue.enqueue('c1', const QueuedMessage(id: 'q2', content: 'y'));
    expect(queue.queue('c1'), isEmpty);
    conns.single.event('task_status', {'chatId': 'c1', 'type': 'created'});
    await pump();
    queue.enqueue('c1', const QueuedMessage(id: 'q3', content: 'z'));
    expect(queue.queue('c1').single.id, 'q3');
    conns.single.event('task_status', 'not json object');
    await pump();
    expect(cubit.state.listGeneration, 2);
    await cubit.close();
  });

  test('renamed and live-stream events do not refetch the detail', () async {
    var detailFetches = 0;
    final detail = queries.query<MothershipChatHistory>(
      MothershipChatKeys.detail('c1'),
      (_) async {
        detailFetches++;
        return const MothershipChatHistory(
          id: 'c1',
          messages: [
            PersistedMessage(id: 's1', role: 'user', content: 'q'),
            PersistedMessage(
              id: 'live-assistant:s1',
              role: 'assistant',
              content: '',
            ),
          ],
          activeStreamId: 's1',
        );
      },
    );
    await detail.fetch();
    final cubit = build()..start();
    await pump();
    conns.single
      ..event('task_status', {'chatId': 'c1', 'type': 'renamed'})
      ..event('task_status', {
        'chatId': 'c1',
        'type': 'started',
        'streamId': 's1',
      });
    await pump();
    expect(detailFetches, 1);
    expect(detail.isStale, isTrue);
    expect(cubit.state.runningChatIds, {'c1'});
    conns.single.event('task_status', {
      'chatId': 'c1',
      'type': 'completed',
      'streamId': 's1',
    });
    await pump();
    expect(detailFetches, 1);
    expect(cubit.state.runningChatIds, isEmpty);
    conns.single.event('task_status', {
      'chatId': 'c1',
      'type': 'completed',
      'streamId': 'other',
    });
    await pump();
    expect(detailFetches, 1, reason: 'a newer cached live turn wins');
    await cubit.close();
  });

  test('reconnect and re-subscription re-sync the lists', () async {
    final first = build()..start();
    await pump();
    expect(first.state.listGeneration, 0);
    await first.close();
    source = buildSource();
    final second = build()..start();
    await pump();
    expect(second.state.listGeneration, 1);
    await conns.last.controller.close();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(second.state.listGeneration, 2);
    await second.close();
  });

  test('shouldSkipDetailInvalidation rules', () {
    const history = MothershipChatHistory(
      id: 'c',
      messages: [
        PersistedMessage(id: 'old', role: 'user', content: ''),
        PersistedMessage(id: 'new', role: 'user', content: ''),
      ],
      activeStreamId: 'new',
    );
    expect(
      ChatEventsCubit.shouldSkipDetailInvalidation(
        history,
        const TaskStatusEvent(type: TaskStatusType.completed, streamId: 'old'),
      ),
      isTrue,
    );
    expect(
      ChatEventsCubit.shouldSkipDetailInvalidation(
        history,
        const TaskStatusEvent(type: TaskStatusType.completed, streamId: 'new'),
      ),
      isFalse,
    );
    expect(
      ChatEventsCubit.shouldSkipDetailInvalidation(
        null,
        const TaskStatusEvent(type: TaskStatusType.started, streamId: 'x'),
      ),
      isFalse,
    );
  });

  test(
    'F16 a deleted open chat refetches and shows the history error',
    () async {
      final client = FakeMothershipClient();
      client.histories['c1'] = const MothershipChatHistory(
        id: 'c1',
        messages: [PersistedMessage(id: 'u', role: 'user', content: 'x')],
      );
      final storages = ChatStorages.memory();
      final session = ChatSessionCubit(
        client: client,
        queryClient: queries,
        queueStore: queue,
        effortStore: MothershipEffortStore(storages.local, plan: false),
        planEffortStore: MothershipEffortStore(storages.local, plan: true),
        workspaceId: 'ws',
        chatId: 'c1',
        markChatRead: false,
        isOnline: () => true,
        timeZone: () => 'UTC',
        browserReturns: const Stream.empty(),
        onlineEvents: const Stream.empty(),
      );
      final events = build()..start();
      await pump();
      expect(session.state.historyStatus, ChatHistoryStatus.ready);
      client.histories.remove('c1');
      conns.single.event('task_status', {'chatId': 'c1', 'type': 'deleted'});
      await pump();
      expect(session.state.historyStatus, ChatHistoryStatus.error);
      expect(session.state.error, chatHistoryErrorMessage);
      expect(session.state.messages, isEmpty);
      await events.close();
      await session.close();
    },
  );
}
