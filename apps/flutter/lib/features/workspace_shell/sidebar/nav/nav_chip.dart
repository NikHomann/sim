import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/sidebar/nav/nav_items.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/context_menu.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/sidebar_chip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/sidebar_tooltip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_design/sim_design.dart';

/// `SidebarNavItem` + `SidebarNavChip`: the full-width 30px nav chip (32px
/// in the collapsed rail, label hidden, tooltip on), a lock on the right
/// when restricted, active by [isNavItemActive]. Right-click opens the nav
/// context menu for link rows.
class SidebarNavRow extends StatelessWidget {
  const SidebarNavRow({
    required this.item,
    required this.active,
    required this.collapsed,
    required this.services,
    super.key,
    this.onAction,
    this.onHoverChanged,
    this.showTooltip = true,
  });

  final SidebarNavItem item;
  final bool active;
  final bool collapsed;
  final SidebarServices services;

  /// The "New workflow" entry's click (when chat is disabled).
  final VoidCallback? onAction;
  final ValueChanged<bool>? onHoverChanged;

  /// False while a rail flyout replaces the tooltip.
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    final href = item.href;
    final c = SimTheme.of(context).colors;
    Widget chip = SidebarChip(
      icon: item.icon,
      label: collapsed ? null : item.label,
      trailing: item.restricted && !collapsed
          ? SimIcon(
              SimEmcnIcons.lock,
              size: SimChipChrome.contentIconSize,
              color: c.textIcon,
            )
          : null,
      active: active,
      width: collapsed ? SimLayout.sidebarRailChip : null,
      isLink: href != null,
      semanticsLabel: item.restricted
          ? '${item.label}: access required'
          : item.label,
      onHoverChanged: onHoverChanged,
      onPressed: () {
        if (href == null) {
          if (isModifierPressed || isShiftPressed) return;
          onAction?.call();
          return;
        }
        if (isModifierPressed) {
          services.navigator.openInNewTab(href);
        } else {
          services.navigator.go(href);
        }
      },
      onMiddleTap: href == null
          ? null
          : () => services.navigator.openInNewTab(href),
      onSecondaryTapDown: href == null
          ? null
          : (position) => showNavItemContextMenu(
              context,
              position,
              href: href,
              services: services,
            ),
    );
    chip = SidebarTooltip(
      label: item.label,
      enabled: collapsed && showTooltip,
      child: chip,
    );
    return Parity(item.parityId, child: chip);
  }
}

/// `navigator.clipboard.writeText(origin + href)`: copies the absolute URL
/// of [href]; a refused clipboard write is logged, never thrown.
void copyAppLink(SidebarServices services, String href) {
  final url = services.navigator.absoluteUrl(href);
  if (url == null) return;
  unawaited(
    services
        .clipboard(url)
        .catchError(
          (Object error) =>
              developer.log('copy link', name: 'sim_app.sidebar', error: error),
        ),
  );
}

/// `NavItemContextMenu`: "Open in new tab" / "Copy link" (absolute URL).
SimMenuHandle showNavItemContextMenu(
  BuildContext context,
  Offset position, {
  required String href,
  required SidebarServices services,
}) => showSidebarContextMenu(
  context,
  position,
  semanticsIdentifier: 'shell.sidebar.nav.menu',
  entries: () => <SimMenuEntry>[
    sidebarMenuItem(
      SimEmcnIcons.squareArrowUpRight,
      'Open in new tab',
      () => services.navigator.openInNewTab(href),
      enabled: services.navigator.canOpenInNewTab,
    ),
    sidebarMenuItem(
      SimEmcnIcons.duplicate,
      'Copy link',
      () => copyAppLink(services, href),
      enabled: services.navigator.absoluteUrl(href) != null,
    ),
  ],
);
