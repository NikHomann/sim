import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sim_design/src/tokens/motion.dart';

/// Which edge of the anchor a floating surface attaches to (Radix `side`).
enum SimSide { top, right, bottom, left }

/// Alignment along the anchor's edge (Radix `align`).
enum SimAlign { start, center, end }

/// Positions a floating surface against an anchor rect with Radix popper
/// semantics: preferred [side] with collision flipping, [align] along the
/// edge, [sideOffset]/[alignOffset], [collisionPadding] from the host edges,
/// partial stickiness (the surface shifts along the edge to stay on screen),
/// an optional `matchAnchorWidth` (`--radix-*-trigger-width`), and a height
/// cap that respects the available space on the resolved side
/// (`--radix-popper-available-height`).
///
/// [animation] drives the `POPOVER_ANIMATION_CLASSES` enter/exit: fade,
/// zoom from 95% and an 8px slide from the anchor side.
class SimAnchoredOverlay extends StatefulWidget {
  const SimAnchoredOverlay({
    required this.anchor,
    required this.child,
    super.key,
    this.side = SimSide.bottom,
    this.align = SimAlign.start,
    this.sideOffset = 0,
    this.alignOffset = 0,
    this.collisionPadding = 8,
    this.avoidCollisions = true,
    this.matchAnchorWidth = false,
    this.minWidth,
    this.maxWidth,
    this.maxHeight,
    this.animation,
    this.contentKey,
  });

  /// Anchor rect in the overlay host's coordinates.
  final Rect anchor;
  final Widget child;
  final SimSide side;
  final SimAlign align;
  final double sideOffset;
  final double alignOffset;
  final double collisionPadding;
  final bool avoidCollisions;
  final bool matchAnchorWidth;
  final double? minWidth;
  final double? maxWidth;
  final double? maxHeight;
  final Animation<double>? animation;

  /// Key attached to the laid-out content so the overlay host can hit-test it.
  final Key? contentKey;

  @override
  State<SimAnchoredOverlay> createState() => _SimAnchoredOverlayState();
}

class _SimAnchoredOverlayState extends State<SimAnchoredOverlay> {
  late _AnchoredDelegate _delegate = _makeDelegate();

  _AnchoredDelegate _makeDelegate() => _AnchoredDelegate(
    anchor: widget.anchor,
    side: widget.side,
    align: widget.align,
    sideOffset: widget.sideOffset,
    alignOffset: widget.alignOffset,
    padding: widget.collisionPadding,
    avoidCollisions: widget.avoidCollisions,
    matchAnchorWidth: widget.matchAnchorWidth,
    minWidth: widget.minWidth,
    maxWidth: widget.maxWidth,
    maxHeight: widget.maxHeight,
  );

  @override
  void didUpdateWidget(SimAnchoredOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _delegate = _makeDelegate();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = KeyedSubtree(key: widget.contentKey, child: widget.child);
    final animation = widget.animation;
    if (animation != null && !SimMotion.disabled) {
      content = AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value;
          final side = _delegate.resolvedSide;
          final slide = (1 - t) * SimMotion.popoverSlidePx;
          final offset = switch (side) {
            SimSide.bottom => Offset(0, -slide),
            SimSide.top => Offset(0, slide),
            SimSide.right => Offset(-slide, 0),
            SimSide.left => Offset(slide, 0),
          };
          final origin = switch (side) {
            SimSide.bottom => Alignment.topCenter,
            SimSide.top => Alignment.bottomCenter,
            SimSide.right => Alignment.centerLeft,
            SimSide.left => Alignment.centerRight,
          };
          return Opacity(
            opacity: t.clamp(0, 1),
            child: Transform.translate(
              offset: offset,
              child: Transform.scale(
                scale: SimMotion.zoomStart + (1 - SimMotion.zoomStart) * t,
                alignment: origin,
                child: child,
              ),
            ),
          );
        },
        child: content,
      );
    }
    return CustomSingleChildLayout(delegate: _delegate, child: content);
  }
}

class _AnchoredDelegate extends SingleChildLayoutDelegate {
  _AnchoredDelegate({
    required this.anchor,
    required this.side,
    required this.align,
    required this.sideOffset,
    required this.alignOffset,
    required this.padding,
    required this.avoidCollisions,
    required this.matchAnchorWidth,
    required this.minWidth,
    required this.maxWidth,
    required this.maxHeight,
  }) : resolvedSide = side;

  final Rect anchor;
  final SimSide side;
  final SimAlign align;
  final double sideOffset;
  final double alignOffset;
  final double padding;
  final bool avoidCollisions;
  final bool matchAnchorWidth;
  final double? minWidth;
  final double? maxWidth;
  final double? maxHeight;

  SimSide resolvedSide;
  Size _host = Size.zero;

  bool get _vertical => side == SimSide.top || side == SimSide.bottom;

  double _availableMain(SimSide s) => switch (s) {
    SimSide.bottom => _host.height - anchor.bottom - sideOffset - padding,
    SimSide.top => anchor.top - sideOffset - padding,
    SimSide.right => _host.width - anchor.right - sideOffset - padding,
    SimSide.left => anchor.left - sideOffset - padding,
  };

  SimSide get _opposite => switch (side) {
    SimSide.bottom => SimSide.top,
    SimSide.top => SimSide.bottom,
    SimSide.right => SimSide.left,
    SimSide.left => SimSide.right,
  };

  @override
  Size getSize(BoxConstraints constraints) => _host = constraints.biggest;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    _host = constraints.biggest;
    final crossCap = _host.width - 2 * padding;
    final preferred = math.max(0, _availableMain(side)).toDouble();
    final opposite = math.max(0, _availableMain(_opposite)).toDouble();
    final mainCap = avoidCollisions ? math.max(preferred, opposite) : preferred;
    double maxW;
    double minW;
    double maxH;
    if (_vertical) {
      maxW = math.min(maxWidth ?? double.infinity, crossCap);
      minW = math.min(minWidth ?? 0, maxW);
      maxH = math.min(maxHeight ?? double.infinity, mainCap);
    } else {
      maxW = math.min(maxWidth ?? double.infinity, mainCap);
      minW = math.min(minWidth ?? 0, maxW);
      maxH = math.min(maxHeight ?? double.infinity, _host.height - 2 * padding);
    }
    if (matchAnchorWidth) {
      final w = math.min(anchor.width, crossCap);
      return BoxConstraints(
        minWidth: w,
        maxWidth: w,
        maxHeight: math.max(0, maxH),
      );
    }
    return BoxConstraints(
      minWidth: math.max(0, minW),
      maxWidth: math.max(0, maxW),
      maxHeight: math.max(0, maxH),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    _host = size;
    var s = side;
    if (avoidCollisions) {
      final needed = _vertical ? childSize.height : childSize.width;
      final preferred = _availableMain(side);
      final opposite = _availableMain(_opposite);
      if (needed > preferred && opposite > preferred) s = _opposite;
    }
    resolvedSide = s;

    double main;
    double cross;
    final vertical = s == SimSide.top || s == SimSide.bottom;
    if (vertical) {
      main = s == SimSide.bottom
          ? anchor.bottom + sideOffset
          : anchor.top - sideOffset - childSize.height;
      cross = switch (align) {
        SimAlign.start => anchor.left + alignOffset,
        SimAlign.center => anchor.center.dx - childSize.width / 2 + alignOffset,
        SimAlign.end => anchor.right - childSize.width - alignOffset,
      };
      cross = _clamp(cross, padding, size.width - padding - childSize.width);
      main = _clamp(main, padding, size.height - padding - childSize.height);
      return Offset(cross, main);
    }
    main = s == SimSide.right
        ? anchor.right + sideOffset
        : anchor.left - sideOffset - childSize.width;
    cross = switch (align) {
      SimAlign.start => anchor.top + alignOffset,
      SimAlign.center => anchor.center.dy - childSize.height / 2 + alignOffset,
      SimAlign.end => anchor.bottom - childSize.height - alignOffset,
    };
    cross = _clamp(cross, padding, size.height - padding - childSize.height);
    main = _clamp(main, padding, size.width - padding - childSize.width);
    return Offset(main, cross);
  }

  static double _clamp(double value, double min, double max) {
    if (max < min) return min;
    return value.clamp(min, max);
  }

  @override
  bool shouldRelayout(_AnchoredDelegate oldDelegate) =>
      anchor != oldDelegate.anchor ||
      side != oldDelegate.side ||
      align != oldDelegate.align ||
      sideOffset != oldDelegate.sideOffset ||
      alignOffset != oldDelegate.alignOffset ||
      padding != oldDelegate.padding ||
      avoidCollisions != oldDelegate.avoidCollisions ||
      matchAnchorWidth != oldDelegate.matchAnchorWidth ||
      minWidth != oldDelegate.minWidth ||
      maxWidth != oldDelegate.maxWidth ||
      maxHeight != oldDelegate.maxHeight;
}
