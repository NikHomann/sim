// Failure modes of the editor rules (`use-prompt-editor.ts:839-1340`,
// chat-input.md "Keyboard", "Triggers and chips", "Paste / copy / cut"):
// 1. Backspace/Delete next to a chip removes one character (half a token)
//    instead of the whole token; Cmd+Backspace is hijacked;
// 2. ArrowLeft/Right step into a chip instead of hopping to its edge;
//    modified arrows are hijacked;
// 3. a printable key with the caret inside a chip inserts text; Ctrl/Cmd
//    combos are blocked; an edit that slips through (IME, web, an emoji or
//    any multi-code-unit insertion) still lands inside the token;
// 4. a caret / selection edge left inside a chip is not snapped (or a
//    stale snap overrides a newer selection);
// 5. `@`/`/` open while composing (IME); a dismissed token reopens while
//    the caret stays in it; a newline in the query keeps the menu open; a
//    boundary character keeps the skills menu open;
// 6. Enter submits while composing / with Shift / on touch-mobile; an open
//    menu does not get Enter/Tab first; hydrating lists let Enter submit
//    with the mention as raw text; an empty match does not fall through;
// 7. ArrowUp on an empty composer does not reach the recall hook, or
//    ArrowUp with text is swallowed;
// 8. Shift+Tab cycles while a menu is open or repeats on key-repeat;
// 9. a paste over 1,000,000 characters / 4,000,000 bytes (payload or
//    result) is inserted; portable links paste as raw markdown or notify
//    onContextAdd (which would open resource tabs);
// 10. copy of a chip range yields raw tokens / EM SPACE instead of links;
// 11. deleting the last token of a context does not report the removal;
//     clear() reports them (clearing is not a removal upstream).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/input/composer_controller.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';
import 'package:sim_app/features/chat/input/model/chat_tokens.dart';
import 'package:sim_app/features/chat/input/model/composer_resources.dart';

class _Menu implements ComposerMenuHandle {
  _Menu(this.result);

  ComposerMenuSelectResult result;
  int moves = 0;
  int selects = 0;

  @override
  void moveActive(int delta) => moves += delta;

  @override
  ComposerMenuSelectResult selectActive() {
    selects++;
    return result;
  }
}

ComposerController make(String text, {List<ChatContext> contexts = const []}) =>
    ComposerController(
      text: text,
      contexts: contexts,
      deferSelectionSnap: (callback) => callback(),
    );

/// Simulates a user edit arriving from the platform (formatter + set).
void type(
  ComposerController c,
  String text,
  int caret, {
  TextRange? composing,
}) {
  final next = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret),
    composing: composing ?? TextRange.empty,
  );
  c.value = ComposerEditFormatter(c).formatEditUpdate(c.value, next);
}

/// A controller whose selection snap never runs (a caret that the
/// platform left inside a chip, before the post-frame correction).
ComposerController unsnapped(String text, List<ChatContext> contexts) =>
    ComposerController(
      text: text,
      contexts: contexts,
      deferSelectionSnap: (_) {},
    );

const ComposerKey Function(
  LogicalKeyboardKey key, {
  String? character,
  bool shift,
  bool meta,
  bool control,
  bool alt,
  bool repeat,
})
_key = ComposerKey.new;
final ChatContext alpha = ChatContext.workflow('w1', 'Alpha');

void main() {
  group('1. atomic delete', () {
    test('Backspace at the chip end removes the whole token', () {
      final c = make('hi @Alpha ', contexts: [alpha])
        ..selection = const TextSelection.collapsed(offset: 10);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.backspace)),
        KeyEventResult.handled,
      );
      expect(c.text, 'hi');
      expect(c.selection.baseOffset, 2);
      expect(c.contexts, isEmpty);
    });

    test('Delete at the chip start removes it; Cmd+Backspace stays native', () {
      final c = make('@Alpha tail', contexts: [alpha])
        ..selection = const TextSelection.collapsed(offset: 0);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.delete)),
        KeyEventResult.handled,
      );
      expect(c.text, 'tail');
      final d = make('x @Alpha ', contexts: [alpha])
        ..selection = const TextSelection.collapsed(offset: 9);
      expect(
        d.handleKey(_key(LogicalKeyboardKey.backspace, meta: true)),
        KeyEventResult.ignored,
      );
    });

    test('Backspace away from chips is native', () {
      final c = make('hello', contexts: [alpha])
        ..selection = const TextSelection.collapsed(offset: 5);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.backspace)),
        KeyEventResult.ignored,
      );
    });
  });

  group('2. caret hop', () {
    test('ArrowRight from before a chip jumps to its end, Left back', () {
      final c = make('a @Alpha b', contexts: [alpha])
        ..selection = const TextSelection.collapsed(offset: 1);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.arrowRight)),
        KeyEventResult.handled,
      );
      expect(c.selection.baseOffset, 9);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.arrowLeft)),
        KeyEventResult.handled,
      );
      expect(c.selection.baseOffset, 1);
    });

    test('Shift+Arrow stays native', () {
      final c = make('a @Alpha b', contexts: [alpha])
        ..selection = const TextSelection.collapsed(offset: 1);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.arrowRight, shift: true)),
        KeyEventResult.ignored,
      );
    });
  });

  group('3. no typing inside a chip', () {
    test('a printable key inside a chip moves the caret to its end', () {
      final c = unsnapped('a @Alpha b', [alpha])
        ..selection = const TextSelection.collapsed(offset: 4);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.keyX, character: 'x')),
        KeyEventResult.handled,
      );
      expect(c.selection.baseOffset, 9);
      expect(c.text, 'a @Alpha b');
    });

    test('Ctrl combos pass through', () {
      final c = make('a @Alpha b', contexts: [alpha])
        ..selection = const TextSelection.collapsed(offset: 4);
      expect(
        c.handleKey(
          _key(LogicalKeyboardKey.keyA, character: 'a', control: true),
        ),
        KeyEventResult.ignored,
      );
    });

    test('an insertion that bypasses the key handler is refused', () {
      final c = unsnapped('a @Alpha b', [alpha])
        ..selection = const TextSelection.collapsed(offset: 4);
      type(c, 'a @Alxpha b', 5);
      expect(c.text, 'a @Alpha b');
      expect(c.selection.baseOffset, 9);
    });

    test('a multi-code-unit insertion (emoji, IME commit) inside a chip is '
        'refused', () {
      // U+1F600 is a surrogate pair: 2 UTF-16 code units.
      final c = unsnapped('a @Alpha b', [alpha])
        ..selection = const TextSelection.collapsed(offset: 4);
      type(c, 'a @A\u{1F600}lpha b', 6);
      expect(c.text, 'a @Alpha b');
      expect(c.selection.baseOffset, 9);
      expect(c.activeContexts, [alpha]);

      // A committed multi-character IME string.
      c.selection = const TextSelection.collapsed(offset: 5);
      type(c, 'a @Alかなpha b', 7);
      expect(c.text, 'a @Alpha b');
      expect(c.selection.baseOffset, 9);
    });

    test('an emoji key inside a chip moves the caret to its end', () {
      final c = unsnapped('a @Alpha b', [alpha])
        ..selection = const TextSelection.collapsed(offset: 4);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.keyX, character: '\u{1F600}')),
        KeyEventResult.handled,
      );
      expect(c.selection.baseOffset, 9);
      expect(c.text, 'a @Alpha b');
    });

    test('a multi-character insertion at a chip edge is allowed', () {
      final c = unsnapped('a @Alpha b', [alpha])
        ..selection = const TextSelection.collapsed(offset: 9);
      type(c, 'a @Alpha \u{1F600}b', 11);
      expect(c.text, 'a @Alpha \u{1F600}b');
    });
  });

  group('4. selection snapping', () {
    test('a caret placed inside a chip snaps to the nearest edge', () {
      final c = make('a @Alpha b', contexts: [alpha])
        ..selection = const TextSelection.collapsed(offset: 0)
        ..selection = const TextSelection.collapsed(offset: 7);
      expect(c.selection, const TextSelection.collapsed(offset: 9));
    });

    test('a range edge inside a chip expands to the chip', () {
      final c = make('a @Alpha b', contexts: [alpha])
        ..selection = const TextSelection.collapsed(offset: 0)
        ..selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      expect(c.selection, const TextSelection(baseOffset: 0, extentOffset: 9));
    });

    test('a stale snap is dropped when the selection moved again', () {
      VoidCallback? pending;
      final c =
          ComposerController(
              text: 'a @Alpha b',
              contexts: [alpha],
              deferSelectionSnap: (cb) => pending = cb,
            )
            ..selection = const TextSelection.collapsed(offset: 5)
            ..selection = const TextSelection.collapsed(offset: 10);
      pending!();
      expect(c.selection, const TextSelection.collapsed(offset: 10));
    });
  });

  group('5. triggers', () {
    test('@ opens the mention query, a newline closes it', () {
      final c = make('');
      type(c, '@', 1);
      expect(c.mentionQuery, const TriggerQuery('', 0, 1));
      type(c, '@wo', 3);
      expect(c.mentionQuery!.query, 'wo');
      type(c, '@wo\n', 4);
      expect(c.mentionQuery, isNull);
    });

    test('no trigger while the IME is composing; it opens on commit', () {
      final c = make('');
      type(c, '@', 1, composing: const TextRange(start: 0, end: 1));
      expect(c.mentionQuery, isNull);
      type(c, '@', 1);
      expect(c.mentionQuery, isNotNull);
    });

    test('a dismissed mention stays closed until the caret leaves it', () {
      final c = make('');
      type(c, '@wo', 3);
      c.dismissMentionMenu();
      expect(c.mentionQuery, isNull);
      type(c, '@wor', 4);
      expect(c.mentionQuery, isNull);
      type(c, '@wor ', 5);
      type(c, '@wor @', 6);
      expect(c.mentionQuery!.start, 5);
    });

    test('slash closes on boundary punctuation', () {
      final c = make('');
      type(c, '/tri', 4);
      expect(c.slashQuery!.query, 'tri');
      type(c, '/tri.', 5);
      expect(c.slashQuery, isNull);
    });

    test('a picked mention replaces the query and adds the context', () {
      final added = <ChatContext>[];
      final c = make('')..onContextAdd = added.add;
      type(c, 'see @al', 7);
      c.insertMention(alpha);
      expect(c.text, 'see @Alpha ');
      expect(c.selection.baseOffset, 11);
      expect(c.mentionQuery, isNull);
      expect(added, [alpha]);
    });

    test('a picked skill stores the sentinel and plainValue restores /', () {
      final c = make('');
      type(c, 'run /tr', 7);
      c.insertSkill(const ComposerSkill(id: 's1', name: 'triage'));
      expect(c.text, 'run ${skillChipTrigger}triage ');
      expect(c.plainValue, 'run /triage ');
      expect(c.activeContexts.single.kind, ChatContextKind.skill);
    });

    test('the Skills chip inserts a spaced slash and opens the menu', () {
      final c = make('hi')
        ..selection = const TextSelection.collapsed(offset: 2)
        ..insertSlashTrigger();
      expect(c.text, 'hi /');
      expect(c.slashQuery, const TriggerQuery('', 3, 4));
    });

    test('typing a boundary after /skill chips it', () {
      final c = make('/triag')
        ..updateCatalog(
          skills: const [ComposerSkill(id: 's1', name: 'triage')],
        )
        ..selection = const TextSelection.collapsed(offset: 6);
      type(c, '/triage', 7);
      expect(c.slashQuery!.query, 'triage');
      type(c, '/triage ', 8);
      expect(c.text, '${skillChipTrigger}triage ');
      expect(c.contexts.single.field('skillId'), 's1');
    });
  });

  group('6. Enter and menu keys', () {
    test('Enter submits; Shift+Enter, composing and touch-mobile do not', () {
      var submits = 0;
      final c = make('hello')..onSubmit = () => submits++;
      expect(
        c.handleKey(_key(LogicalKeyboardKey.enter)),
        KeyEventResult.handled,
      );
      expect(
        c.handleKey(_key(LogicalKeyboardKey.enter, shift: true)),
        KeyEventResult.ignored,
      );
      c.touchMobile = true;
      expect(
        c.handleKey(_key(LogicalKeyboardKey.enter)),
        KeyEventResult.ignored,
      );
      c
        ..touchMobile = false
        ..value = const TextEditingValue(
          text: 'hello',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        );
      expect(
        c.handleKey(_key(LogicalKeyboardKey.enter)),
        KeyEventResult.ignored,
      );
      expect(submits, 1);
    });

    test('an open mention menu takes arrows and Enter first', () {
      var submits = 0;
      final menu = _Menu(ComposerMenuSelectResult.selected);
      final c = make('')
        ..onSubmit = (() => submits++)
        ..mentionMenu = menu;
      type(c, '@a', 2);
      c
        ..handleKey(_key(LogicalKeyboardKey.arrowDown))
        ..handleKey(_key(LogicalKeyboardKey.arrowUp))
        ..handleKey(_key(LogicalKeyboardKey.arrowUp));
      expect(menu.moves, -1);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.enter)),
        KeyEventResult.handled,
      );
      expect(submits, 0);
    });

    test('hydrating lists swallow Enter; an empty match falls through', () {
      var submits = 0;
      final menu = _Menu(ComposerMenuSelectResult.hydrating);
      final c = make('')
        ..onSubmit = (() => submits++)
        ..mentionMenu = menu;
      type(c, '@zz', 3);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.enter)),
        KeyEventResult.handled,
      );
      expect(submits, 0);
      menu.result = ComposerMenuSelectResult.empty;
      expect(
        c.handleKey(_key(LogicalKeyboardKey.enter)),
        KeyEventResult.handled,
      );
      expect(submits, 1);
      expect(c.handleKey(_key(LogicalKeyboardKey.tab)), KeyEventResult.ignored);
    });

    test('Escape dismisses the open menu', () {
      final c = make('');
      type(c, '@a', 2);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.escape)),
        KeyEventResult.handled,
      );
      expect(c.mentionQuery, isNull);
    });
  });

  group('7. ArrowUp recall', () {
    test('only on an empty composer and only when the host claims it', () {
      var recalls = 0;
      final c = make('')
        ..onArrowUpOnEmpty = () {
          recalls++;
          return true;
        };
      expect(
        c.handleKey(_key(LogicalKeyboardKey.arrowUp)),
        KeyEventResult.handled,
      );
      c.setText('x');
      expect(
        c.handleKey(_key(LogicalKeyboardKey.arrowUp)),
        KeyEventResult.ignored,
      );
      expect(recalls, 1);
      final none = make('')..onArrowUpOnEmpty = () => false;
      expect(
        none.handleKey(_key(LogicalKeyboardKey.arrowUp)),
        KeyEventResult.ignored,
      );
    });
  });

  group('8. Shift+Tab', () {
    test('cycles, swallows repeats, never with a menu open', () {
      final calls = <bool>[];
      final c = make('')
        ..onCycleMode = ({required repeat}) {
          calls.add(repeat);
          return true;
        };
      expect(
        c.handleKey(_key(LogicalKeyboardKey.tab, shift: true)),
        KeyEventResult.handled,
      );
      c.handleKey(_key(LogicalKeyboardKey.tab, shift: true, repeat: true));
      expect(calls, [false, true]);
      type(c, '@', 1);
      expect(
        c.handleKey(_key(LogicalKeyboardKey.tab, shift: true)),
        KeyEventResult.ignored,
      );
    });
  });

  group('9. paste', () {
    test('over the character limit is refused with the warning', () {
      var warned = 0;
      final c = make('')..onPasteTooLarge = () => warned++;
      expect(c.handlePastedText('a' * 1000001), isTrue);
      expect(c.text, isEmpty);
      expect(warned, 1);
    });

    test('the result limit counts the existing text', () {
      var warned = 0;
      final c = make('a' * 999999)
        ..selection = const TextSelection.collapsed(offset: 999999)
        ..onPasteTooLarge = () => warned++;
      expect(c.handlePastedText('bb'), isTrue);
      expect(warned, 1);
      expect(c.handlePastedText('b'), isFalse);
    });

    test('over the byte limit (multi-byte text) is refused', () {
      var warned = 0;
      final c = make('')..onPasteTooLarge = () => warned++;
      // 900,000 characters of a 3-byte scalar: 2.7 MB; twice that is over.
      expect(c.handlePastedText('€' * 900000), isFalse);
      expect(c.handlePastedText('€' * 1400000), isTrue);
      expect(warned, 1);
    });

    test('portable links paste as chips without notifying', () {
      final added = <ChatContext>[];
      final c = make('see')
        ..selection = const TextSelection.collapsed(offset: 3)
        ..onContextAdd = added.add;
      expect(c.handlePastedText('[Alpha](sim:workflow/w1)'), isTrue);
      expect(c.text, 'see @Alpha');
      expect(c.contexts.single.field('workflowId'), 'w1');
      expect(added, isEmpty);
    });

    test('a selection context becomes a chip', () {
      final c = make('');
      const sel = ChatContext(
        kind: ChatContextKind.fileSelection,
        label: 'a.md:1-2',
        fields: {'fileId': 'f', 'fileName': 'a.md', 'text': 'x'},
      );
      expect(c.handlePastedText('x', selectionContext: sel), isTrue);
      expect(c.text, '@a.md:1-2 ');
    });

    test('plain paste runs the bulk auto-mention path', () {
      final c = make('')
        ..updateCatalog(
          integrations: const [
            ComposerIntegration(blockType: 'slack', name: 'Slack'),
          ],
        )
        ..pasteText('ping @slack now');
      expect(c.text, 'ping @Slack now');
      expect(c.contexts.single.kind, ChatContextKind.integration);
    });
  });

  group('10. copy', () {
    test('chips copy as portable links, skills as /', () {
      final skill = ChatContext.skill('s1', 'triage');
      final c = make(
        '@Alpha and ${skillChipTrigger}triage ',
        contexts: [alpha, skill],
      )..selection = const TextSelection(baseOffset: 0, extentOffset: 19);
      expect(
        c.clipboardTextForSelection(),
        '[Alpha](sim:workflow/w1) and [triage](sim:skill/s1) ',
      );
      c.selection = const TextSelection(baseOffset: 7, extentOffset: 10);
      expect(c.clipboardTextForSelection(), isNull);
    });
  });

  group('11. context removal', () {
    test('removing the last token reports the context', () {
      final removed = <ChatContext>[];
      final c = make('@Alpha ', contexts: [alpha])
        ..onContextRemove = (ctx, _) => removed.add(ctx);
      type(c, '@Alph', 5);
      expect(removed, [alpha]);
      expect(c.contexts, isEmpty);
    });

    test('clearComposer does not report removals', () {
      final removed = <ChatContext>[];
      make('@Alpha ', contexts: [alpha])
        ..onContextRemove = ((ctx, _) => removed.add(ctx))
        ..clearComposer();
      expect(removed, isEmpty);
    });
  });
}
