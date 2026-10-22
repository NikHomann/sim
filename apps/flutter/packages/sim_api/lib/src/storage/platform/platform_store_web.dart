import 'package:sim_api/src/storage/indexed_db_key_value_store.dart';
import 'package:sim_api/src/storage/key_value_store.dart';

/// Web: IndexedDB under [databaseName]; [filePath] is ignored.
KeyValueStore createPlatformKeyValueStore({
  String? filePath,
  String databaseName = 'sim-flutter-kv',
}) => IndexedDbKeyValueStore(databaseName: databaseName);
