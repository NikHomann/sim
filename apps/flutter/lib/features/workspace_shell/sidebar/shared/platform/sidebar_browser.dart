/// Browser primitives the sidebar needs (`window.open`, `location.origin`,
/// `navigator.userAgent`, the hidden `<input type=file>`). On web they map
/// onto the browser; on desktop they fall back to `url_launcher` and no-ops.
library;

export 'sidebar_browser_stub.dart'
    if (dart.library.js_interop) 'sidebar_browser_web.dart';
