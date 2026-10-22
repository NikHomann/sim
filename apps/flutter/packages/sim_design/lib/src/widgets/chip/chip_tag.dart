import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/interaction/pressable.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';

/// `chipTagVariants` variant axis.
enum SimChipTagVariant { mono, field, gray, solid, workflow, brand, invite }

/// `tone` of the `workflow` variant: fixed brand values, one per mode.
enum SimChipTagTone {
  neutral,
  inverse,
  ash,
  orange,
  blue,
  green,
  yellow,
  purple,
  identity,
  content,
}

/// `brandForeground` of the `brand` variant.
enum SimChipTagForeground { light, dark }

/// Port of `packages/emcn/src/components/chip-tag/chip-tag.tsx`: the 20px
/// rounded-md inline tag (text-sm, leading-5, px-1, gap-[3px]; `invite`
/// uses the chip gap-1.5).
class SimChipTag extends StatelessWidget {
  const SimChipTag({
    required this.label,
    super.key,
    this.variant = SimChipTagVariant.mono,
    this.invalid = false,
    this.tone = SimChipTagTone.neutral,
    this.brandForeground = SimChipTagForeground.light,
    this.brandColor,
    this.brandStrokeColor,
    this.leftIcon,
    this.rightIcon,
    this.onRightIconPressed,
    this.rightIconLabel,
    this.rightIconEnabled = true,
    this.child,
  });

  final String label;
  final Widget? child;
  final SimChipTagVariant variant;

  /// `invite` only: flips to the error surface without a layout shift.
  final bool invalid;
  final SimChipTagTone tone;
  final SimChipTagForeground brandForeground;
  final Color? brandColor;
  final Color? brandStrokeColor;
  final SimIconData? leftIcon;
  final SimIconData? rightIcon;

  /// Upgrades [rightIcon] into a button with an 8px extended hit area.
  final VoidCallback? onRightIconPressed;
  final String? rightIconLabel;
  final bool rightIconEnabled;

  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _paper = Color(0xFFF8F8F8);

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final isDark = c.brightness == Brightness.dark;
    Color fill;
    Color text;
    BoxBorder? border;
    List<BoxShadow>? shadows;
    switch (variant) {
      case SimChipTagVariant.mono:
        fill = isDark ? c.surface4 : c.surface5;
        text = c.textPrimary;
      case SimChipTagVariant.field:
        fill = isDark ? c.surface3 : c.surface6;
        text = c.textPrimary;
      case SimChipTagVariant.gray:
        fill = c.surface5;
        text = c.textSecondary;
        border = Border.all(color: c.border);
      case SimChipTagVariant.solid:
        fill = c.textSecondary;
        text = c.textInverse;
      case SimChipTagVariant.workflow:
        (fill, text) = switch (tone) {
          SimChipTagTone.neutral => (SimColors.white, _ink),
          SimChipTagTone.inverse => (const Color(0xFF3B3B3B), _paper),
          SimChipTagTone.ash => (const Color(0xFFE6E6E6), _ink),
          SimChipTagTone.orange => (const Color(0xFFFF4C00), _paper),
          SimChipTagTone.blue => (const Color(0xFF0062FF), _paper),
          SimChipTagTone.green => (const Color(0xFF188F00), _paper),
          SimChipTagTone.yellow => (const Color(0xFFFFEF08), _ink),
          SimChipTagTone.purple => (const Color(0xFFAA00FF), _paper),
          SimChipTagTone.identity => (const Color(0xFF8B5CF6), _paper),
          SimChipTagTone.content => (const Color(0xFF007E80), SimColors.white),
        };
        if (tone == SimChipTagTone.neutral) {
          shadows = const <BoxShadow>[
            BoxShadow(color: Color(0xFFC3C3C3), spreadRadius: 1),
          ];
        }
      case SimChipTagVariant.brand:
        fill = brandColor ?? c.surface5;
        text = brandForeground == SimChipTagForeground.light
            ? SimColors.white
            : SimColors.black;
        if (brandStrokeColor != null) {
          border = Border.all(color: brandStrokeColor!);
        }
      case SimChipTagVariant.invite:
        if (invalid) {
          fill = c.badgeError.background;
          text = c.textError;
          border = Border.all(color: const Color(0x00000000));
        } else {
          fill = isDark ? c.surface4 : c.surface5;
          text = c.textBody;
          border = Border.all(color: c.border);
        }
    }
    final iconColor =
        (!invalid &&
            variant != SimChipTagVariant.workflow &&
            variant != SimChipTagVariant.brand)
        ? c.textIcon
        : text;
    final style = sim.text.style(14, height: 20 / 14).copyWith(color: text);
    final interactive = rightIcon != null && onRightIconPressed != null;
    return Container(
      height: SimLayout.chipTagHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: fill,
        border: border,
        borderRadius: BorderRadius.circular(SimRadii.md),
        boxShadow: shadows,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: variant == SimChipTagVariant.invite ? 6 : 3,
        children: <Widget>[
          if (leftIcon != null) SimIcon(leftIcon!, color: iconColor),
          DefaultTextStyle.merge(
            style: style,
            maxLines: 1,
            softWrap: false,
            child: child ?? Text(label, style: style),
          ),
          if (rightIcon != null)
            if (interactive)
              _RightIconButton(
                icon: rightIcon!,
                color: iconColor,
                enabled: rightIconEnabled,
                label: rightIconLabel,
                onPressed: onRightIconPressed!,
              )
            else
              SimIcon(rightIcon!, color: iconColor),
        ],
      ),
    );
  }
}

class _RightIconButton extends StatelessWidget {
  const _RightIconButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
    this.label,
  });

  final SimIconData icon;
  final Color color;
  final bool enabled;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SimPressable(
    onPressed: onPressed,
    enabled: enabled,
    semanticsLabel: label,
    builder: (context, state) => AnimatedOpacity(
      duration: SimMotion.of(SimMotion.colors),
      opacity: !enabled ? 0.5 : (state.hovered ? 1 : 0.8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SimIcon(icon, color: color),
      ),
    ),
  );
}
