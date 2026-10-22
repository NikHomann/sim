import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/entry/entry_pages.dart';
import 'package:sim_app/features/entry/entry_support.dart';

/// Entry paths (entry-resolution.md), declared without `/app`.
abstract final class EntryPaths {
  static const String root = '/';
  static const String home = '/home';
  static const String organizationEntry = '/o';
  static const String workspacePicker = '/workspace';
  static const String workspace = '/workspace/:workspaceId';
  static const String login = '/login';
}

/// `isAppSurfacePath` (`lib/navigation/paths.ts:65-71`): `/home`,
/// `/workspace`, `/o` and their descendants.
bool isAppSurfacePath(String path) {
  bool under(String base) => path == base || path.startsWith('$base/');
  return under('/home') || under('/workspace') || under('/o');
}

/// The proxy's app-surface gate (`proxy.ts:408-417`): a signed-out visitor
/// of an app surface goes to `/login` (no callback attached). A session
/// query error is not "signed out" (the picker shows its error card), so it
/// passes through. The session is read once per navigation; the cubit
/// caches it for 5 minutes.
///
/// The proxy gates on cookie *presence*; Flutter only sees the session
/// query, so a stale cookie looks signed out here. The bare `/workspace`
/// picker therefore passes a null session through: it is React's identity
/// recovery surface and signs the stale cookies out before going to
/// `/login` (`workspace/page.tsx:100-119`).
Future<String?> appSurfaceRedirect(String path, SessionCubit session) async {
  if (!isAppSurfacePath(path)) return null;
  if (path == EntryPaths.workspacePicker) return null;
  await session.load();
  final state = session.state;
  if (state.isSignedIn || state.hasError) return null;
  return EntryPaths.login;
}

/// `/`, `/home` and `/o` (`home/page.tsx:12-31`, `o/page.tsx:9-16`) as a
/// router redirect, so the decision replaces the requested location instead
/// of adding a history entry: signed out → `/login`, signed in → the
/// picker (which redirects on to a workspace). A session error renders the
/// page (the error card).
Future<String?> entryHomeRedirect(SessionCubit session) async {
  await session.load();
  final decision = resolveEntry(
    EntryContext(
      route: EntryRoute.home,
      session: entrySessionOf(session.state),
    ),
  );
  return switch (decision) {
    EntryGoLogin() => EntryPaths.login,
    EntryGoWorkspacePicker() => EntryPaths.workspacePicker,
    _ => null,
  };
}

/// The `/workspace` picker's navigating decisions (`workspace/page.tsx:
/// 121-170`) as a router redirect: with a session and a loaded list it
/// resolves `?redirect_workflow=`, `?redirect=` and `?reason=` to the target
/// workspace before anything renders, so a picker visit never mounts a page
/// between two shell pages (the shell navigator's `GlobalKey` would be
/// mounted twice) and never leaves `/workspace` in the history. Everything
/// else (stale-session recovery, default creation, the cards) renders
/// [WorkspacePickerPage].
Future<String?> workspacePickerRedirect(
  GoRouterState state, {
  required SessionCubit session,
  required WorkspacesCubit workspaces,
}) async {
  await session.load();
  if (!session.state.isSignedIn) return null;
  await workspaces.load();
  final query = state.uri.queryParameters;
  final target = redirectTargetOf(query['redirect']);
  final decision = resolveEntry(
    EntryContext(
      route: EntryRoute.workspacePicker,
      session: entrySessionOf(session.state),
      workspaces: entryWorkspacesOf(workspaces.state),
      redirectTarget: target,
      redirectWorkflowId: query['redirect_workflow'],
      upgradeReason: query['reason'],
    ),
  );
  return switch (decision) {
    EntryGoWorkspace(:final workspaceId) => workspaceDestination(
      workspaceId,
      target: target,
      upgradeReason: query['reason'],
    ),
    EntryResolveWorkflowRedirect(
      :final workflowId,
      :final fallbackWorkspaceId,
    ) =>
      await workflowRedirectTarget(
        workflowId,
        fallbackWorkspaceId: fallbackWorkspaceId,
      ),
    _ => null,
  };
}

/// Whether chat is enabled for the `home`/`w` split: the seeded host
/// context shape, else the public-env fallback (loaded on demand).
Future<bool> chatEnabled() async {
  final shape = locator<DeploymentShapeCubit>();
  if (shape.state.seeded == null && !shape.state.isReady) {
    await shape.loadPublicEnv();
  }
  return shape.state.shape.chatEnabled;
}

/// `/workspace/[id]` (`[workspaceId]/page.tsx:13-20`): always a redirect,
/// to `home` with chat enabled, else `w`.
FutureOr<String?> workspaceIndexRedirect(GoRouterState state) async {
  final id = state.pathParameters['workspaceId'] ?? '';
  return await chatEnabled() ? '/workspace/$id/home' : '/workspace/$id/w';
}

/// The entry routes: `/`, `/home`, `/o`, the `/workspace` picker and the
/// `/workspace/:id` redirect. Every navigating decision is a redirect
/// (replace semantics); the pages only render the loading and card states.
List<RouteBase> entryRoutes() {
  GoRoute home(String path, EntryRoute route) => GoRoute(
    path: path,
    redirect: (context, state) => entryHomeRedirect(locator<SessionCubit>()),
    pageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: EntryPage(route: route),
    ),
  );
  return <RouteBase>[
    home(EntryPaths.root, EntryRoute.home),
    home(EntryPaths.home, EntryRoute.home),
    home(EntryPaths.organizationEntry, EntryRoute.organizationEntry),
    GoRoute(
      path: EntryPaths.workspacePicker,
      redirect: (context, state) => workspacePickerRedirect(
        state,
        session: locator<SessionCubit>(),
        workspaces: locator<WorkspacesCubit>(),
      ),
      pageBuilder: (context, state) => NoTransitionPage<void>(
        key: state.pageKey,
        child: WorkspacePickerPage(query: state.uri.queryParameters),
      ),
    ),
    GoRoute(
      path: EntryPaths.workspace,
      redirect: (context, state) => workspaceIndexRedirect(state),
    ),
  ];
}
