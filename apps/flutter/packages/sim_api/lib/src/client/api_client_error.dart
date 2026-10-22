import 'package:sim_api/src/client/retry.dart';

/// Rate-limit headers the API exposes (`X-RateLimit-*`, `Retry-After`).
class RateLimitInfo {
  const RateLimitInfo({
    this.limit,
    this.remaining,
    this.reset,
    this.retryAfter,
  });

  /// Reads the rate-limit headers out of a response header map; `null` when
  /// none is present.
  static RateLimitInfo? fromHeaders(
    Map<String, List<String>> headers, {
    DateTime Function()? now,
  }) {
    String? first(String name) {
      for (final entry in headers.entries) {
        if (entry.key.toLowerCase() == name && entry.value.isNotEmpty) {
          return entry.value.first;
        }
      }
      return null;
    }

    final limit = int.tryParse(first('x-ratelimit-limit') ?? '');
    final remaining = int.tryParse(first('x-ratelimit-remaining') ?? '');
    final reset = first('x-ratelimit-reset');
    final retryAfter = parseRetryAfter(first('retry-after'), now: now);
    if (limit == null &&
        remaining == null &&
        reset == null &&
        retryAfter == null) {
      return null;
    }
    return RateLimitInfo(
      limit: limit,
      remaining: remaining,
      reset: reset,
      retryAfter: retryAfter,
    );
  }

  final int? limit;
  final int? remaining;

  /// Raw `X-RateLimit-Reset` value (epoch seconds or ISO date, route-specific).
  final String? reset;
  final Duration? retryAfter;
}

/// One `details[]` entry of a validation failure
/// (`{error, details:[{path, message}]}`).
class ValidationIssue {
  const ValidationIssue({required this.path, required this.message});

  /// Path of the failing field, e.g. `['updates', 'name']`.
  final List<Object> path;
  final String message;

  /// Whether [path] ends with [suffix] (`['name']` matches
  /// `['updates','name']`).
  bool matches(List<Object> suffix) {
    if (path.length < suffix.length) return false;
    final tail = path.sublist(path.length - suffix.length);
    for (var i = 0; i < suffix.length; i++) {
      if (tail[i] != suffix[i]) return false;
    }
    return true;
  }

  @override
  String toString() => '${path.join('.')}: $message';
}

/// A non-2xx response, port of `apps/sim/lib/api/client/errors.ts` plus the
/// envelope reading the React client does at the call sites.
///
/// Recognised bodies: internal `{error, requestId?}`, validation
/// `{error, details:[{path, message}]}`, v2 `{error:{code, message, details}}`,
/// Better Auth `{code, message}`, and non-JSON text (kept in [rawBody], the
/// message falls back to `Request failed with <status>`).
class ApiClientError implements Exception {
  ApiClientError({
    required this.status,
    required this.message,
    this.body,
    this.rawBody,
    this.code,
    this.requestId,
    this.details = const [],
    this.rateLimit,
  });

  /// Builds the error from a decoded [body] (JSON value or raw text) and the
  /// response [headers].
  factory ApiClientError.fromResponse({
    required int status,
    required Object? body,
    String? rawBody,
    Map<String, List<String>> headers = const {},
    DateTime Function()? now,
  }) {
    var message = 'Request failed with $status';
    String? code;
    String? requestId;
    var details = const <ValidationIssue>[];

    if (body is Map) {
      final error = body['error'];
      final topMessage = body['message'];
      if (topMessage is String && topMessage.isNotEmpty) {
        message = topMessage;
      } else if (error is String && error.isNotEmpty) {
        message = error;
      } else if (error is Map) {
        final nested = error['message'];
        if (nested is String && nested.isNotEmpty) message = nested;
        final nestedCode = error['code'];
        if (nestedCode is String && nestedCode.isNotEmpty) code = nestedCode;
        details = _normalizeDetails(error['details']);
      }
      final topCode = body['code'];
      if (topCode is String && topCode.isNotEmpty) code = topCode;
      final id = body['requestId'];
      if (id is String && id.isNotEmpty) requestId = id;
      if (details.isEmpty) details = _normalizeDetails(body['details']);
    }

    return ApiClientError(
      status: status,
      message: message,
      body: body,
      rawBody: rawBody,
      code: code,
      requestId: requestId,
      details: details,
      rateLimit: RateLimitInfo.fromHeaders(headers, now: now),
    );
  }

  final int status;
  final String message;

  /// The decoded JSON body, or the raw text when it was not JSON.
  final Object? body;
  final String? rawBody;
  final String? code;
  final String? requestId;

  /// Validation issues from `details[]` (empty when not a validation failure).
  final List<ValidationIssue> details;
  final RateLimitInfo? rateLimit;

  /// `Retry-After` of a 429/503, parsed.
  Duration? get retryAfter => rateLimit?.retryAfter;

  bool get isValidationError => details.isNotEmpty;

  /// The request was cancelled by the client while the server was working.
  bool get isClientClosedRequest => status == 499;
  bool get isPayloadTooLarge => status == 413;
  bool get isRateLimited => status == 429;
  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;

  /// First issue whose path ends with [pathSuffix], if any.
  ValidationIssue? findIssue(List<Object> pathSuffix) {
    for (final issue in details) {
      if (issue.matches(pathSuffix)) return issue;
    }
    return null;
  }

  static List<ValidationIssue> _normalizeDetails(Object? raw) {
    if (raw is! List) return const [];
    final issues = <ValidationIssue>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final message = item['message'];
      final path = item['path'];
      if (message is! String || message.isEmpty || path is! List) continue;
      issues.add(
        ValidationIssue(
          path: path
              .whereType<Object>()
              .where((s) => s is String || s is num)
              .toList(),
          message: message,
        ),
      );
    }
    return issues;
  }

  @override
  String toString() =>
      'ApiClientError($status${code == null ? '' : ' $code'}: $message)';
}

/// The request never produced a response: connection failure, timeout or a
/// body read that was cut off.
class ApiNetworkError implements Exception {
  const ApiNetworkError(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ApiNetworkError: $message';
}

/// The request was cancelled through its `CancelToken`.
class ApiCancelledError implements Exception {
  const ApiCancelledError([this.reason]);

  final Object? reason;

  @override
  String toString() => 'ApiCancelledError';
}
