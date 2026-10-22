import 'package:flutter/foundation.dart';

/// One editor's registration (`SettingsGuardState`).
@immutable
class SettingsGuard {
  const SettingsGuard({
    required this.isDirty,
    this.navigationBlocked = false,
    this.onDiscard,
  });

  final bool isDirty;
  final bool navigationBlocked;
  final VoidCallback? onDiscard;
}

/// `useSettingsDirtyStore` (`stores/settings/dirty/store.ts`): every settings
/// editor registers a guard; [requestLeave] runs the leave at once when
/// clean, refuses while any guard blocks navigation, and otherwise stashes
/// it for the discard dialog (`SettingsNavigationGuard`).
class SettingsDirtyStore extends ChangeNotifier {
  final Map<String, SettingsGuard> _guards = {};
  VoidCallback? _pendingLeave;

  bool get isDirty => _guards.values.any((g) => g.isDirty);
  bool get navigationBlocked => _guards.values.any((g) => g.navigationBlocked);

  /// The confirmed-leave action waiting on the dialog.
  bool get hasPendingLeave => _pendingLeave != null;

  void setGuard(String id, SettingsGuard guard) {
    _guards[id] = guard;
    _summarize();
  }

  void removeGuard(String id) {
    _guards.remove(id);
    _summarize();
  }

  /// `summarizeGuards`: a pending leave is dropped once nothing is dirty or
  /// navigation became blocked.
  void _summarize() {
    if (!isDirty || navigationBlocked) _pendingLeave = null;
    notifyListeners();
  }

  /// Returns `true` when [leave] ran immediately. History traversals pass
  /// `discardOnConfirm: false` (the draft is discarded only once the
  /// traversal is observed).
  bool requestLeave(VoidCallback leave, {bool discardOnConfirm = true}) {
    if (navigationBlocked) return false;
    if (!isDirty) {
      leave();
      return true;
    }
    _pendingLeave = () {
      if (discardOnConfirm) discardDrafts();
      leave();
    };
    notifyListeners();
    return false;
  }

  /// Runs the stashed leave (after discarding drafts when allowed).
  void confirmLeave() {
    if (navigationBlocked) return;
    final pending = _pendingLeave;
    if (pending == null) return;
    _pendingLeave = null;
    notifyListeners();
    pending();
  }

  /// Calls every dirty guard's `onDiscard`.
  void discardDrafts() {
    for (final guard in _guards.values.toList()) {
      if (guard.isDirty) guard.onDiscard?.call();
    }
  }

  /// Keeps editing: drops the pending leave, keeps the dirty state.
  void cancelLeave() {
    if (_pendingLeave == null) return;
    _pendingLeave = null;
    notifyListeners();
  }

  /// Sign-out / surface reset.
  void reset() {
    _guards.clear();
    _pendingLeave = null;
    notifyListeners();
  }
}
