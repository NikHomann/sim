import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sim_api/sim_api.dart';

/// First path segments whose pages are forced light (`theme-provider.tsx:
/// 16-31`, entry-resolution.md §9). `cli` and `credential-groups` are out of
/// scope but kept so the rule matches upstream.
const Set<String> forcedLightSegments = <String>{
  'login',
  'signup',
  'reset-password',
  'sso',
  'invite',
  'verify',
  'chat',
  'resume',
  'oauth',
  'oauth-error',
  'f',
  'unsubscribe',
  'cli',
  'credential-groups',
};

/// Whether [path] (declared without the `/app` prefix) is forced light.
bool isForcedLightPath(String path) {
  final segments = Uri.parse(path).pathSegments.where((s) => s.isNotEmpty);
  if (segments.isEmpty) return false;
  return forcedLightSegments.contains(segments.first);
}

/// The stored theme (`sim-theme`): `light`, `dark` or `system`; anything
/// else (or nothing) is `system`.
ThemeSetting parseThemeSetting(String? raw) => switch (raw) {
  'light' => ThemeSetting.light,
  'dark' => ThemeSetting.dark,
  _ => ThemeSetting.system,
};

ThemeMode themeModeOf(ThemeSetting setting) => switch (setting) {
  ThemeSetting.light => ThemeMode.light,
  ThemeSetting.dark => ThemeMode.dark,
  ThemeSetting.system => ThemeMode.system,
};

/// next-themes for the app surface (`defaultTheme 'system'`, storage key
/// `sim-theme`): reads and writes the shared key through [SharedWebState]
/// (so the React app and this one agree), follows changes from other tabs
/// and from the settings sync, and resolves forced-light routes.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController({required SharedWebState storage})
    : _storage = storage,
      _setting = parseThemeSetting(storage.readTheme()) {
    _subscription = storage.changes.listen((change) {
      if (change.key == SharedWebState.themeKey) {
        _set(parseThemeSetting(change.newValue), persist: false);
      }
    });
  }

  final SharedWebState _storage;
  StreamSubscription<SharedStateChange>? _subscription;
  ThemeSetting _setting;

  ThemeSetting get setting => _setting;

  /// The app-wide mode, before forced-light routes are applied.
  ThemeMode get mode => themeModeOf(_setting);

  /// The mode for the page at [path]: light on the forced segments.
  ThemeMode modeFor(String path) =>
      isForcedLightPath(path) ? ThemeMode.light : mode;

  /// Applies [setting] and writes `sim-theme` (`syncThemeToNextThemes`).
  void setSetting(ThemeSetting setting) => _set(setting, persist: true);

  /// Re-reads `sim-theme` (after another writer updated it in this tab).
  void reload() =>
      _set(parseThemeSetting(_storage.readTheme()), persist: false);

  void _set(ThemeSetting setting, {required bool persist}) {
    if (persist) _storage.writeTheme(setting.name);
    if (setting == _setting) return;
    _setting = setting;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
