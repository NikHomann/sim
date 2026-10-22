/// Dart code generator for the Flutter port.
///
/// Reads `apps/flutter/generated/*.json` (written by
/// `apps/sim/scripts/export-flutter-port.ts` through
/// `tools/extract/run.ps1`) and writes:
///
/// * `generated/dart/*.g.dart` — registry data as const Dart (no Flutter imports)
/// * `generated/icons_vec/**.vec` — every SVG precompiled with
///   `vector_graphics_compiler`; failures are recorded under `vec` in
///   `generated/icons/report.json` with a PNG-fallback note
///
/// * `lib/features/home/hero/suggestion_catalog.g.dart` — the home hero
///   suggestion catalog, also reading `packages/deployment-config` and
///   `apps/sim/lib/oauth/oauth.ts` from the upstream checkout
///
///   dart run tools/gen/main.dart [--generated <dir>] [--out <dir>] [--dart-only]
///   dart run tools/gen/main.dart --catalog-only [--catalog-out <file>]
///       [--upstream <dir>] [--generated <dir>]
///
/// `--dart-only` skips the `.vec` compile and the catalog (used by
/// `tools/check_generated.dart` for its determinism run). `--catalog-only`
/// writes just the catalog (to `--catalog-out`, default its `lib/` path). Only `dart:` libraries are used here; the
/// compiler runs as a child process resolved from `tools/gen/pubspec.yaml`.
library;

import 'dart:convert';
import 'dart:io';

import 'src/blocks.dart';
import 'src/icons.dart';
import 'src/subblock_types.dart';
import 'src/suggestion_catalog.dart';
import 'src/tables.dart';
import 'src/tokens.dart';

const _dartFiles = [
  'markers.g.dart',
  'blocks.g.dart',
  'tool_selector_tables.g.dart',
  'subblock_types.g.dart',
  'icons.g.dart',
  'tokens.g.dart',
];

String? _arg(List<String> args, String name) {
  final index = args.indexOf(name);
  return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
}

Map<String, Object?> _readJson(Directory generated, String relative) {
  final file = File('${generated.path}/$relative');
  if (!file.existsSync()) {
    throw StateError('missing ${file.path}; run tools/extract/run.ps1 first');
  }
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

List<Object?> _readJsonList(Directory generated, String relative) {
  final file = File('${generated.path}/$relative');
  if (!file.existsSync()) {
    throw StateError('missing ${file.path}; run tools/extract/run.ps1 first');
  }
  return jsonDecode(file.readAsStringSync()) as List<Object?>;
}

Map<String, Object?> _sortedMap(Map<String, Object?> map) {
  final keys = map.keys.toList()..sort();
  return {for (final key in keys) key: map[key]};
}

/// Compiles the SVGs and records the outcome under `vec` in `icons/report.json`.
Future<Set<String>> _compileVec(
  Directory genDir,
  Directory generated,
  Directory out,
) async {
  final vecRoot = Directory('${out.path}/icons_vec');
  if (vecRoot.existsSync()) vecRoot.deleteSync(recursive: true);
  vecRoot.createSync(recursive: true);
  final reportFile = File(
    '${Directory.systemTemp.path}/sim-vec-report-$pid.json',
  );
  final packageConfig = File('${genDir.path}/.dart_tool/package_config.json');
  if (!packageConfig.existsSync()) {
    final pubGet = await Process.run(Platform.resolvedExecutable, [
      'pub',
      'get',
    ], workingDirectory: genDir.path);
    if (pubGet.exitCode != 0) {
      throw StateError(
        'dart pub get failed in ${genDir.path}:\n${pubGet.stderr}',
      );
    }
  }
  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    'bin/compile_vec.dart',
    '${generated.path}/icons',
    vecRoot.path,
    reportFile.path,
  ], workingDirectory: genDir.path);
  stdout.write(result.stdout);
  if (result.exitCode != 0) {
    throw StateError('vector_graphics_compiler run failed:\n${result.stderr}');
  }
  final vecReport = (jsonDecode(reportFile.readAsStringSync()) as Map)
      .cast<String, Object?>();
  reportFile.deleteSync();
  final failures = (vecReport['failures']! as Map).cast<String, Object?>();

  final iconReportFile = File('${generated.path}/icons/report.json');
  final iconReport = (jsonDecode(iconReportFile.readAsStringSync()) as Map)
      .cast<String, Object?>();
  iconReport['vec'] = {
    'compiler': 'vector_graphics_compiler (tools/gen/pubspec.lock)',
    'compiled': vecReport['compiled'],
    'failed': vecReport['failed'],
    'failures': {
      for (final id in failures.keys.toList()..sort())
        id: {
          'error': failures[id],
          'fallback':
              'no .vec emitted; render the SVG at runtime or ship a PNG@2x fallback',
        },
    },
  };
  iconReportFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(_sortedMap(iconReport))}\n',
  );
  return failures.keys.toSet();
}

Set<String> _recordedVecFailures(Map<String, Object?> iconReport) {
  final vec = iconReport['vec'];
  if (vec is! Map) return {};
  final failures = vec['failures'];
  return failures is Map ? failures.keys.cast<String>().toSet() : {};
}

void _writeCatalog(Directory appRoot, Directory generated, List<String> args) {
  final upstream = Directory(
    _arg(args, '--upstream') ?? appRoot.parent.parent.path,
  );
  String readUpstream(String relative) {
    final file = File('${upstream.path}/$relative');
    if (!file.existsSync()) {
      throw StateError('missing ${file.path}; pass --upstream <repo root>');
    }
    return file.readAsStringSync();
  }

  final source = generateSuggestionCatalog(
    blocks: _readJson(generated, 'blocks.json'),
    integrationMetadataTs: readUpstream(
      'packages/deployment-config/src/integration-metadata.ts',
    ),
    oauthTs: readUpstream('apps/sim/lib/oauth/oauth.ts'),
    log: (line) => stdout.writeln('suggestion catalog: $line'),
  );
  final out = File(
    _arg(args, '--catalog-out') ?? '${appRoot.path}/$suggestionCatalogPath',
  );
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(source);
  // The file lives under lib/, which CI checks with `dart format`.
  final format = Process.runSync(Platform.resolvedExecutable, [
    'format',
    out.path,
  ]);
  if (format.exitCode != 0) {
    throw StateError('dart format ${out.path} failed:\n${format.stderr}');
  }
  stdout.writeln('wrote ${out.path}');
}

Future<void> main(List<String> args) async {
  final genDir = File.fromUri(Platform.script).parent;
  final appRoot = genDir.parent.parent;
  final generated = Directory(
    _arg(args, '--generated') ?? '${appRoot.path}/generated',
  );
  final out = Directory(_arg(args, '--out') ?? generated.path);
  final dartOnly = args.contains('--dart-only');
  final catalogOnly = args.contains('--catalog-only');

  if (catalogOnly || !dartOnly) {
    _writeCatalog(appRoot, generated, args);
    if (catalogOnly) return;
  }

  final manifest = _readJson(generated, 'manifest.json');
  final commit = manifest['upstreamCommit']! as String;
  final blocks = _readJson(generated, 'blocks.json');
  final tables = _readJsonList(generated, 'tool-selector-tables.json');
  final subBlockTypes = _readJson(generated, 'subblock-types.json');
  final tokens = _readJson(generated, 'tokens.json');

  final vecFailures = dartOnly
      ? _recordedVecFailures(_readJson(generated, 'icons/report.json'))
      : await _compileVec(genDir, generated, out);
  final iconReport = _readJson(generated, 'icons/report.json');

  final dartDir = Directory('${out.path}/dart');
  if (dartDir.existsSync()) dartDir.deleteSync(recursive: true);
  dartDir.createSync(recursive: true);
  final sources = <String, String>{
    'markers.g.dart': generateMarkers(commit),
    'blocks.g.dart': generateBlocks(blocks, commit),
    'tool_selector_tables.g.dart': generateTables(tables, commit),
    'subblock_types.g.dart': generateSubBlockTypes(subBlockTypes, commit),
    'icons.g.dart': generateIcons(iconReport, vecFailures, commit),
    'tokens.g.dart': generateTokens(tokens, commit),
  };
  for (final name in _dartFiles) {
    File('${dartDir.path}/$name').writeAsStringSync(sources[name]!);
  }
  stdout.writeln(
    'wrote ${_dartFiles.length} files to ${dartDir.path}'
    '${dartOnly ? ' (dart only)' : ', ${vecFailures.length} vec failures'}',
  );
}
