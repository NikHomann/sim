/// Verifies `apps/flutter/generated` against the recorded upstream baseline.
///
/// Fails (exit 1) with a clear message when:
///
/// * `generated/manifest.json` records a different commit than
///   `docs/port/UPSTREAM_COMMIT`;
/// * the manifest counts disagree with the files and registries on disk;
/// * `tools/gen/main.dart` is not deterministic (two runs differ) or the
///   committed `generated/dart` is stale (differs from a fresh run);
/// * an extracted SVG has neither a `.vec` nor a recorded compile failure.
///
///   dart run tools/check_generated.dart   (from apps/flutter)
library;

import 'dart:convert';
import 'dart:io';

final _failures = <String>[];

void _fail(String message) => _failures.add(message);

Map<String, Object?> _json(File file) =>
    (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();

int _count(Directory dir, String extension) => dir.existsSync()
    ? dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith(extension))
          .length
    : 0;

void _expectCount(String what, int expected, int actual) {
  if (expected != actual) {
    _fail('$what: manifest says $expected, found $actual');
  }
}

Map<String, List<int>> _snapshot(Directory dir) {
  final files = <String, List<int>>{};
  if (!dir.existsSync()) return files;
  for (final file in dir.listSync(recursive: true).whereType<File>()) {
    final relative = file.path.substring(dir.path.length).replaceAll(r'\', '/');
    files[relative] = file.readAsBytesSync();
  }
  return files;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void _compareTrees(String label, Directory left, Directory right) {
  final a = _snapshot(left);
  final b = _snapshot(right);
  final names = {...a.keys, ...b.keys}.toList()..sort();
  for (final name in names) {
    final x = a[name];
    final y = b[name];
    if (x == null || y == null) {
      _fail(
        '$label: $name exists only in ${x == null ? right.path : left.path}',
      );
    } else if (!_sameBytes(x, y)) {
      _fail('$label: $name differs');
    }
  }
}

Future<Directory> _runGenerator(
  Directory appRoot,
  Directory generated,
  String label,
) async {
  final out = Directory.systemTemp.createTempSync('sim-generated-$label-');
  final result = await Process.run(
    Platform.resolvedExecutable,
    [
      'run',
      'tools/gen/main.dart',
      '--generated',
      generated.path,
      '--out',
      out.path,
      '--dart-only',
    ],
    workingDirectory: appRoot.path,
  );
  if (result.exitCode != 0) {
    _fail('generator run $label failed:\n${result.stdout}${result.stderr}');
  }
  return out;
}

Future<void> main() async {
  final appRoot = File.fromUri(Platform.script).parent.parent;
  final generated = Directory('${appRoot.path}/generated');
  final manifestFile = File('${generated.path}/manifest.json');
  if (!manifestFile.existsSync()) {
    stderr.writeln(
      'check_generated: ${manifestFile.path} is missing; run tools/extract/run.ps1',
    );
    exitCode = 1;
    return;
  }
  final manifest = _json(manifestFile);
  final counts = (manifest['counts']! as Map).cast<String, Object?>();

  final expectedCommit = File(
    '${appRoot.path}/docs/port/UPSTREAM_COMMIT',
  ).readAsStringSync().trim();
  final actualCommit = manifest['upstreamCommit'];
  if (actualCommit != expectedCommit) {
    _fail(
      'upstream commit mismatch: manifest.json has $actualCommit, '
      'docs/port/UPSTREAM_COMMIT has $expectedCommit (re-run tools/extract/run.ps1 '
      'or update UPSTREAM_COMMIT)',
    );
  }

  _expectCount(
    'blocks',
    counts['blocks']! as int,
    _json(File('${generated.path}/blocks.json')).length,
  );
  _expectCount(
    'tools',
    counts['tools']! as int,
    _json(File('${generated.path}/tools.json')).length,
  );
  _expectCount(
    'triggers',
    counts['triggers']! as int,
    _json(File('${generated.path}/triggers.json')).length,
  );
  final icons = (counts['icons']! as Map).cast<String, Object?>();
  for (final set in icons.keys) {
    _expectCount(
      'icons/$set',
      icons[set]! as int,
      _count(Directory('${generated.path}/icons/$set'), '.svg'),
    );
  }
  final closures =
      jsonDecode(File('${generated.path}/closures.json').readAsStringSync())
          as List<Object?>;
  _expectCount('closures', counts['closureTotal']! as int, closures.length);
  final tables =
      jsonDecode(
            File(
              '${generated.path}/tool-selector-tables.json',
            ).readAsStringSync(),
          )
          as List<Object?>;
  final tableCounts = (counts['selectorTables']! as Map)
      .cast<String, Object?>();
  _expectCount('selector tables', tableCounts['total']! as int, tables.length);
  _expectCount(
    'pure selector tables',
    tableCounts['pure']! as int,
    tables.where((t) => (t! as Map)['pure'] == true).length,
  );
  _expectCount(
    'contract files',
    counts['contractFiles']! as int,
    _count(Directory('${generated.path}/contracts'), '.schema.json'),
  );
  _expectCount(
    'fixtures',
    counts['fixtures']! as int,
    _count(Directory('${generated.path}/fixtures'), '.json') - 1,
  );
  _expectCount(
    'fonts',
    counts['fonts']! as int,
    _count(Directory('${generated.path}/fonts'), '.woff2'),
  );

  final report = _json(File('${generated.path}/icons/report.json'));
  final vec = report['vec'];
  final vecFailures = vec is Map && vec['failures'] is Map
      ? (vec['failures']! as Map).keys.toSet()
      : <Object?>{};
  for (final set in icons.keys) {
    final dir = Directory('${generated.path}/icons/$set');
    if (!dir.existsSync()) continue;
    for (final svg in dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.svg'),
    )) {
      final name = svg.uri.pathSegments.last.replaceFirst(
        RegExp(r'\.svg$'),
        '',
      );
      final id = '$set/$name';
      if (!File('${generated.path}/icons_vec/$id.vec').existsSync() &&
          !vecFailures.contains(id)) {
        _fail(
          'icons_vec/$id.vec is missing and icons/report.json records no failure for it',
        );
      }
    }
  }

  final runA = await _runGenerator(appRoot, generated, 'a');
  final runB = await _runGenerator(appRoot, generated, 'b');
  _compareTrees(
    'generator determinism',
    Directory('${runA.path}/dart'),
    Directory('${runB.path}/dart'),
  );
  _compareTrees(
    'committed generated/dart vs fresh run',
    Directory('${generated.path}/dart'),
    Directory('${runA.path}/dart'),
  );
  runA.deleteSync(recursive: true);
  runB.deleteSync(recursive: true);

  if (_failures.isNotEmpty) {
    stderr.writeln('check_generated: ${_failures.length} problem(s)');
    for (final failure in _failures) {
      stderr.writeln('  - $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'check_generated: ok (commit $expectedCommit, ${counts['blocks']} blocks, '
    '${counts['tools']} tools, ${counts['triggers']} triggers)',
  );
}
