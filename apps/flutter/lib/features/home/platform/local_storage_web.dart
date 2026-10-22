import 'package:sim_app/features/home/platform/local_storage.dart';
import 'package:web/web.dart' as web;

/// `window.localStorage`; failures (quota, privacy mode) are swallowed.
class _WebLocalStorage implements HomeLocalStorage {
  @override
  String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } on Object {
      return null;
    }
  }

  @override
  void write(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } on Object {
      // `Unable to save chat panel preferences`: the session keeps them.
    }
  }

  @override
  void remove(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } on Object {
      // Ignored like the React store.
    }
  }
}

HomeLocalStorage createHomeLocalStorage() => _WebLocalStorage();
