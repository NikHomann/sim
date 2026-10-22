import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:sim_api/src/client/api_client_error.dart';
import 'package:sim_api/src/client/retry.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/uploads/upload_models.dart';

const int _baseTimeoutMs = 2 * 60 * 1000;
const _timeoutPerMbMs = 1500;
const int _maxTimeoutMs = 10 * 60 * 1000;
const _partUrlBatchSize = 25;

/// Parts in flight at once (`PART_UPLOAD_CONCURRENCY`).
const partUploadConcurrency = 3;
const _maxRetries = 3;
const _retryMaxMs = 8000;

/// Header carrying the signed upload control token.
const uploadTokenHeader = 'upload-token';

/// The transfer timeout upstream derives from the file size.
Duration calculateUploadTimeout(int fileSize) {
  final sizeInMb = fileSize / (1024 * 1024);
  return Duration(
    milliseconds: min(
      _baseTimeoutMs + sizeInMb * _timeoutPerMbMs,
      _maxTimeoutMs,
    ).round(),
  );
}

/// A data-plane failure (port of `UploadSessionTransportError`).
class UploadSessionTransportError implements Exception {
  const UploadSessionTransportError(
    this.message, {
    this.status,
    this.retryAfter,
    this.transient = false,
  });

  final String message;
  final int? status;
  final Duration? retryAfter;

  /// Whether a retry may succeed (408, 429, 5xx, network).
  final bool transient;

  @override
  String toString() => 'UploadSessionTransportError($status: $message)';
}

/// The session's part layout does not match the file.
class UploadSessionMismatchError implements Exception {
  const UploadSessionMismatchError(this.message);

  final String message;

  @override
  String toString() => 'UploadSessionMismatchError: $message';
}

/// Result of one data-plane `PUT`.
class UploadPutResult {
  const UploadPutResult({required this.status, this.retryAfterHeader});

  final int status;
  final String? retryAfterHeader;

  bool get ok => status >= 200 && status < 300;
}

/// Moves bytes to a signed URL. Separate from [SimHttpClient] because the
/// URL may target cloud storage (no credentials, provider error bodies).
// ignore: one_member_abstracts
abstract class UploadTransport {
  Future<UploadPutResult> put({
    required String url,
    required Map<String, String> headers,
    required Uint8List bytes,
    required Duration timeout,
    CancelToken? cancelToken,
    void Function(int sent)? onProgress,
  });
}

/// [UploadTransport] on a plain Dio (no base URL, no cookie jar).
class DioUploadTransport implements UploadTransport {
  DioUploadTransport({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<UploadPutResult> put({
    required String url,
    required Map<String, String> headers,
    required Uint8List bytes,
    required Duration timeout,
    CancelToken? cancelToken,
    void Function(int sent)? onProgress,
  }) async {
    try {
      final response = await _dio.put<void>(
        url,
        data: Stream<List<int>>.value(bytes),
        cancelToken: cancelToken,
        onSendProgress: onProgress == null
            ? null
            : (sent, _) => onProgress(sent),
        options: Options(
          headers: {
            Headers.contentLengthHeader: bytes.length,
            ...headers,
          },
          validateStatus: (_) => true,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          responseType: ResponseType.plain,
        ),
      );
      return UploadPutResult(
        status: response.statusCode ?? 0,
        retryAfterHeader: response.headers.value('retry-after'),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        throw ApiCancelledError(error.error);
      }
      throw UploadSessionTransportError(
        error.type == DioExceptionType.sendTimeout ||
                error.type == DioExceptionType.receiveTimeout
            ? 'Upload timed out'
            : 'Network error uploading: ${error.message}',
        transient: true,
      );
    }
  }
}

/// One signed upload: `put` or `multipart` transfer with retries, then
/// `complete`, or `abort` after any failure. Port of
/// `apps/sim/lib/uploads/client/upload-session.ts`.
class UploadSession<T> {
  UploadSession({
    required this.source,
    required this.transfer,
    required Future<T> Function() complete,
    required Future<void> Function() abort,
    Future<List<UploadPartUrl>> Function(List<int> partNumbers)? getPartUrls,
    UploadTransport? transport,
    CancelToken? cancelToken,
    Future<void> Function(Duration delay)? delay,
    Random? random,
    Logger? logger,
  }) : _complete = complete,
       _abort = abort,
       _getPartUrls = getPartUrls,
       _transport = transport ?? DioUploadTransport(),
       cancelToken = cancelToken ?? CancelToken(),
       _delay = delay ?? Future<void>.delayed,
       _random = random ?? Random(),
       _log = logger ?? Logger('sim_api.uploads') {
    if (transfer is MultipartUploadTransfer && getPartUrls == null) {
      throw ArgumentError('a multipart transfer needs getPartUrls');
    }
  }

  final UploadSource source;
  final UploadTransfer transfer;
  final CancelToken cancelToken;
  final Future<T> Function() _complete;
  final Future<void> Function() _abort;
  final Future<List<UploadPartUrl>> Function(List<int> partNumbers)?
  _getPartUrls;
  final UploadTransport _transport;
  final Future<void> Function(Duration delay) _delay;
  final Random _random;
  final Logger _log;
  final _progress = StreamController<UploadProgress>.broadcast();

  Stream<UploadProgress> get progress => _progress.stream;

  /// Uploads, completes and returns the completion result. On any failure
  /// (including cancellation) the session is aborted first and the failure
  /// rethrown.
  Future<T> run() async {
    try {
      switch (transfer) {
        case PutUploadTransfer(:final url, :final headers):
          await _uploadPut(url, headers);
        case MultipartUploadTransfer(:final partSize, :final partCount):
          await _uploadMultipart(partSize, partCount);
      }
    } on Object {
      try {
        await _abort();
      } on Object catch (abortError) {
        _log.warning(
          'Failed to abort upload session after an upload error',
          abortError,
        );
      }
      rethrow;
    } finally {
      await _progress.close();
    }
    return _complete();
  }

  void _report(int loaded) {
    final total = source.size;
    _progress.add(
      UploadProgress(
        loaded: loaded,
        total: total,
        percent: total == 0 ? 100 : min(100, (loaded / total * 100).round()),
      ),
    );
  }

  Future<void> _uploadPut(String url, Map<String, String> headers) async {
    var reported = 0;
    void report(int loaded) {
      reported = max(reported, loaded);
      _report(reported);
    }

    final bytes = await source.read(0, source.size);
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      _throwIfCancelled();
      try {
        final result = await _transport.put(
          url: url,
          headers: headers,
          bytes: bytes,
          timeout: calculateUploadTimeout(source.size),
          cancelToken: cancelToken,
          onProgress: report,
        );
        _throwIfCancelled();
        if (!result.ok) {
          throw UploadSessionTransportError(
            'PUT upload failed for ${source.name}: ${result.status}',
            status: result.status,
            retryAfter: parseRetryAfter(
              result.retryAfterHeader,
              maxMs: _retryMaxMs,
            ),
            transient: _isRetryableStatus(result.status),
          );
        }
        report(source.size);
        return;
      } on UploadSessionTransportError catch (error) {
        // A retried create-only PUT rejected with 409/412 means the first
        // attempt's bytes are already committed; completion verifies them.
        if (attempt > 0 && (error.status == 409 || error.status == 412)) {
          report(source.size);
          return;
        }
        if (!error.transient || attempt >= _maxRetries) rethrow;
        await _waitForRetry(attempt + 1, error.retryAfter);
      }
    }
    throw UploadSessionTransportError(
      'PUT upload retries exhausted for ${source.name}',
    );
  }

  Future<void> _uploadMultipart(int partSize, int partCount) async {
    final expectedPartCount = (source.size / partSize).ceil();
    if (expectedPartCount != partCount) {
      throw UploadSessionMismatchError(
        'Upload session expected $partCount parts, but file requires $expectedPartCount',
      );
    }
    final completedBytes = List<int>.filled(partCount, 0);
    for (var start = 1; start <= partCount; start += _partUrlBatchSize) {
      final partNumbers = List<int>.generate(
        min(_partUrlBatchSize, partCount - start + 1),
        (index) => start + index,
      );
      _throwIfCancelled();
      final partUrls = _validatePartUrlBatch(
        partNumbers,
        await _getPartUrls!(partNumbers),
      );
      final results = await runWithConcurrency(
        partUrls,
        partUploadConcurrency,
        (part, _) async {
          final partStart = (part.partNumber - 1) * partSize;
          final end = min(partStart + partSize, source.size);
          final chunk = await source.read(partStart, end);
          await _uploadPart(part, chunk);
          completedBytes[part.partNumber - 1] = end - partStart;
          _report(completedBytes.fold(0, (sum, bytes) => sum + bytes));
        },
      );
      for (final result in results) {
        if (result.error != null) {
          Error.throwWithStackTrace(result.error!, result.stackTrace!);
        }
      }
    }
  }

  Future<void> _uploadPart(UploadPartUrl part, Uint8List chunk) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      _throwIfCancelled();
      try {
        final result = await _transport.put(
          url: part.url,
          headers: part.headers,
          bytes: chunk,
          timeout: calculateUploadTimeout(chunk.length),
          cancelToken: cancelToken,
        );
        _throwIfCancelled();
        if (!result.ok) {
          throw UploadSessionTransportError(
            'Part ${part.partNumber} failed (${result.status})',
            status: result.status,
            retryAfter: parseRetryAfter(
              result.retryAfterHeader,
              maxMs: _retryMaxMs,
            ),
            transient: _isRetryableStatus(result.status),
          );
        }
        return;
      } on UploadSessionTransportError catch (error) {
        if (!error.transient || attempt >= _maxRetries) rethrow;
        await _waitForRetry(attempt + 1, error.retryAfter);
      }
    }
    throw UploadSessionTransportError(
      'Part ${part.partNumber} upload retries exhausted',
    );
  }

  static List<UploadPartUrl> _validatePartUrlBatch(
    List<int> requested,
    List<UploadPartUrl> received,
  ) {
    if (received.length != requested.length) {
      throw UploadSessionMismatchError(
        'Expected ${requested.length} part URLs; received ${received.length}',
      );
    }
    final byPartNumber = <int, UploadPartUrl>{};
    for (final part in received) {
      if (byPartNumber.containsKey(part.partNumber)) {
        throw UploadSessionMismatchError(
          'Received duplicate URL for part ${part.partNumber}',
        );
      }
      byPartNumber[part.partNumber] = part;
    }
    return requested.map((partNumber) {
      final part = byPartNumber[partNumber];
      if (part == null) {
        throw UploadSessionMismatchError(
          'Missing upload URL for part $partNumber',
        );
      }
      return part;
    }).toList();
  }

  static bool _isRetryableStatus(int status) =>
      status == 408 || status == 429 || (status >= 500 && status < 600);

  void _throwIfCancelled() {
    if (cancelToken.isCancelled) {
      throw ApiCancelledError('Upload aborted for ${source.name}');
    }
  }

  Future<void> _waitForRetry(int attempt, Duration? retryAfter) async {
    _throwIfCancelled();
    final delay = backoffWithJitter(
      attempt,
      retryAfter,
      maxMs: _retryMaxMs,
      random: _random,
    );
    await Future.any<void>([_delay(delay), cancelToken.whenCancel]);
    _throwIfCancelled();
  }
}

/// One settled result of [runWithConcurrency].
class SettledResult<R> {
  const SettledResult.fulfilled(this.value) : error = null, stackTrace = null;

  const SettledResult.rejected(Object this.error, StackTrace this.stackTrace)
    : value = null;

  final R? value;
  final Object? error;
  final StackTrace? stackTrace;
}

/// Runs [worker] over [items] with at most [limit] in flight; results keep
/// the input order and failures do not stop the others.
Future<List<SettledResult<R>>> runWithConcurrency<T, R>(
  List<T> items,
  int limit,
  Future<R> Function(T item, int index) worker,
) async {
  if (limit <= 0) throw ArgumentError.value(limit, 'limit', 'must be positive');
  final results = List<SettledResult<R>?>.filled(items.length, null);
  if (items.isEmpty) return const [];
  var nextIndex = 0;
  Future<void> runner() async {
    while (true) {
      final index = nextIndex++;
      if (index >= items.length) return;
      try {
        results[index] = SettledResult.fulfilled(
          await worker(items[index], index),
        );
      } on Object catch (error, stackTrace) {
        results[index] = SettledResult.rejected(error, stackTrace);
      }
    }
  }

  await Future.wait(
    List.generate(min(limit, items.length), (_) => runner()),
  );
  return results.cast<SettledResult<R>>();
}

/// The control-plane calls of the signed upload protocol
/// (`lib/api/contracts/upload-sessions.ts`), bundled with [UploadSession].
class UploadSessionClient {
  UploadSessionClient(
    this._http, {
    UploadTransport? transport,
    Logger? logger,
  }) : _transport = transport ?? DioUploadTransport(),
       _log = logger;

  final SimHttpClient _http;
  final UploadTransport _transport;
  final Logger? _log;

  /// `POST /api/files/uploads`.
  Future<CreatedUploadSession> create(
    Map<String, Object?> body, {
    CancelToken? cancelToken,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/files/uploads',
      body: body,
      cancelToken: cancelToken,
    );
    return CreatedUploadSession.fromJson(response.data);
  }

  /// `POST /api/files/uploads/[uploadId]/parts` `{partNumbers}`.
  Future<List<UploadPartUrl>> partUrls({
    required String uploadId,
    required String uploadToken,
    required List<int> partNumbers,
    CancelToken? cancelToken,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/files/uploads/[uploadId]/parts',
      params: {'uploadId': uploadId},
      headers: {uploadTokenHeader: uploadToken},
      body: {'partNumbers': partNumbers},
      cancelToken: cancelToken,
    );
    final data = response.data;
    final parts = data is Map && data['data'] is Map
        ? (data['data'] as Map)['parts']
        : null;
    if (parts is! List) {
      throw const FormatException('part urls: missing data.parts');
    }
    return parts.map(UploadPartUrl.fromJson).toList();
  }

  /// `POST /api/files/uploads/[uploadId]/complete` → the session JSON.
  Future<Map<String, Object?>> complete({
    required String uploadId,
    required String uploadToken,
    CancelToken? cancelToken,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/files/uploads/[uploadId]/complete',
      params: {'uploadId': uploadId},
      headers: {uploadTokenHeader: uploadToken},
      cancelToken: cancelToken,
    );
    return _sessionOf(response.data);
  }

  /// `DELETE /api/files/uploads/[uploadId]`.
  Future<void> abort({
    required String uploadId,
    required String uploadToken,
  }) async {
    await _http.send(
      method: 'DELETE',
      path: '/api/files/uploads/[uploadId]',
      params: {'uploadId': uploadId},
      headers: {uploadTokenHeader: uploadToken},
    );
  }

  /// The whole protocol for one file: create → transfer → complete.
  /// [onSession] receives the created session before bytes move (for
  /// progress wiring); the returned value is the completed session JSON.
  Future<Map<String, Object?>> upload({
    required Map<String, Object?> body,
    required UploadSource source,
    CancelToken? cancelToken,
    void Function(UploadSession<Map<String, Object?>> session)? onSession,
  }) async {
    final created = await create(body, cancelToken: cancelToken);
    final session = UploadSession<Map<String, Object?>>(
      source: source,
      transfer: created.transfer,
      transport: _transport,
      cancelToken: cancelToken,
      logger: _log,
      getPartUrls: (partNumbers) => partUrls(
        uploadId: created.uploadId,
        uploadToken: created.uploadToken,
        partNumbers: partNumbers,
        cancelToken: cancelToken,
      ),
      complete: () => complete(
        uploadId: created.uploadId,
        uploadToken: created.uploadToken,
        cancelToken: cancelToken,
      ),
      abort: () => abort(
        uploadId: created.uploadId,
        uploadToken: created.uploadToken,
      ),
    );
    onSession?.call(session);
    return session.run();
  }

  static Map<String, Object?> _sessionOf(Object? json) {
    final data = json is Map ? json['data'] : null;
    return data is Map ? Map<String, Object?>.from(data) : {};
  }
}
