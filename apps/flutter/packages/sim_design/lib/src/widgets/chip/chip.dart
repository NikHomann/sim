import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/interaction/pressable.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/widgets/chip/chrome.dart';
import 'package:sim_design/src/widgets/overflow_text.dart';

/// `chipVariants` variant axis. [base] is the implicit default pill
/// (transparent, `--surface-hover` on hover); [filled] is reserved for chip
/// fields and triggers and never a plain `Chip`.
enum SimChipVariant {
  base,
  filled,
  primary,
  destructive,
  borderShadow,
  border,
  outline,
}

/// `shape`: the `rounded-lg` pill, or fully round for a row of round controls.
enum SimChipShape { rounded, round }

/// Resolved paint of a chip for one interaction state.
class SimChipPaint {
  const SimChipPaint({
    required this.fill,
    required this.text,
    required this.icon,
    this.border,
    this.shadows,
  });

  final Color fill;
  final Color text;
  final Color icon;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
}

/// Resolves the `chipVariants` compound variants for a state. Exposed so
/// triggers that compose the chip chrome (dropdowns, selects, segmented
/// controls) paint identically to [SimChip].
SimChipPaint resolveChipPaint(
  SimColors c, {
  SimChipVariant variant = SimChipVariant.base,
  bool active = false,
  bool hovered = false,
  bool focused = false,
  bool triggerBorder = false,
}) {
  const transparent = Color(0x00000000);
  final hover = hovered;
  switch (variant) {
    case SimChipVariant.base:
    case SimChipVariant.filled:
      final rest = variant == SimChipVariant.filled
          ? SimChipChrome.filledFill(c)
          : transparent;
      final fill = active
          ? c.surfaceActive
          : (hover || focused)
          ? c.surfaceHover
          : rest;
      return SimChipPaint(
        fill: fill,
        text: c.textBody,
        icon: c.textIcon,
        border: triggerBorder ? Border.all(color: c.border) : null,
      );
    case SimChipVariant.primary:
      final fill = hover
          ? SimChipChrome.primaryHoverFill(c)
          : SimChipChrome.primaryFill(c);
      final text = SimChipChrome.primaryText(c);
      return SimChipPaint(fill: fill, text: text, icon: text);
    case SimChipVariant.destructive:
      return const SimChipPaint(
        fill: Color(0x00000000),
        text: SimColors.white,
        icon: SimColors.white,
      ).copyWithFill(SimChipChrome.destructiveFill(c, hovered: hover));
    case SimChipVariant.borderShadow:
      return SimChipPaint(
        fill: SimChipChrome.borderShadowFill(c, hovered: hover),
        text: c.textBody,
        icon: c.textIcon,
        shadows: SimChipChrome.ring(c),
      );
    case SimChipVariant.border:
      return SimChipPaint(
        fill: hover ? c.surfaceHover : transparent,
        text: c.textBody,
        icon: c.textIcon,
        shadows: SimChipChrome.ring(c),
      );
    case SimChipVariant.outline:
      return SimChipPaint(
        fill: transparent,
        text: c.textBody,
        icon: c.textIcon,
        border: Border.all(
          color: hover ? SimChipChrome.outlineHoverBorder(c) : c.border,
        ),
      );
  }
}

extension on SimChipPaint {
  SimChipPaint copyWithFill(Color fill) => SimChipPaint(
    fill: fill,
    text: text,
    icon: icon,
    border: border,
    shadows: shadows,
  );
}

/// Port of `packages/emcn/src/components/chip/chip.tsx`: the 30px pill.
///
/// Variants follow `chipVariants`; `active` renders the base/filled chip in
/// its selected state (`--surface-active`, held through hover); `fullWidth`
/// swaps the intrinsic pill for a block-level one. The chip carries no outer
/// margin: spacing between chips belongs to the parent.
class SimChip extends StatelessWidget {
  const SimChip({
    super.key,
    this.label,
    this.child,
    this.variant = SimChipVariant.base,
    this.shape = SimChipShape.rounded,
    this.active = false,
    this.fullWidth = false,
    this.leftIcon,
    this.leftAdornment,
    this.rightIcon,
    this.rightAdornment,
    this.onPressed,
    this.onSecondaryTapDown,
    this.enabled = true,
    this.semanticsLabel,
    this.focusNode,
    this.autofocus = false,
    this.triggerBorder = false,
    this.alignment = MainAxisAlignment.start,
    this.isLink = false,
    this.textColor,
  }) : assert(
         label != null ||
             child != null ||
             leftIcon != null ||
             leftAdornment != null,
         'a chip needs content',
       );

  /// Plain text label, rendered through [SimOverflowText].
  final String? label;

  /// Rich content rendered in place of [label] (hard-clipped, no fade).
  final Widget? child;
  final SimChipVariant variant;
  final SimChipShape shape;
  final bool active;
  final bool fullWidth;
  final SimIconData? leftIcon;
  final Widget? leftAdornment;
  final SimIconData? rightIcon;
  final Widget? rightAdornment;
  final VoidCallback? onPressed;
  final void Function(Offset globalPosition)? onSecondaryTapDown;
  final bool enabled;
  final String? semanticsLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  /// `TRIGGER_BORDER_CLASS`: the 1px `--border` outline filled/base triggers add.
  final bool triggerBorder;

  /// Main-axis alignment of the content (toast actions centre theirs).
  final MainAxisAlignment alignment;
  final bool isLink;

  /// Overrides the label colour (e.g. a muted placeholder in a trigger).
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final radius = shape == SimChipShape.round
        ? SimRadii.full
        : SimChipChrome.radius;
    return SimPressable(
      onPressed: onPressed,
      onSecondaryTapDown: onSecondaryTapDown,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticsLabel: semanticsLabel ?? label,
      isLink: isLink,
      selected: active ? true : null,
      builder: (context, state) {
        final paint = resolveChipPaint(
          c,
          variant: variant,
          active: active,
          hovered: state.hovered,
          focused: state.focused,
          triggerBorder: triggerBorder,
        );
        final labelStyle = sim.text.sm.copyWith(color: textColor ?? paint.text);
        final content = <Widget>[];
        if (leftAdornment != null) {
          content.add(leftAdornment!);
        } else if (leftIcon != null) {
          content.add(
            SimIcon(
              leftIcon!,
              size: SimChipChrome.contentIconSize,
              color: paint.icon,
            ),
          );
        }
        if (child != null) {
          content.add(
            Flexible(
              child: DefaultTextStyle.merge(
                style: labelStyle,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                child: ClipRect(child: child),
              ),
            ),
          );
        } else if (label != null) {
          content.add(
            Flexible(
              child: SimOverflowText(label: label!, style: labelStyle),
            ),
          );
        }
        if (rightAdornment != null) {
          content.add(rightAdornment!);
        } else if (rightIcon != null) {
          content.add(
            SimIcon(
              rightIcon!,
              size: SimChipChrome.contentIconSize,
              color: paint.icon,
            ),
          );
        }
        final row = Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: alignment,
          spacing: SimChipChrome.gap,
          children: content,
        );
        return Opacity(
          opacity: enabled ? 1 : SimChipChrome.disabledOpacity,
          child: AnimatedContainer(
            duration: SimMotion.of(SimMotion.colors),
            height: SimChipChrome.height,
            width: fullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(
              horizontal: SimChipChrome.paddingX,
            ),
            decoration: BoxDecoration(
              color: paint.fill,
              border: paint.border,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: paint.shadows,
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                color: paint.icon,
                size: SimChipChrome.contentIconSize,
              ),
              child: row,
            ),
          ),
        );
      },
    );
  }
}

/// `ChipLink`: a chip that navigates. [onPressed] performs the navigation
/// (the router is the app's concern); [href] is exposed for semantics.
class SimChipLink extends StatelessWidget {
  const SimChipLink({
    required this.href,
    required this.onPressed,
    super.key,
    this.label,
    this.child,
    this.variant = SimChipVariant.base,
    this.shape = SimChipShape.rounded,
    this.active = false,
    this.fullWidth = false,
    this.leftIcon,
    this.leftAdornment,
    this.rightIcon,
    this.rightAdornment,
    this.enabled = true,
    this.semanticsLabel,
    this.focusNode,
  });

  final String href;
  final VoidCallback onPressed;
  final String? label;
  final Widget? child;
  final SimChipVariant variant;
  final SimChipShape shape;
  final bool active;
  final bool fullWidth;
  final SimIconData? leftIcon;
  final Widget? leftAdornment;
  final SimIconData? rightIcon;
  final Widget? rightAdornment;
  final bool enabled;
  final String? semanticsLabel;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => Semantics(
    value: href,
    child: SimChip(
      label: label,
      variant: variant,
      shape: shape,
      active: active,
      fullWidth: fullWidth,
      leftIcon: leftIcon,
      leftAdornment: leftAdornment,
      rightIcon: rightIcon,
      rightAdornment: rightAdornment,
      onPressed: onPressed,
      enabled: enabled,
      semanticsLabel: semanticsLabel,
      focusNode: focusNode,
      isLink: true,
      child: child,
    ),
  );
}

/// `ChipChevronDown`: the 16px slot centring a 14px chevron in `--text-icon`,
/// the trailing adornment of every chip-style dropdown trigger.
class SimChipChevron extends StatelessWidget {
  const SimChipChevron({
    super.key,
    this.icon = SimIcons.chevronDown,
    this.color,
  });

  final SimIconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: SimChipChrome.iconSlot,
    child: Center(
      child: SimIcon(
        icon,
        color: color ?? SimTheme.of(context).colors.textIcon,
      ),
    ),
  );
}
