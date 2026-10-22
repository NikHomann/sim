import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';
import 'package:sim_app/features/auth/shared/platform/browser.dart';
import 'package:url_launcher/url_launcher.dart';

/// Navigation the auth cubits perform: in-app route changes through the
/// router, top-level browser navigations for everything the bundle does not
/// own (OAuth providers, `/api/auth/oauth2/authorize`, the marketing site).
abstract class AuthNavigator {
  /// In-app navigation (`router.push` upstream).
  void go(String location);

  /// Top-level browser navigation (`window.location.href = url`); the system
  /// browser on desktop.
  void openTopLevel(String url);

  /// `window.location.replace(url)`: top-level without a history entry.
  void replaceTopLevel(String url);

  /// Opens [url] in a new tab (`target=_blank`).
  void openNewTab(String url);

  /// `window.location.reload()`.
  void reload();

  /// `window.close()` — a no-op where the page cannot close itself.
  void closeWindow();

  /// Routes a post-auth destination: in-app when the bundle owns the path
  /// (relative or same-origin absolute), top-level otherwise.
  void goToDestination(String location, {required String origin}) {
    final target = resolveDestination(location, origin: origin);
    if (target.inApp) {
      go(target.location);
    } else {
      openTopLevel(target.location);
    }
  }
}

/// [AuthNavigator] over [GoRouter] and the browser (or `url_launcher` on
/// desktop, where [baseUrl] is the configured Sim origin).
class RouterAuthNavigator extends AuthNavigator {
  RouterAuthNavigator({
    required this.router,
    required this.baseUrl,
    this.window = const BrowserWindow(),
  });

  final GoRouter router;
  final String baseUrl;
  final BrowserWindow window;

  bool get _isWeb => window.origin != null;

  Uri _absolute(String url) => Uri.parse(baseUrl).resolve(url);

  @override
  void go(String location) => router.go(location);

  @override
  void openTopLevel(String url) {
    if (_isWeb) {
      window.assign(url);
    } else {
      unawaited(
        launchUrl(_absolute(url), mode: LaunchMode.externalApplication),
      );
    }
  }

  @override
  void replaceTopLevel(String url) {
    if (_isWeb) {
      window.replace(url);
    } else {
      openTopLevel(url);
    }
  }

  @override
  void openNewTab(String url) => unawaited(
    launchUrl(_absolute(url), mode: LaunchMode.externalApplication),
  );

  @override
  void reload() => window.reload();

  @override
  void closeWindow() => window.close();
}
