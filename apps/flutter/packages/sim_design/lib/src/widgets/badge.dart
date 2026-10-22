import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';

/// `badgeVariants` (`packages/emcn/src/components/badge/badge.tsx`).
/// Bordered: [base], [outline], [type]; status colours: the rest.
enum SimBadgeVariant {
  base,
  outline,
  type,
  green,
  red,
  gray,
  blue,
  blueSecondary,
  purple,
  orange,
  amber,
  teal,
  cyan,
  pink,
  graySecondary,
}

enum SimBadgeSize { sm, md, lg }

/// Port of the emcn `Badge`. Bordered variants are 40px pills with a 4px gap;
/// status variants are rounded-md with a 6px gap and may show a leading dot.
class SimBadge extends StatefulWidget {
  const SimBadge({
    required this.label,
    super.key,
    this.variant = SimBadgeVariant.base,
    this.size = SimBadgeSize.md,
    this.dot = false,
    this.icon,
  });

  final String label;
  final SimBadgeVariant variant;
  final SimBadgeSize size;

  /// Dot indicator before the label (status variants only).
  final bool dot;
  final SimIconData? icon;

  bool get isStatus =>
      variant != SimBadgeVariant.base &&
      variant != SimBadgeVariant.outline &&
      variant != SimBadgeVariant.type;

  @override
  State<SimBadge> createState() => _SimBadgeState();
}

class _SimBadgeState extends State<SimBadge> {
  bool _hovered = false;

  SimBadgePalette? _palette(SimColors c) => switch (widget.variant) {
    SimBadgeVariant.green => c.badgeSuccess,
    SimBadgeVariant.red => c.badgeError,
    SimBadgeVariant.gray => c.badgeGray,
    SimBadgeVariant.blue => c.badgeBlue,
    SimBadgeVariant.blueSecondary => c.badgeBlueSecondary,
    SimBadgeVariant.purple => c.badgePurple,
    SimBadgeVariant.orange => c.badgeOrange,
    SimBadgeVariant.amber => c.badgeAmber,
    SimBadgeVariant.teal => c.badgeTeal,
    SimBadgeVariant.cyan => c.badgeCyan,
    SimBadgeVariant.pink => c.badgePink,
    SimBadgeVariant.graySecondary => SimBadgePalette(
      background: c.surface4,
      text: c.textSecondary,
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final isDark = c.brightness == Brightness.dark;
    final palette = _palette(c);
    Color fill;
    Color text;
    BoxBorder? border;
    if (palette != null) {
      fill = palette.background;
      text = palette.text;
    } else {
      switch (widget.variant) {
        case SimBadgeVariant.base:
          fill = _hovered ? (isDark ? c.surface5 : c.surface6) : c.surface4;
          text = _hovered ? c.textPrimary : c.textSecondary;
          border = Border.all(color: c.border);
        case SimBadgeVariant.outline:
          fill = _hovered && !isDark ? c.surface5 : const Color(0x00000000);
          text = _hovered ? c.textPrimary : c.textSecondary;
          border = Border.all(
            color: _hovered && isDark ? c.surface6 : c.border,
          );
        case SimBadgeVariant.type:
        case SimBadgeVariant.green:
        case SimBadgeVariant.red:
        case SimBadgeVariant.gray:
        case SimBadgeVariant.blue:
        case SimBadgeVariant.blueSecondary:
        case SimBadgeVariant.purple:
        case SimBadgeVariant.orange:
        case SimBadgeVariant.amber:
        case SimBadgeVariant.teal:
        case SimBadgeVariant.cyan:
        case SimBadgeVariant.pink:
        case SimBadgeVariant.graySecondary:
          fill = isDark ? c.surface6 : c.surface4;
          text = c.textSecondary;
          border = Border.all(color: c.border);
      }
    }
    final padding = switch (widget.size) {
      SimBadgeSize.sm => const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      SimBadgeSize.md => const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      SimBadgeSize.lg => const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 2.25,
      ),
    };
    final style =
        (widget.size == SimBadgeSize.sm ? sim.text.xs : sim.text.caption)
            .copyWith(color: text);
    final dotSize = widget.size == SimBadgeSize.sm ? 5.0 : 6.0;
    final iconSize = widget.size == SimBadgeSize.sm ? 10.0 : 12.0;
    final gap = widget.isStatus ? 6.0 : 4.0;
    final radius = widget.isStatus ? SimRadii.md : SimRadii.badgePill;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: SimMotion.of(SimMotion.colors),
        padding: padding,
        decoration: BoxDecoration(
          color: fill,
          border: border,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: gap,
          children: <Widget>[
            if (widget.isStatus && widget.dot)
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: text,
                  borderRadius: BorderRadius.circular(SimRadii.xs),
                ),
              ),
            if (widget.icon != null)
              SimIcon(widget.icon!, size: iconSize, color: text),
            Text(widget.label, style: style),
          ],
        ),
      ),
    );
  }
}
