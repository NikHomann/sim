// Loader of the recorded stream-v1 sessions under `../fixtures/*.jsonl`.
//
// Format (one JSON object per line, shared with the mock copilot server):
// - an object with `"v": 1` is a stream v1 envelope, written as
//   `data: <json>\n\n` in order;
// - `{"$meta": {scenario, description, streamId, chatId, ...}}` (first line)
//   describes the scenario; extra keys are scenario inputs (`decision`);
// - `{"$keepalive": true}` is a `: keepalive` comment frame;
// - `{"$http": {"status": N, "body": {...}}}` replaces the SSE answer of the
//   POST with that status and JSON body;
// - `{"$await": "tool_permission" | "stop"}` pauses the server until the
//   client sends that request;
// - `{"$cut": true}` drops the POST stream without a terminal event;
// - `{"$tail": {"after": "<cursor>"}}` starts the reconnect tail
//   (`GET /api/mothership/chat/stream?streamId&after`): the envelopes after
//   it are served there.

import 'dart:convert';
import 'dart:io';

import 'package:sim_api/sim_api.dart';

sealed class FixtureLine {
  const FixtureLine();
}

class EnvelopeLine extends FixtureLine {
  const EnvelopeLine(this.json);
  final Map<String, Object?> json;

  MothershipStreamEnvelope get envelope =>
      MothershipStreamEnvelope.fromJson(json, strict: true);

  String get sse => 'data: ${jsonEncode(json)}\n\n';
}

class DirectiveLine extends FixtureLine {
  const DirectiveLine(this.name, this.value);
  final String name;
  final Object? value;
}

class Fixture {
  Fixture(this.name, this.lines);

  final String name;
  final List<FixtureLine> lines;

  Map<String, Object?> get meta =>
      (lines
                  .whereType<DirectiveLine>()
                  .firstWhere((l) => l.name == r'$meta')
                  .value!
              as Map)
          .cast<String, Object?>();

  /// Envelopes before the first `$cut`/`$tail` (the POST stream).
  List<EnvelopeLine> get postEnvelopes => [
    for (final line in lines.takeWhile(
      (l) => l is! DirectiveLine || (l.name != r'$cut' && l.name != r'$tail'),
    ))
      if (line is EnvelopeLine) line,
  ];

  /// Envelopes after the `$tail` directive.
  List<EnvelopeLine> get tailEnvelopes => [
    for (final line in lines.skipWhile(
      (l) => l is! DirectiveLine || l.name != r'$tail',
    ))
      if (line is EnvelopeLine) line,
  ];

  List<EnvelopeLine> get envelopes => lines.whereType<EnvelopeLine>().toList();

  DirectiveLine? directive(String name) =>
      lines.whereType<DirectiveLine>().where((l) => l.name == name).firstOrNull;
}

Fixture loadFixture(String name) {
  final file = File('test/features/chat/engine/fixtures/$name.jsonl');
  final lines = <FixtureLine>[];
  for (final raw in file.readAsLinesSync()) {
    if (raw.trim().isEmpty) continue;
    final json = (jsonDecode(raw) as Map).cast<String, Object?>();
    if (json['v'] == 1) {
      lines.add(EnvelopeLine(json));
    } else {
      final entry = json.entries.single;
      lines.add(DirectiveLine(entry.key, entry.value));
    }
  }
  return Fixture(name, lines);
}

const fixtureNames = [
  'plain_text_answer',
  'thinking_then_text',
  'tool_call_success',
  'tool_error',
  'permission_requested_then_allowed',
  'agent_group_nested_tools',
  'error_after_session',
  'stop_mid_stream',
  'reconnect_duplicate_seq',
  'busy_409',
];
