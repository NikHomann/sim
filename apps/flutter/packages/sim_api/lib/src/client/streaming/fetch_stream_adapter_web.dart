import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

/// The browser's `fetch` as a Dio adapter.
HttpClientAdapter? createFetchStreamAdapter() => FetchStreamAdapter();

/// Dio adapter on the browser's `fetch` that hands the response body over
/// chunk by chunk as it arrives, unlike Dio's XHR adapter, which delivers it
/// only once the request has finished.
///
/// Ported from OttoFrontend `lib/infrastructure/api/web_streaming/`. Covers
/// what a streaming request needs: method, headers, a buffered request body,
/// cancellation through `AbortController` and cookies following
/// `withCredentials` like the XHR adapter. No progress callbacks and no
/// timeouts.
class FetchStreamAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final abort = web.AbortController();
    unawaited(cancelFuture?.then((_) => abort.abort()));

    final headers = web.Headers();
    options.headers.forEach((name, value) {
      if (value == null) return;
      headers.append(name, value is Iterable ? value.join(', ') : '$value');
    });
    final body = requestStream == null ? null : await _collect(requestStream);

    final web.Response response;
    try {
      response = await web.window
          .fetch(
            options.uri.toString().toJS,
            web.RequestInit(
              method: options.method,
              headers: headers,
              body: body?.toJS,
              credentials: options.extra['withCredentials'] == true
                  ? 'include'
                  : 'same-origin',
              redirect: options.followRedirects ? 'follow' : 'manual',
              signal: abort.signal,
            ),
          )
          .toDart;
    } catch (error) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'fetch failed',
        error: error,
      );
    }

    final responseHeaders = <String, List<String>>{};
    response.headers.forEach(
      ((JSString value, JSString name) {
        responseHeaders.putIfAbsent(name.toDart, () => []).add(value.toDart);
      }).toJS,
    );

    final stream = response.body;
    return ResponseBody(
      stream == null
          ? const Stream<Uint8List>.empty()
          : _read(web.ReadableStreamDefaultReader(stream), abort, options),
      response.status,
      statusMessage: response.statusText,
      isRedirect: response.redirected,
      headers: responseHeaders,
    );
  }

  /// The body as it arrives. Cancelling the subscription aborts the request
  /// at once, even while a read is pending (an `async*` generator would only
  /// stop at its next chunk). A connection lost mid-stream surfaces as a Dio
  /// connection error, like on native, so callers treat it as transient.
  Stream<Uint8List> _read(
    web.ReadableStreamDefaultReader reader,
    web.AbortController abort,
    RequestOptions options,
  ) {
    var cancelled = false;
    late final StreamController<Uint8List> controller;

    Future<void> pump() async {
      try {
        while (true) {
          final chunk = await reader.read().toDart;
          if (cancelled) return;
          if (chunk.done) break;
          final value = chunk.value;
          if (value != null) controller.add((value as JSUint8Array).toDart);
        }
      } on Object catch (error) {
        if (cancelled) return;
        controller.addError(
          DioException.connectionError(
            requestOptions: options,
            reason: 'reading the response failed',
            error: error,
          ),
        );
      }
      await controller.close();
    }

    controller = StreamController<Uint8List>(
      onListen: () => unawaited(pump()),
      onCancel: () {
        cancelled = true;
        abort.abort();
      },
    );
    return controller.stream;
  }

  Future<Uint8List> _collect(Stream<Uint8List> stream) async {
    final builder = BytesBuilder(copy: false);
    await stream.forEach(builder.add);
    return builder.takeBytes();
  }

  @override
  void close({bool force = false}) {}
}

extension on web.Headers {
  /// `Headers.forEach((value, name) => ...)`, missing from `package:web`.
  external void forEach(JSFunction callback);
}
