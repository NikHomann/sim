// Failure modes of SseDecoder (bytes -> frames -> JSON events):
// 1. a `data:` line split across two byte chunks is reassembled, not cut;
// 2. a multi-byte UTF-8 character split across chunks decodes correctly;
// 3. `\r\n` line ends decode like `\n`;
// 4. comment keepalives (`: ping`) produce no frame;
// 5. a named event carries its `event:` name and `id:`;
// 6. a bare `[DONE]` ends the JSON event stream;
// 7. a JSON-quoted `"[DONE]"` ends it too;
// 8. a malformed JSON frame is skipped (and logged) and later frames flow;
// 9. a final frame without its trailing blank line is delivered at EOF;
// 10. cancelling mid-frame stops the decoder without an error.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:sim_api/sim_api.dart';

Stream<List<int>> bytes(List<String> chunks) =>
    Stream.fromIterable(chunks.map(utf8.encode));

void main() {
  late SseDecoder decoder;
  late List<LogRecord> logs;

  setUp(() {
    final logger = Logger.detached('test.sse')..level = Level.ALL;
    logs = [];
    logger.onRecord.listen(logs.add);
    decoder = SseDecoder(logger: logger);
  });

  test('a data line split across chunks is reassembled', () async {
    final frames = await decoder
        .frames(bytes(['data: {"a":', '1}\n\n']))
        .toList();
    expect(frames.map((f) => f.data), ['{"a":1}']);
  });

  test('a multi-byte character split across chunks decodes', () async {
    final encoded = utf8.encode('data: "é"\n\n');
    final frames = await decoder
        .frames(
          Stream.fromIterable([encoded.sublist(0, 8), encoded.sublist(8)]),
        )
        .toList();
    expect(frames.single.data, '"é"');
  });

  test('CRLF line ends decode like LF', () async {
    final frames = await decoder
        .frames(bytes(['data: {"a":1}\r\n\r\ndata: {"a":2}\r\n\r\n']))
        .toList();
    expect(frames.map((f) => f.data), ['{"a":1}', '{"a":2}']);
  });

  test('comment keepalives produce no frame', () async {
    final frames = await decoder
        .frames(bytes([': connected\n\n: heartbeat\n\ndata: {}\n\n']))
        .toList();
    expect(frames.map((f) => f.data), ['{}']);
  });

  test('a named event carries its name and id', () async {
    final frames = await decoder
        .frames(bytes(['id: 7\nevent: task_status\ndata: {"chatId":"c"}\n\n']))
        .toList();
    expect(frames.single.event, 'task_status');
    expect(frames.single.id, '7');
    expect(frames.single.data, '{"chatId":"c"}');
  });

  test('a bare [DONE] ends the JSON event stream', () async {
    final events = await decoder
        .jsonEvents(
          bytes(['data: {"a":1}\n\ndata: [DONE]\n\ndata: {"a":2}\n\n']),
        )
        .toList();
    expect(events, [
      {'a': 1},
    ]);
  });

  test('a JSON-quoted "[DONE]" ends the JSON event stream', () async {
    final events = await decoder
        .jsonEvents(bytes(['data: {"chunk":"x"}\n\ndata: "[DONE]"\n\n']))
        .toList();
    expect(events, [
      {'chunk': 'x'},
    ]);
  });

  test(
    'a malformed JSON frame is skipped and logged; later frames flow',
    () async {
      final events = await decoder
          .jsonEvents(
            bytes(['data: {"a":1}\n\ndata: {not json\n\ndata: {"a":2}\n\n']),
          )
          .toList();
      expect(events, [
        {'a': 1},
        {'a': 2},
      ]);
      expect(logs.where((r) => r.level >= Level.SEVERE), hasLength(1));
    },
  );

  test(
    'a final frame without a trailing blank line is delivered at EOF',
    () async {
      final frames = await decoder.frames(bytes(['data: {"a":1}\n'])).toList();
      expect(frames.map((f) => f.data), ['{"a":1}']);
    },
  );

  test('cancelling mid-frame stops without an error', () async {
    final controller = StreamController<List<int>>();
    final received = <SseFrame>[];
    final errors = <Object>[];
    final subscription = decoder
        .frames(controller.stream)
        .listen(received.add, onError: errors.add);
    controller.add(utf8.encode('data: {"a":1}\n\ndata: {"par'));
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(controller.hasListener, isFalse);
    await controller.close();
    expect(received.map((f) => f.data), ['{"a":1}']);
    expect(errors, isEmpty);
  });
}
