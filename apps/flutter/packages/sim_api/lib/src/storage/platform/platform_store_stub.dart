import 'package:sim_api/src/storage/file_key_value_store.dart';
import 'package:sim_api/src/storage/key_value_store.dart';

/// Desktop: the JSON-file store at [filePath] (required here).
KeyValueStore createPlatformKeyValueStore({
  String? filePath,
  String databaseName = 'sim-flutter-kv',
}) {
  if (filePath == null) throw ArgumentError.notNull('filePath');
  return FileKeyValueStore(filePath);
}
