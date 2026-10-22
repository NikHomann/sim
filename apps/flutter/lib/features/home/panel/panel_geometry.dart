/// The resource panel's width rules (`use-mothership-resize.ts:18-91`,
/// `MOTHERSHIP_WIDTH` in `stores/constants.ts:67-82`). Pure functions: the
/// layout, the drag and the keyboard all go through them.
library;

import 'dart:math' as math;

import 'package:flutter/services.dart';

/// `MOTHERSHIP_WIDTH.MIN`.
const double panelMinWidth = 280;

/// `MOTHERSHIP_WIDTH.MAX_PERCENTAGE` (of the viewport).
const double panelMaxViewportFraction = 0.8;

/// `MOTHERSHIP_WIDTH.CHAT_MIN`: the chat column's floor.
const double chatColumnMinWidth = 480;

/// `KEYBOARD_STEP_PX`.
const double panelKeyboardStep = 32;

/// `maxPanelWidth(vw, container)`: the tighter of the viewport share and
/// the chat column's own minimum, never below `min(280, container/2)`.
double maxPanelWidth(double viewportWidth, double containerWidth) => math.max(
  math.min(panelMinWidth, containerWidth / 2),
  math.min(
    viewportWidth * panelMaxViewportFraction,
    containerWidth - math.min(chatColumnMinWidth, containerWidth / 2),
  ),
);

/// What a drag snapshots at pointer-down (`DragGeometry`).
class PanelDragGeometry {
  const PanelDragGeometry({
    required this.panelRight,
    required this.grabOffset,
    required this.maxWidth,
  });

  /// Global x of the panel's right edge.
  final double panelRight;

  /// The pointer's offset from the panel's left edge when grabbed.
  final double grabOffset;
  final double maxWidth;
}

/// `panelWidthAt(clientX, g)`: the only place the drag clamps live.
double panelWidthAt(double globalX, PanelDragGeometry g) => math.max(
  math.min(panelMinWidth, g.maxWidth),
  math.min(g.panelRight - (globalX - g.grabOffset), g.maxWidth),
);

/// A separator key on the focused divider (`readSeparatorKey`).
enum SeparatorKey { left, right, min, max }

/// `readSeparatorKey`: arrows, Home and End without modifiers, outside IME
/// composition; anything else is not a separator key.
SeparatorKey? readSeparatorKey(KeyEvent event, {bool composing = false}) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
  if (composing) return null;
  final keyboard = HardwareKeyboard.instance;
  if (keyboard.isShiftPressed ||
      keyboard.isControlPressed ||
      keyboard.isAltPressed ||
      keyboard.isMetaPressed) {
    return null;
  }
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.arrowLeft) return SeparatorKey.left;
  if (key == LogicalKeyboardKey.arrowRight) return SeparatorKey.right;
  if (key == LogicalKeyboardKey.home) return SeparatorKey.min;
  if (key == LogicalKeyboardKey.end) return SeparatorKey.max;
  return null;
}

/// `keyboardPanelWidth`: the divider is the panel's left edge, so Left
/// widens; Home and End jump to the drag's bounds.
double keyboardPanelWidth(
  SeparatorKey key,
  double currentWidth,
  double maxWidth,
) {
  final minWidth = math.min(panelMinWidth, maxWidth);
  return switch (key) {
    SeparatorKey.min => minWidth,
    SeparatorKey.max => maxWidth,
    SeparatorKey.left => math.max(
      minWidth,
      math.min(currentWidth + panelKeyboardStep, maxWidth),
    ),
    SeparatorKey.right => math.max(
      minWidth,
      math.min(currentWidth - panelKeyboardStep, maxWidth),
    ),
  };
}

/// The rendered panel width: collapsed 0; a stored preference clamped to
/// the current [maxPanelWidth] (`restorePanelWidth`); otherwise the CSS
/// default `w-1/2` of the row.
double resolvePanelWidth({
  required bool collapsed,
  required double? preferred,
  required double viewportWidth,
  required double containerWidth,
}) {
  if (collapsed) return 0;
  if (preferred == null) return containerWidth / 2;
  return math.min(preferred, maxPanelWidth(viewportWidth, containerWidth));
}
