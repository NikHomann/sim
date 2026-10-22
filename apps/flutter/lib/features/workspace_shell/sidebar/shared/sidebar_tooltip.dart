import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_design/sim_design.dart';

/// `SidebarTooltip` (`components/sidebar-tooltip/sidebar-tooltip.tsx`): the
/// emcn cursor-following tooltip, shown only while [enabled] (the collapsed
/// rail, or the header chips while expanded). With [shortcut] the content
/// is `Tooltip.Shortcut` (label + keys at 70 %).
class SidebarTooltip extends StatelessWidget {
  const SidebarTooltip({
    required this.label,
    required this.child,
    super.key,
    this.enabled = true,
    this.shortcut,
  });

  final String label;
  final String? shortcut;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return child;
    final text = Text(label);
    return SimTooltip(
      enabled: enabled,
      content: Parity(
        'shell.sidebar.tooltip',
        child: shortcut == null
            ? text
            : SimTooltipShortcut(keys: shortcut!, child: text),
      ),
      child: child,
    );
  }
}
