import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Minimal SVG path-data parser (M/L/H/V/C/S/Q/T/A/Z and their relative
/// forms) for the hand-ported brand glyphs: the wordmark and the GitHub mark.
/// Only the commands those paths use are supported; anything else throws.
Path parseSvgPath(String data) {
  final path = Path();
  final tokens = _tokenize(data);
  var i = 0;
  var cx = 0.0;
  var cy = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  double? lastCtrlX;
  double? lastCtrlY;
  String? lastCommand;
  var command = '';

  double next() => tokens[i++].value!;

  while (i < tokens.length) {
    final token = tokens[i];
    if (token.value == null) {
      command = token.command!;
      i++;
    } else if (command == 'M') {
      command = 'L';
    } else if (command == 'm') {
      command = 'l';
    }
    final relative = command.toLowerCase() == command;
    switch (command.toUpperCase()) {
      case 'M':
        final x = next();
        final y = next();
        cx = relative ? cx + x : x;
        cy = relative ? cy + y : y;
        startX = cx;
        startY = cy;
        path.moveTo(cx, cy);
        lastCtrlX = lastCtrlY = null;
      case 'L':
        final x = next();
        final y = next();
        cx = relative ? cx + x : x;
        cy = relative ? cy + y : y;
        path.lineTo(cx, cy);
        lastCtrlX = lastCtrlY = null;
      case 'H':
        final x = next();
        cx = relative ? cx + x : x;
        path.lineTo(cx, cy);
        lastCtrlX = lastCtrlY = null;
      case 'V':
        final y = next();
        cy = relative ? cy + y : y;
        path.lineTo(cx, cy);
        lastCtrlX = lastCtrlY = null;
      case 'C':
        final x1 = next();
        final y1 = next();
        final x2 = next();
        final y2 = next();
        final x = next();
        final y = next();
        final ox = relative ? cx : 0.0;
        final oy = relative ? cy : 0.0;
        path.cubicTo(ox + x1, oy + y1, ox + x2, oy + y2, ox + x, oy + y);
        lastCtrlX = ox + x2;
        lastCtrlY = oy + y2;
        cx = ox + x;
        cy = oy + y;
      case 'S':
        final x2 = next();
        final y2 = next();
        final x = next();
        final y = next();
        final ox = relative ? cx : 0.0;
        final oy = relative ? cy : 0.0;
        final smooth =
            lastCommand != null && 'CS'.contains(lastCommand.toUpperCase());
        final x1 = smooth ? 2 * cx - lastCtrlX! : cx;
        final y1 = smooth ? 2 * cy - lastCtrlY! : cy;
        path.cubicTo(x1, y1, ox + x2, oy + y2, ox + x, oy + y);
        lastCtrlX = ox + x2;
        lastCtrlY = oy + y2;
        cx = ox + x;
        cy = oy + y;
      case 'Q':
        final x1 = next();
        final y1 = next();
        final x = next();
        final y = next();
        final ox = relative ? cx : 0.0;
        final oy = relative ? cy : 0.0;
        path.quadraticBezierTo(ox + x1, oy + y1, ox + x, oy + y);
        lastCtrlX = ox + x1;
        lastCtrlY = oy + y1;
        cx = ox + x;
        cy = oy + y;
      case 'T':
        final x = next();
        final y = next();
        final ox = relative ? cx : 0.0;
        final oy = relative ? cy : 0.0;
        final smooth =
            lastCommand != null && 'QT'.contains(lastCommand.toUpperCase());
        final x1 = smooth ? 2 * cx - lastCtrlX! : cx;
        final y1 = smooth ? 2 * cy - lastCtrlY! : cy;
        path.quadraticBezierTo(x1, y1, ox + x, oy + y);
        lastCtrlX = x1;
        lastCtrlY = y1;
        cx = ox + x;
        cy = oy + y;
      case 'A':
        final rx = next();
        final ry = next();
        final rotation = next();
        final largeArc = next() != 0;
        final sweep = next() != 0;
        final x = next();
        final y = next();
        cx = relative ? cx + x : x;
        cy = relative ? cy + y : y;
        path.arcToPoint(
          Offset(cx, cy),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
        lastCtrlX = lastCtrlY = null;
      case 'Z':
        path.close();
        cx = startX;
        cy = startY;
        lastCtrlX = lastCtrlY = null;
      default:
        throw FormatException('Unsupported SVG path command "$command"');
    }
    lastCommand = command;
  }
  return path;
}

class _Token {
  const _Token.command(this.command) : value = null;
  const _Token.number(this.value) : command = null;

  final String? command;
  final double? value;
}

final RegExp _tokenPattern = RegExp(
  r'[A-Za-z]|-?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?',
);

List<_Token> _tokenize(String data) {
  final tokens = <_Token>[];
  for (final match in _tokenPattern.allMatches(data)) {
    final text = match.group(0)!;
    if (RegExp('[A-Za-z]').hasMatch(text)) {
      tokens.add(_Token.command(text));
    } else {
      tokens.add(_Token.number(double.parse(text)));
    }
  }
  return tokens;
}

/// Scales [path] (drawn in a `viewBox` of [viewBox]) into [size], preserving
/// aspect ratio like `preserveAspectRatio="xMidYMid meet"`.
Path fitSvgPath(Path path, Size viewBox, Size size) {
  final scale = math.min(
    size.width / viewBox.width,
    size.height / viewBox.height,
  );
  final dx = (size.width - viewBox.width * scale) / 2;
  final dy = (size.height - viewBox.height * scale) / 2;
  final matrix = Float64List.fromList(<double>[
    scale, 0, 0, 0, //
    0, scale, 0, 0, //
    0, 0, 1, 0, //
    dx, dy, 0, 1, //
  ]);
  return path.transform(matrix);
}
