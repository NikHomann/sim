import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:sim_canvas/src/viewport/canvas_transform.dart';

/// Pan/zoom state of a graph canvas.
///
/// Mirrors the React Flow viewport (`useViewport`): zoom bounded to
/// [minZoom]..[maxZoom] (0.1–1.3 upstream), zoom around an arbitrary screen
/// focal point, fit-to-view. Listeners are notified on every change; the
/// node and edge layers read [transform] at paint and hit-test time.
///
/// [isGestureActive] is the raster-cache hint: while a viewport gesture
/// (pointer pan, wheel, pinch, programmatic animation) is in flight the
/// layers may composite a cached raster of the scene instead of repainting
/// it; at rest they repaint crisply.
class CanvasViewport extends ChangeNotifier {
  CanvasViewport({
    CanvasTransform transform = const CanvasTransform(),
    this.minZoom = 0.1,
    this.maxZoom = 1.3,
  }) : _transform = transform,
       assert(minZoom > 0 && minZoom <= maxZoom, 'invalid zoom bounds');

  final double minZoom;
  final double maxZoom;

  CanvasTransform _transform;
  CanvasTransform get transform => _transform;

  /// The size of the canvas widget, in screen pixels; set by the widget on
  /// layout and used by [fitToView] when no explicit size is given.
  Size viewportSize = Size.zero;

  int _activeGestures = 0;
  bool get isGestureActive => _activeGestures > 0;

  double get zoom => _transform.zoom;
  Offset get offset => _transform.offset;

  Offset toScreen(Offset canvas) => _transform.toScreen(canvas);
  Offset toCanvas(Offset screen) => _transform.toCanvas(screen);

  double clampZoom(double zoom) => zoom.clamp(minZoom, maxZoom);

  void setTransform(CanvasTransform value) {
    final clamped = value.copyWith(zoom: clampZoom(value.zoom));
    if (clamped == _transform) return;
    _transform = clamped;
    notifyListeners();
  }

  void panBy(Offset screenDelta) {
    if (screenDelta == Offset.zero) return;
    setTransform(_transform.copyWith(offset: _transform.offset + screenDelta));
  }

  /// Multiplies the zoom by [factor] keeping the canvas point under
  /// [screenFocal] fixed on screen.
  void zoomAt(Offset screenFocal, double factor) {
    setZoomAt(screenFocal, _transform.zoom * factor);
  }

  /// Sets the zoom to [zoom] (clamped) keeping the canvas point under
  /// [screenFocal] fixed on screen.
  ///
  /// With `c = (focal - offset) / zoom` the point under the cursor, the new
  /// offset must satisfy `c * zoom' + offset' = focal`, i.e.
  /// `offset' = focal - (focal - offset) * zoom' / zoom`.
  void setZoomAt(Offset screenFocal, double zoom) {
    final next = clampZoom(zoom);
    final current = _transform.zoom;
    if (next == current) return;
    final ratio = next / current;
    final nextOffset = screenFocal - (screenFocal - _transform.offset) * ratio;
    setTransform(CanvasTransform(offset: nextOffset, zoom: next));
  }

  /// Zooms (clamped) so that [bounds] fits inside the viewport with [padding]
  /// and centers it. A zero-area viewport or bounds is a no-op.
  void fitToView(Rect bounds, {Size? size, double padding = 40}) {
    final view = size ?? viewportSize;
    if (view.isEmpty || bounds.isEmpty) return;
    final available = Size(
      math.max(1, view.width - 2 * padding),
      math.max(1, view.height - 2 * padding),
    );
    final zoom = clampZoom(
      math.min(
        available.width / bounds.width,
        available.height / bounds.height,
      ),
    );
    final viewCenter = Offset(view.width / 2, view.height / 2);
    final offset = viewCenter - bounds.center * zoom;
    setTransform(CanvasTransform(offset: offset, zoom: zoom));
  }

  /// Marks a viewport gesture as started; balanced by [endGesture].
  void beginGesture() {
    _activeGestures++;
    if (_activeGestures == 1) notifyListeners();
  }

  void endGesture() {
    if (_activeGestures == 0) return;
    _activeGestures--;
    if (_activeGestures == 0) notifyListeners();
  }
}
