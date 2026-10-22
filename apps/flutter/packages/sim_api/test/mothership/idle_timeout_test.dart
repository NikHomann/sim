// Failure modes of the SSE idle timeout (spec chat-engine §2.1, F1; React
// `readSSELines` idleTimeoutMs = 45 s):
// 1. a silent stream fails with SseIdleTimeoutError after the window;
// 2. comment-only chunks (`: keepalive`) reset the window: they are raw
//    chunks even though the decoder drops them;
// 3. the source subscription is cancelled on timeout (the reader stops);
// 4. a stream that ends inside the window completes normally, no error.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

void main() {
  const window = Duration(milliseconds: 120);

  test(
    'silence fails with SseIdleTimeoutError and cancels the source',
    () async {
      var cancelled = false;
      final source = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final errors = <Object>[];
      final done = Completer<void>();
      withSseIdleTimeout(source.stream, window).listen(
        (_) {},
        onError: errors.add,
        onDone: done.complete,
      );
      await done.future.timeout(const Duration(seconds: 2));
      expect(errors.single, isA<SseIdleTimeoutError>());
      expect(cancelled, isTrue);
    },
  );

  test('keepalive comments reset the window', () async {
    final source = StreamController<List<int>>();
    final frames = <SseFrame>[];
    final errors = <Object>[];
    final sub = SseDecoder()
        .frames(withSseIdleTimeout(source.stream, window))
        .listen(frames.add, onError: errors.add);
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      source.add(utf8.encode(': keepalive\n\n'));
    }
    source.add(utf8.encode('data: {"a":1}\n\n'));
    await source.close();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(errors, isEmpty);
    expect(frames.map((f) => f.data), ['{"a":1}']);
    await sub.cancel();
  });

  test('an ended stream completes without error', () async {
    final out = await withSseIdleTimeout(
      Stream.fromIterable([utf8.encode('data: 1\n\n')]),
      window,
    ).toList();
    expect(out, hasLength(1));
  });
}
