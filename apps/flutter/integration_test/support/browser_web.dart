import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Sets a cookie for the app origin. Cookies are host-scoped, so a cookie set
/// here is sent to every localhost port, the same way the server-set one is.
void setDocumentCookie(String cookie) {
  web.document.cookie = '$cookie; path=/; SameSite=Lax';
}

/// The current path of the browser location.
String? currentPath() => web.window.location.pathname;

/// Resource requests the page made so far (Resource Timing), with
/// `responseStatus` where Chromium reports it (0 when it does not).
List<({String path, int status})> resourceTimings() {
  final entries = web.window.performance.getEntriesByType('resource').toDart;
  return [
    for (final entry in entries)
      (
        path: Uri.tryParse(entry.name)?.path ?? entry.name,
        status:
            (entry as JSObject)
                .getProperty<JSNumber?>('responseStatus'.toJS)
                ?.toDartInt ??
            0,
      ),
  ];
}
