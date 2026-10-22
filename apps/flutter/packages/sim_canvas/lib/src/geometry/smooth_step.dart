import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Side of a node a handle sits on (React Flow `Position`).
enum HandlePosition {
  left(-1, 0),
  right(1, 0),
  top(0, -1),
  bottom(0, 1)
  ;

  const HandlePosition(this.dx, this.dy);

  /// Outward unit direction of the handle.
  final int dx;
  final int dy;

  bool get isHorizontal => this == left || this == right;
}

/// Result of [smoothStepPath]: the path plus the polyline corner points it
/// was built from (useful for tests and label placement).
@immutable
class SmoothStepPath {
  const SmoothStepPath({
    required this.path,
    required this.points,
    required this.labelCenter,
  });

  final Path path;

  /// Corner points: source, source gap point, bends..., target gap point, target.
  final List<Offset> points;

  /// Where React Flow places the edge label (`labelX`, `labelY`).
  final Offset labelCenter;
}

/// Port of `getSmoothStepPath` from `@xyflow/system` (`packages/system/src/utils/edges/smoothstep-edge.ts`).
///
/// Upstream `WorkflowEdgeView` calls it with `borderRadius: 8` and
/// `offset: isHorizontal ? 30 : 20`. Geometry only; nothing here depends on
/// Flutter widgets so it can be fixture-tested against upstream output.
SmoothStepPath smoothStepPath({
  required Offset source,
  required Offset target,
  HandlePosition sourcePosition = HandlePosition.bottom,
  HandlePosition targetPosition = HandlePosition.top,
  double borderRadius = 5,
  double offset = 20,
  Offset? center,
}) {
  final result = _points(
    source: source,
    sourcePosition: sourcePosition,
    target: target,
    targetPosition: targetPosition,
    center: center,
    offset: offset,
  );
  final points = result.points;
  final path = Path();
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else if (i < points.length - 1) {
      _addBend(path, points[i - 1], p, points[i + 1], borderRadius);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return SmoothStepPath(
    path: path,
    points: points,
    labelCenter: result.labelCenter,
  );
}

double _distance(Offset a, Offset b) => (b - a).distance;

/// Upstream `getBend`: a straight segment into `b` when the three points are
/// collinear, otherwise a line to the start of the bend and a quadratic
/// through the corner.
void _addBend(Path path, Offset a, Offset b, Offset c, double size) {
  final bendSize = math.min(
    math.min(_distance(a, b) / 2, _distance(b, c) / 2),
    size,
  );
  final x = b.dx;
  final y = b.dy;

  if ((a.dx == x && x == c.dx) || (a.dy == y && y == c.dy)) {
    path.lineTo(x, y);
    return;
  }

  if (a.dy == y) {
    final xDir = a.dx < c.dx ? -1 : 1;
    final yDir = a.dy < c.dy ? 1 : -1;
    path
      ..lineTo(x + bendSize * xDir, y)
      ..quadraticBezierTo(x, y, x, y + bendSize * yDir);
    return;
  }

  final xDir = a.dx < c.dx ? 1 : -1;
  final yDir = a.dy < c.dy ? -1 : 1;
  path
    ..lineTo(x, y + bendSize * yDir)
    ..quadraticBezierTo(x, y, x + bendSize * xDir, y);
}

class _PointsResult {
  const _PointsResult(this.points, this.labelCenter);
  final List<Offset> points;
  final Offset labelCenter;
}

double _axis(Offset p, bool x) => x ? p.dx : p.dy;

/// Upstream `getPoints`.
_PointsResult _points({
  required Offset source,
  required HandlePosition sourcePosition,
  required Offset target,
  required HandlePosition targetPosition,
  required Offset? center,
  required double offset,
}) {
  final sourceDir = Offset(
    sourcePosition.dx.toDouble(),
    sourcePosition.dy.toDouble(),
  );
  final targetDir = Offset(
    targetPosition.dx.toDouble(),
    targetPosition.dy.toDouble(),
  );
  final sourceGapped = source + sourceDir * offset;
  final targetGapped = target + targetDir * offset;

  // getDirection
  final Offset dir;
  if (sourcePosition.isHorizontal) {
    dir = sourceGapped.dx < targetGapped.dx
        ? const Offset(1, 0)
        : const Offset(-1, 0);
  } else {
    dir = sourceGapped.dy < targetGapped.dy
        ? const Offset(0, 1)
        : const Offset(0, -1);
  }
  final alongX = dir.dx != 0;
  final currDir = _axis(dir, alongX);

  var points = <Offset>[];
  double centerX;
  double centerY;
  var sourceGapOffset = Offset.zero;
  var targetGapOffset = Offset.zero;

  // getEdgeCenter
  final defaultCenterX = (source.dx + target.dx) / 2;
  final defaultCenterY = (source.dy + target.dy) / 2;

  if (_axis(sourceDir, alongX) * _axis(targetDir, alongX) == -1) {
    // Opposite handle positions: the default case.
    centerX = center?.dx ?? defaultCenterX;
    centerY = center?.dy ?? defaultCenterY;
    final verticalSplit = [
      Offset(centerX, sourceGapped.dy),
      Offset(centerX, targetGapped.dy),
    ];
    final horizontalSplit = [
      Offset(sourceGapped.dx, centerY),
      Offset(targetGapped.dx, centerY),
    ];
    if (_axis(sourceDir, alongX) == currDir) {
      points = alongX ? verticalSplit : horizontalSplit;
    } else {
      points = alongX ? horizontalSplit : verticalSplit;
    }
  } else {
    // sourceTarget: x from source, y from target; targetSource the opposite.
    final sourceTarget = [Offset(sourceGapped.dx, targetGapped.dy)];
    final targetSource = [Offset(targetGapped.dx, sourceGapped.dy)];
    if (alongX) {
      points = sourceDir.dx == currDir ? targetSource : sourceTarget;
    } else {
      points = sourceDir.dy == currDir ? sourceTarget : targetSource;
    }

    if (sourcePosition == targetPosition) {
      final diff = (_axis(source, alongX) - _axis(target, alongX)).abs();
      // Same side (e.g. right → right) closer than the offset: the added point
      // and the gapped endpoints would overlap, so the gap is shortened.
      if (diff <= offset) {
        final gapOffset = math.min(offset - 1, offset - diff);
        if (_axis(sourceDir, alongX) == currDir) {
          final sign = _axis(sourceGapped, alongX) > _axis(source, alongX)
              ? -1
              : 1;
          sourceGapOffset = alongX
              ? Offset(sign * gapOffset, 0)
              : Offset(0, sign * gapOffset);
        } else {
          final sign = _axis(targetGapped, alongX) > _axis(target, alongX)
              ? -1
              : 1;
          targetGapOffset = alongX
              ? Offset(sign * gapOffset, 0)
              : Offset(0, sign * gapOffset);
        }
      }
    }

    if (sourcePosition != targetPosition) {
      // Mixed handle positions, e.g. right → bottom.
      final isSameDir = _axis(sourceDir, alongX) == _axis(targetDir, !alongX);
      final sourceGtTargetOppo =
          _axis(sourceGapped, !alongX) > _axis(targetGapped, !alongX);
      final sourceLtTargetOppo =
          _axis(sourceGapped, !alongX) < _axis(targetGapped, !alongX);
      final flipSourceTarget =
          (_axis(sourceDir, alongX) == 1 &&
              ((!isSameDir && sourceGtTargetOppo) ||
                  (isSameDir && sourceLtTargetOppo))) ||
          (_axis(sourceDir, alongX) != 1 &&
              ((!isSameDir && sourceLtTargetOppo) ||
                  (isSameDir && sourceGtTargetOppo)));
      if (flipSourceTarget) {
        points = alongX ? sourceTarget : targetSource;
      }
    }

    final sourceGapPoint = sourceGapped + sourceGapOffset;
    final targetGapPoint = targetGapped + targetGapOffset;
    final maxXDistance = math.max(
      (sourceGapPoint.dx - points[0].dx).abs(),
      (targetGapPoint.dx - points[0].dx).abs(),
    );
    final maxYDistance = math.max(
      (sourceGapPoint.dy - points[0].dy).abs(),
      (targetGapPoint.dy - points[0].dy).abs(),
    );
    // The label goes on the longest segment.
    if (maxXDistance >= maxYDistance) {
      centerX = (sourceGapPoint.dx + targetGapPoint.dx) / 2;
      centerY = points[0].dy;
    } else {
      centerX = points[0].dx;
      centerY = (sourceGapPoint.dy + targetGapPoint.dy) / 2;
    }
  }

  final pathPoints = <Offset>[
    source,
    sourceGapped + sourceGapOffset,
    ...points,
    targetGapped + targetGapOffset,
    target,
  ];
  return _PointsResult(pathPoints, Offset(centerX, centerY));
}
