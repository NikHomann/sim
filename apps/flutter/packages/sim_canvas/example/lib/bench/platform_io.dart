import 'dart:io';

String get platformName => Platform.operatingSystem;

/// Appends [line] to the file at [path] (created if missing).
void appendLine(String path, String line) {
  File(path).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
}

void exitApp(int code) => exit(code);
