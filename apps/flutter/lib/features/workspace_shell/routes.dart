import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/entry/entry_routes.dart';
import 'package:sim_app/features/workspace_shell/chrome/workspace_chrome.dart';
import 'package:sim_design/sim_design.dart';

/// The settings sections a URL may name (`UnifiedSettingsSection`,
/// `components/settings/navigation.ts:96-127`).
const Set<String> settingsSections = <String>{
  'connected-accounts',
  'general',
  'desktop',
  'browser',
  'terminal',
  'secrets',
  'access-control',
  'requests',
  'custom-blocks',
  'audit-logs',
  'apikeys',
  'byok',
  'billing',
  'teammates',
  'organization',
  'usage',
  'sso',
  'whitelabeling',
  'forks',
  'mcp',
  'custom-tools',
  'workflow-mcp-servers',
  'inbox',
  'sandboxes',
  'admin',
  'security',
  'data-retention',
  'data-drains',
  'mothership',
  'recently-deleted',
  'self-host',
};

/// `SECTION_ALIASES` (`settings/navigation.ts:41-48`): resolved in place,
/// the alias URL stays.
const Map<String, String> settingsSectionAliases = <String, String>{
  'subscription': 'billing',
  'team': 'organization',
  'api-keys': 'apikeys',
  'domains': 'sso',
  'sessions': 'security',
};

/// `TOP_LEVEL_REDIRECTS` (`settings/[section]/layout.tsx:11-18`).
String? settingsLegacyRedirect(String workspaceId, String section) =>
    switch (section) {
      'integrations' => '/workspace/$workspaceId/integrations',
      'skills' => '/workspace/$workspaceId/skills',
      'privacy' => '/workspace/$workspaceId/settings/general?view=privacy',
      'authorized-apps' =>
        '/workspace/$workspaceId/settings/general?view=authorized-apps',
      _ => null,
    };

/// The canonical section for a routed segment, or null (404).
String? resolveSettingsSection(String section) {
  final canonical = settingsSectionAliases[section] ?? section;
  return settingsSections.contains(canonical) ? canonical : null;
}

/// A centred route title standing in for a screen of a later phase, so
/// navigation through the shell is testable.
class ShellPlaceholderPage extends StatelessWidget {
  const ShellPlaceholderPage(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    return Semantics(
      identifier: 'shell.placeholder',
      container: true,
      child: Center(
        child: Text(
          title,
          style: sim.text.lg.copyWith(color: sim.colors.textPrimary),
        ),
      ),
    );
  }
}

String _id(GoRouterState state) => state.pathParameters['workspaceId'] ?? '';

GoRoute _page(String path, String title) => GoRoute(
  path: '/workspace/:workspaceId/$path',
  pageBuilder: (context, state) => NoTransitionPage<void>(
    key: state.pageKey,
    child: ShellPlaceholderPage(title),
  ),
);

/// `/workspace/[id]/w` (`w/page.tsx:34-45`): `router.replace` to the first
/// workflow of the workspace once the list resolved; an empty or failed
/// list stays on the page.
Future<String?> firstWorkflowRedirect(String workspaceId) async {
  if (!locator.isRegistered<WorkflowsCubit>()) return null;
  final workflows = await locator<WorkflowsCubit>().load(workspaceId);
  for (final workflow in workflows ?? const <WorkflowListItem>[]) {
    if (workflow.workspaceId == workspaceId) {
      return '/workspace/$workspaceId/w/${workflow.id}';
    }
  }
  return null;
}

/// The `/workspace/:workspaceId/...` routes: a [ShellRoute] mounting
/// [WorkspaceChrome] around a placeholder per in-scope child route. The
/// bare `/workspace/:workspaceId` redirect lives in the entry routes.
///
/// Invariant: the shell page stays a zero-duration [NoTransitionPage] with
/// the shell route's constant page key. The shell's nested [Navigator] owns
/// one `GlobalKey`, so a shell page still animating out while a new one
/// mounts would mount that key twice. Shell-to-shell navigation updates the
/// one page, and every decision that leaves the shell only to come back
/// (the picker, `/workspace/:id`, `/home`) is a router redirect, never an
/// intermediate page (features/entry/entry_routes.dart).
List<RouteBase> workspaceShellRoutes() => <RouteBase>[
  ShellRoute(
    pageBuilder: (context, state, child) => NoTransitionPage<void>(
      key: state.pageKey,
      child: WorkspaceChrome(
        workspaceId: _id(state),
        location: state.uri.path,
        child: child,
      ),
    ),
    routes: <RouteBase>[
      GoRoute(
        path: '/workspace/:workspaceId/home',
        redirect: (context, state) async =>
            await chatEnabled() ? null : '/workspace/${_id(state)}',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const ShellPlaceholderPage('Home'),
        ),
      ),
      GoRoute(
        path: '/workspace/:workspaceId/w',
        redirect: (context, state) => firstWorkflowRedirect(_id(state)),
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const ShellPlaceholderPage('Workflows'),
        ),
      ),
      _page('w/:workflowId', 'Workflow'),
      _page('chat/:chatId', 'Chat'),
      _page('tables', 'Tables'),
      _page('files', 'Files'),
      _page('knowledge', 'Knowledge bases'),
      _page('logs', 'Logs'),
      _page('integrations', 'Integrations'),
      _page('skills', 'Skills'),
      GoRoute(
        path: '/workspace/:workspaceId/settings/:section',
        redirect: (context, state) => settingsLegacyRedirect(
          _id(state),
          state.pathParameters['section'] ?? '',
        ),
        pageBuilder: (context, state) {
          final section = resolveSettingsSection(
            state.pathParameters['section'] ?? '',
          );
          return NoTransitionPage<void>(
            child: ShellPlaceholderPage(
              section == null ? 'Page not found' : 'Settings: $section',
            ),
          );
        },
      ),
      _page('dashboards', 'Dashboards'),
      _page('changelog', 'Changelog'),
      _page('tests', 'Tests'),
      _page('upgrade', 'Upgrade'),
      _page('access-requests', 'Access requests'),
    ],
  ),
];
