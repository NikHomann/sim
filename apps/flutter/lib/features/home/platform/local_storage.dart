import 'package:sim_app/features/home/platform/local_storage_stub.dart'
    if (dart.library.js_interop) 'package:sim_app/features/home/platform/local_storage_web.dart'
    as platform;

/// Synchronous string storage for the Home preferences React keeps in
/// `localStorage` (the panel widths). On web it is the browser's
/// `localStorage`, shared with the React app; elsewhere it lives in memory
/// for the app session. Reads and writes never throw (`store.ts:36-58`).
abstract class HomeLocalStorage {
  /// The implementation for the running platform.
  factory HomeLocalStorage.platform() => platform.createHomeLocalStorage();

  /// In-memory storage (desktop, tests).
  factory HomeLocalStorage.memory([Map<String, String>? values]) =
      MemoryHomeLocalStorage;

  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

/// [HomeLocalStorage] on a map.
class MemoryHomeLocalStorage implements HomeLocalStorage {
  MemoryHomeLocalStorage([Map<String, String>? values])
    : values = values ?? <String, String>{};

  final Map<String, String> values;

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;

  @override
  void remove(String key) => values.remove(key);
}
