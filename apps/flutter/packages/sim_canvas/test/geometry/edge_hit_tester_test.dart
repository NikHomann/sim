// Failure modes of stroke hit-testing by PathMetrics sampling:
// 1. a point on the stroke must hit; 14 units off a 30-wide stroke must
//    hit; 16 units off must miss (the width is 30 in canvas units);
// 2. a point past the end cap must miss, a point far away must miss via
//    the bounds pre-check;
// 3. a point near a rounded bend (inside the 8-radius arc's corner) must hit;
// 4. an empty tester, a removed edge and a degenerate zero-length path
//    must not throw and must report no hit;
// 5. overlapping edges resolve to the last inserted (topmost);
// 6. sampling spacing bounds the error: spacing 3 → at most 1.5 units.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_canvas/sim_canvas.dart';

Path _line(Offset a, Offset b) => Path()
  ..moveTo(a.dx, a.dy)
  ..lineTo(b.dx, b.dy);

void main() {
  group('straight edge, hit width 30', () {
    final tester = EdgeHitTester()
      ..update('e', _line(const Offset(0, 100), const Offset(300, 100)));

    test('hits on the line', () {
      expect(tester.edgeAt(const Offset(150, 100)), 'e');
    });

    test('hits 14 units off the line', () {
      expect(tester.edgeAt(const Offset(150, 114)), 'e');
      expect(tester.edgeAt(const Offset(150, 86)), 'e');
    });

    test('misses 16 units off the line', () {
      expect(tester.edgeAt(const Offset(150, 116)), isNull);
      expect(tester.edgeAt(const Offset(150, 84)), isNull);
    });

    test('misses past the end cap', () {
      expect(tester.edgeAt(const Offset(316, 100)), isNull);
      expect(tester.edgeAt(const Offset(314, 100)), 'e');
    });

    test('misses far away', () {
      expect(tester.edgeAt(const Offset(5000, -5000)), isNull);
    });
  });

  test('hits inside the corner of a rounded bend', () {
    final path = smoothStepPath(
      source: const Offset(250, 60),
      target: const Offset(400, 360),
      sourcePosition: HandlePosition.right,
      targetPosition: HandlePosition.left,
      borderRadius: 8,
      offset: 30,
    );
    final tester = EdgeHitTester()..update('bend', path.path);
    // The polyline corner at (325, 60): the arc cuts it by 8·(√2−1) ≈ 3.3 units.
    expect(tester.edgeAt(const Offset(325, 60)), 'bend');
    // On the vertical mid-segment and 14 off it.
    expect(tester.edgeAt(const Offset(325, 200)), 'bend');
    expect(tester.edgeAt(const Offset(339, 200)), 'bend');
    expect(tester.edgeAt(const Offset(341, 200)), isNull);
  });

  group('degenerate input', () {
    test('empty tester reports nothing', () {
      expect(EdgeHitTester().edgeAt(Offset.zero), isNull);
    });

    test('removed edge reports nothing', () {
      final tester = EdgeHitTester()
        ..update('e', _line(Offset.zero, const Offset(10, 0)))
        ..remove('e');
      expect(tester.edgeAt(const Offset(5, 0)), isNull);
      expect(tester.edgeCount, 0);
    });

    test('zero-length path yields no contour and never hits', () {
      // Skia's PathMeasure drops zero-length contours, so a collapsed edge
      // (source and target handle coincide) is simply not hit-testable.
      final tester = EdgeHitTester()
        ..update('dot', _line(const Offset(5, 5), const Offset(5, 5)));
      expect(tester.edgeAt(const Offset(5, 5)), isNull);
      expect(tester.edgeCount, 1);
    });

    test('empty path is harmless', () {
      final tester = EdgeHitTester()..update('none', Path());
      expect(tester.edgeAt(Offset.zero), isNull);
    });
  });

  test('overlapping edges resolve to the last inserted', () {
    final tester = EdgeHitTester()
      ..update('below', _line(Offset.zero, const Offset(100, 0)))
      ..update('above', _line(Offset.zero, const Offset(100, 0)));
    expect(tester.edgeAt(const Offset(50, 0)), 'above');
    tester.remove('above');
    expect(tester.edgeAt(const Offset(50, 0)), 'below');
  });

  test('sampling spacing bounds the error', () {
    final samples = EdgeHitSamples.fromPath(
      _line(Offset.zero, const Offset(300, 0)),
    );
    expect(samples.samples.length, 101);
    expect(samples.bounds, const Rect.fromLTWH(0, 0, 300, 0));
    // Midway between two samples the distance is 1.5; a radius of 1.5 hits.
    expect(samples.hits(const Offset(1.5, 0), 1.5), isTrue);
    expect(samples.hits(const Offset(1.5, 0), 1.4), isFalse);
  });
}
