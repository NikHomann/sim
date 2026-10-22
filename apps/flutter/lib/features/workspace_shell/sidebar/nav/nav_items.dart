import 'package:flutter/foundation.dart';
import 'package:sim_app/features/workspace_shell/shared/permission_config.dart';
import 'package:sim_design/sim_design.dart';

/// `SidebarNavItemData` (`sidebar-nav-chip.tsx`): a link row (or, for the
/// chat-disabled "New workflow" entry, a button) with an optional lock when
/// a permission group restricts it.
@immutable
class SidebarNavItem {
  const SidebarNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.href,
    this.isAction = false,
    this.restricted = false,
    this.additionalActivePaths = const <String>[],
  });

  final String id;
  final String label;
  final SimIconData icon;
  final String? href;

  /// The "New workflow" button (no href; click creates a workflow).
  final bool isAction;
  final bool restricted;
  final List<String> additionalActivePaths;

  /// `parity id` suffix (`knowledge-base` reads `knowledge` in the spec).
  String get parityId =>
      'shell.sidebar.nav.${id == 'knowledge-base' ? 'knowledge' : id}';
}

/// `isNavItemActive`: [pathname] equals the href (or an additional path) or
/// continues it at a segment boundary (`/foo` never lights for `/foo-bar`).
bool isNavItemActive(SidebarNavItem item, String? pathname) {
  if (pathname == null || pathname.isEmpty) return false;
  bool matches(String p) => pathname == p || pathname.startsWith('$p/');
  final href = item.href;
  if (href != null && matches(href)) return true;
  return item.additionalActivePaths.any(matches);
}

/// The gating inputs of the two nav lists (`sidebar.tsx:754-865`).
@immutable
class NavGating {
  const NavGating({
    required this.workspaceId,
    required this.chatEnabled,
    required this.canEdit,
    required this.permissionsLoading,
    required this.dashboardsEnabled,
    required this.changelogEnabled,
    required this.testsEnabled,
    this.permissionConfig = const ShellPermissionConfig(),
    this.accessRequestsEnabled = false,
  });

  final String workspaceId;
  final bool chatEnabled;
  final bool canEdit;
  final bool permissionsLoading;
  final bool dashboardsEnabled;
  final bool changelogEnabled;
  final bool testsEnabled;
  final ShellPermissionConfig permissionConfig;
  final bool accessRequestsEnabled;
}

/// `topNavItems`: home ("New chat" or the chat-disabled "New workflow"),
/// Dashboard, Changelog, Integrations, minus the hidden ones.
List<SidebarNavItem> topNavItems(NavGating g) {
  final ws = '/workspace/${g.workspaceId}';
  final p = g.permissionConfig;
  final ar = g.accessRequestsEnabled;
  return <({SidebarNavItem item, bool hidden})>[
    (
      item: SidebarNavItem(
        id: 'home',
        label: g.chatEnabled ? 'New chat' : 'New workflow',
        icon: g.chatEnabled ? SimEmcnIcons.home : SimEmcnIcons.plus,
        href: g.chatEnabled ? '$ws/home' : null,
        isAction: !g.chatEnabled,
        restricted: g.chatEnabled && p.hideCopilot,
      ),
      hidden:
          (!g.chatEnabled && !g.permissionsLoading && !g.canEdit) ||
          (g.chatEnabled && p.hideCopilot && !ar),
    ),
    (
      item: SidebarNavItem(
        id: 'dashboards',
        label: 'Dashboard',
        icon: SimEmcnIcons.dashboard,
        href: '$ws/dashboards',
        restricted: p.hideFilesTab,
      ),
      hidden: !g.dashboardsEnabled || (p.hideFilesTab && !ar),
    ),
    (
      item: SidebarNavItem(
        id: 'changelog',
        label: 'Changelog',
        icon: SimEmcnIcons.rss,
        href: '$ws/changelog',
        restricted: p.hideFilesTab,
      ),
      hidden: !g.changelogEnabled || (p.hideFilesTab && !ar),
    ),
    (
      item: SidebarNavItem(
        id: 'integrations',
        label: 'Integrations',
        icon: SimEmcnIcons.integration,
        href: '$ws/integrations',
        additionalActivePaths: <String>['$ws/skills'],
        restricted: p.hideIntegrationsTab,
      ),
      hidden: p.hideIntegrationsTab && !ar,
    ),
  ].where((e) => !e.hidden).map((e) => e.item).toList();
}

/// `workspaceNavItems`: Tables, Files, Knowledge bases, Tests, Logs, minus
/// the hidden ones.
List<SidebarNavItem> workspaceNavItems(NavGating g) {
  final ws = '/workspace/${g.workspaceId}';
  final p = g.permissionConfig;
  final ar = g.accessRequestsEnabled;
  return <({SidebarNavItem item, bool hidden})>[
    (
      item: SidebarNavItem(
        id: 'tables',
        label: 'Tables',
        icon: SimEmcnIcons.table,
        href: '$ws/tables',
        restricted: p.hideTablesTab,
      ),
      hidden: p.hideTablesTab && !ar,
    ),
    (
      item: SidebarNavItem(
        id: 'files',
        label: 'Files',
        icon: SimEmcnIcons.files,
        href: '$ws/files',
        restricted: p.hideFilesTab,
      ),
      hidden: p.hideFilesTab && !ar,
    ),
    (
      item: SidebarNavItem(
        id: 'knowledge-base',
        label: 'Knowledge bases',
        icon: SimEmcnIcons.database,
        href: '$ws/knowledge',
        restricted: p.hideKnowledgeBaseTab,
      ),
      hidden: p.hideKnowledgeBaseTab && !ar,
    ),
    (
      item: SidebarNavItem(
        id: 'tests',
        label: 'Tests',
        icon: SimEmcnIcons.shieldCheck,
        href: '$ws/tests',
        restricted: p.hideFilesTab,
      ),
      hidden: !g.testsEnabled || (p.hideFilesTab && !ar),
    ),
    (
      item: SidebarNavItem(
        id: 'logs',
        label: 'Logs',
        icon: SimEmcnIcons.library,
        href: '$ws/logs',
      ),
      hidden: false,
    ),
  ].where((e) => !e.hidden).map((e) => e.item).toList();
}
