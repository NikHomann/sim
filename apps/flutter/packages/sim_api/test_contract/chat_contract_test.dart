// Chat engine contract test (L4) against the docker stack. Run with
//   flutter test test_contract/chat_contract_test.dart --tags contract
// and SIM_BASE_URL, SIM_TEST_EMAIL, SIM_TEST_PASSWORD, SIM_TEST_WORKSPACE_ID
// in the environment; skipped otherwise. Failure modes proven here (spec
// chat-engine §2, §3.1, §3.10):
// 1. `POST /api/mothership/chat` "hi" on a new chat is admitted (200 SSE)
//    and names the chat in `x-mothership-chat-id`;
// 2. every frame passes the React-strict envelope validation;
// 3. the first envelope is `session{kind:'chat'}`;
// 4. the turn ends either with text + `complete{complete}` (worker
//    reachable, `COPILOT_API_KEY` set) or with `error` + `complete{error}`
//    (the §3.10 path without a key);
// 5. cursors increase strictly within the stream;
// 6. the reconnect batch for the finished stream is terminal and its events
//    validate; the new chat is deleted afterwards (cleanup).

@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

void main() {
  final baseUrl = Platform.environment['SIM_BASE_URL'];
  final email = Platform.environment['SIM_TEST_EMAIL'];
  final password = Platform.environment['SIM_TEST_PASSWORD'];
  final workspaceId = Platform.environment['SIM_TEST_WORKSPACE_ID'] ?? '';
  final skip =
      baseUrl == null ||
          email == null ||
          password == null ||
          workspaceId.isEmpty
      ? 'SIM_BASE_URL, SIM_TEST_EMAIL, SIM_TEST_PASSWORD and '
            'SIM_TEST_WORKSPACE_ID are not set'
      : null;

  late SimHttpClient http;
  late MothershipClient client;

  setUpAll(() async {
    if (skip != null) return;
    http = SimHttpClient(
      baseUrl: baseUrl!,
      cookieStorage: MemoryCookieStorage(),
    );
    final auth = AuthRepository(http);
    final session = await auth.getSession(disableCookieCache: true);
    if (session == null) {
      await auth.signInEmail(email: email!, password: password!);
    }
    client = MothershipClient(http);
  });

  test(
    'hi: session frame, then text+complete or error+complete',
    () async {
      final userMessageId = _uuid();
      final stream = await client.send(
        MothershipSendRequest(
          message: 'hi',
          workspaceId: workspaceId,
          userMessageId: userMessageId,
          userTimezone: 'UTC',
          mode: 'agent',
        ),
      );
      expect(stream.chatId, isNotNull, reason: 'x-mothership-chat-id');
      final envelopes = <MothershipStreamEnvelope>[];
      await for (final frame in SseDecoder().frames(
        withSseIdleTimeout(stream.bytes, const Duration(seconds: 45)),
      )) {
        if (frame.isDone) break;
        final envelope = MothershipStreamEnvelope.fromJson(
          jsonDecode(frame.data),
          strict: true,
          context: 'Live SSE event.',
        );
        envelopes.add(envelope);
        if (envelope.type == MothershipStreamType.complete) break;
      }
      expect(envelopes, isNotEmpty);
      final first = MothershipPayload.of(envelopes.first);
      expect(first, isA<SessionChatPayload>());
      expect((first as SessionChatPayload).chatId, stream.chatId);
      final cursors = [
        for (final e in envelopes) int.parse(e.stream.cursor ?? '${e.seq}'),
      ];
      for (var i = 1; i < cursors.length; i++) {
        expect(cursors[i], greaterThan(cursors[i - 1]));
      }
      final terminal = MothershipPayload.of(envelopes.last);
      expect(terminal, isA<CompletePayload>());
      final status = (terminal as CompletePayload).status;
      final types = envelopes.map((e) => e.type).toSet();
      if (status == 'complete') {
        expect(types, contains(MothershipStreamType.text));
      } else {
        expect(status, 'error');
        expect(types, contains(MothershipStreamType.error));
      }

      final batch = await client.batch(userMessageId, '0');
      expect(batch.isTerminal, isTrue);
      await client.deleteChat(stream.chatId!);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
