import 'package:sim_app/features/auth/shared/platform/browser.dart';

/// The `sessionStorage` keys the React auth pages hand each other
/// (`apps/sim/app/(auth)/auth-redirect.ts`, `login-form.tsx`, `invite.tsx`).
abstract final class AuthStorageKeys {
  /// Email carried from login/signup to `/verify`.
  static const String verificationEmail = 'verificationEmail';

  /// `POST_AUTH_REDIRECT_STORAGE_KEY`: the validated destination carried
  /// through the verify hop.
  static const String postAuthRedirectUrl = 'postAuthRedirectUrl';

  /// `inviteToken:<id>`: the invitation token surviving the login round trip.
  static String inviteToken(String inviteId) => 'inviteToken:$inviteId';
}

/// Key-value store shared with the React tab state (browser `sessionStorage`
/// on web, process memory elsewhere). The auth cubits read and write through
/// this interface so tests can substitute a map.
abstract class AuthSessionStore {
  String? read(String key);

  void write(String key, String value);

  void remove(String key);
}

/// `sessionStorage`-backed store.
class BrowserSessionStore implements AuthSessionStore {
  const BrowserSessionStore();

  @override
  String? read(String key) => BrowserStorage.session.getItem(key);

  @override
  void write(String key, String value) =>
      BrowserStorage.session.setItem(key, value);

  @override
  void remove(String key) => BrowserStorage.session.removeItem(key);
}

/// `localStorage`-backed store (the OAuth chat-attempt record).
class BrowserLocalStore implements AuthSessionStore {
  const BrowserLocalStore();

  @override
  String? read(String key) => BrowserStorage.local.getItem(key);

  @override
  void write(String key, String value) =>
      BrowserStorage.local.setItem(key, value);

  @override
  void remove(String key) => BrowserStorage.local.removeItem(key);
}

/// In-memory store for tests and the desktop fallback.
class MemoryAuthSessionStore implements AuthSessionStore {
  MemoryAuthSessionStore([Map<String, String>? initial])
    : values = <String, String>{...?initial};

  final Map<String, String> values;

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;

  @override
  void remove(String key) => values.remove(key);
}
