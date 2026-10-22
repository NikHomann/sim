import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sim_design/sim_design.dart';

/// `useAnimatedPlaceholder` (`hooks/use-animated-placeholder.ts`): types a
/// suffix after "Ask Sim to " at 60ms/char, holds 2000ms, deletes at
/// 35ms/char, waits 400ms, next suffix, loop. With motion disabled the
/// static prefix stays.
class AnimatedPlaceholderText extends ValueNotifier<String> {
  AnimatedPlaceholderText({bool enabled = true}) : super(prefix) {
    if (enabled && !SimMotion.disabled) _schedule(typeDelay);
  }

  static const String prefix = 'Ask Sim to ';
  static const List<String> suffixes = [
    'respond to my emails...',
    'find and track leads...',
    'DM me Linear updates on Slack...',
    'track GitHub commits...',
  ];
  static const Duration typeDelay = Duration(milliseconds: 60);
  static const Duration deleteDelay = Duration(milliseconds: 35);
  static const Duration holdDelay = Duration(milliseconds: 2000);
  static const Duration gapDelay = Duration(milliseconds: 400);

  Timer? _timer;
  int _suffix = 0;
  int _chars = 0;
  _Phase _phase = _Phase.typing;

  void _schedule(Duration delay) {
    _timer = Timer(delay, () => _schedule(_tick()));
  }

  Duration _tick() {
    final suffix = suffixes[_suffix];
    switch (_phase) {
      case _Phase.typing:
        _chars++;
        value = prefix + suffix.substring(0, _chars);
        if (_chars >= suffix.length) {
          _phase = _Phase.paused;
          return holdDelay;
        }
        return typeDelay;
      case _Phase.paused:
        _phase = _Phase.deleting;
        return deleteDelay;
      case _Phase.deleting:
        _chars--;
        value = prefix + suffix.substring(0, _chars);
        if (_chars <= 0) {
          _phase = _Phase.waiting;
          return gapDelay;
        }
        return deleteDelay;
      case _Phase.waiting:
        _suffix = (_suffix + 1) % suffixes.length;
        _chars = 0;
        _phase = _Phase.typing;
        return typeDelay;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

enum _Phase { typing, paused, deleting, waiting }
