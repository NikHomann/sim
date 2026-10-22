import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:sim_api/src/client/cookie_storage.dart';

/// A cookie jar attached to Dio; `null` where the browser owns the cookies.
abstract class CookieJarHandle {
  Interceptor get interceptor;

  /// Drops every cookie, in memory and in storage.
  Future<void> clear();
}

/// A persistent cookie jar on top of [storage], attached to Dio so the
/// Better Auth session cookie survives restarts of the desktop app.
CookieJarHandle? createCookieJar(CookieStorage storage) =>
    _PersistentJar(PersistCookieJar(storage: _StorageAdapter(storage)));

class _PersistentJar implements CookieJarHandle {
  _PersistentJar(this._jar) : interceptor = CookieManager(_jar);

  final PersistCookieJar _jar;

  @override
  final Interceptor interceptor;

  @override
  Future<void> clear() => _jar.deleteAll();
}

class _StorageAdapter implements Storage {
  _StorageAdapter(this._storage);

  final CookieStorage _storage;

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => _storage.read(key);

  @override
  Future<void> write(String key, String value) => _storage.write(key, value);

  @override
  Future<void> delete(String key) => _storage.delete(key);

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await _storage.delete(key);
    }
    await _storage.deleteAll();
  }
}
