import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/overlay/overlay_manager.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/widgets/tooltip.dart';

/// Port of `packages/emcn/src/components/overflow-text/overflow-text.tsx`:
/// a single-line, read-only label that clips without an ellipsis, fades over
/// its last [fadeSize] px only when actually clipped, and shows its complete
/// value in the floating tooltip on hover or keyboard focus.
///
/// Give it bounded width (`Expanded`/`Flexible` in a row); unbounded width
/// never overflows. Intrinsic sizing works, so it can sit in a `Table`.
class SimOverflowText extends StatefulWidget {
  const SimOverflowText({
    required this.label,
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.showWhen = false,
    this.tooltipEnabled = true,
    this.fadeSize = SimLayout.overflowFade,
    this.child,
  });

  /// Full text shown in the tooltip and used as the visible content.
  final String label;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Forces the tooltip when the visible label was shortened before rendering.
  final bool showWhen;

  /// Whether the full-value tooltip may open.
  final bool tooltipEnabled;
  final double fadeSize;

  /// Decorated rendering of [label]; the tooltip keeps the plain label.
  final Widget? child;

  @override
  State<SimOverflowText> createState() => _SimOverflowTextState();
}

class _SimOverflowTextState extends State<SimOverflowText> {
  late final SimFloatingTooltipController _tooltip =
      SimFloatingTooltipController(canShow: () => _eligible);
  bool _overflowing = false;

  bool get _eligible =>
      widget.tooltipEnabled &&
      widget.label.isNotEmpty &&
      (widget.showWhen || _overflowing);

  @override
  void didUpdateWidget(SimOverflowText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tooltip.revalidate();
  }

  @override
  void dispose() {
    _tooltip.dispose();
    super.dispose();
  }

  void _pointer(PointerEvent event) {
    if (event.kind == PointerDeviceKind.touch) return;
    final overlay = SimOverlay.maybeOf(context);
    if (overlay == null) return;
    _tooltip.showAtPointer(event.position, overlay);
  }

  void _onOverflowChanged(bool value) {
    if (_overflowing == value) return;
    _overflowing = value;
    _tooltip.revalidate();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final text =
        widget.child ??
        Text(
          widget.label,
          style: style,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          textAlign: widget.textAlign,
        );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        MouseRegion(
          opaque: false,
          onEnter: _pointer,
          onHover: _pointer,
          onExit: (_) => _tooltip.hide(),
          child: Listener(
            onPointerDown: (_) => _tooltip.hide(),
            child: SimClipFade(
              fadeSize: widget.fadeSize,
              onOverflowChanged: _onOverflowChanged,
              child: text,
            ),
          ),
        ),
        SimFloatingTooltip(controller: _tooltip, label: widget.label),
      ],
    );
  }
}

/// `overflowTextFadeClass`: clips a single-line child to the available width
/// and fades its trailing [fadeSize] px when (and only when) its natural width
/// exceeds the box. Reports overflow changes after layout.
class SimClipFade extends SingleChildRenderObjectWidget {
  const SimClipFade({
    required super.child,
    super.key,
    this.fadeSize = SimLayout.overflowFade,
    this.onOverflowChanged,
  });

  final double fadeSize;
  final ValueChanged<bool>? onOverflowChanged;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderSimClipFade(
    fadeSize: fadeSize,
    onOverflowChanged: onOverflowChanged,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSimClipFade renderObject,
  ) {
    renderObject
      ..fadeSize = fadeSize
      ..onOverflowChanged = onOverflowChanged;
  }
}

/// Render object of [SimClipFade].
class RenderSimClipFade extends RenderProxyBox {
  RenderSimClipFade({required double fadeSize, this.onOverflowChanged})
    : _fadeSize = fadeSize;

  double _fadeSize;
  double get fadeSize => _fadeSize;
  set fadeSize(double value) {
    if (_fadeSize == value) return;
    _fadeSize = value;
    markNeedsPaint();
  }

  ValueChanged<bool>? onOverflowChanged;
  bool _overflow = false;
  bool _reported = false;

  /// Whether the child was wider than the box at the last layout.
  bool get overflowing => _overflow;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      _setOverflow(false);
      return;
    }
    final natural = child.getMaxIntrinsicWidth(double.infinity);
    final overflow =
        constraints.hasBoundedWidth && natural > constraints.maxWidth + 1;
    child.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(child.size);
    _setOverflow(overflow);
  }

  void _setOverflow(bool value) {
    if (_overflow == value && _reported) return;
    _overflow = value;
    _reported = true;
    final callback = onOverflowChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) callback(value);
    });
  }

  @override
  bool get alwaysNeedsCompositing => _overflow && _fadeSize > 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (!_overflow || _fadeSize <= 0 || size.width <= 0) {
      context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        super.paint,
      );
      return;
    }
    final start = size.width <= _fadeSize ? 0.0 : 1 - _fadeSize / size.width;
    final layer = ShaderMaskLayer()
      ..shader = LinearGradient(
        colors: const <Color>[
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0x00000000),
        ],
        stops: <double>[0, start, 1],
      ).createShader(Offset.zero & size)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(layer, (context, offset) {
      context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        super.paint,
      );
    }, offset);
  }
}
