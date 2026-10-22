/// Envelope kinds of mothership stream v1
/// (`apps/sim/lib/mothership/generated/mothership-stream-v1.ts`).
enum MothershipStreamType {
  session,
  text,
  tool,
  span,
  resource,
  run,
  error,
  complete,
  unknown
  ;

  static MothershipStreamType parse(String raw) => switch (raw) {
    'session' => session,
    'text' => text,
    'tool' => tool,
    'span' => span,
    'resource' => resource,
    'run' => run,
    'error' => error,
    'complete' => complete,
    _ => unknown,
  };
}

/// `{streamId, chatId?, cursor?}`; `cursor` resumes
/// `GET /api/mothership/chat/stream?streamId&after=<cursor>`.
class MothershipStreamRef {
  const MothershipStreamRef({required this.streamId, this.chatId, this.cursor});

  factory MothershipStreamRef.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('stream ref: not an object');
    final streamId = json['streamId'];
    if (streamId is! String || streamId.isEmpty) {
      throw const FormatException('stream ref: missing streamId');
    }
    return MothershipStreamRef(
      streamId: streamId,
      chatId: json['chatId'] as String?,
      cursor: json['cursor'] as String?,
    );
  }

  final String streamId;
  final String? chatId;
  final String? cursor;
}

/// One `data:` frame of `POST /api/mothership/chat` and its reconnect stream:
/// `{v:1, type, seq, ts, stream, trace?, scope?, payload}`.
///
/// The payload stays a map here; the chat engine (Phase 3) interprets it per
/// type (`session` kinds, `text` channels, tool lifecycle, ...).
class MothershipStreamEnvelope {
  const MothershipStreamEnvelope({
    required this.type,
    required this.rawType,
    required this.seq,
    required this.ts,
    required this.stream,
    required this.payload,
    this.trace,
    this.scope,
  });

  /// Decodes one frame; throws [FormatException] for anything that is not a
  /// v1 envelope (wrong `v`, missing `type`/`seq`/`stream`).
  factory MothershipStreamEnvelope.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('envelope: not an object');
    if (json['v'] != 1) {
      throw FormatException('envelope: unsupported version ${json['v']}');
    }
    final type = json['type'];
    if (type is! String) throw const FormatException('envelope: missing type');
    final seq = json['seq'];
    if (seq is! num) throw const FormatException('envelope: missing seq');
    final payload = json['payload'];
    return MothershipStreamEnvelope(
      type: MothershipStreamType.parse(type),
      rawType: type,
      seq: seq.toInt(),
      ts: '${json['ts'] ?? ''}',
      stream: MothershipStreamRef.fromJson(json['stream']),
      payload: payload is Map
          ? Map<String, Object?>.from(payload)
          : <String, Object?>{},
      trace: _map(json['trace']),
      scope: _map(json['scope']),
    );
  }

  final MothershipStreamType type;
  final String rawType;
  final int seq;
  final String ts;
  final MothershipStreamRef stream;
  final Map<String, Object?> payload;
  final Map<String, Object?>? trace;
  final Map<String, Object?>? scope;

  /// `kind` of a `session`/`run`/`span`/`tool`/`resource` payload.
  String? get kind => payload['kind'] as String?;

  /// Whether the envelope ends the stream (`complete` or `error`).
  bool get isTerminal =>
      type == MothershipStreamType.complete ||
      type == MothershipStreamType.error;

  static Map<String, Object?>? _map(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : null;
}

/// Tracks the `seq` of decoded envelopes and reports gaps, which the chat
/// engine turns into a reconnect from the last cursor.
class MothershipSeqTracker {
  int? _last;

  int? get lastSeq => _last;

  /// Records [seq]; returns the number of missed envelopes (0 when in order,
  /// also 0 for a replayed envelope at or below the last seq).
  int record(int seq) {
    final last = _last;
    if (last == null) {
      _last = seq;
      return 0;
    }
    if (seq <= last) return 0;
    final gap = seq - last - 1;
    _last = seq;
    return gap;
  }
}
