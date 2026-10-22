/// Cross-surface send handoffs (spec chat-engine §5):
/// - `sessionStorage['copilot_active_stream:queued-send-handoff']`
///   (`QueuedSendHandoffState`, 5 min TTL) and its claim
///   `copilot_active_stream:queued-send-handoff-claim` (`{id, ownerId,
///   claimedAt}`, 30 s TTL), port of `home/hooks/send-handoff.ts`;
/// - `localStorage['sim_mothership_handoff']` (`MothershipHandoffStorage`,
///   60 s, consumed once), port of `lib/core/utils/browser-storage.ts`.
library;

import 'dart:convert';
import 'dart:math';

import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/storage/chat_storage.dart';
import 'package:sim_app/features/chat/engine/stores/queue_store.dart';

const queuedSendHandoffKey = 'copilot_active_stream:queued-send-handoff';
const queuedSendHandoffClaimKey =
    'copilot_active_stream:queued-send-handoff-claim';
const queuedSendHandoffTtl = Duration(minutes: 5);
const queuedSendHandoffClaimTtl = Duration(seconds: 30);
const mothershipHandoffKey = 'sim_mothership_handoff';
const mothershipHandoffMaxAge = Duration(seconds: 60);

/// `QueuedSendHandoffState`.
class QueuedSendHandoffState {
  const QueuedSendHandoffState({
    required this.seed,
    required this.userMessageId,
    required this.payload,
    required this.requestedAt,
    this.workspaceId,
    this.organizationId,
    this.resolveAttempts,
    this.admissionUnknown,
  });

  final QueuedSendHandoffSeed seed;
  final String? workspaceId;
  final String? organizationId;
  final String userMessageId;
  final SendPayload payload;
  final int requestedAt;
  final int? resolveAttempts;
  final bool? admissionUnknown;

  String get id => seed.id;

  Map<String, Object?> toJson() {
    final payloadJson = payload.payloadJson()..remove('content');
    return {
      'id': seed.id,
      'chatId': ?seed.chatId,
      'workspaceId': ?workspaceId,
      'organizationId': ?organizationId,
      'supersededStreamId': seed.supersededStreamId,
      if (seed.stopRequired) 'stopRequired': true,
      'admissionUnknown': ?admissionUnknown,
      'userMessageId': userMessageId,
      'message': payload.content,
      ...payloadJson,
      'requestedAt': requestedAt,
      'resolveAttempts': ?resolveAttempts,
    };
  }

  /// `readQueuedSendHandoffState` validation; `null` when invalid.
  static QueuedSendHandoffState? fromJson(Object? json) {
    if (json is! Map) return null;
    final chatId = json['chatId'] is String ? json['chatId']! as String : null;
    final superseded = json['supersededStreamId'] is String
        ? json['supersededStreamId']! as String
        : null;
    final ws = json['workspaceId'];
    final org = json['organizationId'];
    if (json['id'] is! String ||
        (ws is! String && org is! String) ||
        (ws is String && org is String) ||
        json['userMessageId'] is! String ||
        json['message'] is! String ||
        json['requestedAt'] is! num ||
        (chatId == null && superseded == null)) {
      return null;
    }
    final message = QueuedMessage.fromJson({
      ...Map<String, Object?>.from(json),
      'content': json['message'],
    });
    final mode = json['requestMode'];
    final attempts = json['resolveAttempts'];
    return QueuedSendHandoffState(
      seed: QueuedSendHandoffSeed(
        id: json['id']! as String,
        chatId: chatId,
        supersededStreamId: superseded,
        stopRequired: json['stopRequired'] == true,
      ),
      workspaceId: ws is String ? ws : null,
      organizationId: org is String ? org : null,
      userMessageId: json['userMessageId']! as String,
      payload: SendPayload(
        content: json['message']! as String,
        fileAttachments: message?.fileAttachments,
        contexts: message?.contexts,
        requestMode: mode == 'agent' || mode == 'assistant' || mode == 'plan'
            ? mode! as String
            : null,
        assistantSearch: message?.assistantSearch,
        assistantSearchLevel: message?.assistantSearchLevel,
      ),
      requestedAt: (json['requestedAt']! as num).toInt(),
      resolveAttempts: attempts is num && attempts.isFinite && attempts > 0
          ? attempts.toInt()
          : null,
      admissionUnknown: json['admissionUnknown'] is bool
          ? json['admissionUnknown']! as bool
          : null,
    );
  }
}

/// `MothershipHandoff`: a one-shot seed for the next new-chat surface.
class MothershipHandoff {
  const MothershipHandoff({
    this.message,
    this.contexts = const [],
    this.fileAttachments,
    this.resumeUserMessageId,
    this.requestMode,
    this.assistantSearch,
    this.assistantSearchLevel,
  });

  final String? message;
  final List<Map<String, Object?>> contexts;
  final List<FileAttachmentForApi>? fileAttachments;
  final String? resumeUserMessageId;
  final String? requestMode;
  final Map<String, Object?>? assistantSearch;
  final String? assistantSearchLevel;
}

/// Reads and writes both handoff records with the React formats.
class SendHandoffStore {
  SendHandoffStore({
    required ChatStorage session,
    required ChatStorage local,
    int Function()? nowMs,
    String Function()? idGenerator,
  }) : _session = session,
       _local = local,
       _now = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _id = idGenerator ?? _randomId;

  final ChatStorage _session;
  final ChatStorage _local;
  final int Function() _now;
  final String Function() _id;

  static String _randomId() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Object? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  /// `readQueuedSendHandoffState`: expired records are removed (with a
  /// claim on them).
  QueuedSendHandoffState? readQueued() {
    final state = QueuedSendHandoffState.fromJson(
      _decode(_session.getItem(queuedSendHandoffKey)),
    );
    if (state == null) return null;
    if (_now() - state.requestedAt > queuedSendHandoffTtl.inMilliseconds) {
      _session.removeItem(queuedSendHandoffKey);
      if (readClaim() == state.id) {
        _session.removeItem(queuedSendHandoffClaimKey);
      }
      return null;
    }
    return state;
  }

  void writeQueued(QueuedSendHandoffState state) =>
      _session.setItem(queuedSendHandoffKey, jsonEncode(state.toJson()));

  /// Clears the record, only when it still is [expectedId]'s if given.
  void clearQueued([String? expectedId]) {
    if (expectedId != null) {
      final current = readQueued();
      if (current != null && current.id != expectedId) return;
    }
    _session.removeItem(queuedSendHandoffKey);
  }

  ({String id, String ownerId, int claimedAt})? _claim() {
    final json = _decode(_session.getItem(queuedSendHandoffClaimKey));
    if (json == null) return null;
    if (json is! Map ||
        json['id'] is! String ||
        json['ownerId'] is! String ||
        json['claimedAt'] is! num) {
      _session.removeItem(queuedSendHandoffClaimKey);
      return null;
    }
    final claimedAt = (json['claimedAt']! as num).toInt();
    if (_now() - claimedAt > queuedSendHandoffClaimTtl.inMilliseconds) {
      _session.removeItem(queuedSendHandoffClaimKey);
      return null;
    }
    return (
      id: json['id']! as String,
      ownerId: json['ownerId']! as String,
      claimedAt: claimedAt,
    );
  }

  String? readClaim() => _claim()?.id;

  String writeClaim(String id) {
    final ownerId = _id();
    _session.setItem(
      queuedSendHandoffClaimKey,
      jsonEncode({'id': id, 'ownerId': ownerId, 'claimedAt': _now()}),
    );
    return ownerId;
  }

  bool hasClaimOwner(String id, String ownerId) {
    final claim = _claim();
    return claim?.id == id && claim?.ownerId == ownerId;
  }

  void clearClaim([String? expectedId, String? expectedOwnerId]) {
    if (expectedId != null) {
      final current = _claim();
      if (current != null &&
          (current.id != expectedId ||
              (expectedOwnerId != null &&
                  current.ownerId != expectedOwnerId))) {
        return;
      }
    }
    _session.removeItem(queuedSendHandoffClaimKey);
  }

  /// `MothershipHandoffStorage.store` for a workspace owner; chip-only
  /// handoffs accumulate contexts.
  bool storeHandoff(MothershipHandoff handoff, {required String workspaceId}) {
    final message = handoff.message?.trim();
    final hasAttachments = handoff.fileAttachments?.isNotEmpty ?? false;
    final hasMessage = message != null && message.isNotEmpty;
    if (workspaceId.isEmpty ||
        (!hasMessage && !hasAttachments && handoff.contexts.isEmpty)) {
      return false;
    }
    final contexts = hasMessage || hasAttachments
        ? handoff.contexts
        : [..._pendingContexts(workspaceId), ...handoff.contexts];
    _local.setItem(
      mothershipHandoffKey,
      jsonEncode({
        if (hasMessage || hasAttachments) 'message': message ?? '',
        'contexts': contexts,
        if (hasAttachments)
          'fileAttachments': [
            for (final f in handoff.fileAttachments!) f.toJson(),
          ],
        'resumeUserMessageId': ?handoff.resumeUserMessageId,
        'requestMode': ?handoff.requestMode,
        'assistantSearch': ?handoff.assistantSearch,
        'assistantSearchLevel': ?handoff.assistantSearchLevel,
        'workspaceId': workspaceId,
        'timestamp': _now(),
      }),
    );
    return true;
  }

  List<Map<String, Object?>> _pendingContexts(String workspaceId) {
    final data = _decode(_local.getItem(mothershipHandoffKey));
    if (data is! Map ||
        data['message'] != null ||
        (data['fileAttachments'] is List &&
            (data['fileAttachments']! as List).isNotEmpty) ||
        data['workspaceId'] != workspaceId ||
        data['organizationId'] != null) {
      return const [];
    }
    final ts = data['timestamp'];
    if (ts is! num || _now() - ts > mothershipHandoffMaxAge.inMilliseconds) {
      return const [];
    }
    final contexts = data['contexts'];
    return contexts is List
        ? [
            for (final c in contexts)
              if (c is Map) Map<String, Object?>.from(c),
          ]
        : const [];
  }

  /// `MothershipHandoffStorage.consume(workspaceId)`: another owner's record
  /// stays; this owner's is cleared before the validity checks, so it fires
  /// at most once.
  MothershipHandoff? consumeHandoff({
    required String workspaceId,
    String? requestMode,
  }) {
    final data = _decode(_local.getItem(mothershipHandoffKey));
    if (data is! Map) return null;
    final ws = data['workspaceId'];
    final org = data['organizationId'];
    if ((ws != null || org != null) && (ws != workspaceId || org != null)) {
      return null;
    }
    final storedMode =
        data['requestMode'] ?? (org != null ? 'assistant' : 'agent');
    if (requestMode != null && storedMode != requestMode) return null;
    _local.removeItem(mothershipHandoffKey);
    final contexts = data['contexts'] is List
        ? [
            for (final c in data['contexts']! as List)
              if (c is Map) Map<String, Object?>.from(c),
          ]
        : <Map<String, Object?>>[];
    final files = data['fileAttachments'] is List
        ? [
            for (final f in data['fileAttachments']! as List)
              if (FileAttachmentForApi.isValid(f))
                FileAttachmentForApi.fromJson(
                  Map<String, Object?>.from(f as Map),
                ),
          ]
        : <FileAttachmentForApi>[];
    final message = data['message'] is String
        ? data['message']! as String
        : null;
    final ts = data['timestamp'];
    if ((ws == null && org == null) ||
        ((message == null || message.isEmpty) &&
            files.isEmpty &&
            contexts.isEmpty) ||
        ts is! num ||
        _now() - ts > mothershipHandoffMaxAge.inMilliseconds) {
      return null;
    }
    final mode = data['requestMode'];
    return MothershipHandoff(
      message: (message != null && message.isNotEmpty) || files.isNotEmpty
          ? (message ?? '')
          : null,
      contexts: contexts,
      fileAttachments: files.isEmpty ? null : files,
      resumeUserMessageId: data['resumeUserMessageId'] is String
          ? data['resumeUserMessageId']! as String
          : null,
      requestMode: mode == 'agent' || mode == 'assistant' || mode == 'plan'
          ? mode! as String
          : null,
      assistantSearch: data['assistantSearch'] is Map
          ? Map<String, Object?>.from(data['assistantSearch']! as Map)
          : null,
      assistantSearchLevel: data['assistantSearchLevel'] is String
          ? data['assistantSearchLevel']! as String
          : null,
    );
  }
}
