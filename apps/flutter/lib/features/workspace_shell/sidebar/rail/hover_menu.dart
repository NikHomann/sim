import 'dart:async';

import 'package:flutter/foundation.dart';

/// `CLOSE_DELAY_MS` of `use-hover-menu.ts`.
const Duration hoverMenuCloseDelay = Duration(milliseconds: 150);

/// `useHoverMenu`: opens on trigger enter, closes [hoverMenuCloseDelay]
/// after the pointer has left every hover region (trigger, content, and the
/// content's submenus), never while [isLocked] (a context menu or an inline
/// rename holds it open).
class HoverMenuController extends ChangeNotifier {
  HoverMenuController({this.closeDelay = hoverMenuCloseDelay});

  final Duration closeDelay;

  bool _open = false;
  bool _locked = false;
  bool _inside = false;
  Timer? _closeTimer;

  bool get isOpen => _open;
  bool get isLocked => _locked;

  void _setOpen(bool value) {
    if (_open == value) return;
    _open = value;
    notifyListeners();
  }

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _scheduleClose() {
    if (_locked) return;
    _cancelClose();
    _closeTimer = Timer(closeDelay, () {
      _closeTimer = null;
      if (!_locked && !_inside) _setOpen(false);
    });
  }

  /// `handleTriggerMouseEnter`. Notifies even when already open, so a
  /// freshly mounted trigger whose controller says "open" still builds its
  /// flyout.
  void open() {
    _inside = true;
    _cancelClose();
    if (_open) {
      notifyListeners();
    } else {
      _setOpen(true);
    }
  }

  /// Back to closed and unlocked, without notifying: the trigger that owned
  /// the open flyout is gone (a rail collapse / expand round trip).
  void reset() {
    _cancelClose();
    _open = false;
    _locked = false;
    _inside = false;
  }

  /// Whether the pointer is over any hover region, reported on every
  /// pointer move while open. Leaving starts the close delay; coming back
  /// cancels it.
  void setPointerInside({required bool inside}) {
    if (inside == _inside) {
      if (!inside && _open && _closeTimer == null) _scheduleClose();
      return;
    }
    _inside = inside;
    if (inside) {
      _cancelClose();
    } else if (_open) {
      _scheduleClose();
    }
  }

  /// `close`: immediate unless locked.
  void close() {
    if (_locked) return;
    _cancelClose();
    _inside = false;
    _setOpen(false);
  }

  /// `setLocked`: locking opens and pins the menu; unlocking closes it
  /// unless the pointer is still over it.
  void setLocked({required bool locked}) {
    if (_locked == locked) return;
    _locked = locked;
    _cancelClose();
    if (locked) {
      _setOpen(true);
    } else if (!_inside) {
      _setOpen(false);
    }
  }

  @override
  void dispose() {
    _cancelClose();
    super.dispose();
  }
}
