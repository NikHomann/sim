import 'dart:async';

import 'package:sim_workflow/src/realtime/events.dart';

/// Lifecycle of the underlying socket, as Socket.IO reports it.
enum ConnectionState {
  /// No socket, or closed without auto-reconnect.
  disconnected,

  /// The first handshake is in flight.
  connecting,

  /// The socket is open.
  connected,

  /// The socket dropped and the manager is retrying.
  reconnecting,
}

/// A connection to the realtime server.
///
/// `sim_api` implements this over `socket_io_client`; tests use
/// [FakeTransport]. The transport decodes every incoming event through
/// [ServerEvent.decode], so unknown and malformed events reach consumers as
/// [UnknownEvent] and [MalformedEvent] instead of throwing.
abstract interface class RealtimeTransport {
  /// The current connection state.
  ConnectionState get state;

  /// The socket id the server assigned, while connected.
  String? get socketId;

  /// Every state change, as a broadcast stream.
  Stream<ConnectionState> get connectionStates;

  /// Every decoded server event, as a broadcast stream.
  Stream<ServerEvent> get events;

  /// Opens the socket (minting a fresh one-time token per attempt upstream).
  Future<void> connect();

  /// Closes the socket without auto-reconnect.
  Future<void> disconnect();

  /// Emits a raw `(event, payload)` pair. Returns whether the payload was
  /// handed to the socket; a `false` means the caller should keep the
  /// operation pending rather than wait for a confirmation.
  bool emit(String event, Object? payload);
}

/// Typed emit helper.
extension RealtimeTransportSend on RealtimeTransport {
  /// Emits [event] under its wire name.
  bool send(ClientEvent event) => emit(event.name, event.toJson());
}

/// One emitted event, as recorded by [FakeTransport].
class EmittedEvent {
  /// Creates the record.
  const EmittedEvent(this.name, this.payload);

  /// The event name.
  final String name;

  /// The payload as handed to [RealtimeTransport.emit].
  final Object? payload;

  @override
  String toString() => 'EmittedEvent($name, $payload)';
}

/// An in-memory transport for tests: records emits, lets the test play the
/// server, and flips connection state on demand.
class FakeTransport implements RealtimeTransport {
  /// Creates a disconnected transport.
  FakeTransport({this.socketIdOnConnect = 'socket-1'});

  /// The socket id reported after [connect].
  final String socketIdOnConnect;

  final StreamController<ConnectionState> _states =
      StreamController<ConnectionState>.broadcast(sync: true);
  final StreamController<ServerEvent> _events =
      StreamController<ServerEvent>.broadcast(sync: true);

  /// Every emit, in order.
  final List<EmittedEvent> emitted = [];

  ConnectionState _state = ConnectionState.disconnected;
  String? _socketId;

  /// When `false`, [emit] records nothing and returns `false`, modelling a
  /// transport that refuses to buffer while offline.
  bool acceptEmitsWhileDisconnected = true;

  @override
  ConnectionState get state => _state;

  @override
  String? get socketId => _socketId;

  @override
  Stream<ConnectionState> get connectionStates => _states.stream;

  @override
  Stream<ServerEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    setState(ConnectionState.connecting);
    setState(ConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    setState(ConnectionState.disconnected);
  }

  @override
  bool emit(String event, Object? payload) {
    if (_state != ConnectionState.connected && !acceptEmitsWhileDisconnected) {
      return false;
    }
    emitted.add(EmittedEvent(event, payload));
    return true;
  }

  /// Emits of [name], in order.
  List<EmittedEvent> emittedNamed(String name) => [
    for (final e in emitted)
      if (e.name == name) e,
  ];

  /// Moves to [state], publishing the change. Connecting assigns a socket id;
  /// leaving the connected state clears it.
  void setState(ConnectionState state) {
    if (state == ConnectionState.connected) {
      _socketId = socketIdOnConnect;
    } else {
      _socketId = null;
    }
    _state = state;
    _states.add(state);
  }

  /// Delivers a raw server event through the decoder, as the socket would.
  void receive(String name, Object? data) {
    _events.add(ServerEvent.decode(name, data));
  }

  /// Delivers an already decoded server event.
  void push(ServerEvent event) => _events.add(event);

  /// Closes the streams.
  Future<void> dispose() async {
    await _states.close();
    await _events.close();
  }
}
