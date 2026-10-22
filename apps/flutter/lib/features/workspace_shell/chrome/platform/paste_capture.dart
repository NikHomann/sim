/// The capture-phase DOM `paste` listener of `PasteAdmissionGuard`
/// (`paste-admission-guard.tsx:225-324`): on web the browser pastes
/// natively into the engine's hidden input, so `PasteTextIntent` never runs
/// and only a document listener sees the payload first.
library;

export 'paste_capture_stub.dart'
    if (dart.library.js_interop) 'paste_capture_web.dart';
