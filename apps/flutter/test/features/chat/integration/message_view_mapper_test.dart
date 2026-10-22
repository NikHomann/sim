// Failure modes of the engine → renderer mapping:
// 1. a block-less persisted assistant message renders nothing (the seeded
//    E2E conversation has no contentBlocks);
// 2. tool rows keep the raw tool id or the wrong tense (executing must read
//    in progress, success completed, cancelled "Stopped …");
// 3. a client-executed tool this app never runs keeps spinning instead of
//    reading as unsupported;
// 4. the dispatch tool of a subagent renders beside its lane, or the lane
//    header shows the agent id instead of the live call / completed label;
// 5. the main lane of a live turn never goes live (no shimmer) or stays
//    live after the turn;
// 6. fork / feedback gating ignores live ids and chat-less messages;
// 7. thinking blocks leak into the transcript.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/integration/message_view_mapper.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';

ContentBlock _tool(
  String id,
  String name,
  ToolCallStatus status, {
  Map<String, Object?>? params,
  String? spanId,
  String? calledBy,
  bool unsupported = false,
}) => ContentBlock(
  type: ContentBlockType.toolCall,
  spanId: spanId,
  toolCall: ToolCallInfo(
    id: id,
    name: name,
    status: status,
    params: params,
    calledBy: calledBy,
    unsupportedOnClient: unsupported,
  ),
);

ChatMessage _assistant(List<ContentBlock> blocks, {String id = 'a1'}) =>
    ChatMessage(
      id: id,
      role: ChatRole.assistant,
      content: '',
      contentBlocks: blocks,
    );

const _user = ChatMessage(id: 'u1', role: ChatRole.user, content: 'hi');

List<ChatSegment> _segments(
  List<ContentBlock> blocks, {
  bool sending = false,
}) =>
    (mapChatMessages([
              _user,
              _assistant(blocks),
            ], ChatViewContext(chatId: 'c1', isSending: sending)).last
            as ChatAssistantMessageView)
        .segments;

List<ChatToolCallView> _tools(List<ChatSegment> segments) => [
  for (final s in segments)
    if (s is ChatAgentGroupSegment)
      for (final item in s.group.items)
        if (item is ChatAgentToolItem) item.tool,
];

void main() {
  test('1. a block-less assistant message is one text segment', () {
    final views = mapChatMessages(const [
      _user,
      ChatMessage(id: 'a1', role: ChatRole.assistant, content: '| a |\n'),
    ], const ChatViewContext(chatId: 'c1'));
    final assistant = views.last as ChatAssistantMessageView;
    expect(assistant.segments.single, isA<ChatTextSegment>());
    expect((assistant.segments.single as ChatTextSegment).content, '| a |\n');
  });

  test('2. tool titles follow the status tense', () {
    final executing = _tools(
      _segments([
        _tool('t1', 'grep', ToolCallStatus.executing, params: {'pattern': 'x'}),
      ], sending: true),
    ).single;
    final done = _tools(
      _segments([
        _tool('t1', 'grep', ToolCallStatus.success, params: {'pattern': 'x'}),
      ]),
    ).single;
    final stopped = _tools(
      _segments([
        _tool('t1', 'grep', ToolCallStatus.cancelled, params: {'pattern': 'x'}),
      ]),
    ).single;
    expect(executing.state, ChatToolState.executing);
    expect(executing.title, isNot('grep'));
    expect(executing.title, startsWith('Search'));
    expect(done.title, startsWith('Searched'));
    expect(stopped.title, startsWith('Stopped'));
    expect(executing.activeTitle, isNotNull);
  });

  test('3. an unsupported client tool reads as an error row', () {
    final tool = _tools(
      _segments([
        _tool(
          't1',
          'run_workflow',
          ToolCallStatus.executing,
          unsupported: true,
        ),
      ], sending: true),
    ).single;
    expect(tool.state, ChatToolState.error);
    expect(tool.title, endsWith(unsupportedToolSuffix));
  });

  test('4. a subagent lane absorbs its dispatch and labels its header', () {
    final segments = _segments([
      _tool('d1', 'workflow', ToolCallStatus.executing),
      const ContentBlock(
        type: ContentBlockType.subagent,
        content: 'workflow',
        spanId: 's1',
        parentToolCallId: 'd1',
      ),
      _tool(
        't1',
        'grep',
        ToolCallStatus.executing,
        params: {'pattern': 'x'},
        spanId: 's1',
        calledBy: 'workflow',
      ),
    ], sending: true);
    final group = segments.whereType<ChatAgentGroupSegment>().single.group;
    expect(group.isMain, isFalse);
    expect(group.id, 'agent-d1');
    expect(group.isLive, isTrue);
    expect(group.label, startsWith('Search'));
    expect(
      _tools(segments).map((t) => t.name),
      ['grep'],
      reason: 'the dispatch row is absorbed by the lane',
    );
    final settled = _segments([
      const ContentBlock(
        type: ContentBlockType.subagent,
        content: 'workflow',
        spanId: 's1',
        parentToolCallId: 'd1',
        endedAt: 1,
      ),
      _tool(
        't1',
        'grep',
        ToolCallStatus.success,
        params: {'pattern': 'x'},
        spanId: 's1',
        calledBy: 'workflow',
      ),
    ]).whereType<ChatAgentGroupSegment>().single.group;
    expect(settled.isLive, isFalse);
    expect(settled.label, startsWith('Searched'));
  });

  test('5. the main lane is live only while its call runs in a live turn', () {
    final live = _segments([
      _tool('t1', 'grep', ToolCallStatus.executing),
    ], sending: true).whereType<ChatAgentGroupSegment>().single.group;
    final idle = _segments([
      _tool('t1', 'grep', ToolCallStatus.success),
    ]).whereType<ChatAgentGroupSegment>().single.group;
    expect(live.isMain, isTrue);
    expect(live.isLive, isTrue);
    expect(idle.isLive, isFalse);
  });

  test('6. fork and feedback gating', () {
    final views = mapChatMessages([
      _user,
      const ChatMessage(
        id: 'live-assistant:u1',
        role: ChatRole.assistant,
        content: 'x',
      ),
    ], const ChatViewContext(chatId: 'c1', isSending: true));
    final live = views.last as ChatAssistantMessageView;
    expect(live.canFork, isFalse);
    expect(live.isStreaming, isTrue);
    expect(live.canFeedback, isTrue);
    final chatless =
        mapChatMessages([
              _user,
              const ChatMessage(
                id: 'a1',
                role: ChatRole.assistant,
                content: 'x',
              ),
            ], const ChatViewContext()).last
            as ChatAssistantMessageView;
    expect(chatless.canFork, isFalse);
    expect(chatless.canFeedback, isFalse);
  });

  test('7. thinking never renders', () {
    final segments = _segments([
      const ContentBlock(type: ContentBlockType.thinking, content: 'secret'),
      const ContentBlock(type: ContentBlockType.text, content: 'Answer'),
    ]);
    expect(segments.single, isA<ChatTextSegment>());
    expect((segments.single as ChatTextSegment).content, 'Answer');
  });
}
