import 'dart:js_interop';

import 'package:sim_app/features/workspace_shell/shortcuts/shortcut_matcher.dart';
import 'package:web/web.dart' as web;

/// `codeToKey(e.code)`: `KeyX` → `x`, `DigitN` → `N`, else null.
String? _codeKey(String code) {
  if (code.length == 4 && code.startsWith('Key')) {
    return code.substring(3).toLowerCase();
  }
  if (code.length == 6 && code.startsWith('Digit')) return code.substring(5);
  return null;
}

/// `window.addEventListener('keydown', …, true)`: prevents the browser's
/// default for a chord [willHandle] claims. The event still reaches the
/// engine, which runs the command.
void Function() installShortcutCapture(
  bool Function(ShortcutKeyEvent event) willHandle,
) {
  void onKeyDown(web.Event event) {
    if (!event.isA<web.KeyboardEvent>()) return;
    final key = event as web.KeyboardEvent;
    final raw = key.key;
    final shortcut = ShortcutKeyEvent(
      key: raw.length == 1 ? raw.toLowerCase() : raw,
      codeKey: _codeKey(key.code),
      ctrl: key.ctrlKey,
      meta: key.metaKey,
      shift: key.shiftKey,
      alt: key.altKey,
      isComposing: key.isComposing,
    );
    if (willHandle(shortcut)) event.preventDefault();
  }

  final listener = onKeyDown.toJS;
  final options = web.AddEventListenerOptions(capture: true);
  web.window.addEventListener('keydown', listener, options);
  return () => web.window.removeEventListener(
    'keydown',
    listener,
    web.EventListenerOptions(capture: true),
  );
}
