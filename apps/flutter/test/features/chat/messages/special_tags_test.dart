// Failure modes of the special-tag parser and inline grouping
// (`special-tags.tsx` parseSpecialTags 1573-1673, `chat-content.tsx` 718-823):
// 1. text with no tags comes back as exactly one inline group (the seeded
//    path) — a trailing `<options>` must not re-structure the leading text
// 2. a tag still streaming (opened, not closed) renders nothing and reports
//    `hasPendingTag`; a half-arrived opener (`<opt`) is hidden while streaming
//    but kept as text once the stream ended
// 3. `<thinking>` bodies never render
// 4. `<source>` and `<workspace_resource>` become sentinel links inside the
//    surrounding paragraph, spaced off adjacent words, labels escaped
// 5. block tags (`<options>`, `<question>`, `<mothership-error>`) split the
//    markdown into sibling groups in order
// 6. a malformed JSON body is discarded (never rendered as raw JSON); an
//    unclosed tag after the stream ended renders as literal text
// 7. question options named "Other"/"Something else" are stripped; a question
//    with no real options is dropped
// 8. sanitize: inline code wrapped around a chip tag is unwrapped, fences keep
//    their content verbatim, hidden internal refs disappear
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/messages/markdown/chat_sanitize.dart';
import 'package:sim_app/features/chat/messages/markdown/special_tags.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';

List<ChatRenderGroup> groups(String text, {bool streaming = false}) =>
    buildRenderGroups(parseSpecialTags(text, streaming: streaming).pieces);

void main() {
  test('plain text is one inline group', () {
    final g = groups('Flutter E2E workspace\n\n| a | b |');
    expect(g, hasLength(1));
    expect(
      (g.single as ChatInlineGroup).markdown,
      'Flutter E2E workspace\n\n| a | b |',
    );
  });

  test('trailing options keep the leading text group first', () {
    final g = groups(
      'Hello\n<options>{"1":{"title":"Next","description":"d"}}</options>',
    );
    expect(g.first, isA<ChatInlineGroup>());
    final block = (g[1] as ChatBlockGroup).segment as ChatFollowUpsSegment;
    expect(block.options.single.label, 'Next');
    expect(block.options.single.id, 'Next');
  });

  group('streaming', () {
    test('an unclosed tag renders nothing and reports pending', () {
      final parsed = parseSpecialTags('Hi <question>[{"type"', streaming: true);
      expect(parsed.hasPendingTag, isTrue);
      expect(buildRenderGroups(parsed.pieces).single, isA<ChatInlineGroup>());
      expect(
        (buildRenderGroups(parsed.pieces).single as ChatInlineGroup).markdown,
        'Hi ',
      );
    });

    test('a half-arrived opener is hidden while streaming', () {
      final parsed = parseSpecialTags('Done. <opt', streaming: true);
      expect(parsed.hasPendingTag, isTrue);
      expect(
        (buildRenderGroups(parsed.pieces).single as ChatInlineGroup).markdown,
        'Done. ',
      );
    });

    test('after the stream an unknown fragment is plain text', () {
      final parsed = parseSpecialTags('a <b and <opt', streaming: false);
      expect(parsed.hasPendingTag, isFalse);
      expect(
        (buildRenderGroups(parsed.pieces).single as ChatInlineGroup).markdown,
        'a <b and <opt',
      );
    });

    test('an unclosed tag after the stream ended is literal text', () {
      final g = groups('x <options>{"1":');
      expect((g.single as ChatInlineGroup).markdown, 'x <options>{"1":');
    });
  });

  test('thinking bodies never render', () {
    final g = groups('<thinking>secret plan</thinking>Answer');
    expect((g.single as ChatInlineGroup).markdown, 'Answer');
  });

  group('inline chips', () {
    test('a source becomes a sentinel link spaced from the sentence', () {
      final g = groups(
        'GitHub supports it.<source>{"url":"https://docs.github.com/a","title":"Docs [v2]"}</source> Next',
      );
      final inline = g.single as ChatInlineGroup;
      expect(
        inline.markdown,
        r'GitHub supports it. [Docs \[v2\]](<#sim-source-ref-0>) Next',
      );
      expect(inline.sources.single.url, 'https://docs.github.com/a');
    });

    test('a workspace resource is spaced off adjacent words', () {
      final g = groups(
        'Open<workspace_resource>{"type":"table","id":"t1","title":"Leads"}</workspace_resource>now',
      );
      final inline = g.single as ChatInlineGroup;
      expect(inline.markdown, 'Open [Leads](<#sim-workspace-ref-0>) now');
      expect(inline.resources.single.kind, ChatResourceKind.table);
    });
  });

  test('block tags split markdown into ordered sibling groups', () {
    final g = groups(
      'Before\n<mothership-error>{"message":"Rate limited"}</mothership-error>After',
    );
    expect(g, hasLength(3));
    expect((g[0] as ChatInlineGroup).markdown, 'Before\n');
    expect(
      ((g[1] as ChatBlockGroup).segment as ChatErrorSegment).message,
      'Rate limited',
    );
    expect((g[2] as ChatInlineGroup).markdown, 'After');
  });

  test('a malformed JSON body is discarded, not rendered raw', () {
    final g = groups('Pick:<options>{"1": {"title": </options>');
    expect(g, hasLength(1));
    expect((g.single as ChatInlineGroup).markdown, 'Pick:');
  });

  group('questions', () {
    test('catch-all options are stripped and single objects normalised', () {
      final g = groups(
        '<question>{"type":"single_select","prompt":"Which?","options":[{"id":"a","label":"A"},{"id":"o","label":"Other"}]}</question>',
      );
      final q = (g.single as ChatBlockGroup).segment as ChatQuestionSegment;
      expect(q.questions.single.prompt, 'Which?');
      expect(q.questions.single.options.map((o) => o.label), ['A']);
    });

    test('a question without real options is dropped', () {
      final g = groups(
        'x<question>[{"type":"multi_select","prompt":"P","options":[{"id":"o","label":"Something else"}]}]</question>',
      );
      expect(g.whereType<ChatBlockGroup>(), isEmpty);
    });
  });

  group('sanitize', () {
    test('inline code around a chip tag is unwrapped', () {
      expect(
        sanitizeChatDisplayContent(
          'See `<workspace_resource>{"type":"table","id":"t"}</workspace_resource>` now',
        ),
        'See <workspace_resource>{"type":"table","id":"t"}</workspace_resource> now',
      );
    });

    test('fenced content is kept verbatim', () {
      const text =
          '```\n`<workspace_resource>{"type":"table"}</workspace_resource>`\n```';
      expect(sanitizeChatDisplayContent(text), text);
    });

    test('hidden internal references are removed', () {
      expect(
        sanitizeChatDisplayContent('Read `internal/tool-results/x.json` ok'),
        'Read  ok',
      );
    });
  });
}
