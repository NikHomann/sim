import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/auth/shared/google_icon_data.dart';
import 'package:sim_app/features/auth/shared/svg_path.dart';
import 'package:sim_design/sim_design.dart';

/// `WORDMARK_VIEW_BOX` / `WORDMARK_PATHS`
/// (`packages/emcn/src/components/sim-wordmark/paths.ts`).
const Size simWordmarkViewBox = Size(441, 212);

const List<String> _wordmarkPaths = <String>[
  'M0 160.9H29.51C29.51 169.08 32.46 175.61 38.37 180.48C44.27 185.12 52.25 187.44 62.31 187.44C73.24 187.44 81.65 185.34 87.56 181.14C93.46 176.71 96.41 170.85 96.41 163.55C96.41 158.24 94.77 153.82 91.49 150.28C88.43 146.74 82.75 143.86 74.44 141.65L46.24 135.01C32.03 131.47 21.42 126.05 14.43 118.75C7.65 111.45 4.26 101.83 4.26 89.88C4.26 79.93 6.78 71.3 11.81 64C17.05 56.7 24.16 51.06 33.12 47.08C42.3 43.09 52.8 41.1 64.6 41.1C76.41 41.1 86.57 43.2 95.1 47.41C103.84 51.61 110.62 57.47 115.43 64.99C120.46 72.52 123.08 81.48 123.3 91.87H93.79C93.57 83.47 90.84 76.94 85.59 72.3C80.34 67.65 73.02 65.33 63.62 65.33C54 65.33 46.57 67.43 41.32 71.63C36.07 75.83 33.45 81.59 33.45 88.89C33.45 99.73 41.32 107.14 57.06 111.12L85.26 118.09C98.81 121.19 108.98 126.28 115.76 133.35C122.53 140.21 125.92 149.61 125.92 161.56C125.92 171.74 123.19 180.7 117.73 188.44C112.26 195.96 104.72 201.82 95.1 206.03C85.7 210.01 74.55 212 61.65 212C42.85 212 27.87 207.35 16.72 198.06C5.57 188.77 0 176.38 0 160.9Z',
  'M232.8 212H202.13L202.13 49.76H229.54V77.39C232.8 68.34 239.11 60.66 247.81 54.7C256.73 48.52 267.5 45.43 280.12 45.43C294.26 45.43 306.01 49.29 315.36 57.02C324.72 64.75 330.81 75.01 333.64 87.82H328.09C330.27 75.01 336.25 64.75 346.04 57.02C355.83 49.29 367.9 45.43 382.26 45.43C400.54 45.43 414.89 50.84 425.34 61.66C435.78 72.47 441 87.26 441 106.03V212H410.98V113.65C410.98 100.84 407.71 91.02 401.19 84.17C394.88 77.11 386.29 73.58 375.41 73.58C367.79 73.58 361.05 75.34 355.17 78.88C349.52 82.19 345.06 87.04 341.8 93.45C338.53 99.85 336.9 107.36 336.9 115.97V212H306.55V113.32C306.55 100.51 303.4 90.8 297.09 84.17C290.78 77.33 282.19 73.91 271.31 73.91C263.69 73.91 256.95 75.67 251.08 79.21C245.42 82.52 240.96 87.38 237.7 93.78C234.43 99.96 232.8 107.36 232.8 115.97V212Z',
  'M184.83 20.55C184.83 31.9 175.64 41.1 164.29 41.1C152.95 41.1 143.76 31.9 143.76 20.55C143.76 9.2 152.95 0 164.29 0C175.64 0 184.83 9.2 184.83 20.55Z',
  'M179.43 212H149.16V49.76C153.76 51.91 158.88 53.12 164.29 53.12C169.7 53.12 174.83 51.91 179.43 49.76V212Z',
];

final List<Path> _wordmarkGlyphs = _wordmarkPaths.map(parseSvgPath).toList();

/// `SimWordmark`: the logotype at the `nav` size (37×18) by default, filled
/// `--text-body`.
class SimWordmark extends StatelessWidget {
  const SimWordmark({super.key, this.width = 37, this.height = 18, this.color});

  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, height),
    painter: _GlyphPainter(
      glyphs: _wordmarkGlyphs,
      viewBox: simWordmarkViewBox,
      color: color ?? SimTheme.of(context).colors.textBody,
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.glyphs,
    required this.viewBox,
    required this.color,
  });

  final List<Path> glyphs;
  final Size viewBox;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final glyph in glyphs) {
      canvas.drawPath(fitSvgPath(glyph, viewBox, size), paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.viewBox != viewBox ||
      oldDelegate.glyphs != glyphs;
}

const String _githubPath =
    'M13 0C11.29 0 9.6 0.34 8.03 0.99C6.45 1.64 5.01 2.6 3.81 3.81C1.37 6.25 0 9.55 0 13C0 18.75 3.73 23.62 8.89 25.35C9.54 25.45 9.75 25.05 9.75 24.7V22.5C6.15 23.28 5.38 20.76 5.38 20.76C4.78 19.25 3.94 18.85 3.94 18.85C2.76 18.04 4.03 18.07 4.03 18.07C5.33 18.16 6.02 19.41 6.02 19.41C7.15 21.39 9.06 20.8 9.8 20.49C9.92 19.64 10.26 19.07 10.62 18.75C7.74 18.42 4.71 17.3 4.71 12.35C4.71 10.91 5.2 9.75 6.05 8.83C5.92 8.5 5.46 7.15 6.18 5.4C6.18 5.4 7.27 5.04 9.75 6.72C10.78 6.44 11.9 6.29 13 6.29C14.11 6.29 15.22 6.44 16.25 6.72C18.73 5.04 19.83 5.4 19.83 5.4C20.54 7.15 20.09 8.5 19.95 8.83C20.8 9.75 21.29 10.91 21.29 12.35C21.29 17.32 18.25 18.41 15.35 18.73C15.82 19.14 16.25 19.93 16.25 21.14V24.7C16.25 25.05 16.46 25.47 17.12 25.35C22.28 23.61 26 18.75 26 13C26 11.29 25.66 9.6 25.01 8.03C24.36 6.45 23.4 5.01 22.19 3.81C20.99 2.6 19.55 1.64 17.97 0.99C16.4 0.34 14.71 0 13 0Z';

final List<Path> _githubGlyph = <Path>[parseSvgPath(_githubPath)];

/// `GithubIcon` (`components/icons.tsx:764`): the mark in `currentColor`.
class GithubIcon extends StatelessWidget {
  const GithubIcon({super.key, this.size = 16, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(
      glyphs: _githubGlyph,
      viewBox: const Size(26, 26),
      color: color ?? SimTheme.of(context).colors.textIcon,
    ),
  );
}

/// `MicrosoftIcon` (`components/icons.tsx:3537`): four brand squares.
class MicrosoftIcon extends StatelessWidget {
  const MicrosoftIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _MicrosoftPainter());
}

class _MicrosoftPainter extends CustomPainter {
  const _MicrosoftPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 109.3;
    void square(double x, double y, Color color) => canvas.drawRect(
      Rect.fromLTWH(x * s, y * s, 51.9 * s, 51.9 * s),
      Paint()..color = color,
    );
    square(0, 0, const Color(0xFFF1511B));
    square(57.3, 0, const Color(0xFF80CC28));
    square(0, 57.4, const Color(0xFF00ADEF));
    square(57.3, 57.4, const Color(0xFFFBBC09));
  }

  @override
  bool shouldRepaint(_MicrosoftPainter oldDelegate) => false;
}

/// The decoded Google PNG (exposed so goldens can precache it).
final Uint8List googleIconPng = base64Decode(googleIconPngBase64);

/// `GoogleIcon` (`components/icons.tsx:1459`): the PNG "G" mark.
class GoogleIcon extends StatelessWidget {
  const GoogleIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => Image.memory(
    googleIconPng,
    width: size,
    height: size,
  );
}
