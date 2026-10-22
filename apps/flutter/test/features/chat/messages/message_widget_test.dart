// Failure modes of the message rows (`mothership-chat.tsx` rows,
// `message-content.tsx` tail, `message-actions.tsx`, special-tag cards):
// 1. tail slot: the last streaming message shows the Thinking shimmer in a
//    10 + 36px slot; settled shows the actions in the same slot (same
//    extent); a non-last streaming message has no slot; the shimmer is
//    hidden (opacity 0) while text paints and a live lane owns the wait
// 2. stopped: "Stopped by user" replaces the slot, actions follow
// 3. actions gating: copy only with text, like/dislike only with
//    feedback, fork only when allowed; copy copies the portable text and
//    flips to "Copied message"; like opens the feedback modal, an empty
//    submit closes without a callback, a typed one reports it; dislike
//    offers Copy ID; fork reports the message id
// 4. a message citing sources shows "N sources"; the popover lists them
//    and "View all sources" reports the message
// 5. a trailing question replaces the actions; single-select answers with
//    "Prompt — Answer"; dismissing brings the actions back; answers render
//    the recap; multi-select toggles + Submit; free text submits on Enter
// 6. follow-ups submit their title on the last message; on older messages
//    they are disabled and the label collapses them
// 7. option chips submit their id; error tags render italic
// 8. user row: mentions become chips inside the bubble, attachments show
//    above it, task notifications render as the centred pill
// 9. segment spacing: 16px between segments, 8px between activity rows
// 10. a streaming text segment reveals progressively with motion on and
//     fades its newest words; with motion off it renders in full
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/messages/activity/thinking_loader.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/streaming/smooth_text.dart';
import 'package:sim_app/features/chat/messages/widgets/assistant_message.dart';
import 'package:sim_app/features/chat/messages/widgets/user_message.dart';
import 'package:sim_design/sim_design.dart';

import 'support/chat_harness.dart';

Future<RecordedCallbacks> pumpAssistant(
  WidgetTester tester,
  ChatAssistantMessageView message, {
  bool isLast = true,
  RecordedCallbacks? recorded,
}) async {
  final r = recorded ?? RecordedCallbacks();
  await pumpChat(
    tester,
    Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 704,
        child: ChatAssistantMessage(message: message, isLast: isLast),
      ),
    ),
    callbacks: r.callbacks,
  );
  await tester.pump();
  return r;
}

const _text = ChatTextSegment(id: 't', content: 'Hello **world**');

double _opacityOf(WidgetTester tester, Finder finder) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: finder, matching: find.byType(AnimatedOpacity)).first,
    )
    .opacity;

void main() {
  group('tail slot', () {
    testWidgets('a streaming last message with nothing yet shows Thinking', (
      tester,
    ) async {
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [],
          isStreaming: true,
        ),
      );
      final tail = tester.getRect(byParityId('chat.message.tail'));
      expect(tail.height, 36);
      expect(find.text('Thinking'), findsOneWidget);
      expect(_opacityOf(tester, byParityId('chat.message.thinking')), 1);
      expect(byParityId('chat.message.actions'), findsNothing);
      final loader = tester.widget<ChatThinkingLoader>(
        find.byType(ChatThinkingLoader),
      );
      expect(loader.size, 20);
    });

    testWidgets('settled swaps in the actions at the same extent', (
      tester,
    ) async {
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [_text],
          isStreaming: true,
        ),
      );
      final streamingRow = tester.getRect(byParityId('chat.message.assistant'));
      // Text is painting: the shimmer is hidden but holds its slot.
      expect(_opacityOf(tester, byParityId('chat.message.thinking')), 0);
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [_text],
          canFeedback: true,
        ),
      );
      await tester.pumpAndSettle();
      final settledRow = tester.getRect(byParityId('chat.message.assistant'));
      expect(byParityId('chat.message.thinking'), findsNothing);
      expect(byParityId('chat.message.actions'), findsOneWidget);
      expect(settledRow.height, streamingRow.height);
    });

    testWidgets('a streaming message that is not last has no slot', (
      tester,
    ) async {
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [_text],
          isStreaming: true,
        ),
        isLast: false,
      );
      expect(byParityId('chat.message.tail'), findsNothing);
    });

    testWidgets('a live lane owns the wait: no turn shimmer', (tester) async {
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          isStreaming: true,
          segments: [
            ChatAgentGroupSegment(
              group: ChatAgentGroupView(
                id: 'g',
                agentName: 'Research',
                label: 'Thinking',
                isLive: true,
                items: [ChatAgentTextItem(content: 'reading')],
              ),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 1600));
      expect(_opacityOf(tester, byParityId('chat.message.thinking')), 0);
    });

    testWidgets('1500 ms of stream silence brings the shimmer back', (
      tester,
    ) async {
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          isStreaming: true,
          thinkingLabel: 'Dispatching',
          segments: [
            ChatToolCallSegment(
              tool: ChatToolCallView(
                id: 'x',
                name: 'read',
                state: ChatToolState.success,
                title: 'Read file',
              ),
            ),
          ],
        ),
      );
      expect(_opacityOf(tester, byParityId('chat.message.thinking')), 0);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(_opacityOf(tester, byParityId('chat.message.thinking')), 1);
      expect(find.text('Dispatching'), findsOneWidget);
    });
  });

  testWidgets('stopped shows the stopped row then the actions', (tester) async {
    await pumpAssistant(
      tester,
      const ChatAssistantMessageView(
        id: 'a',
        segments: [_text, ChatStoppedSegment()],
      ),
    );
    final stopped = tester.getRect(byParityId('chat.message.stopped'));
    final actions = tester.getRect(byParityId('chat.message.actions'));
    expect(find.text('Stopped by user'), findsOneWidget);
    expect(actions.top - stopped.bottom, 10);
    expect(byParityId('chat.message.thinking'), findsNothing);
  });

  group('actions', () {
    testWidgets('gating hides like/dislike and fork when not allowed', (
      tester,
    ) async {
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(id: 'a', segments: [_text]),
      );
      expect(byParityId('chat.message.actions.copy'), findsOneWidget);
      expect(byParityId('chat.message.actions.like'), findsNothing);
      expect(byParityId('chat.message.actions.fork'), findsNothing);
    });

    testWidgets('copy copies portable text and flips its tooltip', (
      tester,
    ) async {
      final recorded = await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [
            ChatTextSegment(
              id: 't',
              content:
                  'See<workspace_resource>{"type":"table","id":"t1","title":"Leads"}</workspace_resource>',
            ),
          ],
        ),
      );
      await tester.tap(byParityId('chat.message.actions.copy'));
      await tester.pump();
      expect(recorded.copied.single, 'See [Leads](sim:table/t1)');
      expect(find.bySemanticsLabel('Copy message'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
    });

    testWidgets('like opens feedback; empty submit closes silently', (
      tester,
    ) async {
      final recorded = await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [_text],
          canFeedback: true,
        ),
      );
      await tester.tap(byParityId('chat.message.actions.like'));
      await tester.pumpAndSettle();
      expect(find.text('Give feedback'), findsOneWidget);
      expect(find.text('Copy ID'), findsNothing);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Give feedback'), findsNothing);
      expect(recorded.feedback, isEmpty);

      await tester.tap(byParityId('chat.message.actions.like'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Great answer');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(recorded.feedback.single, ('a', true, 'Great answer'));
    });

    testWidgets('dislike offers Copy ID for the request', (tester) async {
      final recorded = await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [_text],
          canFeedback: true,
          requestId: 'req-9',
        ),
      );
      await tester.tap(byParityId('chat.message.actions.dislike'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy ID'));
      await tester.pump();
      expect(recorded.copied.single, 'req-9');
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('Copy ID'), findsOneWidget);
    });

    testWidgets('fork reports the message id', (tester) async {
      final recorded = await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [_text],
          canFork: true,
        ),
      );
      await tester.tap(byParityId('chat.message.actions.fork'));
      await tester.pumpAndSettle();
      expect(recorded.forks.single, 'a');
    });

    testWidgets('cited sources add the sources button and popover', (
      tester,
    ) async {
      final recorded = await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [
            ChatTextSegment(
              id: 't',
              content:
                  'Fact.<source>{"url":"https://a.dev/1","title":"One"}</source> '
                  'More.<source>{"url":"https://b.dev/2","siteName":"Bee"}</source> '
                  '<source>{"url":"https://a.dev/1","title":"One"}</source>',
            ),
          ],
        ),
      );
      expect(byParityId('chat.source.chip'), findsNWidgets(3));
      expect(find.text('2'), findsOneWidget);
      await tester.tap(byParityId('chat.message.sources'));
      await tester.pumpAndSettle();
      expect(byParityId('chat.source.card'), findsNWidgets(2));
      await tester.tap(find.text('View all sources'));
      await tester.pumpAndSettle();
      expect(recorded.viewAll.single, 'a');
    });
  });

  group('question', () {
    const question =
        '<question>{"type":"single_select","prompt":"Which env?","options":[{"id":"p","label":"Prod"},{"id":"s","label":"Staging"}]}</question>';

    testWidgets('a trailing question replaces actions and answers', (
      tester,
    ) async {
      final recorded = await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          canFeedback: true,
          segments: [ChatTextSegment(id: 't', content: 'Pick one.\n$question')],
        ),
      );
      expect(byParityId('chat.question'), findsOneWidget);
      expect(byParityId('chat.message.actions'), findsNothing);
      final row = tester.getRect(byParityId('chat.message.assistant'));
      final card = tester.getRect(byParityId('chat.question'));
      expect(row.bottom - card.bottom, 40);
      await tester.tap(find.text('Staging'));
      await tester.pumpAndSettle();
      expect(recorded.options.single, 'Which env? — Staging');
      expect(find.text('Staging'), findsOneWidget);
      expect(find.text('Prod'), findsNothing);
    });

    testWidgets('dismissing brings the actions back', (tester) async {
      final recorded = await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [ChatTextSegment(id: 't', content: question)],
        ),
      );
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.pumpAndSettle();
      expect(recorded.dismissed.single, 'a');
      expect(byParityId('chat.question'), findsNothing);
      expect(byParityId('chat.message.actions'), findsOneWidget);
    });

    testWidgets('transcript answers render the recap', (tester) async {
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          questionAnswers: ['Prod'],
          segments: [ChatTextSegment(id: 't', content: question)],
        ),
      );
      expect(find.text('Which env?'), findsOneWidget);
      expect(find.text('Prod'), findsOneWidget);
      expect(find.text('Something else'), findsNothing);
    });

    testWidgets('multi-select toggles and submits; free text joins it', (
      tester,
    ) async {
      final recorded = await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [
            ChatQuestionSegment(
              questions: [
                ChatQuestionView(
                  prompt: 'Tools?',
                  type: ChatQuestionType.multiSelect,
                  options: [
                    ChatOptionView(id: 'a', label: 'Alpha'),
                    ChatOptionView(id: 'b', label: 'Beta'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      await tester.tap(find.text('Beta'));
      await tester.pump();
      await tester.tap(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'Gamma');
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(recorded.options.single, 'Tools? — Beta, Gamma');
    });

    testWidgets('single-select free text submits on Enter', (tester) async {
      final recorded = await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [ChatTextSegment(id: 't', content: question)],
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'QA');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(recorded.options.single, 'Which env? — QA');
    });
  });

  group('follow-ups and options', () {
    const followUps =
        'Done.<options>{"1":{"title":"Run it","description":"d"},"2":{"title":"Explain","description":"d"}}</options>';

    testWidgets('follow-ups submit their title on the last message', (
      tester,
    ) async {
      final recorded = await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [ChatTextSegment(id: 't', content: followUps)],
        ),
      );
      expect(find.text('Suggested follow-ups'), findsOneWidget);
      await tester.tap(find.text('Explain'));
      expect(recorded.options.single, 'Explain');
    });

    testWidgets('older follow-ups are disabled and collapsible', (
      tester,
    ) async {
      final recorded = RecordedCallbacks();
      await pumpChat(
        tester,
        const SizedBox(
          width: 704,
          child: ChatAssistantMessage(
            message: ChatAssistantMessageView(
              id: 'a',
              segments: [ChatTextSegment(id: 't', content: followUps)],
            ),
          ),
        ),
        callbacks: recorded.callbacks.withoutOptionSelect(),
      );
      await tester.tap(find.text('Explain'), warnIfMissed: false);
      expect(recorded.options, isEmpty);
      await tester.tap(find.text('Suggested follow-ups'));
      await tester.pumpAndSettle();
      expect(find.text('Explain'), findsNothing);
    });

    testWidgets('option chips submit their id; errors are italic', (
      tester,
    ) async {
      final recorded = await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          segments: [
            ChatTextSegment(
              id: 't',
              content:
                  '<mothership-error>{"message":"Provider failed"}</mothership-error>',
            ),
            ChatOptionsSegment(
              options: [ChatOptionView(id: 'retry', label: 'Retry')],
            ),
          ],
        ),
      );
      expect(
        tester.widget<Text>(find.text('Provider failed')).style!.fontStyle,
        FontStyle.italic,
      );
      await tester.tap(find.text('Retry'));
      expect(recorded.options.single, 'retry');
    });
  });

  testWidgets('segments are 16px apart, activity rows 8px', (tester) async {
    const toolA = ChatToolCallSegment(
      tool: ChatToolCallView(
        id: 'a',
        name: 'x',
        state: ChatToolState.success,
        title: 'A',
      ),
    );
    const toolB = ChatToolCallSegment(
      tool: ChatToolCallView(
        id: 'b',
        name: 'x',
        state: ChatToolState.success,
        title: 'B',
      ),
    );
    await pumpAssistant(
      tester,
      const ChatAssistantMessageView(
        id: 'a',
        segments: [
          toolA,
          toolB,
          ChatTextSegment(id: 't', content: 'After'),
        ],
      ),
    );
    final calls = byParityId('chat.tool.call');
    final a = tester.getRect(calls.at(0));
    final b = tester.getRect(calls.at(1));
    final p = tester.getRect(byParityId('chat.markdown.p'));
    expect(b.top - a.bottom, 8);
    expect(p.top - b.bottom, 16);
  });

  group('user row', () {
    testWidgets('mentions become chips, attachments sit above the bubble', (
      tester,
    ) async {
      await pumpChat(
        tester,
        const SizedBox(
          width: 704,
          child: ChatUserMessage(
            message: ChatUserMessageView(
              id: 'u',
              text: 'Summarise @Leads please',
              mentions: [
                ChatMentionView(kind: ChatResourceKind.table, label: 'Leads'),
              ],
              attachments: [
                ChatAttachmentView(
                  id: 'f',
                  filename: 'notes.pdf',
                  mediaType: 'application/pdf',
                ),
              ],
            ),
          ),
        ),
      );
      expect(byParityId('chat.message.user.mention'), findsOneWidget);
      final attachments = tester.getRect(
        byParityId('chat.message.user.attachments'),
      );
      final bubble = tester.getRect(byParityId('chat.message.user.bubble'));
      expect(bubble.top - attachments.bottom, 6);
      expect(attachments.right, bubble.right);
      final row = tester.getRect(byParityId('chat.message.user'));
      expect(bubble.top, greaterThan(row.top + 12));
    });

    testWidgets('a background task renders the centred pill', (tester) async {
      await pumpChat(
        tester,
        const SizedBox(
          width: 704,
          child: ChatUserMessage(
            message: ChatUserMessageView(
              id: 'u',
              text: 'header\nTask 1234-ab completed: report ready',
              isTaskNotification: true,
            ),
          ),
        ),
      );
      expect(byParityId('chat.message.taskNotification'), findsOneWidget);
      expect(find.textContaining('completed: report ready'), findsOneWidget);
      expect(byParityId('chat.message.user.bubble'), findsNothing);
    });
  });

  group('streaming text', () {
    setUp(() => SimMotion.scale = 1);
    tearDown(() => SimMotion.scale = 0);

    testWidgets('reveals progressively and fades its newest words', (
      tester,
    ) async {
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          isStreaming: true,
          segments: [ChatTextSegment(id: 't', content: 'Hi', streaming: true)],
        ),
      );
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          isStreaming: true,
          segments: [
            ChatTextSegment(
              id: 't',
              content: 'Hi there, this is a streamed answer',
              streaming: true,
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      String visible() => tester
          .widgetList<RichText>(
            find.descendant(
              of: byParityId('chat.markdown'),
              matching: find.byType(RichText),
            ),
          )
          .map((r) => r.text.toPlainText())
          .join();
      final early = visible();
      expect(
        early.length,
        lessThan('Hi there, this is a streamed answer'.length),
      );
      var faded = false;
      tester
          .widget<RichText>(
            find
                .descendant(
                  of: byParityId('chat.markdown'),
                  matching: find.byType(RichText),
                )
                .first,
          )
          .text
          .visitChildren((span) {
            final alpha = span.style?.color?.a;
            if (alpha != null && alpha < 1) faded = true;
            return true;
          });
      expect(faded, isTrue);
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(visible(), 'Hi there, this is a streamed answer');
      // The shimmer loops forever with motion on: unmount instead of settle.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('snap reveals the whole backlog at once', (tester) async {
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          isStreaming: true,
          segments: [ChatTextSegment(id: 't', content: '', streaming: true)],
        ),
      );
      await pumpAssistant(
        tester,
        const ChatAssistantMessageView(
          id: 'a',
          isStreaming: true,
          segments: [
            ChatTextSegment(
              id: 't',
              content: 'one two three four',
              streaming: true,
            ),
          ],
        ),
      );
      SmoothTextSnap.snapAll();
      await tester.pump();
      expect(find.text('one two three four'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('with motion off streamed text renders in full', (tester) async {
    await pumpAssistant(
      tester,
      const ChatAssistantMessageView(
        id: 'a',
        isStreaming: true,
        segments: [
          ChatTextSegment(
            id: 't',
            content: 'Complete sentence here.',
            streaming: true,
          ),
        ],
      ),
    );
    expect(find.text('Complete sentence here.'), findsOneWidget);
  });
}
