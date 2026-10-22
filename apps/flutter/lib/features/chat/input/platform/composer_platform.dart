/// Platform seams of the composer: draft storage, the web clipboard bridge,
/// OS file drop and the file picker.
library;

export 'composer_platform_stub.dart'
    if (dart.library.js_interop) 'composer_platform_web.dart';
export 'composer_platform_types.dart';
