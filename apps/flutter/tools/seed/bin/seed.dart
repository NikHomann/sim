// Seeds the Flutter port's e2e stack with deterministic test data and mints a
// Better Auth session cookie (docs/port/04-test-plan.md section 2).
//
//   dart run tools/seed/bin/seed.dart --out seed.json      # reset + insert, write seed.json
//   dart run tools/seed/bin/seed.dart --reset              # delete only the seeded rows
//   dart run tools/seed/bin/seed.dart --expire-session     # session-expired e2e
//   dart run tools/seed/bin/seed.dart --renew-session
//   dart run tools/seed/bin/seed.dart --dry-run --sql-out seed.sql   # print SQL, touch nothing
//
// SQL runs through `docker compose -p <project> exec -T db psql -U postgres <db> -v ON_ERROR_STOP=1`
// (Postgres is not published to the host). Guards from the reference e2e
// scripts: loopback base URL, database name with a `test` segment, secret of
// at least 32 characters. `--allow-non-test-db` exists for one-off validation
// against the plain `simstudio` database and prints a warning.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:sim_seed/src/config.dart';
import 'package:sim_seed/src/encryption.dart';
import 'package:sim_seed/src/fixtures.dart';
import 'package:sim_seed/src/psql.dart';

ArgParser buildParser() => ArgParser()
  ..addOption(
    'out',
    defaultsTo: 'seed.json',
    help: 'Where to write the seed report.',
  )
  ..addOption(
    'base-url',
    help: 'Proxy origin the suites use (loopback http).',
    defaultsTo: defaultBaseUrl,
  )
  ..addOption('app-url', help: 'Next app origin.', defaultsTo: defaultAppUrl)
  ..addOption(
    'socket-url',
    help: 'Realtime origin.',
    defaultsTo: defaultSocketUrl,
  )
  ..addOption(
    'mailpit-url',
    help: 'Mailpit HTTP origin.',
    defaultsTo: defaultMailpitUrl,
  )
  ..addOption(
    'db',
    help:
        'Database name (default: POSTGRES_DB / SIM_TEST_DB / .env / $defaultDatabase).',
  )
  ..addOption(
    'project',
    help:
        'Compose project name (default: SIM_SEED_COMPOSE_PROJECT / $defaultComposeProject).',
  )
  ..addMultiOption(
    'compose-file',
    help: 'Compose file(s) to pass with -f (optional).',
  )
  ..addOption('project-dir', help: 'Compose --project-directory (optional).')
  ..addOption(
    'db-container',
    help: 'Use `docker exec -i <container>` instead of compose exec.',
  )
  ..addOption(
    'auth-secret',
    help: 'BETTER_AUTH_SECRET (default: env / .env / base-compose default).',
  )
  ..addOption(
    'encryption-key',
    help:
        'ENCRYPTION_KEY, 64 hex chars (default: env / .env / overlay default).',
  )
  ..addOption('env-file', help: 'Path to the repo .env (default: <repo>/.env).')
  ..addOption(
    'repo-root',
    help: 'Repo root (default: detected from the script path).',
  )
  ..addFlag(
    'allow-non-test-db',
    negatable: false,
    help: 'Skip the test-database guard (prints a warning).',
  )
  ..addFlag('reset', negatable: false, help: 'Delete the seeded rows only.')
  ..addFlag(
    'expire-session',
    negatable: false,
    help: 'Set the seeded session expires_at = now().',
  )
  ..addFlag(
    'renew-session',
    negatable: false,
    help: 'Push the seeded session expiry 30 days out.',
  )
  ..addFlag(
    'dry-run',
    negatable: false,
    help: 'Do not run psql; print the SQL (or write --sql-out).',
  )
  ..addOption('sql-out', help: 'Also write the SQL script to this file.')
  ..addFlag('help', abbr: 'h', negatable: false);

Future<int> main(List<String> arguments) async {
  final parser = buildParser();
  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(parser.usage);
    return 64;
  }
  if (args.flag('help')) {
    stdout.writeln(parser.usage);
    return 0;
  }

  final repoRoot = args.option('repo-root') ?? detectRepoRoot();
  final dotEnv = readDotEnv(
    args.option('env-file') ?? p.join(repoRoot, '.env'),
  );
  final env = Platform.environment;

  final database = firstValue(
    [
      args.option('db'),
      env['SIM_TEST_DB'],
      env['POSTGRES_DB'],
      dotEnv['SIM_TEST_DB'],
      dotEnv['POSTGRES_DB'],
    ],
    defaultDatabase,
  );
  final project = firstValue(
    [
      args.option('project'),
      env['SIM_SEED_COMPOSE_PROJECT'],
      dotEnv['SIM_SEED_COMPOSE_PROJECT'],
    ],
    defaultComposeProject,
  );
  final authSecret = firstValue(
    [
      args.option('auth-secret'),
      env['BETTER_AUTH_SECRET'],
      dotEnv['BETTER_AUTH_SECRET'],
    ],
    defaultAuthSecret,
  );
  final encryptionKeyText = firstValue(
    [
      args.option('encryption-key'),
      env['ENCRYPTION_KEY'],
      dotEnv['ENCRYPTION_KEY'],
    ],
    defaultEncryptionKey,
  );
  final baseUrl = args.option('base-url')!;

  try {
    assertGuards(
      baseUrl: baseUrl,
      database: database,
      authSecret: authSecret,
      allowNonTestDatabase: args.flag('allow-non-test-db'),
    );
  } on GuardError catch (e) {
    stderr.writeln('guard failed: $e');
    return 2;
  }

  final encryptionKey = parseEncryptionKey(encryptionKeyText);
  if (encryptionKey == null) {
    stderr.writeln(
      'warning: ENCRYPTION_KEY is not 64 hex characters; environment variables are not seeded '
      '(the app could not decrypt them either).',
    );
  }

  final fixture = SeedFixture(
    authSecret: authSecret,
    encryptionKey: encryptionKey,
  );

  final modes = [
    if (args.flag('reset')) 'reset',
    if (args.flag('expire-session')) 'expire-session',
    if (args.flag('renew-session')) 'renew-session',
  ];
  if (modes.length > 1) {
    stderr.writeln('choose one of --reset, --expire-session, --renew-session');
    return 64;
  }
  final mode = modes.isEmpty ? 'seed' : modes.single;
  final sql = switch (mode) {
    'reset' => fixture.resetScript(),
    'expire-session' => fixture.expireSessionScript(),
    'renew-session' => fixture.renewSessionScript(),
    _ => fixture.seedScript(),
  };

  final sqlOut = args.option('sql-out');
  if (sqlOut != null) {
    File(sqlOut).writeAsStringSync(sql);
    stdout.writeln('sql written to $sqlOut');
  }

  if (args.flag('dry-run')) {
    if (sqlOut == null) stdout.writeln(sql);
    if (mode == 'seed') {
      _writeReport(args.option('out')!, fixture, args, database, project);
    }
    stdout.writeln(
      'dry run: nothing executed (mode $mode, ${sql.split('\n').length} lines)',
    );
    return 0;
  }

  final target = PsqlTarget(
    database: database,
    composeProject: project,
    composeFiles: args.multiOption('compose-file'),
    projectDirectory: args.option('project-dir'),
    container: args.option('db-container'),
  );
  stdout.writeln(
    '$mode → psql ($database via ${target.container ?? 'compose project $project'})',
  );
  final result = await runPsql(target, sql);
  if (!result.ok) {
    stderr.writeln('psql exited with ${result.exitCode}');
    if (result.stdout.trim().isNotEmpty) stderr.writeln(result.stdout.trim());
    if (result.stderr.trim().isNotEmpty) stderr.writeln(result.stderr.trim());
    return 1;
  }
  if (result.stderr.trim().isNotEmpty) stderr.writeln(result.stderr.trim());

  switch (mode) {
    case 'seed':
      final out = _writeReport(
        args.option('out')!,
        fixture,
        args,
        database,
        project,
      );
      stdout.writeln('seeded ${fixture.email} in $database; report: $out');
    case 'reset':
      stdout.writeln('seeded rows removed from $database');
    case 'expire-session':
      stdout.writeln('session ${fixture.sessionId} expired');
    case 'renew-session':
      stdout.writeln('session ${fixture.sessionId} renewed');
  }
  return 0;
}

String _writeReport(
  String out,
  SeedFixture fixture,
  ArgResults args,
  String database,
  String project,
) {
  final report = fixture.report(
    baseUrl: args.option('base-url')!,
    appUrl: args.option('app-url')!,
    socketUrl: args.option('socket-url')!,
    mailpitUrl: args.option('mailpit-url')!,
    database: database,
    composeProject: project,
  );
  final file = File(out)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
  return file.path;
}
