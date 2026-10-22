// Failure modes of SocketTransport on a fake Socket.IO client:
// 1. every handshake mints a fresh token through the auth callback;
// 2. a session that is gone hands the server a null token and flags it;
// 3. a token mint that fails for a retryable reason ends the attempt,
//    reports the error and reconnects after a delay;
// 4. the socket is created with forceNew only when re-created;
// 5. desktop uses websocket only; the socket URL must be configured there;
// 6. every server event, including unknown ones, reaches the event stream;
// 7. connection state follows connect / disconnect / connect_error.

import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class FakeSocket extends Fake implements io.Socket {
  FakeSocket(this.options);

  final Map<String, dynamic> options;
  final handlers = <String, List<dynamic Function(dynamic)>>{};
  final anyHandlers = <dynamic Function(String, dynamic)>[];
  final emitted = <(String, Object?)>[];
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  String? id;

  @override
  bool connected = false;

  @override
  bool get active => true;

  @override
  dynamic Function() on(String event, dynamic Function(dynamic) handler) {
    handlers.putIfAbsent(event, () => []).add(handler);
    return () {};
  }

  @override
  io.Socket onAny(dynamic Function(String, dynamic) handler) {
    anyHandlers.add(handler);
    return this;
  }

  @override
  io.Socket connect() {
    connectCalls += 1;
    return this;
  }

  @override
  io.Socket disconnect() {
    disconnectCalls += 1;
    connected = false;
    return this;
  }

  @override
  void dispose() {}

  @override
  void emit(String event, [dynamic data]) => emitted.add((event, data));

  /// Runs the auth callback the way the manager does on each handshake.
  Future<Map<dynamic, dynamic>> handshake() async {
    final completer = Completer<Map<dynamic, dynamic>>();
    final auth =
        options['auth'] as void Function(void Function(Map<dynamic, dynamic>));
    auth(completer.complete);
    return completer.future.timeout(const Duration(seconds: 1));
  }

  void fire(String event, [dynamic data]) {
    for (final handler
        in handlers[event] ?? const <dynamic Function(dynamic)>[]) {
      handler(data);
    }
    for (final handler in anyHandlers) {
      handler(event, data);
    }
  }
}

void main() {
  late List<FakeSocket> sockets;
  late List<String> tokens;
  late Exception? tokenError;

  setUp(() {
    sockets = [];
    tokens = [];
    tokenError = null;
  });

  SocketTransport transport() => SocketTransport(
    url: 'http://localhost:3001',
    random: Random(1),
    tokenProvider: () async {
      final error = tokenError;
      if (error != null) throw error;
      final token = 'tok-${tokens.length + 1}';
      tokens.add(token);
      return token;
    },
    socketFactory: (url, options) {
      final socket = FakeSocket(options);
      sockets.add(socket);
      return socket;
    },
  );

  test('every handshake mints a fresh token', () async {
    final t = transport();
    await t.connect();
    expect(await sockets.single.handshake(), {'token': 'tok-1'});
    expect(await sockets.single.handshake(), {'token': 'tok-2'});
    expect(sockets.single.options['withCredentials'], isTrue);
    await t.dispose();
  });

  test('a missing session hands over a null token and flags it', () async {
    tokenError = const SocketTokenAuthRequiredError();
    final t = transport();
    await t.connect();
    expect(await sockets.single.handshake(), {'token': null});
    expect(t.sessionRejected, isTrue);
    await t.dispose();
  });

  test(
    'a retryable mint failure ends the attempt and reconnects later',
    () async {
      tokenError = const SocketTokenUnavailableError(
        retryAfter: Duration(milliseconds: 50),
      );
      final t = transport();
      final errors = <Object>[];
      t.errors.listen(errors.add);
      await t.connect();
      final socket = sockets.single;
      expect(socket.connectCalls, 1);
      await expectLater(socket.handshake(), throwsA(isA<TimeoutException>()));
      expect(socket.disconnectCalls, 1);
      expect(t.state, RealtimeConnectionState.reconnecting);
      expect(errors.single, isA<SocketTokenUnavailableError>());
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(socket.connectCalls, 2);
      await t.dispose();
    },
  );

  test('forceNew only when the socket is re-created', () async {
    final t = transport();
    expect(t.buildOptions()['forceNew'], isNull);
    await t.connect();
    expect(t.buildOptions()['forceNew'], isTrue);
    await t.dispose();
  });

  test('desktop uses websocket only and needs a configured URL', () {
    expect(SocketTransport.defaultTransports(), ['websocket']);
    expect(
      () => SocketTransport(tokenProvider: () async => ''),
      throwsArgumentError,
    );
    expect(transport().buildOptions()['transports'], ['websocket']);
  });

  test(
    'every server event reaches the stream and state follows the socket',
    () async {
      final t = transport();
      final events = <RealtimeEvent>[];
      final states = <RealtimeConnectionState>[];
      t.events.listen(events.add);
      t.states.listen(states.add);
      await t.connect();
      sockets.single
        ..connected = true
        ..id = 'sock-1'
        ..fire('connect')
        ..fire('file-doc:update', {'room': 'x'})
        ..fire('workflow-operation', {'operation': 'add'})
        ..fire('disconnect', 'transport close')
        ..fire('connect_error', 'nope');
      await Future<void>.delayed(Duration.zero);
      final socket = sockets.single;
      expect(t.socketId, 'sock-1');
      expect(events.map((e) => e.name), contains('file-doc:update'));
      expect(events.map((e) => e.name), contains('workflow-operation'));
      expect(states, [
        RealtimeConnectionState.connecting,
        RealtimeConnectionState.connected,
        RealtimeConnectionState.reconnecting,
      ]);
      t.emit('join-workflow', {'workflowId': 'wf'});
      expect(socket.emitted.single.$1, 'join-workflow');
      await t.dispose();
    },
  );
}
