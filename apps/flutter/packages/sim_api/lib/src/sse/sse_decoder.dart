import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

/// One Server-Sent Events frame: the `data:` lines joined with `\n`, the
/// optional `event:` name and `id:`.
class SseFrame {
  const SseFrame({required this.data, this.event, this.id});

  final String data;
  final String? event;
  final String? id;

  /// The end-of-stream sentinel the Sim backend writes: a bare `[DONE]`
  /// (execution and mothership streams) or the JSON-quoted `"[DONE]"`
  /// (API-flavour chat streams).
  bool get isDone => data == '[DONE]' || data == '"[DONE]"';

  @override
  String toString() => 'SseFrame(event: $event, id: $id, data: $data)';
}

/// Decodes an SSE byte stream into frames.
///
/// Port of `readSSELines` in `apps/sim/lib/core/utils/sse.ts`, extended to the
/// named events (`event:`) and ids (`id:`) the workspace event endpoints use.
/// Handles `data:` lines split across chunks (and across UTF-8 sequences),
/// `\n` and `\r\n` line ends, comment keepalives (`: ping`), a frame without
/// a trailing blank line at end of stream, and the terminal markers.
class SseDecoder {
  SseDecoder({Logger? logger}) : _log = logger ?? Logger('sim_api.sse');

  final Logger _log;

  /// Frames of [bytes]. Comments are dropped; frames without any `data:`
  /// line are dropped too (an `event: rotate` always carries `data: {}`).
  Stream<SseFrame> frames(Stream<List<int>> bytes) {
    final lines = const LineSplitter().bind(utf8.decoder.bind(bytes));
    return lines.transform(const _FrameAssembler());
  }

  /// JSON-decoded `data:` payloads of [bytes], ending at the first terminal
  /// marker. Malformed JSON is logged and skipped so one bad frame cannot
  /// take the whole stream down. Named frames are included; callers that need
  /// the name use [frames].
  Stream<Object?> jsonEvents(Stream<List<int>> bytes) async* {
    await for (final frame in frames(bytes)) {
      if (frame.isDone) return;
      final decoded = decodeJsonFrame(frame);
      if (decoded.ok) yield decoded.value;
    }
  }

  /// Parses one frame's JSON; `ok` is false (and the error logged) when the
  /// payload is not JSON.
  ({bool ok, Object? value}) decodeJsonFrame(SseFrame frame) {
    try {
      return (ok: true, value: jsonDecode(frame.data));
    } on FormatException catch (error) {
      _log.severe('Failed to parse SSE event: ${error.message}', frame.data);
      return (ok: false, value: null);
    }
  }
}

/// Folds lines into frames per the SSE specification: `data:` lines are
/// accumulated (joined with `\n`), `event:` and `id:` set the frame fields,
/// a blank line dispatches, a `:` line is a comment. Unlike `EventSource`,
/// an `id:` is not remembered across frames: callers track the last id.
class _FrameAssembler extends StreamTransformerBase<String, SseFrame> {
  const _FrameAssembler();

  @override
  Stream<SseFrame> bind(Stream<String> stream) {
    final data = <String>[];
    String? event;
    String? id;

    SseFrame? flush() {
      if (data.isEmpty) {
        event = null;
        id = null;
        return null;
      }
      final frame = SseFrame(data: data.join('\n'), event: event, id: id);
      data.clear();
      event = null;
      id = null;
      return frame;
    }

    return stream.transform(
      StreamTransformer<String, SseFrame>.fromHandlers(
        handleData: (line, sink) {
          if (line.isEmpty) {
            final frame = flush();
            if (frame != null) sink.add(frame);
            return;
          }
          if (line.startsWith(':')) return;
          final colon = line.indexOf(':');
          final field = colon == -1 ? line : line.substring(0, colon);
          var value = colon == -1 ? '' : line.substring(colon + 1);
          if (value.startsWith(' ')) value = value.substring(1);
          switch (field) {
            case 'data':
              data.add(value);
            case 'event':
              event = value;
            case 'id':
              if (!value.contains('\u0000')) id = value;
            default:
              // `retry:` and unknown fields are ignored.
              break;
          }
        },
        handleDone: (sink) {
          final frame = flush();
          if (frame != null) sink.add(frame);
          sink.close();
        },
      ),
    );
  }
}
