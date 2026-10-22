import 'package:flutter/painting.dart';

/// Corner radii (`02-design-system.md` §1c). `--radius` is 8px.
abstract final class SimRadii {
  static const double base = 8;
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
  static const double xxl = 16;

  /// Chips, fields and menu rows.
  static const double chip = lg;

  /// Menus, popovers, modals, the search palette.
  static const double menu = xl;
  static const double modal = xl;

  /// `Button` base radius and its `size='icon'` radius.
  static const double button = 5;
  static const double buttonIcon = sm;

  /// Toast corner: compact (<= 46px tall) vs concentric.
  static const double toastCompact = 12;
  static const double toast = 16;
  static const double toastCompactMaxHeight = 46;

  static const double scrollbarThumb = 8;

  /// Identity tile radius at 16px and 36px sizes.
  static const double identityTile16 = 4;
  static const double identityTile36 = 8;

  /// Segmented control items: `calc(var(--radius-lg) - 2px)`.
  static const double segment = lg - 2;

  /// Tailwind `rounded-[40px]` on bordered badges.
  static const double badgePill = 40;

  static const double full = 9999;

  static BorderRadius circular(double radius) => BorderRadius.circular(radius);
}
