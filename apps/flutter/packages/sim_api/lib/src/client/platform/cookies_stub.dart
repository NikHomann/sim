import 'package:dio/dio.dart';
import 'package:sim_api/src/client/cookie_storage.dart';

/// A cookie jar attached to Dio; `null` where the browser owns the cookies.
abstract class CookieJarHandle {
  Interceptor get interceptor;

  /// Drops every cookie, in memory and in storage.
  Future<void> clear();
}

/// The browser owns the cookies (`withCredentials`), so no jar.
CookieJarHandle? createCookieJar(CookieStorage storage) => null;
