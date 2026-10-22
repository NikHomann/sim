import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sim_api/src/client/api_client_error.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/mothership/mothership_models.dart';
import 'package:sim_api/src/sse/named_events.dart';

/// The cancellation handle the client methods take (Dio's `CancelToken`),
/// named here so callers need no direct `dio` dependency.
typedef MothershipCancelToken = CancelToken;

/// Response header naming the chat a send opened or continued.
const mothershipChatIdHeader = 'x-mothership-chat-id';

/// Response header of a reconnect re-synced from the worker log.
const mothershipStreamReplayHeader = 'x-mothership-stream-replay';

/// Response header when the desktop background executor runs device tools.
const mothershipDesktopExecutorHeader = 'x-mothership-desktop-executor';

/// The reconnect target has no run any more (404): the persisted
/// transcript is authoritative (`StreamGoneError`).
class MothershipStreamGoneError implements Exception {
  const MothershipStreamGoneError(this.streamId);
  final String streamId;

  @override
  String toString() => 'Stream $streamId no longer exists';
}

/// A non-2xx answer to `POST /api/mothership/chat` (spec §3.1): the body is
/// read so the engine can tell a busy 409 from a duplicate 409.
class MothershipSendRejected implements Exception {
  const MothershipSendRejected({
    required this.status,
    this.error,
    this.activeStreamId,
    this.chatId,
    this.body,
  });

  factory MothershipSendRejected.fromApiError(ApiClientError error) {
    final body = error.body;
    final map = body is Map ? body : const <Object?, Object?>{};
    return MothershipSendRejected(
      status: error.status,
      error: map['error'] is String ? map['error']! as String : null,
      activeStreamId: map['activeStreamId'] is String
          ? map['activeStreamId']! as String
          : null,
      chatId: map['chatId'] is String ? map['chatId']! as String : null,
      body: body,
    );
  }

  final int status;

  /// `errorData.error` when it is a string.
  final String? error;
  final String? activeStreamId;
  final String? chatId;
  final Object? body;

  bool get isConflict => status == 409;

  /// `errorData.error ?? 'Request failed: <status>'`.
  String get displayMessage => error ?? 'Request failed: $status';

  @override
  String toString() => 'MothershipSendRejected($status, $error)';
}

/// The admitted send: headers now, the SSE body as it arrives.
class MothershipSendStream {
  const MothershipSendStream({
    required this.bytes,
    this.chatId,
    this.traceparent,
    this.desktopToolsOnDevice = false,
  });

  final Stream<List<int>> bytes;

  /// `x-mothership-chat-id`.
  final String? chatId;
  final String? traceparent;
  final bool desktopToolsOnDevice;

  /// The trace id inside [traceparent] when it is 32 lowercase hex chars.
  String? get traceId {
    final parts = traceparent?.split('-');
    if (parts == null || parts.length < 2) return null;
    return RegExp(r'^[0-9a-f]{32}$').hasMatch(parts[1]) ? parts[1] : null;
  }
}

/// The live tail of a stream.
class MothershipTailStream {
  const MothershipTailStream({
    required this.bytes,
    this.logResynced = false,
    this.desktopToolsOnDevice = false,
  });

  final Stream<List<int>> bytes;

  /// `x-mothership-stream-replay: log`: cursors restart at 1.
  final bool logResynced;
  final bool desktopToolsOnDevice;
}

/// The mothership chat client (spec chat-engine §3): the streaming send,
/// reconnect tail and batch, stop/abort, stream status, tool permission and
/// confirm, the chat CRUD routes and the `task_status` events source.
///
/// Requests go through [SimHttpClient] (same-origin cookies on web, the jar
/// on desktop). Paths and bodies match what React sends.
class MothershipClient {
  MothershipClient(this._http);

  final SimHttpClient _http;

  static const streamBatchTimeout = Duration(seconds: 10);
  static const stopRequestTimeout = Duration(seconds: 15);

  /// `streamReconnectQuery`.
  static Map<String, Object?> reconnectQuery(
    String streamId,
    String after, {
    required bool fromLog,
    bool batch = false,
  }) => {
    'streamId': streamId,
    'after': after,
    if (fromLog) 'source': 'log',
    if (batch) 'batch': 'true',
  };

  /// `POST /api/mothership/chat`. Throws [MothershipSendRejected] for a
  /// non-2xx status, `ApiNetworkError` when no response arrived and
  /// `ApiCancelledError` when [cancelToken] fired before the headers.
  Future<MothershipSendStream> send(
    MothershipSendRequest request, {
    CancelToken? cancelToken,
  }) async {
    final ApiStreamResponse response;
    try {
      response = await _http.stream(
        method: 'POST',
        path: '/api/mothership/chat',
        body: request.toJson(),
        cancelToken: cancelToken,
      );
    } on ApiClientError catch (error) {
      throw MothershipSendRejected.fromApiError(error);
    }
    return MothershipSendStream(
      bytes: response.bytes,
      chatId: response.header(mothershipChatIdHeader),
      traceparent: response.header('traceparent'),
      desktopToolsOnDevice:
          response.header(mothershipDesktopExecutorHeader) == 'device',
    );
  }

  /// `GET /api/mothership/chat/stream?streamId&after[&source=log]`: 404 →
  /// [MothershipStreamGoneError]; other non-2xx → [ApiClientError].
  Future<MothershipTailStream> tail(
    String streamId,
    String after, {
    bool fromLog = false,
    String? traceparent,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _http.stream(
        method: 'GET',
        path: '/api/mothership/chat/stream',
        query: reconnectQuery(streamId, after, fromLog: fromLog),
        headers: {'traceparent': ?traceparent},
        cancelToken: cancelToken,
      );
      return MothershipTailStream(
        bytes: response.bytes,
        logResynced: response.header(mothershipStreamReplayHeader) == 'log',
        desktopToolsOnDevice:
            response.header(mothershipDesktopExecutorHeader) == 'device',
      );
    } on ApiClientError catch (error) {
      if (error.status == 404) throw MothershipStreamGoneError(streamId);
      rethrow;
    }
  }

  /// `GET …/chat/stream?…&batch=true` with a 10 s timeout: 404 →
  /// [MothershipStreamGoneError]; an invalid event →
  /// `MothershipStreamSchemaError`.
  Future<StreamBatch> batch(
    String streamId,
    String after, {
    bool fromLog = false,
    String? traceparent,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _http.send(
        method: 'GET',
        path: '/api/mothership/chat/stream',
        query: reconnectQuery(streamId, after, fromLog: fromLog, batch: true),
        headers: {'traceparent': ?traceparent},
        cancelToken: cancelToken,
        timeout: streamBatchTimeout,
      );
      return StreamBatch.fromJson(response.data);
    } on ApiClientError catch (error) {
      if (error.status == 404) throw MothershipStreamGoneError(streamId);
      rethrow;
    }
  }

  /// `POST /api/copilot/chat/abort` (React calls the copilot route, spec
  /// §3.4 and ambiguity 9), 15 s timeout.
  Future<MothershipAbortResult> abort({
    required String streamId,
    String? workspaceId,
    String? organizationId,
    String? chatId,
    String? traceparent,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/copilot/chat/abort',
      body: {
        'streamId': streamId,
        if (organizationId != null)
          'organizationId': organizationId
        else
          'workspaceId': workspaceId,
        'chatId': ?chatId,
      },
      headers: {'traceparent': ?traceparent},
      timeout: stopRequestTimeout,
    );
    return MothershipAbortResult.fromJson(response.data);
  }

  /// `POST /api/mothership/chat/stop` `{chatId, streamId, requestId?}`; a
  /// non-2xx throws with `payload.error ?? 'Failed to persist partial
  /// response'`.
  Future<void> persistStop({
    required String chatId,
    required String streamId,
    String? requestId,
    String? traceparent,
  }) async {
    try {
      await _http.send(
        method: 'POST',
        path: '/api/mothership/chat/stop',
        body: {'chatId': chatId, 'streamId': streamId, 'requestId': ?requestId},
        headers: {'traceparent': ?traceparent},
        timeout: stopRequestTimeout,
      );
    } on ApiClientError catch (error) {
      final body = error.body;
      final message = body is Map && body['error'] is String
          ? body['error']! as String
          : 'Failed to persist partial response';
      throw MothershipStopFailed(message);
    }
  }

  /// `GET /api/mothership/chats/[chatId]/stream-status` → `activeStreamId`.
  Future<String?> streamStatus(String chatId, {CancelToken? cancelToken}) =>
      _http.requestJson(
        method: 'GET',
        path: '/api/mothership/chats/[chatId]/stream-status',
        params: {'chatId': chatId},
        cancelToken: cancelToken,
        decode: (json) => json is Map && json['activeStreamId'] is String
            ? json['activeStreamId']! as String
            : null,
      );

  /// `POST /api/copilot/tool-permission` with 1–50 decisions.
  Future<List<ToolPermissionResult>> decideToolPermissions(
    Map<String, ToolPermissionDecision> decisions,
  ) {
    if (decisions.isEmpty || decisions.length > 50) {
      throw ArgumentError.value(decisions.length, 'decisions', '1-50');
    }
    return _http.requestJson(
      method: 'POST',
      path: '/api/copilot/tool-permission',
      body: {
        'decisions': [
          for (final entry in decisions.entries)
            {'toolCallId': entry.key, 'decision': entry.value.wire},
        ],
      },
      decode: (json) {
        final results = json is Map ? json['results'] : null;
        return [
          if (results is List)
            for (final r in results)
              if (r is Map)
                ToolPermissionResult(
                  toolCallId: '${r['toolCallId']}',
                  decision: '${r['decision']}',
                  applied: r['applied'] == true,
                ),
        ];
      },
    );
  }

  /// `POST /api/copilot/confirm` (client-executed tool completion). The
  /// port does not execute client tools in Phase 1.5 (spec ambiguity 6);
  /// this exists for the editor copilot (Phase 3).
  Future<void> confirm({
    required String toolCallId,
    required String status,
    String? executionId,
    String? message,
    Map<String, Object?>? data,
  }) => _http.send(
    method: 'POST',
    path: '/api/copilot/confirm',
    body: {
      'toolCallId': toolCallId,
      'executionId': ?executionId,
      'status': status,
      'message': ?message,
      'data': ?data,
    },
  );

  // Chat CRUD ----------------------------------------------------------------

  /// `GET /api/mothership/chats?workspaceId=&scope=`.
  Future<List<MothershipChatSummary>> listChats({
    required String workspaceId,
    String scope = 'active',
    CancelToken? cancelToken,
  }) => _http.requestJson(
    method: 'GET',
    path: '/api/mothership/chats',
    query: {'workspaceId': workspaceId, 'scope': scope},
    cancelToken: cancelToken,
    decode: (json) {
      final data = json is Map ? json['data'] : null;
      return [
        if (data is List)
          for (final row in data)
            if (row is Map)
              MothershipChatSummary.fromJson(Map<String, Object?>.from(row)),
      ];
    },
  );

  /// `GET /api/mothership/chats/[chatId]`: `?window=latest` on a first
  /// load, `?from=<windowStartCursor>` when a window is cached; the cached
  /// older messages are joined back (`fetchMothershipChatHistory`).
  Future<MothershipChatHistory> chatHistory(
    String chatId, {
    MothershipChatHistory? cached,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    final from = cached?.windowStartCursor;
    final history = await _http.requestJson(
      method: 'GET',
      path: '/api/mothership/chats/[chatId]',
      params: {'chatId': chatId},
      query: from != null ? {'from': from} : {'window': 'latest'},
      cancelToken: cancelToken,
      timeout: timeout,
      decode: MothershipChatHistory.fromJson,
    );
    return history.joinedWithCached(cached);
  }

  /// `GET /api/mothership/chats/[chatId]/messages?before=` →
  /// `(messages, olderCursor)`.
  Future<({List<PersistedMessage> messages, String? olderCursor})>
  olderMessages(String chatId, String before, {CancelToken? cancelToken}) =>
      _http.requestJson(
        method: 'GET',
        path: '/api/mothership/chats/[chatId]/messages',
        params: {'chatId': chatId},
        query: {'before': before},
        cancelToken: cancelToken,
        decode: (json) {
          final map = json is Map ? json : const <Object?, Object?>{};
          final messages = map['messages'];
          return (
            messages: [
              if (messages is List)
                for (final m in messages)
                  if (m is Map)
                    PersistedMessage.fromJson(Map<String, Object?>.from(m)),
            ],
            olderCursor: map['olderCursor'] is String
                ? map['olderCursor']! as String
                : null,
          );
        },
      );

  /// `POST /api/mothership/chats` (not used by the Home send).
  Future<String> createChat({
    String? workspaceId,
    String? organizationId,
    String? mode,
  }) => _http.requestJson(
    method: 'POST',
    path: '/api/mothership/chats',
    body: {
      if (organizationId != null)
        'organizationId': organizationId
      else
        'workspaceId': workspaceId,
      'mode': ?mode,
    },
    decode: (json) => json is Map ? '${json['id']}' : '',
  );

  Future<void> _patch(String chatId, Map<String, Object?> body) => _http.send(
    method: 'PATCH',
    path: '/api/mothership/chats/[chatId]',
    params: {'chatId': chatId},
    body: body,
  );

  /// `PATCH {title}` (trimmed, 1–200 chars).
  Future<void> renameChat(String chatId, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 200) {
      throw ArgumentError.value(title, 'title', 'must be 1-200 characters');
    }
    return _patch(chatId, {'title': trimmed});
  }

  Future<void> setPinned(String chatId, {required bool pinned}) =>
      _patch(chatId, {'pinned': pinned});

  Future<void> markUnread(String chatId) => _patch(chatId, {'isUnread': true});

  /// `POST /api/mothership/chats/read {chatId}`.
  Future<void> markRead(String chatId) => _http.send(
    method: 'POST',
    path: '/api/mothership/chats/read',
    body: {'chatId': chatId},
  );

  Future<void> deleteChat(String chatId) => _http.send(
    method: 'DELETE',
    path: '/api/mothership/chats/[chatId]',
    params: {'chatId': chatId},
  );

  Future<void> restoreChat(String chatId) => _http.send(
    method: 'POST',
    path: '/api/mothership/chats/[chatId]/restore',
    params: {'chatId': chatId},
  );

  /// `POST …/fork {upToMessageId}` → the new chat id. Live ids
  /// (`live-assistant:*`) are not forkable.
  Future<({String id, List<Object?> failedFileCopies})> forkChat(
    String chatId, {
    required String upToMessageId,
  }) {
    if (upToMessageId.startsWith('live-assistant:')) {
      throw ArgumentError.value(upToMessageId, 'upToMessageId', 'live id');
    }
    return _http.requestJson(
      method: 'POST',
      path: '/api/mothership/chats/[chatId]/fork',
      params: {'chatId': chatId},
      body: {'upToMessageId': upToMessageId},
      decode: (json) {
        final map = json is Map ? json : const <Object?, Object?>{};
        final failed = map['failedFileCopies'];
        return (
          id: '${map['id']}',
          failedFileCopies: failed is List ? failed : const <Object?>[],
        );
      },
    );
  }

  /// `PUT …/effort {effort}`.
  Future<void> setChatEffort(String chatId, String effort) => _http.send(
    method: 'PUT',
    path: '/api/mothership/chats/[chatId]/effort',
    params: {'chatId': chatId},
    body: {'effort': effort},
  );

  // Events -------------------------------------------------------------------

  /// The rotating `task_status` source of `/api/mothership/events?workspaceId=`
  /// (spec §3.9). The caller starts and closes it.
  RotatingEventSource chatEvents({required String workspaceId}) =>
      RotatingEventSource(
        open: ({required cancelToken, lastEventId}) => _http.stream(
          method: 'GET',
          path: '/api/mothership/events',
          query: {'workspaceId': workspaceId},
          headers: const {'accept': 'text/event-stream'},
          cancelToken: cancelToken,
        ),
      );
}

/// The stop-persist route answered non-2xx.
class MothershipStopFailed implements Exception {
  const MothershipStopFailed(this.message);
  final String message;

  @override
  String toString() => message;
}
