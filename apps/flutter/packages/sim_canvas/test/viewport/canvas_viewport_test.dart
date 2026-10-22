// Failure modes of the viewport math, written before the implementation:
// 1. zoom beyond the bounds (above 1.3, below 0.1) must clamp, not throw;
// 2. zooming around a cursor must keep the canvas point under it fixed;
// 3. zooming at a clamp bound must not drift the offset;
// 4. a zoom factor of exactly 1 must not notify;
// 5. fit-to-view with an empty viewport or empty bounds is a no-op;
// 6. fit-to-view clamps for huge (→ 0.1) and tiny (→ 1.3) bounds and centers;
// 7. toCanvas/toScreen are inverses at any zoom;
// 8. gesture begin/end are balanced and an unbalanced end is harmless.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_canvas/sim_canvas.dart';

void main() {
  group('zoom bounds', () {
    test('clamps above the maximum', () {
      final viewport = CanvasViewport()..setZoomAt(Offset.zero, 5);
      expect(viewport.zoom, 1.3);
    });

    test('clamps below the minimum', () {
      final viewport = CanvasViewport()..zoomAt(Offset.zero, 0.0001);
      expect(viewport.zoom, 0.1);
    });

    test('rejects inverted bounds', () {
      expect(
        () => CanvasViewport(minZoom: 2, maxZoom: 1),
        throwsAssertionError,
      );
    });
  });

  group('zoom around cursor', () {
    for (final focal in const <Offset>[
      Offset.zero,
      Offset(640, 360),
      Offset(-50, 900),
    ]) {
      for (final factor in const <double>[0.5, 1.25, 0.9]) {
        test(
          'keeps the canvas point under $focal fixed for factor $factor',
          () {
            final viewport = CanvasViewport(
              transform: const CanvasTransform(
                offset: Offset(120, -80),
                zoom: 0.8,
              ),
            );
            final before = viewport.toCanvas(focal);
            viewport.zoomAt(focal, factor);
            final after = viewport.toCanvas(focal);
            expect(after.dx, closeTo(before.dx, 1e-9));
            expect(after.dy, closeTo(before.dy, 1e-9));
            expect(viewport.zoom, closeTo(0.8 * factor, 1e-12));
          },
        );
      }
    }

    test('does not drift the offset when already at the bound', () {
      final viewport = CanvasViewport(
        transform: const CanvasTransform(offset: Offset(10, 20), zoom: 1.3),
      )..zoomAt(const Offset(300, 300), 2);
      expect(
        viewport.transform,
        const CanvasTransform(offset: Offset(10, 20), zoom: 1.3),
      );
    });

    test('a factor of 1 does not notify', () {
      var notifications = 0;
      CanvasViewport()
        ..addListener(() => notifications++)
        ..zoomAt(const Offset(5, 5), 1);
      expect(notifications, 0);
    });

    test('clamped zoom still keeps the focal point fixed', () {
      final viewport = CanvasViewport();
      const focal = Offset(200, 100);
      final before = viewport.toCanvas(focal);
      viewport.zoomAt(focal, 10);
      expect(viewport.zoom, 1.3);
      expect(viewport.toCanvas(focal), before);
    });
  });

  group('fit to view', () {
    test('is a no-op without a viewport size', () {
      final viewport = CanvasViewport()
        ..fitToView(const Rect.fromLTWH(0, 0, 100, 100));
      expect(viewport.transform, const CanvasTransform());
    });

    test('is a no-op for empty bounds', () {
      final viewport = CanvasViewport()
        ..viewportSize = const Size(800, 600)
        ..fitToView(Rect.zero);
      expect(viewport.transform, const CanvasTransform());
    });

    test('centers the bounds and keeps them inside the padding', () {
      const bounds = Rect.fromLTWH(-1000, 500, 2000, 1000);
      final viewport = CanvasViewport()
        ..viewportSize = const Size(800, 600)
        ..fitToView(bounds);
      final screen = viewport.transform.rectToScreen(bounds);
      expect(screen.center.dx, closeTo(400, 1e-9));
      expect(screen.center.dy, closeTo(300, 1e-9));
      expect(screen.width, lessThanOrEqualTo(720 + 1e-9));
      expect(screen.height, lessThanOrEqualTo(520 + 1e-9));
      expect(viewport.zoom, closeTo(0.36, 1e-9));
    });

    test('clamps to the minimum zoom for huge bounds', () {
      final viewport = CanvasViewport()
        ..viewportSize = const Size(800, 600)
        ..fitToView(const Rect.fromLTWH(0, 0, 100000, 100000));
      expect(viewport.zoom, 0.1);
    });

    test('clamps to the maximum zoom for tiny bounds', () {
      final viewport = CanvasViewport()
        ..viewportSize = const Size(800, 600)
        ..fitToView(const Rect.fromLTWH(0, 0, 10, 10));
      expect(viewport.zoom, 1.3);
      expect(viewport.toScreen(const Offset(5, 5)), const Offset(400, 300));
    });
  });

  test('toCanvas and toScreen are inverses', () {
    const transform = CanvasTransform(offset: Offset(-312.5, 77), zoom: 0.37);
    const canvas = Offset(-4400, 1234.5);
    final screen = transform.toScreen(canvas);
    final back = transform.toCanvas(screen);
    expect(back.dx, closeTo(canvas.dx, 1e-9));
    expect(back.dy, closeTo(canvas.dy, 1e-9));
    final matrixPoint = MatrixUtils.transformPoint(
      transform.toMatrix(),
      canvas,
    );
    expect(matrixPoint.dx, closeTo(screen.dx, 1e-9));
    expect(matrixPoint.dy, closeTo(screen.dy, 1e-9));
  });

  test('gesture flag is balanced and tolerates a stray end', () {
    var notifications = 0;
    final viewport = CanvasViewport()
      ..addListener(() => notifications++)
      ..endGesture();
    expect(viewport.isGestureActive, isFalse);
    viewport
      ..beginGesture()
      ..beginGesture();
    expect(viewport.isGestureActive, isTrue);
    viewport.endGesture();
    expect(viewport.isGestureActive, isTrue);
    viewport.endGesture();
    expect(viewport.isGestureActive, isFalse);
    expect(notifications, 2);
  });
}
