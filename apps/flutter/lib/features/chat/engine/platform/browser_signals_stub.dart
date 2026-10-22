import 'package:sim_app/features/chat/engine/platform/browser_signals.dart';

/// The device zone off the web: an IANA name is not available from
/// `dart:core`, so a whole-hour offset maps to `Etc/GMT∓N` (POSIX signs are
/// inverted) and anything else to `UTC`.
String deviceTimeZone() {
  final offset = DateTime.now().timeZoneOffset;
  if (offset == Duration.zero) return 'UTC';
  if (offset.inMinutes % 60 != 0) return 'UTC';
  final hours = offset.inHours;
  return hours > 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}';
}

/// Desktop has no `navigator.onLine`; a failed request tells the engine.
bool deviceIsOnline() => true;

/// Desktop has no page visibility events; the shell may call
/// `ChatSessionCubit.recoverActiveStream` from its lifecycle listener.
Stream<BrowserReturnReason> browserReturnSignals() => const Stream.empty();

/// `online` events (held sends are released when they fire).
Stream<void> onlineSignals() => const Stream.empty();
