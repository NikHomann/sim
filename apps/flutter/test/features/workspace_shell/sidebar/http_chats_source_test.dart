// Failure modes of the sidebar chat source (parity finding (e): the seeded
// chat never showed because the section read an always-empty source):
// 1. the list is fetched from `GET /api/mothership/chats?workspaceId&
//    scope=active` and mapped like `mapChat` (`title ?? 'New chat'`,
//    running stream = active, unread only when idle and updated after the
//    last visit);
// 2. a fresh list is not refetched within 60 s; a stale one is;
// 3. a failed load settles on an empty list instead of loading forever;
// 4. a chat-status event (`ChatEventsState.listGeneration`) refetches the
//    list at once, even within the 60 s staleness;
// 5. `runningChatIds` shows the running dot before the refetch lands and
//    drops it when the chat completes.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/chat_models.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/http_chats_source.dart';

class _MockHttp extends Mock implements SimHttpClient {}

const Map<String, Object?> _body = <String, Object?>{
  'success': true,
  'data': <Object?>[
    <String, Object?>{
      'id': 'c1',
      'title': 'E2E conversation',
      'updatedAt': '2026-10-21T10:00:00.000Z',
      'activeStreamId': null,
      'lastSeenAt': '2026-10-21T11:00:00.000Z',
      'pinned': true,
    },
    <String, Object?>{
      'id': 'c2',
      'title': null,
      'updatedAt': '2026-10-21T12:00:00.000Z',
      'activeStreamId': null,
      'lastSeenAt': '2026-10-21T11:00:00.000Z',
      'pinned': false,
    },
    <String, Object?>{
      'id': 'c3',
      'title': 'Running',
      'updatedAt': '2026-10-21T12:00:00.000Z',
      'activeStreamId': 'stream',
      'lastSeenAt': null,
      'pinned': false,
    },
  ],
};

void main() {
  late _MockHttp http;
  late DateTime now;
  late List<Map<String, Object?>?> queries;

  void stubList(Future<Object?> Function() body) {
    when(
      () => http.requestJson<List<SidebarChat>>(
        method: any(named: 'method'),
        path: any(named: 'path'),
        query: any(named: 'query'),
        decode: any(named: 'decode'),
      ),
    ).thenAnswer((invocation) async {
      queries.add(invocation.namedArguments[#query] as Map<String, Object?>?);
      final decode =
          invocation.namedArguments[#decode]
              as List<SidebarChat> Function(Object?);
      return decode(await body());
    });
  }

  setUp(() {
    http = _MockHttp();
    now = DateTime.utc(2026, 10, 22);
    queries = <Map<String, Object?>?>[];
  });

  test('1. lists and maps the active chats', () async {
    stubList(() async => _body);
    final source = HttpChatsSource(http, now: () => now);
    final list = source.chats('ws');
    expect(list.value, isNull, reason: 'loading');
    await pumpEventQueue();
    expect(queries.single, <String, Object?>{
      'workspaceId': 'ws',
      'scope': 'active',
    });
    final chats = list.value!;
    expect(chats.map((c) => c.name), <String>[
      'E2E conversation',
      'New chat',
      'Running',
    ]);
    expect(chats[0].isPinned, isTrue);
    expect(chats[0].isUnread, isFalse);
    expect(chats[1].isUnread, isTrue);
    expect(chats[2].isActive, isTrue);
    expect(chats[2].isUnread, isFalse);
  });

  test('2. refetches only once the list is 60 s old', () async {
    stubList(() async => _body);
    final source = HttpChatsSource(http, now: () => now)..chats('ws');
    await pumpEventQueue();
    now = now.add(const Duration(seconds: 59));
    source.chats('ws');
    await pumpEventQueue();
    expect(queries, hasLength(1));
    now = now.add(const Duration(seconds: 2));
    source.chats('ws');
    await pumpEventQueue();
    expect(queries, hasLength(2));
  });

  test('3. a failed load settles on an empty list', () async {
    stubList(() async => throw const ApiNetworkError('offline'));
    final list = HttpChatsSource(http, now: () => now).chats('ws');
    await pumpEventQueue();
    expect(list.value, isEmpty);
  });

  test('4. invalidate refetches a fresh list now', () async {
    stubList(() async => _body);
    final source = HttpChatsSource(http, now: () => now)..chats('ws');
    await pumpEventQueue();
    expect(queries, hasLength(1));
    source.invalidate('ws');
    await pumpEventQueue();
    expect(queries, hasLength(2));
    source.invalidate('other');
    await pumpEventQueue();
    expect(queries, hasLength(2), reason: 'an unread list waits for a read');
  });

  test('5. running ids overlay the dot until the chat completes', () async {
    stubList(() async => _body);
    final source = HttpChatsSource(http, now: () => now);
    final list = source.chats('ws');
    await pumpEventQueue();
    SidebarChat row(String id) => list.value!.firstWhere((c) => c.id == id);
    expect(row('c1').isActive, isFalse);
    source.setRunning('ws', {'c1'});
    expect(row('c1').isActive, isTrue);
    expect(row('c1').isUnread, isFalse);
    expect(row('c3').isActive, isTrue, reason: 'the server says running');
    source.setRunning('ws', <String>{});
    expect(row('c1').isActive, isFalse);
  });
}
