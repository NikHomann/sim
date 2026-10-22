import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/chat_models.dart';

/// `MOTHERSHIP_CHAT_LIST_STALE_TIME`.
const Duration chatListStaleTime = Duration(seconds: 60);

/// `mapChat` (`mothership-chats.ts:301-315`) of one list entry.
SidebarChat? sidebarChatFromJson(Object? json) {
  if (json is! Map) return null;
  final id = json['id'];
  if (id is! String) return null;
  final title = json['title'];
  final activeStreamId = json['activeStreamId'];
  final updatedAt = DateTime.tryParse('${json['updatedAt']}');
  final lastSeenRaw = json['lastSeenAt'];
  final lastSeenAt = lastSeenRaw is String
      ? DateTime.tryParse(lastSeenRaw)
      : null;
  final unread =
      activeStreamId == null &&
      (lastSeenAt == null ||
          (updatedAt != null && updatedAt.isAfter(lastSeenAt)));
  return SidebarChat(
    id: id,
    name: title is String ? title : 'New chat',
    isActive: activeStreamId != null,
    isUnread: unread,
    isPinned: json['pinned'] == true,
  );
}

/// The sidebar's chat list over the mothership chat routes
/// (`useMothershipChats(ws, 'active')` and the chat mutations,
/// `workspace-sidebar.md` network rows): `GET /api/mothership/chats`
/// with a 60 s staleness, optimistic rename / pin / unread / read and
/// delete, each followed by a refetch (the owner-list invalidation).
class HttpChatsSource extends SidebarChatsSource {
  HttpChatsSource(this._http, {DateTime Function()? now})
    : _now = now ?? (() => clock.now());

  final SimHttpClient _http;
  final DateTime Function() _now;
  final Map<String, ValueNotifier<List<SidebarChat>?>> _lists =
      <String, ValueNotifier<List<SidebarChat>?>>{};
  final Map<String, DateTime> _fetchedAt = <String, DateTime>{};
  final Map<String, Future<void>> _inFlight = <String, Future<void>>{};
  final Map<String, String> _workspaceOf = <String, String>{};
  final Map<String, Set<String>> _running = <String, Set<String>>{};

  /// The owner-list invalidation (`invalidateQueries(workspaceLists)`):
  /// a mounted list refetches now, a fetch in flight is followed by one
  /// more (its answer may predate the change); an unmounted list refetches
  /// on its next read.
  void invalidate(String workspaceId) {
    _fetchedAt.remove(workspaceId);
    if (!_lists.containsKey(workspaceId)) return;
    final inFlight = _inFlight[workspaceId];
    if (inFlight == null) {
      unawaited(_load(workspaceId));
    } else {
      unawaited(inFlight.whenComplete(() => _load(workspaceId)));
    }
  }

  /// The chats a `task_status` event reported `started` and no later event
  /// `completed` (`ChatEventsState.runningChatIds`): they show the running
  /// dot before the refetch lands, as React's optimistic list update does.
  void setRunning(String workspaceId, Set<String> chatIds) {
    final previous = _running[workspaceId] ?? const <String>{};
    if (setEquals(previous, chatIds)) return;
    _running[workspaceId] = Set<String>.of(chatIds);
    final list = _lists[workspaceId];
    final rows = list?.value;
    if (list == null || rows == null) return;
    list.value = <SidebarChat>[
      for (final row in rows)
        _withRunning(
          row,
          running: chatIds.contains(row.id),
          wasRunning: previous.contains(row.id),
        ),
    ];
  }

  /// A row's dot with the event overlay: a started chat is active; a chat
  /// whose overlay ended falls back to the last fetched state (the
  /// refetch the same event triggered settles it).
  SidebarChat _withRunning(
    SidebarChat row, {
    required bool running,
    bool wasRunning = false,
  }) {
    final serverActive = _serverActive[row.id] ?? row.isActive;
    final active = running || (serverActive && !wasRunning);
    if (active == row.isActive) return row;
    return SidebarChat(
      id: row.id,
      name: row.name,
      isActive: active,
      isUnread: !active && row.isUnread,
      isPinned: row.isPinned,
    );
  }

  final Map<String, bool> _serverActive = <String, bool>{};

  @override
  ValueListenable<List<SidebarChat>?> chats(String workspaceId) {
    final list = _lists.putIfAbsent(
      workspaceId,
      () => ValueNotifier<List<SidebarChat>?>(null),
    );
    final fetched = _fetchedAt[workspaceId];
    if (fetched == null || _now().difference(fetched) >= chatListStaleTime) {
      unawaited(_load(workspaceId));
    }
    return list;
  }

  Future<void> _load(String workspaceId) =>
      _inFlight[workspaceId] ??= _fetch(workspaceId).whenComplete(
        () => _inFlight.remove(workspaceId),
      );

  Future<void> _fetch(String workspaceId) async {
    try {
      final rows = await _http.requestJson<List<SidebarChat>>(
        method: 'GET',
        path: '/api/mothership/chats',
        query: <String, Object?>{'workspaceId': workspaceId, 'scope': 'active'},
        decode: (json) {
          final data = json is Map ? json['data'] : null;
          return <SidebarChat>[
            if (data is List)
              for (final row in data) ?sidebarChatFromJson(row),
          ];
        },
      );
      _fetchedAt[workspaceId] = _now();
      final running = _running[workspaceId] ?? const <String>{};
      for (final chat in rows) {
        _workspaceOf[chat.id] = workspaceId;
        _serverActive[chat.id] = chat.isActive;
      }
      _lists[workspaceId]?.value = <SidebarChat>[
        for (final chat in rows)
          _withRunning(chat, running: running.contains(chat.id)),
      ];
    } on Object catch (error) {
      developer.log('chat list', name: 'sim_app.sidebar', error: error);
      final list = _lists[workspaceId];
      if (list != null && list.value == null) {
        list.value = const <SidebarChat>[];
      }
    }
  }

  /// Applies [change] to the cached row of [chatId], runs [request], and
  /// refetches the owner list either way (rolled back by the refetch).
  Future<void> _mutate(
    String chatId,
    SidebarChat Function(SidebarChat chat) change,
    Future<void> Function() request,
  ) async {
    final workspaceId = _workspaceOf[chatId];
    final list = workspaceId == null ? null : _lists[workspaceId];
    final rows = list?.value;
    if (list != null && rows != null) {
      list.value = <SidebarChat>[
        for (final row in rows) row.id == chatId ? change(row) : row,
      ];
    }
    try {
      await request();
    } finally {
      if (workspaceId != null) {
        _fetchedAt.remove(workspaceId);
        await _load(workspaceId);
      }
    }
  }

  static SidebarChat _copy(
    SidebarChat chat, {
    String? name,
    bool? isUnread,
    bool? isPinned,
  }) => SidebarChat(
    id: chat.id,
    name: name ?? chat.name,
    isActive: chat.isActive,
    isUnread: isUnread ?? chat.isUnread,
    isPinned: isPinned ?? chat.isPinned,
  );

  Future<void> _patch(String chatId, Map<String, Object?> body) => _http.send(
    method: 'PATCH',
    path: '/api/mothership/chats/[chatId]',
    params: <String, Object?>{'chatId': chatId},
    body: body,
  );

  @override
  Future<void> rename(String chatId, String title) => _mutate(
    chatId,
    (chat) => _copy(chat, name: title),
    () => _patch(chatId, <String, Object?>{'title': title}),
  );

  @override
  Future<void> setPinned(String chatId, {required bool pinned}) => _mutate(
    chatId,
    (chat) => _copy(chat, isPinned: pinned),
    () => _patch(chatId, <String, Object?>{'pinned': pinned}),
  );

  @override
  Future<void> markUnread(String chatId) => _mutate(
    chatId,
    (chat) => _copy(chat, isUnread: true),
    () => _patch(chatId, <String, Object?>{'isUnread': true}),
  );

  @override
  Future<void> markRead(String chatId) => _mutate(
    chatId,
    (chat) => _copy(chat, isUnread: false),
    () => _http.send(
      method: 'POST',
      path: '/api/mothership/chats/read',
      body: <String, Object?>{'chatId': chatId},
    ),
  );

  /// One `DELETE` per chat; the list drops them at once.
  @override
  Future<void> delete(List<String> chatIds) async {
    final workspaces = <String>{
      for (final id in chatIds) ?_workspaceOf[id],
    };
    for (final workspaceId in workspaces) {
      final list = _lists[workspaceId];
      final rows = list?.value;
      if (list != null && rows != null) {
        list.value = <SidebarChat>[
          for (final row in rows)
            if (!chatIds.contains(row.id)) row,
        ];
      }
    }
    try {
      await Future.wait(
        chatIds.map(
          (id) => _http.send(
            method: 'DELETE',
            path: '/api/mothership/chats/[chatId]',
            params: <String, Object?>{'chatId': id},
          ),
        ),
      );
    } finally {
      for (final workspaceId in workspaces) {
        _fetchedAt.remove(workspaceId);
        await _load(workspaceId);
      }
    }
  }
}

HttpChatsSource? _sharedChats;

/// The app-wide chat source (one cache for every sidebar mount); `null`
/// without an HTTP client. Sign-out drops it with the other user data.
HttpChatsSource? get sharedChatsSource {
  final existing = _sharedChats;
  if (existing != null) return existing;
  if (!locator.isRegistered<SimHttpClient>()) return null;
  if (locator.isRegistered<UserDataResetRegistry>()) {
    locator<UserDataResetRegistry>().register(() => _sharedChats = null);
  }
  return _sharedChats = HttpChatsSource(locator<SimHttpClient>());
}
