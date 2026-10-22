import 'package:get_it/get_it.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/chrome/fullscreen_origin.dart';
import 'package:sim_app/features/workspace_shell/chrome/search_palette_controller.dart';
import 'package:sim_app/features/workspace_shell/chrome/session_actions.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_dirty_store.dart';
import 'package:sim_app/features/workspace_shell/chrome/sidebar_controller.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/global_commands.dart';
import 'package:sim_app/features/workspace_shell/theme/theme_mode_controller.dart';
import 'package:sim_design/sim_design.dart';

/// Registers the shell's long-lived client state (plan §4.1: sidebar, theme,
/// toasts, modals, settings dirty state) in [getIt] unless already present,
/// and hooks the per-user ones into the user-data reset registry so a
/// sign-out returns them to their initial state. Idempotent; tests register
/// their own instances first.
void registerWorkspaceShellServices([GetIt? getIt]) {
  final gi = getIt ?? locator;
  void lazy<T extends Object>(T Function() factory) {
    if (!gi.isRegistered<T>()) gi.registerLazySingleton<T>(factory);
  }

  SharedWebState storage() => gi.isRegistered<SharedWebState>()
      ? gi<SharedWebState>()
      : _fallbackStorage;

  lazy<SimToasts>(() => SimToasts.instance);
  lazy<SidebarController>(() => SidebarController(storage: storage()));
  lazy<ThemeModeController>(() => ThemeModeController(storage: storage()));
  lazy<SearchPaletteController>(SearchPaletteController.new);
  lazy<SettingsDirtyStore>(SettingsDirtyStore.new);
  lazy<FullscreenOriginStore>(FullscreenOriginStore.new);
  lazy<GlobalCommandRegistry>(GlobalCommandRegistry.new);
  lazy<SessionActions>(SessionActions.fromLocator);

  if (gi.isRegistered<UserDataResetRegistry>() &&
      !gi.isRegistered<_ShellResetsRegistered>()) {
    gi.registerSingleton<_ShellResetsRegistered>(
      const _ShellResetsRegistered(),
    );
    gi<UserDataResetRegistry>().register(() {
      gi<SidebarController>().reset();
      gi<SearchPaletteController>().reset();
      gi<SettingsDirtyStore>().reset();
      gi<FullscreenOriginStore>().reset();
      gi<SimToasts>().dismissAll();
    });
  }
}

final SharedWebState _fallbackStorage = MemorySharedWebState();

/// Marker so the resets are registered once per locator generation.
class _ShellResetsRegistered {
  const _ShellResetsRegistered();
}
