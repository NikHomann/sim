/// Port of `packages/utils/src/retry.ts`.
library;

import 'dart:math';

const _defaultBackoffBaseMs = 500;
const _defaultBackoffMaxMs = 30000;
const _retryAfterMaxMs = 30000;

/// The next delay of a retry loop (`attempt` is 1-indexed).
///
/// A non-null [retryAfter] is clamped to `[baseMs, maxMs]`; otherwise
/// exponential backoff with +-20 % jitter.
Duration backoffWithJitter(
  int attempt,
  Duration? retryAfter, {
  int baseMs = _defaultBackoffBaseMs,
  int maxMs = _defaultBackoffMaxMs,
  Random? random,
}) {
  if (retryAfter != null) {
    return Duration(
      milliseconds: min(max(retryAfter.inMilliseconds, baseMs), maxMs),
    );
  }
  final exponential = min(baseMs * pow(2, attempt - 1), maxMs).toDouble();
  final jitter = (random ?? Random()).nextDouble();
  return Duration(milliseconds: (exponential * (0.8 + jitter * 0.4)).round());
}

/// Parses an HTTP `Retry-After` header (delta-seconds or HTTP-date) into a
/// delay capped at [maxMs]. `null` when absent or unparseable.
Duration? parseRetryAfter(
  String? header, {
  int maxMs = _retryAfterMaxMs,
  DateTime Function()? now,
}) {
  if (header == null) return null;
  final trimmed = header.trim();
  if (trimmed.isEmpty) return null;
  final seconds = double.tryParse(trimmed);
  if (seconds != null && seconds.isFinite && seconds >= 0) {
    return Duration(milliseconds: min((seconds * 1000).floor(), maxMs));
  }
  final date = _parseHttpDate(trimmed);
  if (date != null) {
    final delta = date.difference((now ?? DateTime.now)()).inMilliseconds;
    if (delta <= 0) return Duration.zero;
    return Duration(milliseconds: min(delta, maxMs));
  }
  return null;
}

final _httpDate = RegExp(
  r'^(?:[A-Za-z]{3}),\s+(\d{2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$',
);
const _months = {
  'Jan': 1,
  'Feb': 2,
  'Mar': 3,
  'Apr': 4,
  'May': 5,
  'Jun': 6,
  'Jul': 7,
  'Aug': 8,
  'Sep': 9,
  'Oct': 10,
  'Nov': 11,
  'Dec': 12,
};

DateTime? _parseHttpDate(String value) {
  final match = _httpDate.firstMatch(value);
  if (match != null) {
    final month = _months[match.group(2)];
    if (month == null) return null;
    return DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
  return DateTime.tryParse(value);
}
