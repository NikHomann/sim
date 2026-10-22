/// Emits `subblock_types.g.dart` from `subblock-types.json`.
library;

// Codegen writes long runs of buffer.writeln calls; cascades would hide the
// line structure of the emitted source.
// ignore_for_file: cascade_invocations

import 'literals.dart';

/// Generates the `SubBlockType` union as constants plus usage counts.
String generateSubBlockTypes(Map<String, Object?> json, String commit) {
  final types = (json['types']! as List<Object?>).cast<String>();
  final usage = (json['usage'] as List<Object?>? ?? const [])
      .cast<Map<String, Object?>>();
  final buffer = StringBuffer(generatedHeader(commit, 'subblock-types.json'));
  buffer.writeln('''
/// The upstream `SubBlockType` union (`packages/workflow-types/src/blocks.ts`),
/// in declaration order, with how many registry entries use each type.
class SubBlockTypes {
  const SubBlockTypes._();

  static bool isKnown(String type) => all.contains(type);

  static const List<String> all = <String>[''');
  for (final type in types) {
    buffer.writeln('    ${dartString(type)},');
  }
  buffer.writeln('  ];');
  buffer.writeln();
  buffer.writeln(
    '  /// Number of subblock declarations of each type across blocks and triggers.',
  );
  buffer.writeln(
    '  static const Map<String, int> declarationCounts = <String, int>{',
  );
  final sortedUsage = [...usage]
    ..sort((a, b) => (a['type']! as String).compareTo(b['type']! as String));
  for (final entry in sortedUsage) {
    buffer.writeln(
      '    ${dartString(entry['type']! as String)}: ${entry['subBlocks']},',
    );
  }
  buffer.writeln('  };');
  buffer.writeln();
  buffer.writeln(
    '  /// Number of blocks and triggers declaring at least one subblock of each type.',
  );
  buffer.writeln(
    '  static const Map<String, int> ownerCounts = <String, int>{',
  );
  for (final entry in sortedUsage) {
    buffer.writeln(
      '    ${dartString(entry['type']! as String)}: ${entry['blocks']},',
    );
  }
  buffer.writeln('  };');
  buffer.writeln('}');
  return buffer.toString();
}
