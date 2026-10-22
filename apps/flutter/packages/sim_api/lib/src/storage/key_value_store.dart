import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

/// The store refused a write because its quota is exhausted
/// (`QuotaExceededError` on IndexedDB, the configured ceiling elsewhere).
class KeyValueQuotaExceededError implements Exception {
  const KeyValueQuotaExceededError(this.key, {this.cause});

  final String key;
  final Object? cause;

  @override
  String toString() => 'KeyValueQuotaExceededError($key)';
}

/// Persistent key/value storage of JSON-encodable values (plan §4.1):
/// console entries, undo stacks, drafts, autosave.
///
/// Implementations: [InMemoryKeyValueStore] (tests), the JSON-file store on
/// desktop and the IndexedDB store on web (`createPlatformKeyValueStore`).
abstract class KeyValueStore {
  /// The decoded value, `null` when absent or unreadable.
  Future<Object?> read(String key);

  /// Writes a JSON-encodable [value]. Throws [KeyValueQuotaExceededError]
  /// when the store is full; the previous value stays.
  Future<void> write(String key, Object? value);

  Future<void> delete(String key);

  /// Every key, or those starting with [prefix].
  Future<List<String>> keys({String? prefix});

  Future<void> clear();
}

/// Volatile store; [maxBytes] simulates a quota for tests.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore({this.maxBytes});

  final int? maxBytes;
  final Map<String, String> _values = {};

  int get usedBytes =>
      _values.entries.fold(0, (sum, e) => sum + e.key.length + e.value.length);

  @override
  Future<Object?> read(String key) async {
    final raw = _values[key];
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String key, Object? value) async {
    final encoded = jsonEncode(value);
    final limit = maxBytes;
    if (limit != null) {
      final current = _values[key];
      final projected =
          usedBytes -
          (current == null ? 0 : key.length + current.length) +
          key.length +
          encoded.length;
      if (projected > limit) throw KeyValueQuotaExceededError(key);
    }
    _values[key] = encoded;
  }

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<List<String>> keys({String? prefix}) async => _values.keys
      .where((k) => prefix == null || k.startsWith(prefix))
      .toList();

  @override
  Future<void> clear() async => _values.clear();

  /// Plants a raw (possibly corrupt) value, for tests.
  void plantRaw(String key, String raw) => _values[key] = raw;
}

/// A typed view of a [KeyValueStore] under a key prefix.
///
/// Decoding failures (a value written by an older version, a corrupt entry)
/// are logged, the entry is dropped and `null` returned, so a bad record can
/// never keep the app from starting.
class KeyValueNamespace<T> {
  KeyValueNamespace({
    required KeyValueStore store,
    required String prefix,
    required Object? Function(T value) encode,
    required T Function(Object? json) decode,
    Logger? logger,
  }) : _store = store,
       _prefix = prefix,
       _encode = encode,
       _decode = decode,
       _log = logger ?? Logger('sim_api.kv');

  final KeyValueStore _store;
  final String _prefix;
  final Object? Function(T value) _encode;
  final T Function(Object? json) _decode;
  final Logger _log;

  String _key(String key) => '$_prefix$key';

  Future<T?> read(String key) async {
    final raw = await _store.read(_key(key));
    if (raw == null) return null;
    try {
      return _decode(raw);
    } on Object catch (error) {
      _log.warning('Dropping unreadable value at ${_key(key)}', error);
      await _store.delete(_key(key));
      return null;
    }
  }

  Future<void> write(String key, T value) =>
      _store.write(_key(key), _encode(value));

  Future<void> delete(String key) => _store.delete(_key(key));

  /// Keys of this namespace without the prefix.
  Future<List<String>> keys() async {
    final all = await _store.keys(prefix: _prefix);
    return all.map((k) => k.substring(_prefix.length)).toList();
  }

  Future<void> clear() async {
    for (final key in await _store.keys(prefix: _prefix)) {
      await _store.delete(key);
    }
  }
}
