// Failure modes the seeded-conversation capture must catch
// (`docs/port/specs/chat-messages.md` "Seeded rendering", 704px column):
// - user row: 12 + 39 + 24 = 75px, bubble right-aligned at the column edge,
//   14 × 8 padding, `--surface-5` fill, single 23px line
// - assistant row: content 320.75 (paragraph 25 at y 0; table at 43.75 —
//   the paragraph's 18.75 margin wins over the table's 16 — 163 tall with
//   41/41/41/40 rows; code block at 230.75, 90 tall = 1 + 35 + 53 + 1),
//   tail at 330.75 (10 + 36), 24px bottom → 390.75
// - the actions row holds exactly copy, like, dislike, fork (26px each, 2px
//   gap) vertically centred in the 36px tail
// - code body is one line coloured with the Prism palette; header label
//   `json`; light and dark token fills (bubble, header, body, border)
// The image is a CI golden (obscured text) plus a platform golden locally.
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_transcript.dart';
import 'package:sim_design/sim_design.dart';

import 'support/chat_harness.dart';

/// Desktop (>= 768) viewport: the 704px column is centred.
const Size _viewport = Size(800, 520);

void expectSeededGeometry(WidgetTester tester) {
  final column = tester.getRect(byParityId('chat.message.user'));
  expect(column.width, 704);
  expect(column.left, (800 - 704) / 2);
  expect(column.top, 16);
  expect(column.height, 75);

  final bubble = tester.getRect(byParityId('chat.message.user.bubble'));
  expect(bubble.height, 39);
  expect(bubble.right, column.right);
  expect(bubble.width, lessThanOrEqualTo(704 * 0.7));

  final row = tester.getRect(byParityId('chat.message.assistant'));
  expect(row.top, column.bottom);
  expect(row.height, closeTo(390.75, 0.01));

  final top = row.top;
  final p = tester.getRect(byParityId('chat.markdown.p'));
  expect(p.top - top, 0);
  expect(p.height, 25);

  final table = tester.getRect(byParityId('chat.table'));
  expect(table.top - top, closeTo(43.75, 0.01));
  expect(table.height, 163);
  expect(table.width, 704);
  final th = tester.getRect(byParityId('chat.table.th').first);
  expect(th.height, 41);
  final tds = byParityId('chat.table.td');
  expect(tds, findsNWidgets(6));
  expect(tester.getRect(tds.at(0)).height, 41);
  expect(tester.getRect(tds.at(5)).height, 40);

  final code = tester.getRect(byParityId('chat.code'));
  expect(code.top - top, closeTo(230.75, 0.01));
  expect(code.height, 90);
  expect(tester.getRect(byParityId('chat.code.header')).height, 35);
  expect(tester.getRect(byParityId('chat.code.body')).height, 53);

  final tail = tester.getRect(byParityId('chat.message.tail'));
  expect(tail.top - top, closeTo(330.75, 0.01));
  expect(tail.height, 36);
  final buttons = <String>[
    'chat.message.actions.copy',
    'chat.message.actions.like',
    'chat.message.actions.dislike',
    'chat.message.actions.fork',
  ].map((id) => tester.getRect(byParityId(id))).toList();
  for (var i = 0; i < buttons.length; i++) {
    expect(buttons[i].size, const Size(26, 26));
    expect(buttons[i].top, tail.top + 5);
    if (i > 0) expect(buttons[i].left - buttons[i - 1].right, 2);
  }
  expect(buttons.first.left, column.left);
  expect(byParityId('chat.message.sources'), findsNothing);
}

void main() {
  final recorded = RecordedCallbacks();

  testWidgets('seeded conversation matches the spec box stack', (tester) async {
    await pumpChat(
      tester,
      ChatTranscript(
        messages: seededConversation,
        chatId: 'chat-1',
        callbacks: recorded.callbacks,
      ),
      size: _viewport,
    );
    await tester.pumpAndSettle();
    expectSeededGeometry(tester);
  });

  testWidgets('seeded conversation keeps the geometry in dark mode', (
    tester,
  ) async {
    await pumpChat(
      tester,
      ChatTranscript(
        messages: seededConversation,
        chatId: 'chat-1',
        callbacks: recorded.callbacks,
      ),
      size: _viewport,
      dark: true,
    );
    await tester.pumpAndSettle();
    expectSeededGeometry(tester);
    const c = SimColors.dark;
    final header = tester.widget<Container>(
      find
          .descendant(
            of: byParityId('chat.code.header'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((header.decoration! as BoxDecoration).color, c.surface4);
    final body = tester.widget<ColoredBox>(
      find
          .descendant(
            of: byParityId('chat.code.body'),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(body.color, c.codeBg);
  });

  for (final dark in <bool>[false, true]) {
    final suffix = dark ? 'dark' : 'light';
    // goldenTest registers the test synchronously.
    // ignore: discarded_futures
    goldenTest(
      'seeded E2E conversation ($suffix)',
      fileName: 'chat_seeded_conversation_$suffix',
      constraints: BoxConstraints.tight(_viewport),
      pumpWidget: (tester, widget) async {
        tester.view.physicalSize = _viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(widget);
      },
      whilePerforming: (tester) async {
        await tester.pumpAndSettle();
        expectSeededGeometry(tester);
        return null;
      },
      builder: () => chatApp(
        ChatTranscript(
          messages: seededConversation,
          chatId: 'chat-1',
          callbacks: recorded.callbacks,
        ),
        dark: dark,
      ),
    );
  }
}
