import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_canvas/src/model/canvas_graph.dart';
import 'package:sim_canvas/src/viewport/canvas_viewport.dart';

/// When the scene is composited from a cached raster instead of repainted.
enum RasterPolicy {
  /// Always paint vector content under a `TransformLayer`.
  never,

  /// While [CanvasViewport.isGestureActive], composite through an
  /// `ImageFilterLayer(ImageFilter.matrix)` so the engine can cache the scene
  /// as a texture and only re-blit it per frame.
  duringGestures,
}

typedef NodeWidgetBuilder =
    Widget Function(BuildContext context, CanvasNode node);

/// Everything a node-layer implementation needs to build the scene.
class NodeLayerScope {
  const NodeLayerScope({
    required this.viewport,
    required this.controller,
    required this.contentBounds,
    required this.nodeBuilder,
    required this.edgeLayer,
    required this.rasterPolicy,
  });

  final CanvasViewport viewport;
  final GraphController controller;

  /// Canvas-unit rect enclosing every node and edge (plus margin).
  final Rect contentBounds;
  final NodeWidgetBuilder nodeBuilder;

  /// Already sized to [contentBounds]; placed at `contentBounds.topLeft`.
  final Widget edgeLayer;
  final RasterPolicy rasterPolicy;
}

/// One of the two interchangeable scene implementations measured by the spike.
abstract class NodeLayerImplementation {
  const NodeLayerImplementation();

  String get name;

  Widget build(NodeLayerScope scope);
}

/// Wraps a node widget so that it rebuilds (only itself) when its position
/// notifier changes.
class _PositionedNode extends StatelessWidget {
  const _PositionedNode({
    required this.node,
    required this.controller,
    required this.builder,
    required this.place,
  });

  final CanvasNode node;
  final GraphController controller;
  final NodeWidgetBuilder builder;
  final Widget Function(Offset absolute, Widget child) place;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: controller.positionListenable(node.id),
      // One picture per node: pan/zoom only re-composite the layer tree.
      child: RepaintBoundary(child: builder(context, node)),
      builder: (context, position, child) => place(position, child!),
    );
  }
}

/// Implementation A: `Stack` + `Transform`.
///
/// The `Stack` is sized to the content bounds and the transform includes
/// the bounds origin, so every node lies inside the `Stack` and passes its
/// `RenderBox.hitTest` bounds check; `RenderTransform.hitTest` deliberately
/// skips its own size check. The price is that the bounds must be
/// recomputed (a full rebuild of the layer) whenever a node moves outside
/// them, which `GraphCanvasState.refreshBounds` does at drag end.
class StackNodeLayer extends NodeLayerImplementation {
  const StackNodeLayer();

  @override
  String get name => 'stack';

  @override
  Widget build(NodeLayerScope scope) {
    final bounds = scope.contentBounds;
    final children = <Widget>[
      Positioned(left: 0, top: 0, child: scope.edgeLayer),
      for (final node in scope.controller.nodes)
        _PositionedNode(
          node: node,
          controller: scope.controller,
          builder: scope.nodeBuilder,
          place: (absolute, child) => Positioned(
            left: absolute.dx - bounds.left,
            top: absolute.dy - bounds.top,
            child: child,
          ),
        ),
    ];
    return ListenableBuilder(
      listenable: scope.viewport,
      child: SizedBox(
        width: bounds.width,
        height: bounds.height,
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
      builder: (context, child) {
        final viewport = scope.viewport;
        final matrix = viewport.transform.toMatrix()
          ..multiply(Matrix4.translationValues(bounds.left, bounds.top, 0));
        final rasterize =
            scope.rasterPolicy == RasterPolicy.duringGestures &&
            viewport.isGestureActive;
        return OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform(
            transform: matrix,
            filterQuality: rasterize ? FilterQuality.low : null,
            child: child,
          ),
        );
      },
    );
  }
}

/// Implementation B: a custom `RenderBox` that lays out children loosely,
/// paints them at their canvas positions under the viewport transform and
/// hit-tests them through the same transform without a bounds check.
class RenderBoxNodeLayer extends NodeLayerImplementation {
  const RenderBoxNodeLayer();

  @override
  String get name => 'renderbox';

  @override
  Widget build(NodeLayerScope scope) {
    final bounds = scope.contentBounds;
    return CanvasNodeLayer(
      viewport: scope.viewport,
      rasterPolicy: scope.rasterPolicy,
      children: <Widget>[
        CanvasPositioned(position: bounds.topLeft, child: scope.edgeLayer),
        for (final node in scope.controller.nodes)
          _PositionedNode(
            node: node,
            controller: scope.controller,
            builder: scope.nodeBuilder,
            place: (absolute, child) =>
                CanvasPositioned(position: absolute, child: child),
          ),
      ],
    );
  }
}

class CanvasNodeParentData extends ContainerBoxParentData<RenderBox> {
  /// Absolute canvas position of the child's top-left corner.
  Offset position = Offset.zero;
}

/// Parent-data widget giving a [CanvasNodeLayer] child its canvas position.
/// A position change only marks the layer for paint, never layout.
class CanvasPositioned extends ParentDataWidget<CanvasNodeParentData> {
  const CanvasPositioned({
    required this.position,
    required super.child,
    super.key,
  });

  final Offset position;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as CanvasNodeParentData;
    if (parentData.position != position) {
      parentData.position = position;
      final parent = renderObject.parent;
      if (parent is RenderObject) parent.markNeedsPaint();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => CanvasNodeLayer;
}

class CanvasNodeLayer extends MultiChildRenderObjectWidget {
  const CanvasNodeLayer({
    required this.viewport,
    required this.rasterPolicy,
    required super.children,
    super.key,
  });

  final CanvasViewport viewport;
  final RasterPolicy rasterPolicy;

  @override
  RenderCanvasNodeLayer createRenderObject(BuildContext context) =>
      RenderCanvasNodeLayer(viewport: viewport, rasterPolicy: rasterPolicy);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCanvasNodeLayer renderObject,
  ) {
    renderObject
      ..viewport = viewport
      ..rasterPolicy = rasterPolicy;
  }
}

class RenderCanvasNodeLayer extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, CanvasNodeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, CanvasNodeParentData> {
  RenderCanvasNodeLayer({
    required CanvasViewport viewport,
    required RasterPolicy rasterPolicy,
  }) : _viewport = viewport,
       _rasterPolicy = rasterPolicy;

  CanvasViewport _viewport;
  CanvasViewport get viewport => _viewport;
  set viewport(CanvasViewport value) {
    if (identical(value, _viewport)) return;
    if (attached) _viewport.removeListener(markNeedsPaint);
    _viewport = value;
    if (attached) _viewport.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  RasterPolicy _rasterPolicy;
  RasterPolicy get rasterPolicy => _rasterPolicy;
  set rasterPolicy(RasterPolicy value) {
    if (value == _rasterPolicy) return;
    _rasterPolicy = value;
    markNeedsPaint();
  }

  bool get _rasterizing =>
      _rasterPolicy == RasterPolicy.duringGestures && _viewport.isGestureActive;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _viewport.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _viewport.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! CanvasNodeParentData) {
      child.parentData = CanvasNodeParentData();
    }
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    // Children are laid out unconstrained: a node's size is its own business
    // (fixed width, intrinsic height) and never depends on the viewport.
    var child = firstChild;
    while (child != null) {
      child.layout(const BoxConstraints());
      child = (child.parentData! as CanvasNodeParentData).nextSibling;
    }
  }

  Matrix4 _effectiveTransform(Offset offset) =>
      Matrix4.translationValues(offset.dx, offset.dy, 0)
        ..multiply(_viewport.transform.toMatrix())
        ..multiply(Matrix4.translationValues(-offset.dx, -offset.dy, 0));

  void _paintChildren(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as CanvasNodeParentData;
      context.paintChild(child, offset + parentData.position);
      child = parentData.nextSibling;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final transform = _effectiveTransform(offset);
    if (_rasterizing) {
      // Same recipe as RenderTransform with a non-null filterQuality: the
      // children are rasterised untransformed and the compositor applies
      // the matrix as an image filter, which the engine can cache.
      final filterLayer =
          layer is ImageFilterLayer
                ? layer! as ImageFilterLayer
                : ImageFilterLayer()
            ..imageFilter = ui.ImageFilter.matrix(
              transform.storage,
              filterQuality: FilterQuality.low,
            );
      layer = filterLayer;
      context.pushLayer(filterLayer, _paintChildren, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _viewport.transform.toMatrix(),
      _paintChildren,
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final parentData = child.parentData! as CanvasNodeParentData;
    transform
      ..multiply(_viewport.transform.toMatrix())
      ..multiply(
        Matrix4.translationValues(
          parentData.position.dx,
          parentData.position.dy,
          0,
        ),
      );
  }

  /// No `size.contains(position)` check: children live outside this box
  /// whenever the viewport is panned, and they must stay interactive.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _viewport.transform.toMatrix(),
      position: position,
      hitTest: (result, canvasPosition) {
        var child = lastChild;
        while (child != null) {
          final parentData = child.parentData! as CanvasNodeParentData;
          final hit = result.addWithPaintOffset(
            offset: parentData.position,
            position: canvasPosition,
            hitTest: (result, local) => child!.hitTest(result, position: local),
          );
          if (hit) return true;
          child = parentData.previousSibling;
        }
        return false;
      },
    );
  }
}
