// Failure modes of the streaming repair pass (Streamdown `remend` behaviour,
// `docs/port/specs/chat-messages.md` "Flutter renderer decision"):
// 1. an unclosed ``` / ~~~ fence swallows nothing after it and renders as a
//    code block (closing fence appended, info string kept)
// 2. a fence opened with a longer run is closed with the same run
// 3. an unclosed **bold**, *italic*, ~~strike~~ or `code` span renders styled,
//    not as literal markers; nested openers close in reverse order
// 4. a dangling marker with nothing after it is dropped, not closed into an
//    empty `****`
// 5. list bullets (`* item`) and intraword/escaped asterisks are not counted
//    as emphasis openers
// 6. markers inside a closed code span or inside a fenced block never trigger
//    repair
// 7. a table whose delimiter row is half-received becomes a table with the
//    header's column count; a lone header row stays text
// 8. a half-received link `[label](http…` renders its label only
// 9. already balanced text is returned unchanged (idempotent)
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:sim_app/features/chat/messages/markdown/markdown_repair.dart';

String html(String source) => md.markdownToHtml(
  source,
  extensionSet: md.ExtensionSet.gitHubFlavored,
);

void main() {
  group('fences', () {
    test('unclosed backtick fence is closed with its info string kept', () {
      final repaired = repairStreamingMarkdown('Intro\n\n```json\n{"a": 1');
      expect(repaired, 'Intro\n\n```json\n{"a": 1\n```');
      expect(html(repaired), contains('<code class="language-json">'));
    });

    test('a longer opening run is closed with the same run', () {
      final repaired = repairStreamingMarkdown('````\ncode ``` inside');
      expect(repaired.endsWith('\n````'), isTrue);
    });

    test('tilde fences are closed with tildes', () {
      expect(repairStreamingMarkdown('~~~py\nx = 1\n'), '~~~py\nx = 1\n~~~');
    });

    test('emphasis markers inside an open fence are left alone', () {
      expect(
        repairStreamingMarkdown('```\n**not bold'),
        '```\n**not bold\n```',
      );
    });

    test('a closed fence followed by text is not reopened', () {
      const text = '```\na\n```\n\nafter';
      expect(repairStreamingMarkdown(text), text);
    });
  });

  group('emphasis', () {
    test('unclosed bold is closed', () {
      expect(repairStreamingMarkdown('This is **bold'), 'This is **bold**');
    });

    test('unclosed italic is closed', () {
      expect(repairStreamingMarkdown('an *idea'), 'an *idea*');
    });

    test('unclosed strikethrough is closed', () {
      expect(repairStreamingMarkdown('~~gone'), '~~gone~~');
    });

    test('unclosed inline code is closed and hides emphasis inside it', () {
      expect(repairStreamingMarkdown('run `npm **x'), 'run `npm **x`');
    });

    test('nested openers close in reverse order', () {
      expect(repairStreamingMarkdown('**bold *both'), '**bold *both***');
    });

    test('a dangling marker at the very end is dropped', () {
      expect(repairStreamingMarkdown('Hello **'), 'Hello ');
      expect(repairStreamingMarkdown('Hello `'), 'Hello ');
    });

    test('list bullets are not italic openers', () {
      const text = '* first\n* second';
      expect(repairStreamingMarkdown(text), text);
    });

    test('intraword and escaped asterisks are ignored', () {
      expect(
        repairStreamingMarkdown(r'2*3 and \*literal'),
        r'2*3 and \*literal',
      );
    });

    test('markers inside a closed code span do not count', () {
      const text = 'use `a*b` here';
      expect(repairStreamingMarkdown(text), text);
    });

    test('balanced text is unchanged', () {
      const text = 'A **b** and *c* with `d` and ~~e~~.';
      expect(repairStreamingMarkdown(text), text);
      expect(repairStreamingMarkdown(repairStreamingMarkdown(text)), text);
    });
  });

  group('tables mid-stream', () {
    test('a half-received delimiter row is completed to the header width', () {
      final repaired = repairStreamingMarkdown(
        '| Resource | Count |\n| --- | -',
      );
      expect(repaired, '| Resource | Count |\n| --- | --- |');
      expect(html(repaired), contains('<table>'));
    });

    test('a lone header row stays text until the delimiter arrives', () {
      const text = '| Resource | Count |';
      expect(repairStreamingMarkdown(text), text);
      expect(html(text), isNot(contains('<table>')));
    });

    test('a partial body row keeps the table', () {
      final repaired = repairStreamingMarkdown(
        '| a | b |\n| --- | --- |\n| 1 | **tw',
      );
      expect(html(repaired), contains('<strong>tw</strong>'));
      expect(html(repaired), contains('<table>'));
    });
  });

  group('links', () {
    test('a half-received link renders its label only', () {
      expect(
        repairStreamingMarkdown('See [the docs](https://exa'),
        'See the docs',
      );
    });

    test('an unclosed label bracket renders as text', () {
      expect(repairStreamingMarkdown('See [the do'), 'See the do');
    });

    test('complete links are untouched', () {
      const text = 'See [docs](https://example.com).';
      expect(repairStreamingMarkdown(text), text);
    });
  });
}
