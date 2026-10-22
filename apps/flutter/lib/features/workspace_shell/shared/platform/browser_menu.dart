/// Whether the browser's own context menu shows over Flutter's.
library;

export 'browser_menu_stub.dart'
    if (dart.library.js_interop) 'browser_menu_web.dart';
