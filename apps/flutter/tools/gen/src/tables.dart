/// Emits `tool_selector_tables.g.dart` from `tool-selector-tables.json`.
library;

// Codegen writes long runs of buffer.writeln calls; cascades would hide the
// line structure of the emitted source.
// ignore_for_file: cascade_invocations

import 'literals.dart';

String _rowKey(Map<String, Object?> params, List<String> dimensions) =>
    dimensions.map((d) => '$d=${params[d] ?? ''}').join('|');

/// Generates the decision tables plus a pure-Dart `selectToolId` lookup.
String generateTables(List<Object?> tables, String commit) {
  final buffer = StringBuffer(
    generatedHeader(commit, 'tool-selector-tables.json'),
  );
  buffer.writeln(
    r'''
/// The sampled `tools.config.tool` selector of one block.
///
/// [rows] is keyed by [rowKey] over [dimensions]; [pure] is true when the
/// extraction proved the selector reads nothing but the sampled dropdowns. An
/// impure table still carries every sampled row, but the block needs a hand
/// port keyed on `FnRef('<block>.tools.config.tool')` for the cases listed in
/// [freeInputs], [dynamicOptions], [unknownKeys] and [errors].
class ToolSelectorTable {
  const ToolSelectorTable({
    required this.block,
    required this.pure,
    required this.dimensions,
    required this.rows,
    required this.fallback,
    required this.freeInputs,
    required this.dynamicOptions,
    required this.unknownKeys,
    required this.errors,
  });

  final String block;
  final bool pure;
  final List<String> dimensions;
  final Map<String, String> rows;
  final String? fallback;
  final List<String> freeInputs;
  final List<String> dynamicOptions;
  final List<String> unknownKeys;
  final List<String> errors;

  /// Builds the [rows] key for [params]: `dim=value|dim=value` in dimension order.
  String rowKey(Map<String, Object?> params) =>
      dimensions.map((d) => '$d=${params[d] ?? ''}').join('|');

  /// The tool id for [params], or [fallback] when no row matches.
  String? lookup(Map<String, Object?> params) => rows[rowKey(params)] ?? fallback;
}

/// Registry of every sampled selector table, keyed by block type.
class ToolSelectorTables {
  const ToolSelectorTables._();

  static ToolSelectorTable? byBlock(String block) => tables[block];

  /// Resolves the serialized tool id the way upstream `selectToolId` does for
  /// blocks whose selector is a pure table; returns null for impure blocks and
  /// blocks without a selector (callers fall back to `toolAccess.first`).
  static String? selectToolId(String block, Map<String, Object?> params) {
    final table = tables[block];
    if (table == null || !table.pure) return null;
    return table.lookup(params);
  }

  static const Map<String, ToolSelectorTable> tables = <String, ToolSelectorTable>{''',
  );
  final sorted = tables.cast<Map<String, Object?>>().toList()
    ..sort((a, b) => (a['block']! as String).compareTo(b['block']! as String));
  for (final table in sorted) {
    final block = table['block']! as String;
    final dimensions = (table['dimensions']! as List<Object?>).cast<String>();
    final rows = (table['rows']! as List<Object?>).cast<Map<String, Object?>>();
    buffer.writeln('    ${dartString(block)}: ToolSelectorTable(');
    buffer.writeln('      block: ${dartString(block)},');
    buffer.writeln('      pure: ${table['pure'] == true},');
    buffer.writeln(
      '      dimensions: ${dartStringList(dimensions, indent: '      ')},',
    );
    buffer.writeln('      rows: <String, String>{');
    for (final row in rows) {
      final params = row['params']! as Map<String, Object?>;
      buffer.writeln(
        '        ${dartString(_rowKey(params, dimensions))}: ${dartString(row['toolId']! as String)},',
      );
    }
    buffer.writeln('      },');
    final fallback = table['fallback'];
    buffer.writeln(
      '      fallback: ${fallback is String ? dartString(fallback) : 'null'},',
    );
    for (final key in [
      'freeInputs',
      'dynamicOptions',
      'unknownKeys',
      'errors',
    ]) {
      buffer.writeln(
        '      $key: ${dartStringList(table[key] as List<Object?>? ?? const <Object?>[], indent: '      ')},',
      );
    }
    buffer.writeln('    ),');
  }
  buffer.writeln('  };');
  buffer.writeln('}');
  return buffer.toString();
}
