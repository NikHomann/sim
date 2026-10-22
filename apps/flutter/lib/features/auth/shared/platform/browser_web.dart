import 'package:web/web.dart' as web;

/// The real browser window.
class BrowserWindow {
  const BrowserWindow();

  String? get origin => web.window.location.origin;

  String get search => web.window.location.search;

  void assign(String url) => web.window.location.assign(url);

  void replace(String url) => web.window.location.replace(url);

  void reload() => web.window.location.reload();

  void close() => web.window.close();
}

/// `sessionStorage` / `localStorage`, every access guarded: a blocked store
/// (private mode, quota) must never take the page down.
class BrowserStorage {
  BrowserStorage._(this._storage);

  static final BrowserStorage session = BrowserStorage._(
    () => web.window.sessionStorage,
  );
  static final BrowserStorage local = BrowserStorage._(
    () => web.window.localStorage,
  );

  final web.Storage Function() _storage;

  String? getItem(String key) {
    try {
      return _storage().getItem(key);
    } on Object {
      return null;
    }
  }

  void setItem(String key, String value) {
    try {
      _storage().setItem(key, value);
    } on Object {
      // Storage blocked: the value stays in the app's state only.
    }
  }

  void removeItem(String key) {
    try {
      _storage().removeItem(key);
    } on Object {
      // Nothing to remove when storage is unavailable.
    }
  }
}
