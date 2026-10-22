import 'dart:async';
import 'dart:developer' as developer;

import 'package:sim_api/sim_api.dart';

/// [SharedWebState] off the web: the same keys (`sim-theme`, the
/// `sidebar-state` envelope, `sidebar_collapsed`) persisted in the
/// [KeyValueStore], so the theme, rail width and collapse survive a
/// relaunch (workspace-chrome.md "Collapse and persistence").
///
/// Reads are synchronous, so [load] must complete before the theme and
/// sidebar controllers read it (`bootstrap` awaits it); writes update the
/// cache at once and persist in the background.
class KeyValueSharedWebState implements SharedWebState {
  KeyValueSharedWebState(this._store);

  final KeyValueStore _store;
  String? _theme;
  int? _width;
  bool _collapsed = false;

  /// Reads the three keys; unreadable values fall back to the defaults.
  Future<void> load() async {
    try {
      final theme = await _store.read(SharedWebState.themeKey);
      _theme = theme is String ? theme : null;
      _width = sidebarWidthFromEnvelope(
        await _store.read(SharedWebState.sidebarStateKey),
      );
      _collapsed =
          await _store.read(SharedWebState.sidebarCollapsedCookie) == true;
    } on Object catch (error) {
      developer.log(
        'Reading the persisted shell state failed',
        name: 'sim_app.storage',
        error: error,
      );
    }
  }

  void _persist(String key, Object? value) {
    unawaited(
      (value == null ? _store.delete(key) : _store.write(key, value))
          .catchError(
            (Object error) => developer.log(
              'Persisting $key failed',
              name: 'sim_app.storage',
              error: error,
            ),
          ),
    );
  }

  @override
  String? readTheme() => _theme;

  @override
  void writeTheme(String? theme) {
    _theme = theme;
    _persist(SharedWebState.themeKey, theme);
  }

  @override
  int? readSidebarWidth() => _width;

  @override
  void writeSidebarWidth(int width) {
    _width = width;
    _persist(SharedWebState.sidebarStateKey, <String, Object?>{
      'state': <String, Object?>{'sidebarWidth': width},
      'version': 0,
    });
  }

  @override
  void clearSidebarWidth() {
    _width = null;
    _persist(SharedWebState.sidebarStateKey, null);
  }

  @override
  bool readSidebarCollapsed() => _collapsed;

  @override
  void writeSidebarCollapsed({required bool collapsed}) {
    _collapsed = collapsed;
    _persist(SharedWebState.sidebarCollapsedCookie, collapsed);
  }

  /// No other writer shares this store.
  @override
  Stream<SharedStateChange> get changes => const Stream.empty();
}
