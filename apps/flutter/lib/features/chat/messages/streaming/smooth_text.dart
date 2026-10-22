import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Pure port of `useSmoothText` (`hooks/use-smooth-text.ts`): a time-based
/// paced reveal of a growing string. Each frame earns a character budget
/// from elapsed time at a rate that drains the backlog over
/// [drainHorizonMs] (clamped to [minCps]..[maxCps]) and releases text one
/// word/punctuation boundary at a time, publishing at most 60 times a
/// second. The widget layer drives [tick] from a ticker.
class SmoothTextPacer {
  SmoothTextPacer({required String content, required bool streaming})
    : _content = content,
      _streaming = streaming,
      _revealed = streaming && content.length <= resumeSkipThreshold
          ? 0
          : content.length;

  /// Content longer than this when streaming begins shows immediately.
  static const int resumeSkipThreshold = 60;
  static const double drainHorizonMs = 400;
  static const double minCps = 45;
  static const double maxCps = 2400;
  static const double publishIntervalMs = 1000 / 60;
  static const double maxFrameMs = 100;
  static const int lookahead = 24;
  static final RegExp _snap = RegExp(r'[\s.,!?;:)\]]');

  String _content;
  bool _streaming;
  int _revealed;
  double _budget = 0;
  double _publishBudgetMs = 0;
  double? _completionRemainingMs;

  String get content => _content;
  bool get streaming => _streaming;
  int get revealed => math.min(_revealed, _content.length);
  bool get hasBacklog => _revealed < _content.length;
  String get visible =>
      hasBacklog ? _content.substring(0, _revealed) : _content;

  /// Feeds a new [content]/[streaming] pair (the hook's render inputs).
  void update(String content, {required bool streaming}) {
    final changed = content != _content;
    final wasStreaming = _streaming;
    if (streaming &&
        !wasStreaming &&
        content.length > resumeSkipThreshold &&
        _revealed < content.length) {
      _revealed = content.length;
    }
    if (streaming) {
      _completionRemainingMs = null;
    } else if (changed || wasStreaming) {
      _completionRemainingMs = drainHorizonMs;
    }
    _content = content;
    _streaming = streaming;
    if (_revealed > content.length) {
      _revealed = content.length;
      _budget = 0;
    }
  }

  /// User Stop: reveal everything now.
  void snap() {
    _revealed = _content.length;
    _budget = 0;
  }

  static double _drainRate(int remaining) =>
      ((remaining * 1000) / drainHorizonMs).clamp(minCps, maxCps);

  int _nextIndex(int start, double budget) {
    final limit = math.min(_content.length, start + budget.floor());
    for (var i = limit; i > start; i--) {
      if (_snap.hasMatch(_content[i - 1])) return i;
    }
    if (limit >= math.min(_content.length, start + lookahead)) return limit;
    return start;
  }

  /// Advances one frame of [elapsed]; returns whether [visible] changed.
  bool tick(Duration elapsed) {
    final target = _content.length;
    if (_revealed >= target) return false;
    final dt = math.min(elapsed.inMicroseconds / 1000, maxFrameMs);
    final completion = _completionRemainingMs;
    final rate = completion == null
        ? _drainRate(target - _revealed)
        : math.max(
            minCps,
            ((target - _revealed - _budget) * 1000) / math.max(1, completion),
          );
    _budget += rate * dt / 1000;
    _publishBudgetMs += dt;
    if (completion != null) {
      _completionRemainingMs = math.max(0, completion - dt);
    }
    final finishing = _completionRemainingMs == 0;
    final canPublish = finishing || _publishBudgetMs >= publishIntervalMs - 0.5;
    final next = finishing
        ? target
        : canPublish
        ? _nextIndex(_revealed, _budget)
        : _revealed;
    if (next <= _revealed) return false;
    _budget = math.max(0, _budget - (next - _revealed));
    _publishBudgetMs = _publishBudgetMs < publishIntervalMs
        ? 0
        : _publishBudgetMs % publishIntervalMs;
    _revealed = next;
    return true;
  }
}

/// Global snap signal (`snapAllSmoothText`): the engine calls [snapAll] on
/// user Stop so every mounted paced reveal jumps to its full text.
abstract final class SmoothTextSnap {
  static final ValueNotifier<int> epoch = ValueNotifier<int>(0);

  static void snapAll() => epoch.value++;
}
