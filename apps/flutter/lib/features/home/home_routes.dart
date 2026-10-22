import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_app/features/entry/entry_routes.dart';
import 'package:sim_app/features/home/home_page.dart';

/// Route paths (declared without the `/app` base).
abstract final class HomePaths {
  static const String home = '/workspace/:workspaceId/home';
  static const String chat = '/workspace/:workspaceId/chat/:chatId';
}

/// Both routes share this page key, so the new chat's in-place rewrite
/// from `/home` to `/chat/<id>` updates the one page instead of replacing
/// it ([HomeSurfaceHost] then decides whether the content remounts).
const ValueKey<String> homeSurfacePageKey = ValueKey<String>('home-surface');

String _workspaceId(GoRouterState state) =>
    state.pathParameters['workspaceId'] ?? '';

/// `/workspace/:id/home` (`home/page.tsx`, `home/layout.tsx`): chat
/// disabled → redirect to `/workspace/:id` (which resolves to `w`).
GoRoute homeRoute() => GoRoute(
  path: HomePaths.home,
  redirect: (context, state) async =>
      await chatEnabled() ? null : '/workspace/${_workspaceId(state)}',
  pageBuilder: (context, state) => NoTransitionPage<void>(
    key: homeSurfacePageKey,
    child: HomeRoutePage(
      workspaceId: _workspaceId(state),
      initialResource: state.uri.queryParameters['resource'],
    ),
  ),
);

/// `/workspace/:id/chat/:chatId` (`chat/[chatId]/page.tsx`): chat
/// disabled → the workspace not-found page (rendered by [HomeRoutePage]).
GoRoute chatRoute() => GoRoute(
  path: HomePaths.chat,
  pageBuilder: (context, state) => NoTransitionPage<void>(
    key: homeSurfacePageKey,
    child: HomeRoutePage(
      workspaceId: _workspaceId(state),
      chatId: state.pathParameters['chatId'],
      initialResource: state.uri.queryParameters['resource'],
    ),
  ),
);

/// Replaces the shell's `home` and `chat/:chatId` placeholder routes with
/// the Home page routes, keeping every other route (and the shell route
/// itself) as it is. Routes outside a [ShellRoute] pass through.
List<RouteBase> withHomeRoutes(List<RouteBase> routes) => <RouteBase>[
  for (final route in routes)
    if (route is ShellRoute)
      ShellRoute(
        redirect: route.redirect,
        builder: route.builder,
        pageBuilder: route.pageBuilder,
        observers: route.observers,
        parentNavigatorKey: route.parentNavigatorKey,
        navigatorKey: route.navigatorKey,
        restorationScopeId: route.restorationScopeId,
        routes: <RouteBase>[
          for (final child in route.routes)
            if (child is GoRoute && child.path == HomePaths.home)
              homeRoute()
            else if (child is GoRoute && child.path == HomePaths.chat)
              chatRoute()
            else
              child,
        ],
      )
    else
      route,
];
