import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// `DropOverlay`: inset 6px, radius 14, dashed 1.5px `--border-1`, fill
/// `--white` / dark `--surface-4`, "Drop files" over nine 14px type icons.
class ComposerDropOverlay extends StatelessWidget {
  const ComposerDropOverlay({super.key});

  static const List<SimIconData> icons = [
    SimEmcnIcons.pdfIcon,
    SimEmcnIcons.docxIcon,
    SimEmcnIcons.xlsxIcon,
    SimEmcnIcons.csvIcon,
    SimEmcnIcons.txtIcon,
    SimEmcnIcons.markdownIcon,
    SimEmcnIcons.jsonIcon,
    SimEmcnIcons.audioIcon,
    SimEmcnIcons.videoIcon,
  ];

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Positioned.fill(
      left: 6,
      top: 6,
      right: 6,
      bottom: 6,
      child: IgnorePointer(
        child: Semantics(
          container: true,
          identifier: 'chat-input.drop-overlay',
          child: CustomPaint(
            painter: _DashedRRectPainter(color: c.border, radius: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: sim.isDark ? c.surface4 : SimColors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Text(
                      'Drop files',
                      style: sim.text.small.copyWith(color: c.textSecondary),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        for (final icon in icons)
                          SimIcon(icon, color: c.textIcon),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;
  static const double strokeWidth = 1.5;
  static const double dash = 4.5;
  static const double gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
