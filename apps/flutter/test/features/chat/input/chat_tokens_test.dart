// Failure modes of the token layer (chat-input.md "Triggers and chips",
// `copilot/.../user-input/utils.ts`, `use-mention-tokens.ts`,
// `use-mention-menu.ts`, `chip-selection.ts`):
// 1. a label that is a prefix of another label matches the shorter token
//    inside the longer one (longest-first alternation is required);
// 2. skill/MCP tokens use the EM SPACE sentinel and slash commands `/`;
//    current_workflow never produces a token;
// 3. a context whose token left the text survives into submit (pruning);
// 4. chip ranges miss the start-of-text / end-of-text forms, or a range
//    swallows the space glue so deleting one chip eats a neighbour's space;
// 5. deleting a chip leaves a double space seam (only the seam it created
//    collapses);
// 6. `@` inside a word (emails) or inside a completed chip opens the menu;
//    a space right after `@` keeps it open; a newline in the query keeps it
//    open (the editor checks that, see controller tests);
// 7. selection snapping inverts a range, collapses a ranged selection, or
//    moves an edge that was not inside a chip;
// 8. a duplicate label silently drops the second context instead of the
//    ` (n)` ordinal.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';
import 'package:sim_app/features/chat/input/model/chat_tokens.dart';

ChatContext wf(String id, String label) => ChatContext.workflow(id, label);

void main() {
  group('1-2. tokens and highlight ranges', () {
    test('longest label wins over its prefix', () {
      final ranges = computeMentionHighlightRanges('see @Sales Report now', [
        '@Sales',
        '@Sales Report',
      ]);
      expect(ranges, hasLength(1));
      expect(ranges.single.token, '@Sales Report');
      expect(ranges.single.start, 4);
      expect(ranges.single.end, 17);
    });

    test('per-kind triggers; current_workflow has no token', () {
      final tokens = extractContextTokens([
        ChatContext.skill('s1', 'triage'),
        ChatContext.mcp('m1', 'Linear MCP'),
        const ChatContext(
          kind: ChatContextKind.slashCommand,
          label: 'web',
          fields: {'command': 'web'},
        ),
        const ChatContext(
          kind: ChatContextKind.currentWorkflow,
          label: 'Current',
          fields: {'workflowId': 'w'},
        ),
        wf('w1', 'Onboarding'),
      ]);
      expect(tokens, [
        '${skillChipTrigger}triage',
        '${skillChipTrigger}Linear MCP',
        '/web',
        '@Onboarding',
      ]);
      expect(skillChipTrigger, ' ');
      expect(restoreSkillTriggerText('a  triage b'), 'a /triage b');
    });
  });

  group('3. pruning', () {
    test('drops contexts whose token left the text, keeps identity '
        'when nothing changed', () {
      final a = wf('1', 'Alpha');
      final b = wf('2', 'Beta');
      final both = [a, b];
      expect(
        filterContextsPresentInMessage(both, '@Alpha and @Beta '),
        same(both),
      );
      expect(filterContextsPresentInMessage(both, '@Alpha and Beta'), [a]);
      expect(filterContextsPresentInMessage(both, ''), isEmpty);
    });
  });

  group('4. chip ranges', () {
    final ctx = [wf('1', 'Alpha'), wf('2', 'Beta')];

    test('start, space-wrapped and end forms include the glue spaces', () {
      final ranges = computeChipRanges('@Alpha x @Beta', ctx);
      expect(
        ranges.map((r) => (r.start, r.end)).toList(),
        [(0, 7), (8, 14)],
      );
      final wrapped = computeChipRanges('x @Alpha y', ctx);
      expect(wrapped.single.start, 1);
      expect(wrapped.single.end, 9);
    });

    test('findRangeContaining is strict at both edges', () {
      final ranges = computeChipRanges('x @Alpha y', ctx);
      expect(findRangeContaining(ranges, 1), isNull);
      expect(findRangeContaining(ranges, 2), isNotNull);
      expect(findRangeContaining(ranges, 8), isNotNull);
      expect(findRangeContaining(ranges, 9), isNull);
    });
  });

  group('5. atomic delete', () {
    test('removes the token with both glue spaces (upstream joins the '
        'neighbouring words)', () {
      final ctx = [wf('1', 'Alpha')];
      const text = 'one  two @Alpha three';
      final range = computeChipRanges(text, ctx).single;
      final result = deleteChipRange(text, range);
      expect(result.text, 'one  twothree');
      expect(result.caret, range.start);
    });

    test('collapses only the space seam the removal creates', () {
      final ctx = [wf('1', 'Alpha')];
      const text = 'a  @Alpha   b';
      final range = computeChipRanges(text, ctx).single;
      expect(deleteChipRange(text, range).text, 'a b');
    });

    test('a chip at the very start leaves no leading space', () {
      final ctx = [wf('1', 'Alpha')];
      const text = '@Alpha rest';
      final result = deleteChipRange(text, computeChipRanges(text, ctx).single);
      expect(result.text, 'rest');
      expect(result.caret, 0);
    });
  });

  group('6. trigger detection', () {
    test('@ opens at token start only', () {
      expect(activeMentionQuery('hi @wo', 6, const []), isNotNull);
      expect(activeMentionQuery('@', 1, const [])!.query, '');
      expect(activeMentionQuery('mail@foo', 8, const []), isNull);
    });

    test('a space right after @ closes the query', () {
      expect(activeMentionQuery('@ x', 3, const []), isNull);
    });

    test('the @ of a completed chip does not reopen the menu', () {
      final ctx = [wf('1', 'Alpha')];
      expect(activeMentionQuery('@Alpha ', 7, ctx), isNull);
      expect(activeMentionQuery('x @Alpha y', 5, ctx), isNull);
      expect(activeMentionQuery('@Alpha @be', 10, ctx)!.query, 'be');
    });

    test('slash at token start, never inside a path', () {
      expect(activeSlashQuery('run /tri', 8, const [])!.query, 'tri');
      expect(activeSlashQuery('a/b', 3, const []), isNull);
    });
  });

  group('7. selection snapping', () {
    const chip = (start: 2, end: 9);

    test('collapsed caret snaps to the nearest edge', () {
      expect(
        snapSelectionToChips(
          (start: 3, end: 3),
          (start: 0, end: 0),
          chip,
          chip,
        ),
        (start: 2, end: 2),
      );
      expect(
        snapSelectionToChips(
          (start: 8, end: 8),
          (start: 0, end: 0),
          chip,
          chip,
        ),
        (start: 9, end: 9),
      );
    });

    test('a fresh range expands outward and never collapses', () {
      expect(
        snapSelectionToChips(
          (start: 4, end: 12),
          (start: 0, end: 0),
          chip,
          null,
        ),
        (start: 2, end: 12),
      );
    });

    test('a shrinking single edge releases the chip', () {
      // prev selected 0..9; the end edge moved left into the chip.
      expect(
        snapSelectionToChips(
          (start: 0, end: 6),
          (start: 0, end: 9),
          null,
          chip,
        ),
        (start: 0, end: 2),
      );
    });

    test('a range inside one chip clamps instead of inverting', () {
      final snapped = snapSelectionToChips(
        (start: 4, end: 6),
        (start: 4, end: 5),
        chip,
        chip,
      );
      expect(snapped.start <= snapped.end, isTrue);
    });

    test('edges outside chips are untouched', () {
      expect(
        snapSelectionToChips(
          (start: 0, end: 1),
          (start: 0, end: 0),
          null,
          null,
        ),
        (start: 0, end: 1),
      );
    });
  });

  group('8. labels', () {
    test('uniqueContextLabel appends the first free ordinal', () {
      final taken = [wf('1', 'Sales'), wf('2', 'Sales (2)')];
      expect(uniqueContextLabel('Sales', taken), 'Sales (3)');
      expect(uniqueContextLabel('Other', taken), 'Other');
    });

    test('prepareContextForInsert: exact duplicate is a no-op, a label '
        'collision gets an ordinal', () {
      final existing = [wf('1', 'Sales')];
      expect(prepareContextForInsert(wf('1', 'Sales'), existing), isNull);
      expect(
        prepareContextForInsert(wf('2', 'Sales'), existing)!.label,
        'Sales (2)',
      );
    });

    test('isContextAlreadySelected checks the label first', () {
      expect(
        isContextAlreadySelected(wf('9', 'Sales'), [wf('1', 'Sales')]),
        isTrue,
      );
      expect(
        isContextAlreadySelected(wf('1', 'Other'), [wf('1', 'Sales')]),
        isTrue,
      );
      expect(
        isContextAlreadySelected(wf('2', 'Other'), [wf('1', 'Sales')]),
        isFalse,
      );
    });
  });
}
