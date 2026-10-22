/// Where the desktop key-value store lives. Returns null on web, where
/// IndexedDB is used instead.
library;

export 'storage_path_stub.dart' if (dart.library.io) 'storage_path_io.dart';
