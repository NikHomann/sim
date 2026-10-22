// Failure modes:
// - implicit line-to pairs after M must continue the subpath
// - relative commands accumulate from the current point
// - H/V keep the other coordinate; Z returns to the subpath start
// - arcs produce a non-empty path
// - an unsupported command throws instead of silently drawing garbage
// - the wordmark and GitHub glyphs parse and fit the requested box
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/shared/svg_path.dart';

void main() {
  test('absolute, implicit and relative segments', () {
    final path = parseSvgPath('M0 0 10 0 L10 10 l-10 0 Z');
    expect(path.getBounds(), const Rect.fromLTWH(0, 0, 10, 10));
  });

  test('H and V keep the orthogonal coordinate; Z closes to start', () {
    final path = parseSvgPath('M5 5H15V15H5Z');
    expect(path.getBounds(), const Rect.fromLTWH(5, 5, 10, 10));
    expect(path.contains(const Offset(10, 10)), isTrue);
  });

  test('cubic and arc commands draw', () {
    final cubic = parseSvgPath('M0 0C0 10 10 10 10 0Z');
    expect(cubic.getBounds().height, greaterThan(5));
    final arc = parseSvgPath('M0 0A5 5 0 0 1 10 0Z');
    expect(arc.getBounds().width, closeTo(10, 0.01));
  });

  test('unsupported commands throw', () {
    expect(() => parseSvgPath('M0 0 X 1 1'), throwsFormatException);
  });

  test('fitSvgPath scales preserving aspect ratio', () {
    final path = parseSvgPath('M0 0H441V212H0Z');
    final fitted = fitSvgPath(path, const Size(441, 212), const Size(37, 18));
    final bounds = fitted.getBounds();
    expect(bounds.width, closeTo(37, 0.5));
    expect(bounds.height, closeTo(37 * 212 / 441, 0.5));
  });
}
