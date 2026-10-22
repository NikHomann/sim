// Browser hooks for the L5 flows: the web implementation sets the minted
// session cookie and reads the location/resource timings; elsewhere (Windows
// `flutter test integration_test`) they are inert.
export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';
