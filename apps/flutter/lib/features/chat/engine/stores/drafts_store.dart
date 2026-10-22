/// Composer drafts, port of `stores/mothership-drafts/store.ts` and the
/// draft lifecycle of `user-input.tsx:170-262` (spec chat-engine §5).
///
/// `localStorage['mothership-drafts:v1']` holds the zustand persist envelope
/// `{"state":{"drafts":{"<key>":{text, searchQuery?, fileAttachments?, contexts?}}},"version":1}`; an empty payload deletes its key; a v0
/// envelope drops the legacy `<ws>:workflow-copilot:<wf>` keys.
library;

import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/storage/chat_storage.dart';

/// `DraftPayload`.
class DraftPayload extends Equatable {
  const DraftPayload({
    required this.text,
    this.searchQuery,
    this.fileAttachments,
    this.contexts,
  });

  static DraftPayload? fromJson(Object? json) {
    if (json is! Map || json['text'] is! String) return null;
    final files = json['fileAttachments'];
    final contexts = json['contexts'];
    return DraftPayload(
      text: json['text']! as String,
      searchQuery: json['searchQuery'] is String
          ? json['searchQuery']! as String
          : null,
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
    );
  }

  final String text;
  final String? searchQuery;
  final List<FileAttachmentForApi>? fileAttachments;
  final List<Map<String, Object?>>? contexts;

  bool get isEmpty =>
      text.isEmpty &&
      searchQuery == null &&
      (fileAttachments?.isEmpty ?? true) &&
      (contexts?.isEmpty ?? true);

  Map<String, Object?> toJson() => {
    'text': text,
    'searchQuery': ?searchQuery,
    if (fileAttachments != null)
      'fileAttachments': [for (final f in fileAttachments!) f.toJson()],
    'contexts': ?contexts,
  };

  @override
  List<Object?> get props => [text, searchQuery, fileAttachments, contexts];
}

/// The Home draft key: `<workspaceId>:<chatId|'new'>` (`home.tsx:405`).
String homeDraftKey(String workspaceId, String? chatId) =>
    '$workspaceId:${chatId ?? 'new'}';

/// The copilot panel key:
/// `<workspaceId>:workflow-copilot:<workflowId>:<chatId|'new'>`.
String copilotDraftKey(String workspaceId, String workflowId, String? chatId) =>
    '$workspaceId:workflow-copilot:$workflowId:${chatId ?? 'new'}';

final _legacyCopilotKey = RegExp(r'^[^:]+:workflow-copilot:[^:]+$');

/// `useMothershipDraftsStore`.
class MothershipDraftsStore extends ChangeNotifier {
  MothershipDraftsStore(this._storage) {
    _drafts = _read();
  }

  static const storageKey = 'mothership-drafts:v1';
  static const version = 1;

  final ChatStorage _storage;
  Map<String, DraftPayload> _drafts = {};

  Map<String, DraftPayload> get drafts => Map.unmodifiable(_drafts);
  DraftPayload? draft(String key) => _drafts[key];

  Map<String, DraftPayload> _read() {
    final raw = _storage.getItem(storageKey);
    if (raw == null) return {};
    Object? envelope;
    try {
      envelope = jsonDecode(raw);
    } on FormatException {
      return {};
    }
    if (envelope is! Map) return {};
    final storedVersion = envelope['version'] is num
        ? (envelope['version']! as num).toInt()
        : 0;
    final state = envelope['state'];
    final drafts = state is Map ? state['drafts'] : null;
    if (drafts is! Map) return {};
    final out = <String, DraftPayload>{};
    for (final entry in drafts.entries) {
      final key = '${entry.key}';
      if (storedVersion < 1 && _legacyCopilotKey.hasMatch(key)) continue;
      final payload = DraftPayload.fromJson(entry.value);
      if (payload != null) out[key] = payload;
    }
    if (storedVersion < version) _write(out);
    return out;
  }

  void _write(Map<String, DraftPayload> drafts) => _storage.setItem(
    storageKey,
    jsonEncode({
      'state': {
        'drafts': {for (final e in drafts.entries) e.key: e.value.toJson()},
      },
      'version': version,
    }),
  );

  void _commit() {
    _write(_drafts);
    notifyListeners();
  }

  /// An empty payload deletes the key.
  void setDraft(String key, DraftPayload payload) {
    if (payload.isEmpty) {
      if (_drafts.remove(key) != null) _commit();
      return;
    }
    _drafts[key] = payload;
    _commit();
  }

  void clearDraft(String key) {
    if (_drafts.remove(key) != null) _commit();
  }

  /// Moves a `'new'` draft onto the chat it opened (the target wins).
  void migrateDraft(String fromKey, String toKey) {
    if (fromKey == toKey) return;
    final draft = _drafts.remove(fromKey);
    if (draft == null) return;
    _drafts.putIfAbsent(toKey, () => draft);
    _commit();
  }

  void reset() {
    _drafts = {};
    _commit();
  }
}

/// The composer's draft lifecycle (`user-input.tsx:215-262`): [restore] once
/// on mount, [save] debounced by 200 ms, [flush] on unmount, [clear] on
/// submit. Owned by the composer widget.
class DraftAutosaver {
  DraftAutosaver(
    this._store,
    this.key, {
    this.debounce = const Duration(milliseconds: 200),
  });

  final MothershipDraftsStore _store;
  final String key;
  final Duration debounce;
  Timer? _timer;
  DraftPayload? _pending;
  bool _restored = false;

  /// The stored draft, once per autosaver.
  DraftPayload? restore() {
    if (_restored) return null;
    _restored = true;
    return _store.draft(key);
  }

  void save(DraftPayload payload) {
    _pending = payload;
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    _pending = null;
    if (pending != null) _store.setDraft(key, pending);
  }

  /// Drops the pending save without writing it.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _store.clearDraft(key);
  }

  void dispose() => flush();
}
