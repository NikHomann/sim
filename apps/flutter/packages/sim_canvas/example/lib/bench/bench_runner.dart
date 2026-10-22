import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_canvas/sim_canvas.dart';
import 'package:sim_canvas_example/bench/frame_stats.dart';
import 'package:sim_canvas_example/bench/platform_stub.dart'
    if (dart.library.io) 'package:sim_canvas_example/bench/platform_io.dart';

/// What the benchmark needs from the hosting widget tree.
abstract class BenchHost {
  CanvasViewport get viewport;
  GraphController get controller;
  GlobalKey<GraphCanvasState> get canvasKey;

  /// Taps recorded through `GraphCanvas.onHit` since the last [clearHits].
  List<HitRecord> get hits;
  void clearHits();

  /// Rebuilds the canvas with the given scene; completes after a frame.
  Future<void> configure({
    required NodeLayerImplementation implementation,
    required RasterPolicy rasterPolicy,
    CanvasGraph? graph,
  });
}

class BenchVariant {
  const BenchVariant(this.implementation, this.rasterPolicy);

  final NodeLayerImplementation implementation;
  final RasterPolicy rasterPolicy;

  String get label => '${implementation.name}/${rasterPolicy.name}';
}

/// Drives the viewport programmatically (pan across the whole graph, zoom
/// sweep, node drag) per variant, records frame timings, runs the hit-test
/// checks once per implementation and emits one JSON line per variant.
class BenchRunner {
  BenchRunner({
    required this.host,
    required this.variants,
    this.panDuration = const Duration(seconds: 5),
    this.zoomDuration = const Duration(seconds: 2),
    this.dragDuration = const Duration(milliseconds: 1500),
    this.outPath,
    this.log = print,
  });

  final BenchHost host;
  final List<BenchVariant> variants;
  final Duration panDuration;
  final Duration zoomDuration;
  final Duration dragDuration;
  final String? outPath;
  final void Function(String line) log;

  int _pointer = 100;

  Future<List<Map<String, Object?>>> runAll({
    required double refreshRate,
  }) async {
    final results = <Map<String, Object?>>[];
    final checked = <String>{};
    for (final variant in variants) {
      final result = await runVariant(variant, refreshRate: refreshRate);
      if (checked.add(variant.implementation.name)) {
        result['hit_tests'] = await runHitChecks(variant.implementation);
      }
      results.add(result);
      final line = jsonEncode(result);
      log('BENCH_RESULT $line');
      if (outPath != null && outPath!.isNotEmpty) appendLine(outPath!, line);
    }
    log('BENCH_DONE');
    return results;
  }

  Future<Map<String, Object?>> runVariant(
    BenchVariant variant, {
    required double refreshRate,
  }) async {
    await host.configure(
      implementation: variant.implementation,
      rasterPolicy: variant.rasterPolicy,
      graph: generateSyntheticWorkflow(),
    );
    await _settle();
    final viewport = host.viewport;
    final controller = host.controller;
    final bounds = controller.contentBounds();
    final view = viewport.viewportSize;

    // Pan: three horizontal sweeps at zoom 1 covering the whole graph.
    viewport
      ..setTransform(CanvasTransform(offset: -bounds.topLeft))
      ..beginGesture();
    await _settle();
    final pan = await _phase(panDuration, (t) {
      const sweeps = 3;
      final s = t * sweeps;
      final i = math.min(sweeps - 1, s.floor());
      final u = s - i;
      final left = bounds.left;
      final right = math.max(bounds.left, bounds.right - view.width);
      final x = i.isEven
          ? lerpDouble(left, right, u)!
          : lerpDouble(right, left, u)!;
      final y = lerpDouble(
        bounds.top,
        math.max(bounds.top, bounds.bottom - view.height),
        s / sweeps,
      )!;
      viewport.setTransform(CanvasTransform(offset: Offset(-x, -y)));
    });
    viewport
      ..endGesture()
      ..fitToView(bounds)
      ..setZoomAt(view.center(Offset.zero), 1);
    await _settle();
    // Zoom: 1 → 0.1 → 1.3 around the viewport centre.
    viewport.beginGesture();
    final zoom = await _phase(zoomDuration, (t) {
      final z = t < 0.5
          ? lerpDouble(1, 0.1, t * 2)!
          : lerpDouble(0.1, 1.3, (t - 0.5) * 2)!;
      viewport.setZoomAt(view.center(Offset.zero), z);
    });
    viewport.endGesture();

    // Drag one node in a circle at zoom 1 (not a viewport gesture).
    const dragged = 'n-3-3';
    final base = controller.absolutePosition(dragged);
    _centerOn(controller.absoluteRect(dragged).center, zoom: 1);
    await _settle();
    final drag = await _phase(dragDuration, (t) {
      final angle = t * 2 * math.pi;
      controller.setAbsolutePosition(
        dragged,
        base + Offset(math.cos(angle), math.sin(angle)) * 120,
      );
    });
    controller.setAbsolutePosition(dragged, base);

    // Same drag with the viewport gesture flag raised: the cost of a naive
    // raster policy that also caches during node drags.
    FrameStats? dragRaster;
    if (variant.rasterPolicy == RasterPolicy.duringGestures) {
      await _settle();
      viewport.beginGesture();
      dragRaster = await _phase(dragDuration, (t) {
        final angle = t * 2 * math.pi;
        controller.setAbsolutePosition(
          dragged,
          base + Offset(math.cos(angle), math.sin(angle)) * 120,
        );
      });
      viewport.endGesture();
      controller.setAbsolutePosition(dragged, base);
    }

    return <String, Object?>{
      'platform': platformName,
      'mode': kProfileMode ? 'profile' : (kReleaseMode ? 'release' : 'debug'),
      'impl': variant.implementation.name,
      'raster': variant.rasterPolicy.name,
      'nodes': controller.nodeCount,
      'edges': controller.edgeCount,
      'viewport': <String, Object?>{'width': view.width, 'height': view.height},
      'refresh_rate': refreshRate,
      'phases': <String, Object?>{
        'pan': pan.toJson(),
        'zoom': zoom.toJson(),
        'drag': drag.toJson(),
        if (dragRaster != null) 'drag_rasterized': dragRaster.toJson(),
      },
    };
  }

  void _centerOn(Offset canvasPoint, {required double zoom}) {
    final view = host.viewport.viewportSize;
    final center = Offset(view.width / 2, view.height / 2);
    host.viewport.setTransform(
      CanvasTransform(offset: center - canvasPoint * zoom, zoom: zoom),
    );
  }

  Future<void> _settle([int frames = 3]) async {
    for (var i = 0; i < frames; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  /// Runs [step] once per frame for [duration] and returns the frame
  /// timings reported for it. Timings arrive in batches up to a second
  /// late, so the collector stays registered for a flush interval.
  Future<FrameStats> _phase(
    Duration duration,
    void Function(double t) step,
  ) async {
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(collect);
    final done = Completer<void>();
    final stopwatch = Stopwatch()..start();
    late final Ticker ticker;
    ticker = Ticker((elapsed) {
      final t = elapsed.inMicroseconds / duration.inMicroseconds;
      if (t >= 1) {
        step(1);
        ticker.stop();
        if (!done.isCompleted) done.complete();
      } else {
        step(t);
      }
    });
    unawaited(ticker.start());
    await done.future;
    final elapsed = stopwatch.elapsed;
    ticker.dispose();
    // Flush interval: timings for the last frames arrive late.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    SchedulerBinding.instance.removeTimingsCallback(collect);
    return FrameStats.from(timings, elapsed);
  }

  // ---------------------------------------------------------------------------
  // Hit-test checks
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> runHitChecks(
    NodeLayerImplementation implementation,
  ) async {
    await host.configure(
      implementation: implementation,
      rasterPolicy: RasterPolicy.never,
      graph: generateSyntheticWorkflow(),
    );
    await _settle();
    final results = <Map<String, Object?>>[];
    final controller = host.controller;

    // The fixture: fanSource's source handle at (+250, +60); the near edge's
    // vertical segment is at centerX = +325, the far edge's at +385.
    final fixtureOrigin = controller.absolutePosition(
      SyntheticFixture.fanSource,
    );
    final nearMid = fixtureOrigin + const Offset(325, 200);
    final betweenEdges = fixtureOrigin + const Offset(355, 200);

    Future<void> check(
      String name,
      Offset canvasPoint,
      double zoom,
      HitRecord expected, {
      Offset? screenOverride,
    }) async {
      final Offset screen;
      if (screenOverride == null) {
        _centerOn(canvasPoint, zoom: zoom);
        screen = _viewCenter();
      } else {
        screen = screenOverride;
        host.viewport.setTransform(
          CanvasTransform(offset: screen - canvasPoint * zoom, zoom: zoom),
        );
      }
      await _settle(2);
      final actual = await _click(screen);
      final pass = actual.length == 1 && actual.single == expected;
      results.add(<String, Object?>{
        'name': name,
        'impl': implementation.name,
        'zoom': zoom,
        'canvas_point': <double>[canvasPoint.dx, canvasPoint.dy],
        'screen_point': <double>[screen.dx, screen.dy],
        'expected': expected.toString(),
        'actual': actual.map((h) => h.toString()).toList(),
        'pass': pass,
      });
    }

    await check(
      'node at negative canvas coordinates after panning',
      controller.absoluteRect(SyntheticFixture.negativeNode).center,
      1,
      const HitRecord.node(SyntheticFixture.negativeNode),
    );
    await check(
      'child node inside a container (child above container)',
      controller.absoluteRect(SyntheticFixture.containerChild).center,
      1,
      const HitRecord.node(SyntheticFixture.containerChild),
    );
    await check(
      'edge mid-segment at zoom 0.5',
      nearMid,
      0.5,
      const HitRecord.edge(SyntheticFixture.fanEdgeNear),
    );
    await check(
      'edge mid-segment at zoom 1.3',
      nearMid,
      1.3,
      const HitRecord.edge(SyntheticFixture.fanEdgeNear),
    );
    await check(
      'edge 13 canvas units off-centre at zoom 0.5 (inside hit width 30)',
      nearMid + const Offset(13, 0),
      0.5,
      const HitRecord.edge(SyntheticFixture.fanEdgeNear),
    );
    await check(
      'edge 22 canvas units off-centre at zoom 1.3 (outside hit width 30)',
      nearMid + const Offset(22, 0),
      1.3,
      const HitRecord.empty(),
    );
    await check(
      'empty space between two edges 60 canvas units apart',
      betweenEdges,
      1,
      const HitRecord.empty(),
    );

    // Small graph: the content-sized Stack/Transform is smaller than the
    // viewport, and the node is placed at a screen position beyond that size.
    await host.configure(
      implementation: implementation,
      rasterPolicy: RasterPolicy.never,
      graph: generateTinyWorkflow(),
    );
    await _settle();
    final view = host.viewport.viewportSize;
    await check(
      'node visible beyond the content-sized layer box (tiny graph, zoom 1.3)',
      host.controller.absoluteRect('tiny-b').center,
      1.3,
      const HitRecord.node('tiny-b'),
      screenOverride: Offset(view.width * 0.85, view.height * 0.85),
    );

    await host.configure(
      implementation: implementation,
      rasterPolicy: RasterPolicy.never,
      graph: generateSyntheticWorkflow(),
    );
    return results;
  }

  Offset _viewCenter() {
    final view = host.viewport.viewportSize;
    return Offset(view.width / 2, view.height / 2);
  }

  /// Dispatches a primary-button mouse click at [canvasLocal] (canvas-widget
  /// pixels) through the real pointer pipeline and returns what was hit.
  Future<List<HitRecord>> _click(Offset canvasLocal) async {
    final box = host.canvasKey.currentContext!.findRenderObject()! as RenderBox;
    final global = box.localToGlobal(canvasLocal);
    host.clearHits();
    final pointer = _pointer++;
    WidgetsBinding.instance
      ..handlePointerEvent(
        PointerDownEvent(pointer: pointer, position: global),
      )
      ..handlePointerEvent(PointerUpEvent(pointer: pointer, position: global));
    await _settle(2);
    return List<HitRecord>.of(host.hits);
  }
}
