/// Browser facts and events the chat engine reads: the IANA time zone
/// (`Intl…timeZone`), `navigator.onLine`, and the "browser return" signals
/// (`visibilitychange → visible`, `pageshow`, `online`) that trigger stream
/// recovery (spec chat-engine §4.8).
library;

export 'browser_signals_stub.dart'
    if (dart.library.js_interop) 'browser_signals_web.dart';

/// Why stream recovery runs (`ActiveStreamRecoveryReason`).
enum BrowserReturnReason {
  visible,
  pageshow,
  online,
  exhaustedRecheck,
  busyRefusal,
}
