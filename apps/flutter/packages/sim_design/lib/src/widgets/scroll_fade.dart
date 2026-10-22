import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/tokens/layout.dart';

/// Which edges of a scroll region currently hide content (`ScrollEdges`).
@immutable
class SimScrollEdges {
  const SimScrollEdges({required this.start, required this.end});

  static const SimScrollEdges none = SimScrollEdges(start: false, end: false);

  final bool start;
  final bool end;

  @override
  bool operator ==(Object other) =>
      other is SimScrollEdges && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Port of `scroll-fade.module.css` + `use-scroll-edges.ts`: fades a scroll
/// region over a [band] px gradient at every edge that hides content, and
/// stays fully opaque at edges that do not, so a list that fits is never
/// fogged. Wrap the scrollable; edges are read from its scroll notifications.
///
/// The widget tree below the fade is the same whatever the edges are, so an
/// edge flip never remounts [child] (its scroll offset and any state below
/// it survive).
///
/// [inset] starts the leading band below a floating control
/// (`--scroll-fade-inset`).
class SimScrollFade extends StatefulWidget {
  const SimScrollFade({
    required this.child,
    super.key,
    this.axis = Axis.vertical,
    this.band = SimLayout.scrollFadeBand,
    this.inset = 0,
    this.onEdgesChanged,
  });

  final Widget child;
  final Axis axis;
  final double band;
  final double inset;
  final ValueChanged<SimScrollEdges>? onEdgesChanged;

  /// Sub-pixel scroll positions leave the metrics fractionally off at rest.
  static const double edgeTolerance = 1;

  static SimScrollEdges edgesOf(ScrollMetrics metrics) {
    if (!metrics.hasContentDimensions || !metrics.hasPixels) {
      return SimScrollEdges.none;
    }
    return SimScrollEdges(
      start: metrics.pixels - metrics.minScrollExtent > edgeTolerance,
      end: metrics.maxScrollExtent - metrics.pixels > edgeTolerance,
    );
  }

  @override
  State<SimScrollFade> createState() => _SimScrollFadeState();
}

class _SimScrollFadeState extends State<SimScrollFade> {
  SimScrollEdges _edges = SimScrollEdges.none;

  bool _onNotification(Notification notification) {
    ScrollMetrics? metrics;
    if (notification is ScrollMetricsNotification) {
      metrics = notification.metrics;
    } else if (notification is ScrollNotification) {
      metrics = notification.metrics;
    }
    if (metrics == null || metrics.axis != widget.axis) return false;
    final next = SimScrollFade.edgesOf(metrics);
    if (next != _edges) {
      setState(() => _edges = next);
      widget.onEdgesChanged?.call(next);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => _FadeMask(
    edges: _edges,
    axis: widget.axis,
    band: widget.band,
    inset: widget.inset,
    child: NotificationListener<Notification>(
      onNotification: _onNotification,
      child: widget.child,
    ),
  );
}

/// Paints its child through a `dstIn` gradient mask while an edge hides
/// content, and straight through (no layer) otherwise. Unlike swapping a
/// [ShaderMask] in and out, the render object stays in place across edge
/// changes, so the elements below it are kept.
class _FadeMask extends SingleChildRenderObjectWidget {
  const _FadeMask({
    required this.edges,
    required this.axis,
    required this.band,
    required this.inset,
    required super.child,
  });

  final SimScrollEdges edges;
  final Axis axis;
  final double band;
  final double inset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFadeMask(edges: edges, axis: axis, band: band, inset: inset);

  @override
  void updateRenderObject(BuildContext context, _RenderFadeMask renderObject) {
    renderObject
      ..edges = edges
      ..axis = axis
      ..band = band
      ..inset = inset;
  }
}

class _RenderFadeMask extends RenderProxyBox {
  _RenderFadeMask({
    required SimScrollEdges edges,
    required Axis axis,
    required double band,
    required double inset,
  }) : _edges = edges,
       _axis = axis,
       _band = band,
       _inset = inset;

  SimScrollEdges _edges;
  Axis _axis;
  double _band;
  double _inset;

  SimScrollEdges get edges => _edges;
  Axis get axis => _axis;
  double get band => _band;
  double get inset => _inset;

  set edges(SimScrollEdges value) {
    if (value == _edges) return;
    final wasMasking = _masking;
    _edges = value;
    if (wasMasking != _masking) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  set axis(Axis value) {
    if (value == _axis) return;
    _axis = value;
    markNeedsPaint();
  }

  set band(double value) {
    if (value == _band) return;
    _band = value;
    markNeedsPaint();
  }

  set inset(double value) {
    if (value == _inset) return;
    _inset = value;
    markNeedsPaint();
  }

  bool get _masking => _edges.start || _edges.end;

  @override
  bool get alwaysNeedsCompositing => child != null && _masking;

  Shader _shader(Rect bounds) {
    final length = _axis == Axis.vertical ? bounds.height : bounds.width;
    if (length <= 0) {
      return const LinearGradient(
        colors: <Color>[Color(0xFF000000), Color(0xFF000000)],
      ).createShader(bounds);
    }
    final startBegin = _edges.start ? _inset / length : 0.0;
    final startEnd = _edges.start ? (_inset + _band) / length : 0.0;
    final endBegin = _edges.end ? 1 - _band / length : 1.0;
    return LinearGradient(
      begin: _axis == Axis.vertical
          ? Alignment.topCenter
          : Alignment.centerLeft,
      end: _axis == Axis.vertical
          ? Alignment.bottomCenter
          : Alignment.centerRight,
      colors: const <Color>[
        Color(0x00000000),
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0x00000000),
      ],
      stops: <double>[
        startBegin.clamp(0, 1),
        startEnd.clamp(0, 1),
        endBegin.clamp(0, 1),
        1,
      ],
    ).createShader(bounds);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || !_masking) {
      layer = null;
      if (child != null) context.paintChild(child, offset);
      return;
    }
    final current = layer;
    final mask = (current is ShaderMaskLayer ? current : ShaderMaskLayer())
      ..shader = _shader(Offset.zero & size)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    layer = mask;
    context.pushLayer(mask, super.paint, offset);
  }
}
