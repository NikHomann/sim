import 'dart:js_interop';

import 'package:web/web.dart' as web;

String get platformName => 'web';

/// No file system on the web: results are printed to the console and, when
/// `BENCH_OUT` is an http(s) URL, POSTed there line by line so a driver outside
/// the browser can collect them (`flutter run -d chrome --profile` does not
/// forward the page's console output).
void appendLine(String path, String line) {
  if (!path.startsWith('http')) return;
  web.window.fetch(
    path.toJS,
    web.RequestInit(method: 'POST', body: line.toJS),
  );
}

/// A browser tab cannot terminate the process; the driver stops `flutter run`
/// once it has collected the `BENCH_DONE` line.
void exitApp(int code) {
  const done = 'BENCH_DONE';
  web.document.title = done;
}
