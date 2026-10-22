// Failure modes of the transcript (`mothership-chat.tsx` 865-962,
// `use-auto-scroll.ts`), mounted with the real rows and segments:
// 1. loading with no messages shows the skeleton, not an empty list
// 2. opening a chat lands at the last row; switching chats lands again; a
//    pending chat persisting its id (null → id) does not re-jump
// 3. while streaming the view follows growth; scrolling up detaches it;
//    scrolling back down to within 5px of the bottom re-attaches it
// 4. jumpToBottom (the user's own send) jumps even when detached
// 5. option chips and follow-ups are interactive only on the last message
// 6. below a 768px viewport the side padding is 12px and buttons are 44px
//    targets; a narrow column in a wide viewport stays desktop (24px + the
//    10px scrollbar gutter, 26px buttons)
// 7. the full composition (user rows, text, agent lane with a pending
//    permission, question, sources, tool rows) builds without overflow
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_transcript.dart';

import 'support/chat_harness.dart';

List<ChatMessageView> longConversation(int turns, {String? lastText}) => [
  for (var i = 0; i < turns; i++) ...[
    ChatUserMessageView(id: 'u$i', text: 'Question $i'),
    ChatAssistantMessageView(
      id: 'a$i',
      segments: [
        ChatTextSegment(
          id: 't$i',
          content: i == turns - 1 && lastText != null
              ? lastText
              : 'Answer $i\n\n${'Line of prose. ' * 20}',
        ),
      ],
    ),
  ],
];

ScrollPosition positionOf(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

void main() {
  testWidgets('loading without messages shows the skeleton', (tester) async {
    await pumpChat(tester, const ChatTranscript(messages: [], isLoading: true));
    expect(byParityId('chat.skeleton'), findsOneWidget);
  });

  testWidgets('opening a chat lands at the last row', (tester) async {
    await pumpChat(
      tester,
      ChatTranscript(messages: longConversation(8), chatId: 'c1'),
      size: const Size(800, 600),
    );
    await tester.pumpAndSettle();
    final p = positionOf(tester);
    expect(p.pixels, p.maxScrollExtent);
    expect(p.maxScrollExtent, greaterThan(0));
  });

  testWidgets('switching chats lands again; persisting an id does not', (
    tester,
  ) async {
    Future<void> show(String? chatId, int turns) async {
      await tester.pumpWidget(
        chatApp(
          ChatTranscript(messages: longConversation(turns), chatId: chatId),
        ),
      );
      await tester.pumpAndSettle();
    }

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await show(null, 6);
    positionOf(tester).jumpTo(0);
    await tester.pump();
    await show('c1', 6);
    expect(positionOf(tester).pixels, 0, reason: 'pending persist keeps place');
    await show('c2', 7);
    final p = positionOf(tester);
    expect(p.pixels, p.maxScrollExtent);
  });

  testWidgets('streaming growth is followed until the user scrolls up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ChatTranscriptController();
    Future<void> show(String text) async {
      await tester.pumpWidget(
        chatApp(
          ChatTranscript(
            messages: longConversation(4, lastText: text),
            chatId: 'c',
            isStreaming: true,
            controller: controller,
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    final text = StringBuffer('Start.');
    await show(text.toString());
    for (var i = 0; i < 3; i++) {
      text.write('\n\n${'More streamed prose. ' * 15}');
      await show(text.toString());
      final p = positionOf(tester);
      expect(p.pixels, closeTo(p.maxScrollExtent, 1), reason: 'follows growth');
    }

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pump();
    final detachedAt = positionOf(tester).pixels;
    text.write('\n\n${'Even more prose. ' * 15}');
    await show(text.toString());
    expect(
      positionOf(tester).pixels,
      closeTo(detachedAt, 1),
      reason: 'detached',
    );

    final p = positionOf(tester);
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, -(p.maxScrollExtent - p.pixels) - 50),
    );
    await tester.pump();
    text.write('\n\n${'Final prose. ' * 15}');
    await show(text.toString());
    final after = positionOf(tester);
    expect(
      after.pixels,
      closeTo(after.maxScrollExtent, 1),
      reason: 'reattached',
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pump();
    controller.jumpToBottom();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final jumped = positionOf(tester);
    expect(jumped.pixels, closeTo(jumped.maxScrollExtent, 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('options are interactive only on the last message', (
    tester,
  ) async {
    final recorded = RecordedCallbacks();
    const chips = ChatOptionsSegment(
      options: [ChatOptionView(id: 'x', label: 'Go')],
    );
    await pumpChat(
      tester,
      ChatTranscript(
        chatId: 'c',
        callbacks: recorded.callbacks,
        messages: const [
          ChatAssistantMessageView(id: 'a1', segments: [chips]),
          ChatUserMessageView(id: 'u', text: 'Go'),
          ChatAssistantMessageView(
            id: 'a2',
            segments: [ChatTextSegment(id: 't', content: 'Done')],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go').first, warnIfMissed: false);
    expect(recorded.options, isEmpty);
  });

  testWidgets('below 768px the padding is 12 and actions are 44px', (
    tester,
  ) async {
    await pumpChat(
      tester,
      ChatTranscript(
        messages: seededConversation,
        chatId: 'c',
        callbacks: RecordedCallbacks().callbacks,
      ),
      size: const Size(600, 900),
    );
    await tester.pumpAndSettle();
    final user = tester.getRect(byParityId('chat.message.user'));
    // 10px scrollbar gutter + 12px padding on each side.
    expect(user.left, 22);
    expect(user.width, 556);
    expect(
      tester.getRect(byParityId('chat.message.actions.copy')).size,
      const Size(44, 44),
    );
  });

  // `md:` is a viewport query: the half-width chat beside the resource panel
  // (607.5px at 1440) keeps the desktop padding and 26px actions; the column
  // starts after the 10px gutter + 24px padding (x 34, React 259 - 225).
  testWidgets('a narrow column in a desktop viewport stays desktop', (
    tester,
  ) async {
    await pumpChat(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 607.5,
          child: ChatTranscript(
            messages: seededConversation,
            chatId: 'c',
            callbacks: RecordedCallbacks().callbacks,
          ),
        ),
      ),
      size: const Size(1440, 900),
    );
    await tester.pumpAndSettle();
    final user = tester.getRect(byParityId('chat.message.user'));
    expect(user.left, 34);
    expect(user.width, 539.5);
    expect(
      tester.getRect(byParityId('chat.message.actions.copy')).size,
      const Size(26, 26),
    );
  });

  testWidgets('the full composition renders together', (tester) async {
    final recorded = RecordedCallbacks();
    await pumpChat(
      tester,
      ChatTranscript(
        chatId: 'c',
        callbacks: recorded.callbacks,
        messages: const [
          ChatUserMessageView(
            id: 'u1',
            text: 'Check @Leads and fix the deploy',
            mentions: [
              ChatMentionView(kind: ChatResourceKind.table, label: 'Leads'),
            ],
          ),
          ChatAssistantMessageView(
            id: 'a1',
            canFeedback: true,
            segments: [
              ChatTextSegment(
                id: 't1',
                content:
                    'Looked at <workspace_resource>{"type":"table","id":"t","title":"Leads"}</workspace_resource>. '
                    '<source>{"url":"https://docs.dev","title":"Docs"}</source>\n\n'
                    '1. first\n2. second\n\n```ts\nconst x: number = 1\n```',
              ),
              ChatAgentGroupSegment(
                group: ChatAgentGroupView(
                  id: 'main',
                  agentName: 'mothership',
                  label: '',
                  isMain: true,
                  items: [
                    ChatAgentToolItem(
                      tool: ChatToolCallView(
                        id: 'r',
                        name: 'read',
                        state: ChatToolState.success,
                        title: 'Read workflow',
                      ),
                    ),
                  ],
                ),
              ),
              ChatAgentGroupSegment(
                group: ChatAgentGroupView(
                  id: 'deploy',
                  agentName: 'Deploy',
                  label: 'Deploying',
                  items: [
                    ChatAgentTextItem(content: 'Checking **config**'),
                    ChatAgentToolItem(
                      tool: ChatToolCallView(
                        id: 'p',
                        name: 'deploy',
                        state: ChatToolState.awaitingApproval,
                        title: 'Deploy workflow',
                      ),
                    ),
                  ],
                ),
              ),
              ChatWatchSegment(label: 'Waiting until 9:47 AM', pending: true),
              ChatTextSegment(
                id: 't2',
                content:
                    '<question>{"type":"single_select","prompt":"Ship?","options":[{"id":"y","label":"Yes"}]}</question>',
              ),
            ],
          ),
        ],
      ),
      size: const Size(1000, 1400),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(byParityId('chat.message.user.mention'), findsOneWidget);
    expect(byParityId('chat.workspaceResource.chip'), findsOneWidget);
    expect(byParityId('chat.source.chip'), findsOneWidget);
    expect(byParityId('chat.code'), findsOneWidget);
    expect(byParityId('chat.tool.call'), findsOneWidget);
    expect(byParityId('chat.tool.permission'), findsOneWidget);
    expect(byParityId('chat.agent.narration'), findsOneWidget);
    expect(byParityId('chat.watch'), findsOneWidget);
    expect(byParityId('chat.question'), findsOneWidget);
    expect(byParityId('chat.message.actions'), findsNothing);
    await tester.tap(find.text('Yes'));
    expect(recorded.options.single, 'Ship? — Yes');
    await tester.pumpWidget(const SizedBox());
  });
}
