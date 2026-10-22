/// The `isApplyingRemoteChange` ref of `use-collaborative-workflow.ts`.
///
/// While a remote broadcast is being applied to local state, every local
/// write path is a no-op (the store mutation must not be echoed back as a new
/// queued operation) and a nested remote broadcast is ignored.
class RemoteApplyGuard {
  bool _applying = false;

  /// Whether a remote change is being applied right now.
  bool get isApplying => _applying;

  /// Runs [apply] with the guard raised, lowering it even when [apply] throws.
  /// Returns `false` without running when the guard is already raised, which
  /// is how upstream handlers skip a re-entrant broadcast.
  bool run(void Function() apply) {
    if (_applying) return false;
    _applying = true;
    try {
      apply();
    } finally {
      _applying = false;
    }
    return true;
  }

  /// Lowers the guard unconditionally (upstream does this on
  /// `workflow-deleted` and `access-revoked` for the active workflow).
  void release() {
    _applying = false;
  }
}
