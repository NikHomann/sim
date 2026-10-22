import 'dart:async';

/// Time and timers, injected so the queue and session are deterministic.
abstract interface class Clock {
  /// Epoch milliseconds, the `Date.now()` the wire timestamps carry.
  int get nowMs;

  /// Schedules [callback] after [duration]; cancel through the returned timer.
  Timer schedule(Duration duration, void Function() callback);
}

/// The wall clock and `dart:async` timers.
class SystemClock implements Clock {
  /// Creates a wall clock.
  const SystemClock();

  @override
  int get nowMs => DateTime.now().millisecondsSinceEpoch;

  @override
  Timer schedule(Duration duration, void Function() callback) =>
      Timer(duration, callback);
}

/// A clock that only advances through [elapse], firing due timers in order.
class FakeClock implements Clock {
  /// Creates a clock starting at [startMs] epoch milliseconds.
  FakeClock({int startMs = 1700000000000}) : _nowMs = startMs;

  int _nowMs;
  int _sequence = 0;
  final List<_FakeTimer> _timers = [];

  @override
  int get nowMs => _nowMs;

  /// Timers scheduled and not yet fired or cancelled.
  int get pendingTimerCount => _timers.length;

  @override
  Timer schedule(Duration duration, void Function() callback) {
    final timer = _FakeTimer(
      this,
      _nowMs + duration.inMilliseconds,
      _sequence++,
      callback,
    );
    _timers.add(timer);
    return timer;
  }

  /// Advances time by [duration], running every timer that becomes due in
  /// due-time order (ties fire in scheduling order). Timers scheduled by a
  /// callback fire in the same call when they fall inside the window.
  void elapse(Duration duration) {
    final target = _nowMs + duration.inMilliseconds;
    while (true) {
      _FakeTimer? next;
      for (final timer in _timers) {
        if (timer.dueMs > target) continue;
        if (next == null ||
            timer.dueMs < next.dueMs ||
            (timer.dueMs == next.dueMs && timer.sequence < next.sequence)) {
          next = timer;
        }
      }
      if (next == null) break;
      _timers.remove(next);
      _nowMs = next.dueMs;
      next.fire();
    }
    _nowMs = target;
  }

  void _cancel(_FakeTimer timer) => _timers.remove(timer);
}

class _FakeTimer implements Timer {
  _FakeTimer(this._clock, this.dueMs, this.sequence, this._callback);

  final FakeClock _clock;
  final int dueMs;
  final int sequence;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    _active = false;
    _callback();
  }

  @override
  void cancel() {
    _active = false;
    _clock._cancel(this);
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}
