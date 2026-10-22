// Failure modes (home-page.md Layout "Conversation", "Queued messages",
// States "Queue item ..."; mothership-chat.tsx:858-996,
// queued-messages.tsx):
// - the conversation's scroll padding / 704px column / footer insets drift
// - the queue tray renders for an empty queue, sits beside instead of
//   12px under the composer, or loses its 14px inset
// - Edit is pressable while the row is dispatching or its admission is
//   unknown (it could send twice), or its tooltip does not say why
// - Send now is enabled while dispatching; Remove / Cancel edit do nothing
// - editing does not load the message into the composer
// - the attachment pill shows the name when the tray is narrow, or loses
//   the +N
// - a message chip's resource is not resolved (by id, path or unique
//   name, with one refetch) or the failure is silent

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/home/conversation/queued_messages.dart';
import 'package:sim_app/features/home/home_page.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/placeholder_slots.dart';
import 'package:sim_design/sim_design.dart';

import 'support/home_harness.dart';

const List<PlaceholderMessage> _transcript = <PlaceholderMessage>[
  PlaceholderMessage(role: 'user', content: 'Summarise the seeded workspace.'),
  PlaceholderMessage(role: 'assistant', content: 'Flutter E2E workspace'),
];

const List<HomeQueuedMessage> _queue = <HomeQueuedMessage>[
  HomeQueuedMessage(
    id: 'q1',
    content: 'First follow-up',
    attachments: <HomeAttachment>[
      HomeAttachment(filename: 'report.csv'),
      HomeAttachment(filename: 'notes.md'),
    ],
  ),
  HomeQueuedMessage(id: 'q2', content: 'Second follow-up'),
];

String? _tooltipOf(WidgetTester tester, String parityId) => tester
    .widget<SimTooltip>(
      find.descendant(
        of: byParityId(parityId),
        matching: find.byType(SimTooltip),
      ),
    )
    .message;

Future<void> _conversation(HomeHarness h, WidgetTester tester) async {
  await h.pump(tester, chatPath);
  h.session.setMessages(_transcript);
  await settle(tester);
}

void main() {
  late HomeHarness h;

  setUp(() async {
    h = HomeHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  testWidgets('conversation frame: scroll region, 704px footer, composer', (
    tester,
  ) async {
    await _conversation(h, tester);
    expect(byParityId('home.chat'), findsOneWidget);
    final column = rectOf(tester, 'home.chat-column');
    final footer = rectOf(tester, 'home.chat.footer');
    final composer = rectOf(tester, 'chat-input.root');
    expect(composer.width, 704);
    expect(composer.center.dx, closeTo(column.center.dx, 0.01));
    expect(footer.bottom - composer.bottom, 16);
    expect(composer.height, 80);
    expect(
      h.transcriptProps!.padding,
      const EdgeInsets.fromLTRB(24, 16, 24, 8),
    );
    expect(h.transcriptProps!.maxWidth, 704);
    expect(byParityId('home.queue'), findsNothing);
  });

  testWidgets('queue tray geometry and header', (tester) async {
    await _conversation(h, tester);
    h.session.setQueue(_queue);
    await settle(tester);
    final tray = rectOf(tester, 'home.queue');
    final composer = rectOf(tester, 'chat-input.root');
    expect(tray.left - composer.left, 14);
    expect(composer.right - tray.right, 14);
    // `-mb-3`: the composer overlaps the tray's last 12px.
    expect(tray.bottom - composer.top, 12);
    expect(find.text('2 Queued'), findsOneWidget);
    expect(find.text('First follow-up'), findsOneWidget);
    expect(find.text('report.csv'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    await tester.tap(find.text('2 Queued'));
    await settle(tester);
    expect(find.text('First follow-up'), findsNothing);
  });

  testWidgets('row actions: edit loads the composer, send now, remove', (
    tester,
  ) async {
    await _conversation(h, tester);
    h.session.setQueue(_queue);
    await settle(tester);
    expect(_tooltipOf(tester, 'home.queue.row.edit'), 'Edit queued message');
    await tester.tap(byParityId('home.queue.row.edit'));
    await settle(tester);
    expect(h.session.editingQueuedId, 'q1');
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(PlaceholderComposer),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, 'First follow-up');
    expect(find.bySemanticsLabel('Cancel edit'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Cancel edit'));
    await settle(tester);
    expect(h.session.editingQueuedId, isNull);
    await tester.tap(byParityId('home.queue.row.remove'));
    await settle(tester);
    expect(h.session.queuedMessages.map((m) => m.id), <String>['q2']);
    await tester.tap(byParityId('home.queue.row.send'));
    await settle(tester);
    expect(h.session.queuedMessages, isEmpty);
    expect(h.session.sent.last.$1.text, 'Second follow-up');
  });

  testWidgets('dispatching and admission-unknown rows refuse editing', (
    tester,
  ) async {
    await _conversation(h, tester);
    h.session.setQueue(_queue, dispatchingId: 'q1');
    await settle(tester);
    expect(_tooltipOf(tester, 'home.queue.row.edit'), 'Sending now');
    await tester.tap(byParityId('home.queue.row.edit'));
    await tester.tap(byParityId('home.queue.row.send'));
    await settle(tester);
    expect(h.session.editingQueuedId, isNull);
    expect(h.session.queuedMessages, hasLength(2), reason: 'send disabled');
    h.session.setQueue(<HomeQueuedMessage>[
      const HomeQueuedMessage(
        id: 'q9',
        content: 'Maybe sent',
        admissionUnknown: true,
      ),
    ]);
    await settle(tester);
    expect(
      _tooltipOf(tester, 'home.queue.row.edit'),
      'May already be sent; editing could send a second message',
    );
    await tester.tap(byParityId('home.queue.row.edit'));
    await settle(tester);
    expect(h.session.editingQueuedId, isNull);
  });

  testWidgets('the attachment pill shows only the count when narrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: simLightTheme(),
        builder: (context, child) => SimOverlayHost(child: child!),
        home: Center(
          child: SizedBox(
            width: 300,
            child: QueuedMessagesTray(
              messages: _queue,
              onRemove: (_) {},
              onSendNow: (_) {},
              onEdit: (_) {},
              onCancelEdit: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('report.csv'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('message resource chips: id, unique name after one refetch, '
      'or a toast', (tester) async {
    await _conversation(h, tester);
    final state = tester.state<HomeContentState>(find.byType(HomeContent));
    await state.openResourceRef(
      const HomeResourceRef(
        type: HomeResourceType.table,
        id: 'tbl-1',
        title: 'Deals',
      ),
    );
    await settle(tester);
    expect(h.session.resources.single.id, 'tbl-1');
    var listCalls = 0;
    h.http.handlers['/api/workspaces/$workspaceId/files'] = (_) {
      listCalls++;
      return <String, Object?>{
        'files': <Object?>[
          if (listCalls > 1) <String, Object?>{'id': 'f-9', 'name': 'brief.md'},
        ],
      };
    };
    h.shell.queries.removeQueries(<Object?>['workspace-files']);
    await state.openResourceRef(
      const HomeResourceRef(type: HomeResourceType.file, title: 'brief.md'),
    );
    await settle(tester);
    expect(listCalls, 2, reason: 'one forced refetch after a miss');
    expect(h.session.resources.last.id, 'f-9');
    await state.openResourceRef(
      const HomeResourceRef(type: HomeResourceType.file, title: 'ghost.md'),
    );
    await settle(tester);
    expect(
      h.shell.toasts.toasts.last.message,
      'Couldn\'t find "ghost.md" in this workspace',
    );
    h.http.handlers['/api/workspaces/$workspaceId/files'] = (_) =>
        throw apiError(500);
    h.shell.queries.removeQueries(<Object?>['workspace-files']);
    await state.openResourceRef(
      const HomeResourceRef(type: HomeResourceType.file, title: 'x.md'),
    );
    await settle(tester);
    expect(
      h.shell.toasts.toasts.last.message,
      'Couldn\'t open "x.md" — check your connection and try again',
    );
  });
}
