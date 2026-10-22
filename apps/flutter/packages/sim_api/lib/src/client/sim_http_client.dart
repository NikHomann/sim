import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:sim_api/src/client/api_client_error.dart';
import 'package:sim_api/src/client/client_id.dart';
import 'package:sim_api/src/client/cookie_storage.dart';
import 'package:sim_api/src/client/platform/cookies.dart' as cookies;
import 'package:sim_api/src/client/platform/origin.dart' as origin;
import 'package:sim_api/src/client/query_serialization.dart';
import 'package:sim_api/src/client/streaming/fetch_streaming.dart';

/// A decoded successful response.
class ApiResponse<T> {
  const ApiResponse({
    required this.status,
    required this.data,
    required this.headers,
    this.rateLimit,
    this.requestId,
  });

  final int status;
  final T data;

  /// Response headers, keys lower-cased.
  final Map<String, List<String>> headers;
  final RateLimitInfo? rateLimit;
  final String? requestId;

  String? header(String name) {
    final values = headers[name.toLowerCase()];
    return values == null || values.isEmpty ? null : values.first;
  }
}

/// A streaming response: headers now, body bytes as they arrive.
class ApiStreamResponse {
  const ApiStreamResponse({
    required this.status,
    required this.headers,
    required this.bytes,
  });

  final int status;
  final Map<String, List<String>> headers;
  final Stream<Uint8List> bytes;

  String? header(String name) {
    final values = headers[name.toLowerCase()];
    return values == null || values.isEmpty ? null : values.first;
  }
}

/// The Dio client of the Flutter port (plan §4.3).
///
/// Base URL is the page origin on web and the configured origin on desktop;
/// `withCredentials` on web; a persistent cookie jar on desktop; every request
/// carries `x-sim-client-id`; paths and queries follow the upstream
/// serialisation rules; non-2xx responses become [ApiClientError].
class SimHttpClient {
  /// Builds the client for [baseUrl]. [cookieStorage] enables the desktop
  /// cookie jar (ignored on web). [dio] and [streamingAdapter] are injection
  /// points for tests.
  SimHttpClient({
    required String baseUrl,
    Dio? dio,
    String? clientId,
    CookieStorage? cookieStorage,
    HttpClientAdapter? streamingAdapter,
    Logger? logger,
  }) : baseUrl = _stripTrailingSlash(baseUrl),
       clientId = clientId ?? generateShortId(),
       _cookieStorage = cookieStorage,
       _log = logger ?? Logger('sim_api.http') {
    _dio = dio ?? Dio();
    _dio.options
      ..baseUrl = this.baseUrl
      ..responseType = ResponseType.plain
      ..headers[clientIdHeader] = this.clientId
      ..extra['withCredentials'] = true
      ..validateStatus = _isSuccess
      ..receiveDataWhenStatusError = true;
    if (cookieStorage != null) {
      final jar = _cookieJar = cookies.createCookieJar(cookieStorage);
      if (jar != null) _dio.interceptors.add(jar.interceptor);
      // Better Auth rejects a POST that carries a session cookie but no
      // Origin header (`MISSING_OR_NULL_ORIGIN`, spike d). Browsers send it
      // automatically; the desktop client sends its own, trusted origin.
      _dio.options.headers['origin'] = this.baseUrl;
    }
    final streaming = streamingAdapter ?? createFetchStreamAdapter();
    if (streaming != null) {
      _dio.httpClientAdapter = FetchStreamingRouter(
        fallback: _dio.httpClientAdapter,
        streaming: streaming,
      );
    }
  }

  /// The client for the running platform: page origin on web, [desktopOrigin]
  /// with a secure cookie jar on desktop.
  factory SimHttpClient.forPlatform({
    String? desktopOrigin,
    CookieStorage? cookieStorage,
    Logger? logger,
  }) {
    final pageOrigin = origin.resolvePageOrigin();
    if (pageOrigin != null) {
      return SimHttpClient(baseUrl: pageOrigin, logger: logger);
    }
    if (desktopOrigin == null) {
      throw ArgumentError.notNull('desktopOrigin');
    }
    return SimHttpClient(
      baseUrl: desktopOrigin,
      cookieStorage: cookieStorage ?? SecureCookieStorage(),
      logger: logger,
    );
  }

  final String baseUrl;
  final String clientId;
  final CookieStorage? _cookieStorage;
  cookies.CookieJarHandle? _cookieJar;
  final Logger _log;
  late final Dio _dio;

  /// The underlying Dio, for interceptors the app adds (logging, session
  /// expiry) and for tests.
  Dio get dio => _dio;

  static bool _isSuccess(int? status) =>
      status != null && status >= 200 && status < 300;

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// The request path for [path] with [params] filled and [query] appended,
  /// relative to [baseUrl].
  String resolvePath(
    String path, {
    Map<String, Object?>? params,
    Map<String, Object?>? query,
  }) => appendQuery(replacePathParams(path, params), query);

  /// The absolute URL of a request, for anchor downloads and the browser.
  String resolveUrl(
    String path, {
    Map<String, Object?>? params,
    Map<String, Object?>? query,
  }) => '$baseUrl${resolvePath(path, params: params, query: query)}';

  /// Sends a JSON request and decodes the body (JSON, else raw text, else
  /// `null` when empty). Throws [ApiClientError] for non-2xx responses,
  /// [ApiNetworkError] when no response arrived and [ApiCancelledError] on
  /// cancellation.
  Future<ApiResponse<Object?>> send({
    required String method,
    required String path,
    Map<String, Object?>? params,
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    final requestPath = resolvePath(path, params: params, query: query);
    final hasBody = body != null && method.toUpperCase() != 'GET';
    final options = Options(
      method: method.toUpperCase(),
      headers: {
        if (hasBody) Headers.contentTypeHeader: 'application/json',
        ...?headers,
      },
      receiveTimeout: timeout,
      sendTimeout: timeout,
    );
    try {
      final response = await _dio.request<String>(
        requestPath,
        data: hasBody ? jsonEncode(body) : null,
        options: options,
        cancelToken: cancelToken,
      );
      final headersMap = response.headers.map;
      return ApiResponse(
        status: response.statusCode ?? 0,
        data: decodeBody(response.data),
        headers: headersMap,
        rateLimit: RateLimitInfo.fromHeaders(headersMap),
        requestId: _firstHeader(headersMap, 'x-request-id'),
      );
    } on DioException catch (error) {
      throw await mapDioException(error);
    }
  }

  /// [send] followed by [decode] on the JSON body.
  Future<T> requestJson<T>({
    required String method,
    required String path,
    required T Function(Object? json) decode,
    Map<String, Object?>? params,
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    final response = await send(
      method: method,
      path: path,
      params: params,
      query: query,
      body: body,
      headers: headers,
      cancelToken: cancelToken,
      timeout: timeout,
    );
    return decode(response.data);
  }

  /// Opens a streaming request (SSE, chunked CSV). The future completes once
  /// the status and headers are in; the body arrives on
  /// [ApiStreamResponse.bytes]. A non-2xx status reads the whole body and
  /// throws [ApiClientError].
  Future<ApiStreamResponse> stream({
    required String method,
    required String path,
    Map<String, Object?>? params,
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    final requestPath = resolvePath(path, params: params, query: query);
    final hasBody = body != null && method.toUpperCase() != 'GET';
    final options = Options(
      method: method.toUpperCase(),
      responseType: ResponseType.stream,
      headers: {
        if (hasBody) Headers.contentTypeHeader: 'application/json',
        ...?headers,
      },
      extra: {streamViaFetch: true},
      validateStatus: (_) => true,
    );
    final Response<ResponseBody> response;
    try {
      response = await _dio.request<ResponseBody>(
        requestPath,
        data: hasBody ? jsonEncode(body) : null,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      throw await mapDioException(error);
    }
    final status = response.statusCode ?? 0;
    final headersMap = response.headers.map;
    final responseBody = response.data;
    if (!_isSuccess(status)) {
      final raw = responseBody == null
          ? ''
          : await _collectText(responseBody.stream);
      throw ApiClientError.fromResponse(
        status: status,
        body: decodeBody(raw),
        rawBody: raw,
        headers: headersMap,
      );
    }
    final bytes = responseBody?.stream ?? const Stream<Uint8List>.empty();
    return ApiStreamResponse(
      status: status,
      headers: headersMap,
      bytes: bytes.transform(_StreamErrors.transformer),
    );
  }

  /// Forgets the desktop cookies (sign-out, store reset). No-op on web.
  Future<void> clearCookies() async {
    await _cookieJar?.clear();
    await _cookieStorage?.deleteAll();
  }

  void close({bool force = false}) => _dio.close(force: force);

  /// Decodes a response body the way `readResponseBody` does upstream: JSON
  /// when it parses, the raw text otherwise, `null` when empty.
  static Object? decodeBody(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  /// Maps a [DioException] to the package's error types.
  Future<Exception> mapDioException(DioException error) async {
    if (error.type == DioExceptionType.cancel) {
      return ApiCancelledError(error.error);
    }
    if (error.type == DioExceptionType.badResponse) {
      final response = error.response;
      final status = response?.statusCode ?? 0;
      final data = response?.data;
      final String raw;
      if (data is ResponseBody) {
        raw = await _collectText(data.stream);
      } else if (data is String) {
        raw = data;
      } else if (data == null) {
        raw = '';
      } else {
        raw = jsonEncode(data);
      }
      final mapped = ApiClientError.fromResponse(
        status: status,
        body: decodeBody(raw),
        rawBody: raw,
        headers: response?.headers.map ?? const {},
      );
      _log.fine(
        '${error.requestOptions.method} ${error.requestOptions.path} -> $mapped',
      );
      return mapped;
    }
    _log.fine(
      '${error.requestOptions.method} ${error.requestOptions.path} failed: ${error.message}',
    );
    return ApiNetworkError(
      error.message ?? error.type.name,
      cause: error.error ?? error,
    );
  }

  static Future<String> _collectText(Stream<Uint8List> stream) async {
    final builder = BytesBuilder(copy: false);
    try {
      await stream.forEach(builder.add);
    } on Object {
      // A body that cannot be read leaves the status as the only signal.
    }
    return utf8.decode(builder.takeBytes(), allowMalformed: true);
  }

  static String? _firstHeader(Map<String, List<String>> headers, String name) {
    final values = headers[name];
    return values == null || values.isEmpty ? null : values.first;
  }
}

/// Error mapping of a streamed body: a cancellation through the token ends
/// the stream quietly (the consumer asked for it); anything else is a
/// transport failure surfaced as [ApiNetworkError].
class _StreamErrors {
  static final transformer =
      StreamTransformer<Uint8List, Uint8List>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          if (error is ApiCancelledError ||
              (error is DioException &&
                  error.type == DioExceptionType.cancel)) {
            sink.close();
            return;
          }
          sink.addError(
            ApiNetworkError('stream interrupted', cause: error),
            stackTrace,
          );
        },
      );
}
