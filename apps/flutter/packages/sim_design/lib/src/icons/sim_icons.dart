import 'package:flutter/foundation.dart';

/// One SVG icon asset bundled with this package.
@immutable
class SimIconData {
  const SimIconData(this.name, {this.precompiled = false});

  /// Path stem under `assets/icons/` (e.g. `chevron-down`, `emcn/folder`).
  final String name;

  /// Whether a `vector_graphics` binary (`.vec`) ships next to the SVG.
  /// `SimIcon` renders it with a `srcIn` colour filter (every emcn icon is
  /// single-colour `currentColor`) and falls back to the SVG only when a
  /// `strokeWidth` override has to rewrite the source.
  final bool precompiled;

  String get assetPath => 'assets/icons/$name.svg';

  /// The precompiled asset, or `null` when only the SVG ships.
  String? get vecAssetPath => precompiled ? 'assets/icons/$name.vec' : null;

  @override
  bool operator ==(Object other) => other is SimIconData && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'SimIconData($name)';
}

/// The icons the widgets in this package need, hand-ported from
/// `packages/emcn/src/icons/*.tsx` (24x24 viewBox, `stroke="currentColor"`,
/// stroke-width 1.55, round caps and joins). The complete emcn set is
/// generated into `SimEmcnIcons` (`tool/generate_emcn_icons.dart`), which
/// aliases these constants where the two overlap.
abstract final class SimIcons {
  static const SimIconData chevronDown = SimIconData('chevron-down');
  static const SimIconData chevronRight = SimIconData('chevron-right');
  static const SimIconData chevronLeft = SimIconData('chevron-left');
  static const SimIconData chevronUp = SimIconData('chevron-up');
  static const SimIconData check = SimIconData('check');
  static const SimIconData x = SimIconData('x');
  static const SimIconData search = SimIconData('search');
  static const SimIconData plus = SimIconData('plus');
  static const SimIconData minus = SimIconData('minus');
  static const SimIconData bell = SimIconData('bell');
  static const SimIconData circleInfo = SimIconData('circle-info');
  static const SimIconData triangleAlert = SimIconData('triangle-alert');
  static const SimIconData circleAlert = SimIconData('circle-alert');
  static const SimIconData circleCheck = SimIconData('circle-check');
  static const SimIconData circleX = SimIconData('circle-x');
  static const SimIconData circle = SimIconData('circle');
  static const SimIconData loader = SimIconData('loader');
  static const SimIconData duplicate = SimIconData('duplicate');
  static const SimIconData eye = SimIconData('eye');
  static const SimIconData eyeOff = SimIconData('eye-off');

  static const List<SimIconData> all = <SimIconData>[
    chevronDown,
    chevronRight,
    chevronLeft,
    chevronUp,
    check,
    x,
    search,
    plus,
    minus,
    bell,
    circleInfo,
    triangleAlert,
    circleAlert,
    circleCheck,
    circleX,
    circle,
    loader,
    duplicate,
    eye,
    eyeOff,
  ];
}
