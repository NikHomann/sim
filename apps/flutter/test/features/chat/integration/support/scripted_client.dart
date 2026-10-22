// A fake MothershipClient that answers each send by replaying an engine
// fixture (`test/features/chat/engine/fixtures/*.jsonl`) and serves the
// chat detail the way the server does after a turn: the engine's own
// detail-cache copy (it writes the live answer there on every flush) with
// the stream no longer active.

import 'dart:async';
import 'dart:convert';

import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/engine.dart';

import '../../engine/support/fake_client.dart';
import '../../engine/support/fixtures.dart';

/// One scripted turn: the fixture's POST envelopes, written up to each
/// `$await` directive.
class ScriptedTurn {
  ScriptedTurn(this.fixture, this.request, {required this.chatId});

  final Fixture fixture;
  final MothershipSendRequest request;
  final String chatId;
  final FakeSse sse = FakeSse();
  int _next = 0;
  bool get done => _next >= fixture.lines.length;

  Map<String, Object?> _rewrite(Map<String, Object?> json) {
    final copy = (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>();
    final stream = (copy['stream']! as Map).cast<String, Object?>()
      ..['streamId'] = request.userMessageId;
    if (stream.containsKey('chatId')) stream['chatId'] = chatId;
    copy['stream'] = stream;
    final payload = copy['payload'];
    if (payload is Map && payload['chatId'] is String) {
      payload['chatId'] = chatId;
    }
    return copy;
  }

  /// Writes envelopes until the next `$await` (returned) or the end
  /// (closes the body, returns null).
  String? advance() {
    // A Stop cancelled the request: the body is already closed.
    if (sse.controller.isClosed) return null;
    while (_next < fixture.lines.length) {
      final line = fixture.lines[_next++];
      switch (line) {
        case EnvelopeLine(:final json):
          sse.envelope(_rewrite(json));
        case DirectiveLine(name: r'$await', :final value):
          return '$value';
        case DirectiveLine():
          break;
      }
    }
    unawaited(sse.end());
    return null;
  }
}

class ScriptedMothershipClient extends FakeMothershipClient {
  ScriptedMothershipClient(this.queries);

  final QueryClient queries;

  /// The fixtures the next sends replay, in order.
  final List<String> script = [];
  final List<ScriptedTurn> turns = [];
  String chatId = 'chat-1';

  @override
  Future<MothershipSendStream> send(
    MothershipSendRequest request, {
    MothershipCancelToken? cancelToken,
  }) {
    calls.add('send ${request.userMessageId}');
    sends.add(request);
    final turn = ScriptedTurn(
      loadFixture(script.removeAt(0)),
      request,
      chatId: chatId,
    );
    turns.add(turn);
    turn.sse.bindCancel(cancelToken);
    final stream = MothershipSendStream(bytes: turn.sse.bytes, chatId: chatId);
    // The headers arrive first; the body follows on the next microtask.
    scheduleMicrotask(turn.advance);
    return Future.value(stream);
  }

  @override
  Future<MothershipChatHistory> chatHistory(
    String chatId, {
    MothershipChatHistory? cached,
    MothershipCancelToken? cancelToken,
    Duration? timeout,
  }) async {
    calls.add('history $chatId');
    final seeded = histories[chatId];
    if (seeded != null) return seeded;
    final current = queries.getQueryData<MothershipChatHistory>(
      MothershipChatKeys.detail(chatId),
    );
    final turn = turns.lastOrNull;
    final live = turn != null && !turn.done;
    return (current ?? MothershipChatHistory(id: chatId, messages: const []))
        .copyWith(
          activeStreamId: live ? turn.request.userMessageId : null,
          clearActiveStreamId: !live,
        );
  }
}
