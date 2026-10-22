/// Synchronous string storage for the chat stores (spec chat-engine §5).
///
/// On web the stores read and write the browser's `localStorage` and
/// `sessionStorage` under the exact React keys, so a tab can move between
/// the React and Flutter apps without losing a queue, a draft or a model
/// pick. Off the web the same keys live in the [KeyValueStore] (local) or in
/// memory (session: a tab session ends with the process).
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/storage/platform/browser_storage.dart'
    as platform;

/// The subset of the Web Storage API the stores use. Failures (quota,
/// blocked storage) are swallowed and logged, as the React adapters do.
abstract class ChatStorage {
  String? getItem(String key);
  void setItem(String key, String value);
  void removeItem(String key);
}

/// Volatile storage (tests, desktop `sessionStorage`).
class MemoryChatStorage implements ChatStorage {
  final Map<String, String> values = {};

  @override
  String? getItem(String key) => values[key];

  @override
  void setItem(String key, String value) => values[key] = value;

  @override
  void removeItem(String key) => values.remove(key);
}

/// [ChatStorage] over a [KeyValueStore] off the web: reads are served from a
/// cache that [load] fills; writes update the cache at once and persist in
/// the background (the pattern of `KeyValueSharedWebState`).
class KeyValueChatStorage implements ChatStorage {
  KeyValueChatStorage(this._store, {this.prefix = 'chat-storage:'});

  final KeyValueStore _store;
  final String prefix;
  final Map<String, String> _cache = {};

  /// Loads every key under [prefix]; unreadable values are skipped.
  Future<void> load() async {
    try {
      for (final key in await _store.keys(prefix: prefix)) {
        final value = await _store.read(key);
        if (value is String) _cache[key.substring(prefix.length)] = value;
      }
    } on Object catch (error) {
      developer.log('chat storage load', name: 'sim_app.chat', error: error);
    }
  }

  @override
  String? getItem(String key) => _cache[key];

  @override
  void setItem(String key, String value) {
    _cache[key] = value;
    unawaited(
      _store.write('$prefix$key', value).catchError((Object error) {
        developer.log('chat storage write', name: 'sim_app.chat', error: error);
      }),
    );
  }

  @override
  void removeItem(String key) {
    _cache.remove(key);
    unawaited(_store.delete('$prefix$key'));
  }
}

/// The browser's `localStorage` and `sessionStorage` on web; `null` off
/// the web (callers build [KeyValueChatStorage] / [MemoryChatStorage]).
ChatStorages? browserChatStorages() => platform.browserChatStorages();

/// The two stores of the running platform.
class ChatStorages {
  const ChatStorages({required this.local, required this.session});

  /// The browser stores on web, else [fallback] for local and memory for
  /// session.
  factory ChatStorages.forPlatform({required ChatStorage fallback}) =>
      browserChatStorages() ??
      ChatStorages(local: fallback, session: MemoryChatStorage());

  /// Both in memory (tests).
  factory ChatStorages.memory() =>
      ChatStorages(local: MemoryChatStorage(), session: MemoryChatStorage());

  final ChatStorage local;
  final ChatStorage session;
}
