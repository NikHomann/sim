import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:sim_api/src/storage/key_value_store.dart';

/// Desktop [KeyValueStore]: one JSON file, rewritten atomically (temp file +
/// rename) on every write, writes serialised through a queue so concurrent
/// writers never interleave. A corrupt file is moved aside (`.corrupt`) and
/// the store starts empty instead of failing the app.
class FileKeyValueStore implements KeyValueStore {
  FileKeyValueStore(this.path, {this.maxBytes, Logger? logger})
    : _log = logger ?? Logger('sim_api.kv.file');

  final String path;

  /// Optional ceiling on the encoded file size, mirroring browser quotas.
  final int? maxBytes;
  final Logger _log;

  Map<String, Object?>? _cache;
  Future<void> _queue = Future.value();

  Future<Map<String, Object?>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final file = File(path);
    if (!file.existsSync()) return _cache = {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) return _cache = Map<String, Object?>.from(decoded);
      throw const FormatException('not an object');
    } on Object catch (error) {
      _log.warning('Corrupt key-value file at $path; starting empty', error);
      try {
        await file.rename('$path.corrupt');
      } on FileSystemException {
        // Leave it; the next write overwrites it.
      }
      return _cache = {};
    }
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _flush(Map<String, Object?> values) async {
    final encoded = jsonEncode(values);
    final limit = maxBytes;
    if (limit != null && encoded.length > limit) {
      throw const KeyValueQuotaExceededError('<file>');
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    final temp = File('$path.tmp');
    await temp.writeAsString(encoded, flush: true);
    await temp.rename(path);
  }

  @override
  Future<Object?> read(String key) =>
      _serialized(() async => (await _load())[key]);

  @override
  Future<void> write(String key, Object? value) => _serialized(() async {
    final values = await _load();
    final previous = values[key];
    final had = values.containsKey(key);
    values[key] = jsonDecode(jsonEncode(value));
    try {
      await _flush(values);
    } on KeyValueQuotaExceededError {
      if (had) {
        values[key] = previous;
      } else {
        values.remove(key);
      }
      throw KeyValueQuotaExceededError(key);
    }
  });

  @override
  Future<void> delete(String key) => _serialized(() async {
    final values = await _load();
    if (values.remove(key) != null || values.containsKey(key)) {
      await _flush(values);
    }
  });

  @override
  Future<List<String>> keys({String? prefix}) => _serialized(
    () async => (await _load()).keys
        .where((k) => prefix == null || k.startsWith(prefix))
        .toList(),
  );

  @override
  Future<void> clear() => _serialized(() async {
    _cache = {};
    await _flush({});
  });
}
