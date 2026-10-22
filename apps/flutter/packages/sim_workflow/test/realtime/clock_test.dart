// Failure modes of FakeClock:
// 1. Timers fire out of due-time order, or ties fire out of scheduling order.
// 2. A timer scheduled by a firing callback inside the elapsed window does not
//    fire in the same elapse call.
// 3. A cancelled timer still fires, or nowMs does not reach the target.

import 'package:sim_workflow/sim_workflow_realtime.dart';
import 'package:test/test.dart';

void main() {
  test('fires due timers in order and advances time', () {
    final clock = FakeClock(startMs: 0);
    final fired = <String>[];
    clock
      ..schedule(const Duration(milliseconds: 20), () => fired.add('b'))
      ..schedule(const Duration(milliseconds: 10), () => fired.add('a'))
      ..schedule(const Duration(milliseconds: 20), () => fired.add('c'))
      ..elapse(const Duration(milliseconds: 20));
    expect(fired, ['a', 'b', 'c']);
    expect(clock.nowMs, 20);
    expect(clock.pendingTimerCount, 0);
  });

  test('a timer scheduled by a callback fires inside the same window', () {
    final clock = FakeClock(startMs: 0);
    final fired = <int>[];
    clock
      ..schedule(const Duration(milliseconds: 5), () {
        fired.add(clock.nowMs);
        clock.schedule(
          const Duration(milliseconds: 5),
          () => fired.add(clock.nowMs),
        );
      })
      ..elapse(const Duration(milliseconds: 10));
    expect(fired, [5, 10]);
  });

  test('a cancelled timer never fires', () {
    final clock = FakeClock(startMs: 0);
    var fired = false;
    clock
      ..schedule(const Duration(seconds: 1), () => fired = true).cancel()
      ..elapse(const Duration(seconds: 2));
    expect(fired, isFalse);
    expect(clock.nowMs, 2000);
  });
}
