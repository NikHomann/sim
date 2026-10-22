/// Typed models of the mothership chat wire (spec chat-engine §2.3, §3):
/// stream payloads by envelope type, the reconnect batch, chat rows and
/// detail, persisted messages, send/abort/permission bodies and the
/// `task_status` event.
library;

import 'package:meta/meta.dart';
import 'package:sim_api/src/mothership/envelope_contract.dart';
import 'package:sim_api/src/sse/mothership_stream.dart';

Map<String, Object?>? _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : null;

String? _str(Object? value) => value is String ? value : null;

String? _nonEmpty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

// Stream payloads ------------------------------------------------------------

/// A typed view of one envelope's payload (`generated/mothership-stream-v1.ts`).
sealed class MothershipPayload {
  const MothershipPayload();

  /// The payload of [envelope], per its type and `kind`/`phase`.
  factory MothershipPayload.of(MothershipStreamEnvelope envelope) {
    final p = envelope.payload;
    switch (envelope.type) {
      case MothershipStreamType.session:
        return switch (p['kind']) {
          'start' => SessionStartPayload(
            responseId: _str(_map(p['data'])?['responseId']),
          ),
          'chat' => SessionChatPayload(chatId: '${p['chatId']}'),
          'title' => SessionTitlePayload(title: '${p['title']}'),
          'trace' => SessionTracePayload(
            requestId: '${p['requestId']}',
            spanId: _str(p['spanId']),
          ),
          _ => UnknownPayload(p),
        };
      case MothershipStreamType.text:
        return TextPayload(
          channel: p['channel'] == 'thinking'
              ? TextChannel.thinking
              : TextChannel.assistant,
          text: _str(p['text']) ?? '',
          textOffset: _int(p['textOffset']),
        );
      case MothershipStreamType.tool:
        if (p.containsKey('previewPhase')) {
          return FilePreviewPayload(
            toolCallId: '${p['toolCallId']}',
            previewPhase: '${p['previewPhase']}',
            raw: p,
          );
        }
        final common = (
          toolCallId: _str(p['toolCallId']) ?? '',
          toolName: _str(p['toolName']) ?? '',
          executor: _str(p['executor']),
          mode: _str(p['mode']),
        );
        return switch (p['phase']) {
          'call' => ToolCallPayload(
            toolCallId: common.toolCallId,
            toolName: common.toolName,
            executor: common.executor,
            mode: common.mode,
            arguments: _map(p['arguments']),
            partial: p['partial'] == true,
            status: _str(p['status']),
            activityDescription: _str(p['activityDescription']),
            execName: _str(p['execName']),
            ui: ToolUi.fromJson(p['ui']),
            replay: p['replay'] == true,
            workspaceId: _str(p['workspaceId']),
            deadlineMs: _int(p['deadlineMs']),
            integrationDescription: _str(p['integrationDescription']),
          ),
          'args_delta' => ToolArgsDeltaPayload(
            toolCallId: common.toolCallId,
            toolName: common.toolName,
            executor: common.executor,
            mode: common.mode,
            argumentsDelta: _str(p['argumentsDelta']) ?? '',
          ),
          'result' => ToolResultPayload(
            toolCallId: common.toolCallId,
            toolName: common.toolName,
            executor: common.executor,
            mode: common.mode,
            success: p['success'] == true,
            status: _str(p['status']),
            output: p['output'],
            error: _str(p['error']),
            replay: p['replay'] == true,
          ),
          _ => UnknownPayload(p),
        };
      case MothershipStreamType.span:
        return SpanPayload(
          kind: _str(p['kind']) ?? '',
          event: _str(p['event']),
          agent: _str(p['agent']),
          data: _map(p['data']),
        );
      case MothershipStreamType.resource:
        return ResourceEventPayload(
          op: _str(p['op']) ?? '',
          resource: _map(p['resource']) ?? const {},
          readOnly: p['readOnly'] == true,
          effectId: _str(p['effectId']),
          replay: p['replay'] == true,
        );
      case MothershipStreamType.run:
        return RunPayload(kind: _str(p['kind']) ?? '', raw: p);
      case MothershipStreamType.error:
        return ErrorPayload(
          message: _str(p['message']),
          error: _str(p['error']),
          displayMessage: _str(p['displayMessage']),
          code: _str(p['code']),
          provider: _str(p['provider']),
          data: _map(p['data']),
        );
      case MothershipStreamType.complete:
        return CompletePayload(
          status: _str(p['status']) ?? '',
          reason: _str(p['reason']),
          response: _map(p['response']),
          partialContent: _str(p['partialContent']),
          raw: p,
        );
      case MothershipStreamType.unknown:
        return UnknownPayload(p);
    }
  }
}

enum TextChannel { assistant, thinking }

class SessionStartPayload extends MothershipPayload {
  const SessionStartPayload({this.responseId});
  final String? responseId;
}

class SessionChatPayload extends MothershipPayload {
  const SessionChatPayload({required this.chatId});
  final String chatId;
}

class SessionTitlePayload extends MothershipPayload {
  const SessionTitlePayload({required this.title});
  final String title;
}

class SessionTracePayload extends MothershipPayload {
  const SessionTracePayload({required this.requestId, this.spanId});
  final String requestId;
  final String? spanId;
}

class TextPayload extends MothershipPayload {
  const TextPayload({
    required this.channel,
    required this.text,
    this.textOffset,
  });
  final TextChannel channel;
  final String text;
  final int? textOffset;
}

/// `ui` of a tool call frame.
@immutable
class ToolUi {
  const ToolUi({
    this.hidden = false,
    this.internal = false,
    this.clientExecutable = false,
    this.simExecutable = false,
    this.inbandOwned = false,
  });

  factory ToolUi.fromJson(Object? json) {
    final m = _map(json);
    if (m == null) return const ToolUi();
    return ToolUi(
      hidden: m['hidden'] == true,
      internal: m['internal'] == true,
      clientExecutable: m['clientExecutable'] == true,
      simExecutable: m['simExecutable'] == true,
      inbandOwned: m['inbandOwned'] == true,
    );
  }

  final bool hidden;
  final bool internal;
  final bool clientExecutable;
  final bool simExecutable;
  final bool inbandOwned;
}

class ToolCallPayload extends MothershipPayload {
  const ToolCallPayload({
    required this.toolCallId,
    required this.toolName,
    this.executor,
    this.mode,
    this.arguments,
    this.partial = false,
    this.status,
    this.activityDescription,
    this.execName,
    this.ui = const ToolUi(),
    this.replay = false,
    this.workspaceId,
    this.deadlineMs,
    this.integrationDescription,
  });

  final String toolCallId;
  final String toolName;

  /// `go`, `sim` or `client`.
  final String? executor;

  /// `sync` or `async`.
  final String? mode;
  final Map<String, Object?>? arguments;
  final bool partial;

  /// `awaiting_approval` (permission gate) or `executing` (allowed).
  final String? status;
  final String? activityDescription;
  final String? execName;
  final ToolUi ui;
  final bool replay;
  final String? workspaceId;
  final int? deadlineMs;
  final String? integrationDescription;
}

class ToolArgsDeltaPayload extends MothershipPayload {
  const ToolArgsDeltaPayload({
    required this.toolCallId,
    required this.toolName,
    required this.argumentsDelta,
    this.executor,
    this.mode,
  });
  final String toolCallId;
  final String toolName;
  final String? executor;
  final String? mode;
  final String argumentsDelta;
}

class ToolResultPayload extends MothershipPayload {
  const ToolResultPayload({
    required this.toolCallId,
    required this.toolName,
    required this.success,
    this.executor,
    this.mode,
    this.status,
    this.output,
    this.error,
    this.replay = false,
  });
  final String toolCallId;
  final String toolName;
  final String? executor;
  final String? mode;
  final bool success;
  final String? status;
  final Object? output;
  final String? error;
  final bool replay;
}

/// A synthetic `prepare_file_edit` preview frame (`session/contract.ts:30-131`).
class FilePreviewPayload extends MothershipPayload {
  const FilePreviewPayload({
    required this.toolCallId,
    required this.previewPhase,
    required this.raw,
  });
  final String toolCallId;

  /// `file_preview_start|target|edit_meta|content|complete`.
  final String previewPhase;
  final Map<String, Object?> raw;
}

class SpanPayload extends MothershipPayload {
  const SpanPayload({required this.kind, this.event, this.agent, this.data});

  /// `subagent`, `structured_result` or `subagent_result`.
  final String kind;

  /// `start` or `end` for `subagent`.
  final String? event;
  final String? agent;
  final Map<String, Object?>? data;
}

class ResourceEventPayload extends MothershipPayload {
  const ResourceEventPayload({
    required this.op,
    required this.resource,
    this.readOnly = false,
    this.effectId,
    this.replay = false,
  });

  /// `upsert`, `remove`, `clear_view` or `refresh`.
  final String op;
  final Map<String, Object?> resource;
  final bool readOnly;
  final String? effectId;
  final bool replay;
}

class RunPayload extends MothershipPayload {
  const RunPayload({required this.kind, required this.raw});
  final String kind;
  final Map<String, Object?> raw;
}

class ErrorPayload extends MothershipPayload {
  const ErrorPayload({
    this.message,
    this.error,
    this.displayMessage,
    this.code,
    this.provider,
    this.data,
  });
  final String? message;
  final String? error;
  final String? displayMessage;
  final String? code;
  final String? provider;
  final Map<String, Object?>? data;

  /// `mothershipErrorText`: displayMessage ‖ message ‖ error.
  String? get text {
    for (final candidate in [displayMessage, message, error]) {
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    return null;
  }
}

class CompletePayload extends MothershipPayload {
  const CompletePayload({
    required this.status,
    required this.raw,
    this.reason,
    this.response,
    this.partialContent,
  });

  /// `complete`, `error` or `cancelled`.
  final String status;
  final String? reason;
  final Map<String, Object?>? response;
  final String? partialContent;
  final Map<String, Object?> raw;

  /// `response.async_pause`: not a turn terminal.
  bool get isAsyncPause => response?.containsKey('async_pause') ?? false;
}

class UnknownPayload extends MothershipPayload {
  const UnknownPayload(this.raw);
  final Map<String, Object?> raw;
}

/// `isTerminalStreamStatus`: complete | error | cancelled.
bool isTerminalStreamStatus(String? status) =>
    status == 'complete' || status == 'error' || status == 'cancelled';

// Reconnect batch ------------------------------------------------------------

@immutable
class StreamBatchEvent {
  const StreamBatchEvent({
    required this.eventId,
    required this.streamId,
    required this.envelope,
    required this.raw,
  });

  final int eventId;
  final String streamId;
  final MothershipStreamEnvelope envelope;

  /// The validated envelope JSON, for re-serialisation (fixtures, replay).
  final Map<String, Object?> raw;
}

/// `GET /api/mothership/chat/stream?...&batch=true` (spec §3.3), parsed like
/// `parseStreamBatchResponse` (`home/hooks/stream-protocol.ts:61-115`).
@immutable
class StreamBatch {
  const StreamBatch({
    required this.success,
    required this.events,
    required this.status,
    this.previewSessions = const [],
    this.chatId,
    this.desktopToolsOnDevice = false,
  });

  /// Throws [FormatException] for a non-object body and
  /// [MothershipStreamSchemaError] for an invalid event.
  factory StreamBatch.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Invalid stream batch response');
    }
    final rawEvents = json['events'] is List
        ? json['events']! as List
        : const <Object?>[];
    final events = <StreamBatchEvent>[];
    for (var i = 0; i < rawEvents.length; i++) {
      final entry = rawEvents[i];
      final n = i + 1;
      if (entry is! Map) {
        throw MothershipStreamSchemaError(
          '${MothershipStreamSchemaError.prefix} Reconnect batch event $n is not an object.',
        );
      }
      final eventId = entry['eventId'];
      if (eventId is! num ||
          !eventId.isFinite ||
          entry['streamId'] is! String) {
        throw MothershipStreamSchemaError(
          '${MothershipStreamSchemaError.prefix} Reconnect batch event $n is missing required metadata.',
        );
      }
      final envelope = MothershipStreamEnvelope.fromJson(
        entry['event'],
        strict: true,
        context: 'Reconnect batch event $n.',
      );
      events.add(
        StreamBatchEvent(
          eventId: eventId.toInt(),
          streamId: entry['streamId']! as String,
          envelope: envelope,
          raw: Map<String, Object?>.from(entry['event']! as Map),
        ),
      );
    }
    final previews = json['previewSessions'];
    return StreamBatch(
      success: json['success'] == true,
      events: events,
      previewSessions: previews is List
          ? [for (final s in previews) ?_map(s)]
          : const [],
      status: _str(json['status']) ?? 'unknown',
      chatId: _nonEmpty(json['chatId']),
      desktopToolsOnDevice: json['desktopToolsOnDevice'] == true,
    );
  }

  final bool success;
  final List<StreamBatchEvent> events;
  final List<Map<String, Object?>> previewSessions;

  /// The run status (`active`, `complete`, `error`, `cancelled`, ...).
  final String status;
  final String? chatId;
  final bool desktopToolsOnDevice;

  bool get isTerminal => isTerminalStreamStatus(status);

  /// `resolveChatIdFromStreamBatch`.
  String? get resolvedChatId {
    if (chatId != null) return chatId;
    for (final event in events) {
      final streamChat = event.envelope.stream.chatId;
      if (streamChat != null && streamChat.isNotEmpty) return streamChat;
      final payload = MothershipPayload.of(event.envelope);
      if (payload is SessionChatPayload) return payload.chatId;
    }
    return null;
  }
}

// Chats ----------------------------------------------------------------------

/// One `GET /api/mothership/chats` row mapped like `mapChat`
/// (`hooks/queries/mothership-chats.ts:301-315`).
@immutable
class MothershipChatSummary {
  const MothershipChatSummary({
    required this.id,
    required this.name,
    required this.mode,
    required this.isActive,
    required this.isUnread,
    required this.isPinned,
    this.title,
    this.updatedAt,
    this.activeStreamId,
    this.lastSeenAt,
    this.deletedAt,
  });

  factory MothershipChatSummary.fromJson(Map<String, Object?> json) {
    final updatedAt = DateTime.tryParse('${json['updatedAt']}');
    final lastSeen = _str(json['lastSeenAt']);
    final lastSeenAt = lastSeen == null ? null : DateTime.tryParse(lastSeen);
    final active = _str(json['activeStreamId']);
    final title = _str(json['title']);
    final deleted = _str(json['deletedAt']);
    return MothershipChatSummary(
      id: '${json['id']}',
      title: title,
      name: title ?? 'New chat',
      mode: _str(json['mode']) ?? 'agent',
      updatedAt: updatedAt,
      activeStreamId: active,
      lastSeenAt: lastSeenAt,
      isActive: active != null,
      isUnread:
          active == null &&
          (lastSeenAt == null ||
              (updatedAt != null && updatedAt.isAfter(lastSeenAt))),
      isPinned: json['pinned'] == true,
      deletedAt: deleted == null ? null : DateTime.tryParse(deleted),
    );
  }

  final String id;
  final String? title;
  final String name;
  final String mode;
  final DateTime? updatedAt;
  final String? activeStreamId;
  final DateTime? lastSeenAt;
  final bool isActive;
  final bool isUnread;
  final bool isPinned;
  final DateTime? deletedAt;
}

/// A persisted tool call inside a stored content block.
@immutable
class PersistedToolCall {
  const PersistedToolCall({
    required this.id,
    required this.name,
    required this.state,
    this.displayTitle,
    this.params,
    this.result,
    this.calledBy,
    this.activityDescription,
  });

  factory PersistedToolCall.fromJson(Map<String, Object?> json) {
    final result = _map(json['result']);
    return PersistedToolCall(
      id: '${json['id']}',
      name: _str(json['name']) ?? '',
      state: _str(json['state']) ?? 'error',
      displayTitle: _str(_map(json['display'])?['title']),
      params: _map(json['params']),
      result: result == null
          ? null
          : (
              success: result['success'] == true,
              output: result['output'],
              error: _str(result['error']),
            ),
      calledBy: _str(json['calledBy']),
      activityDescription: _str(json['activityDescription']),
    );
  }

  final String id;
  final String name;

  /// `pending|executing|awaiting_approval|success|error|cancelled|skipped|
  /// rejected|aborted|failed|interrupted`.
  final String state;
  final String? displayTitle;
  final Map<String, Object?>? params;
  final ({bool success, Object? output, String? error})? result;
  final String? calledBy;
  final String? activityDescription;
}

/// A stored content block (`lib/api/contracts/copilot-messages.ts:12-67`).
@immutable
class PersistedContentBlock {
  const PersistedContentBlock({required this.type, required this.raw});

  factory PersistedContentBlock.fromJson(Map<String, Object?> json) =>
      PersistedContentBlock(type: _str(json['type']) ?? 'text', raw: json);

  final String type;
  final Map<String, Object?> raw;

  String? get lane => _str(raw['lane']);
  String? get agent => _str(raw['agent']);
  String? get channel => _str(raw['channel']);
  String? get lifecycle => _str(raw['lifecycle']);
  String? get status => _str(raw['status']);
  String? get content => _str(raw['content']);
  String? get name => _str(raw['name']);
  String? get error => _str(raw['error']);
  String? get parentToolCallId => _str(raw['parentToolCallId']);
  String? get spanId => _str(raw['spanId']);
  String? get parentSpanId => _str(raw['parentSpanId']);
  int? get timestamp => _int(raw['timestamp']);
  int? get endedAt => _int(raw['endedAt']);
  Map<String, Object?>? get task => _map(raw['task']);
  PersistedToolCall? get toolCall {
    final tc = _map(raw['toolCall']);
    return tc == null ? null : PersistedToolCall.fromJson(tc);
  }
}

/// `PersistedMessage` (`lib/mothership/chat/persisted-message.ts:119-131`).
@immutable
class PersistedMessage {
  const PersistedMessage({
    required this.id,
    required this.role,
    required this.content,
    this.timestamp,
    this.requestMode,
    this.origin,
    this.requestId,
    this.contentBlocks,
    this.fileAttachments,
    this.contexts,
  });

  factory PersistedMessage.fromJson(Map<String, Object?> json) {
    final blocks = json['contentBlocks'];
    final files = json['fileAttachments'];
    final contexts = json['contexts'];
    return PersistedMessage(
      id: '${json['id']}',
      role: json['role'] == 'user' ? 'user' : 'assistant',
      content: _str(json['content']) ?? '',
      timestamp: _str(json['timestamp']),
      requestMode: _str(json['requestMode']),
      origin: _str(json['origin']),
      requestId: _str(json['requestId']),
      contentBlocks: blocks is List
          ? [
              for (final b in blocks)
                if (_map(b) case final m?) PersistedContentBlock.fromJson(m),
            ]
          : null,
      fileAttachments: files is List
          ? [
              for (final f in files)
                if (_map(f) case final m?) FileAttachmentForApi.fromJson(m),
            ]
          : null,
      contexts: contexts is List ? [for (final c in contexts) ?_map(c)] : null,
    );
  }

  final String id;

  /// `user` or `assistant`.
  final String role;
  final String content;
  final String? timestamp;
  final String? requestMode;
  final String? origin;
  final String? requestId;
  final List<PersistedContentBlock>? contentBlocks;
  final List<FileAttachmentForApi>? fileAttachments;
  final List<Map<String, Object?>>? contexts;

  Map<String, Object?> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'timestamp': ?timestamp,
    'requestMode': ?requestMode,
    'origin': ?origin,
    'requestId': ?requestId,
    if (contentBlocks != null)
      'contentBlocks': [for (final b in contentBlocks!) b.raw],
    if (fileAttachments != null)
      'fileAttachments': [for (final f in fileAttachments!) f.toJson()],
    'contexts': ?contexts,
  };
}

/// `GET /api/mothership/chats/[chatId]` → `chat` (spec §3.6, `parseChatHistory`).
@immutable
class MothershipChatHistory {
  const MothershipChatHistory({
    required this.id,
    required this.messages,
    this.title,
    this.mode = 'agent',
    this.activeStreamId,
    this.resources = const [],
    this.effort,
    this.streamSnapshotStatus,
    this.streamSnapshotEvents = const [],
    this.olderCursor,
    this.windowStartCursor,
  });

  /// Throws [FormatException] on the shapes `parseChatHistory` rejects.
  factory MothershipChatHistory.fromJson(Object? json) {
    if (json is! Map || json['chat'] is! Map) {
      throw const FormatException(
        'Invalid chat response: chat must be an object',
      );
    }
    final chat = json['chat']! as Map;
    if (chat['id'] is! String) {
      throw const FormatException(
        'Invalid chat response: chat.id must be a string',
      );
    }
    if (chat['messages'] is! List) {
      throw const FormatException(
        'Invalid chat response: chat.messages must be an array',
      );
    }
    final snapshot = _map(chat['streamSnapshot']);
    final snapshotEvents = snapshot?['events'];
    return MothershipChatHistory(
      id: chat['id']! as String,
      title: _str(chat['title']),
      mode: _str(chat['mode']) ?? 'agent',
      messages: [
        for (final m in chat['messages']! as List)
          if (_map(m) case final map?) PersistedMessage.fromJson(map),
      ],
      activeStreamId: _str(chat['activeStreamId']),
      resources: chat['resources'] is List
          ? [for (final r in chat['resources']! as List) ?_map(r)]
          : const [],
      effort: _str(chat['effort']),
      streamSnapshotStatus: snapshot == null
          ? null
          : (_str(snapshot['status']) ?? 'unknown'),
      streamSnapshotEvents: snapshotEvents is List
          ? [for (final e in snapshotEvents) ?_map(e)]
          : const [],
      olderCursor: _str(chat['olderCursor']),
      windowStartCursor: _str(chat['windowStartCursor']),
    );
  }

  final String id;
  final String? title;
  final String mode;
  final List<PersistedMessage> messages;
  final String? activeStreamId;
  final List<Map<String, Object?>> resources;
  final String? effort;
  final String? streamSnapshotStatus;
  final List<Map<String, Object?>> streamSnapshotEvents;
  final String? olderCursor;
  final String? windowStartCursor;

  MothershipChatHistory copyWith({
    List<PersistedMessage>? messages,
    String? activeStreamId,
    bool clearActiveStreamId = false,
    List<Map<String, Object?>>? resources,
    String? effort,
    String? title,
    String? olderCursor,
  }) => MothershipChatHistory(
    id: id,
    title: title ?? this.title,
    mode: mode,
    messages: messages ?? this.messages,
    activeStreamId: clearActiveStreamId
        ? null
        : (activeStreamId ?? this.activeStreamId),
    resources: resources ?? this.resources,
    effort: effort ?? this.effort,
    streamSnapshotStatus: streamSnapshotStatus,
    streamSnapshotEvents: streamSnapshotEvents,
    olderCursor: olderCursor ?? this.olderCursor,
    windowStartCursor: windowStartCursor,
  );

  /// `joinCachedOlderMessages`: a reloaded window joined to the older
  /// messages [cached] holds before it.
  MothershipChatHistory joinedWithCached(MothershipChatHistory? cached) {
    if (cached == null || windowStartCursor == null || messages.isEmpty) {
      return this;
    }
    final firstId = messages.first.id;
    final overlap = cached.messages.indexWhere((m) => m.id == firstId);
    if (overlap <= 0) return this;
    return MothershipChatHistory(
      id: id,
      title: title,
      mode: mode,
      messages: [...cached.messages.sublist(0, overlap), ...messages],
      activeStreamId: activeStreamId,
      resources: resources,
      effort: effort,
      streamSnapshotStatus: streamSnapshotStatus,
      streamSnapshotEvents: streamSnapshotEvents,
      olderCursor: cached.olderCursor,
      windowStartCursor: windowStartCursor,
    );
  }
}

/// `FileAttachmentForApi` (`P:118-125`).
@immutable
class FileAttachmentForApi {
  const FileAttachmentForApi({
    required this.id,
    required this.key,
    required this.filename,
    required this.mediaType,
    required this.size,
    this.path,
  });

  factory FileAttachmentForApi.fromJson(Map<String, Object?> json) =>
      FileAttachmentForApi(
        id: '${json['id']}',
        key: '${json['key']}',
        filename: '${json['filename']}',
        mediaType: '${json['media_type']}',
        size: _int(json['size']) ?? 0,
        path: _str(json['path']),
      );

  /// Whether [json] has the shape `isFileAttachmentForApi` accepts.
  static bool isValid(Object? json) =>
      json is Map &&
      json['id'] is String &&
      json['key'] is String &&
      json['filename'] is String &&
      json['media_type'] is String &&
      json['size'] is num &&
      (json['path'] == null || json['path'] is String);

  final String id;
  final String key;
  final String filename;
  final String mediaType;
  final int size;
  final String? path;

  Map<String, Object?> toJson() => {
    'id': id,
    'key': key,
    'filename': filename,
    'media_type': mediaType,
    'size': size,
    'path': ?path,
  };

  @override
  bool operator ==(Object other) =>
      other is FileAttachmentForApi &&
      other.id == id &&
      other.key == key &&
      other.filename == filename &&
      other.mediaType == mediaType &&
      other.size == size &&
      other.path == path;

  @override
  int get hashCode => Object.hash(id, key, filename, mediaType, size, path);
}

/// The JSON body of `POST /api/mothership/chat`, built exactly as React does
/// (`use-chat.ts:3946-3984`, spec §3.1): optional fields are omitted, never
/// sent as null; `model`/`clientCapabilities` are never sent.
@immutable
class MothershipSendRequest {
  const MothershipSendRequest({
    required this.message,
    required this.userMessageId,
    required this.userTimezone,
    this.workspaceId,
    this.organizationId,
    this.chatId,
    this.fileAttachments = const [],
    this.resourceAttachments,
    this.contexts = const [],
    this.mode,
    this.assistantSearch,
    this.assistantSearchLevel,
    this.workflowId,
    this.desktopCapabilities = const {},
    this.modelSelection,
    this.effort,
  }) : assert(
         (workspaceId == null) != (organizationId == null),
         'exactly one owner',
       );

  final String message;
  final String userMessageId;
  final String userTimezone;
  final String? workspaceId;
  final String? organizationId;
  final String? chatId;
  final List<FileAttachmentForApi> fileAttachments;
  final List<Map<String, Object?>>? resourceAttachments;
  final List<Map<String, Object?>> contexts;

  /// `agent`, `assistant` or `plan`.
  final String? mode;
  final Map<String, Object?>? assistantSearch;
  final String? assistantSearchLevel;
  final String? workflowId;
  final Map<String, Object?> desktopCapabilities;

  /// `{model, fastMode}`; only sent for non-assistant modes.
  final Map<String, Object?>? modelSelection;
  final String? effort;

  bool get isAssistant => mode == 'assistant';

  Map<String, Object?> toJson() => {
    'message': message,
    if (organizationId != null)
      'organizationId': organizationId
    else
      'workspaceId': workspaceId,
    'userMessageId': userMessageId,
    'createNewChat': chatId == null,
    'chatId': ?chatId,
    if (fileAttachments.isNotEmpty)
      'fileAttachments': [for (final f in fileAttachments) f.toJson()],
    'resourceAttachments': ?resourceAttachments,
    if (contexts.isNotEmpty) 'contexts': contexts,
    'mode': ?mode,
    'assistantSearch': ?assistantSearch,
    if (isAssistant && assistantSearchLevel != null)
      'assistantSearchLevel': assistantSearchLevel,
    if (!isAssistant && workflowId != null) 'workflowId': workflowId,
    ...desktopCapabilities,
    'userTimezone': userTimezone,
    if (!isAssistant) ...{
      'modelSelection': ?modelSelection,
      'effort': ?effort,
    },
  };
}

/// `{aborted, settled, forceReleased?}` of the abort route.
@immutable
class MothershipAbortResult {
  const MothershipAbortResult({
    required this.aborted,
    required this.settled,
    this.forceReleased = false,
  });

  factory MothershipAbortResult.fromJson(Object? json) {
    final m = _map(json) ?? const {};
    return MothershipAbortResult(
      aborted: m['aborted'] == true,
      settled: m['settled'] == true,
      forceReleased: m['forceReleased'] == true,
    );
  }

  final bool aborted;
  final bool settled;
  final bool forceReleased;
}

/// The four tool-permission decisions (`copilot.ts:71-93`). "Deny" in the
/// brief is [skip]; there is no explicit deny (spec ambiguity 7).
enum ToolPermissionDecision {
  allow('allow'),
  allowChat('allow_chat'),
  alwaysAllow('always_allow'),
  skip('skip')
  ;

  const ToolPermissionDecision(this.wire);
  final String wire;
}

@immutable
class ToolPermissionResult {
  const ToolPermissionResult({
    required this.toolCallId,
    required this.decision,
    required this.applied,
  });
  final String toolCallId;
  final String decision;

  /// `false` when another tab answered first.
  final bool applied;
}

/// `task_status` type (`events/route.ts:25-37`).
enum TaskStatusType { started, completed, created, deleted, renamed, updated }

/// One `event: task_status` frame of `/api/mothership/events`, parsed like
/// `parseChatStatusEventPayload` (unknown types drop the `type` only).
@immutable
class TaskStatusEvent {
  const TaskStatusEvent({
    this.chatId,
    this.type,
    this.streamId,
    this.ownChat,
    this.timestamp,
  });

  /// `null` when [data] is not a JSON object (React logs and ignores it).
  static TaskStatusEvent? parse(Object? data) {
    if (data is! Map) return null;
    final type = data['type'];
    return TaskStatusEvent(
      chatId: _str(data['chatId']),
      type: type is String
          ? TaskStatusType.values.where((t) => t.name == type).firstOrNull
          : null,
      streamId: _str(data['streamId']),
      ownChat: data['ownChat'] is bool ? data['ownChat']! as bool : null,
      timestamp: _int(data['timestamp']),
    );
  }

  final String? chatId;
  final TaskStatusType? type;
  final String? streamId;
  final bool? ownChat;
  final int? timestamp;
}
