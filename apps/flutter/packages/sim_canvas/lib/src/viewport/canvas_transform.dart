import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// The affine map between canvas units and viewport (screen) pixels.
///
/// Coordinate conventions (kept by the Phase 2 engine):
/// - *canvas* coordinates are the workflow's own units (React Flow "flow"
///   coordinates): node positions, edge paths and hit widths live here;
/// - *screen* coordinates are logical pixels local to the canvas widget;
/// - `screen = canvas * zoom + offset`, so [offset] is the screen position of
///   the canvas origin and [zoom] is the uniform scale (no rotation).
@immutable
class CanvasTransform {
  const CanvasTransform({this.offset = Offset.zero, this.zoom = 1});

  final Offset offset;
  final double zoom;

  Offset toScreen(Offset canvas) => canvas * zoom + offset;

  Offset toCanvas(Offset screen) => (screen - offset) / zoom;

  /// Screen rect covered by [canvasRect].
  Rect rectToScreen(Rect canvasRect) => Rect.fromPoints(
    toScreen(canvasRect.topLeft),
    toScreen(canvasRect.bottomRight),
  );

  /// The matrix mapping canvas coordinates to screen coordinates (column
  /// major, as `Matrix4` stores it): scale then translate.
  Matrix4 toMatrix() => Matrix4(
    zoom,
    0,
    0,
    0, //
    0,
    zoom,
    0,
    0, //
    0,
    0,
    1,
    0, //
    offset.dx,
    offset.dy,
    0,
    1,
  );

  CanvasTransform copyWith({Offset? offset, double? zoom}) =>
      CanvasTransform(offset: offset ?? this.offset, zoom: zoom ?? this.zoom);

  @override
  bool operator ==(Object other) =>
      other is CanvasTransform && other.offset == offset && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(offset, zoom);

  @override
  String toString() => 'CanvasTransform(offset: $offset, zoom: $zoom)';
}
