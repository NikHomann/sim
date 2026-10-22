import 'dart:async';

import 'package:clock/clock.dart';

/// Port of `createStableFlagController` (`hooks/use-stable-flag.ts:26-96`):
/// an anti-flicker boolean. The rising edge waits [delay] of continuous
/// `true`; once shown, the flag stays on for at least [minVisible].
/// `Timer` and `clock.now()` are the ambient ones, so `fakeAsync` drives
/// it in tests.
class StableFlagController {
  StableFlagController(
    this._onChange, {
    this.delay = Duration.zero,
    this.minVisible = Duration.zero,
  });

  final void Function({required bool active}) _onChange;
  final Duration delay;
  final Duration minVisible;

  bool _active = false;
  DateTime? _shownAt;
  Timer? _showTimer;
  Timer? _hideTimer;

  bool get active => _active;

  void _clearShow() {
    _showTimer?.cancel();
    _showTimer = null;
  }

  void _clearHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _show() {
    _showTimer = null;
    _shownAt = clock.now();
    _active = true;
    _onChange(active: true);
  }

  void _hide() {
    _hideTimer = null;
    _shownAt = null;
    _active = false;
    _onChange(active: false);
  }

  /// Idempotent: feeding the same value repeatedly is safe.
  void setValue({required bool value}) {
    if (value) {
      _clearHide();
      if (_active || _showTimer != null) return;
      if (delay <= Duration.zero) {
        _show();
        return;
      }
      _showTimer = Timer(delay, _show);
      return;
    }
    _clearShow();
    if (!_active || _hideTimer != null) return;
    final shownAt = _shownAt;
    final elapsed = shownAt == null
        ? minVisible
        : clock.now().difference(shownAt);
    final remaining = minVisible - elapsed;
    if (remaining <= Duration.zero) {
      _hide();
      return;
    }
    _hideTimer = Timer(remaining, _hide);
  }

  void dispose() {
    _clearShow();
    _clearHide();
  }
}
