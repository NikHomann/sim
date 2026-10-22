import 'package:flutter/widgets.dart';
import 'package:sim_app/features/auth/shared/svg_path.dart';
import 'package:sim_design/sim_design.dart';

/// `SlackIcon` (`apps/sim/components/icons.tsx`): the four-colour brand mark
/// of the help menu's "Join Slack" row. It is a brand icon, not an emcn
/// export, so `SimEmcnIcons` does not carry it; its fills are literal.
class SlackIcon extends StatelessWidget {
  const SlackIcon({super.key, this.size = SimLayout.iconSize});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: const _SlackPainter()),
  );
}

const List<(String, Color)> _shapes = <(String, Color)>[
  (
    'M53.84,161.32 C53.84,176.15 41.85,188.14 27.02,188.14 C12.19,188.14 0.2,176.15 0.2,161.32 C0.2,146.49 12.19,134.5 27.02,134.5 L53.84,134.5 L53.84,161.32 Z M67.25,161.32 C67.25,146.49 79.24,134.5 94.07,134.5 C108.9,134.5 120.89,146.49 120.89,161.32 L120.89,228.37 C120.89,243.2 108.9,255.19 94.07,255.19 C79.24,255.19 67.25,243.2 67.25,228.37 L67.25,161.32 Z',
    Color(0xFFE01E5A),
  ),
  (
    'M94.07,53.64 C79.24,53.64 67.25,41.65 67.25,26.82 C67.25,11.99 79.24,0 94.07,0 C108.9,0 120.89,11.99 120.89,26.82 L120.89,53.64 L94.07,53.64 Z M94.07,67.25 C108.9,67.25 120.89,79.24 120.89,94.07 C120.89,108.9 108.9,120.89 94.07,120.89 L26.82,120.89 C11.99,120.89 0,108.9 0,94.07 C0,79.24 11.99,67.25 26.82,67.25 L94.07,67.25 Z',
    Color(0xFF36C5F0),
  ),
  (
    'M201.55,94.07 C201.55,79.24 213.54,67.25 228.37,67.25 C243.2,67.25 255.19,79.24 255.19,94.07 C255.19,108.9 243.2,120.89 228.37,120.89 L201.55,120.89 L201.55,94.07 Z M188.14,94.07 C188.14,108.9 176.15,120.89 161.32,120.89 C146.49,120.89 134.5,108.9 134.5,94.07 L134.5,26.82 C134.5,11.99 146.49,0 161.32,0 C176.15,0 188.14,11.99 188.14,26.82 L188.14,94.07 Z',
    Color(0xFF2EB67D),
  ),
  (
    'M161.32,201.55 C176.15,201.55 188.14,213.54 188.14,228.37 C188.14,243.2 176.15,255.19 161.32,255.19 C146.49,255.19 134.5,243.2 134.5,228.37 L134.5,201.55 L161.32,201.55 Z M161.32,188.14 C146.49,188.14 134.5,176.15 134.5,161.32 C134.5,146.49 146.49,134.5 161.32,134.5 L228.57,134.5 C243.4,134.5 255.39,146.49 255.39,161.32 C255.39,176.15 243.4,188.14 228.57,188.14 L161.32,188.14 Z',
    Color(0xFFECB22E),
  ),
];

final List<Path> _paths = <Path>[for (final (d, _) in _shapes) parseSvgPath(d)];

class _SlackPainter extends CustomPainter {
  const _SlackPainter();

  /// The mark's 256-unit viewBox.
  static const double _viewBox = 256;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _viewBox);
    for (var i = 0; i < _shapes.length; i++) {
      canvas.drawPath(
        _paths[i],
        Paint()
          ..style = PaintingStyle.fill
          ..color = _shapes[i].$2
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SlackPainter oldDelegate) => false;
}
