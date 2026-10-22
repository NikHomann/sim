import 'dart:convert';

/// A decoded JSON object as produced by `dart:convert`.
typedef JsonMap = Map<String, Object?>;

/// Thrown when a wire payload does not have the shape the protocol requires.
///
/// Mirrors a zod parse failure on the server side: the payload is kept so a
/// caller can log or inspect what arrived.
class ProtocolFormatException implements Exception {
  /// Creates a format exception for [path] on [payload].
  const ProtocolFormatException(this.message, {this.path, this.payload});

  /// Human readable description of the violation.
  final String message;

  /// Dotted path of the offending key, when known.
  final String? path;

  /// The payload that failed validation.
  final Object? payload;

  @override
  String toString() =>
      'ProtocolFormatException(${path == null ? '' : '$path: '}$message)';
}

/// Coerces [value] into a [JsonMap] or throws [ProtocolFormatException].
JsonMap asJsonMap(Object? value, {String? path}) {
  if (value is JsonMap) return value;
  if (value is Map) {
    return value.map((key, dynamic v) => MapEntry(key.toString(), v));
  }
  throw ProtocolFormatException('expected object', path: path, payload: value);
}

/// Reads a required string at [key].
String readString(JsonMap map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw ProtocolFormatException('expected string', path: key, payload: map);
}

/// Reads an optional string at [key]; `null` and absence both yield `null`.
String? readOptionalString(JsonMap map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is String) return value;
  throw ProtocolFormatException('expected string', path: key, payload: map);
}

/// Reads a required number at [key].
num readNum(JsonMap map, String key) {
  final value = map[key];
  if (value is num) return value;
  throw ProtocolFormatException('expected number', path: key, payload: map);
}

/// Reads an optional number at [key].
num? readOptionalNum(JsonMap map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is num) return value;
  throw ProtocolFormatException('expected number', path: key, payload: map);
}

/// Reads a required integer-valued number at [key] (JSON has no int type).
int readInt(JsonMap map, String key) {
  final value = readNum(map, key);
  if (value is int) return value;
  if (value == value.truncateToDouble()) return value.toInt();
  throw ProtocolFormatException('expected integer', path: key, payload: map);
}

/// Reads a required boolean at [key].
bool readBool(JsonMap map, String key) {
  final value = map[key];
  if (value is bool) return value;
  throw ProtocolFormatException('expected boolean', path: key, payload: map);
}

/// Reads an optional boolean at [key].
bool? readOptionalBool(JsonMap map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw ProtocolFormatException('expected boolean', path: key, payload: map);
}

/// Reads a required object at [key].
JsonMap readMap(JsonMap map, String key) {
  final value = map[key];
  if (value == null) {
    throw ProtocolFormatException('expected object', path: key, payload: map);
  }
  return asJsonMap(value, path: key);
}

/// Reads an optional object at [key].
JsonMap? readOptionalMap(JsonMap map, String key) {
  final value = map[key];
  if (value == null) return null;
  return asJsonMap(value, path: key);
}

/// Reads a required list at [key].
List<Object?> readList(JsonMap map, String key) {
  final value = map[key];
  if (value is List) return value;
  throw ProtocolFormatException('expected array', path: key, payload: map);
}

/// Reads an optional list at [key].
List<Object?>? readOptionalList(JsonMap map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is List) return value;
  throw ProtocolFormatException('expected array', path: key, payload: map);
}

/// Reads a required list of objects at [key].
List<JsonMap> readMapList(JsonMap map, String key) {
  final list = readList(map, key);
  return [
    for (var i = 0; i < list.length; i++) asJsonMap(list[i], path: '$key[$i]'),
  ];
}

/// Reads a required list of strings at [key].
List<String> readStringList(JsonMap map, String key) {
  final list = readList(map, key);
  return [
    for (var i = 0; i < list.length; i++)
      if (list[i] is String)
        list[i]! as String
      else
        throw ProtocolFormatException(
          'expected string',
          path: '$key[$i]',
          payload: map,
        ),
  ];
}

/// Structural JSON equality, as `JSON.stringify(a) === JSON.stringify(b)`
/// upstream: key order is significant, exactly like the TypeScript check in
/// `stores/operation-queue/store.ts`.
bool jsonContentEquals(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);
