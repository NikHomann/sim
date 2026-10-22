import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/sidebar/nav/nav_chip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/nav/nav_items.dart';
import 'package:sim_app/features/workspace_shell/sidebar/rail/hover_menu.dart';
import 'package:sim_app/features/workspace_shell/sidebar/rail/rail_flyout.dart';
import 'package:sim_app/features/workspace_shell/sidebar/rail/rail_resources.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_section.dart';
import 'package:sim_design/sim_design.dart';

/// The "Workspace" section (`sidebar.tsx:1653-1688`): Tables, Files,
/// Knowledge bases, Tests, Logs. In the collapsed rail Tables and Files
/// (unless restricted) keep their nav chip as the trigger of a hover
/// flyout listing the resources.
class WorkspaceNavSection extends StatefulWidget {
  const WorkspaceNavSection({
    required this.workspaceId,
    required this.items,
    required this.pathname,
    required this.collapsed,
    required this.services,
    super.key,
  });

  final String workspaceId;
  final List<SidebarNavItem> items;
  final String pathname;
  final bool collapsed;
  final SidebarServices services;

  @override
  State<WorkspaceNavSection> createState() => _WorkspaceNavSectionState();
}

class _WorkspaceNavSectionState extends State<WorkspaceNavSection> {
  final HoverMenuController _tablesHover = HoverMenuController();
  final HoverMenuController _filesHover = HoverMenuController();

  @override
  void dispose() {
    _tablesHover.dispose();
    _filesHover.dispose();
    super.dispose();
  }

  Widget _row(SidebarNavItem item) {
    final active = isNavItemActive(item, widget.pathname);
    final services = widget.services;
    final flyout = widget.collapsed && !item.restricted
        ? switch (item.id) {
            'tables' => (
              hover: _tablesHover,
              source: services.tables,
              empty: 'No tables yet',
              segment: 'tables',
            ),
            'files' => (
              hover: _filesHover,
              source: services.files,
              empty: 'No files yet',
              segment: 'files',
            ),
            _ => null,
          }
        : null;
    if (flyout == null) {
      return SidebarNavRow(
        item: item,
        active: active,
        collapsed: widget.collapsed,
        services: services,
      );
    }
    final listing = flyout.source.listing(widget.workspaceId);
    return ValueListenableBuilder<RailResourceListing>(
      valueListenable: listing,
      builder: (context, _, _) => RailFlyout(
        controller: flyout.hover,
        entries: () => railResourceEntries(
          listing.value,
          emptyLabel: flyout.empty,
          currentPath: widget.pathname,
          onOpen: (href) {
            flyout.hover.close();
            services.navigator.go(href);
          },
        ),
        // Radix's trigger toggles the menu on pointer down; the click then
        // follows the link.
        trigger: (context, {required open}) => Listener(
          onPointerDown: (_) => flyout.hover.close(),
          child: SidebarNavRow(
            item: item,
            active: active,
            collapsed: true,
            services: services,
            showTooltip: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SidebarSection(
    title: 'Workspace',
    railCollapsed: widget.collapsed,
    topGap: SimLayout.sidebarSectionGap,
    parityId: 'shell.sidebar.workspace',
    titleParityId: 'shell.sidebar.workspace.title',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: SimLayout.sidebarItemGap,
        children: <Widget>[for (final item in widget.items) _row(item)],
      ),
    ),
  );
}

/// `CollapsedResourceFlyout` rows: "Loading..." (with a 14px loader) while
/// pending, the empty label, else folders as submenus (empty ones
/// disabled) and items as links, active for the open resource, pinned rows
/// marked with a 12px pin.
List<SimMenuEntry> railResourceEntries(
  RailResourceListing listing, {
  required String emptyLabel,
  required String currentPath,
  required void Function(String href) onOpen,
}) {
  if (listing.loading) {
    return const <SimMenuEntry>[
      SimMenuItem(
        label: 'Loading...',
        enabled: false,
        leading: SimSpinner(),
      ),
    ];
  }
  if (listing.entries.isEmpty) {
    return <SimMenuEntry>[SimMenuItem(label: emptyLabel, enabled: false)];
  }
  List<SimMenuEntry> level(List<RailResourceEntry> entries) => <SimMenuEntry>[
    for (final entry in entries)
      switch (entry) {
        RailResourceFolderEntry(:final children) =>
          children.isEmpty
              ? SimMenuItem(label: entry.name, enabled: false)
              : SimMenuSub(label: entry.name, entries: level(children)),
        RailResourceItemEntry(:final href) => SimMenuCustom(
          FlyoutRow(
            label: entry.name,
            active: currentPath == href || currentPath.startsWith('$href/'),
            indicator: entry.pinned
                ? const SimIcon(
                    SimEmcnIcons.pin,
                    size: 12,
                    semanticLabel: 'Pinned',
                  )
                : null,
            onPressed: () => onOpen(href),
          ),
        ),
      },
  ];
  return level(listing.entries);
}
