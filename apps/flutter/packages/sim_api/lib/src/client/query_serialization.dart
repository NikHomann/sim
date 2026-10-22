/// Path and query serialisation rules of `apps/sim/lib/api/client/request.ts`.
///
/// Path params fill `[id]`, `[...rest]` and `[[...optional]]` segments; query
/// values follow `appendQuery`: empty values are skipped, scalar lists repeat
/// the key, lists containing objects and plain objects are sent as one JSON
/// string, everything else is stringified. Encoding matches `URLSearchParams`
/// so the proxy request log compares equal between the React and Flutter apps.
library;

import 'dart:convert';

final _pathParam = RegExp(r'\[\[?(\.\.\.)?([^\]\[]+)\]\]?');

/// Fills the bracket params of a Next-style route [path] from [params].
///
/// Throws [MissingRouteParamError] when a required param is absent.
String replacePathParams(String path, Map<String, Object?>? params) {
  if (params == null) return path;
  return path.replaceAllMapped(_pathParam, (match) {
    final rest = match.group(1) != null;
    final key = match.group(2)!;
    final isOptionalCatchAll = match.group(0)!.startsWith('[[...');
    final value = params[key];

    if (rest && value is List) {
      return value.map((item) => Uri.encodeComponent('$item')).join('/');
    }
    if (value == null && isOptionalCatchAll) return '';
    if (value is! String && value is! num && value is! bool) {
      throw MissingRouteParamError(key);
    }
    return Uri.encodeComponent('$value');
  });
}

/// Appends [query] to [path] following the upstream rules.
String appendQuery(String path, Map<String, Object?>? query) {
  if (query == null || query.isEmpty) return path;
  final parts = <String>[];
  void add(String key, String value) {
    parts.add('${encodeFormComponent(key)}=${encodeFormComponent(value)}');
  }

  for (final entry in query.entries) {
    final value = entry.value;
    if (value == null || value == '') continue;
    if (value is List) {
      if (value.any((item) => item is Map || item is List)) {
        add(entry.key, jsonEncode(value));
        continue;
      }
      for (final item in value) {
        if (item == null || item == '') continue;
        add(entry.key, '$item');
      }
      continue;
    }
    if (value is Map) {
      add(entry.key, jsonEncode(value));
      continue;
    }
    add(entry.key, '$value');
  }
  if (parts.isEmpty) return path;
  final joined = parts.join('&');
  return '$path${path.contains('?') ? '&' : '?'}$joined';
}

/// `application/x-www-form-urlencoded` component encoding as `URLSearchParams`
/// does it: `*-._` and alphanumerics stay, space becomes `+`, everything else
/// is percent-encoded as UTF-8.
String encodeFormComponent(String value) {
  final buffer = StringBuffer();
  for (final byte in utf8.encode(value)) {
    final isAlnum =
        (byte >= 0x30 && byte <= 0x39) ||
        (byte >= 0x41 && byte <= 0x5a) ||
        (byte >= 0x61 && byte <= 0x7a);
    if (isAlnum ||
        byte == 0x2a ||
        byte == 0x2d ||
        byte == 0x2e ||
        byte == 0x5f) {
      buffer.writeCharCode(byte);
    } else if (byte == 0x20) {
      buffer.write('+');
    } else {
      buffer
        ..write('%')
        ..write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
    }
  }
  return buffer.toString();
}

/// A bracket param of the route path that [replacePathParams] could not fill.
class MissingRouteParamError implements Exception {
  const MissingRouteParamError(this.key);

  final String key;

  @override
  String toString() => 'Missing route param "$key"';
}
