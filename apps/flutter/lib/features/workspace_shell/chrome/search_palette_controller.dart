import 'package:flutter/foundation.dart';

/// The open state of `useSearchModalStore` (`stores/modals/search/store.ts`):
/// one global flag toggled by `Mod+K`, the sidebar's search chip and the
/// desktop `open-search` command. The palette widget listens to it; the
/// chrome owns it (registered in the locator by
/// `registerWorkspaceShellServices`). Reset to closed on sign-out.
class SearchPaletteController extends ChangeNotifier {
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  void setOpen({required bool open}) {
    if (_isOpen == open) return;
    _isOpen = open;
    notifyListeners();
  }

  void open() => setOpen(open: true);

  void close() => setOpen(open: false);

  void toggle() => setOpen(open: !_isOpen);

  /// Store reset (sign-out).
  void reset() => close();
}
