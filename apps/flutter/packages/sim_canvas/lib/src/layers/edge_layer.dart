import 'package:flutter/widgets.dart';
import 'package:sim_canvas/src/model/canvas_graph.dart';

/// Paints every edge of a [GraphController] as a smooth-step stroke and
/// hit-tests strokes with the controller's `PathMetrics` sampler.
///
/// The painter's local space is the canvas space translated by [origin]
/// (the top-left of the content bounds), so that the host `CustomPaint`
/// can be a finite box covering all edges. Positions handed to [hitTest]
/// are therefore local pixels of that box in canvas units.
class EdgePainter extends CustomPainter {
  EdgePainter({
    required this.controller,
    required this.origin,
    this.strokeColor = const Color(0xFF94A3B8),
    this.strokeWidth = 1.5,
    super.repaint,
  });

  final GraphController controller;
  final Offset origin;
  final Color strokeColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.translate(-origin.dx, -origin.dy);
    for (final edge in controller.edges) {
      canvas.drawPath(controller.geometryOf(edge).path.path, paint);
    }
  }

  /// The edge under [localPosition], or null.
  String? edgeAt(Offset localPosition) =>
      controller.edgeAt(localPosition + origin);

  @override
  bool hitTest(Offset position) => edgeAt(position) != null;

  @override
  bool shouldRepaint(EdgePainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.origin != origin ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// The edge layer: a [CustomPaint] sized to [bounds] whose painter repaints
/// when any node moves and reports edge taps.
class EdgeLayer extends StatelessWidget {
  const EdgeLayer({
    required this.controller,
    required this.bounds,
    this.onEdgeTap,
    super.key,
  });

  final GraphController controller;

  /// Content bounds in canvas units; the layer is painted at `bounds.topLeft`.
  final Rect bounds;
  final ValueChanged<String>? onEdgeTap;

  @override
  Widget build(BuildContext context) {
    final painter = EdgePainter(
      controller: controller,
      origin: bounds.topLeft,
      repaint: controller.geometryChanged,
    );
    return SizedBox(
      width: bounds.width,
      height: bounds.height,
      child: GestureDetector(
        onTapDown: onEdgeTap == null
            ? null
            : (details) {
                final id = painter.edgeAt(details.localPosition);
                if (id != null) onEdgeTap!(id);
              },
        child: RepaintBoundary(child: CustomPaint(painter: painter)),
      ),
    );
  }
}
