/// Turns decoded JSON into Dart const literal source.
///
/// Markers written by the extraction script (`{"$fn": id}`, `{"$icon": id}`,
/// `{"$regex": source, "flags": f}`) become `FnRef`, `IconRef` and `RegexRef`
/// constructor calls so consumers can switch on them instead of sniffing keys.
library;

/// Escapes [value] into a single-quoted Dart string literal.
String dartString(String value) {
  final buffer = StringBuffer("'");
  for (final rune in value.runes) {
    switch (rune) {
      case 0x27: // '
        buffer.write(r"\'");
      case 0x5c: // \
        buffer.write(r'\\');
      case 0x24: // $
        buffer.write(r'\$');
      case 0x0a:
        buffer.write(r'\n');
      case 0x0d:
        buffer.write(r'\r');
      case 0x09:
        buffer.write(r'\t');
      default:
        if (rune < 0x20 || rune == 0x7f || (rune >= 0x2028 && rune <= 0x2029)) {
          buffer.write('\\u{${rune.toRadixString(16)}}');
        } else {
          buffer.writeCharCode(rune);
        }
    }
  }
  buffer.write("'");
  return buffer.toString();
}

String _number(num value) {
  if (value is int) return value.toString();
  if (value.isNaN || value.isInfinite) return 'null';
  final text = value.toString();
  return text.contains('.') || text.contains('e') ? text : '$text.0';
}

/// Emits [value] as a Dart literal valid in a const context.
///
/// Maps become `<String, Object?>{...}`, lists `<Object?>[...]` unless every
/// element is a string (then `<String>[...]`), and marker objects become the
/// `FnRef` / `IconRef` / `RegexRef` const constructors from `markers.g.dart`.
String dartLiteral(Object? value, {String indent = ''}) {
  if (value == null) return 'null';
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return _number(value);
  if (value is String) return dartString(value);
  if (value is List) {
    if (value.isEmpty) return '<Object?>[]';
    final allStrings = value.every((item) => item is String);
    final type = allStrings ? 'String' : 'Object?';
    final inner = '$indent  ';
    final items = value
        .map((item) => '$inner${dartLiteral(item, indent: inner)},')
        .join('\n');
    return '<$type>[\n$items\n$indent]';
  }
  if (value is Map) {
    final marker = markerLiteral(value);
    if (marker != null) return marker;
    if (value.isEmpty) return '<String, Object?>{}';
    final inner = '$indent  ';
    final entries = value.entries
        .map(
          (entry) =>
              '$inner${dartString(entry.key.toString())}: ${dartLiteral(entry.value, indent: inner)},',
        )
        .join('\n');
    return '<String, Object?>{\n$entries\n$indent}';
  }
  throw ArgumentError('Unsupported JSON value: ${value.runtimeType}');
}

/// Emits a `List<String>` literal (typed even when empty, unlike [dartLiteral]).
String dartStringList(Iterable<Object?> values, {String indent = ''}) {
  final items = values.map((v) => v.toString()).toList();
  if (items.isEmpty) return '<String>[]';
  final inner = '$indent  ';
  return '<String>[\n${items.map((v) => '$inner${dartString(v)},').join('\n')}\n$indent]';
}

/// A marker constructor call for the extraction script's function markers, or
/// null when [map] is an ordinary object.
String? markerLiteral(Map<Object?, Object?> map) {
  if (map.length == 1 && map[r'$fn'] is String) {
    return 'FnRef(${dartString(map[r'$fn']! as String)})';
  }
  if (map.length == 1 && map.containsKey(r'$const')) {
    // A function that read no params and returned plain data; inline the data.
    return dartLiteral(map[r'$const']);
  }
  if (map.length == 1 && map[r'$icon'] is String) {
    return 'IconRef(${dartString(map[r'$icon']! as String)})';
  }
  if (map.length == 2 && map[r'$regex'] is String && map['flags'] is String) {
    return 'RegexRef(${dartString(map[r'$regex']! as String)}, '
        '${dartString(map['flags']! as String)})';
  }
  return null;
}

/// Whether [value] is a `{"$fn": ...}` marker.
bool isFnMarker(Object? value) =>
    value is Map && value.length == 1 && value[r'$fn'] is String;

/// Converts a kebab-case or snake_case name into a lowerCamelCase identifier.
String camelIdentifier(String name) {
  final parts = name
      .split(RegExp('[^A-Za-z0-9]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'unnamed';
  final buffer = StringBuffer();
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    if (i == 0) {
      buffer.write(part[0].toLowerCase() + part.substring(1));
    } else {
      buffer.write(part[0].toUpperCase() + part.substring(1));
    }
  }
  var id = buffer.toString();
  if (RegExp('^[0-9]').hasMatch(id)) id = 'i$id';
  if (_reserved.contains(id)) id = '${id}Icon';
  return id;
}

const _reserved = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'type',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// Standard header for every generated file.
String generatedHeader(String commit, String source) =>
    '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: apps/flutter/generated/$source (upstream commit $commit)
// Regenerate: dart run tools/gen/main.dart (from apps/flutter)
// ignore_for_file: type=lint

''';
