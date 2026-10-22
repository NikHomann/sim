import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';
import 'package:sim_api/src/auth/auth_repository.dart';
import 'package:sim_api/src/client/platform/origin.dart' as origin;
import 'package:sim_api/src/client/retry.dart';
import 'package:sim_api/src/realtime/realtime_transport.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

const _authRetryBaseMs = 1000;
const _socketTokenRetryAfterJitter = 0.25;

/// Mints the one-time socket token for one handshake
/// (`AuthRepository.socketToken`).
typedef SocketTokenProvider = Future<String> Function();

/// Builds the Socket.IO client; injectable so tests can stand in a fake.
typedef SocketFactory =
    io.Socket Function(String url, Map<String, dynamic> options);

/// [RealtimeTransport] over `socket_io_client`, mirroring the connection
/// setup of `app/workspace/providers/socket-provider.tsx`: a fresh token per
/// connect through the auth callback, `forceNew` when the socket is
/// re-created, infinite reconnection with 1 s to 30 s delays, 10 s connect
/// timeout, `withCredentials`, websocket + polling on web and websocket only
/// on desktop (the server lists websocket first).
class SocketTransport implements RealtimeTransport {
  SocketTransport({
    required SocketTokenProvider tokenProvider,
    String? url,
    List<String>? transports,
    SocketFactory? socketFactory,
    Random? random,
    Logger? logger,
  }) : _tokenProvider = tokenProvider,
       url = url ?? defaultSocketUrl(),
       transports = transports ?? defaultTransports(),
       _socketFactory = socketFactory ?? _defaultFactory,
       _random = random ?? Random(),
       _log = logger ?? Logger('sim_api.socket');

  /// The socket origin: the page origin on web (the dev proxy and Caddy
  /// forward `/socket.io`), which desktop must configure explicitly.
  static String defaultSocketUrl() {
    final page = origin.resolvePageOrigin();
    if (page == null) throw ArgumentError.notNull('url');
    return page;
  }

  static List<String> defaultTransports() =>
      kIsWeb ? const ['websocket', 'polling'] : const ['websocket'];

  static io.Socket _defaultFactory(String url, Map<String, dynamic> options) =>
      io.io(url, options);

  final String url;
  final List<String> transports;
  final SocketTokenProvider _tokenProvider;
  final SocketFactory _socketFactory;
  final Random _random;
  final Logger _log;

  final _states = StreamController<RealtimeConnectionState>.broadcast();
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _errors = StreamController<Object>.broadcast();

  io.Socket? _socket;
  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;
  var _createdBefore = false;
  var _authAttemptGeneration = 0;
  var _tokenRetryAttempts = 0;
  Timer? _authRetryTimer;
  var _disposed = false;

  /// Whether the last handshake was refused because the session is gone.
  bool sessionRejected = false;

  @override
  RealtimeConnectionState get state => _state;

  @override
  Stream<RealtimeConnectionState> get states => _states.stream;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  String? get socketId => _socket?.id;

  void _setState(RealtimeConnectionState next) {
    if (_state == next) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  /// The options the socket is created with (exposed for tests).
  Map<String, dynamic> buildOptions() {
    final builder = io.OptionBuilder()
        .setTransports(transports)
        .enableWithCredentials()
        .disableAutoConnect()
        .setReconnectionAttempts(double.infinity)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(30000)
        .setTimeout(10000)
        .setAuthFn(_auth);
    if (_createdBefore) builder.enableForceNew();
    return builder.build();
  }

  @override
  Future<void> connect() async {
    if (_disposed) throw StateError('SocketTransport is disposed');
    final existing = _socket;
    if (existing != null) {
      if (existing.connected) return;
      _setState(RealtimeConnectionState.connecting);
      existing.connect();
      return;
    }
    final socket = _socketFactory(url, buildOptions());
    _createdBefore = true;
    _socket = socket;
    socket
      ..onConnect((_) {
        _tokenRetryAttempts = 0;
        _setState(RealtimeConnectionState.connected);
      })
      ..onDisconnect((reason) {
        _setState(
          socket.active
              ? RealtimeConnectionState.reconnecting
              : RealtimeConnectionState.disconnected,
        );
      })
      ..onConnectError((error) {
        _errors.add(error is Object ? error : 'connect_error');
        _setState(
          socket.active
              ? RealtimeConnectionState.reconnecting
              : RealtimeConnectionState.disconnected,
        );
      })
      ..onAny((event, data) {
        if (!_events.isClosed) _events.add(RealtimeEvent(event, data));
      });
    _setState(RealtimeConnectionState.connecting);
    socket.connect();
  }

  Future<void> _auth(void Function(Map<dynamic, dynamic> auth) callback) async {
    sessionRejected = false;
    final attempt = ++_authAttemptGeneration;
    final socket = _socket;
    try {
      final token = await _tokenProvider();
      callback({'token': token});
    } on SocketTokenAuthRequiredError {
      // The server rejects the null token with "Authentication required",
      // which the app turns into re-authentication.
      sessionRejected = true;
      callback({'token': null});
    } on Object catch (error) {
      _log.warning('Failed to generate fresh token for connection', error);
      if (attempt != _authAttemptGeneration ||
          socket == null ||
          !socket.active ||
          socket.connected) {
        return;
      }
      // Withholding the callback would park the transport until the server's
      // connect timeout, so end this attempt and reconnect after a delay.
      _tokenRetryAttempts += 1;
      final retryAfter = error is SocketTokenUnavailableError
          ? error.retryAfter
          : null;
      final backoff = backoffWithJitter(
        _tokenRetryAttempts,
        null,
        baseMs: _authRetryBaseMs,
        random: _random,
      );
      final delay = retryAfter == null
          ? backoff
          : Duration(
              milliseconds: max(
                backoff.inMilliseconds,
                (retryAfter.inMilliseconds *
                        (1 +
                            _socketTokenRetryAfterJitter *
                                _random.nextDouble()))
                    .round(),
              ),
            );
      socket.disconnect();
      _setState(RealtimeConnectionState.reconnecting);
      _errors.add(error);
      _authRetryTimer?.cancel();
      _authRetryTimer = Timer(delay, () {
        _authRetryTimer = null;
        if (_disposed || _socket != socket) return;
        socket.connect();
      });
    }
  }

  @override
  Future<void> disconnect() async {
    _authRetryTimer?.cancel();
    _authRetryTimer = null;
    _socket?.disconnect();
    _setState(RealtimeConnectionState.disconnected);
  }

  @override
  void emit(String event, [Object? payload]) {
    final socket = _socket;
    if (socket == null) throw StateError('not connected');
    socket.emit(event, payload);
  }

  @override
  Future<Object?> emitWithAck(
    String event,
    Object? payload, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    final socket = _socket;
    if (socket == null) throw StateError('not connected');
    final completer = Completer<Object?>();
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('ack for $event', timeout));
      }
    });
    socket.emitWithAck(
      event,
      payload,
      ack: (dynamic data) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(data);
      },
    );
    return completer.future;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _authRetryTimer?.cancel();
    _socket?.dispose();
    _socket = null;
    _setState(RealtimeConnectionState.disconnected);
    await _states.close();
    await _events.close();
    await _errors.close();
  }
}
