import 'dart:convert';

import 'package:sim_api/src/storage/shared_web_state.dart';
import 'package:web/web.dart' as web;

SharedWebState createSharedWebState() => BrowserSharedWebState();

/// [SharedWebState] on the browser's `localStorage` and `document.cookie`.
class BrowserSharedWebState implements SharedWebState {
  web.Storage get _storage => web.window.localStorage;

  String? _read(String key) {
    try {
      return _storage.getItem(key);
    } on Object {
      return null;
    }
  }

  void _write(String key, String? value) {
    try {
      if (value == null) {
        _storage.removeItem(key);
      } else {
        _storage.setItem(key, value);
      }
    } on Object {
      // Storage blocked (private mode, quota): the value stays in the app.
    }
  }

  @override
  String? readTheme() => _read(SharedWebState.themeKey);

  /// Writes the theme and dispatches the synthetic `storage` event the React
  /// theme util fires so listeners in the same document update too.
  @override
  void writeTheme(String? theme) {
    final oldValue = _read(SharedWebState.themeKey);
    _write(SharedWebState.themeKey, theme);
    web.window.dispatchEvent(
      web.StorageEvent(
        'storage',
        web.StorageEventInit(
          key: SharedWebState.themeKey,
          oldValue: oldValue,
          newValue: theme,
          storageArea: _storage,
        ),
      ),
    );
  }

  @override
  int? readSidebarWidth() {
    final raw = _read(SharedWebState.sidebarStateKey);
    if (raw == null) return null;
    try {
      return sidebarWidthFromEnvelope(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  @override
  void writeSidebarWidth(int width) {
    _write(
      SharedWebState.sidebarStateKey,
      jsonEncode({
        'state': {'sidebarWidth': width},
        'version': 0,
      }),
    );
  }

  @override
  void clearSidebarWidth() => _write(SharedWebState.sidebarStateKey, null);

  /// The cookie; when it is absent, a legacy `isCollapsed` persisted in
  /// `sidebar-state` seeds it once (`app/layout.tsx:146-151`).
  @override
  bool readSidebarCollapsed() {
    final cookie = web.document.cookie;
    if (hasSidebarCollapsedCookie(cookie)) {
      return sidebarCollapsedFromCookie(cookie);
    }
    final raw = _read(SharedWebState.sidebarStateKey);
    if (raw == null) return false;
    try {
      final legacy = legacyCollapsedFromEnvelope(jsonDecode(raw));
      if (legacy == null) return false;
      writeSidebarCollapsed(collapsed: legacy);
      return legacy;
    } on FormatException {
      return false;
    }
  }

  @override
  void writeSidebarCollapsed({required bool collapsed}) {
    web.document.cookie =
        '${SharedWebState.sidebarCollapsedCookie}=${collapsed ? '1' : '0'}; path=/; max-age=31536000; samesite=lax';
  }

  @override
  Stream<SharedStateChange> get changes => web.EventStreamProviders.storageEvent
      .forTarget(web.window)
      .where(
        (event) =>
            event.key == SharedWebState.themeKey ||
            event.key == SharedWebState.sidebarStateKey,
      )
      .map(
        (event) => SharedStateChange(key: event.key!, newValue: event.newValue),
      );
}
