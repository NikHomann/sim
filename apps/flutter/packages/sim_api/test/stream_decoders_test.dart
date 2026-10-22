// Failure modes of the API-flavour and mothership frame decoders:
// 1. a frame with `event` set must never be appended as answer text, and an
//    empty `chunk` is not answer text either;
// 2. a tool frame with an unrecognised end status is a protocol violation
//    and is rejected rather than rendered as a success;
// 3. an `error` frame is terminal even without a blockId;
// 4. a mothership envelope with another version or without a stream ref is
//    rejected;
// 5. seq tracking reports gaps and ignores replays.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

void main() {
  group('ApiStreamEvent', () {
    test('event-carrying and empty chunks are not answer text', () {
      expect(
        ApiStreamEvent.fromJson({
          'blockId': 'b',
          'chunk': 'x',
          'event': 'thinking',
          'data': 'd',
        }),
        isA<ApiStreamThinking>(),
      );
      expect(
        ApiStreamEvent.fromJson({'blockId': 'b', 'chunk': ''}),
        isA<ApiStreamUnknown>(),
      );
      expect(
        ApiStreamEvent.fromJson({'blockId': 'b', 'chunk': 'x'}),
        isA<ApiStreamChunk>(),
      );
    });

    test('a tool frame with an unknown status is rejected', () {
      final frame = {
        'blockId': 'b',
        'event': 'tool',
        'phase': 'end',
        'id': 't1',
        'name': 'search',
        'status': 'maybe',
      };
      expect(ApiStreamEvent.fromJson(frame), isA<ApiStreamUnknown>());
      expect(
        ApiStreamEvent.fromJson({...frame, 'status': 'success'}),
        isA<ApiStreamTool>().having((t) => t.status, 'status', 'success'),
      );
    });

    test('an error frame needs no blockId', () {
      final event = ApiStreamEvent.fromJson({
        'event': 'error',
        'error': 'boom',
      });
      expect(
        event,
        isA<ApiStreamError>().having((e) => e.error, 'error', 'boom'),
      );
      expect(
        ApiStreamEvent.fromJson({'event': 'final', 'data': 'not a map'}),
        isA<ApiStreamUnknown>(),
      );
    });
  });

  group('MothershipStreamEnvelope', () {
    final valid = {
      'v': 1,
      'type': 'text',
      'seq': 3,
      'ts': 't',
      'stream': {'streamId': 's1', 'cursor': 'c3'},
      'payload': {'channel': 'assistant', 'text': 'hi'},
    };

    test('other versions and missing stream refs are rejected', () {
      expect(
        () => MothershipStreamEnvelope.fromJson({...valid, 'v': 2}),
        throwsFormatException,
      );
      expect(
        () => MothershipStreamEnvelope.fromJson({
          ...valid,
          'stream': <String, Object?>{},
        }),
        throwsFormatException,
      );
      final envelope = MothershipStreamEnvelope.fromJson(valid);
      expect(envelope.type, MothershipStreamType.text);
      expect(envelope.stream.cursor, 'c3');
      expect(envelope.isTerminal, isFalse);
      expect(
        MothershipStreamEnvelope.fromJson({
          ...valid,
          'type': 'complete',
        }).isTerminal,
        isTrue,
      );
      expect(
        MothershipStreamEnvelope.fromJson({...valid, 'type': 'later'}).type,
        MothershipStreamType.unknown,
      );
    });

    test('seq tracking reports gaps and ignores replays', () {
      final tracker = MothershipSeqTracker();
      expect(tracker.record(1), 0);
      expect(tracker.record(2), 0);
      expect(tracker.record(5), 2);
      expect(tracker.record(4), 0);
      expect(tracker.lastSeq, 5);
    });
  });
}
