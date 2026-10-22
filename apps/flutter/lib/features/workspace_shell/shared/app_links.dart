import 'package:sim_app/app/config.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/features/workspace_shell/shared/platform/page_base.dart';

/// Absolute URLs of app routes, for "Open in new tab" (Cmd/Ctrl-click,
/// middle-click, context menus) and "Copy link" in the sidebar, the search
/// palette and the workspace switcher.
///
/// Routes are app paths without the `/app` base (`/workspace/{id}/w/{wf}`).
/// They resolve against one [base]:
/// - web: the document base (`<base href>`, `https://host/app/`). Never
///   `Uri.base`, which is `location.href` under the path URL strategy, so a
///   relative route would nest under the current one
///   (`/app/workspace/ws/w/workspace/ws/w/x`).
/// - Windows: the configured Sim origin. A desktop process has no tab of
///   its own to open, so the link is the React app's page for that route
///   (`https://sim.example.com/workspace/…`), opened in the browser.
/// - no base (desktop without a configured origin, tests): no link;
///   new-tab actions are unavailable rather than opening a `file:` URL.
class AppLinks {
  const AppLinks(this.base);

  /// Resolves the platform base: [pageBase] on web, else [backendOrigin].
  factory AppLinks.resolve({String? pageBase, Uri? backendOrigin}) {
    if (pageBase != null && pageBase.isNotEmpty) {
      return AppLinks(_directory(Uri.parse(pageBase)));
    }
    if (backendOrigin != null && backendOrigin.hasAuthority) {
      return AppLinks(_directory(backendOrigin.replace(path: '/')));
    }
    return const AppLinks(null);
  }

  /// The running app's links: the document base on web, the configured
  /// backend origin on desktop.
  factory AppLinks.platform() => AppLinks.resolve(
    pageBase: pageBaseUri(),
    backendOrigin: locator.isRegistered<AppConfig>()
        ? locator<AppConfig>().backendOrigin
        : null,
  );

  /// Absolute base every route resolves against; ends with `/`.
  final Uri? base;

  /// Whether routes can be opened outside this window.
  bool get available => base != null;

  /// The absolute URL of [route], or `null` without a base.
  String? resolve(String route) {
    final base = this.base;
    if (base == null) return null;
    final relative = route.startsWith('/') ? route.substring(1) : route;
    return base.resolve(relative).toString();
  }

  /// Drops the last segment unless the path is a directory (`/app/x` ->
  /// `/app/`), and any query or fragment, like a `<base href>` does.
  static Uri _directory(Uri uri) {
    final path = uri.path;
    final slash = path.lastIndexOf('/');
    final directory = slash < 0 ? '/' : path.substring(0, slash + 1);
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: directory,
    );
  }
}
