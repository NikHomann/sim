// Failure modes of the React-strict envelope validation (spec chat-engine
// §2.2, `session/contract.ts:233-509`) and the strict flag on
// `MothershipStreamEnvelope.fromJson`:
// 1. a missing or non-string `ts` is rejected (lenient Dart accepted it);
// 2. a non-object payload is rejected (lenient Dart replaced it with {});
// 3. an unknown `type` is rejected (lenient Dart mapped it to `unknown`);
// 4. `stream.streamId` empty, `trace` without requestId, `scope.lane` not
//    `subagent` are rejected;
// 5. an explicit JSON null in an optional string field fails (JS
//    `undefined` vs `null`), a missing key passes;
// 6. per-type payload checks: session kinds, text channel/offset, tool
//    phase/replay, span kinds, run kinds (incl. `steering_applied`),
//    activityReceipt, error message/error, complete status, resource ops;
// 7. a synthetic `prepare_file_edit` preview frame (no `phase`) passes;
// 8. the thrown error starts with "Client stream schema enforcement failed."
//    and carries the context and hints;
// 9. the lenient path (strict: false) keeps its old behaviour.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

Map<String, Object?> env(
  String type,
  Map<String, Object?> payload, {
  Map<String, Object?>? extra,
}) => {
  'v': 1,
  'type': type,
  'seq': 3,
  'ts': '2026-10-22T10:00:00.000Z',
  'stream': {'streamId': 's1', 'cursor': '3'},
  'trace': {'requestId': 'r1'},
  'payload': payload,
  ...?extra,
};

void main() {
  group('shell', () {
    test('missing ts is rejected', () {
      final e = env('text', {'channel': 'assistant', 'text': 'x'})
        ..remove('ts');
      expect(isValidMothershipEnvelope(e), isFalse);
      expect(
        () => MothershipStreamEnvelope.fromJson(e, strict: true),
        throwsA(isA<MothershipStreamSchemaError>()),
      );
      expect(MothershipStreamEnvelope.fromJson(e).ts, '');
    });

    test('non-object payload is rejected', () {
      final e = env('complete', {})..['payload'] = 'nope';
      expect(
        mothershipEnvelopeProblems(e),
        contains('missing or invalid payload'),
      );
    });

    test('unknown type is rejected with a hint', () {
      final e = env('mystery', {});
      expect(mothershipEnvelopeProblems(e), ['unknown type="mystery"']);
      expect(
        MothershipStreamEnvelope.fromJson(e).type,
        MothershipStreamType.unknown,
      );
    });

    test('bad stream, trace and scope are rejected', () {
      final text = {'channel': 'assistant', 'text': 'x'};
      expect(
        isValidMothershipEnvelope(
          env(
            'text',
            text,
            extra: {
              'stream': {'streamId': ''},
            },
          ),
        ),
        isFalse,
      );
      expect(
        isValidMothershipEnvelope(env('text', text, extra: {'trace': {}})),
        isFalse,
      );
      expect(
        isValidMothershipEnvelope(
          env(
            'text',
            text,
            extra: {
              'scope': {'lane': 'main'},
            },
          ),
        ),
        isFalse,
      );
      expect(
        isValidMothershipEnvelope(
          env(
            'text',
            text,
            extra: {
              'scope': {'lane': 'subagent', 'agentId': 'file', 'spanId': 'x'},
            },
          ),
        ),
        isTrue,
      );
    });

    test('explicit null fails where JS undefined passes', () {
      final text = {'channel': 'assistant', 'text': 'x'};
      expect(
        isValidMothershipEnvelope(
          env(
            'text',
            text,
            extra: {
              'stream': {'streamId': 's', 'chatId': null},
            },
          ),
        ),
        isFalse,
      );
      expect(
        isValidMothershipEnvelope(env('text', text)..remove('trace')),
        isTrue,
      );
      expect(
        isValidMothershipEnvelope(env('text', text)..['trace'] = null),
        isFalse,
      );
    });
  });

  group('payloads', () {
    void valid(String type, Map<String, Object?> payload) => expect(
      isValidMothershipEnvelope(env(type, payload)),
      isTrue,
      reason: '$type $payload',
    );
    void invalid(String type, Map<String, Object?> payload) => expect(
      isValidMothershipEnvelope(env(type, payload)),
      isFalse,
      reason: '$type $payload',
    );

    test('session kinds', () {
      valid('session', {'kind': 'start'});
      valid('session', {'kind': 'chat', 'chatId': 'c'});
      invalid('session', {'kind': 'chat'});
      valid('session', {'kind': 'title', 'title': 'T'});
      invalid('session', {'kind': 'title'});
      valid('session', {'kind': 'trace', 'requestId': 'r'});
      invalid('session', {'kind': 'other'});
    });

    test('text channel and offset', () {
      valid('text', {'channel': 'thinking', 'text': ''});
      invalid('text', {'channel': 'tool', 'text': 'x'});
      invalid('text', {'channel': 'assistant'});
      valid('text', {'channel': 'assistant', 'text': 'x', 'textOffset': 4});
      invalid('text', {'channel': 'assistant', 'text': 'x', 'textOffset': -1});
      invalid('text', {
        'channel': 'assistant',
        'text': 'x',
        'textOffset': 1.5,
      });
    });

    test('tool phase and replay', () {
      final base = {'toolCallId': 't', 'toolName': 'grep'};
      valid('tool', {...base, 'phase': 'call'});
      valid('tool', {...base, 'phase': 'args_delta'});
      valid('tool', {...base, 'phase': 'result', 'replay': true});
      invalid('tool', {...base, 'phase': 'result', 'replay': false});
      invalid('tool', {...base, 'phase': 'start'});
      invalid('tool', {'toolName': 'grep', 'phase': 'call'});
    });

    test('span, run, error and complete', () {
      valid('span', {'kind': 'subagent', 'event': 'start'});
      valid('span', {'kind': 'structured_result'});
      invalid('span', {'kind': 'other'});
      valid('run', {'kind': 'steering_applied'});
      valid('run', {'kind': 'task_armed'});
      invalid('run', {'kind': 'not_a_kind'});
      valid('run', {
        'kind': 'resumed',
        'activityReceipt': {'emitterId': 'e', 'sequence': 0},
      });
      invalid('run', {
        'kind': 'resumed',
        'activityReceipt': {'emitterId': '', 'sequence': 0},
      });
      valid('error', {'message': 'x'});
      valid('error', {'error': 'x'});
      invalid('error', {'code': 'x'});
      valid('complete', {'status': 'complete'});
      invalid('complete', {});
    });

    test('resource ops', () {
      valid('resource', {
        'op': 'upsert',
        'resource': {'type': 'workflow', 'id': 'w1'},
      });
      invalid('resource', {
        'op': 'upsert',
        'resource': {'type': 'workflow', 'id': ' '},
      });
      invalid('resource', {
        'op': 'upsert',
        'resource': {'type': 'spaceship', 'id': 'x'},
      });
      valid('resource', {
        'op': 'clear_view',
        'resource': {'type': 'table', 'id': 't', 'viewId': 'v'},
      });
      valid('resource', {
        'op': 'refresh',
        'resource': {'type': 'settings', 'id': 'x', 'scope': 'workspace'},
      });
      valid('resource', {
        'op': 'refresh',
        'resource': {'type': 'table'},
      });
      invalid('resource', {
        'op': 'move',
        'resource': {'type': 'table', 'id': 't'},
      });
    });

    test('synthetic file preview passes without a phase', () {
      valid('tool', {
        'toolCallId': 't',
        'toolName': 'prepare_file_edit',
        'previewPhase': 'file_preview_content',
        'content': 'abc',
        'contentMode': 'delta',
        'previewVersion': 2,
        'fileName': 'a.md',
      });
      invalid('tool', {
        'toolCallId': 't',
        'toolName': 'prepare_file_edit',
        'previewPhase': 'file_preview_content',
        'contentMode': 'delta',
      });
    });
  });

  test('the error message carries prefix, context and hints', () {
    final e = env('nope', {});
    expect(
      () => MothershipStreamEnvelope.fromJson(
        e,
        strict: true,
        context: 'Live SSE event.',
      ),
      throwsA(
        isA<MothershipStreamSchemaError>().having(
          (error) => error.message,
          'message',
          'Client stream schema enforcement failed. Live SSE event. '
              'A stream event failed validation. unknown type="nope"',
        ),
      ),
    );
  });
}
