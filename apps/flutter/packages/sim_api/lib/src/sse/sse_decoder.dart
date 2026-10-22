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

/// The stream delivered no bytes for the idle window: port of
/// `SSEIdleTimeoutError` (`apps/sim/lib/core/utils/sse.ts:137-195`).
class SseIdleTimeoutError implements Exception {
  const SseIdleTimeoutError(this.timeout);

  final Duration timeout;

  @override
  String toString() =>
      'SseIdleTimeoutError: no data for ${timeout.inMilliseconds} ms';
}

/// Fails [bytes] with [SseIdleTimeoutError] and cancels the source when no
/// raw chunk arrives for [timeout]. Every chunk resets the window, comments
/// (`: keepalive`) included, because the timer runs on bytes, before the
/// decoder drops comments (React's `readSSELines` idle timeout, which the
/// chat sets to 45 s).
Stream<List<int>> withSseIdleTimeout(
  Stream<List<int>> bytes,
  Duration timeout,
) {
  late StreamController<List<int>> controller;
  // Cancelled on timeout and in onCancel.
  // ignore: cancel_subscriptions
  StreamSubscription<List<int>>? source;
  Timer? timer;

  void arm() {
    timer?.cancel();
    timer = Timer(timeout, () {
      final subscription = source;
      source = null;
      unawaited(subscription?.cancel());
      if (!controller.isClosed) {
        controller.addError(SseIdleTimeoutError(timeout));
        unawaited(controller.close());
      }
    });
  }

  controller = StreamController<List<int>>(
    onListen: () {
      arm();
      source = bytes.listen(
        (chunk) {
          arm();
          controller.add(chunk);
        },
        onError: controller.addError,
        onDone: () {
          timer?.cancel();
          // The source is finished: nothing is left to cancel.
          source = null;
          if (!controller.isClosed) unawaited(controller.close());
        },
      );
    },
    onPause: () => source?.pause(),
    onResume: () => source?.resume(),
    // Returns the source's own cancel future (not an `async` wrapper), so a
    // `cancelOnError` listener gets the error without an extra hop.
    onCancel: () {
      timer?.cancel();
      final subscription = source;
      source = null;
      return subscription?.cancel();
    },
  );
  return controller.stream;
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
