// Failure modes of the smooth-step port (upstream getSmoothStepPath):
// 1. right→left with the target to the right on the same y is a straight line;
// 2. right→left with a different y bends twice at centerX = (sx + tx) / 2 and
//    leaves/enters the handles by the offset (30 horizontally);
// 3. right→left with the target to the LEFT (backwards edge) routes around
//    through centerY and still leaves the source to the right;
// 4. same-side handles closer than the offset shorten the gap instead of
//    producing a loop;
// 5. the path starts at the source and ends at the target exactly.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_canvas/sim_canvas.dart';

SmoothStepPath _rightToLeft(Offset source, Offset target) => smoothStepPath(
  source: source,
  target: target,
  sourcePosition: HandlePosition.right,
  targetPosition: HandlePosition.left,
  borderRadius: 8,
  offset: 30,
);

void main() {
  test('straight line when the target is to the right on the same y', () {
    final path = _rightToLeft(const Offset(250, 60), const Offset(600, 60));
    expect(path.points.every((p) => p.dy == 60), isTrue);
    expect(path.path.getBounds(), const Rect.fromLTRB(250, 60, 600, 60));
    expect(path.labelCenter, const Offset(425, 60));
  });

  test('two bends at centerX for a forward edge on different rows', () {
    final path = _rightToLeft(const Offset(250, 60), const Offset(400, 360));
    expect(path.points, const <Offset>[
      Offset(250, 60),
      Offset(280, 60),
      Offset(325, 60),
      Offset(325, 360),
      Offset(370, 360),
      Offset(400, 360),
    ]);
    expect(path.labelCenter, const Offset(325, 210));
    final bounds = path.path.getBounds();
    expect(bounds.left, 250);
    expect(bounds.right, 400);
  });

  test('backwards edge routes through centerY and leaves to the right', () {
    final path = _rightToLeft(const Offset(250, 60), const Offset(-500, 460));
    expect(path.points.first, const Offset(250, 60));
    expect(path.points[1], const Offset(280, 60));
    expect(path.points[2], const Offset(280, 260));
    expect(path.points[3], const Offset(-530, 260));
    expect(path.points[4], const Offset(-530, 460));
    expect(path.points.last, const Offset(-500, 460));
    expect(path.path.getBounds().right, 280);
  });

  test('same-side handles closer than the offset shorten the gap', () {
    final path = smoothStepPath(
      source: const Offset(100, 0),
      target: const Offset(110, 200),
      sourcePosition: HandlePosition.right,
      targetPosition: HandlePosition.right,
      borderRadius: 8,
      offset: 30,
    );
    // Source gap shortened by (offset - diff) = 20 → 110 instead of 130.
    expect(path.points[1], const Offset(110, 0));
    expect(path.points[path.points.length - 2], const Offset(140, 200));
  });

  test('path starts at the source and ends at the target', () {
    final path = _rightToLeft(
      const Offset(-700, -340),
      const Offset(1234, 987),
    );
    final metrics = path.path.computeMetrics().toList();
    expect(metrics, hasLength(1));
    final start = metrics.single.getTangentForOffset(0)!.position;
    final end = metrics.single
        .getTangentForOffset(metrics.single.length)!
        .position;
    expect(start, const Offset(-700, -340));
    expect(end.dx, closeTo(1234, 1e-6));
    expect(end.dy, closeTo(987, 1e-6));
  });
}
