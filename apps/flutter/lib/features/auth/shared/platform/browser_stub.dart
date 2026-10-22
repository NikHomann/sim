/// Non-web fallback: no document to navigate, storage kept in memory for the
/// lifetime of the process (the desktop app never shares it with React).
class BrowserWindow {
  const BrowserWindow();

  /// `window.location.origin`; null when there is no page.
  String? get origin => null;

  /// `window.location.search` (with the leading `?`), empty when no page.
  String get search => '';

  /// `window.location.assign(url)` — nothing to do off the web.
  void assign(String url) {}

  /// `window.location.replace(url)`.
  void replace(String url) {}

  /// `window.location.reload()`.
  void reload() {}

  /// `window.close()`.
  void close() {}
}

/// In-memory stand-in for `sessionStorage` / `localStorage`.
class BrowserStorage {
  BrowserStorage._(this._values);

  static final BrowserStorage session = BrowserStorage._(<String, String>{});
  static final BrowserStorage local = BrowserStorage._(<String, String>{});

  final Map<String, String> _values;

  String? getItem(String key) => _values[key];

  void setItem(String key, String value) => _values[key] = value;

  void removeItem(String key) => _values.remove(key);
}
