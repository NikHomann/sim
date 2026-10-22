import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:sim_api/src/client/api_client_error.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/sse/sse_decoder.dart';

/// A named SSE event (`event: task_status`, `event: pruned`, ...) or a
/// plain `data:` entry (`name` is `message`, as `EventSource` names it).
class NamedSseEvent {
  const NamedSseEvent({required this.name, required this.data, this.id});

  final String name;

  /// The raw `data:` payload.
  final String data;
  final String? id;

  /// [data] decoded as JSON, or `null` when it is not JSON.
  Object? get json {
    try {
      return jsonDecode(data);
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => 'NamedSseEvent($name, id: $id, data: $data)';
}

/// Why a connection opened: port of `EventSourceOpenReason`.
enum EventSourceOpenReason { initial, reconnect, rotation }

/// Opens one SSE connection. [lastEventId] is the id of the last delivered
/// event (for `?from=` on the table stream) or `null` on a fresh start.
typedef SseConnectionFactory =
    Future<ApiStreamResponse> Function({
      required CancelToken cancelToken,
      String? lastEventId,
    });

/// Maintains one live SSE connection with make-before-break rotation on the
/// server's `event: rotate` and automatic reconnection after a drop, resuming
/// from the last event id. Port of `apps/sim/lib/events/rotating-event-source.ts`
/// plus the reconnect `EventSource` does on its own.
///
/// A connection counts as open once its headers arrived (the fetch resolved),
/// which is when the server has written its `: connected` comment. The
/// previous connection stays open until the replacement is open, so planned
/// lifetime bounds create no delivery gap.
class RotatingEventSource {
  RotatingEventSource({
    required SseConnectionFactory open,
    SseDecoder? decoder,
    this.retryDelay = const Duration(seconds: 3),
    this.maxRetryDelay = const Duration(seconds: 30),
    this.rotateEventName = 'rotate',
    Logger? logger,
  }) : _open = open,
       _decoder = decoder ?? SseDecoder(logger: logger),
       _log = logger ?? Logger('sim_api.events');

  final SseConnectionFactory _open;
  final SseDecoder _decoder;
  final Logger _log;
  final Duration retryDelay;
  final Duration maxRetryDelay;
  final String rotateEventName;

  final _events = StreamController<NamedSseEvent>.broadcast();
  final _opens = StreamController<EventSourceOpenReason>.broadcast();
  final _errors = StreamController<Object>.broadcast();

  _Source? _current;
  _Source? _replacement;
  Timer? _retryTimer;
  var _retries = 0;
  var _closed = false;
  var _started = false;
  String? _lastEventId;

  /// Events other than the rotation signal.
  Stream<NamedSseEvent> get events => _events.stream;

  /// Fires once per connection that opened, with why.
  Stream<EventSourceOpenReason> get opens => _opens.stream;

  /// Connection failures (the source keeps reconnecting after network
  /// failures; an HTTP rejection closes it, as `EventSource` does).
  Stream<Object> get errors => _errors.stream;

  String? get lastEventId => _lastEventId;
  bool get isClosed => _closed;

  /// Whether a connection is open right now.
  bool get isOpen => _current?.opened ?? false;

  /// Opens the initial connection. Idempotent.
  void start() {
    if (_started || _closed) return;
    _started = true;
    _current = _openSource(isReplacement: false);
  }

  /// Closes every connection; the streams complete.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _retryTimer?.cancel();
    final sources = [_current, _replacement].nonNulls.toList();
    _current = null;
    _replacement = null;
    for (final source in sources) {
      await source.dispose();
    }
    await _events.close();
    await _opens.close();
    await _errors.close();
  }

  _Source _openSource({required bool isReplacement}) {
    final source = _Source(cancelToken: CancelToken());
    unawaited(_run(source, isReplacement: isReplacement));
    return source;
  }

  Future<void> _run(_Source source, {required bool isReplacement}) async {
    final ApiStreamResponse response;
    try {
      response = await _open(
        cancelToken: source.cancelToken,
        lastEventId: _lastEventId,
      );
    } on Object catch (error) {
      if (_closed || source.disposed) return;
      if (isReplacement) {
        // Keep the current source; the server closes it after its grace
        // period and the drop then reconnects normally.
        _replacement = null;
        _errors.add(error);
        return;
      }
      _handleFailure(source, error);
      return;
    }
    if (_closed || source.disposed) {
      source.cancelToken.cancel('closed');
      return;
    }
    _onOpened(source, isReplacement: isReplacement);
    source.subscription = _decoder
        .frames(response.bytes)
        .listen(
          (frame) => _onFrame(source, frame),
          onError: (Object error) => _onDrop(source, error),
          onDone: () => _onDrop(source, null),
        );
  }

  void _onOpened(_Source source, {required bool isReplacement}) {
    source.opened = true;
    if (isReplacement) {
      if (source != _replacement) {
        unawaited(source.dispose());
        return;
      }
      final previous = _current;
      final seamless = previous?.opened ?? false;
      _current = source;
      _replacement = null;
      if (previous != null && previous != source) unawaited(previous.dispose());
      _retries = 0;
      _opens.add(
        seamless
            ? EventSourceOpenReason.rotation
            : EventSourceOpenReason.reconnect,
      );
      return;
    }
    final reason = _retries > 0
        ? EventSourceOpenReason.reconnect
        : EventSourceOpenReason.initial;
    _retries = 0;
    _opens.add(reason);
  }

  void _onFrame(_Source source, SseFrame frame) {
    if (_closed || source.disposed) return;
    if (frame.id != null) _lastEventId = frame.id;
    final name = frame.event ?? 'message';
    if (name == rotateEventName) {
      if (source != _current || _replacement != null) return;
      _replacement = _openSource(isReplacement: true);
      return;
    }
    _events.add(NamedSseEvent(name: name, data: frame.data, id: frame.id));
  }

  void _onDrop(_Source source, Object? error) {
    if (_closed || source.disposed) return;
    source.opened = false;
    if (source == _replacement) {
      _replacement = null;
      if (error != null) _errors.add(error);
      return;
    }
    if (source != _current) return;
    if (error != null) _errors.add(error);
    if (_replacement != null) {
      // The replacement takes over when it opens; nothing to schedule.
      unawaited(source.dispose());
      return;
    }
    _scheduleReconnect(source);
  }

  void _handleFailure(_Source source, Object error) {
    _errors.add(error);
    if (error is ApiClientError) {
      // `EventSource` gives up on an HTTP rejection; the caller decides.
      _log.warning('event stream rejected: $error');
      unawaited(source.dispose());
      if (_current == source) _current = null;
      return;
    }
    _scheduleReconnect(source);
  }

  void _scheduleReconnect(_Source source) {
    unawaited(source.dispose());
    _retries += 1;
    final factor = 1 << (_retries - 1).clamp(0, 10);
    final delayMs = (retryDelay.inMilliseconds * factor).clamp(
      0,
      maxRetryDelay.inMilliseconds,
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_closed) return;
      _current = _openSource(isReplacement: false);
    });
  }
}

class _Source {
  _Source({required this.cancelToken});

  final CancelToken cancelToken;
  StreamSubscription<SseFrame>? subscription;
  bool opened = false;
  bool disposed = false;

  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    opened = false;
    if (!cancelToken.isCancelled) cancelToken.cancel('closed');
    await subscription?.cancel();
  }
}
