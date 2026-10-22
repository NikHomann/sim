import 'package:flutter/foundation.dart';
import 'package:sim_app/features/chat/engine/stores/drafts_store.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';
import 'package:sim_app/features/chat/input/model/composer_models.dart';

/// One saved draft (`DraftPayload`).
@immutable
class ComposerDraft {
  const ComposerDraft({
    this.text = '',
    this.fileAttachments = const [],
    this.contexts = const [],
    this.searchQuery,
  });

  static ComposerDraft? fromJson(Object? json) {
    if (json is! Map) return null;
    final text = json['text'];
    final files = json['fileAttachments'];
    final contexts = json['contexts'];
    final searchQuery = json['searchQuery'];
    return ComposerDraft(
      text: text is String ? text : '',
      fileAttachments: [
        if (files is List)
          for (final f in files) ?ComposerFileAttachment.fromJson(f),
      ],
      contexts: [
        if (contexts is List)
          for (final c in contexts) ?ChatContext.fromJson(c),
      ],
      searchQuery: searchQuery is String ? searchQuery : null,
    );
  }

  final String text;
  final List<ComposerFileAttachment> fileAttachments;
  final List<ChatContext> contexts;

  /// Kept verbatim for Search-tab drafts written by the React app.
  final String? searchQuery;

  /// `isEmpty`: an empty draft deletes its key.
  bool get isEmpty =>
      text.isEmpty &&
      searchQuery == null &&
      fileAttachments.isEmpty &&
      contexts.isEmpty;

  Map<String, Object?> toJson() => {
    'text': text,
    'searchQuery': ?searchQuery,
    if (fileAttachments.isNotEmpty)
      'fileAttachments': [for (final f in fileAttachments) f.toJson()],
    if (contexts.isNotEmpty) 'contexts': [for (final c in contexts) c.toJson()],
  };
}

/// The composer's view of the one drafts store,
/// [MothershipDraftsStore] (`stores/mothership-drafts/store.ts`: the
/// zustand-persist envelope `{"state":{"drafts":{…}},"version":1}` under
/// `mothership-drafts:v1`, kept in memory and written whole). This class only
/// converts between [ComposerDraft] and the engine's [DraftPayload]; reads
/// and writes go through the shared store so the composer, the engine and
/// the React app see the same entries.
class ComposerDraftStore {
  ComposerDraftStore(this.store);

  static const String storageKey = MothershipDraftsStore.storageKey;
  static const int version = MothershipDraftsStore.version;

  /// `<workspaceId>:<chatId|'new'>`. A chat created in place keeps writing
  /// under `…:new` until the host remounts the composer with the chat id
  /// (upstream quirk, mirrored).
  static String draftKey(String workspaceId, String? chatId) =>
      homeDraftKey(workspaceId, chatId);

  /// The shared store.
  final MothershipDraftsStore store;

  static DraftPayload _toPayload(ComposerDraft draft) =>
      DraftPayload.fromJson(draft.toJson()) ?? DraftPayload(text: draft.text);

  /// The draft at [key], or `null`.
  Future<ComposerDraft?> read(String key) async {
    final payload = store.draft(key);
    return payload == null ? null : ComposerDraft.fromJson(payload.toJson());
  }

  /// `setDraft`: an empty draft deletes the key.
  Future<void> write(String key, ComposerDraft draft) async =>
      store.setDraft(key, _toPayload(draft));

  /// `clearDraft`.
  Future<void> clear(String key) async => store.clearDraft(key);
}

/// The 200ms trailing save of `user-input.tsx:218-261` over the engine's
/// [DraftAutosaver]: [schedule] replaces the pending payload and restarts
/// the timer; [flush] writes it now (unmount); [cancel] drops it (submit).
class DraftAutosave {
  DraftAutosave(
    this._store, {
    this.delay = const Duration(milliseconds: 200),
  });

  final ComposerDraftStore _store;
  final Duration delay;
  DraftAutosaver? _saver;
  bool _pending = false;

  bool get hasPending => _pending;

  void schedule(String key, ComposerDraft draft) {
    var saver = _saver;
    if (saver == null || saver.key != key) {
      saver?.flush();
      saver = _saver = DraftAutosaver(_store.store, key, debounce: delay);
    }
    _pending = true;
    saver.save(ComposerDraftStore._toPayload(draft));
  }

  void flush() {
    _pending = false;
    _saver?.flush();
  }

  /// Drops the pending save without writing it (submit; the composer
  /// clears the draft itself).
  void cancel() {
    _pending = false;
    _saver?.cancel();
  }
}
