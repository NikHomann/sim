import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/interaction/keyboard.dart';
import 'package:sim_design/src/overlay/overlay_manager.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/tokens/shadows.dart';
import 'package:sim_design/src/tokens/z.dart';

/// Horizontal placement relative to the pointer (`alignX`).
enum SimTooltipAlignX { left, right }

/// Vertical placement relative to the pointer (`alignY`).
enum SimTooltipAlignY { above, below }

/// Resolved position of a floating tooltip (`FloatingTooltipState` in
/// `packages/emcn/src/components/tooltip/tooltip.tsx`); `x`/`y` are whole-pixel
/// host coordinates the bubble anchors to.
@immutable
class SimFloatingTooltipState {
  const SimFloatingTooltipState({
    required this.visible,
    required this.x,
    required this.y,
    required this.alignX,
    required this.alignY,
  });

  static const SimFloatingTooltipState hidden = SimFloatingTooltipState(
    visible: false,
    x: 0,
    y: 0,
    alignX: SimTooltipAlignX.left,
    alignY: SimTooltipAlignY.below,
  );

  final bool visible;
  final double x;
  final double y;
  final SimTooltipAlignX alignX;
  final SimTooltipAlignY alignY;

  @override
  bool operator ==(Object other) =>
      other is SimFloatingTooltipState &&
      other.visible == visible &&
      other.x == x &&
      other.y == y &&
      other.alignX == alignX &&
      other.alignY == alignY;

  @override
  int get hashCode => Object.hash(visible, x, y, alignX, alignY);
}

/// `getTooltipPosition`: flips away from the nearest edge (360px threshold,
/// half that vertically) and clamps the anchor inside the 16px gutter.
SimFloatingTooltipState resolveTooltipPosition(
  Offset hostLocal,
  Size host, {
  bool preferAbove = false,
}) {
  const threshold = SimLayout.tooltipEdgeThreshold;
  const gutter = SimLayout.tooltipEdgeGutter;
  final alignX = host.width - hostLocal.dx < threshold
      ? SimTooltipAlignX.right
      : SimTooltipAlignX.left;
  final nearTop = hostLocal.dy < threshold / 2;
  final nearBottom = host.height - hostLocal.dy < threshold / 2;
  final alignY = preferAbove
      ? (nearTop ? SimTooltipAlignY.below : SimTooltipAlignY.above)
      : (nearBottom ? SimTooltipAlignY.above : SimTooltipAlignY.below);
  double clamp(double v, double max) =>
      max <= 2 * gutter ? v : v.clamp(gutter, max - gutter);
  return SimFloatingTooltipState(
    visible: true,
    x: clamp(hostLocal.dx, host.width).roundToDouble(),
    y: clamp(hostLocal.dy, host.height).roundToDouble(),
    alignX: alignX,
    alignY: alignY,
  );
}

/// Drives a cursor-following tooltip (`useFloatingTooltip`). Attach the
/// handlers to a trigger and render a [SimFloatingTooltip] with it.
class SimFloatingTooltipController extends ChangeNotifier {
  SimFloatingTooltipController({this.preferAbove = false, this.canShow});

  final bool preferAbove;

  /// Checked on every gesture; the tooltip hides when it turns false.
  final bool Function()? canShow;

  SimFloatingTooltipState _state = SimFloatingTooltipState.hidden;
  SimFloatingTooltipState get state => _state;
  bool get visible => _state.visible;

  void _apply(SimFloatingTooltipState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  /// Shows (or moves) the bubble at a global pointer position.
  void showAtPointer(Offset global, SimOverlayController overlay) {
    if (canShow != null && !canShow!()) return hide();
    _apply(
      resolveTooltipPosition(
        overlay.globalToHost(global),
        overlay.hostSize,
        preferAbove: preferAbove,
      ),
    );
  }

  /// Anchors the bubble to an element's edge centre (keyboard focus).
  void showFromRect(Rect hostRect, SimOverlayController overlay) {
    if (canShow != null && !canShow!()) return hide();
    _apply(
      resolveTooltipPosition(
        Offset(
          hostRect.center.dx,
          preferAbove ? hostRect.top : hostRect.bottom,
        ),
        overlay.hostSize,
        preferAbove: preferAbove,
      ),
    );
  }

  void hide() {
    if (!_state.visible) return;
    _apply(SimFloatingTooltipState.hidden);
  }

  /// Re-checks [canShow] while visible (`revalidateKey`).
  void revalidate() {
    if (_state.visible && canShow != null && !canShow!()) hide();
  }
}

/// Floating tooltip body. Renders nothing in place; while the controller is
/// visible it mounts a layer at [SimZ.tooltip] positioned from the state:
/// 16px from the pointer, flipped away from the nearest edge, eased 150ms.
class SimFloatingTooltip extends StatefulWidget {
  const SimFloatingTooltip({
    required this.controller,
    super.key,
    this.label,
    this.child,
    this.offset = SimLayout.tooltipOffset,
    this.semanticsRole = false,
  });

  final SimFloatingTooltipController controller;

  /// Text shown when no [child] is provided (the overflow-tooltip case).
  final String? label;

  /// Arbitrary content; overrides [label].
  final Widget? child;

  /// Cursor-to-bubble gap in px.
  final double offset;

  /// `role='tooltip'` for described tooltips; false for decorative overflow.
  final bool semanticsRole;

  @override
  State<SimFloatingTooltip> createState() => _SimFloatingTooltipState();
}

class _SimFloatingTooltipState extends State<SimFloatingTooltip> {
  SimOverlayEntry? _entry;
  SimOverlayController? _overlay;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(SimFloatingTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
    _entry?.markNeedsBuild();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overlay = SimOverlay.maybeOf(context);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _sync() {
    final visible = widget.controller.visible;
    final overlay = _overlay;
    if (visible && _entry == null && overlay != null) {
      final entry = SimOverlayEntry(
        z: SimZ.tooltip,
        dismissOnOutsideTap: false,
        dismissOnEscape: false,
        builder: (context) => _TooltipLayer(
          controller: widget.controller,
          offset: widget.offset,
          label: widget.label,
          semanticsRole: widget.semanticsRole,
          child: widget.child,
        ),
      );
      _entry = entry;
      overlay.insert(entry);
    } else if (!visible && _entry != null) {
      _entry!.remove();
      _entry = null;
    } else {
      _entry?.markNeedsBuild();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _TooltipLayer extends StatelessWidget {
  const _TooltipLayer({
    required this.controller,
    required this.offset,
    required this.label,
    required this.semanticsRole,
    required this.child,
  });

  final SimFloatingTooltipController controller;
  final double offset;
  final String? label;
  final bool semanticsRole;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        return TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(end: Offset(state.x, state.y)),
          duration: SimMotion.of(SimMotion.tooltip),
          curve: SimMotion.easeOut,
          builder: (context, position, body) => CustomSingleChildLayout(
            delegate: _TooltipDelegate(
              x: position.dx,
              y: position.dy,
              alignX: state.alignX,
              alignY: state.alignY,
              offset: offset,
            ),
            child: body,
          ),
          child: IgnorePointer(
            child: Semantics(
              container: true,
              tooltip: semanticsRole ? label : null,
              child: SimTooltipSurface(
                child:
                    child ??
                    Text(
                      label ?? '',
                      style: sim.text.caption.copyWith(color: c.textBody),
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `TOOLTIP_SURFACE_CLASS`: w-fit, max-w min(256px, 100vw - 2rem), rounded-lg,
/// `--border` border, `--bg` fill, text-caption `--text-body`, shadow-xs,
/// px-2 py-1.5.
class SimTooltipSurface extends StatelessWidget {
  const SimTooltipSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final viewport = MediaQuery.maybeOf(context)?.size.width ?? double.infinity;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.max(
          0,
          math.min(SimLayout.tooltipMaxWidth, viewport - 32),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.bg,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(SimRadii.lg),
          boxShadow: SimShadows.xs,
        ),
        child: Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: sim.text.caption.copyWith(color: c.textBody),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TooltipDelegate extends SingleChildLayoutDelegate {
  const _TooltipDelegate({
    required this.x,
    required this.y,
    required this.alignX,
    required this.alignY,
    required this.offset,
  });

  final double x;
  final double y;
  final SimTooltipAlignX alignX;
  final SimTooltipAlignY alignY;
  final double offset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const gutter = SimLayout.tooltipEdgeGutter;
    final left = alignX == SimTooltipAlignX.left
        ? x + offset
        : x - offset - childSize.width;
    final top = alignY == SimTooltipAlignY.below
        ? y + offset
        : y - offset - childSize.height;
    return Offset(
      _contain(left, size.width, childSize.width, gutter),
      _contain(top, size.height, childSize.height, gutter),
    );
  }

  /// `containTooltipAxis`: keep the bubble inside the gutter, shrinking the
  /// gutter in windows too small to honour it.
  static double _contain(
    double pos,
    double viewport,
    double size,
    double gutter,
  ) {
    final maxPos = math.max(0, viewport - size).toDouble();
    final low = math.min(gutter, maxPos);
    final inner = pos.clamp(low, math.max(low, viewport - size - gutter));
    return inner.clamp(0, maxPos).toDouble();
  }

  @override
  bool shouldRelayout(_TooltipDelegate oldDelegate) =>
      x != oldDelegate.x ||
      y != oldDelegate.y ||
      alignX != oldDelegate.alignX ||
      alignY != oldDelegate.alignY ||
      offset != oldDelegate.offset;
}

/// `Tooltip.Root` + `Trigger` + `Content` in one widget: a cursor-following
/// bubble that appears with no delay on mouse hover, follows the pointer at
/// a 16px offset, hides on pointer down or leave, and anchors to the trigger
/// when it receives keyboard focus. Touch never shows it.
class SimTooltip extends StatefulWidget {
  const SimTooltip({
    required this.child,
    super.key,
    this.message,
    this.content,
    this.preferAbove = false,
    this.offset = SimLayout.tooltipOffset,
    this.enabled = true,
  });

  final Widget child;
  final String? message;
  final Widget? content;
  final bool preferAbove;
  final double offset;
  final bool enabled;

  @override
  State<SimTooltip> createState() => _SimTooltipState();
}

class _SimTooltipState extends State<SimTooltip> {
  late SimFloatingTooltipController _controller = SimFloatingTooltipController(
    preferAbove: widget.preferAbove,
    canShow: () => widget.enabled,
  );

  @override
  void didUpdateWidget(SimTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferAbove != widget.preferAbove) {
      _controller.dispose();
      _controller = SimFloatingTooltipController(
        preferAbove: widget.preferAbove,
        canShow: () => widget.enabled,
      );
    }
    if (!widget.enabled) _controller.hide();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pointer(PointerEvent event) {
    if (event.kind == PointerDeviceKind.touch) return;
    final overlay = SimOverlay.maybeOf(context);
    if (overlay == null) return;
    _controller.showAtPointer(event.position, overlay);
  }

  @override
  Widget build(BuildContext context) {
    final hasContent =
        widget.content != null || (widget.message ?? '').isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) {
            if (!focused) return _controller.hide();
            if (!isFocusVisibleMode) return;
            final overlay = SimOverlay.maybeOf(context);
            if (overlay == null) return;
            _controller.showFromRect(overlay.rectOf(context), overlay);
          },
          child: MouseRegion(
            opaque: false,
            onEnter: _pointer,
            onHover: _pointer,
            onExit: (_) => _controller.hide(),
            child: Listener(
              onPointerDown: (_) => _controller.hide(),
              child: widget.child,
            ),
          ),
        ),
        if (hasContent)
          SimFloatingTooltip(
            controller: _controller,
            label: widget.message,
            offset: widget.offset,
            semanticsRole: true,
            child: widget.content,
          ),
      ],
    );
  }
}

/// `Tooltip.Shortcut`: label followed by the key combo at 70% opacity.
class SimTooltipShortcut extends StatelessWidget {
  const SimTooltipShortcut({required this.keys, super.key, this.child});

  final String keys;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      if (child != null) ...<Widget>[child!, const SizedBox(width: 8)],
      Opacity(opacity: 0.7, child: Text(keys)),
    ],
  );
}
