/// Emits `lib/features/home/hero/suggestion_catalog.g.dart` from
/// `generated/blocks.json` (`$meta.templates`),
/// `packages/deployment-config/src/integration-metadata.ts` and
/// `apps/sim/lib/oauth/oauth.ts`.
library;

// Codegen writes long runs of buffer.writeln calls; cascades would hide the
// line structure of the emitted source.
// ignore_for_file: cascade_invocations

import 'dart:convert';

/// Output path relative to `apps/flutter`.
const suggestionCatalogPath =
    'lib/features/home/hero/suggestion_catalog.g.dart';

final _jsonParse = RegExp(r"JSON\.parse\(\s*'(.*)'\s*\)", dotAll: true);

// One `OAUTH_PROVIDERS` service entry: `key: {\n name: '...',` followed by its
// `providerId`, without crossing into the next `key: {` entry.
final _service = RegExp(
  r"\n\s+('?[\w-]+'?):\s*\{\s*\n\s*name:\s*'([^']+)',\s*\n"
  r"(?:(?!\n\s+'?[\w-]+'?:\s*\{).)*?providerId:\s*'([^']+)'",
  dotAll: true,
);

final _version = RegExp(r'_v\d+$');

String _stripVersion(String type) => type.replaceFirst(_version, '');

/// Decodes the body of a single-quoted JS string literal.
String _decodeJsString(String body) {
  final out = StringBuffer();
  var i = 0;
  int hex(int start, int length) =>
      int.parse(body.substring(start, start + length), radix: 16);
  while (i < body.length) {
    final c = body[i];
    if (c != r'\') {
      out.write(c);
      i++;
      continue;
    }
    final e = body[i + 1];
    i += 2;
    switch (e) {
      case 'n':
        out.write('\n');
      case 'r':
        out.write('\r');
      case 't':
        out.write('\t');
      case 'b':
        out.write('\b');
      case 'f':
        out.write('\f');
      case 'v':
        out.write('\v');
      case '0':
        out.write('\x00');
      case 'x':
        out.writeCharCode(hex(i, 2));
        i += 2;
      case 'u':
        if (body[i] == '{') {
          final end = body.indexOf('}', i);
          out.writeCharCode(int.parse(body.substring(i + 1, end), radix: 16));
          i = end + 1;
        } else {
          out.writeCharCode(hex(i, 4));
          i += 4;
        }
      case '\r':
        if (i < body.length && body[i] == '\n') i++;
      case '\n':
        break;
      default:
        out.write(e);
    }
  }
  return out.toString();
}

/// Single-quoted Dart literal, escaping only what the catalog needs (matches
/// the original generator byte for byte; `\r` is dropped).
String _q(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n').replaceAll('\r', '')}'";

bool _truthy(Object? value) => switch (value) {
  null || false || 0 || '' => false,
  final List<Object?> l => l.isNotEmpty,
  final Map<Object?, Object?> m => m.isNotEmpty,
  _ => true,
};

/// Builds the catalog source. [log] receives a one-line summary.
String generateSuggestionCatalog({
  required Map<String, Object?> blocks,
  required String integrationMetadataTs,
  required String oauthTs,
  void Function(String)? log,
}) {
  final literal = _jsonParse.firstMatch(integrationMetadataTs);
  if (literal == null) {
    throw StateError("integration-metadata.ts: no JSON.parse('...') literal");
  }
  final integrations = (jsonDecode(_decodeJsString(literal.group(1)!)) as List)
      .cast<Map<String, Object?>>();

  final services = [
    for (final m in _service.allMatches(oauthTs))
      (
        key: m.group(1)!.replaceAll("'", ''),
        name: m.group(2)!,
        providerId: m.group(3)!,
      ),
  ];
  final serviceByKey = {for (final s in services) s.key: s};

  final intByType = <String, Map<String, Object?>>{};
  for (final i in integrations) {
    final type = i['type']! as String;
    intByType[type] = i;
    intByType[_stripVersion(type)] = i;
  }

  String? providerFor(Map<String, Object?> integration) {
    final serviceId = integration['oauthServiceId'];
    if (integration['authType'] != 'oauth' || !_truthy(serviceId)) return null;
    return serviceByKey[serviceId]?.providerId;
  }

  final b = StringBuffer();
  b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  b.writeln(
    r'// Source: generated/blocks.json (\$meta.templates), packages/deployment-config',
  );
  b.writeln(
    '// integration-metadata.ts and apps/sim/lib/oauth/oauth.ts at the upstream commit',
  );
  b.writeln(
    '// in docs/port/UPSTREAM_COMMIT. Regenerate with (from apps/flutter):',
  );
  b.writeln('//   dart run tools/gen/main.dart --catalog-only');
  b.writeln('// ignore_for_file: type=lint');
  b.writeln();
  b.writeln(
    "import 'package:sim_app/features/home/hero/suggestion_types.dart';",
  );
  b.writeln();
  b.writeln(
    '/// Every catalog template whose block is a public integration (`CANDIDATES`',
  );
  b.writeln('/// minus the table starters, `suggested-actions.tsx:89-114`).');
  b.writeln(
    'const List<SuggestionTemplate> suggestionTemplates = <SuggestionTemplate>[',
  );
  var templateCount = 0;
  for (final MapEntry(key: blockType, value: block) in blocks.entries) {
    final meta = _truthy((block! as Map)[r'$meta'])
        ? ((block as Map)[r'$meta'] as Map).cast<String, Object?>()
        : const <String, Object?>{};
    final templates = _truthy(meta['templates'])
        ? meta['templates']! as List<Object?>
        : const <Object?>[];
    final integration = intByType[blockType];
    if (integration == null) continue;
    final provider = providerFor(integration);
    for (var i = 0; i < templates.length; i++) {
      final t = (templates[i]! as Map).cast<String, Object?>();
      final iconField = t['icon'];
      final icon = iconField is Map ? iconField[r'$icon'] as String? : null;
      final modules = _truthy(t['modules'])
          ? (t['modules']! as List).cast<String>()
          : const <String>[];
      templateCount++;
      b.writeln('  SuggestionTemplate(');
      b.writeln('    id: ${_q('$blockType-$i')},');
      b.writeln('    blockType: ${_q(blockType)},');
      b.writeln('    label: ${_q(t['title']! as String)},');
      b.writeln('    prompt: ${_q(t['prompt']! as String)},');
      if (_truthy(icon)) b.writeln('    iconId: ${_q(icon!)},');
      b.writeln('    modules: <String>[${modules.map(_q).join(', ')}],');
      if (_truthy(t['featured'])) b.writeln('    featured: true,');
      if (t['category'] == 'popular') b.writeln('    popular: true,');
      if (_truthy(provider)) b.writeln('    providerId: ${_q(provider!)},');
      b.writeln('  ),');
    }
  }
  b.writeln('];');
  b.writeln();
  b.writeln('/// `OAUTH_PROVIDERS` services: (service key, name, providerId).');
  b.writeln(
    'const List<OAuthServiceEntry> oauthServiceCatalog = <OAuthServiceEntry>[',
  );
  for (final s in services) {
    b.writeln(
      '  OAuthServiceEntry(id: ${_q(s.key)}, name: ${_q(s.name)}, '
      'providerId: ${_q(s.providerId)}),',
    );
  }
  b.writeln('];');
  b.writeln();
  b.writeln('/// `SLUG_BY_LOWER_NAME` (`suggested-actions.tsx:31-33`).');
  b.writeln(
    'const Map<String, String> integrationSlugByLowerName = <String, String>{',
  );
  final seenNames = <String>{};
  for (final i in integrations) {
    final key = (i['name']! as String).toLowerCase();
    if (!seenNames.add(key)) continue;
    b.writeln('  ${_q(key)}: ${_q(i['slug']! as String)},');
  }
  b.writeln('};');
  b.writeln();
  b.writeln('/// `TYPE_BY_SLUG` (`suggested-actions.tsx:36-38`).');
  b.writeln(
    'const Map<String, String> integrationTypeBySlug = <String, String>{',
  );
  final seenSlugs = <String>{};
  for (final i in integrations) {
    final slug = i['slug']! as String;
    if (!seenSlugs.add(slug)) continue;
    b.writeln('  ${_q(slug)}: ${_q(_stripVersion(i['type']! as String))},');
  }
  b.writeln('};');
  log?.call(
    '$templateCount templates ${services.length} services '
    '${integrations.length} integrations',
  );
  return b.toString();
}
