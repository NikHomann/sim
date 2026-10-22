// Failure modes of the completed-activity summary
// (`activity.ts:670-690` `getToolActivitySummaryActions`,
// `tool-activity-group.tsx:71-82` `getToolActivitySummary`):
// 1. a finished multi-call run lists up to three call titles ("Navigated to
//    x, read page y, …") instead of the catalog's action phrases
//    ("Navigated, read pages, clicked elements");
// 2. repeated actions are not collapsed, so one kind of call crowds out the
//    others, or the cap counts duplicates;
// 3. adjacent phrases on one object do not share it ("listed, read tables");
// 4. an operation tool ignores its operation / default operation, a named
//    `sim_cli` command does not read "<past verb> <resource>", an unknown
//    tool loses its own title;
// 5. the subagent header (mapper) and the main-lane run header (renderer)
//    still print titles: the real transcript must show the phrases.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/integration/message_view_mapper.dart';
import 'package:sim_app/features/chat/integration/tool_activity.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_transcript.dart';

import '../messages/support/chat_harness.dart';

ToolActivitySubject _s(
  String name, {
  Map<String, Object?>? params,
  String title = '',
}) => ToolActivitySubject(toolName: name, params: params, title: title);

ContentBlock _tool(
  String id,
  String name, {
  Map<String, Object?>? params,
  String? spanId,
  String? calledBy,
}) => ContentBlock(
  type: ContentBlockType.toolCall,
  spanId: spanId,
  toolCall: ToolCallInfo(
    id: id,
    name: name,
    status: ToolCallStatus.success,
    params: params,
    calledBy: calledBy,
  ),
);

final List<ContentBlock> _browserRun = [
  _tool('t1', 'browser_navigate', params: {'url': 'https://a.example'}),
  _tool('t2', 'browser_read_text'),
  _tool('t3', 'browser_navigate', params: {'url': 'https://b.example'}),
  _tool('t4', 'browser_click', params: {'selector': '#go'}),
  _tool('t5', 'browser_screenshot'),
];

void main() {
  test('1-3. phrases: first occurrence, collapsed, shared objects, capped', () {
    expect(
      toolActivitySummaryActions([
        _s('browser_navigate'),
        _s('browser_read_text'),
        _s('browser_navigate'),
        _s('browser_snapshot'),
        _s('browser_click'),
        _s('browser_screenshot'),
      ], 3),
      ['navigated', 'read pages', 'clicked elements'],
    );
    expect(
      toolActivitySummaryActions([
        _s('list_workspaces'),
        _s('workspaces'),
        _s('read'),
      ], 3),
      ['listed', 'created workspaces', 'read files'],
    );
  });

  test('4. operations, CLI commands and fallbacks', () {
    List<String> one(ToolActivitySubject s) =>
        toolActivitySummaryActions([s], 3);
    expect(one(_s('user_table', params: {'operation': 'query_rows'})), [
      'searched rows',
    ]);
    expect(one(_s('user_table', params: {'operation': 'nope'})), [
      'used tables',
    ]);
    expect(one(_s('deploy_as_api')), ['deployed workflows']);
    expect(one(_s('settings', params: {'action': 'open'})), [
      'opened settings',
    ]);
    expect(one(_s('cli_tables_list')), ['listed tables']);
    expect(one(_s('cli_docs_search')), ['searched Sim docs']);
    expect(one(_s('mcp-x-do_thing', title: 'Ran Do thing')), [
      'ran Do thing',
    ]);
    expect(one(_s('mcp-x-do_thing', title: 'API call')), ['API call']);
    expect(one(_s('browser_new_thing')), ['used the browser']);
    expect(one(_s('mystery')), ['used tools']);
  });

  test('5a. a finished subagent lane reads the phrases', () {
    final views = mapChatMessages([
      const ChatMessage(id: 'u', role: ChatRole.user, content: 'go'),
      ChatMessage(
        id: 'a',
        role: ChatRole.assistant,
        content: '',
        contentBlocks: [
          for (final b in _browserRun)
            _tool(
              b.toolCall!.id,
              b.toolCall!.name,
              params: b.toolCall!.params,
              calledBy: 'research',
            ),
        ],
      ),
    ], const ChatViewContext(chatId: 'c'));
    final lane =
        ((views.last as ChatAssistantMessageView).segments.single
                as ChatAgentGroupSegment)
            .group;
    expect(lane.label, 'Navigated, read pages, clicked elements');
  });

  testWidgets('5b. the main-lane run header in the real transcript reads the '
      'phrases', (tester) async {
    final views = mapChatMessages([
      const ChatMessage(id: 'u', role: ChatRole.user, content: 'go'),
      ChatMessage(
        id: 'a',
        role: ChatRole.assistant,
        content: '',
        contentBlocks: _browserRun,
      ),
    ], const ChatViewContext(chatId: 'c'));
    await pumpChat(tester, ChatTranscript(messages: views, chatId: 'c'));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.textContaining(
        'Navigated, read pages, clicked elements',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });
}
