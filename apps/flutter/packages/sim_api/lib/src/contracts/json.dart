/// Decoding helpers shared by the contract DTOs. Field reads mirror the zod
/// schemas in `apps/sim/lib/api/contracts/**`: a required field that is
/// missing or of the wrong type throws [ContractDecodeError] (the repository
/// turns it into `ApiClientError{status: 2xx}`), unknown fields are ignored.
library;

import 'package:meta/meta.dart';

/// A response body that does not match its contract schema.
class ContractDecodeError implements Exception {
  const ContractDecodeError(this.path, this.reason);

  /// Dotted path of the failing field, e.g. `workspaces.0.id`.
  final String path;
  final String reason;

  @override
  String toString() => '$path: $reason';
}

/// A JSON object with string keys.
typedef JsonObject = Map<String, Object?>;

/// Narrows [json] to a [JsonObject]; [path] names the value in errors.
JsonObject asJsonObject(Object? json, {String path = r'$'}) {
  if (json is Map) {
    return json.map((key, value) => MapEntry('$key', value));
  }
  throw ContractDecodeError(path, 'expected an object');
}

/// A list of objects at [path].
List<JsonObject> asJsonObjectList(Object? json, {String path = r'$'}) {
  if (json is! List) throw ContractDecodeError(path, 'expected an array');
  return [
    for (var i = 0; i < json.length; i++)
      asJsonObject(json[i], path: '$path.$i'),
  ];
}

/// Equality over a list of values, structural for nested lists and maps, so
/// DTOs compare by content (the "structurally equal" rule of
/// `seedDeploymentShape`).
bool deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!deepEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is Set && b is Set) {
    return a.length == b.length && a.every(b.contains);
  }
  return a == b;
}

int deepHash(Object? value) {
  if (value is List) return Object.hashAll(value.map(deepHash));
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map((e) => Object.hash(e.key, deepHash(e.value))),
    );
  }
  if (value is Set) return Object.hashAllUnordered(value.map(deepHash));
  return value.hashCode;
}

/// Base of every contract DTO: value equality over [props].
@immutable
abstract class ContractValue {
  const ContractValue();

  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          other is ContractValue &&
          deepEquals(props, other.props);

  @override
  int get hashCode => Object.hash(runtimeType, deepHash(props));

  @override
  String toString() => '$runtimeType(${toJson()})';

  Object? toJson();
}

/// Typed reads on a decoded object. Every accessor takes the wire field name.
extension JsonObjectReads on JsonObject {
  Never _fail(String key, String reason) =>
      throw ContractDecodeError(key, reason);

  bool has(String key) => containsKey(key) && this[key] != null;

  String string(String key) {
    final value = this[key];
    if (value is String) return value;
    _fail(key, 'expected a string');
  }

  String? stringOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return value;
    _fail(key, 'expected a string or null');
  }

  bool boolean(String key) {
    final value = this[key];
    if (value is bool) return value;
    _fail(key, 'expected a boolean');
  }

  bool? boolOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is bool) return value;
    _fail(key, 'expected a boolean or null');
  }

  /// A boolean that the schema defaults when absent.
  bool boolOr(String key, {required bool fallback}) =>
      boolOrNull(key) ?? fallback;

  num number(String key) {
    final value = this[key];
    if (value is num) return value;
    _fail(key, 'expected a number');
  }

  num? numOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is num) return value;
    _fail(key, 'expected a number or null');
  }

  int integer(String key) {
    final value = this[key];
    if (value is int) return value;
    if (value is double && value == value.truncateToDouble()) {
      return value.toInt();
    }
    _fail(key, 'expected an integer');
  }

  int? intOrNull(String key) => this[key] == null ? null : integer(key);

  List<Object?> list(String key) {
    final value = this[key];
    if (value is List) return value;
    _fail(key, 'expected an array');
  }

  List<Object?>? listOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is List) return value;
    _fail(key, 'expected an array or null');
  }

  List<String> stringList(String key) {
    final value = list(key);
    return [
      for (var i = 0; i < value.length; i++)
        if (value[i] is String)
          value[i]! as String
        else
          _fail('$key.$i', 'expected a string'),
    ];
  }

  List<String>? stringListOrNull(String key) =>
      this[key] == null ? null : stringList(key);

  List<JsonObject> objectList(String key) =>
      asJsonObjectList(this[key], path: key);

  JsonObject object(String key) => asJsonObject(this[key], path: key);

  JsonObject? objectOrNull(String key) =>
      this[key] == null ? null : object(key);

  /// A `date-time` string parsed, or an error when it does not parse.
  DateTime date(String key) {
    final value = string(key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) _fail(key, 'expected a date-time');
    return parsed;
  }

  DateTime? dateOrNull(String key) => this[key] == null ? null : date(key);

  /// An enum value by its wire name; unknown values fail like zod's `z.enum`.
  T enumValue<T extends Enum>(String key, List<T> values) {
    final raw = string(key);
    for (final value in values) {
      if (wireName(value) == raw) return value;
    }
    _fail(key, 'unexpected value "$raw"');
  }

  T? enumOrNull<T extends Enum>(String key, List<T> values) =>
      this[key] == null ? null : enumValue(key, values);
}

/// The wire name of an enum: [WireNamed.wireName] when the enum declares
/// one (kebab-case values), otherwise the Dart name.
String wireName(Enum value) =>
    value is WireNamed ? (value as WireNamed).wireName : value.name;

/// Enums whose wire spelling differs from their Dart name.
abstract interface class WireNamed {
  String get wireName;
}
