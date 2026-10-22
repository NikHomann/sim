import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/json.dart';

/// Ports of the retry policy and its bounds from
/// `packages/workflow-types/src/workflow.ts`.
const int blockRetryMinTries = 2;
const int blockRetryMaxTries = 5;
const int blockRetryDefaultTries = 3;
const int blockRetryMinWaitMs = 0;
const int blockRetryMaxWaitMs = 5000;
const int blockRetryDefaultWaitMs = 1000;

/// Port of `BlockRetryConfig` from `packages/workflow-types/src/workflow.ts`.
@immutable
class BlockRetryConfig {
  const BlockRetryConfig({
    required this.enabled,
    required this.maxTries,
    required this.waitBetweenTriesMs,
  });

  factory BlockRetryConfig.fromJson(
    Map<String, Object?> json, [
    String path = '',
  ]) {
    final reader = JsonReader(json, path);
    return BlockRetryConfig(
      enabled: reader.boolean('enabled'),
      maxTries: reader.number('maxTries').toInt(),
      waitBetweenTriesMs: reader.number('waitBetweenTriesMs').toInt(),
    );
  }

  final bool enabled;
  final int maxTries;
  final int waitBetweenTriesMs;

  BlockRetryConfig copyWith({
    bool? enabled,
    int? maxTries,
    int? waitBetweenTriesMs,
  }) => BlockRetryConfig(
    enabled: enabled ?? this.enabled,
    maxTries: maxTries ?? this.maxTries,
    waitBetweenTriesMs: waitBetweenTriesMs ?? this.waitBetweenTriesMs,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'maxTries': maxTries,
    'waitBetweenTriesMs': waitBetweenTriesMs,
  };

  @override
  bool operator ==(Object other) =>
      other is BlockRetryConfig &&
      other.enabled == enabled &&
      other.maxTries == maxTries &&
      other.waitBetweenTriesMs == waitBetweenTriesMs;

  @override
  int get hashCode => Object.hash(enabled, maxTries, waitBetweenTriesMs);
}

/// Port of `blockRetryEquals`: field-by-field, nullish on both sides equal.
bool blockRetryEquals(BlockRetryConfig? a, BlockRetryConfig? b) {
  if (a == null || b == null) return a == null && b == null;
  return a == b;
}

/// Port of `normalizeBlockRetryTries`.
int normalizeBlockRetryTries(Object? value) => _normalizeBound(
  value,
  blockRetryMinTries,
  blockRetryMaxTries,
  blockRetryDefaultTries,
);

/// Port of `normalizeBlockRetryWaitMs`.
int normalizeBlockRetryWaitMs(Object? value) => _normalizeBound(
  value,
  blockRetryMinWaitMs,
  blockRetryMaxWaitMs,
  blockRetryDefaultWaitMs,
);

/// Port of `normalizeBound`. Mirrors JavaScript `Number(value)`: numbers pass,
/// numeric strings parse, booleans map to 0/1, anything else is NaN and falls
/// back. Nullish is checked before conversion because `Number(null)` is `0`.
int _normalizeBound(Object? value, int min, int max, int fallback) {
  if (value == null) return fallback;
  final parsed = _jsNumber(value);
  if (parsed == null || !parsed.isFinite) return fallback;
  return parsed.floor().clamp(min, max);
}

double? _jsNumber(Object value) {
  if (value is num) return value.toDouble();
  if (value is bool) return value ? 1 : 0;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 0;
    return double.tryParse(trimmed);
  }
  return null;
}

/// Port of `resolveBlockRetryConfig`: null when the block must not retry,
/// otherwise a clamped copy with `enabled: true`.
BlockRetryConfig? resolveBlockRetryConfig(BlockRetryConfig? retry) {
  if (retry == null || !retry.enabled) return null;
  return BlockRetryConfig(
    enabled: true,
    maxTries: normalizeBlockRetryTries(retry.maxTries),
    waitBetweenTriesMs: normalizeBlockRetryWaitMs(retry.waitBetweenTriesMs),
  );
}
