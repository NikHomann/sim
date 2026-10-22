import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One request the fake server saw.
class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final String body;

  Object? get json => body.isEmpty ? null : jsonDecode(body);
}

typedef FakeHandler = Future<void> Function(HttpRequest request, String body);

/// A `dart:io` HTTP server on a loopback port for client tests.
class FakeServer {
  FakeServer._(this._server);

  static Future<FakeServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeServer._(server);
    server.listen(fake._dispatch);
    return fake;
  }

  final HttpServer _server;
  final List<RecordedRequest> requests = [];
  FakeHandler? handler;

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> _dispatch(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final headers = <String, String>{};
    request.headers.forEach(
      (name, values) => headers[name] = values.join(', '),
    );
    requests.add(
      RecordedRequest(
        method: request.method,
        path: request.uri.path,
        query: request.uri.queryParameters,
        headers: headers,
        body: body,
      ),
    );
    final handle = handler;
    if (handle == null) {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }
    try {
      await handle(request, body);
    } on Object {
      // The client side asserts on what it saw; a broken socket is expected
      // in the interruption tests.
    }
  }

  /// Replies with [status] and a JSON [body].
  static Future<void> json(
    HttpRequest request,
    int status,
    Object? body, {
    Map<String, String> headers = const {},
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    headers.forEach(request.response.headers.set);
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  /// Starts an SSE response; chunks are written through the returned sink
  /// and flushed immediately.
  /// [cuttable] declares a content length the body never reaches, so that
  /// [SseWriter.cut] can drop the connection mid-body.
  static Future<SseWriter> sse(
    HttpRequest request, {
    Map<String, String> headers = const {},
    bool cuttable = false,
  }) async {
    final response = request.response
      ..statusCode = 200
      ..bufferOutput = false;
    if (cuttable) response.headers.contentLength = 1 << 30;
    response.headers
      ..set('content-type', 'text/event-stream')
      ..set('cache-control', 'no-cache');
    headers.forEach(response.headers.set);
    return SseWriter(response);
  }

  Future<void> close() => _server.close(force: true);
}

class SseWriter {
  SseWriter(this._response);

  final HttpResponse _response;

  Future<void> write(String text) async {
    _response.write(text);
    await _response.flush();
  }

  Future<void> data(Object? json) => write('data: ${jsonEncode(json)}\n\n');

  Future<void> close() => _response.close();

  /// Drops the connection without a clean end (simulated transport
  /// failure); needs `cuttable: true` on [FakeServer.sse].
  Future<void> cut() => _response.close().catchError((_) {});
}
