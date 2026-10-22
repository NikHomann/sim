import 'dart:convert';

import 'package:sim_app/features/home/panel/panel_geometry.dart';
import 'package:sim_app/features/home/platform/local_storage.dart';

/// `useChatPanelStore` (`stores/chat-panel/store.ts`): the resource panel
/// width a user chose per chat, persisted in `localStorage['chat-panel-
/// widths']` with the zustand-persist envelope `{"state":{"widths":{…}},
/// "version":0}` so the React and Flutter apps share it.
///
/// Keys are `${userId}:${scopeId}` (scope = chat id, or `pending:<id>`
/// before the chat exists); values below 280 are dropped; at most 200 keys
/// are kept, most recently adjusted last. A storage failure never blocks
/// resizing (the in-memory map keeps the session's preferences).
class ChatPanelWidthStore {
  ChatPanelWidthStore({HomeLocalStorage? storage})
    : _storage = storage ?? HomeLocalStorage.platform();

  static const String storageKey = 'chat-panel-widths';
  static const int maxSavedChats = 200;

  final HomeLocalStorage _storage;
  Map<String, double>? _widths;

  /// Pending scopes adopted by a chat id (`adoptedChatKeys`): a drag that
  /// finishes after the adoption still lands on the chat.
  final Map<String, String> _adopted = <String, String>{};

  Map<String, double> get _hydrated => _widths ??= _bounded(_readEnvelope());

  /// Every stored width (tests, diagnostics).
  Map<String, double> get widths => Map<String, double>.unmodifiable(_hydrated);

  /// `resolveChatId`.
  String resolveScope(String scopeId) => _adopted[scopeId] ?? scopeId;

  /// The stored width of [scopeId] for [userId]; none without a user.
  double? preferred(String? userId, String scopeId) {
    if (userId == null) return null;
    return _hydrated['$userId:${resolveScope(scopeId)}'];
  }

  /// `setWidth`: invalid widths are ignored; the key moves to the end.
  void setWidth(String userId, String scopeId, double width) {
    if (!_valid(width)) return;
    final widths = _hydrated;
    final key = '$userId:${resolveScope(scopeId)}';
    if (widths[key] == width) return;
    widths
      ..remove(key)
      ..[key] = width;
    _widths = _bounded(widths);
    _write();
  }

  /// `migrate`: a pending scope became [toScope].
  void migrate(String fromScope, String toScope) {
    if (fromScope == toScope) return;
    _adopted
      ..remove(fromScope)
      ..[fromScope] = toScope;
    while (_adopted.length > maxSavedChats) {
      _adopted.remove(_adopted.keys.first);
    }
    final widths = _hydrated;
    var changed = false;
    for (final key in widths.keys.toList()) {
      if (!key.endsWith(':$fromScope')) continue;
      final destination =
          '${key.substring(0, key.length - fromScope.length)}$toScope';
      final width = widths.remove(key)!;
      widths.putIfAbsent(destination, () => width);
      changed = true;
    }
    if (changed) _write();
  }

  /// The user-data reset (sign-out): forget everything, clear storage.
  void reset() {
    _adopted.clear();
    _widths = <String, double>{};
    _storage.remove(storageKey);
  }

  static bool _valid(Object? value) =>
      value is num && value.isFinite && value >= panelMinWidth;

  Object? _readEnvelope() {
    final raw = _storage.read(storageKey);
    if (raw == null) return null;
    try {
      final envelope = jsonDecode(raw);
      final state = envelope is Map ? envelope['state'] : null;
      return state is Map ? state['widths'] : null;
    } on FormatException {
      return null;
    }
  }

  /// `boundedWidths`: the last 200 valid entries.
  static Map<String, double> _bounded(Object? value) {
    final result = <String, double>{};
    if (value is! Map) return result;
    final entries = value.entries.toList();
    final start = entries.length > maxSavedChats
        ? entries.length - maxSavedChats
        : 0;
    for (final entry in entries.skip(start)) {
      final key = entry.key;
      final width = entry.value;
      if (key is String && key.isNotEmpty && _valid(width)) {
        result[key] = (width as num).toDouble();
      }
    }
    return result;
  }

  void _write() {
    final widths = _hydrated;
    _storage.write(
      storageKey,
      jsonEncode(<String, Object?>{
        'state': <String, Object?>{
          'widths': <String, Object?>{
            for (final entry in widths.entries)
              entry.key: _jsonNumber(entry.value),
          },
        },
        'version': 0,
      }),
    );
  }

  /// Whole widths as integers, like `JSON.stringify` of a JS number.
  static num _jsonNumber(double value) =>
      value == value.roundToDouble() ? value.toInt() : value;
}
