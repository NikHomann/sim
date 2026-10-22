import 'dart:typed_data';

import 'package:dio/dio.dart';

export 'fetch_stream_adapter_stub.dart'
    if (dart.library.js_interop) 'fetch_stream_adapter_web.dart';

/// [RequestOptions.extra] flag that routes a request through the browser's
/// `fetch` (see [FetchStreamingRouter]) so its response streams on web.
const streamViaFetch = 'sim.streamViaFetch';

/// Sends requests flagged with [streamViaFetch] through [streaming], every
/// other request through [fallback].
///
/// Dio's browser adapter (XHR) hands a response body over only once the whole
/// request has finished, so a `ResponseType.stream` request (every SSE
/// endpoint) would arrive in one piece on web. The `fetch` adapter delivers
/// it chunk by chunk. Opt-in per request, so uploads, downloads and every
/// other call keep the proven XHR path.
class FetchStreamingRouter implements HttpClientAdapter {
  FetchStreamingRouter({required this.fallback, required this.streaming});

  final HttpClientAdapter fallback;
  final HttpClientAdapter streaming;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => (options.extra[streamViaFetch] == true ? streaming : fallback).fetch(
    options,
    requestStream,
    cancelFuture,
  );

  @override
  void close({bool force = false}) {
    fallback.close(force: force);
    streaming.close(force: force);
  }
}
