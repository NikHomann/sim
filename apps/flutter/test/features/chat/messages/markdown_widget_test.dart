// Failure modes of the markdown renderer (`chat-content.tsx` components):
// 1. prose metrics: p 15/25, headings h1 36/40 … h4 16/24 at weight 600,
//    margins collapse (p→table 18.75, table→code 24, first/last dropped)
// 2. inline code renders without backticks in mono on the chip fill
// 3. links: external http(s) get a favicon slot, mailto/relative do not; a
//    tap reports the href; sentinel links become citation/resource chips
//    and a dangling sentinel index falls back to its label
// 4. images: unresolvable inline file refs are hidden; http images render
// 5. lists (bullets, numbers, nested), task lists (checkbox), blockquote,
//    hr, strikethrough render as their own parity elements
// 6. tables: header + body cells, last row has no rule, a table wider than
//    the column scrolls horizontally and becomes a labelled region
// 7. code: language label (`code` when absent), copy copies the raw fence
//    text and flips to Check for 2000 ms; an empty fence has no header
// 8. raw HTML is shown as text, never interpreted
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/messages/markdown/markdown_view.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chips.dart';
import 'package:sim_design/sim_design.dart';

import 'support/chat_harness.dart';

Future<RecordedCallbacks> pumpMarkdown(
  WidgetTester tester,
  String markdown, {
  List<ChatSourceView> sources = const [],
  List<ChatResourceView> resources = const [],
  double width = 704,
}) async {
  final recorded = RecordedCallbacks();
  await pumpChat(
    tester,
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: ChatMarkdown(
          markdown: markdown,
          sources: sources,
          resources: resources,
        ),
      ),
    ),
    callbacks: recorded.callbacks,
  );
  return recorded;
}

TextStyle styleOfText(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find
        .byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains(text),
        )
        .first,
  );
  TextStyle? found;
  rich.text.visitChildren((span) {
    if (span is TextSpan && (span.text?.contains(text) ?? false)) {
      found = span.style;
      return false;
    }
    return true;
  });
  return (rich.text.style ?? const TextStyle()).merge(found);
}

void main() {
  testWidgets('headings use the prose-base scale at weight 600', (
    tester,
  ) async {
    await pumpMarkdown(
      tester,
      '# One\n\n## Two\n\n### Three\n\n#### Four\n\ntext',
    );
    for (final (tag, size, height) in <(String, double, double)>[
      ('h1', 36, 40),
      ('h2', 24, 32),
      ('h3', 20, 32),
      ('h4', 16, 24),
    ]) {
      final rect = tester.getRect(byParityId('chat.markdown.$tag'));
      expect(rect.height, height, reason: tag);
      final label = {
        'h1': 'One',
        'h2': 'Two',
        'h3': 'Three',
        'h4': 'Four',
      }[tag]!;
      final style = styleOfText(tester, label);
      expect(style.fontSize, size);
      expect(style.fontWeight, FontWeight.w600);
    }
    // First heading has no top margin; h1 → h2 gap is max(12, 24) = 24.
    final h1 = tester.getRect(byParityId('chat.markdown.h1'));
    final h2 = tester.getRect(byParityId('chat.markdown.h2'));
    expect(h1.top, 0);
    expect(h2.top - h1.bottom, 24);
  });

  testWidgets('paragraphs are 15/25 and 18.75px apart', (tester) async {
    await pumpMarkdown(tester, 'first\n\nsecond');
    final ps = byParityId('chat.markdown.p');
    expect(ps, findsNWidgets(2));
    final a = tester.getRect(ps.at(0));
    final b = tester.getRect(ps.at(1));
    expect(a.height, 25);
    expect(b.top - a.bottom, 18.75);
    expect(styleOfText(tester, 'first').fontSize, 15);
  });

  testWidgets('inline code drops the backticks and uses the mono face', (
    tester,
  ) async {
    await pumpMarkdown(tester, 'run `npm test` now');
    final code = find.descendant(
      of: byParityId('chat.markdown.inlineCode'),
      matching: find.text('npm test'),
    );
    expect(code, findsOneWidget);
    expect(tester.widget<Text>(code).style!.fontFamily, 'JetBrains Mono');
    expect(find.textContaining('`'), findsNothing);
  });

  testWidgets('links report their href; only external links get a favicon', (
    tester,
  ) async {
    final recorded = await pumpMarkdown(
      tester,
      '[ext](https://example.com/a) [mail](mailto:a@b.c) [rel](/docs)',
    );
    expect(find.byType(ChatSourceIcon), findsOneWidget);
    final rich = tester.widget<RichText>(
      find
          .byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains('mail'),
          )
          .first,
    );
    final hrefs = <String>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
        (span.recognizer! as TapGestureRecognizer).onTap!();
        hrefs.add(span.text!);
      }
      return true;
    });
    expect(hrefs, <String>['ext', 'mail', 'rel']);
    expect(recorded.links, <String>[
      'https://example.com/a',
      'mailto:a@b.c',
      '/docs',
    ]);
    expect(styleOfText(tester, 'ext').color, SimColors.light.brandBlue);
  });

  testWidgets('sentinel links become chips; dangling ones keep the label', (
    tester,
  ) async {
    final recorded = await pumpMarkdown(
      tester,
      'See [Docs](<#sim-source-ref-0>) and [Leads](<#sim-workspace-ref-0>) '
      'and [gone](<#sim-source-ref-9>).',
      sources: const [ChatSourceView(url: 'https://docs.dev/x', title: 'Docs')],
      resources: const [
        ChatResourceView(
          kind: ChatResourceKind.table,
          id: 't1',
          title: 'Leads',
        ),
      ],
    );
    expect(byParityId('chat.source.chip'), findsOneWidget);
    expect(byParityId('chat.workspaceResource.chip'), findsOneWidget);
    expect(find.textContaining('gone'), findsOneWidget);
    await tester.tap(byParityId('chat.workspaceResource.chip'));
    expect(recorded.resources.single.id, 't1');
    await tester.tap(byParityId('chat.source.chip'));
    expect(recorded.links.single, 'https://docs.dev/x');
  });

  testWidgets('unresolvable inline file images are hidden', (tester) async {
    await pumpMarkdown(tester, '![chart](files/chart.png)\n\nafter');
    expect(byParityId('chat.markdown.image'), findsNothing);
  });

  testWidgets('http images render as an image block', (tester) async {
    await pumpMarkdown(tester, '![chart](https://example.com/c.png)');
    expect(byParityId('chat.markdown.image'), findsOneWidget);
  });

  testWidgets('lists, task lists, blockquote, hr and strike render', (
    tester,
  ) async {
    await pumpMarkdown(
      tester,
      '- one\n- two\n  1. nested\n\npara\n\n- [x] done\n- [ ] todo\n\n> quoted\n\n---\n\n~~gone~~',
    );
    expect(byParityId('chat.markdown.ul'), findsOneWidget);
    expect(byParityId('chat.markdown.ol'), findsOneWidget);
    expect(byParityId('chat.markdown.taskList'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('1.'), findsOneWidget);
    expect(byParityId('chat.markdown.blockquote'), findsOneWidget);
    expect(styleOfText(tester, 'quoted').fontStyle, FontStyle.italic);
    expect(tester.getRect(byParityId('chat.markdown.hr')).height, 1);
    final strike = styleOfText(tester, 'gone');
    expect(strike.decoration, TextDecoration.lineThrough);
    expect(strike.color, SimColors.light.textTertiary);
    final li = tester.getRect(byParityId('chat.markdown.li').first);
    expect(li.height, 25);
  });

  testWidgets('a table wider than the column scrolls and is a region', (
    tester,
  ) async {
    final wide = List<String>.generate(
      8,
      (i) => 'Column number $i',
    ).join(' | ');
    final rule = List<String>.filled(8, '---').join(' | ');
    final cells = List<String>.filled(8, 'value').join(' | ');
    await pumpMarkdown(tester, '| $wide |\n| $rule |\n| $cells |', width: 400);
    await tester.pump();
    final table = tester.getRect(byParityId('chat.table'));
    expect(table.width, 400);
    expect(
      find.descendant(
        of: byParityId('chat.table'),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Scrollable table',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('a narrow table stretches to the column, last row unruled', (
    tester,
  ) async {
    await pumpMarkdown(
      tester,
      '| a | b |\n| --- | ---: |\n| 1 | 2 |\n| 3 | 4 |',
    );
    expect(tester.getRect(byParityId('chat.table')).width, 704);
    final tds = byParityId('chat.table.td');
    expect(tester.getRect(tds.at(0)).height, 41);
    expect(tester.getRect(tds.at(3)).height, 40);
    final right = tester.widget<RichText>(
      find.descendant(of: tds.at(1), matching: find.byType(RichText)),
    );
    expect(right.textAlign, TextAlign.right);
  });

  testWidgets('copy code copies the raw fence and flips for 2000 ms', (
    tester,
  ) async {
    final recorded = await pumpMarkdown(tester, '```\nline one\n```');
    expect(find.text('code'), findsOneWidget);
    await tester.tap(byParityId('chat.code.copy'));
    await tester.pump();
    expect(recorded.copied.single, 'line one\n');
    expect(find.bySemanticsLabel('Copied'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.bySemanticsLabel('Copied'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.bySemanticsLabel('Copy code'), findsOneWidget);
  });

  testWidgets('an empty fence has no header', (tester) async {
    await pumpMarkdown(tester, '```\n```');
    expect(byParityId('chat.code'), findsOneWidget);
    expect(byParityId('chat.code.header'), findsNothing);
  });

  testWidgets('raw HTML is shown as text', (tester) async {
    await pumpMarkdown(tester, 'a <b>bold</b> tag');
    expect(find.textContaining('<b>bold</b>'), findsOneWidget);
  });
}
