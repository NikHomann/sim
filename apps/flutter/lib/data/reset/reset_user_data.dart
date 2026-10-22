import 'dart:async';
import 'dart:developer' as developer;

import 'package:sim_api/sim_api.dart';

/// Keys that survive a sign-out (`stores/index.ts:34-39`).
abstract final class UserDataKeepList {
  static const nextFavicon = 'next-favicon';
  static const simTheme = 'sim-theme';
  static const simLandingTheme = 'sim-landing-theme';

  /// `RECENT_IMPERSONATIONS_STORAGE_KEY`, kept only when stopping an
  /// impersonation.
  static const recentImpersonations = 'recent-impersonations';

  /// The collapse flag is a cookie upstream, which `clearUserData` never
  /// touches; off the web it lives in the key-value store, so it is kept.
  static const sidebarCollapsed = 'sidebar_collapsed';

  static Set<String> keys({bool preserveRecentImpersonations = false}) => {
    nextFavicon,
    simTheme,
    simLandingTheme,
    sidebarCollapsed,
    if (preserveRecentImpersonations) recentImpersonations,
  };
}

/// `user-data-reset-registry.ts`: every cubit holding per-user state
/// registers its `reset()` here (the GetIt locator does it).
class UserDataResetRegistry {
  final List<FutureOr<void> Function()> _resets = [];

  void register(FutureOr<void> Function() reset) => _resets.add(reset);

  Future<void> resetAll() async {
    for (final reset in _resets) {
      await reset();
    }
  }

  int get length => _resets.length;
}

/// `clearUserData` + `resetAllStores` (spec §7, `stores/index.ts:23-64`,
/// `reset-all-stores.ts:19-59`): wipes the persisted store except the
/// keep-list, clears the tab's `sessionStorage` ([clearSessionStorage]),
/// resets every registered cubit, empties the query cache and forgets the
/// desktop cookies. Returns whether the in-memory reset
/// succeeded (callers fall back to a full document navigation otherwise).
Future<bool> resetUserData({
  required KeyValueStore store,
  required QueryClient queryClient,
  required UserDataResetRegistry registry,
  bool preserveRecentImpersonations = false,
  Future<void> Function()? clearCookies,
  void Function()? clearSessionStorage,
}) async {
  void log(String message, Object error) =>
      developer.log(message, name: 'sim_app.reset', error: error);
  var inMemoryResetSucceeded = true;

  try {
    final keep = UserDataKeepList.keys(
      preserveRecentImpersonations: preserveRecentImpersonations,
    );
    for (final key in await store.keys()) {
      if (!keep.contains(key)) await store.delete(key);
    }
  } on Object catch (error) {
    log('Error clearing local user data', error);
  }

  try {
    clearSessionStorage?.call();
  } on Object catch (error) {
    log('Error clearing tab-scoped user data', error);
  }

  try {
    await registry.resetAll();
    queryClient.clear();
  } on Object catch (error) {
    inMemoryResetSucceeded = false;
    log('Error resetting in-memory user data', error);
  }

  try {
    await clearCookies?.call();
  } on Object catch (error) {
    log('Error clearing cookies', error);
  }

  return inMemoryResetSucceeded;
}
