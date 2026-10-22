// Failure modes (global-behaviours.md "Theme", entry-resolution.md §9):
// - an absent or unknown `sim-theme` value is not `system`
// - a stored `dark`/`light` is ignored, or a change made in another tab (or
//   by the settings sync) does not apply without a reload
// - choosing a theme does not write `sim-theme` (the React app disagrees)
// - a forced-light segment follows the stored dark theme, or a non-forced
//   route is pinned light; the check uses more than the first segment

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/theme/theme_mode_controller.dart';

class TabStorage extends MemorySharedWebState {
  final StreamController<SharedStateChange> controller =
      StreamController<SharedStateChange>.broadcast();

  @override
  Stream<SharedStateChange> get changes => controller.stream;
}

void main() {
  test('absent or unknown stored values are system', () {
    expect(parseThemeSetting(null), ThemeSetting.system);
    expect(parseThemeSetting('sepia'), ThemeSetting.system);
    expect(parseThemeSetting('dark'), ThemeSetting.dark);
    final storage = TabStorage();
    expect(ThemeModeController(storage: storage).mode, ThemeMode.system);
  });

  test('reads, writes and follows sim-theme', () async {
    final storage = TabStorage()..writeTheme('dark');
    final theme = ThemeModeController(storage: storage);
    addTearDown(theme.dispose);
    expect(theme.mode, ThemeMode.dark);

    var notified = 0;
    theme
      ..addListener(() => notified++)
      ..setSetting(ThemeSetting.light);
    expect(storage.readTheme(), 'light');
    expect(theme.mode, ThemeMode.light);

    storage.controller.add(
      const SharedStateChange(key: SharedWebState.themeKey, newValue: 'dark'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(theme.mode, ThemeMode.dark);
    expect(storage.readTheme(), 'light', reason: 'another tab owns the write');

    storage.writeTheme('system');
    theme.reload();
    expect(theme.mode, ThemeMode.system);
    expect(notified, 3);
  });

  test('forced-light routes pin light whatever is stored', () {
    final theme = ThemeModeController(
      storage: TabStorage()..writeTheme('dark'),
    );
    addTearDown(theme.dispose);
    // Two representative forced segments (the set itself is a constant
    // mirrored from theme-provider.tsx), and the first-segment-only rule.
    expect(theme.modeFor('/login'), ThemeMode.light);
    expect(theme.modeFor('/invite/abc'), ThemeMode.light);
    expect(theme.modeFor('/home'), ThemeMode.dark);
    expect(
      theme.modeFor('/workspace/w1/chat/c1'),
      ThemeMode.dark,
      reason: 'a forced segment deeper in the path does not count',
    );
  });
}
