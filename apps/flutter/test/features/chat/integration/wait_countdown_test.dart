// Failure modes of the live `wait` title and the timer time
// (`tool-call-title.ts:16-50` `useElapsedMs` + `COUNTDOWN_TICK_MS = 250`,
// `watch-activity.tsx:24-28` `toLocaleTimeString([], {hour: '2-digit',
// minute: '2-digit'})`):
// 1. a running wait row is frozen at the title computed when the transcript
//    was mapped ("Waiting 30s" forever) because nothing ticks;
// 2. the countdown restarts at mount instead of resuming from `startedAt`;
// 3. the tick rebuilds the transcript (every row) instead of the live row;
// 4. a settled wait keeps ticking;
// 5. a subagent header naming the running wait does not count down;
// 6. the timer time ignores the locale (always `HH:mm`): en-US must read
//    "09:05 AM", de-DE "09:05".

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/integration/locale_time.dart';
import 'package:sim_app/features/chat/integration/message_view_mapper.dart';
import 'package:sim_app/features/chat/messages/activity/countdown.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_transcript.dart';

import '../messages/support/chat_harness.dart';

ContentBlock _wait(
  String id, {
  required int startedAtMs,
  ToolCallStatus status = ToolCallStatus.executing,
  String? calledBy,
  String? spanId,
}) => ContentBlock(
  type: ContentBlockType.toolCall,
  spanId: spanId,
  toolCall: ToolCallInfo(
    id: id,
    name: 'wait',
    status: status,
    params: const {'seconds': 30, 'reason': 'the build'},
    startedAtMs: startedAtMs,
    calledBy: calledBy,
  ),
);

List<ChatMessageView> _views(List<ContentBlock> blocks) => mapChatMessages([
  const ChatMessage(id: 'u', role: ChatRole.user, content: 'go'),
  ChatMessage(
    id: 'a',
    role: ChatRole.assistant,
    content: '',
    contentBlocks: blocks,
  ),
  const ChatMessage(id: 'u2', role: ChatRole.user, content: 'and then?'),
  const ChatMessage(id: 'a2', role: ChatRole.assistant, content: 'Later.'),
], const ChatViewContext(chatId: 'c'));

Finder _text(String s) => find.textContaining(s, findRichText: true);

void main() {
  testWidgets('1-4. the live wait row counts down on its own, from '
      'startedAt, rebuilding only itself', (tester) async {
    // Started 5 s before the transcript mounts.
    final started = clock.now().millisecondsSinceEpoch - 5000;
    final views = _views([_wait('w1', startedAtMs: started)]);
    await pumpChat(tester, ChatTranscript(messages: views, chatId: 'c'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_text('Waiting 25s for the build'), findsOneWidget);

    // Every element rebuilt by the ticks is the countdown or inside it.
    final rebuilt = <Type>{};
    final outside = <Type>{};
    debugOnRebuildDirtyWidget = (element, _) {
      rebuilt.add(element.widget.runtimeType);
      if (element.widget is! ChatCountdownBuilder &&
          element.findAncestorWidgetOfExactType<ChatCountdownBuilder>() ==
              null) {
        outside.add(element.widget.runtimeType);
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_text('Waiting 24s for the build'), findsOneWidget);
    expect(rebuilt, contains(ChatCountdownBuilder));
    expect(outside, isEmpty, reason: 'only the live row rebuilds');
    debugOnRebuildDirtyWidget = null;

    // A settled wait reads its static title and holds no ticker.
    final done = _views([
      _wait('w1', startedAtMs: started, status: ToolCallStatus.success),
    ]);
    await pumpChat(tester, ChatTranscript(messages: done, chatId: 'c'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ChatCountdownBuilder), findsNothing);
    expect(_text('Waited 30s for the build'), findsOneWidget);
  });

  testWidgets('5. a subagent header naming the running wait counts down', (
    tester,
  ) async {
    final started = clock.now().millisecondsSinceEpoch;
    final views = mapChatMessages([
      const ChatMessage(id: 'u', role: ChatRole.user, content: 'go'),
      ChatMessage(
        id: 'a',
        role: ChatRole.assistant,
        content: '',
        contentBlocks: [
          const ContentBlock(
            type: ContentBlockType.subagent,
            content: 'build',
            spanId: 's1',
          ),
          _wait('w1', startedAtMs: started, calledBy: 'build', spanId: 's1'),
        ],
      ),
    ], const ChatViewContext(chatId: 'c', isSending: true));
    await pumpChat(tester, ChatTranscript(messages: views, chatId: 'c'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_text('Waiting 30s for the build'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    expect(_text('Waiting 28s for the build'), findsWidgets);
  });

  test('6. timer times follow the locale', () {
    final at = DateTime(2026, 1, 1, 9, 5);
    final pm = DateTime(2026, 1, 1, 21, 5);
    expect(formatLocaleTime(at, const Locale('en', 'US')), '09:05 AM');
    expect(formatLocaleTime(pm, const Locale('en', 'US')), '09:05 PM');
    expect(formatLocaleTime(pm, const Locale('de', 'DE')), '21:05');
    expect(formatLocaleTime(pm, const Locale('en', 'GB')), '21:05');

    final fires = DateTime(2026, 1, 1, 21, 5).toUtc().toIso8601String();
    final views = mapChatMessages([
      ChatMessage(
        id: 'a',
        role: ChatRole.assistant,
        content: '',
        contentBlocks: [
          ContentBlock(
            type: ContentBlockType.task,
            task: TaskBlockInfo(
              taskId: 't',
              kind: 'timer',
              status: 'pending',
              target: {'firesAt': fires},
            ),
          ),
        ],
      ),
    ], const ChatViewContext(chatId: 'c', locale: Locale('en', 'US')));
    final watch =
        (views.single as ChatAssistantMessageView).segments.single
            as ChatWatchSegment;
    expect(watch.label, 'Waiting until 09:05 PM');
  });
}
