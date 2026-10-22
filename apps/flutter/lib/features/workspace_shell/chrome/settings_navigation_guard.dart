import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/features/workspace_shell/chrome/platform/before_unload.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_dirty_store.dart';
import 'package:sim_app/features/workspace_shell/modals/confirm_modal_frame.dart';
import 'package:sim_design/sim_design.dart';

/// The app's in-app navigation, with the settings dirty guard in front of
/// every link-like navigation: the replacement for the capture-phase
/// `a[href]` click interception of `SettingsNavigationGuard`
/// (`settings-navigation-guard.tsx:13-47`).
///
/// `SimApp` registers one in the locator for the app router; sidebar rows,
/// the search palette, the switcher and the chrome navigate through
/// [ShellNavigator.of]. Programmatic `router.push`-style navigations that
/// upstream does not guard (`Mod+L` goto-logs) use [goUnguarded].
class ShellNavigator {
  ShellNavigator({required GoRouter router, SettingsDirtyStore? dirty})
    : _router = router,
      _dirty = dirty;

  /// The registered navigator, else one over the nearest [GoRouter] and the
  /// registered [SettingsDirtyStore] (widget tests without the app).
  factory ShellNavigator.of(BuildContext context) {
    if (locator.isRegistered<ShellNavigator>()) {
      return locator<ShellNavigator>();
    }
    return ShellNavigator(
      router: GoRouter.of(context),
      dirty: locator.isRegistered<SettingsDirtyStore>()
          ? locator<SettingsDirtyStore>()
          : null,
    );
  }

  final GoRouter _router;
  final SettingsDirtyStore? _dirty;

  /// The current location after redirects (path and query, no `/app`).
  Uri get currentUri {
    final configuration = _router.routerDelegate.currentConfiguration;
    return configuration.isEmpty
        ? _router.routeInformationProvider.value.uri
        : configuration.uri;
  }

  /// A link click: ignored when [location] is the current path and query
  /// (upstream skips same-URL anchors), otherwise asks the dirty guard
  /// first. Returns whether the navigation ran immediately.
  bool go(String location) {
    final current = currentUri;
    final target = Uri.parse(location);
    if (target.path == current.path && target.query == current.query) {
      return false;
    }
    final dirty = _dirty;
    if (dirty == null) {
      _router.go(location);
      return true;
    }
    return dirty.requestLeave(() => _router.go(location));
  }

  /// Navigates without the guard.
  void goUnguarded(String location) => _router.go(location);
}

/// [ShellNavigator.go] for a widget [context] with an explicit [store].
bool guardedGo(
  BuildContext context,
  String location, {
  required SettingsDirtyStore store,
}) => ShellNavigator(router: GoRouter.of(context), dirty: store).go(location);

/// `SettingsNavigationGuard`'s dialog (`shell.dirty-guard.modal`): opens the
/// "Unsaved changes" confirm whenever [store] holds a pending leave;
/// "Discard changes" runs it, "Keep editing", Escape, the close button and
/// an outside tap cancel it. On web it also arms the `beforeunload` prompt
/// while an editor is dirty or blocks navigation.
class SettingsNavigationGuard extends StatefulWidget {
  const SettingsNavigationGuard({
    required this.store,
    required this.child,
    super.key,
  });

  final SettingsDirtyStore store;
  final Widget child;

  @override
  State<SettingsNavigationGuard> createState() =>
      _SettingsNavigationGuardState();
}

class _SettingsNavigationGuardState extends State<SettingsNavigationGuard> {
  SimModalHandle<void>? _handle;
  late final void Function() _removeUnloadGuard;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_sync);
    _removeUnloadGuard = installBeforeUnloadGuard(
      () => widget.store.isDirty || widget.store.navigationBlocked,
    );
  }

  @override
  void didUpdateWidget(SettingsNavigationGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_sync);
      widget.store.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_sync);
    _removeUnloadGuard();
    _handle?.close();
    super.dispose();
  }

  void _sync() {
    final open = widget.store.hasPendingLeave;
    if (open && _handle == null) {
      _open();
    } else if (!open && _handle != null) {
      final handle = _handle;
      _handle = null;
      handle?.close();
    }
  }

  void _open() {
    final handle = openSimModal<void>(
      context,
      size: SimModalSize.sm,
      bare: true,
      semanticsLabel: 'Unsaved changes',
      builder: (context) => SimChipModalSurface(
        child: ConfirmModalFrame(
          parityId: 'shell.dirty-guard.modal',
          title: 'Unsaved changes',
          text:
              'You have unsaved changes. Are you sure you want to discard '
              'them?',
          dismissLabel: 'Keep editing',
          confirmLabel: 'Discard changes',
          onDismiss: () => SimModalScope.of(context).close(),
          onConfirm: () {
            final handle = _handle;
            _handle = null;
            handle?.close();
            widget.store.confirmLeave();
          },
        ),
      ),
    );
    _handle = handle;
    unawaited(
      handle.closed.then((_) {
        if (identical(_handle, handle)) {
          _handle = null;
          widget.store.cancelLeave();
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
