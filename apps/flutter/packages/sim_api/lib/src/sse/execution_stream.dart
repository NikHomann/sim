import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:sim_api/src/client/api_client_error.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/sse/sse_decoder.dart';

/// Response header carrying the execution id of a streamed run.
const executionIdHeader = 'x-execution-id';

/// Request header selecting async execution (`202` JSON instead of SSE).
const executionModeHeader = 'x-execution-mode';

/// Events of `POST /api/workflows/[id]/execute` (`stream: true`) and of the
/// reconnect stream, per `apps/sim/lib/workflows/executor/execution-events.ts`.
///
/// Every event keeps its raw `data` map; the subclasses add typed access to
/// the fields the canvas, terminal and execution stores read.
sealed class ExecutionStreamEvent {
  const ExecutionStreamEvent({
    required this.type,
    required this.timestamp,
    required this.executionId,
    required this.data,
    this.eventId,
    this.workflowId,
  });

  /// Decodes one JSON frame. Unknown `type`s become
  /// [UnknownExecutionEvent]; a frame without a string `type` is rejected
  /// with [FormatException].
  factory ExecutionStreamEvent.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('execution event: not an object');
    }
    final type = json['type'];
    if (type is! String) {
      throw const FormatException('execution event: missing type');
    }
    final rawData = json['data'];
    final data = rawData is Map
        ? Map<String, Object?>.from(rawData)
        : <String, Object?>{};
    final timestamp = '${json['timestamp'] ?? ''}';
    final executionId = '${json['executionId'] ?? ''}';
    final eventId = _asInt(json['eventId']);
    final workflowId = json['workflowId'] is String
        ? json['workflowId'] as String
        : null;
    return switch (type) {
      'execution:started' => ExecutionStarted._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'execution:completed' => ExecutionCompleted._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'execution:paused' => ExecutionPaused._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'execution:error' => ExecutionError._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'execution:cancelled' => ExecutionCancelled._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'block:started' => BlockStarted._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'block:completed' => BlockCompleted._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'block:error' => BlockError._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'block:childWorkflowStarted' => BlockChildWorkflowStarted._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'stream:chunk' => StreamChunk._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'stream:chunk_reset' => StreamChunkReset._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'stream:done' => StreamDone._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'stream:thinking' => StreamThinking._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      'stream:tool' => StreamTool._(
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
      _ => UnknownExecutionEvent._(
        type: type,
        timestamp: timestamp,
        executionId: executionId,
        data: data,
        eventId: eventId,
        workflowId: workflowId,
      ),
    };
  }

  final String type;
  final String timestamp;
  final String executionId;
  final int? eventId;
  final String? workflowId;
  final Map<String, Object?> data;

  /// Whether the event ends the run (`execution:completed|paused|error|cancelled`).
  bool get isTerminal => switch (this) {
    ExecutionCompleted() ||
    ExecutionPaused() ||
    ExecutionError() ||
    ExecutionCancelled() => true,
    _ => false,
  };

  static int? _asInt(Object? value) =>
      value is int ? value : (value is num ? value.toInt() : null);

  @override
  String toString() => 'ExecutionStreamEvent($type, eventId: $eventId)';
}

mixin _BlockFields on ExecutionStreamEvent {
  String get blockId => '${data['blockId'] ?? ''}';
  String? get blockName => data['blockName'] as String?;
  String? get blockType => data['blockType'] as String?;
  int? get executionOrder =>
      ExecutionStreamEvent._asInt(data['executionOrder']);
  int? get iterationCurrent =>
      ExecutionStreamEvent._asInt(data['iterationCurrent']);
  int? get iterationTotal =>
      ExecutionStreamEvent._asInt(data['iterationTotal']);
  String? get iterationType => data['iterationType'] as String?;
  String? get iterationContainerId => data['iterationContainerId'] as String?;
  String? get childWorkflowBlockId => data['childWorkflowBlockId'] as String?;
  String? get childWorkflowName => data['childWorkflowName'] as String?;
  String? get childWorkflowInstanceId =>
      data['childWorkflowInstanceId'] as String?;

  /// `getBlockInvocationKey` upstream: identifies one block invocation across
  /// iterations and child workflows.
  String get invocationKey => [
    blockId,
    executionOrder ?? '',
    iterationContainerId ?? '',
    iterationCurrent ?? '',
    childWorkflowBlockId ?? '',
  ].join(':');
}

mixin _TerminalFields on ExecutionStreamEvent {
  num? get duration => data['duration'] as num?;
  List<Object?>? get finalBlockLogs => data['finalBlockLogs'] as List<Object?>?;
}

class ExecutionStarted extends ExecutionStreamEvent {
  const ExecutionStarted._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'execution:started');

  String? get startTime => data['startTime'] as String?;
}

class ExecutionCompleted extends ExecutionStreamEvent with _TerminalFields {
  const ExecutionCompleted._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'execution:completed');

  bool get success => data['success'] == true;
  Object? get output => data['output'];
}

class ExecutionPaused extends ExecutionStreamEvent with _TerminalFields {
  const ExecutionPaused._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'execution:paused');

  Object? get output => data['output'];
}

class ExecutionError extends ExecutionStreamEvent with _TerminalFields {
  const ExecutionError._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'execution:error');

  String get error => '${data['error'] ?? 'Unknown error'}';
}

class ExecutionCancelled extends ExecutionStreamEvent with _TerminalFields {
  const ExecutionCancelled._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'execution:cancelled');
}

class BlockStarted extends ExecutionStreamEvent with _BlockFields {
  const BlockStarted._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'block:started');
}

class BlockCompleted extends ExecutionStreamEvent with _BlockFields {
  const BlockCompleted._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'block:completed');

  Object? get input => data['input'];
  Object? get output => data['output'];
  num? get durationMs => data['durationMs'] as num?;
  String? get startedAt => data['startedAt'] as String?;
  String? get endedAt => data['endedAt'] as String?;
}

class BlockError extends ExecutionStreamEvent with _BlockFields {
  const BlockError._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'block:error');

  Object? get input => data['input'];
  String get error => '${data['error'] ?? 'Unknown error'}';
  num? get durationMs => data['durationMs'] as num?;
  String? get startedAt => data['startedAt'] as String?;
  String? get endedAt => data['endedAt'] as String?;
}

class BlockChildWorkflowStarted extends ExecutionStreamEvent with _BlockFields {
  const BlockChildWorkflowStarted._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'block:childWorkflowStarted');
}

class StreamChunk extends ExecutionStreamEvent {
  const StreamChunk._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'stream:chunk');

  String get blockId => '${data['blockId'] ?? ''}';
  String get chunk => '${data['chunk'] ?? ''}';
}

class StreamChunkReset extends ExecutionStreamEvent {
  const StreamChunkReset._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'stream:chunk_reset');

  String get blockId => '${data['blockId'] ?? ''}';
}

class StreamDone extends ExecutionStreamEvent {
  const StreamDone._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'stream:done');

  String get blockId => '${data['blockId'] ?? ''}';
}

class StreamThinking extends ExecutionStreamEvent {
  const StreamThinking._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'stream:thinking');

  String get blockId => '${data['blockId'] ?? ''}';
  String get text => '${data['text'] ?? ''}';
}

class StreamTool extends ExecutionStreamEvent {
  const StreamTool._({
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  }) : super(type: 'stream:tool');

  String get blockId => '${data['blockId'] ?? ''}';

  /// `start` or `end`.
  String get phase => '${data['phase'] ?? ''}';
  String get id => '${data['id'] ?? ''}';
  String get name => '${data['name'] ?? ''}';

  /// `success`, `error` or `cancelled` on `end`.
  String? get status => data['status'] as String?;
}

class UnknownExecutionEvent extends ExecutionStreamEvent {
  const UnknownExecutionEvent._({
    required super.type,
    required super.timestamp,
    required super.executionId,
    required super.data,
    super.eventId,
    super.workflowId,
  });
}

/// The execute endpoint rejected the request (port of
/// `ExecutionStreamHttpError`). [executionResult] is the JSON body when the
/// server returned one.
class ExecutionStreamHttpError implements Exception {
  const ExecutionStreamHttpError({
    required this.message,
    required this.httpStatus,
    this.code,
    this.executionResult,
  });

  factory ExecutionStreamHttpError.fromApiError(ApiClientError error) =>
      ExecutionStreamHttpError(
        message: error.body is Map
            ? '${(error.body! as Map)['error'] ?? 'Failed to start execution'}'
            : 'Server error (${error.status})',
        httpStatus: error.status,
        code: error.code,
        executionResult: error.body is Map ? error.body! as Map : null,
      );

  final String message;
  final int httpStatus;
  final String? code;
  final Map<Object?, Object?>? executionResult;

  @override
  String toString() => 'ExecutionStreamHttpError($httpStatus: $message)';
}

/// A transport failure cut the stream before a terminal event (port of
/// `SSEStreamInterruptedError`); the run may still be alive for reconnect.
class ExecutionStreamInterruptedError implements Exception {
  const ExecutionStreamInterruptedError({
    required this.message,
    this.executionId,
    this.cause,
  });

  final String message;
  final String? executionId;
  final Object? cause;

  @override
  String toString() => 'ExecutionStreamInterruptedError($message)';
}

/// A live or reconnected execution stream.
class ExecutionStream {
  ExecutionStream._({
    required this.events,
    required this.cancelToken,
    this.executionId,
    this.asyncAccepted,
  });

  /// From `X-Execution-Id`; `null` when the server did not send it.
  final String? executionId;

  /// The typed events, ending at `[DONE]` or the end of the body. A transport
  /// failure before a terminal event is delivered as an
  /// [ExecutionStreamInterruptedError].
  final Stream<ExecutionStreamEvent> events;

  /// The `202` body when the request ran with `X-Execution-Mode: async`;
  /// [events] is then empty.
  final Map<String, Object?>? asyncAccepted;

  final CancelToken cancelToken;

  /// Closes the connection (the server treats it as a client disconnect).
  void cancel() {
    if (!cancelToken.isCancelled) cancelToken.cancel('cancelled');
  }
}

/// `execute`, `reconnect` and `cancel` of `hooks/use-execution-stream.ts`
/// on top of [SimHttpClient].
class ExecutionStreamClient {
  ExecutionStreamClient(this._http, {SseDecoder? decoder, Logger? logger})
    : _decoder = decoder ?? SseDecoder(logger: logger),
      _log = logger ?? Logger('sim_api.execution');

  final SimHttpClient _http;
  final SseDecoder _decoder;
  final Logger _log;

  /// `POST /api/workflows/[id]/execute` with `stream: true`. [body] carries
  /// the upstream fields (`input`, `workflowInput`, `selectedOutputs`,
  /// `startBlockId`, `useDraftState`, `isClientSession`,
  /// `workflowStateOverride`, `runFromBlock`, ...).
  Future<ExecutionStream> execute({
    required String workflowId,
    Map<String, Object?> body = const {},
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    final ApiStreamResponse response;
    try {
      response = await _http.stream(
        method: 'POST',
        path: '/api/workflows/[id]/execute',
        params: {'id': workflowId},
        body: {...body, 'stream': true},
        headers: headers,
        cancelToken: token,
      );
    } on ApiClientError catch (error) {
      throw ExecutionStreamHttpError.fromApiError(error);
    }
    final executionId = response.header(executionIdHeader);
    if (response.status == 202) {
      final text = await _collect(response.bytes);
      final decoded = SimHttpClient.decodeBody(text);
      return ExecutionStream._(
        events: const Stream.empty(),
        cancelToken: token,
        executionId: executionId,
        asyncAccepted: decoded is Map ? Map<String, Object?>.from(decoded) : {},
      );
    }
    return ExecutionStream._(
      events: _events(response.bytes, executionId),
      cancelToken: token,
      executionId: executionId,
    );
  }

  /// `GET /api/workflows/[id]/executions/[executionId]/stream?from=N`:
  /// replays buffered events after [fromEventId] and then tails the run.
  Future<ExecutionStream> reconnect({
    required String workflowId,
    required String executionId,
    int fromEventId = 0,
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    final ApiStreamResponse response;
    try {
      response = await _http.stream(
        method: 'GET',
        path: '/api/workflows/[id]/executions/[executionId]/stream',
        params: {'id': workflowId, 'executionId': executionId},
        query: {'from': fromEventId},
        cancelToken: token,
      );
    } on ApiClientError catch (error) {
      throw ExecutionStreamHttpError(
        message: 'Reconnect failed (${error.status})',
        httpStatus: error.status,
        code: error.code,
      );
    }
    return ExecutionStream._(
      events: _events(response.bytes, executionId),
      cancelToken: token,
      executionId: executionId,
    );
  }

  /// `POST /api/workflows/[id]/executions/[executionId]/cancel`; returns the
  /// JSON body (`{success, reason?}`).
  Future<Map<String, Object?>> cancelExecution({
    required String workflowId,
    required String executionId,
  }) async {
    final response = await _http.send(
      method: 'POST',
      path: '/api/workflows/[id]/executions/[executionId]/cancel',
      params: {'id': workflowId, 'executionId': executionId},
    );
    final data = response.data;
    return data is Map ? Map<String, Object?>.from(data) : {};
  }

  /// `GET /api/workflows/[id]/executions/[executionId]?includeOutput=true`,
  /// the recorded outcome used when a reconnect ends without a terminal event.
  Future<Map<String, Object?>> recordedExecution({
    required String workflowId,
    required String executionId,
    CancelToken? cancelToken,
  }) async {
    final response = await _http.send(
      method: 'GET',
      path: '/api/workflows/[id]/executions/[executionId]',
      params: {'id': workflowId, 'executionId': executionId},
      query: {'includeOutput': 'true'},
      cancelToken: cancelToken,
    );
    final data = response.data;
    return data is Map ? Map<String, Object?>.from(data) : {};
  }

  Stream<ExecutionStreamEvent> _events(
    Stream<List<int>> bytes,
    String? executionId,
  ) async* {
    var terminal = false;
    try {
      await for (final json in _decoder.jsonEvents(bytes)) {
        final ExecutionStreamEvent event;
        try {
          event = ExecutionStreamEvent.fromJson(json);
        } on FormatException catch (error) {
          _log.severe('Invalid execution event: ${error.message}', json);
          continue;
        }
        if (event is UnknownExecutionEvent) {
          _log.warning('Unknown event type: ${event.type}');
        }
        if (event.isTerminal) terminal = true;
        yield event;
      }
    } on ApiNetworkError catch (error) {
      if (terminal) return;
      throw ExecutionStreamInterruptedError(
        message:
            'Execution stream interrupted before a terminal event was received',
        executionId: executionId,
        cause: error,
      );
    }
  }

  static Future<String> _collect(Stream<List<int>> bytes) async {
    final buffer = <int>[];
    await bytes.forEach(buffer.addAll);
    return String.fromCharCodes(buffer);
  }
}
