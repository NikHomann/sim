import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';

/// How often a countdown re-reads the clock (`COUNTDOWN_TICK_MS`,
/// `tool-call-title.ts:16`): under a second so the number turns over close
/// to when it should.
const Duration chatCountdownTick = Duration(milliseconds: 250);

/// Rebuilds only its own subtree every [chatCountdownTick] with the
/// milliseconds elapsed since [ChatCountdown.startedAtMs] (`useElapsedMs`):
/// a row mounting mid-pause resumes mid-countdown; without a start it counts
/// from mount.
class ChatCountdownBuilder extends StatefulWidget {
  const ChatCountdownBuilder({
    required this.countdown,
    required this.builder,
    super.key,
  });

  final ChatCountdown countdown;
  final Widget Function(BuildContext context, int elapsedMs) builder;

  @override
  State<ChatCountdownBuilder> createState() => _ChatCountdownBuilderState();
}

class _ChatCountdownBuilderState extends State<ChatCountdownBuilder> {
  Timer? _timer;
  late int _anchor;

  int get _now => clock.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _anchor = widget.countdown.startedAtMs ?? _now;
    _timer = Timer.periodic(chatCountdownTick, (_) => setState(() {}));
  }

  @override
  void didUpdateWidget(ChatCountdownBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    final started = widget.countdown.startedAtMs;
    if (started != oldWidget.countdown.startedAtMs) {
      _anchor = started ?? _now;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now - _anchor);
}
