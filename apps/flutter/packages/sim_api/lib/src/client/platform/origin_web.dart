import 'package:web/web.dart' as web;

/// The page origin: the Flutter bundle is served under `/app/` of the same
/// origin as the Sim API (plan §3), so every request is same-origin.
String? resolvePageOrigin() => web.window.location.origin;
