/// `sessionStorage.clear()` for the sign-out reset (`clearUserData`,
/// `stores/index.ts:44-49`): the browser's tab storage on web, nothing
/// elsewhere (the in-memory stand-ins are cleared by their owners).
library;

export 'session_storage_stub.dart'
    if (dart.library.js_interop) 'session_storage_web.dart';
