/// JSON reading helpers shared by the model classes.
///
/// Every reader throws a [FormatException] whose message names the offending
/// path (`blocks.agent-1.position.x`) so a malformed payload fails loudly at
/// the boundary instead of surfacing as a null dereference deep in the editor.
library;

import 'package:collection/collection.dart';

const deepEquality = DeepCollectionEquality();

/// Wraps a JSON object and the path it was found at.
class JsonReader {
  JsonReader(this.map, [this.path = '']);

  final Map<String, Object?> map;
  final String path;

  String _at(String key) => path.isEmpty ? key : '$path.$key';

  FormatException _error(String key, String expected, Object? value) =>
      FormatException(
        'Expected $expected at ${_at(key)}, got ${value.runtimeType}',
      );

  bool has(String key) => map.containsKey(key);

  /// Required string.
  String string(String key) {
    final value = map[key];
    if (value is String) return value;
    throw _error(key, 'string', value);
  }

  String? optionalString(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is String) return value;
    throw _error(key, 'string', value);
  }

  bool boolean(String key) {
    final value = map[key];
    if (value is bool) return value;
    throw _error(key, 'bool', value);
  }

  bool? optionalBool(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is bool) return value;
    throw _error(key, 'bool', value);
  }

  double number(String key) {
    final value = map[key];
    if (value is num) return value.toDouble();
    throw _error(key, 'number', value);
  }

  double? optionalNumber(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    throw _error(key, 'number', value);
  }

  int? optionalInt(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is double && value == value.truncateToDouble()) {
      return value.toInt();
    }
    throw _error(key, 'integer', value);
  }

  Map<String, Object?> object(String key) {
    final value = map[key];
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    throw _error(key, 'object', value);
  }

  Map<String, Object?>? optionalObject(String key) {
    final value = map[key];
    if (value == null) return null;
    return object(key);
  }

  List<Object?> list(String key) {
    final value = map[key];
    if (value is List<Object?>) return value;
    if (value is List) return value.cast<Object?>();
    throw _error(key, 'array', value);
  }

  List<Object?>? optionalList(String key) {
    final value = map[key];
    if (value == null) return null;
    return list(key);
  }

  List<String> stringList(String key) {
    final value = list(key);
    return [
      for (var i = 0; i < value.length; i++)
        value[i] is String
            ? value[i]! as String
            : throw FormatException(
                'Expected string at ${_at(key)}[$i], got ${value[i].runtimeType}',
              ),
    ];
  }

  JsonReader child(String key) => JsonReader(object(key), _at(key));

  JsonReader? optionalChild(String key) {
    final value = optionalObject(key);
    return value == null ? null : JsonReader(value, _at(key));
  }

  /// Every key not in [known], kept so a round trip does not drop upstream
  /// fields this port does not model yet.
  Map<String, Object?> extra(Set<String> known) => {
    for (final entry in map.entries)
      if (!known.contains(entry.key)) entry.key: entry.value,
  };
}

/// Encodes a double as a JSON integer when it is integral, matching the way
/// JavaScript serialises `100` (never `100.0`).
Object jsonNumber(double value) =>
    value.isFinite && value == value.truncateToDouble() ? value.toInt() : value;

/// Inserts [value] under [key] only when it is non-null, mirroring the way
/// `JSON.stringify` omits `undefined` properties.
void putIfNotNull(Map<String, Object?> json, String key, Object? value) {
  if (value != null) json[key] = value;
}

/// A deep, read-only copy of a JSON value so model instances cannot be
/// mutated through a retained reference to their input.
Object? freezeJson(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: freezeJson(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(freezeJson));
  }
  return value;
}

Map<String, Object?> freezeMap(Map<String, Object?> value) =>
    freezeJson(value)! as Map<String, Object?>;
