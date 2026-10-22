import 'package:sim_api/sim_api.dart';

/// The JSON reads and writes the Home surface issues outside the Phase 1
/// cubits (credit availability, suggested-action signals, the add-resource
/// inventory, the access policy, mark-read). One seam so tests can answer
/// every request and assert which ones fired.
abstract class HomeHttp {
  /// `GET` [path] with [query]; returns the decoded JSON body. Throws
  /// [ApiClientError] / [ApiNetworkError] like [SimHttpClient.send].
  Future<Object?> get(String path, {Map<String, Object?>? query});

  /// `POST` [path] with a JSON [body].
  Future<Object?> post(String path, {Object? body});
}

/// [HomeHttp] over the app's [SimHttpClient].
class SimHomeHttp implements HomeHttp {
  SimHomeHttp(this._client);

  final SimHttpClient _client;

  @override
  Future<Object?> get(String path, {Map<String, Object?>? query}) async =>
      (await _client.send(method: 'GET', path: path, query: query)).data;

  @override
  Future<Object?> post(String path, {Object? body}) async =>
      (await _client.send(method: 'POST', path: path, body: body)).data;
}

/// Reads `json[key]` as a list of maps (missing or malformed: empty).
List<Map<String, Object?>> jsonList(Object? json, [String? key]) {
  final value = key == null ? json : (json is Map ? json[key] : null);
  if (value is! List) return const <Map<String, Object?>>[];
  return <Map<String, Object?>>[
    for (final item in value)
      if (item is Map) item.cast<String, Object?>(),
  ];
}

/// `json[key]` as a string, else null.
String? jsonString(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}
