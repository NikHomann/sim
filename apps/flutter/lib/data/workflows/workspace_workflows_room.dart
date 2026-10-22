import 'dart:async';

import 'package:sim_api/sim_api.dart';

/// The `workspace-workflows` invalidation room
/// (`use-workspace-workflows-room.ts:22-29`,
/// `use-workspace-invalidation-room.ts:29-86`, spec §4.6): emit
/// `join-workspace-workflows {workspaceId}` on connect and on every
/// reconnect, retry a retryable join error up to three times with a
/// `1 s · n` backoff, invalidate through the `onChanged` callback on
/// `workspace-workflows-changed`, and emit `leave-workspace-workflows` on
/// dispose.
class WorkspaceWorkflowsRoom {
  WorkspaceWorkflowsRoom({
    required RealtimeTransport transport,
    required this.workspaceId,
    required FutureOr<void> Function(String workspaceId) onChanged,
    Duration retryBase = const Duration(seconds: 1),
    int maxRetries = 3,
  }) : _transport = transport,
       _onChanged = onChanged,
       _retryBase = retryBase,
       _maxRetries = maxRetries;

  static const joinEvent = 'join-workspace-workflows';
  static const joinSuccessEvent = 'join-workspace-workflows-success';
  static const joinErrorEvent = 'join-workspace-workflows-error';
  static const changedEvent = 'workspace-workflows-changed';
  static const leaveEvent = 'leave-workspace-workflows';

  final RealtimeTransport _transport;
  final String workspaceId;
  final FutureOr<void> Function(String workspaceId) _onChanged;
  final Duration _retryBase;
  final int _maxRetries;

  StreamSubscription<RealtimeEvent>? _events;
  StreamSubscription<RealtimeConnectionState>? _states;
  Timer? _retryTimer;
  int _retries = 0;
  bool _joined = false;
  bool _disposed = false;

  bool get isJoined => _joined;
  int get retries => _retries;

  /// Starts listening; joins now when connected, else on connect.
  void start() {
    _events = _transport.events.listen(_onEvent);
    _states = _transport.states.listen((state) {
      if (state == RealtimeConnectionState.connected) {
        _retries = 0;
        _join();
      } else {
        _joined = false;
      }
    });
    if (_transport.state == RealtimeConnectionState.connected) _join();
  }

  void _join() {
    if (_disposed) return;
    _transport.emit(joinEvent, {'workspaceId': workspaceId});
  }

  bool _isMine(Object? payload) =>
      payload is Map && payload['workspaceId'] == workspaceId;

  void _onEvent(RealtimeEvent event) {
    if (_disposed || !_isMine(event.payload)) return;
    switch (event.name) {
      case joinSuccessEvent:
        _joined = true;
        _retries = 0;
      case joinErrorEvent:
        _joined = false;
        final payload = event.payload! as Map;
        if (payload['retryable'] == true && _retries < _maxRetries) {
          _retries += 1;
          _retryTimer?.cancel();
          _retryTimer = Timer(_retryBase * _retries, _join);
        }
      case changedEvent:
        unawaited(Future.sync(() => _onChanged(workspaceId)));
    }
  }

  /// Leaves the room and releases the listeners.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    unawaited(_events?.cancel());
    unawaited(_states?.cancel());
    if (_transport.state == RealtimeConnectionState.connected) {
      _transport.emit(leaveEvent, {'workspaceId': workspaceId});
    }
    _joined = false;
  }
}
