// Failure modes of the activity widgets (agent-group/**, activity-status):
// 1. a subagent lane is collapsed by default; tapping the header expands it
//    and shows its rows; a lane with one plain successful tool is not
//    collapsible (no chevron)
// 2. a pending permission forces the lane open and shows the card instead
//    of the row; Allow / For this chat / For every chat / Skip report the
//    decision for that tool; with several pending, the first card offers
//    Allow all / Skip all over every id
// 3. a 404 outcome turns the card into "… — this request is no longer
//    active"; a failure re-enables it
// 4. the main lane groups consecutive tools into one run: one tool → its own
//    title, several finished → the completed title when all succeeded, else
//    a summary with "N stopped/skipped"
// 5. a lane error renders under the header; a live lane header shimmers and
//    shows the 14px loader when no tool runs
// 6. narration renders inline markdown (bold, code) without markers
// 7. a pending watch row is active
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/messages/activity/activity_status.dart';
import 'package:sim_app/features/chat/messages/activity/agent_group.dart';
import 'package:sim_app/features/chat/messages/activity/shimmer.dart';
import 'package:sim_app/features/chat/messages/activity/thinking_loader.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';

import 'support/chat_harness.dart';

ChatToolCallView tool(
  String id, {
  ChatToolState state = ChatToolState.success,
  String? title,
}) => ChatToolCallView(
  id: id,
  name: 'read',
  state: state,
  title: title ?? 'Read $id',
  argsSummary: '{"path":"$id"}',
);

Future<RecordedCallbacks> pumpGroup(
  WidgetTester tester,
  ChatAgentGroupView group, {
  List<String> outstanding = const [],
  RecordedCallbacks? recorded,
}) async {
  final r = recorded ?? RecordedCallbacks();
  await pumpChat(
    tester,
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 704,
        child: ChatAgentGroup(group: group, outstandingIds: outstanding),
      ),
    ),
    callbacks: r.callbacks,
  );
  return r;
}

void main() {
  testWidgets('a subagent lane is collapsed until its header is tapped', (
    tester,
  ) async {
    await pumpGroup(
      tester,
      ChatAgentGroupView(
        id: 'g',
        agentName: 'Research',
        label: 'Researched sources',
        items: [
          ChatAgentToolItem(tool: tool('a')),
          ChatAgentToolItem(tool: tool('b')),
        ],
      ),
    );
    expect(find.text('Researched sources'), findsOneWidget);
    expect(find.text('Read a'), findsNothing);
    expect(byParityId('chat.activity.chevron'), findsOneWidget);
    await tester.tap(byParityId('chat.activity.header'));
    await tester.pumpAndSettle();
    expect(find.text('Read a'), findsOneWidget);
    expect(find.text('Read b'), findsOneWidget);
    await tester.tap(byParityId('chat.activity.header'));
    await tester.pumpAndSettle();
    expect(find.text('Read a'), findsNothing);
  });

  testWidgets('a single plain success is not collapsible', (tester) async {
    await pumpGroup(
      tester,
      ChatAgentGroupView(
        id: 'g',
        agentName: 'Research',
        label: 'Read a',
        items: [ChatAgentToolItem(tool: tool('a'))],
      ),
    );
    expect(byParityId('chat.activity.chevron'), findsNothing);
  });

  testWidgets('a pending permission forces the lane open; decisions report', (
    tester,
  ) async {
    final pending = tool(
      'p',
      state: ChatToolState.awaitingApproval,
      title: 'Run bun test',
    );
    final recorded = await pumpGroup(
      tester,
      ChatAgentGroupView(
        id: 'g',
        agentName: 'Build',
        label: 'Waiting',
        items: [
          ChatAgentToolItem(tool: tool('a')),
          ChatAgentToolItem(tool: pending),
        ],
      ),
      outstanding: const ['p'],
    );
    expect(byParityId('chat.tool.permission'), findsOneWidget);
    expect(find.text('Run bun test'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(recorded.permissions.single.$1, ['p']);
    expect(recorded.permissions.single.$2, ChatPermissionDecision.allow);
  });

  testWidgets("Don't ask again offers chat and global scopes", (tester) async {
    final pending = tool('p', state: ChatToolState.awaitingApproval);
    final recorded = await pumpGroup(
      tester,
      ChatAgentGroupView(
        id: 'g',
        agentName: 'Build',
        label: 'Waiting',
        isMain: true,
        items: [ChatAgentToolItem(tool: pending)],
      ),
      outstanding: const ['p'],
    );
    await tester.tap(find.text("Don't ask again"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('For every chat'));
    await tester.pumpAndSettle();
    expect(recorded.permissions.single.$2, ChatPermissionDecision.alwaysAllow);
  });

  testWidgets('several pending permissions offer Allow all on the first', (
    tester,
  ) async {
    final recorded = await pumpGroup(
      tester,
      ChatAgentGroupView(
        id: 'g',
        agentName: 'Build',
        label: 'Waiting',
        isMain: true,
        items: [
          ChatAgentToolItem(
            tool: tool('p1', state: ChatToolState.awaitingApproval),
          ),
          ChatAgentToolItem(
            tool: tool('p2', state: ChatToolState.awaitingApproval),
          ),
        ],
      ),
      outstanding: const ['p1', 'p2'],
    );
    expect(find.text('2 tools need permission'), findsOneWidget);
    await tester.tap(find.text('Skip all'));
    await tester.pumpAndSettle();
    expect(recorded.permissions.single.$1, ['p1', 'p2']);
    expect(recorded.permissions.single.$2, ChatPermissionDecision.skip);
  });

  testWidgets('a 404 expires the card; a failure re-enables it', (
    tester,
  ) async {
    final recorded = RecordedCallbacks()
      ..permissionOutcome = ChatPermissionOutcome.failed;
    final group = ChatAgentGroupView(
      id: 'g',
      agentName: 'Build',
      label: 'Waiting',
      isMain: true,
      items: [
        ChatAgentToolItem(
          tool: tool(
            'p',
            state: ChatToolState.awaitingApproval,
            title: 'Deploy',
          ),
        ),
      ],
    );
    await pumpGroup(
      tester,
      group,
      outstanding: const ['p'],
      recorded: recorded,
    );
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(recorded.permissions, hasLength(2));
    recorded.permissionOutcome = ChatPermissionOutcome.expired;
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(
      find.text('Deploy — this request is no longer active'),
      findsOneWidget,
    );
  });

  group('main-lane runs', () {
    testWidgets('one tool shows its own title without a chevron', (
      tester,
    ) async {
      await pumpGroup(
        tester,
        ChatAgentGroupView(
          id: 'm',
          agentName: 'mothership',
          label: '',
          isMain: true,
          items: [ChatAgentToolItem(tool: tool('a', title: 'Read Gmail'))],
        ),
      );
      expect(find.text('Read Gmail'), findsOneWidget);
      expect(byParityId('chat.activity.chevron'), findsNothing);
    });

    testWidgets('all succeeded → the completed title', (tester) async {
      await pumpGroup(
        tester,
        ChatAgentGroupView(
          id: 'm',
          agentName: 'mothership',
          label: '',
          isMain: true,
          completedTitle: 'Checked the inbox',
          items: [
            ChatAgentToolItem(tool: tool('a')),
            ChatAgentToolItem(tool: tool('b')),
          ],
        ),
      );
      expect(find.text('Checked the inbox'), findsOneWidget);
      expect(byParityId('chat.activity.chevron'), findsOneWidget);
    });

    testWidgets('interrupted calls are counted in the summary', (tester) async {
      await pumpGroup(
        tester,
        ChatAgentGroupView(
          id: 'm',
          agentName: 'mothership',
          label: '',
          isMain: true,
          completedTitle: 'Checked the inbox',
          items: [
            ChatAgentToolItem(tool: tool('a', title: 'Navigated')),
            ChatAgentToolItem(tool: tool('b', title: 'Read pages')),
            ChatAgentToolItem(tool: tool('c', state: ChatToolState.cancelled)),
          ],
        ),
      );
      expect(find.text('Navigated, read pages · 1 stopped'), findsOneWidget);
    });

    testWidgets('a live run shows the running title with the shimmer', (
      tester,
    ) async {
      await pumpGroup(
        tester,
        ChatAgentGroupView(
          id: 'm',
          agentName: 'mothership',
          label: '',
          isMain: true,
          isLive: true,
          items: [
            ChatAgentToolItem(tool: tool('a')),
            const ChatAgentToolItem(
              tool: ChatToolCallView(
                id: 'b',
                name: 'search',
                state: ChatToolState.executing,
                title: 'Search docs',
                activeTitle: 'Searching docs',
              ),
            ),
          ],
        ),
      );
      expect(find.text('Searching docs'), findsWidgets);
      expect(find.byType(ChatShimmer), findsOneWidget);
    });
  });

  testWidgets('a live lane without a running tool shows the 14px loader', (
    tester,
  ) async {
    await pumpGroup(
      tester,
      const ChatAgentGroupView(
        id: 'g',
        agentName: 'Research',
        label: 'Thinking',
        isLive: true,
        items: [ChatAgentTextItem(content: 'Looking **closer** at `x`')],
      ),
    );
    final loader = tester.widget<ChatThinkingLoader>(
      find.byType(ChatThinkingLoader),
    );
    expect(loader.size, 14);
    await tester.tap(byParityId('chat.activity.header'));
    await tester.pumpAndSettle();
    final narration = tester.widget<RichText>(
      find.descendant(
        of: byParityId('chat.agent.narration'),
        matching: find.byType(RichText),
      ),
    );
    expect(narration.text.toPlainText(), 'Looking closer at x');
  });

  testWidgets('a lane error renders under the header', (tester) async {
    await pumpGroup(
      tester,
      const ChatAgentGroupView(
        id: 'g',
        agentName: 'Research',
        label: 'Research',
        error: 'Rate limited',
        items: [],
      ),
    );
    expect(byParityId('chat.agent.error'), findsOneWidget);
    expect(find.text('Rate limited'), findsOneWidget);
  });

  testWidgets('a pending watch row is active', (tester) async {
    await pumpChat(
      tester,
      const ChatWatchRow(
        segment: ChatWatchSegment(
          label: 'Waiting for workflow run: Daily',
          pending: true,
        ),
      ),
    );
    final status = tester.widget<ChatActivityStatus>(
      find.byType(ChatActivityStatus),
    );
    expect(status.active, isTrue);
    expect(byParityId('chat.watch'), findsOneWidget);
  });
}
