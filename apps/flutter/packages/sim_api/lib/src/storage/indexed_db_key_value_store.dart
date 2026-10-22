import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:logging/logging.dart';
import 'package:sim_api/src/storage/key_value_store.dart';
import 'package:web/web.dart' as web;

/// Web [KeyValueStore] on IndexedDB through `package:web`, one object store
/// of JSON strings keyed by name (the shape `idb-keyval` uses upstream, in
/// its own database so both apps keep their own entries).
class IndexedDbKeyValueStore implements KeyValueStore {
  IndexedDbKeyValueStore({
    this.databaseName = 'sim-flutter-kv',
    this.storeName = 'keyval',
    Logger? logger,
  }) : _log = logger ?? Logger('sim_api.kv.idb');

  final String databaseName;
  final String storeName;
  final Logger _log;
  Future<web.IDBDatabase>? _db;

  Future<web.IDBDatabase> _open() => _db ??= _openDatabase();

  Future<web.IDBDatabase> _openDatabase() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(databaseName, 1);
    request
      ..onupgradeneeded = (web.IDBVersionChangeEvent _) {
        final db = request.result! as web.IDBDatabase;
        if (!db.objectStoreNames.contains(storeName)) {
          db.createObjectStore(storeName);
        }
      }.toJS
      ..onsuccess = (web.Event _) {
        completer.complete(request.result! as web.IDBDatabase);
      }.toJS
      ..onerror = (web.Event _) {
        completer.completeError(
          StateError('IndexedDB open failed: ${request.error?.message}'),
        );
      }.toJS;
    return completer.future;
  }

  Future<JSAny?> _request(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request
      ..onsuccess = (web.Event _) {
        completer.complete(request.result);
      }.toJS
      ..onerror = (web.Event _) {
        final error = request.error;
        completer.completeError(
          _isQuotaError(error)
              ? KeyValueQuotaExceededError('', cause: error?.message)
              : StateError('IndexedDB request failed: ${error?.message}'),
        );
      }.toJS;
    return completer.future;
  }

  static bool _isQuotaError(web.DOMException? error) =>
      error != null && error.name == 'QuotaExceededError';

  web.IDBObjectStore _store(web.IDBDatabase db, String mode) =>
      db.transaction(storeName.toJS, mode).objectStore(storeName);

  @override
  Future<Object?> read(String key) async {
    final db = await _open();
    final raw = await _request(_store(db, 'readonly').get(key.toJS));
    if (raw == null) return null;
    final text = (raw as JSString).toDart;
    try {
      return jsonDecode(text);
    } on FormatException {
      _log.warning('Dropping corrupt IndexedDB value at $key');
      await delete(key);
      return null;
    }
  }

  @override
  Future<void> write(String key, Object? value) async {
    final db = await _open();
    try {
      await _request(
        _store(db, 'readwrite').put(jsonEncode(value).toJS, key.toJS),
      );
    } on KeyValueQuotaExceededError catch (error) {
      throw KeyValueQuotaExceededError(key, cause: error.cause);
    }
  }

  @override
  Future<void> delete(String key) async {
    final db = await _open();
    await _request(_store(db, 'readwrite').delete(key.toJS));
  }

  @override
  Future<List<String>> keys({String? prefix}) async {
    final db = await _open();
    final all = await _request(_store(db, 'readonly').getAllKeys());
    if (all == null) return const [];
    return (all as JSArray<JSAny?>).toDart
        .map((k) => (k! as JSString).toDart)
        .where((k) => prefix == null || k.startsWith(prefix))
        .toList();
  }

  @override
  Future<void> clear() async {
    final db = await _open();
    await _request(_store(db, 'readwrite').clear());
  }
}
