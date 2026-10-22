// Contract tests (L4) against the docker stack. Run with
//   flutter test test_contract --tags contract
// and SIM_BASE_URL (e.g. http://localhost:3001), SIM_TEST_EMAIL,
// SIM_TEST_PASSWORD and SIM_TEST_WORKFLOW_ID in the environment; they are
// skipped otherwise. Failure modes proven here (the client speaks the real
// protocol):
// 1. password sign-in sets the session cookie and get-session returns the
//    user (desktop path: no Origin header, cookie jar);
// 2. socket-token + Socket.IO handshake succeeds with the fresh token;
// 3. execute streams `execution:started` ... terminal `[DONE]`, with the
//    execution id in `X-Execution-Id`;
// 4. reconnect `?from=` replays the buffered events.

@Tags(['contract'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

void main() {
  final baseUrl = Platform.environment['SIM_BASE_URL'];
  final email = Platform.environment['SIM_TEST_EMAIL'];
  final password = Platform.environment['SIM_TEST_PASSWORD'];
  final workflowId = Platform.environment['SIM_TEST_WORKFLOW_ID'];
  final skip = baseUrl == null || email == null || password == null
      ? 'SIM_BASE_URL, SIM_TEST_EMAIL and SIM_TEST_PASSWORD are not set'
      : null;

  late SimHttpClient http;
  late AuthRepository auth;

  setUpAll(() {
    if (skip != null) return;
    http = SimHttpClient(
      baseUrl: baseUrl!,
      cookieStorage: MemoryCookieStorage(),
    );
    auth = AuthRepository(http);
  });

  /// Signs in only when the jar has no live session: the server rate-limits
  /// sign-ins, and a second contract file in the same run otherwise turns the
  /// later requests into 429s.
  Future<void> ensureSignedIn() async {
    final session = await auth.getSession(disableCookieCache: true);
    if (session == null) {
      await auth.signInEmail(email: email!, password: password!);
    }
  }

  /// One bounded retry that honours the server's `Retry-After` on a 429, as a
  /// real client does (capped at 70 s so a misconfigured limit fails fast).
  Future<T> retryOnceOn429<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ExecutionStreamHttpError catch (error) {
      // This error type does not carry the Retry-After header.
      if (error.httpStatus != 429) rethrow;
      await Future<void>.delayed(_retryDelay(null));
      return call();
    } on ApiClientError catch (error) {
      if (error.status != 429) rethrow;
      await Future<void>.delayed(_retryDelay(error.retryAfter));
      return call();
    }
  }

  test(
    'password sign-in sets the cookie and get-session returns the user',
    () async {
      final user = await auth.signInEmail(email: email!, password: password!);
      expect(user?.email.toLowerCase(), email.toLowerCase());
      final session = await auth.getSession(disableCookieCache: true);
      expect(session?.user.email.toLowerCase(), email.toLowerCase());
    },
    skip: skip,
  );

  test('socket-token + Socket.IO handshake succeeds', () async {
    await ensureSignedIn();
    final transport = SocketTransport(
      url: baseUrl,
      tokenProvider: auth.socketToken,
    );
    final connected = transport.states
        .firstWhere((s) => s == RealtimeConnectionState.connected)
        .timeout(const Duration(seconds: 15));
    await transport.connect();
    await connected;
    expect(transport.socketId, isNotNull);
    await transport.dispose();
  }, skip: skip);

  test(
    'execute streams execution:started ... [DONE] and reconnect replays',
    () async {
      if (workflowId == null) {
        markTestSkipped('SIM_TEST_WORKFLOW_ID is not set');
        return;
      }
      await ensureSignedIn();
      final client = ExecutionStreamClient(http);
      final stream = await retryOnceOn429(
        () => client.execute(
          workflowId: workflowId,
          body: {'useDraftState': true, 'isClientSession': true},
        ),
      );
      expect(stream.executionId, isNotNull);
      final events = await stream.events.toList().timeout(
        const Duration(minutes: 2),
      );
      expect(events.first, isA<ExecutionStarted>());
      expect(events.last.isTerminal, isTrue);
      final lastId = events.map((e) => e.eventId).nonNulls.last;

      final replay = await client.reconnect(
        workflowId: workflowId,
        executionId: stream.executionId!,
      );
      final replayed = await replay.events.toList().timeout(
        const Duration(seconds: 30),
      );
      expect(replayed.map((e) => e.eventId).nonNulls.last, lastId);
      expect(replayed.last.isTerminal, isTrue);
    },
    skip: skip,
  );
}

Duration _retryDelay(Duration? retryAfter) {
  const cap = Duration(seconds: 70);
  if (retryAfter == null) return const Duration(seconds: 60);
  return retryAfter > cap ? cap : retryAfter;
}
