import 'package:flutter/widgets.dart';
import 'package:sim_app/features/auth/shared/brand_icons.dart';
import 'package:sim_app/features/workspace_shell/sidebar/footer/slack_icon.dart';
import 'package:sim_design/sim_design.dart';

/// `GmailIcon` (`components/icons.tsx`), the five-colour mark on a 48×48
/// view box.
class GmailMark extends StatelessWidget {
  const GmailMark({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: const _GmailPainter(),
    ),
  );
}

class _GmailPainter extends CustomPainter {
  const _GmailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 48, size.height / 48);
    void fill(Color color, Path path) =>
        canvas.drawPath(path, Paint()..color = color);
    fill(
      const Color(0xFF4CAF50),
      Path()
        ..moveTo(45, 16.2)
        ..lineTo(40, 18.95)
        ..lineTo(35, 23.7)
        ..lineTo(35, 40)
        ..lineTo(42, 40)
        ..cubicTo(43.66, 40, 45, 38.66, 45, 37)
        ..close(),
    );
    fill(
      const Color(0xFF1E88E5),
      Path()
        ..moveTo(3, 16.2)
        ..lineTo(6.61, 17.91)
        ..lineTo(13, 23.7)
        ..lineTo(13, 40)
        ..lineTo(6, 40)
        ..cubicTo(4.34, 40, 3, 38.66, 3, 37)
        ..close(),
    );
    fill(
      const Color(0xFFE53935),
      Path()
        ..moveTo(35, 11.2)
        ..lineTo(24, 19.45)
        ..lineTo(13, 11.2)
        ..lineTo(12, 17)
        ..lineTo(13, 23.7)
        ..lineTo(24, 31.95)
        ..lineTo(35, 23.7)
        ..lineTo(36, 17)
        ..close(),
    );
    fill(
      const Color(0xFFC62828),
      Path()
        ..moveTo(3, 12.3)
        ..lineTo(3, 16.2)
        ..lineTo(13, 23.7)
        ..lineTo(13, 11.2)
        ..lineTo(9.88, 8.86)
        ..cubicTo(9.13, 8.3, 8.23, 8, 7.3, 8)
        ..cubicTo(4.92, 8, 3, 9.92, 3, 12.3)
        ..close(),
    );
    fill(
      const Color(0xFFFBC02D),
      Path()
        ..moveTo(45, 12.3)
        ..lineTo(45, 16.2)
        ..lineTo(35, 23.7)
        ..lineTo(35, 11.2)
        ..lineTo(38.12, 8.86)
        ..cubicTo(38.87, 8.3, 39.77, 8, 40.7, 8)
        ..cubicTo(43.08, 8, 45, 9.92, 45, 12.3)
        ..close(),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GmailPainter oldDelegate) => false;
}

/// The 16px `BrandIcon` of a suggested-action row. Slack, Gmail, GitHub
/// and the table glyph are drawn; any other brand falls back to a neutral
/// tile with the integration's initial (brand SVG rendering is a later
/// phase).
class SuggestionIcon extends StatelessWidget {
  const SuggestionIcon({
    super.key,
    this.slug,
    this.iconId,
    this.label = '',
    this.size = 16,
  });

  /// `slack`, `gmail`, ... for integration rows.
  final String? slug;

  /// `brand/github-icon`, ... for prompt rows; null is the table glyph.
  final String? iconId;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final key =
        slug ??
        iconId
            ?.replaceFirst('brand/', '')
            .replaceFirst(
              RegExp(r'-icon$'),
              '',
            );
    switch (key) {
      case 'slack':
        return SlackIcon(size: size);
      case 'gmail':
        return GmailMark(size: size);
      case 'github':
        return GithubIcon(size: size, color: c.textPrimary);
      case null:
        return SimIcon(SimEmcnIcons.table, size: size, color: c.textIcon);
    }
    final initial = label
        .replaceFirst('Integrate with ', '')
        .trim()
        .characters
        .firstOrNull;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface5,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        (initial ?? '').toUpperCase(),
        style: SimTheme.of(
          context,
        ).text.style(size * 0.6, color: c.textSecondary),
      ),
    );
  }
}
