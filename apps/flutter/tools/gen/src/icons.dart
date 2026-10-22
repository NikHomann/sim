/// Emits `icons.g.dart`: asset path constants for every extracted icon.
library;

// Codegen writes long runs of buffer.writeln calls; cascades would hide the
// line structure of the emitted source.
// ignore_for_file: cascade_invocations

import 'literals.dart';

/// Generates path constants from `icons/report.json`.
///
/// [vecFailures] lists `<set>/<name>` ids whose `.vec` compile failed; those
/// keep an SVG path only and are listed under `needsRasterFallback`.
String generateIcons(
  Map<String, Object?> report,
  Set<String> vecFailures,
  String commit,
) {
  final icons = (report['icons']! as Map<String, Object?>)
      .cast<String, Map<String, Object?>>();
  final ids = icons.keys.toList()..sort();
  final buffer = StringBuffer(generatedHeader(commit, 'icons/report.json'));
  buffer.writeln('''
/// Paths of the extracted icons, relative to `apps/flutter/generated`.
///
/// `<id>` is `<set>/<name>` (`emcn/arrow-down`, `brand/agent-icon`), the same
/// id an `IconRef` carries. `.vec` files are precompiled with
/// `vector_graphics_compiler`; an icon in [needsRasterFallback] has no `.vec`
/// and must be drawn from its SVG or a PNG fallback.
class SimIconAssets {
  const SimIconAssets._();

  static const String svgRoot = 'icons';
  static const String vecRoot = 'icons_vec';

  static String? svgPath(String id) => svg[id];
  static String? vecPath(String id) => vec[id];

  /// `<set>/<name>` for every exported React icon component, keyed by export name.
  static const Map<String, String> byExport = <String, String>{''');
  for (final id in ids) {
    buffer.writeln(
      '    ${dartString(icons[id]!['export']! as String)}: ${dartString(id)},',
    );
  }
  buffer.writeln('  };');
  buffer.writeln();
  buffer.writeln('  static const Map<String, String> svg = <String, String>{');
  for (final id in ids) {
    buffer.writeln(
      '    ${dartString(id)}: ${dartString(icons[id]!['file']! as String)},',
    );
  }
  buffer.writeln('  };');
  buffer.writeln();
  buffer.writeln('  static const Map<String, String> vec = <String, String>{');
  for (final id in ids) {
    if (vecFailures.contains(id)) continue;
    buffer.writeln(
      '    ${dartString(id)}: ${dartString('icons_vec/$id.vec')},',
    );
  }
  buffer.writeln('  };');
  buffer.writeln();
  buffer.writeln(
    '  /// Icons using SVG features the vector renderer may not support.',
  );
  buffer.writeln(
    '  static const Map<String, List<String>> features = <String, List<String>>{',
  );
  for (final id in ids) {
    final features = (icons[id]!['features'] as List<Object?>? ?? const [])
        .cast<String>();
    if (features.isEmpty) continue;
    buffer.writeln(
      '    ${dartString(id)}: ${dartLiteral(features, indent: '    ')},',
    );
  }
  buffer.writeln('  };');
  buffer.writeln();
  buffer.writeln('  static const Set<String> needsRasterFallback = <String>{');
  for (final id in vecFailures.toList()..sort()) {
    buffer.writeln('    ${dartString(id)},');
  }
  buffer.writeln('  };');
  buffer.writeln('}');
  return buffer.toString();
}
