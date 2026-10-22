import 'dart:developer' as developer;

import 'package:sim_app/features/chat/engine/storage/chat_storage.dart';
import 'package:web/web.dart' as web;

/// `window.localStorage` and `window.sessionStorage`.
ChatStorages? browserChatStorages() => ChatStorages(
  local: _WebStorage(() => web.window.localStorage),
  session: _WebStorage(() => web.window.sessionStorage),
);

class _WebStorage implements ChatStorage {
  _WebStorage(this._storage);

  final web.Storage Function() _storage;

  @override
  String? getItem(String key) {
    try {
      return _storage().getItem(key);
    } on Object catch (error) {
      developer.log('storage read', name: 'sim_app.chat', error: error);
      return null;
    }
  }

  @override
  void setItem(String key, String value) {
    try {
      _storage().setItem(key, value);
    } on Object catch (error) {
      developer.log('storage write', name: 'sim_app.chat', error: error);
    }
  }

  @override
  void removeItem(String key) {
    try {
      _storage().removeItem(key);
    } on Object catch (error) {
      developer.log('storage remove', name: 'sim_app.chat', error: error);
    }
  }
}
