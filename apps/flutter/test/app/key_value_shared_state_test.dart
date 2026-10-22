// Failure modes (review finding 7, workspace-chrome.md "Collapse and
// persistence", global-behaviours.md "Theme"): on Windows the theme, the
// rail width and the collapse flag must survive a relaunch.
// - a value written through the theme/sidebar controllers is not in the
//   key-value store, so a new process starts at 224 px, expanded, `system`
// - an unreadable stored value keeps the app from starting
// - sign-out leaves `sidebar-state` behind, or drops the collapse flag
// - the locator still wires the in-memory stub off the web

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/config.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/app/platform/key_value_shared_state.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/chrome/sidebar_controller.dart';
import 'package:sim_app/features/workspace_shell/theme/theme_mode_controller.dart';

void main() {
  test('theme, width and collapse survive a relaunch', () async {
    final store = InMemoryKeyValueStore();
    final first = KeyValueSharedWebState(store);
    await first.load();
    ThemeModeController(storage: first).setSetting(ThemeSetting.dark);
    SidebarController(storage: first)
      ..setSidebarWidth(320, viewportWidth: 1440)
      ..setCollapsed(collapsed: true);
    await pumpEventQueue();

    final relaunched = KeyValueSharedWebState(store);
    await relaunched.load();
    expect(ThemeModeController(storage: relaunched).setting, ThemeSetting.dark);
    final sidebar = SidebarController(storage: relaunched);
    expect(sidebar.storedWidth, 320);
    expect(sidebar.isCollapsed, isTrue);
    expect(
      await store.read(SharedWebState.sidebarStateKey),
      {
        'state': {'sidebarWidth': 320},
        'version': 0,
      },
      reason: 'the zustand envelope React writes',
    );
  });

  test('unreadable values fall back to the defaults', () async {
    final store = InMemoryKeyValueStore()
      ..plantRaw(SharedWebState.themeKey, '{not json')
      ..plantRaw(SharedWebState.sidebarStateKey, '"wide"');
    final state = KeyValueSharedWebState(store);
    await state.load();
    expect(state.readTheme(), isNull);
    expect(state.readSidebarWidth(), isNull);
    expect(state.readSidebarCollapsed(), isFalse);
  });

  test('sign-out removes sidebar-state, keeps theme and collapse', () async {
    final store = InMemoryKeyValueStore();
    final state = KeyValueSharedWebState(store);
    await state.load();
    final sidebar = SidebarController(storage: state)
      ..setSidebarWidth(320, viewportWidth: 1440)
      ..setCollapsed(collapsed: true);
    state.writeTheme('dark');
    await pumpEventQueue();

    await resetUserData(
      store: store,
      queryClient: QueryClient(),
      registry: UserDataResetRegistry()..register(sidebar.reset),
    );
    await pumpEventQueue();

    final relaunched = KeyValueSharedWebState(store);
    await relaunched.load();
    expect(relaunched.readSidebarWidth(), isNull);
    expect(relaunched.readSidebarCollapsed(), isTrue);
    expect(relaunched.readTheme(), 'dark');
  });

  test('the locator wires the key-value store off the web', () async {
    await configureLocator(
      const AppConfig(
        surface: AppSurface.desktop,
        backendOrigin: null,
        e2e: true,
      ),
    );
    addTearDown(locator.reset);
    await locator.unregister<KeyValueStore>();
    locator.registerSingleton<KeyValueStore>(InMemoryKeyValueStore());
    expect(locator<SharedWebState>(), isA<KeyValueSharedWebState>());
  });
}
