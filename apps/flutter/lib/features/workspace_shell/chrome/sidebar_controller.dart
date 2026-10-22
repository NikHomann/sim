import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';

/// `SIDEBAR_WIDTH` (`stores/constants.ts:21-35`).
abstract final class SidebarWidth {
  static const double defaultWidth = 224;
  static const double min = 224;
  static const double max = 400;
  static const double collapsed = 48;
  static const double maxPercentage = 0.3;

  /// The mobile/desktop split (`use-is-mobile.ts:5`).
  static const double mobileBreakpoint = 768;
}

/// `getMaxSidebarWidth(vw)` = `max(224, min(400, vw × 0.3))`
/// (`stores/sidebar/store.ts:15-20`): 400 at 1440, 384 at 1280.
double getMaxSidebarWidth(double viewportWidth) => math.max(
  SidebarWidth.min,
  math.min(SidebarWidth.max, viewportWidth * SidebarWidth.maxPercentage),
);

/// `clampSidebarWidth` (`store.ts:23-30`): non-finite → the default; the
/// ceiling is [getMaxSidebarWidth] at desktop widths and 400 below 768px.
double clampSidebarWidth(double width, {required double viewportWidth}) {
  final target = width.isFinite ? width : SidebarWidth.defaultWidth;
  final ceiling = viewportWidth < SidebarWidth.mobileBreakpoint
      ? SidebarWidth.max
      : getMaxSidebarWidth(viewportWidth);
  return math.min(math.max(target, SidebarWidth.min), ceiling);
}

/// `useSidebarStore` (`stores/sidebar/store.ts`): the expanded width
/// persisted in `localStorage['sidebar-state']` (zustand envelope, written
/// through [SharedWebState] so the React app reads the same value) and the
/// collapse flag in the `sidebar_collapsed` cookie.
///
/// The rendered width is derived per viewport ([renderedWidth]); the stored
/// width is only re-clamped and persisted by [setSidebarWidth], which is a
/// no-op while collapsed.
class SidebarController extends ChangeNotifier {
  SidebarController({required SharedWebState storage})
    : _storage = storage,
      _width =
          storage.readSidebarWidth()?.toDouble() ?? SidebarWidth.defaultWidth,
      _collapsed = storage.readSidebarCollapsed();

  final SharedWebState _storage;
  double _width;
  bool _collapsed;

  /// The persisted expanded width (unclamped by viewport).
  double get storedWidth => _width;

  bool get isCollapsed => _collapsed;

  /// The expanded width at [viewportWidth] (`syncWidth`'s clamp).
  double expandedWidth(double viewportWidth) =>
      clampSidebarWidth(_width, viewportWidth: viewportWidth);

  /// What the rail occupies: 48 collapsed, else [expandedWidth].
  double renderedWidth(double viewportWidth) =>
      _collapsed ? SidebarWidth.collapsed : expandedWidth(viewportWidth);

  /// `setSidebarWidth`: ignored while collapsed; clamps against
  /// [viewportWidth], persists, notifies.
  void setSidebarWidth(double width, {required double viewportWidth}) {
    if (_collapsed) return;
    final clamped = clampSidebarWidth(width, viewportWidth: viewportWidth);
    _width = clamped;
    _storage.writeSidebarWidth(clamped.round());
    notifyListeners();
  }

  /// `toggleCollapsed`: flips and writes the cookie (`=1` / `=0`).
  void toggleCollapsed() => setCollapsed(collapsed: !_collapsed);

  void setCollapsed({required bool collapsed}) {
    if (_collapsed == collapsed) return;
    _collapsed = collapsed;
    _storage.writeSidebarCollapsed(collapsed: collapsed);
    notifyListeners();
  }

  /// Sign-out: `sidebar-state` is wiped upstream (`clearUserData`), so the
  /// key is removed (not rewritten with the default) and the width returns
  /// to the default; the collapse cookie survives.
  void reset() {
    _width = SidebarWidth.defaultWidth;
    _storage.clearSidebarWidth();
    notifyListeners();
  }
}
