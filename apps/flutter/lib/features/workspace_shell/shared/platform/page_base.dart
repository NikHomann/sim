/// The page's document base URL (`document.baseURI`, the `<base href>`) on
/// web; `null` elsewhere.
library;

export 'page_base_stub.dart' if (dart.library.js_interop) 'page_base_web.dart';
