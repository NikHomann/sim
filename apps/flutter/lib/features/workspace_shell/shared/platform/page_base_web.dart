import 'package:web/web.dart' as web;

/// `document.baseURI`: the `<base href>` resolved against the page (for the
/// app, `https://host/app/`), unlike `Uri.base`, which is `location.href`.
String? pageBaseUri() => web.document.baseURI;
