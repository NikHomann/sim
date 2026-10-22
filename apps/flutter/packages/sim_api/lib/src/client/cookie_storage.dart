import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the desktop cookie jar keeps its serialised cookies.
///
/// Kept separate from `cookie_jar`'s own `Storage` so the web build never
/// imports `dart:io`; the io adapter wraps this into a `cookie_jar` storage.
abstract class CookieStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// In-memory cookies: tests and the fallback when secure storage fails.
class MemoryCookieStorage implements CookieStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deleteAll() async => _values.clear();
}

/// Cookies under `flutter_secure_storage` (DPAPI on Windows), keyed with a
/// prefix so other secure values of the app are never touched.
class SecureCookieStorage implements CookieStorage {
  SecureCookieStorage({
    FlutterSecureStorage? storage,
    this.prefix = 'sim.cookies.',
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final String prefix;

  @override
  Future<String?> read(String key) => _storage.read(key: '$prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$prefix$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: '$prefix$key');

  @override
  Future<void> deleteAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(prefix)) await _storage.delete(key: key);
    }
  }
}
