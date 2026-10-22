/// Browser-only primitives the auth pages need (`window.location`,
/// `sessionStorage`, `localStorage`, `window.close`). On web they map onto the
/// real browser; elsewhere they fall back to in-memory state and no-ops.
library;

export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';
