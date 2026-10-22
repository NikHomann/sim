import 'package:web/web.dart' as web;

/// Clears `window.sessionStorage`; a blocked store is left alone.
void clearBrowserSessionStorage() {
  try {
    web.window.sessionStorage.clear();
  } on Object {
    // Storage blocked (private mode): nothing to clear.
  }
}
