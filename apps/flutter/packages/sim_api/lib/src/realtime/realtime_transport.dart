/// Connection state of a [RealtimeTransport].
enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// One decoded server event (`join-workflow-success`, `workflow-operation`,
/// `presence-update`, ...). [payload] is the decoded JSON argument (a map
/// for every documented event; a list when the server sent several
/// arguments).
class RealtimeEvent {
  const RealtimeEvent(this.name, this.payload);

  final String name;
  final Object? payload;

  @override
  String toString() => 'RealtimeEvent($name)';
}

/// The transport the operation queue in `sim_workflow` will drive. Kept
/// minimal so the canonical interface that package provides later can be
/// adapted onto it.
abstract class RealtimeTransport {
  RealtimeConnectionState get state;
  Stream<RealtimeConnectionState> get states;

  /// Every server event, including ones the client does not know (Yjs
  /// file-doc rooms), so unknown events are tolerated by construction.
  Stream<RealtimeEvent> get events;

  /// Connection failures (`connect_error`, token minting failures).
  Stream<Object> get errors;

  /// The server-assigned socket id while connected.
  String? get socketId;

  Future<void> connect();
  Future<void> disconnect();

  void emit(String event, [Object? payload]);

  /// Emits and resolves with the server's acknowledgement.
  Future<Object?> emitWithAck(
    String event,
    Object? payload, {
    Duration timeout = const Duration(seconds: 10),
  });

  /// Disconnects and releases every listener.
  Future<void> dispose();
}
