import 'dart:io';

import 'package:path/path.dart' as p;

/// Base-compose defaults (docker-compose.local.yml) used when neither the
/// environment, the repo `.env`, nor the command line sets a value.
const defaultAuthSecret = 'dev-secret-at-least-32-characters-long';

/// The `ENCRYPTION_KEY` docker-compose.flutter.yml sets when `.env` has none.
const defaultEncryptionKey =
    '6c1e4d4b2f9a4c3e8d7b6a5f4e3d2c1b0a9f8e7d6c5b4a392817161514131211';

const defaultDatabase = 'simstudio_test';
const defaultComposeProject = 'upstream';
const defaultBaseUrl = 'http://localhost:3001';
const defaultAppUrl = 'http://localhost:3000';
const defaultSocketUrl = 'http://localhost:3002';
const defaultMailpitUrl = 'http://localhost:8025';

const loopbackHosts = {'localhost', '127.0.0.1', '[::1]', '::1'};

/// `test-mobile-e2e.ts`: the database name must carry a `test` segment.
final testDatabasePattern = RegExp(
  r'(?:^|[_-])test(?:[_-]|$)',
  caseSensitive: false,
);

class GuardError implements Exception {
  GuardError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The guards of `apps/sim/scripts/test-scim-e2e.ts:30-41` and
/// `test-mobile-e2e.ts:33-45`: loopback plain-HTTP origin without credentials
/// or path, a dedicated test database, a secret of at least 32 characters.
void assertGuards({
  required String baseUrl,
  required String database,
  required String authSecret,
  bool allowNonTestDatabase = false,
}) {
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || !uri.hasScheme) {
    throw GuardError('Base URL is not a URL: $baseUrl');
  }
  if (uri.scheme != 'http') {
    throw GuardError('The app must use local HTTP: $baseUrl');
  }
  if (!loopbackHosts.contains(uri.host)) {
    throw GuardError('The app must use a loopback host: ${uri.host}');
  }
  if (uri.userInfo.isNotEmpty) {
    throw GuardError('App URL must not contain credentials');
  }
  if (uri.path.isNotEmpty && uri.path != '/') {
    throw GuardError('App URL must be an origin without a path: ${uri.path}');
  }
  if (!testDatabasePattern.hasMatch(database)) {
    if (!allowNonTestDatabase) {
      throw GuardError(
        'Use a dedicated test database (name with a `test` segment, e.g. simstudio_test); '
        'got "$database". --allow-non-test-db overrides this for a one-off validation.',
      );
    }
    stderr.writeln(
      'warning: seeding non-test database "$database" (--allow-non-test-db)',
    );
  }
  if (authSecret.length < 32) {
    throw GuardError(
      'Use a local Better Auth secret of at least 32 characters',
    );
  }
}

/// Minimal `.env` reader (KEY=VALUE, `#` comments, optional single/double quotes).
Map<String, String> readDotEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final values = <String, String>{};
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[key] = value;
  }
  return values;
}

/// Repo root from the script location (`apps/flutter/tools/seed/bin/seed.dart`).
String detectRepoRoot() {
  final script = Platform.script.toFilePath();
  var dir = p.dirname(script);
  for (var i = 0; i < 8; i++) {
    if (File(p.join(dir, 'docker-compose.local.yml')).existsSync()) return dir;
    final parent = p.dirname(dir);
    if (parent == dir) break;
    dir = parent;
  }
  return Directory.current.path;
}

/// First non-empty value wins.
String firstValue(List<String?> candidates, String fallback) {
  for (final c in candidates) {
    if (c != null && c.trim().isNotEmpty) return c.trim();
  }
  return fallback;
}
