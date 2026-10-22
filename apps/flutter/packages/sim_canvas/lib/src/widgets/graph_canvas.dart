import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_canvas/src/hit_record.dart';
import 'package:sim_canvas/src/layers/edge_layer.dart';
import 'package:sim_canvas/src/layers/node_layer.dart';
import 'package:sim_canvas/src/model/canvas_graph.dart';
import 'package:sim_canvas/src/viewport/canvas_viewport.dart';
import 'package:sim_canvas/src/widgets/node_card.dart';

/// The graph editor surface: viewport gestures, the node layer (one of two
/// implementations) and the edge layer, with node drag.
///
/// Gestures:
/// - primary-button drag on empty space pans;
/// - wheel pans; ctrl/cmd + wheel zooms around the cursor; trackpad pinch
///   (`PointerScaleEvent`, `PointerPanZoom*`) zooms/pans;
/// - drag on a node moves it (delta divided by zoom).
class GraphCanvas extends StatefulWidget {
  const GraphCanvas({
    required this.controller,
    required this.viewport,
    this.implementation = const RenderBoxNodeLayer(),
    this.rasterPolicy = RasterPolicy.duringGestures,
    this.onHit,
    this.nodeBuilder,
    this.backgroundColor = const Color(0xFFF1F5F9),
    this.contentMargin = 100,
    super.key,
  });

  final GraphController controller;
  final CanvasViewport viewport;
  final NodeLayerImplementation implementation;
  final RasterPolicy rasterPolicy;

  /// Reports what a tap resolved to.
  final ValueChanged<HitRecord>? onHit;
  final NodeWidgetBuilder? nodeBuilder;
  final Color backgroundColor;

  /// Canvas units added around the content bounds that size the layers.
  final double contentMargin;

  /// Wheel zoom: `factor = exp(-deltaY * wheelZoomSensitivity)`.
  static const double wheelZoomSensitivity = 0.0015;

  @override
  State<GraphCanvas> createState() => GraphCanvasState();
}

class GraphCanvasState extends State<GraphCanvas> {
  late Rect _contentBounds;
  Timer? _wheelGesture;
  bool _wheelGestureActive = false;
  double _panZoomLastScale = 1;

  /// The screen-space rect of the canvas widget, for tests and tools that
  /// translate between global and canvas coordinates.
  Rect get contentBounds => _contentBounds;

  @override
  void initState() {
    super.initState();
    _recomputeBounds();
  }

  @override
  void didUpdateWidget(GraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.contentMargin != widget.contentMargin) {
      _recomputeBounds();
    }
  }

  @override
  void dispose() {
    _wheelGesture?.cancel();
    if (_wheelGestureActive) widget.viewport.endGesture();
    super.dispose();
  }

  void _recomputeBounds() {
    _contentBounds = widget.controller.contentBounds().inflate(
      widget.contentMargin,
    );
  }

  /// Re-derives the layer bounds from the current node positions (call after
  /// a drag ends; during the drag the bounds are left alone so that nothing
  /// re-lays out).
  void refreshBounds() {
    final next = widget.controller.contentBounds().inflate(
      widget.contentMargin,
    );
    if (next != _contentBounds) setState(() => _contentBounds = next);
  }

  void fitToView() =>
      widget.viewport.fitToView(widget.controller.contentBounds());

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (event) {
        final scroll = event as PointerScrollEvent;
        final keyboard = HardwareKeyboard.instance;
        _touchWheelGesture();
        if (keyboard.isControlPressed || keyboard.isMetaPressed) {
          final factor = math.exp(
            -scroll.scrollDelta.dy * GraphCanvas.wheelZoomSensitivity,
          );
          widget.viewport.zoomAt(scroll.localPosition, factor);
        } else {
          widget.viewport.panBy(-scroll.scrollDelta);
        }
      });
    } else if (event is PointerScaleEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (event) {
        _touchWheelGesture();
        widget.viewport.zoomAt(
          event.localPosition,
          (event as PointerScaleEvent).scale,
        );
      });
    }
  }

  /// Wheel events have no start/end, so the gesture flag is held for a short
  /// idle timeout after the last event.
  void _touchWheelGesture() {
    if (!_wheelGestureActive) {
      _wheelGestureActive = true;
      widget.viewport.beginGesture();
    }
    _wheelGesture?.cancel();
    _wheelGesture = Timer(const Duration(milliseconds: 150), () {
      _wheelGestureActive = false;
      widget.viewport.endGesture();
    });
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _panZoomLastScale = 1;
    widget.viewport.beginGesture();
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    widget.viewport.panBy(event.panDelta);
    if (event.scale != _panZoomLastScale) {
      widget.viewport.zoomAt(
        event.localPosition,
        event.scale / _panZoomLastScale,
      );
      _panZoomLastScale = event.scale;
    }
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent event) =>
      widget.viewport.endGesture();

  Widget _buildNode(BuildContext context, CanvasNode node) {
    final child =
        widget.nodeBuilder?.call(context, node) ?? NodeCard(node: node);
    return _NodeInteraction(
      node: node,
      controller: widget.controller,
      viewport: widget.viewport,
      onHit: widget.onHit,
      onDragEnd: refreshBounds,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = widget.viewport;
    final scope = NodeLayerScope(
      viewport: viewport,
      controller: widget.controller,
      contentBounds: _contentBounds,
      nodeBuilder: _buildNode,
      edgeLayer: EdgeLayer(
        controller: widget.controller,
        bounds: _contentBounds,
        onEdgeTap: widget.onHit == null
            ? null
            : (id) => widget.onHit!(HitRecord.edge(id)),
      ),
      rasterPolicy: widget.rasterPolicy,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        viewport.viewportSize = constraints.biggest;
        return ClipRect(
          child: Listener(
            onPointerSignal: _onPointerSignal,
            onPointerPanZoomStart: _onPanZoomStart,
            onPointerPanZoomUpdate: _onPanZoomUpdate,
            onPointerPanZoomEnd: _onPanZoomEnd,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onTapDown: widget.onHit == null
                  ? null
                  : (_) => widget.onHit!(const HitRecord.empty()),
              onPanStart: (_) => viewport.beginGesture(),
              onPanUpdate: (details) => viewport.panBy(details.delta),
              onPanEnd: (_) => viewport.endGesture(),
              onPanCancel: viewport.endGesture,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(color: widget.backgroundColor),
                  widget.implementation.build(scope),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tap and drag handling for one node. Dragging is a node gesture, not a
/// viewport gesture, so it does not toggle the raster-cache flag.
class _NodeInteraction extends StatelessWidget {
  const _NodeInteraction({
    required this.node,
    required this.controller,
    required this.viewport,
    required this.child,
    required this.onDragEnd,
    this.onHit,
  });

  final CanvasNode node;
  final GraphController controller;
  final CanvasViewport viewport;
  final Widget child;
  final VoidCallback onDragEnd;
  final ValueChanged<HitRecord>? onHit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onTapDown: onHit == null ? null : (_) => onHit!(HitRecord.node(node.id)),
      onPanUpdate: (details) =>
          controller.moveNodeBy(node.id, details.delta / viewport.zoom),
      onPanEnd: (_) => onDragEnd(),
      onPanCancel: onDragEnd,
      child: child,
    );
  }
}
