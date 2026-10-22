/// Severity of a [RealtimeLogger] entry.
enum RealtimeLogLevel {
  /// Diagnostic detail.
  debug,

  /// Normal progress.
  info,

  /// Something unexpected the code recovered from.
  warn,

  /// A failure.
  error,
}

/// Receives the log lines upstream sends to `createLogger('OperationQueue')`
/// and friends. `data` is a JSON-like map of context fields.
typedef RealtimeLogger =
    void Function(
      RealtimeLogLevel level,
      String message, [
      Map<String, Object?>? data,
    ]);

/// A logger that drops everything.
void noopRealtimeLogger(
  RealtimeLogLevel level,
  String message, [
  Map<String, Object?>? data,
]) {}
