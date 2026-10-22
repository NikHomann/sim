import 'package:flutter/foundation.dart';

/// `FULLSCREEN_SUFFIXES` (`workspace-chrome.tsx:27`).
const List<String> fullscreenSuffixes = <String>['/upgrade'];

/// Whether the chrome hides its sidebar for [path].
bool isFullscreenPath(String path) =>
    fullscreenSuffixes.any((suffix) => path.endsWith(suffix));

/// `useFullscreenOriginStore`: the last non-fullscreen pathname, so the
/// upgrade page's Back control can return there (Phase 5 consumer).
class FullscreenOriginStore extends ValueNotifier<String?> {
  FullscreenOriginStore() : super(null);

  /// `setOrigin`, called by the chrome for every non-fullscreen path.
  // ignore: use_setters_to_change_properties, mirrors the store action name
  void setOrigin(String path) => value = path;

  /// Store reset (sign-out).
  void reset() => value = null;
}
