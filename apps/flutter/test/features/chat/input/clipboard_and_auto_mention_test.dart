// Failure modes of the portable chip codec (`chip-clipboard-codec.ts`) and
// the auto-mention matchers (`use-integration-auto-mention.ts`,
// `use-skill-auto-mention.ts`):
// 1. copy loses a chip (raw `@label` instead of `[label](sim:kind/id)`), or
//    rewrites text that contains no chip (callers detect "no change");
// 2. markdown delimiters in a label break the link; an owner workspace is
//    lost on the round trip;
// 3. a non-portable `sim:` kind or generic markdown is parsed into a chip;
// 4. paste-back joins two chips, or accumulates glue spaces on re-paste;
// 5. skill sentinels leak to the clipboard as EM SPACE;
// 6. a bare integration word in prose is chipped (only `@slack` opts in);
//    `foo@slack` (email-like) is chipped; casing is not canonicalised;
// 7. a `/name` inside a path chips; the skill trigger is not swapped to the
//    sentinel; a longer skill name loses to its prefix.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/input/model/auto_mention.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';
import 'package:sim_app/features/chat/input/model/chat_tokens.dart';
import 'package:sim_app/features/chat/input/model/chip_clipboard_codec.dart';
import 'package:sim_app/features/chat/input/model/composer_resources.dart';

void main() {
  const table = ChatContext(
    kind: ChatContextKind.table,
    label: 'Leads [Q3]',
    fields: {'tableId': 't-1', 'workspaceId': 'ws-9'},
  );
  final skill = ChatContext.skill('sk-1', 'triage');

  group('1-5. portable chip links', () {
    test('serialises chips and leaves plain text byte-identical', () {
      expect(
        serializeSelectionForClipboard('hello there', [table]),
        'hello there',
      );
      final out = serializeSelectionForClipboard(
        'see @Leads [Q3] and ${skillChipTrigger}triage now',
        [table, skill],
      );
      expect(
        out,
        r'see [Leads \[Q3\]](sim:table/t-1?workspace=ws-9) and '
        '[triage](sim:skill/sk-1) now',
      );
    });

    test('round-trips label, id and owner', () {
      final links = parseChipLinks(
        r'x [Leads \[Q3\]](sim:table/t-1?workspace=ws-9) y',
      );
      expect(links, hasLength(1));
      final ctx = chipLinkToContext(links.single);
      expect(ctx.kind, ChatContextKind.table);
      expect(ctx.label, 'Leads [Q3]');
      expect(ctx.field('tableId'), 't-1');
      expect(ctx.workspaceId, 'ws-9');
    });

    test('ignores non-portable kinds and ordinary markdown', () {
      expect(parseChipLinks('[a](https://x.y) [b](sim:blocks/1)'), isEmpty);
    });

    test('paste-back inserts kind-correct tokens with single glue', () {
      final rewritten = rewritePastedChipLinks(
        '[A](sim:workflow/1)[B](sim:skill/2)   [C](sim:file/3) tail',
      )!;
      expect(
        rewritten.text,
        '@A ${skillChipTrigger}B @C tail',
      );
      expect(rewritten.contexts.map((c) => c.kind), [
        ChatContextKind.workflow,
        ChatContextKind.skill,
        ChatContextKind.file,
      ]);
      expect(rewritePastedChipLinks('no links'), isNull);
    });

    test('a lone selection chip is detected for the custom MIME', () {
      const sel = ChatContext(
        kind: ChatContextKind.fileSelection,
        label: 'a.md:1-2',
        fields: {'fileId': 'f', 'fileName': 'a.md', 'text': 'hi'},
      );
      expect(selectionContextsInText('@a.md:1-2', [sel, table]), [sel]);
    });
  });

  group('6. integration auto-mention', () {
    final matcher = IntegrationMatcher(const [
      ComposerIntegration(blockType: 'slack', name: 'Slack'),
      ComposerIntegration(blockType: 'google_sheets', name: 'Google Sheets'),
      ComposerIntegration(blockType: 'google_docs', name: 'Google'),
    ]);

    test('bulk: only explicit @ mentions, casing canonicalised', () {
      final result = matcher.convertText('ping @slack and Slack, mail@slack');
      expect(result.text, 'ping @Slack and Slack, mail@slack');
      expect(result.contexts.single.field('blockType'), 'slack');
    });

    test('longest name wins and boundaries are respected', () {
      final result = matcher.convertText('@google sheets please @Slackbot');
      expect(result.text, '@Google Sheets please @Slackbot');
      expect(result.contexts.single.label, 'Google Sheets');
    });

    test('keystroke: a boundary after @slack canonicalises', () {
      final hit = matcher.processKeystroke('hi @slack', 'hi @slack ', 10)!;
      expect(hit.text, 'hi @Slack ');
      expect(hit.context.label, 'Slack');
      expect(matcher.processKeystroke('hi @slac', 'hi @slack', 9), isNull);
      expect(matcher.processKeystroke('slack', 'slack ', 6), isNull);
    });

    test('mentionify prefixes bare names once', () {
      expect(
        matcher.mentionify('Post to Slack and @Slack'),
        'Post to @Slack and @Slack',
      );
    });
  });

  group('7. skill auto-mention', () {
    final matcher = SlashMatcher(
      skills: const [
        ComposerSkill(id: 's1', name: 'triage'),
        ComposerSkill(id: 's2', name: 'triage-deep'),
      ],
      mcpServers: const [ComposerMcpServer(id: 'm1', name: 'linear')],
    );

    test('bulk swaps each typed slash for the sentinel', () {
      final result = matcher.convertText('/triage-deep then /linear a/triage');
      expect(
        result.text,
        '${skillChipTrigger}triage-deep then ${skillChipTrigger}linear a/triage',
      );
      expect(result.contexts.map((c) => c.label), ['triage-deep', 'linear']);
      // Workspace chats register skills without an owner (organization
      // chats pass one).
      expect(result.contexts.first.workspaceId, isNull);
    });

    test('keystroke boundary chips the completed name', () {
      final hit = matcher.processKeystroke('/triage', '/triage ', 8)!;
      expect(hit.text, '${skillChipTrigger}triage ');
      expect(hit.context.kind, ChatContextKind.skill);
      expect(matcher.processKeystroke('/tri', '/tria', 5), isNull);
    });
  });
}
