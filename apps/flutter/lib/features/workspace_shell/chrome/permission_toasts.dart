import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_design/sim_design.dart';

/// The persistent connection toasts of `WorkspacePermissionsProvider`
/// (`workspace-permissions-provider.tsx:42-84, 139-162`): three
/// `usePersistentErrorToast` slots (realtime status, offline, join blocked),
/// each an error toast with `duration: 0` and `persistAcrossRoutes: true`.
///
/// Per slot, like the hook's id/message refs: a new message replaces the
/// slot's toast (dismiss + show), a cleared slot dismisses it, and the same
/// message is never raised again while it stays, even after the user closed
/// it. Every toast is dismissed when the shell unmounts. The offline and
/// join-blocked toasts carry their description and a "Refresh" action.
class PermissionToastsListener extends StatefulWidget {
  const PermissionToastsListener({
    required this.permissions,
    required this.toasts,
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final PermissionsCubit permissions;
  final SimToasts toasts;

  /// `window.location.reload()` upstream.
  final VoidCallback onRefresh;
  final Widget child;

  @override
  State<PermissionToastsListener> createState() =>
      _PermissionToastsListenerState();
}

class _PermissionToastsListenerState extends State<PermissionToastsListener> {
  StreamSubscription<List<PermissionToast>>? _subscription;

  /// What each slot last raised (`shownMessageRef`) and its toast id
  /// (`toastIdRef`); kept after a user dismissal.
  final Map<PermissionToastSlot, (PermissionToast, String)> _shown = {};

  @override
  void initState() {
    super.initState();
    // Mounting happens during a build; the toast stack rebuilds on show.
    scheduleMicrotask(() {
      if (mounted) _apply(widget.permissions.state.toasts);
    });
    _subscription = widget.permissions.toasts.listen(_apply);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    final ids = [for (final (_, id) in _shown.values) id];
    final toasts = widget.toasts;
    _shown.clear();
    // Disposal runs while the tree is locked; the toast stack rebuilds on
    // dismissal, so the dismissals wait for the frame to finish.
    scheduleMicrotask(() => ids.forEach(toasts.dismiss));
    super.dispose();
  }

  static String? _descriptionOf(PermissionToast toast) => switch (toast) {
    PermissionToast.connectionUnavailable =>
      'Recent changes may not have been saved. Refresh to resync.',
    PermissionToast.unableToConnect =>
      'Changes cannot be saved. Refresh to retry.',
    _ => null,
  };

  static bool _hasRefresh(PermissionToast toast) =>
      toast == PermissionToast.connectionUnavailable ||
      toast == PermissionToast.unableToConnect;

  void _apply(List<PermissionToast> next) {
    for (final slot in PermissionToastSlot.values) {
      PermissionToast? desired;
      for (final toast in next) {
        if (toast.slot == slot) desired = toast;
      }
      final current = _shown[slot];
      if (current != null && current.$1 == desired) continue;
      if (current != null) {
        _shown.remove(slot);
        widget.toasts.dismiss(current.$2);
      }
      if (desired == null) continue;
      final id = widget.toasts.show(
        desired.title,
        variant: SimToastVariant.error,
        description: _descriptionOf(desired),
        action: _hasRefresh(desired)
            ? SimToastAction(label: 'Refresh', onPressed: widget.onRefresh)
            : null,
        duration: Duration.zero,
        persistAcrossRoutes: true,
      );
      _shown[slot] = (desired, id);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
