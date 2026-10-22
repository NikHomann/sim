/// Sets a cookie for the app origin (no-op off the web).
void setDocumentCookie(String cookie) {}

/// The current path of the browser location (`null` off the web).
String? currentPath() => null;

/// Resource requests the page made so far, with their HTTP status when the
/// browser reports one (empty off the web).
List<({String path, int status})> resourceTimings() => const [];
