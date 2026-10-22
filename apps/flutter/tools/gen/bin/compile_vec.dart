/// Compiles every SVG under an input root into `vector_graphics` binaries.
///
/// Runs in-process (one VM for all ~560 icons) and never aborts the batch: a
/// file that fails to parse is recorded in the JSON report written to the
/// third argument and skipped.
///
///   `dart run bin/compile_vec.dart svgRoot vecRoot report.json`
library;

import 'dart:convert';
import 'dart:io';

import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln('usage: compile_vec <svgRoot> <vecRoot> <report.json>');
    exitCode = 2;
    return;
  }
  final svgRoot = Directory(args[0]);
  final vecRoot = Directory(args[1]);
  final failures = <String, String>{};
  final compiled = <String>[];
  // The mask/clip/overdraw optimizers need Flutter's native path_ops library;
  // without it (no Flutter SDK cache) the SVG still encodes, with masks and
  // clips kept as runtime instructions instead of being flattened.
  final optimize = initializePathOpsFromFlutterCache();
  stdout.writeln(
    optimize
        ? 'path_ops loaded from the Flutter cache; optimizers enabled'
        : 'path_ops unavailable; masking/clipping/overdraw optimizers disabled',
  );
  final files =
      svgRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.svg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final relative = file.path
        .substring(svgRoot.path.length)
        .replaceAll(r'\', '/')
        .replaceFirst(RegExp('^/'), '');
    final id = relative.substring(0, relative.length - '.svg'.length);
    try {
      final bytes = encodeSvg(
        xml: file.readAsStringSync(),
        debugName: id,
        enableMaskingOptimizer: optimize,
        enableClippingOptimizer: optimize,
        enableOverdrawOptimizer: optimize,
      );
      final target = File('${vecRoot.path}/$id.vec');
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(bytes);
      compiled.add(id);
    } on Object catch (error) {
      failures[id] = error.toString().split('\n').first;
    }
  }
  final report = <String, Object?>{
    'compiled': compiled.length,
    'failed': failures.length,
    'failures': Map.fromEntries(
      failures.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
  };
  File(args[2]).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(
    'compiled ${compiled.length} icons, ${failures.length} failed',
  );
}
