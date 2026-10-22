import 'package:sim_api/src/storage/platform/shared_web_state_platform.dart'
    as platform;

/// A change of one shared key, from another tab (`storage` event) or this
/// one (the React theme util dispatches a synthetic event on write).
class SharedStateChange {
  const SharedStateChange({required this.key, this.newValue});

  final String key;
  final String? newValue;
}

/// The keys both apps read and write (plan §4.1): `sim-theme` and
/// `sidebar-state` in `localStorage`, the `sidebar_collapsed` cookie. On web
/// they go through `package:web` so the React and Flutter apps agree; on
/// desktop they live in memory (the app persists them its own way).
abstract class SharedWebState {
  /// `localStorage['sim-theme']`: `light`, `dark` or `system`.
  static const themeKey = 'sim-theme';

  /// `localStorage['sidebar-state']`: zustand persist envelope
  /// `{"state":{"sidebarWidth":N},"version":0}`.
  static const sidebarStateKey = 'sidebar-state';

  /// Cookie `sidebar_collapsed=1|0; path=/; max-age=31536000; samesite=lax`,
  /// the single source of truth for collapse upstream.
  static const sidebarCollapsedCookie = 'sidebar_collapsed';

  String? readTheme();
  void writeTheme(String? theme);

  int? readSidebarWidth();
  void writeSidebarWidth(int width);

  /// Removes `sidebar-state` (sign-out wipes it upstream).
  void clearSidebarWidth();

  bool readSidebarCollapsed();
  void writeSidebarCollapsed({required bool collapsed});

  /// Changes of [themeKey] and [sidebarStateKey]; empty on desktop.
  Stream<SharedStateChange> get changes;
}

/// The implementation for the running platform.
SharedWebState createSharedWebState() => platform.createSharedWebState();

/// Reads the width out of the persist envelope; `null` when the shape is
/// not the one zustand writes.
int? sidebarWidthFromEnvelope(Object? envelope) {
  if (envelope is! Map) return null;
  final state = envelope['state'];
  if (state is! Map) return null;
  final width = state['sidebarWidth'];
  return width is num ? width.toInt() : null;
}

/// The legacy `isCollapsed` of an old persist envelope, if any.
bool? legacyCollapsedFromEnvelope(Object? envelope) {
  if (envelope is! Map) return null;
  final state = envelope['state'];
  if (state is! Map) return null;
  final collapsed = state['isCollapsed'];
  return collapsed is bool ? collapsed : null;
}

/// Whether the `sidebar_collapsed` cookie is set at all.
bool hasSidebarCollapsedCookie(String cookie) => RegExp(
  '(?:^|;\\s*)${SharedWebState.sidebarCollapsedCookie}=',
).hasMatch(cookie);

/// Reads the strict `=1` value out of a cookie header string, as
/// `readSidebarCollapsedCookie` does upstream.
bool sidebarCollapsedFromCookie(String cookie) {
  final match = RegExp(
    '(?:^|;\\s*)${SharedWebState.sidebarCollapsedCookie}=([^;]*)',
  ).firstMatch(cookie);
  return match?.group(1) == '1';
}

/// In-memory [SharedWebState] for desktop and tests.
class MemorySharedWebState implements SharedWebState {
  String? _theme;
  int? _width;
  bool _collapsed = false;

  @override
  String? readTheme() => _theme;

  @override
  void writeTheme(String? theme) => _theme = theme;

  @override
  int? readSidebarWidth() => _width;

  @override
  void writeSidebarWidth(int width) => _width = width;

  @override
  void clearSidebarWidth() => _width = null;

  @override
  bool readSidebarCollapsed() => _collapsed;

  @override
  void writeSidebarCollapsed({required bool collapsed}) =>
      _collapsed = collapsed;

  @override
  Stream<SharedStateChange> get changes => const Stream.empty();
}
