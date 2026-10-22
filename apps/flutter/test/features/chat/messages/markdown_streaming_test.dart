// Failure modes of the streaming markdown renderer (Streamdown's memoised
// block rendering, `chat-content.tsx` link/strong components):
// 1. a link tap whose pointer-down and pointer-up straddle a rebuild (a
//    streamed delta, a ticker frame, an equal-but-new callbacks object) is
//    lost when the recognizer is recreated in between
// 2. an older row rebuilds on every transcript build because a new (equal)
//    callbacks object notifies its ChatScope
// 3. every streamed delta re-parses the whole message; completed blocks must
//    keep their parse and rendering, only the tail block is re-parsed
// 4. a growing unclosed fence floods the highlight LRU (one entry per delta),
//    evicting completed blocks so they get re-highlighted
// 5. links are keyboard reachable (Tab, Enter opens, focus-visible outline),
//    carry link semantics and parity ids; inline code inside a link opens it
// 6. chunked parsing is equivalent to a whole-document parse
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:sim_app/features/chat/messages/markdown/code_highlight.dart';
import 'package:sim_app/features/chat/messages/markdown/markdown_view.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/streaming/chat_text_content.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_transcript.dart';
import 'package:sim_design/sim_design.dart';

import 'support/chat_harness.dart';

Finder richTextContaining(String needle) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(needle),
);

/// Global centre of [needle] inside the paragraph that renders it.
Offset textCenter(WidgetTester tester, String needle) {
  final paragraph = tester.renderObject<RenderParagraph>(
    richTextContaining(needle).first,
  );
  final start = paragraph.text.toPlainText().indexOf(needle);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: start + needle.length),
  );
  return paragraph.localToGlobal(boxes.first.toRect().center);
}

TextSpan spanWithText(WidgetTester tester, String text) {
  TextSpan? found;
  for (final rich in tester.widgetList<RichText>(richTextContaining(text))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span;
        return false;
      }
      return true;
    });
  }
  return found!;
}

Widget sized(Widget child) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(width: 704, child: child),
);

/// A ~20k-character answer: prose sections, each with a closed fence.
String longAnswer({int sections = 56}) {
  final b = StringBuffer();
  for (var i = 0; i < sections; i++) {
    b
      ..write('## Section $i\n\n')
      ..write('${'Paragraph $i explains the change in detail. ' * 7}\n\n')
      ..write('```ts\nconst value$i = compute($i);\nexport default value$i;\n')
      ..write('```\n\n');
  }
  return b.toString();
}

void main() {
  group('link taps across rebuilds', () {
    testWidgets('a streamed delta between down and up keeps the tap', (
      tester,
    ) async {
      final recorded = RecordedCallbacks();
      final content = ValueNotifier<String>(
        'see [docs](https://example.com/d) now',
      );
      await pumpChat(
        tester,
        sized(
          ValueListenableBuilder<String>(
            valueListenable: content,
            builder: (context, markdown, _) => ChatMarkdown(markdown: markdown),
          ),
        ),
        callbacks: recorded.callbacks,
      );
      final gesture = await tester.startGesture(textCenter(tester, 'docs'));
      content.value = '${content.value} and more words';
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(recorded.links, <String>['https://example.com/d']);
    });

    testWidgets('an equal callbacks object between down and up keeps it', (
      tester,
    ) async {
      final recorded = RecordedCallbacks();
      final callbacks = recorded.callbacks;
      final tick = ValueNotifier<int>(0);
      await pumpChat(
        tester,
        sized(
          ValueListenableBuilder<int>(
            valueListenable: tick,
            builder: (context, _, child) => ChatScope(
              callbacks: callbacks.withoutOptionSelect(),
              child: child!,
            ),
            child: const ChatMarkdown(markdown: '[docs](/docs)'),
          ),
        ),
      );
      final gesture = await tester.startGesture(textCenter(tester, 'docs'));
      tick.value++;
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(recorded.links, <String>['/docs']);
    });

    test('older-row callbacks compare equal, so ChatScope stays quiet', () {
      final callbacks = RecordedCallbacks().callbacks;
      final a = callbacks.withoutOptionSelect();
      final b = callbacks.withoutOptionSelect();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == callbacks, isFalse, reason: 'onOptionSelect differs');
      final scope = ChatScope(callbacks: a, child: const SizedBox());
      expect(
        ChatScope(callbacks: b, child: const SizedBox()).updateShouldNotify(
          scope,
        ),
        isFalse,
      );
    });
  });

  group('incremental parse and highlight', () {
    late List<String> parses;
    late List<String> highlights;

    setUp(() {
      parses = <String>[];
      highlights = <String>[];
      debugOnChatMarkdownParse = parses.add;
      debugOnChatHighlight = highlights.add;
      debugClearChatHighlightCache();
    });
    tearDown(() {
      debugOnChatMarkdownParse = null;
      debugOnChatHighlight = null;
      SimMotion.scale = 0;
    });

    testWidgets('a delta re-parses only the tail block of a 20k message', (
      tester,
    ) async {
      final answer = longAnswer();
      expect(answer.length, greaterThan(20000));
      final content = ValueNotifier<String>('${answer}Closing words');
      await pumpChat(
        tester,
        SingleChildScrollView(
          child: sized(
            ValueListenableBuilder<String>(
              valueListenable: content,
              builder: (context, markdown, _) =>
                  ChatMarkdown(markdown: markdown),
            ),
          ),
        ),
      );
      parses.clear();
      highlights.clear();
      for (var i = 0; i < 5; i++) {
        content.value = '${content.value} more$i';
        await tester.pump();
      }
      final parsed = parses.fold<int>(0, (sum, s) => sum + s.length);
      expect(parsed, lessThan(500), reason: 'only the tail paragraph');
      expect(highlights, isEmpty);
    });

    testWidgets('a growing fence never re-highlights completed blocks', (
      tester,
    ) async {
      SimMotion.scale = 1;
      final answer = longAnswer();
      final content = StringBuffer('$answer```py\n');
      ChatTextSegment segment() => ChatTextSegment(
        id: 't',
        content: content.toString(),
        streaming: true,
      );
      final notifier = ValueNotifier<ChatTextSegment>(segment());
      await pumpChat(
        tester,
        SingleChildScrollView(
          child: sized(
            ValueListenableBuilder<ChatTextSegment>(
              valueListenable: notifier,
              builder: (context, s, _) => ChatTextContent(segment: s),
            ),
          ),
        ),
      );
      parses.clear();
      final completed = <String>{
        for (var i = 0; i < 56; i++)
          'const value$i = compute($i);\nexport default value$i;',
      };
      const frames = 600;
      for (var i = 0; i < frames; i++) {
        content.write('x$i = $i\n');
        notifier.value = segment();
        await tester.pump(const Duration(milliseconds: 16));
      }
      final perBlock = <String, int>{};
      for (final h in highlights.where(completed.contains)) {
        perBlock[h] = (perBlock[h] ?? 0) + 1;
      }
      expect(perBlock.values.where((n) => n > 1), isEmpty);
      final open = highlights.where((h) => !completed.contains(h)).length;
      // Throttled: at most one live highlight per 100 ms of streaming.
      expect(open, lessThanOrEqualTo(frames * 16 ~/ 100 + 2));
      expect(debugChatHighlightCacheSize, lessThanOrEqualTo(57));
      final longest = parses.fold<int>(
        0,
        (max, s) => s.length > max ? s.length : max,
      );
      expect(longest, lessThan(10000), reason: 'never the whole message');
      await tester.pumpWidget(const SizedBox());
    });

    test('chunked parsing renders like a whole-document parse', () {
      const samples = <String>[
        '# Title\n\npara one\n\npara two',
        '- a\n- b\n\n- c\n\n  continued\n\nafter',
        '1. one\n\n2. two\n\n3. three',
        '```js\nconst a = 1;\n\nconst b = 2;\n```\n\ntext',
        '> quote\n\n> again\n\n    indented\n\n    code',
        'see [x][ref]\n\n[ref]: https://example.com',
        'note[^1]\n\n[^1]: footnote',
        '| a | b |\n| - | - |\n| 1 | 2 |\n\ntext\n***\n\nmore',
        'text\n\n<div>\n\nhtml\n\n</div>\n\nend',
        '~~~\nfence\n\n~~~~\n\nafter tilde',
        'Setext\n===\n\nbody',
        'para\n\n\n\n\nfar para',
      ];
      for (final sample in samples) {
        String html(List<md.Node> nodes) => md.HtmlRenderer().render(nodes);
        final whole = html(parseChatMarkdown(sample));
        final chunked = html(<md.Node>[
          for (final chunk in splitChatMarkdownBlocks(sample))
            ...parseChatMarkdown(chunk),
        ]);
        expect(chunked, whole, reason: sample);
      }
    });
  });

  group('link accessibility', () {
    testWidgets('links and bold text carry their parity ids and link role', (
      tester,
    ) async {
      await pumpChat(
        tester,
        sized(
          const ChatMarkdown(
            markdown: '[ext](https://example.com/a) [rel](/docs) **bold**',
          ),
        ),
        callbacks: RecordedCallbacks().callbacks,
      );
      expect(
        spanWithText(tester, 'ext').semanticsIdentifier,
        'chat.markdown.link.external',
      );
      expect(
        spanWithText(tester, 'rel').semanticsIdentifier,
        'chat.markdown.link',
      );
      expect(
        spanWithText(tester, 'bold').semanticsIdentifier,
        'chat.markdown.strong',
      );
      final handle = tester.ensureSemantics();
      await tester.pump();
      expect(
        find.semantics.byLabel('rel').evaluate().single,
        matchesSemantics(label: 'rel', isLink: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('Tab focuses a link, shows an outline and Enter opens it', (
      tester,
    ) async {
      final recorded = RecordedCallbacks();
      await pumpChat(
        tester,
        sized(const ChatMarkdown(markdown: 'read [the docs](/docs) first')),
        callbacks: recorded.callbacks,
      );
      final paragraph = byParityId('chat.markdown.p');
      final outline = paints
        ..rect(
          style: PaintingStyle.stroke,
          strokeWidth: 2,
          color: SimColors.light.textPrimary,
        );
      expect(tester.renderObject(paragraph), isNot(outline));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.renderObject(paragraph), outline);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(recorded.links, <String>['/docs']);
    });

    testWidgets('inline code inside a link opens the link', (tester) async {
      final recorded = RecordedCallbacks();
      await pumpChat(
        tester,
        sized(const ChatMarkdown(markdown: 'open [`config.ts`](/config)')),
        callbacks: recorded.callbacks,
      );
      await tester.tap(find.text('config.ts'));
      await tester.pump();
      expect(recorded.links, <String>['/config']);
    });

    testWidgets('the transcript column carries its parity id', (tester) async {
      await pumpChat(
        tester,
        const ChatTranscript(messages: seededConversation),
        size: const Size(1000, 700),
      );
      final handle = tester.ensureSemantics();
      await tester.pump();
      final node = find.semantics
          .byPredicate((n) => n.identifier == 'chat.transcript.column')
          .evaluate()
          .single;
      var rect = node.rect;
      for (SemanticsNode? n = node; n != null; n = n.parent) {
        if (n.transform != null) {
          rect = MatrixUtils.transformRect(n.transform!, rect);
        }
      }
      expect(rect.width, ChatTranscriptMetrics.columnMaxWidth);
      expect(rect.center.dx, 500);
      handle.dispose();
    });
  });
}
