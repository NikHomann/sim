/// The per-chat send queue, port of `stores/mothership-queue/store.ts`
/// (spec chat-engine §4.11, §5).
///
/// Persisted to `sessionStorage['mothership-queue']` in the zustand persist
/// envelope `{"state":{"queues":{<chatKey>:[...]}},"version":0}`; `editing`,
/// `cleared` and `migratedTo` stay in memory. On read, legacy fields are
/// migrated and the admission guard applied, exactly as `restoredQueues`.
library;

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/storage/chat_storage.dart';

/// Prefix of a new-chat queue key before the chat exists
/// (`lib/desktop/chat-scope.ts:19`).
const pendingChatKeyPrefix = 'pending::';

/// `QueuedSendHandoffSeed`: the stream a Send-now must stop first.
class QueuedSendHandoffSeed extends Equatable {
  const QueuedSendHandoffSeed({
    required this.id,
    required this.supersededStreamId,
    this.chatId,
    this.stopRequired = false,
  });

  static QueuedSendHandoffSeed? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    return QueuedSendHandoffSeed(
      id: json['id']! as String,
      chatId: json['chatId'] is String ? json['chatId']! as String : null,
      supersededStreamId: json['supersededStreamId'] is String
          ? json['supersededStreamId']! as String
          : null,
      stopRequired: json['stopRequired'] == true,
    );
  }

  final String id;
  final String? chatId;
  final String? supersededStreamId;
  final bool stopRequired;

  QueuedSendHandoffSeed copyWith({
    String? chatId,
    String? supersededStreamId,
    bool? stopRequired,
  }) => QueuedSendHandoffSeed(
    id: id,
    chatId: chatId ?? this.chatId,
    supersededStreamId: supersededStreamId ?? this.supersededStreamId,
    stopRequired: stopRequired ?? this.stopRequired,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'chatId': ?chatId,
    'supersededStreamId': supersededStreamId,
    if (stopRequired) 'stopRequired': true,
  };

  @override
  List<Object?> get props => [id, chatId, supersededStreamId, stopRequired];
}

/// `SendRetry`: the attempt and the epoch ms before which it is not sent.
class SendRetry extends Equatable {
  const SendRetry({required this.attempt, required this.notBefore});

  final int attempt;
  final int notBefore;

  Map<String, Object?> toJson() => {
    'attempt': attempt,
    'notBefore': notBefore,
  };

  @override
  List<Object?> get props => [attempt, notBefore];
}

/// Why a queued message waits: for the user, or for the browser to be online.
enum QueueHold { user, online }

/// `SendPayload`: what a chat send carries.
class SendPayload extends Equatable {
  const SendPayload({
    required this.content,
    this.fileAttachments,
    this.contexts,
    this.requestMode,
    this.assistantSearch,
    this.assistantSearchLevel,
  });

  final String content;
  final List<FileAttachmentForApi>? fileAttachments;
  final List<Map<String, Object?>>? contexts;
  final String? requestMode;
  final Map<String, Object?>? assistantSearch;
  final String? assistantSearchLevel;

  Map<String, Object?> payloadJson() => {
    'content': content,
    if (fileAttachments != null)
      'fileAttachments': [for (final f in fileAttachments!) f.toJson()],
    'contexts': ?contexts,
    'requestMode': ?requestMode,
    'assistantSearch': ?assistantSearch,
    'assistantSearchLevel': ?assistantSearchLevel,
  };

  @override
  List<Object?> get props => [
    content,
    fileAttachments,
    contexts,
    requestMode,
    assistantSearch,
    assistantSearchLevel,
  ];
}

/// `QueuedMothershipMessage`.
class QueuedMessage extends SendPayload {
  const QueuedMessage({
    required this.id,
    required super.content,
    super.fileAttachments,
    super.contexts,
    super.requestMode,
    super.assistantSearch,
    super.assistantSearchLevel,
    this.admissionUnknown,
    this.queuedSendHandoff,
    this.hold,
    this.heldSurface,
    this.retry,
    this.resumeUserMessageId,
  });

  /// Restores a stored entry, migrating the legacy fields
  /// (`withCurrentWaitFields`); `null` when it lacks `id`/`content`.
  static QueuedMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final record = Map<String, Object?>.from(json);
    final retryRequired = record.remove('retryRequired');
    final heldUntilOnline = record.remove('heldUntilOnline');
    final sendRetries = record.remove('sendRetries');
    final notBefore = record.remove('notBefore');
    final seed = record['queuedSendHandoff'];
    if (seed is Map && seed['userMessageId'] is String) {
      final rest = Map<String, Object?>.from(seed);
      record
        ..['resumeUserMessageId'] = rest.remove('userMessageId')
        ..['queuedSendHandoff'] = rest;
    }
    if (retryRequired == true && record['hold'] == null) {
      record['hold'] = heldUntilOnline == true ? 'online' : 'user';
    }
    if (sendRetries is num && notBefore is num && record['retry'] == null) {
      record['retry'] = {
        'attempt': sendRetries.toInt(),
        'notBefore': notBefore.toInt(),
      };
    }
    if (record['id'] is! String || record['content'] is! String) return null;
    final files = record['fileAttachments'];
    final contexts = record['contexts'];
    final retry = record['retry'];
    final hold = record['hold'];
    return QueuedMessage(
      id: record['id']! as String,
      content: record['content']! as String,
      fileAttachments: files is List
          ? [
              for (final f in files)
                if (FileAttachmentForApi.isValid(f))
                  FileAttachmentForApi.fromJson(
                    Map<String, Object?>.from(f as Map),
                  ),
            ]
          : null,
      contexts: contexts is List
          ? [
              for (final c in contexts)
                if (c is Map) Map<String, Object?>.from(c),
            ]
          : null,
      requestMode: record['requestMode'] is String
          ? record['requestMode']! as String
          : null,
      assistantSearch: record['assistantSearch'] is Map
          ? Map<String, Object?>.from(record['assistantSearch']! as Map)
          : null,
      assistantSearchLevel: record['assistantSearchLevel'] is String
          ? record['assistantSearchLevel']! as String
          : null,
      admissionUnknown: record['admissionUnknown'] is bool
          ? record['admissionUnknown']! as bool
          : null,
      queuedSendHandoff: QueuedSendHandoffSeed.fromJson(
        record['queuedSendHandoff'],
      ),
      hold: hold == 'user'
          ? QueueHold.user
          : hold == 'online'
          ? QueueHold.online
          : null,
      heldSurface: record['heldSurface'] is String
          ? record['heldSurface']! as String
          : null,
      retry:
          retry is Map && retry['attempt'] is num && retry['notBefore'] is num
          ? SendRetry(
              attempt: (retry['attempt']! as num).toInt(),
              notBefore: (retry['notBefore']! as num).toInt(),
            )
          : null,
      resumeUserMessageId: record['resumeUserMessageId'] is String
          ? record['resumeUserMessageId']! as String
          : null,
    );
  }

  final String id;

  /// The server may already hold [resumeUserMessageId] as sent: the entry
  /// cannot be edited into a different message.
  final bool? admissionUnknown;
  final QueuedSendHandoffSeed? queuedSendHandoff;
  final QueueHold? hold;
  final String? heldSurface;
  final SendRetry? retry;
  final String? resumeUserMessageId;

  /// `withAdmissionGuard`.
  QueuedMessage withAdmissionGuard() =>
      resumeUserMessageId == null || admissionUnknown != null
      ? this
      : copyWith(admissionUnknown: true);

  /// `withoutRequeueFields`.
  QueuedMessage withoutRequeueFields() =>
      copyWith(clearHold: true, clearRetry: true, clearHeldSurface: true);

  QueuedMessage copyWith({
    String? content,
    List<FileAttachmentForApi>? fileAttachments,
    List<Map<String, Object?>>? contexts,
    String? requestMode,
    Map<String, Object?>? assistantSearch,
    String? assistantSearchLevel,
    bool? admissionUnknown,
    QueuedSendHandoffSeed? queuedSendHandoff,
    bool clearHandoff = false,
    QueueHold? hold,
    bool clearHold = false,
    String? heldSurface,
    bool clearHeldSurface = false,
    SendRetry? retry,
    bool clearRetry = false,
    String? resumeUserMessageId,
    bool clearResume = false,
    bool replacePayload = false,
  }) => QueuedMessage(
    id: id,
    content: content ?? this.content,
    fileAttachments: replacePayload
        ? fileAttachments
        : (fileAttachments ?? this.fileAttachments),
    contexts: replacePayload ? contexts : (contexts ?? this.contexts),
    requestMode: replacePayload
        ? requestMode
        : (requestMode ?? this.requestMode),
    assistantSearch: replacePayload
        ? assistantSearch
        : (assistantSearch ?? this.assistantSearch),
    assistantSearchLevel: replacePayload
        ? assistantSearchLevel
        : (assistantSearchLevel ?? this.assistantSearchLevel),
    admissionUnknown: admissionUnknown ?? this.admissionUnknown,
    queuedSendHandoff: clearHandoff
        ? null
        : (queuedSendHandoff ?? this.queuedSendHandoff),
    hold: clearHold ? null : (hold ?? this.hold),
    heldSurface: clearHeldSurface ? null : (heldSurface ?? this.heldSurface),
    retry: clearRetry ? null : (retry ?? this.retry),
    resumeUserMessageId: clearResume
        ? null
        : (resumeUserMessageId ?? this.resumeUserMessageId),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    ...payloadJson(),
    'admissionUnknown': ?admissionUnknown,
    if (queuedSendHandoff != null)
      'queuedSendHandoff': queuedSendHandoff!.toJson(),
    if (hold != null) 'hold': hold!.name,
    'heldSurface': ?heldSurface,
    if (retry != null) 'retry': retry!.toJson(),
    'resumeUserMessageId': ?resumeUserMessageId,
  };

  @override
  List<Object?> get props => [
    ...super.props,
    id,
    admissionUnknown,
    queuedSendHandoff,
    hold,
    heldSurface,
    retry,
    resumeUserMessageId,
  ];
}

/// `QueueMigration`.
class QueueMigration {
  const QueueMigration({required this.key, required this.ahead});
  final String key;
  final List<String> ahead;
}

/// `useMothershipQueueStore`.
class MothershipQueueStore extends ChangeNotifier {
  MothershipQueueStore(this._storage) {
    _queues = restoredQueues(_read());
  }

  static const storageKey = 'mothership-queue';

  final ChatStorage _storage;
  Map<String, List<QueuedMessage>> _queues = {};
  final Map<String, String> _editing = {};
  final Map<String, int> _cleared = {};
  final Map<String, QueueMigration> _migratedTo = {};
  int _deleteCount = 0;

  Map<String, List<QueuedMessage>> get queues => Map.unmodifiable(_queues);
  Map<String, String> get editing => Map.unmodifiable(_editing);
  Map<String, int> get cleared => Map.unmodifiable(_cleared);

  List<QueuedMessage> queue(String chatKey) => _queues[chatKey] ?? const [];

  Object? _read() {
    final raw = _storage.getItem(storageKey);
    if (raw == null) return null;
    try {
      final envelope = jsonDecode(raw);
      return envelope is Map ? envelope['state'] : null;
    } on FormatException {
      return null;
    }
  }

  /// `restoredQueues`.
  static Map<String, List<QueuedMessage>> restoredQueues(Object? persisted) {
    final queues = <String, List<QueuedMessage>>{};
    final raw = persisted is Map ? persisted['queues'] : null;
    if (raw is! Map) return queues;
    for (final entry in raw.entries) {
      final list = entry.value;
      if (list is! List) continue;
      final messages = [
        for (final m in list)
          if (QueuedMessage.fromJson(m) case final message?)
            message.withAdmissionGuard(),
      ];
      if (messages.isNotEmpty) queues['${entry.key}'] = messages;
    }
    return queues;
  }

  void _persistAndNotify() {
    _storage.setItem(
      storageKey,
      jsonEncode({
        'state': {
          'queues': {
            for (final e in _queues.entries)
              e.key: [for (final m in e.value) m.toJson()],
          },
        },
        'version': 0,
      }),
    );
    notifyListeners();
  }

  void _setQueue(String chatKey, List<QueuedMessage> next) {
    if (next.isEmpty) {
      _queues.remove(chatKey);
    } else {
      _queues[chatKey] = next;
    }
  }

  void enqueue(String chatKey, QueuedMessage message) {
    if (_cleared.containsKey(chatKey)) return;
    _setQueue(chatKey, [...queue(chatKey), message.withAdmissionGuard()]);
    _persistAndNotify();
  }

  void insertAt(String chatKey, int index, QueuedMessage message) {
    if (_cleared.containsKey(chatKey)) return;
    final current = queue(chatKey);
    if (current.any((m) => m.id == message.id)) return;
    final next = [...current]
      ..insert(index.clamp(0, current.length), message.withAdmissionGuard());
    _setQueue(chatKey, next);
    _persistAndNotify();
  }

  /// In-place edit: refused for `admissionUnknown`; strips the resume id,
  /// hold, surface, retry and an unneeded handoff.
  void replaceAt(String chatKey, String id, SendPayload patch) {
    final current = queue(chatKey);
    final index = current.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final existing = current[index];
    if (existing.admissionUnknown ?? false) return;
    final handoff = existing.queuedSendHandoff;
    final next = [...current];
    next[index] = QueuedMessage(
      id: existing.id,
      content: patch.content,
      fileAttachments: patch.fileAttachments,
      contexts: patch.contexts,
      requestMode: patch.requestMode,
      assistantSearch: patch.assistantSearch,
      assistantSearchLevel: patch.assistantSearchLevel,
      admissionUnknown: existing.admissionUnknown,
      queuedSendHandoff: handoff != null && handoff.stopRequired
          ? handoff
          : null,
    );
    _setQueue(chatKey, next);
    _persistAndNotify();
  }

  void remove(String chatKey, String id) {
    final current = queue(chatKey);
    final next = current.where((m) => m.id != id).toList();
    final wasEditing = _editing[chatKey] == id;
    if (wasEditing) _editing.remove(chatKey);
    if (next.length == current.length) {
      if (wasEditing) notifyListeners();
      return;
    }
    _setQueue(chatKey, next);
    _persistAndNotify();
  }

  void setEditing(String chatKey, String? id) {
    if (id == null) {
      _editing.remove(chatKey);
    } else {
      _editing[chatKey] = id;
    }
    notifyListeners();
  }

  /// A new-chat queue moves to its chat; existing entries stay ahead.
  void migrate(String fromKey, String toKey) {
    if (fromKey == toKey) return;
    _migratedTo.putIfAbsent(
      fromKey,
      () => QueueMigration(
        key: toKey,
        ahead: [for (final m in queue(toKey)) m.id],
      ),
    );
    final fromQueue = _queues.remove(fromKey);
    final fromEditing = _editing.remove(fromKey);
    if (fromQueue == null && fromEditing == null) return;
    if (fromQueue != null &&
        fromQueue.isNotEmpty &&
        !_cleared.containsKey(toKey)) {
      _queues[toKey] = [
        ...queue(toKey),
        for (final m in fromQueue) m.copyWith(clearHeldSurface: true),
      ];
    }
    if (fromEditing != null) _editing[toKey] = fromEditing;
    _persistAndNotify();
  }

  /// `liveQueuePosition`.
  ({String chatKey, int index}) liveQueuePosition(
    String chatKey,
    List<String> aheadIds,
  ) {
    final migration = _migratedTo[chatKey];
    final key = migration?.key ?? chatKey;
    final ahead = {...aheadIds, ...?migration?.ahead};
    var index = 0;
    final q = queue(key);
    for (var i = 0; i < q.length; i++) {
      if (ahead.contains(q[i].id)) index = i + 1;
    }
    return (chatKey: key, index: index);
  }

  String liveQueueKey(String chatKey) =>
      liveQueuePosition(chatKey, const []).chatKey;

  void releaseHeldUntilOnline() {
    var released = false;
    for (final entry in _queues.entries.toList()) {
      _queues[entry.key] = [
        for (final m in entry.value)
          if (m.hold == QueueHold.online)
            (() {
              released = true;
              return m.copyWith(clearHold: true);
            })()
          else
            m,
      ];
    }
    if (released) _persistAndNotify();
  }

  void deferRetry(String chatKey, String id, SendRetry retry) {
    final current = _queues[chatKey];
    if (current == null || !current.any((m) => m.id == id)) return;
    _queues[chatKey] = [
      for (final m in current) m.id == id ? m.copyWith(retry: retry) : m,
    ];
    _persistAndNotify();
  }

  void adoptHeldSends(String toKey, String surface) {
    final adopted = <QueuedMessage>[];
    for (final entry in _queues.entries.toList()) {
      if (entry.key == toKey) continue;
      final held = entry.value.where((m) => m.heldSurface == surface).toList();
      if (held.isEmpty) continue;
      adopted.addAll(held);
      _setQueue(entry.key, [
        for (final m in entry.value)
          if (m.heldSurface != surface) m,
      ]);
    }
    if (adopted.isEmpty) return;
    _setQueue(toKey, [...queue(toKey), ...adopted]);
    _persistAndNotify();
  }

  void holdForSurface(String chatKey, String surface) {
    final q = _queues[chatKey];
    if (q == null || !q.any((m) => m.heldSurface != surface)) return;
    _queues[chatKey] = [for (final m in q) m.copyWith(heldSurface: surface)];
    _persistAndNotify();
  }

  /// A deleted chat: its queue goes and no write recreates it until the
  /// delete is lifted.
  void clearChat(String chatKey) {
    _queues.remove(chatKey);
    _editing.remove(chatKey);
    _cleared[chatKey] = ++_deleteCount;
    _persistAndNotify();
  }

  void liftDelete(String chatKey, int deleteToken) {
    if (_cleared[chatKey] == deleteToken) {
      _cleared.remove(chatKey);
      notifyListeners();
    }
  }

  void reopenRestoredChat(String chatKey) {
    if (_cleared.remove(chatKey) != null) notifyListeners();
  }

  void reset() {
    _queues.clear();
    _editing.clear();
    _cleared.clear();
    _migratedTo.clear();
    _persistAndNotify();
  }
}
