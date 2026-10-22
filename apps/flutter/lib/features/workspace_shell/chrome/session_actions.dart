import 'dart:developer' as developer;

import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart' as app;

/// The session-ending flows of the shell, with the collaborators injectable:
/// `recoverFromStaleSession` (`lib/auth/stale-session-recovery.ts:19-29`),
/// `signOutAndRedirect`'s reset half (`lib/auth/sign-out.ts:8-21`) and the
/// admin `stopImpersonating` mutation. Navigation is left to the caller.
class SessionActions {
  SessionActions({
    required Future<void> Function() signOut,
    required Future<bool> Function({bool preserveRecentImpersonations})
    clearUserData,
    required Future<void> Function() stopImpersonating,
  }) : _signOut = signOut,
       _clearUserData = clearUserData,
       _stopImpersonating = stopImpersonating;

  /// The production wiring from the locator.
  factory SessionActions.fromLocator() => SessionActions(
    signOut: () => app.locator<AuthRepository>().signOut(),
    clearUserData: app.clearUserData,
    stopImpersonating: () => app.locator<SimHttpClient>().send(
      method: 'POST',
      path: '/api/auth/admin/stop-impersonating',
      body: const <String, Object?>{},
    ),
  );

  final Future<void> Function() _signOut;
  final Future<bool> Function({bool preserveRecentImpersonations})
  _clearUserData;
  final Future<void> Function() _stopImpersonating;

  /// Sign-out (clears the auth cookies server-side) then wipe the user data;
  /// `false` when the sign-out request failed (nothing is wiped then, so a
  /// retry starts from the same state). The caller then goes to `/login`.
  Future<bool> recoverFromStaleSession() async {
    try {
      await _signOut();
    } on Object catch (error) {
      developer.log(
        'Stale session sign-out failed',
        name: 'sim_app.session',
        error: error,
      );
      return false;
    }
    await _clearUserData();
    return true;
  }

  /// `signOutAndRedirect`: sign-out and the reset run together; returns
  /// whether the in-memory reset succeeded (else the caller should fall back
  /// to a full page load of `/login?fromLogout=true`).
  Future<bool> signOut() async {
    final results = await Future.wait<bool>([
      _signOut().then((_) => true, onError: (Object _) => false),
      _clearUserData(),
    ]);
    return results[1];
  }

  /// `useStopImpersonating` then `clearUserData({preserveRecentImpersonations:
  /// true})`. Throws when the mutation fails (nothing is cleared then).
  Future<void> stopImpersonating() async {
    await _stopImpersonating();
    await _clearUserData(preserveRecentImpersonations: true);
  }
}
