import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/app/router.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/chrome/paste_admission_guard.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_dirty_store.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_navigation_guard.dart';
import 'package:sim_app/features/workspace_shell/chrome/shell_services.dart';
import 'package:sim_app/features/workspace_shell/theme/theme_mode_controller.dart';
import 'package:sim_design/sim_design.dart';

/// Root widget: Sim themes (`sim-theme`, system by default, forced light on
/// the auth/public segments), the overlay host for the z-ladder with the
/// app-wide paste guard, toast stack and settings discard dialog, the
/// router (with its [ShellNavigator] in the locator), the route-change
/// toast sweep and the window-focus session refetch.
class SimApp extends StatefulWidget {
  const SimApp({super.key, this.routerBuilder});

  /// Replaces [buildRouter] (tests mount the shell routes with stubs).
  @visibleForTesting
  final GoRouter Function()? routerBuilder;

  @override
  State<SimApp> createState() => _SimAppState();
}

class _SimAppState extends State<SimApp> {
  late final GoRouter router;
  late final ThemeModeController _theme;
  late final SimToasts _toasts;
  late final SettingsDirtyStore _dirty;
  late final AppLifecycleListener _lifecycle;
  late final ShellNavigator _navigator;
  StreamSubscription<SettingsState>? _settingsSubscription;
  String _path = '/';

  @override
  void initState() {
    super.initState();
    registerWorkspaceShellServices();
    _theme = locator<ThemeModeController>();
    _toasts = locator<SimToasts>();
    _dirty = locator<SettingsDirtyStore>();
    router = (widget.routerBuilder ?? buildRouter)();
    _navigator = ShellNavigator(router: router, dirty: _dirty);
    if (locator.isRegistered<ShellNavigator>()) {
      unawaited(Future<void>.sync(locator.unregister<ShellNavigator>));
    }
    locator.registerSingleton<ShellNavigator>(_navigator);
    _path = _currentPath() ?? router.routeInformationProvider.value.uri.path;
    // The delegate, not the information provider: a redirect replaces the
    // provider's value without notifying, so only the delegate's
    // configuration knows where a redirect landed (`/login` for a
    // signed-out deep link, the workspace for `/home`).
    router.routerDelegate.addListener(_onRoute);
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(locator<SessionCubit>().onFocus()),
    );
    _settingsSubscription = locator<SettingsCubit>().stream.listen(
      (_) => _theme.reload(),
    );
    unawaited(locator<DeploymentShapeCubit>().loadPublicEnv());
  }

  @override
  void dispose() {
    router.routerDelegate.removeListener(_onRoute);
    if (locator.isRegistered<ShellNavigator>() &&
        identical(locator<ShellNavigator>(), _navigator)) {
      unawaited(Future<void>.sync(locator.unregister<ShellNavigator>));
    }
    _lifecycle.dispose();
    unawaited(_settingsSubscription?.cancel());
    router.dispose();
    super.dispose();
  }

  /// The post-redirect path, or null before the first route resolved.
  String? _currentPath() {
    final configuration = router.routerDelegate.currentConfiguration;
    return configuration.isEmpty ? null : configuration.uri.path;
  }

  /// The toast provider's pathname sweep (`toast.tsx:143-150`) and the
  /// forced-light check, on every path change (query changes keep toasts).
  void _onRoute() {
    final path = _currentPath();
    if (path == null || path == _path) return;
    _toasts.sweepRoute();
    setState(() => _path = path);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _theme,
      builder: (context, _) => MaterialApp.router(
        title: 'Sim',
        debugShowCheckedModeBanner: false,
        theme: simLightTheme(),
        darkTheme: simDarkTheme(),
        themeMode: _theme.modeFor(_path),
        routerConfig: router,
        // The transparent Material gives every page and overlay layer the
        // theme's text style (no debug underline) without painting.
        builder: (context, child) => PasteAdmissionGuard(
          toasts: _toasts,
          child: SimTextFieldDefaults(
            contextMenuBuilder: pasteGuardedContextMenuBuilder,
            child: Material(
              type: MaterialType.transparency,
              child: SimOverlayHost(
                child: SettingsNavigationGuard(
                  store: _dirty,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      child ?? const SizedBox.shrink(),
                      SimToastStack(controller: _toasts),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
