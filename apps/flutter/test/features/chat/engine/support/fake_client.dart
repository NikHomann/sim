// A scripted MothershipClient for the cubit tests: every route the engine
// calls is a replaceable handler; calls are logged in order.

import 'dart:async';
import 'dart:convert';

import 'package:sim_api/sim_api.dart';

import 'fixtures.dart';

/// A live SSE body the test writes to.
class FakeSse {
  final StreamController<List<int>> controller = StreamController<List<int>>();
  bool cancelled = false;

  Stream<List<int>> get bytes => controller.stream;

  void comment([String text = 'keepalive']) =>
      controller.add(utf8.encode(': $text\n\n'));

  void envelope(Map<String, Object?> json) =>
      controller.add(utf8.encode('data: ${jsonEncode(json)}\n\n'));

  void raw(String text) => controller.add(utf8.encode(text));

  void lines(Iterable<EnvelopeLine> lines) {
    for (final line in lines) {
      envelope(line.json);
    }
  }

  /// Transport drop: the body errors like a cut fetch.
  void cut() {
    controller.addError(const ApiNetworkError('stream interrupted'));
    unawaited(controller.close());
  }

  Future<void> end() => controller.close();

  /// Closes the body when [token] fires, as Dio does on cancel.
  void bindCancel(MothershipCancelToken? token) {
    unawaited(
      token?.whenCancel.then((_) {
        cancelled = true;
        if (!controller.isClosed) unawaited(controller.close());
      }),
    );
  }
}

typedef SendHandler =
    Future<MothershipSendStream> Function(
      MothershipSendRequest request,
      MothershipCancelToken? token,
    );
typedef TailHandler =
    Future<MothershipTailStream> Function(
      String streamId,
      String after, {
      required bool fromLog,
      MothershipCancelToken? token,
    });
typedef BatchHandler =
    Future<StreamBatch> Function(
      String streamId,
      String after, {
      required bool fromLog,
    });

class FakeMothershipClient implements MothershipClient {
  final List<String> calls = [];
  final List<MothershipSendRequest> sends = [];
  final List<Map<String, Object?>> aborts = [];
  final List<Map<String, Object?>> stops = [];
  final Map<String, MothershipChatHistory> histories = {};

  SendHandler? onSend;
  TailHandler? onTail;
  BatchHandler? onBatch;
  Future<MothershipAbortResult> Function()? onAbort;
  Future<void> Function()? onPersistStop;
  Future<String?> Function(String chatId)? onStreamStatus;
  Future<MothershipChatHistory> Function(String chatId)? onHistory;

  /// Answers a send with [sse] (headers first).
  void answerSend(FakeSse sse, {String? chatId, String? traceparent}) {
    onSend = (request, token) async {
      sse.bindCancel(token);
      return MothershipSendStream(
        bytes: sse.bytes,
        chatId: chatId,
        traceparent: traceparent,
      );
    };
  }

  @override
  Future<MothershipSendStream> send(
    MothershipSendRequest request, {
    MothershipCancelToken? cancelToken,
  }) {
    calls.add('send ${request.userMessageId}');
    sends.add(request);
    final handler = onSend;
    if (handler == null) throw StateError('no send handler');
    return handler(request, cancelToken);
  }

  @override
  Future<MothershipTailStream> tail(
    String streamId,
    String after, {
    bool fromLog = false,
    String? traceparent,
    MothershipCancelToken? cancelToken,
  }) {
    calls.add('tail $streamId after=$after${fromLog ? ' log' : ''}');
    final handler = onTail;
    if (handler == null) throw MothershipStreamGoneError(streamId);
    return handler(streamId, after, fromLog: fromLog, token: cancelToken);
  }

  @override
  Future<StreamBatch> batch(
    String streamId,
    String after, {
    bool fromLog = false,
    String? traceparent,
    MothershipCancelToken? cancelToken,
  }) {
    calls.add('batch $streamId after=$after${fromLog ? ' log' : ''}');
    final handler = onBatch;
    if (handler == null) throw MothershipStreamGoneError(streamId);
    return handler(streamId, after, fromLog: fromLog);
  }

  @override
  Future<MothershipAbortResult> abort({
    required String streamId,
    String? workspaceId,
    String? organizationId,
    String? chatId,
    String? traceparent,
  }) {
    calls.add('abort $streamId');
    aborts.add({
      'streamId': streamId,
      'workspaceId': workspaceId,
      'chatId': chatId,
    });
    return onAbort?.call() ??
        Future.value(
          const MothershipAbortResult(aborted: true, settled: true),
        );
  }

  @override
  Future<void> persistStop({
    required String chatId,
    required String streamId,
    String? requestId,
    String? traceparent,
  }) {
    calls.add('stop $chatId $streamId');
    stops.add({'chatId': chatId, 'streamId': streamId, 'requestId': requestId});
    return onPersistStop?.call() ?? Future.value();
  }

  @override
  Future<String?> streamStatus(
    String chatId, {
    MothershipCancelToken? cancelToken,
  }) {
    calls.add('stream-status $chatId');
    return onStreamStatus?.call(chatId) ?? Future.value();
  }

  @override
  Future<MothershipChatHistory> chatHistory(
    String chatId, {
    MothershipChatHistory? cached,
    MothershipCancelToken? cancelToken,
    Duration? timeout,
  }) {
    calls.add('history $chatId');
    final handler = onHistory;
    if (handler != null) return handler(chatId);
    final history = histories[chatId];
    if (history == null) {
      return Future.error(
        ApiClientError.fromResponse(
          status: 404,
          body: {'success': false, 'error': 'Chat not found'},
        ),
      );
    }
    return Future.value(history);
  }

  @override
  Future<void> markRead(String chatId) async => calls.add('read $chatId');

  @override
  Future<void> setChatEffort(String chatId, String effort) async =>
      calls.add('effort $chatId $effort');

  @override
  Future<List<ToolPermissionResult>> decideToolPermissions(
    Map<String, ToolPermissionDecision> decisions,
  ) async {
    calls.add(
      'permission ${decisions.entries.map((e) => '${e.key}=${e.value.wire}').join(',')}',
    );
    return [
      for (final e in decisions.entries)
        ToolPermissionResult(
          toolCallId: e.key,
          decision: e.value.wire,
          applied: true,
        ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A batch response.
StreamBatch batchOf(
  List<Map<String, Object?>> envelopes, {
  String status = 'active',
  String? chatId,
}) => StreamBatch.fromJson({
  'success': true,
  'status': status,
  'chatId': ?chatId,
  'events': [
    for (final e in envelopes)
      {
        'eventId': e['seq'],
        'streamId': (e['stream']! as Map)['streamId'],
        'event': e,
      },
  ],
});

/// One envelope of stream [streamId].
Map<String, Object?> envelope(
  int seq,
  String type,
  Map<String, Object?> payload, {
  String streamId = 'u-1',
  Map<String, Object?>? scope,
}) => {
  'v': 1,
  'type': type,
  'seq': seq,
  'ts': '2026-10-22T10:00:00.000Z',
  'stream': {'streamId': streamId, 'cursor': '$seq'},
  'trace': {'requestId': 'req-1'},
  'scope': ?scope,
  'payload': payload,
};

Map<String, Object?> text(int seq, String text, {String streamId = 'u-1'}) =>
    envelope(seq, 'text', {
      'channel': 'assistant',
      'text': text,
    }, streamId: streamId);

Map<String, Object?> complete(
  int seq, {
  String status = 'complete',
  String streamId = 'u-1',
}) => envelope(seq, 'complete', {'status': status}, streamId: streamId);
