/// Request header declaring that the client understands `agent-events-v1`
/// framing (`chunk_reset`, `thinking`, `tool`).
const agentStreamProtocolHeader = 'X-Sim-Stream-Protocol';
const agentStreamProtocolV1 = 'agent-events-v1';

/// Frames of the API/deployed flavour streams (`POST /api/chat/[identifier]`,
/// non-draft execute, `/api/v2/chat`), per
/// `apps/sim/lib/workflows/streaming/agent-stream-protocol.ts`. The stream
/// ends with the JSON-quoted `"[DONE]"` marker, which `SseFrame.isDone`
/// recognises before frames reach this decoder.
sealed class ApiStreamEvent {
  const ApiStreamEvent();

  /// Decodes one JSON frame with the upstream type guards; frames that match
  /// no guard become [ApiStreamUnknown] (a tool frame with an unrecognised
  /// status is a protocol violation and is rejected the same way).
  factory ApiStreamEvent.fromJson(Object? json) {
    if (json is! Map) return ApiStreamUnknown(json);
    final blockId = json['blockId'];
    final event = json['event'];
    final chunk = json['chunk'];
    if (event == null &&
        blockId is String &&
        chunk is String &&
        chunk.isNotEmpty) {
      return ApiStreamChunk(blockId: blockId, chunk: chunk);
    }
    switch (event) {
      case 'chunk_reset':
        if (blockId is String) return ApiStreamChunkReset(blockId: blockId);
      case 'output':
        if (blockId is String && json.containsKey('data')) {
          return ApiStreamOutput(blockId: blockId, data: json['data']);
        }
      case 'thinking':
        final data = json['data'];
        if (blockId is String && data is String) {
          return ApiStreamThinking(blockId: blockId, data: data);
        }
      case 'tool':
        final phase = json['phase'];
        final id = json['id'];
        final name = json['name'];
        final status = json['status'];
        if (blockId is String &&
            (phase == 'start' || phase == 'end') &&
            id is String &&
            id.isNotEmpty &&
            name is String &&
            name.isNotEmpty &&
            (status == null || _toolEndStatuses.contains(status))) {
          return ApiStreamTool(
            blockId: blockId,
            phase: phase! as String,
            id: id,
            name: name,
            status: status as String?,
          );
        }
      case 'final':
        final data = json['data'];
        if (data is Map) return ApiStreamFinal(Map<String, Object?>.from(data));
      case 'error':
        return ApiStreamError(
          error: '${json['error'] ?? 'Unknown error'}',
          blockId: blockId is String ? blockId : null,
        );
      case 'stream_error':
        return ApiStreamStreamError(
          error: '${json['error'] ?? 'Unknown error'}',
          blockId: blockId is String ? blockId : null,
        );
    }
    return ApiStreamUnknown(json);
  }

  static const _toolEndStatuses = {'success', 'error', 'cancelled'};
}

/// Answer text: the only frame appended to the answer.
class ApiStreamChunk extends ApiStreamEvent {
  const ApiStreamChunk({required this.blockId, required this.chunk});

  final String blockId;
  final String chunk;
}

/// Selected non-text output (negotiated deployed chats).
class ApiStreamOutput extends ApiStreamEvent {
  const ApiStreamOutput({required this.blockId, required this.data});

  final String blockId;
  final Object? data;
}

/// Discard the block's accumulated answer text; the final turn re-streams.
class ApiStreamChunkReset extends ApiStreamEvent {
  const ApiStreamChunkReset({required this.blockId});

  final String blockId;
}

class ApiStreamThinking extends ApiStreamEvent {
  const ApiStreamThinking({required this.blockId, required this.data});

  final String blockId;
  final String data;
}

class ApiStreamTool extends ApiStreamEvent {
  const ApiStreamTool({
    required this.blockId,
    required this.phase,
    required this.id,
    required this.name,
    this.status,
  });

  final String blockId;

  /// `start` or `end`.
  final String phase;
  final String id;
  final String name;

  /// `success`, `error` or `cancelled` on `end`.
  final String? status;
}

/// Terminal success envelope, followed by `"[DONE]"`.
class ApiStreamFinal extends ApiStreamEvent {
  const ApiStreamFinal(this.data);

  final Map<String, Object?> data;
}

/// Terminal failure, followed by `"[DONE]"`; never followed by `final`.
class ApiStreamError extends ApiStreamEvent {
  const ApiStreamError({required this.error, this.blockId});

  final String error;
  final String? blockId;
}

/// Non-terminal mid-block read issue; the stream keeps going.
class ApiStreamStreamError extends ApiStreamEvent {
  const ApiStreamStreamError({required this.error, this.blockId});

  final String error;
  final String? blockId;
}

/// A frame no guard accepted; kept for logging.
class ApiStreamUnknown extends ApiStreamEvent {
  const ApiStreamUnknown(this.raw);

  final Object? raw;
}
