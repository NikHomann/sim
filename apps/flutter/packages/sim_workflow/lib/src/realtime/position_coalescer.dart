import 'dart:async';

import 'package:sim_workflow/src/realtime/clock.dart';
import 'package:sim_workflow/src/realtime/events.dart';
import 'package:sim_workflow/src/realtime/operations.dart';

/// Coalesces uncommitted `update-position` emits per block on a 33 ms timer.
///
/// Port of the `pendingPositionUpdates` / `positionUpdateTimeouts` maps in
/// `socket-provider.tsx`'s `emitWorkflowOperation`: a frame with
/// `commit: false` replaces the block's pending frame and the latest one is
/// sent when the timer fires; a `commit: true` (or absent) move is sent at
/// once and drops the block's pending frame. Every other operation passes
/// straight through to the `send` callback.
class PositionUpdateCoalescer {
  /// Creates a coalescer that forwards to [send].
  PositionUpdateCoalescer({
    required Clock clock,
    required bool Function(WorkflowOperationEvent event) send,
    this.window = const Duration(milliseconds: 33),
  }) : _clock = clock,
       _send = send;

  /// The coalescing window (33 ms upstream).
  final Duration window;

  final Clock _clock;
  final bool Function(WorkflowOperationEvent event) _send;
  final Map<String, WorkflowOperationEvent> _pending = {};
  final Map<String, Timer> _timers = {};

  /// Block ids with a frame waiting for the timer.
  Iterable<String> get pendingBlockIds => _pending.keys;

  /// Emits [event], coalescing uncommitted position frames. Returns whether
  /// the event was accepted (sent or scheduled), mirroring the emit contract.
  bool emit(WorkflowOperationEvent event) {
    final operation = event.operation;
    if (operation is! UpdatePositionOperation) return _send(event);

    final blockId = operation.id;
    if (operation.commit) {
      final sent = _send(event);
      _pending.remove(blockId);
      _timers.remove(blockId)?.cancel();
      return sent;
    }

    _pending[blockId] = event;
    _timers.putIfAbsent(
      blockId,
      () => _clock.schedule(window, () {
        final latest = _pending.remove(blockId);
        _timers.remove(blockId);
        if (latest != null) _send(latest);
      }),
    );
    return true;
  }

  /// Drops every pending frame and timer (room switch, leave, dispose).
  void clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pending.clear();
  }
}
