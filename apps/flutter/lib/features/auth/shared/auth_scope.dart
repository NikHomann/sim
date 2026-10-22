import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_navigator.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/shared/auth_timers.dart';
import 'package:sim_app/features/auth/shared/platform/browser.dart';

/// The collaborators every auth page needs. Resolved once per route from the
/// locator (overridable by registering [AuthApi], [AuthNavigator] or
/// [AuthSessionStore] there) and handed to the page through [AuthScope].
class AuthDependencies {
  const AuthDependencies({
    required this.api,
    required this.navigator,
    required this.sessionStore,
    required this.localStore,
    required this.timers,
    required this.origin,
  });

  /// Builds the production set for the route whose [context] sits under the
  /// router.
  factory AuthDependencies.resolve(BuildContext context) {
    final http = locator<SimHttpClient>();
    final api = locator.isRegistered<AuthApi>()
        ? locator<AuthApi>()
        : HttpAuthApi(
            auth: locator<AuthRepository>(),
            http: http,
            onSessionChanged: locator.isRegistered<SessionCubit>()
                ? () => locator<SessionCubit>().refresh()
                : null,
          );
    final navigator = locator.isRegistered<AuthNavigator>()
        ? locator<AuthNavigator>()
        : RouterAuthNavigator(
            router: GoRouter.of(context),
            baseUrl: http.baseUrl,
          );
    final sessionStore = locator.isRegistered<AuthSessionStore>()
        ? locator<AuthSessionStore>()
        : (const BrowserWindow().origin != null
              ? const BrowserSessionStore()
              : _memorySessionStore);
    return AuthDependencies(
      api: api,
      navigator: navigator,
      sessionStore: sessionStore,
      localStore: const BrowserWindow().origin != null
          ? const BrowserLocalStore()
          : _memoryLocalStore,
      timers: const SystemAuthTimers(),
      origin: http.baseUrl,
    );
  }

  static final MemoryAuthSessionStore _memorySessionStore =
      MemoryAuthSessionStore();
  static final MemoryAuthSessionStore _memoryLocalStore =
      MemoryAuthSessionStore();

  final AuthApi api;
  final AuthNavigator navigator;

  /// `sessionStorage` twin.
  final AuthSessionStore sessionStore;

  /// `localStorage` twin.
  final AuthSessionStore localStore;
  final AuthTimers timers;

  /// The page origin (`scheme://host[:port]`) callbacks are validated against.
  final String origin;
}

/// Provides [AuthDependencies] to a page subtree.
class AuthScope extends InheritedWidget {
  const AuthScope({required this.deps, required super.child, super.key});

  final AuthDependencies deps;

  static AuthDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'No AuthScope above this widget');
    return scope!.deps;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) => deps != oldWidget.deps;
}
