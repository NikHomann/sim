import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Points sampled along an edge path, used for stroke hit-testing.
///
/// `Path.contains` is fill-only, so a stroked edge is hit-tested by sampling
/// its `PathMetrics` every [EdgeHitTester.sampleSpacing] canvas units and
/// comparing the distance from the query point to the nearest sample with
/// half the hit width. The sampling error is at most `spacing / 2`.
@immutable
class EdgeHitSamples {
  const EdgeHitSamples({required this.bounds, required this.samples});

  factory EdgeHitSamples.fromPath(Path path, {double spacing = 3}) {
    assert(spacing > 0, 'spacing must be positive');
    final samples = <Offset>[];
    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      if (length == 0) {
        final tangent = metric.getTangentForOffset(0);
        if (tangent != null) samples.add(tangent.position);
        continue;
      }
      for (var d = 0.0; d < length; d += spacing) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent != null) samples.add(tangent.position);
      }
      final end = metric.getTangentForOffset(length);
      if (end != null) samples.add(end.position);
    }
    return EdgeHitSamples(bounds: path.getBounds(), samples: samples);
  }

  /// Path bounds, *not* inflated.
  final Rect bounds;
  final List<Offset> samples;

  /// Whether [point] is within [radius] of the sampled path.
  bool hits(Offset point, double radius) {
    if (!bounds.inflate(radius).contains(point)) return false;
    final r2 = radius * radius;
    for (final s in samples) {
      final dx = s.dx - point.dx;
      final dy = s.dy - point.dy;
      if (dx * dx + dy * dy <= r2) return true;
    }
    return false;
  }
}

/// Stroke hit-testing for a set of edges, in canvas units.
///
/// [hitWidth] is the full stroke width that counts as a hit (React Flow's
/// `interactionWidth`, 30 upstream), independent of zoom because the test
/// runs in canvas coordinates after the viewport transform has been undone.
class EdgeHitTester {
  EdgeHitTester({this.hitWidth = 30, this.sampleSpacing = 3});

  final double hitWidth;
  final double sampleSpacing;

  final Map<String, EdgeHitSamples> _samples = <String, EdgeHitSamples>{};

  /// Insertion order is paint order; the last inserted edge is on top.
  final List<String> _order = <String>[];

  int get edgeCount => _order.length;

  void update(String edgeId, Path path) {
    if (!_samples.containsKey(edgeId)) _order.add(edgeId);
    _samples[edgeId] = EdgeHitSamples.fromPath(path, spacing: sampleSpacing);
  }

  void remove(String edgeId) {
    if (_samples.remove(edgeId) != null) _order.remove(edgeId);
  }

  void clear() {
    _samples.clear();
    _order.clear();
  }

  bool contains(String edgeId) => _samples.containsKey(edgeId);

  /// The topmost edge within [hitWidth] / 2 of [canvasPoint], or null.
  String? edgeAt(Offset canvasPoint) {
    final radius = hitWidth / 2;
    for (var i = _order.length - 1; i >= 0; i--) {
      final id = _order[i];
      if (_samples[id]!.hits(canvasPoint, radius)) return id;
    }
    return null;
  }
}
