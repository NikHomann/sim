import 'package:go_router/go_router.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/auth/routes.dart';
import 'package:sim_app/features/entry/entry_routes.dart';
import 'package:sim_app/features/home/home_routes.dart';
import 'package:sim_app/features/workspace_shell/routes.dart';

/// Route paths mirror the React app 1:1 (docs/port/00-plan.md section 3).
/// They are declared WITHOUT the /app prefix: the fixed `<base href="/app/">`
/// in web/index.html supplies it.
abstract final class AppRoutes {
  static const String root = EntryPaths.root;
  static const String home = EntryPaths.home;
}

/// The app router: the entry, workspace shell and auth routes behind the
/// app-surface gate. The Phase 0 dev spike page (lib/dev) is not routed.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.root,
    // The proxy's app-surface gate: signed-out visitors of `/home`,
    // `/workspace/**` and `/o/**` go to `/login`.
    redirect: (context, state) =>
        appSurfaceRedirect(state.uri.path, locator<SessionCubit>()),
    routes: [
      // `/`, `/home`, `/o`, `/workspace` and `/workspace/:id`
      // (features/entry/entry_routes.dart).
      ...entryRoutes(),
      // `/workspace/:workspaceId/...` inside the workspace chrome, with the
      // Home page on `home` and `chat/:chatId` (features/home).
      ...withHomeRoutes(workspaceShellRoutes()),
      // Auth pages (features/auth/routes.dart): /login, /signup, /verify,
      // /reset-password, /sso, /oauth/*, /oauth-error, /invite/:id.
      ...authRoutes(),
    ],
  );
}
