import 'dart:async';

/// Timer factory the auth cubits schedule through (auto-verify delay, resend
/// countdown, post-success redirects), so tests drive time by hand instead of
/// waiting on the wall clock.
abstract class AuthTimers {
  Timer schedule(Duration duration, void Function() callback);

  Timer periodic(Duration period, void Function(Timer timer) callback);
}

/// Real `dart:async` timers.
class SystemAuthTimers implements AuthTimers {
  const SystemAuthTimers();

  @override
  Timer schedule(Duration duration, void Function() callback) =>
      Timer(duration, callback);

  @override
  Timer periodic(Duration period, void Function(Timer timer) callback) =>
      Timer.periodic(period, callback);
}
