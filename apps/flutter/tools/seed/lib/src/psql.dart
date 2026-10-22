import 'dart:convert';
import 'dart:io';

class PsqlResult {
  PsqlResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
  final int exitCode;
  final String stdout;
  final String stderr;
  bool get ok => exitCode == 0;
}

/// How to reach `psql` inside the stack's `db` container.
///
/// Default: `docker compose -p <project> exec -T db psql ...` (the project
/// name is enough; Compose resolves the container from its labels). Postgres
/// is not published to the host, so this is the only route. `container` swaps
/// that for `docker exec -i <container>` when Compose is unavailable.
class PsqlTarget {
  const PsqlTarget({
    required this.database,
    this.composeProject = 'upstream',
    this.composeFiles = const [],
    this.projectDirectory,
    this.container,
    this.user = 'postgres',
  });

  final String database;
  final String composeProject;
  final List<String> composeFiles;
  final String? projectDirectory;
  final String? container;
  final String user;

  List<String> commandLine() {
    final psql = [
      'psql',
      '-U',
      user,
      '-d',
      database,
      '-v',
      'ON_ERROR_STOP=1',
      '-X',
      '-q',
    ];
    if (container != null) return ['exec', '-i', container!, ...psql];
    return [
      'compose',
      '-p',
      composeProject,
      if (projectDirectory != null) ...[
        '--project-directory',
        projectDirectory!,
      ],
      for (final f in composeFiles) ...['-f', f],
      'exec',
      '-T',
      'db',
      ...psql,
    ];
  }
}

/// Pipes [sql] into psql and returns its output. `ON_ERROR_STOP=1` makes a
/// failing statement exit non-zero inside the open transaction, which the
/// disconnect then rolls back.
Future<PsqlResult> runPsql(
  PsqlTarget target,
  String sql, {
  String docker = 'docker',
}) async {
  final process = await Process.start(docker, target.commandLine());
  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();
  process.stdin.write(sql);
  if (!sql.endsWith('\n')) process.stdin.writeln();
  await process.stdin.flush();
  await process.stdin.close();
  final exitCode = await process.exitCode;
  return PsqlResult(
    exitCode: exitCode,
    stdout: await stdoutFuture,
    stderr: await stderrFuture,
  );
}
