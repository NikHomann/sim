import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// `window.addEventListener('beforeunload', …)`: while [shouldBlock] holds
/// (a settings editor is dirty or blocks navigation) the browser asks
/// before a refresh or tab close. Returns the remover.
void Function() installBeforeUnloadGuard(bool Function() shouldBlock) {
  void onBeforeUnload(web.Event event) {
    if (shouldBlock()) event.preventDefault();
  }

  final listener = onBeforeUnload.toJS;
  web.window.addEventListener('beforeunload', listener);
  return () => web.window.removeEventListener('beforeunload', listener);
}
