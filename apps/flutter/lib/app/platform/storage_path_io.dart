import 'dart:io';

/// `%LOCALAPPDATA%\sim_flutter\kv.json` on Windows, `~/.sim_flutter/kv.json`
/// elsewhere.
String? defaultStoragePath() {
  final env = Platform.environment;
  final base = Platform.isWindows
      ? env['LOCALAPPDATA'] ?? env['USERPROFILE']
      : env['HOME'];
  if (base == null) return null;
  final separator = Platform.pathSeparator;
  final folder = Platform.isWindows ? 'sim_flutter' : '.sim_flutter';
  return '$base$separator$folder${separator}kv.json';
}
