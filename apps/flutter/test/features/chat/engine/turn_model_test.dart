// Failure modes of the turn reducer (spec chat-engine §4.2, parity rows
// 7, 18-29), driven by the recorded sessions in fixtures/:
// 1. every fixture envelope passes the React-strict validation;
// 2. text deltas of one lane+channel append to one segment; a channel switch
//    closes the other channel's segment and stamps its end;
// 3. a tool call opens a row (closing the lane's text); args stream into
//    `streamingArgs`; the result settles it and clears the streaming args;
// 4. a failed result maps `failed` → error and keeps the error text;
// 5. `awaiting_approval` moves a live call to the permission state, a
//    re-emitted `executing` call moves it back, the result settles it;
// 6. a subagent span groups its tools (spanId/parentSpanId/calledBy); the
//    span end settles a tool left running; the end block sorts at endSeq;
// 7. an error frame appends `<mothership-error>{...}</mothership-error>`
//    once, and `complete{error}` settles running tools as error;
// 8. `complete{cancelled}` settles a running tool as cancelled;
// 9. replayed envelopes at or below lastSeq are no-ops (reconnect dup);
// 10. a result before its call is buffered and drained;
// 11. apply_file_edit folds into the span's prepare_file_edit row;
// 12. `ui.hidden` tools are tracked but not serialised;
// 13. task_armed / task_delivered and compaction start/done nodes;
// 14. a pending span end (`data.pending`) is not a terminal;
// 15. `complete` with `response.async_pause` is not a terminal;
// 16. client-executed tools are flagged unsupported (spec ambiguity 6).

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/chat_message.dart';
import 'package:sim_app/features/chat/engine/special_tags.dart';
import 'package:sim_app/features/chat/engine/turn_model.dart';

import 'support/fixtures.dart';

TurnModel replay(Iterable<EnvelopeLine> lines, [TurnModel? into]) {
  final model = into ?? TurnModel();
  for (final line in lines) {
    reduceEvent(model, line.envelope);
  }
  return model;
}

MothershipStreamEnvelope env(
  int seq,
  String type,
  Map<String, Object?> payload, {
  Map<String, Object?>? scope,
}) => MothershipStreamEnvelope.fromJson({
  'v': 1,
  'type': type,
  'seq': seq,
  'ts': '2026-10-22T10:00:00.000Z',
  'stream': {'streamId': 's'},
  'scope': ?scope,
  'payload': payload,
}, strict: true);

List<ToolCallInfo> tools(List<ContentBlock> blocks) => [
  for (final b in blocks)
    if (b.toolCall != null) b.toolCall!,
];

void main() {
  test('every fixture envelope passes strict validation', () {
    for (final name in fixtureNames) {
      for (final line in loadFixture(name).envelopes) {
        expect(
          isValidMothershipEnvelope(line.json),
          isTrue,
          reason: '$name seq ${line.json['seq']}',
        );
      }
    }
  });

  test('plain text answer', () {
    final model = replay(loadFixture('plain_text_answer').envelopes);
    expect(model.status, TurnStatus.complete);
    final blocks = modelToContentBlocks(model);
    expect(blocks, hasLength(1));
    expect(blocks.single.type, ContentBlockType.text);
    expect(blocks.single.content, 'Hello there.');
    expect(modelMainText(model), 'Hello there.');
  });

  test('thinking then text closes the thinking segment', () {
    final blocks = modelToContentBlocks(
      replay(loadFixture('thinking_then_text').envelopes),
    );
    expect(blocks.map((b) => b.type), [
      ContentBlockType.thinking,
      ContentBlockType.text,
    ]);
    expect(blocks.first.content, 'Let me think about it.');
    expect(blocks.first.endedAt, isNotNull);
    expect(blocks.last.endedAt, isNull);
  });

  test('tool call success', () {
    final fixture = loadFixture('tool_call_success');
    final model = TurnModel();
    final lines = fixture.envelopes;
    replay(lines.take(4), model);
    final mid = tools(modelToContentBlocks(model)).single;
    expect(mid.status, ToolCallStatus.executing);
    expect(mid.params, {'pattern': 'foo'});
    expect(mid.streamingArgs, '{"pattern":');
    replay(lines.skip(4), model);
    final blocks = modelToContentBlocks(model);
    expect(blocks.map((b) => b.type), [
      ContentBlockType.text,
      ContentBlockType.toolCall,
      ContentBlockType.text,
    ]);
    final tool = tools(blocks).single;
    expect(tool.status, ToolCallStatus.success);
    expect(tool.streamingArgs, isNull);
    expect(tool.result?.output, {'matches': 3});
  });

  test('tool error maps failed to error', () {
    final tool = tools(
      modelToContentBlocks(replay(loadFixture('tool_error').envelopes)),
    ).single;
    expect(tool.status, ToolCallStatus.error);
    expect(tool.result?.error, 'Logs unavailable');
  });

  test('permission requested then allowed', () {
    final lines = loadFixture('permission_requested_then_allowed').envelopes;
    final model = replay(lines.take(2));
    expect(
      tools(modelToContentBlocks(model)).single.status,
      ToolCallStatus.awaitingApproval,
    );
    replay(lines.skip(2).take(1), model);
    expect(
      tools(modelToContentBlocks(model)).single.status,
      ToolCallStatus.executing,
    );
    replay(lines.skip(3), model);
    expect(
      tools(modelToContentBlocks(model)).single.status,
      ToolCallStatus.success,
    );
  });

  test('an unanswered prompt at turn end takes the terminal status', () {
    final model = TurnModel();
    reduceEvent(
      model,
      env(1, 'tool', {
        'phase': 'call',
        'toolCallId': 't',
        'toolName': 'x',
        'status': 'awaiting_approval',
      }),
    );
    reduceEvent(model, env(2, 'complete', {'status': 'cancelled'}));
    expect(
      tools(modelToContentBlocks(model)).single.status,
      ToolCallStatus.cancelled,
    );
  });

  test('agent group with nested tools', () {
    final blocks = modelToContentBlocks(
      replay(loadFixture('agent_group_nested_tools').envelopes),
    );
    expect(blocks.map((b) => b.type), [
      ContentBlockType.toolCall,
      ContentBlockType.subagent,
      ContentBlockType.subagentThinking,
      ContentBlockType.toolCall,
      ContentBlockType.toolCall,
      ContentBlockType.subagentEnd,
      ContentBlockType.text,
    ]);
    final agent = blocks[1];
    expect(agent.content, 'workflow');
    expect(agent.subagentName, 'Build the workflow');
    expect(agent.parentToolCallId, 't-delegate');
    final nested = tools(blocks).where((t) => t.calledBy == 'workflow');
    expect(nested.map((t) => t.id), ['t-a1', 't-a2']);
    // t-a2 never got a result: the span end settled it.
    expect(nested.map((t) => t.status), everyElement(ToolCallStatus.success));
    expect(blocks[3].spanId, 'span-a');
    expect(blocks[3].parentSpanId, mainSpan);
    expect(blocks.first.toolCall!.status, ToolCallStatus.success);
  });

  test('error after session appends one mothership-error tag', () {
    final model = replay(loadFixture('error_after_session').envelopes);
    expect(model.status, TurnStatus.error);
    final text = modelMainText(model);
    final segments = parseSpecialTags(text);
    final tag = segments.single as SpecialTagSegment;
    expect(
      decodeMothershipErrorTag(tag)?.message,
      'The agent service is temporarily unavailable. Please try again.',
    );
    // A replayed error frame does not add a second tag.
    final again = TurnModel();
    reduceEvent(
      again,
      env(1, 'text', {'channel': 'assistant', 'text': 'Partial'}),
    );
    reduceEvent(again, env(2, 'error', {'message': 'boom'}));
    reduceEvent(again, env(3, 'error', {'message': 'boom'}));
    expect(
      modelMainText(again),
      'Partial\n<mothership-error>{"message":"boom"}</mothership-error>',
    );
  });

  test('stop mid stream settles the running tool as cancelled', () {
    final model = replay(loadFixture('stop_mid_stream').envelopes);
    expect(model.status, TurnStatus.cancelled);
    expect(
      tools(modelToContentBlocks(model)).single.status,
      ToolCallStatus.cancelled,
    );
  });

  test('reconnect with duplicate seq is idempotent', () {
    final fixture = loadFixture('reconnect_duplicate_seq');
    final model = replay(fixture.postEnvelopes);
    expect(modelMainText(model), 'Part one. Part two. ');
    replay(fixture.tailEnvelopes, model);
    expect(modelMainText(model), 'Part one. Part two. Part three.');
    // A fresh model from the full log rebuilds the same tree.
    final fresh = replay(fixture.tailEnvelopes, replay(fixture.postEnvelopes));
    expect(modelToContentBlocks(fresh), modelToContentBlocks(model));
  });

  test('a result before its call is buffered and drained', () {
    final model = TurnModel();
    reduceEvent(
      model,
      env(1, 'tool', {
        'phase': 'result',
        'toolCallId': 't',
        'toolName': 'grep',
        'success': true,
      }),
    );
    expect(model.order, isEmpty);
    reduceEvent(
      model,
      env(2, 'tool', {'phase': 'call', 'toolCallId': 't', 'toolName': 'grep'}),
    );
    expect(
      tools(modelToContentBlocks(model)).single.status,
      ToolCallStatus.success,
    );
  });

  test('apply_file_edit folds into prepare_file_edit', () {
    final model = TurnModel();
    reduceEvent(
      model,
      env(1, 'tool', {
        'phase': 'call',
        'toolCallId': 'p',
        'toolName': 'prepare_file_edit',
      }),
    );
    reduceEvent(
      model,
      env(2, 'tool', {
        'phase': 'result',
        'toolCallId': 'p',
        'toolName': 'prepare_file_edit',
        'success': true,
      }),
    );
    reduceEvent(
      model,
      env(3, 'tool', {
        'phase': 'call',
        'toolCallId': 'a',
        'toolName': 'apply_file_edit',
      }),
    );
    var rows = tools(modelToContentBlocks(model));
    expect(rows.single.id, 'p');
    expect(rows.single.status, ToolCallStatus.executing);
    reduceEvent(
      model,
      env(4, 'tool', {
        'phase': 'result',
        'toolCallId': 'a',
        'toolName': 'apply_file_edit',
        'success': false,
        'status': 'error',
      }),
    );
    rows = tools(modelToContentBlocks(model));
    expect(rows.single.status, ToolCallStatus.error);
  });

  test('hidden tools are not serialised', () {
    final model = TurnModel();
    reduceEvent(
      model,
      env(1, 'tool', {
        'phase': 'call',
        'toolCallId': 't',
        'toolName': 'update_plan',
        'ui': {'hidden': true},
      }),
    );
    expect(modelToContentBlocks(model), isEmpty);
    expect(model.order, ['t']);
  });

  test('tasks and compaction', () {
    final model = TurnModel();
    reduceEvent(
      model,
      env(1, 'run', {
        'kind': 'task_armed',
        'taskId': 'k',
        'taskKind': 'timer',
        'target': 'x',
        'note': 'n',
      }),
    );
    reduceEvent(model, env(2, 'run', {'kind': 'compaction_start'}));
    reduceEvent(model, env(3, 'run', {'kind': 'compaction_done'}));
    reduceEvent(
      model,
      env(4, 'run', {
        'kind': 'task_delivered',
        'taskId': 'k',
        'status': 'completed',
        'summary': 'ok',
      }),
    );
    final blocks = modelToContentBlocks(model);
    expect(blocks.first.task?.status, 'completed');
    expect(blocks.first.task?.summary, 'ok');
    final compaction = tools(blocks).single;
    expect(compaction.name, 'context_compaction');
    expect(compaction.status, ToolCallStatus.success);
    expect(compaction.displayTitle, contextCompactionDisplayTitle);
  });

  test('pending span end and async pause are not terminals', () {
    final scope = {'lane': 'subagent', 'spanId': 'sp', 'agentId': 'file'};
    final model = TurnModel();
    reduceEvent(
      model,
      env(1, 'span', {
        'kind': 'subagent',
        'event': 'start',
        'agent': 'file',
      }, scope: scope),
    );
    reduceEvent(
      model,
      env(2, 'tool', {
        'phase': 'call',
        'toolCallId': 't',
        'toolName': 'x',
      }, scope: scope),
    );
    reduceEvent(
      model,
      env(3, 'span', {
        'kind': 'subagent',
        'event': 'end',
        'data': {'pending': true},
      }, scope: scope),
    );
    reduceEvent(
      model,
      env(4, 'complete', {
        'status': 'complete',
        'response': {'async_pause': true},
      }),
    );
    expect(model.status, TurnStatus.streaming);
    expect(
      tools(modelToContentBlocks(model)).single.status,
      ToolCallStatus.executing,
    );
  });

  test('client-executed tools are flagged unsupported', () {
    final model = TurnModel();
    reduceEvent(
      model,
      env(1, 'tool', {
        'phase': 'call',
        'toolCallId': 't',
        'toolName': 'run_workflow',
        'executor': 'client',
      }),
    );
    reduceEvent(
      model,
      env(2, 'tool', {
        'phase': 'call',
        'toolCallId': 'b',
        'toolName': 'browser_navigate',
      }),
    );
    expect(
      tools(modelToContentBlocks(model)).map((t) => t.unsupportedOnClient),
      [true, true],
    );
  });

  test('markBlocksStopped cancels unsettled tools and appends stopped', () {
    final model = replay(loadFixture('stop_mid_stream').postEnvelopes.take(3));
    final stopped = markBlocksStopped(modelToContentBlocks(model), nowMs: 99);
    expect(stopped.last.type, ContentBlockType.stopped);
    final tool = tools(stopped).single;
    expect(tool.status, ToolCallStatus.cancelled);
    expect(tool.displayTitle, 'Stopped by user');
    // The text was already closed by the tool; the open tool row is stamped.
    expect(stopped.first.endedAt, isNot(99));
    expect(stopped[1].endedAt, 99);
  });

  test('args_delta refines a streaming sim_cli name', () {
    Map<String, Object?> delta(String chunk) => {
      'phase': 'args_delta',
      'toolCallId': 'c1',
      'toolName': 'sim_cli',
      'executor': 'go',
      'mode': 'sync',
      'argumentsDelta': chunk,
    };
    final known = {'cli_workflows_list', 'cli_workflows'};
    final model = TurnModel(isKnownCliToolName: known.contains);
    reduceEvent(model, env(1, 'tool', delta('{"args": ["workflows"')));
    expect((model.nodes['c1']! as ToolNode).name, 'cli_workflows');
    reduceEvent(model, env(2, 'tool', delta(', "list", "--output"')));
    expect((model.nodes['c1']! as ToolNode).name, 'cli_workflows_list');
    // A later call frame naming the placeholder does not undo it.
    reduceEvent(
      model,
      env(3, 'tool', {
        'phase': 'call',
        'toolCallId': 'c1',
        'toolName': 'sim_cli',
        'executor': 'go',
        'mode': 'sync',
      }),
    );
    expect(
      tools(modelToContentBlocks(model)).single.name,
      'cli_workflows_list',
    );

    final help = TurnModel();
    reduceEvent(help, env(1, 'tool', delta('{"args": ["tables", "--help"')));
    expect((help.nodes['c1']! as ToolNode).name, 'cli_help');
    expect(
      refineStreamingCliToolName(
        '{"args": ["-w", "ws", "unknown"]',
        isKnown: known.contains,
      ),
      isNull,
    );
  });

  test('a call captures the first valid arguments.activity', () {
    Map<String, Object?> call(Map<String, Object?> activity) => {
      'phase': 'call',
      'toolCallId': 't1',
      'toolName': 'grep',
      'executor': 'go',
      'mode': 'sync',
      'arguments': {'pattern': 'x', 'activity': activity},
    };
    final model = TurnModel();
    reduceEvent(model, env(1, 'tool', call({'id': '', 'title': 'bad'})));
    expect((model.nodes['t1']! as ToolNode).activity, isNull);
    reduceEvent(
      model,
      env(2, 'tool', call({'id': ' a1 ', 'title': ' Searching ', 'x': 1})),
    );
    reduceEvent(model, env(3, 'tool', call({'id': 'a2', 'title': 'Other'})));
    expect(
      (model.nodes['t1']! as ToolNode).activity,
      const ToolActivity(id: 'a1', title: 'Searching'),
    );
  });
}
