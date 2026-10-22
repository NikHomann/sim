import 'package:flutter/widgets.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/radii.dart';

/// Port of `packages/emcn/src/components/chip/chrome.ts`: the chip-family
/// chrome tokens every chip surface composes instead of restating literals.
abstract final class SimChipChrome {
  /// Chip pill geometry: 30px tall, px-2, gap-1.5, text-sm, rounded-lg.
  static const double height = SimLayout.chipHeight;
  static const double paddingX = SimLayout.chipPaddingX;
  static const double gap = SimLayout.chipGap;
  static const double radius = SimRadii.chip;

  /// Chip-content icon: 16px, `--text-icon` (inverse variants: currentColor).
  static const double contentIconSize = SimLayout.chipIconSize;

  /// Field icons (`ChipInput`) and disclosure chevrons: 14px.
  static const double fieldIconSize = SimLayout.iconSize;

  /// The 16px square a chip-row icon or chevron centres in.
  static const double iconSlot = 16;

  /// `disabled:opacity-60` on chips, `opacity-50` on chip fields.
  static const double disabledOpacity = 0.6;
  static const double fieldDisabledOpacity = 0.5;

  /// `chipFilledFillTokens`: `--surface-5` light / `--surface-4` dark.
  static Color filledFill(SimColors c) =>
      c.brightness == Brightness.light ? c.surface5 : c.surface4;

  /// `chipPrimaryFillTokens` at rest.
  static Color primaryFill(SimColors c) =>
      c.brightness == Brightness.light ? c.textPrimary : SimColors.white;
  static Color primaryText(SimColors c) =>
      c.brightness == Brightness.light ? c.textInverse : c.bg;

  /// `primary` hover: `--text-body` light / `--text-secondary` dark.
  static Color primaryHoverFill(SimColors c) =>
      c.brightness == Brightness.light ? c.textBody : c.textSecondary;

  /// `destructive`: `--text-error` fill, white text, `brightness-106` hover.
  static Color destructiveFill(SimColors c, {bool hovered = false}) =>
      hovered ? SimColors.brighten(c.textError, 1.06) : c.textError;

  /// `border-shadow` fill and hover fill.
  static Color borderShadowFill(SimColors c, {bool hovered = false}) {
    if (c.brightness == Brightness.light) {
      return hovered ? c.surface3 : c.surface2;
    }
    return hovered ? c.surface4 : c.surface2;
  }

  /// `outline` hover border: `color-mix(in srgb, var(--border) 80%, var(--text-secondary))`.
  static Color outlineHoverBorder(SimColors c) =>
      SimColors.mix(c.border, c.textSecondary, 0.8);

  /// `chipBorderShadowRing`.
  static List<BoxShadow> ring(SimColors c) => c.chipRing;

  /// `chipDropTargetSurfaceClass`: `--surface-active` fill with a 1px inset
  /// `--text-subtle` outline.
  static BoxDecoration dropTarget(SimColors c) => BoxDecoration(
    color: c.surfaceActive,
    border: Border.all(color: c.textSubtle),
    borderRadius: BorderRadius.circular(radius),
  );

  /// `chipFieldSurfaceClass`: rounded-lg, 1px `--border`, the filled fill.
  static BoxDecoration fieldSurface(
    SimColors c, {
    bool error = false,
    Color? borderColor,
  }) => BoxDecoration(
    color: filledFill(c),
    border: Border.all(color: borderColor ?? (error ? c.textError : c.border)),
    borderRadius: BorderRadius.circular(radius),
  );
}
