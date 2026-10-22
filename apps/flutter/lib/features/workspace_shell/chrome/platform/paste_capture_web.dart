import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Decides whether a paste of [text] is refused (and reports it).
typedef PasteCaptureDecision = bool Function(String text);

/// `document.addEventListener('paste', …, true)`: reads the plain-text
/// payload and, when [reject] refuses it, cancels the browser's insertion
/// (`preventDefault` + `stopImmediatePropagation`). Returns the remover.
void Function() installPasteCapture(PasteCaptureDecision reject) {
  void onPaste(web.Event event) {
    if (!event.isA<web.ClipboardEvent>()) return;
    final clipboard = (event as web.ClipboardEvent).clipboardData;
    final text = clipboard?.getData('text/plain') ?? '';
    if (text.isEmpty || !reject(text)) return;
    event
      ..preventDefault()
      ..stopImmediatePropagation();
  }

  final listener = onPaste.toJS;
  final options = web.AddEventListenerOptions(capture: true);
  web.document.addEventListener('paste', listener, options);
  return () => web.document.removeEventListener(
    'paste',
    listener,
    web.EventListenerOptions(capture: true),
  );
}
