/// Emits `tokens.g.dart` from `tokens.json`.
library;

// Codegen writes long runs of buffer.writeln calls; cascades would hide the
// line structure of the emitted source.
// ignore_for_file: cascade_invocations

import 'literals.dart';

final _hex = RegExp(r'^#([0-9a-fA-F]{3,8})$');
final _rgb = RegExp(
  r'^rgba?\(\s*([0-9.]+)\s*[, ]\s*([0-9.]+)\s*[, ]\s*([0-9.]+)\s*(?:[,/]\s*([0-9.]+%?)\s*)?\)$',
);

/// Parses a CSS colour literal into 0xAARRGGBB, or null for anything else
/// (`var(...)`, `oklch`, lengths).
int? parseArgb(String value) {
  final hex = _hex.firstMatch(value.trim());
  if (hex != null) {
    var digits = hex.group(1)!;
    if (digits.length == 3 || digits.length == 4) {
      digits = digits.split('').map((c) => '$c$c').join();
    }
    if (digits.length == 6) digits = 'ff$digits';
    if (digits.length != 8) return null;
    final rgb = int.parse(digits.substring(2), radix: 16);
    final alpha = int.parse(digits.substring(0, 2), radix: 16);
    return (alpha << 24) | rgb;
  }
  final rgb = _rgb.firstMatch(value.trim());
  if (rgb != null) {
    final r = double.parse(rgb.group(1)!).round().clamp(0, 255);
    final g = double.parse(rgb.group(2)!).round().clamp(0, 255);
    final b = double.parse(rgb.group(3)!).round().clamp(0, 255);
    var a = 255;
    final alphaText = rgb.group(4);
    if (alphaText != null) {
      final alpha = alphaText.endsWith('%')
          ? double.parse(alphaText.substring(0, alphaText.length - 1)) / 100
          : double.parse(alphaText);
      a = (alpha * 255).round().clamp(0, 255);
    }
    return (a << 24) | (r << 16) | (g << 8) | b;
  }
  return null;
}

void _stringMap(
  StringBuffer buffer,
  String name,
  Map<String, Object?> map,
  String doc,
) {
  buffer.writeln('  /// $doc');
  buffer.writeln(
    '  static const Map<String, String> $name = <String, String>{',
  );
  for (final key in map.keys.toList()..sort()) {
    buffer.writeln(
      '    ${dartString(key)}: ${dartString(map[key].toString())},',
    );
  }
  buffer.writeln('  };');
  buffer.writeln();
}

void _argbMap(
  StringBuffer buffer,
  String name,
  Map<String, Object?> map,
  String doc,
) {
  buffer.writeln('  /// $doc');
  buffer.writeln('  static const Map<String, int> $name = <String, int>{');
  for (final key in map.keys.toList()..sort()) {
    final argb = parseArgb(map[key].toString());
    if (argb == null) continue;
    buffer.writeln(
      '    ${dartString(key)}: 0x${argb.toRadixString(16).padLeft(8, '0')},',
    );
  }
  buffer.writeln('  };');
  buffer.writeln();
}

/// Generates the CSS custom properties of `globals.css` as Dart constants.
String generateTokens(Map<String, Object?> tokens, String commit) {
  final theme = tokens['theme']! as Map<String, Object?>;
  final buffer = StringBuffer(generatedHeader(commit, 'tokens.json'));
  buffer.writeln('''
/// CSS custom properties from `apps/sim/app/_styles/globals.css`, keyed by
/// their `--name`. Values are the raw CSS text; the `*Argb` maps hold the
/// subset that is a colour literal, as 0xAARRGGBB.
class SimCssTokens {
  const SimCssTokens._();
''');
  _stringMap(
    buffer,
    'root',
    tokens['root']! as Map<String, Object?>,
    'Declared on `:root` (layout variables and light defaults).',
  );
  _stringMap(
    buffer,
    'light',
    tokens['light']! as Map<String, Object?>,
    'Declared on `.light` (also `:root`).',
  );
  _stringMap(
    buffer,
    'dark',
    tokens['dark']! as Map<String, Object?>,
    'Declared on `.dark`.',
  );
  _stringMap(
    buffer,
    'themeInline',
    theme['inline']! as Map<String, Object?>,
    'Tailwind `@theme inline` variables (fonts, colour aliases, radii, shadows).',
  );
  _stringMap(
    buffer,
    'themeStatic',
    theme['static']! as Map<String, Object?>,
    'Tailwind `@theme static` variables.',
  );
  _argbMap(
    buffer,
    'lightArgb',
    tokens['light']! as Map<String, Object?>,
    'Colour literals of [light].',
  );
  _argbMap(
    buffer,
    'darkArgb',
    tokens['dark']! as Map<String, Object?>,
    'Colour literals of [dark].',
  );
  _argbMap(
    buffer,
    'themeStaticArgb',
    theme['static']! as Map<String, Object?>,
    'Colour literals of [themeStatic].',
  );
  final keyframes = (tokens['keyframes'] as List<Object?>? ?? const [])
      .cast<String>();
  buffer.writeln('  /// `@keyframes` names declared in the stylesheet.');
  buffer.writeln(
    '  static const List<String> keyframes = ${dartStringList(keyframes, indent: '  ')};',
  );
  buffer.writeln('}');
  return buffer.toString();
}
