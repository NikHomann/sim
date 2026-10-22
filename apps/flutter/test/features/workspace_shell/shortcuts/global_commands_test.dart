// Failure modes (global-behaviours.md "Keyboard shortcut registry"):
// - `Mod` resolves to the wrong modifier per platform (Ctrl+K firing on
//   macOS, Meta+K on Windows)
// - an extra or missing modifier still matches (Ctrl+Shift+K firing Mod+K)
// - a layout where Shift/Option changes the character (`P`, `π`) no longer
//   matches by physical key
// - multi-character keys (`Enter`, numpad Enter) never match
// - `allowInEditable: false` commands fire while a text field is focused,
//   or `allowInEditable: true` ones stop firing there
// - a focused element claiming the chord (`data-owned-shortcuts`) does not
//   win
// - a matched chord is not reported consumed (the browser's own Mod+L /
//   Mod+K would run) or an unmatched one is swallowed
// - a throwing handler breaks later shortcuts
// - unregistering removes other callers' commands; re-registering an id
//   duplicates it
// - key-up events fire commands
// - a chord typed while an IME composes in the focused field fires

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/commands.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/global_commands.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/shortcut_matcher.dart';

ShortcutKeyEvent key(
  String key, {
  String? code,
  bool ctrl = false,
  bool meta = false,
  bool shift = false,
  bool alt = false,
}) => ShortcutKeyEvent(
  key: key,
  codeKey: code ?? (key.length == 1 ? key : null),
  ctrl: ctrl,
  meta: meta,
  shift: shift,
  alt: alt,
);

void main() {
  group('matchesShortcut', () {
    final modK = parseShortcut('Mod+K');

    test('Mod is Ctrl off macOS and Meta on macOS', () {
      expect(matchesShortcut(key('k', ctrl: true), modK, isMac: false), isTrue);
      expect(
        matchesShortcut(key('k', meta: true), modK, isMac: false),
        isFalse,
      );
      expect(matchesShortcut(key('k', meta: true), modK, isMac: true), isTrue);
      expect(matchesShortcut(key('k', ctrl: true), modK, isMac: true), isFalse);
    });

    test('extra or missing modifiers never match', () {
      expect(
        matchesShortcut(key('k', ctrl: true, shift: true), modK, isMac: false),
        isFalse,
      );
      expect(
        matchesShortcut(key('k', ctrl: true, alt: true), modK, isMac: false),
        isFalse,
      );
      expect(matchesShortcut(key('k'), modK, isMac: false), isFalse);
      expect(
        matchesShortcut(
          key('k', ctrl: true, meta: true),
          modK,
          isMac: false,
        ),
        isFalse,
      );
    });

    test('a remapped character still matches by physical key', () {
      final addWorkflow = parseShortcut('Mod+Shift+P');
      expect(
        matchesShortcut(
          key('π', code: 'p', meta: true, shift: true),
          addWorkflow,
          isMac: true,
        ),
        isTrue,
      );
    });

    test('Enter matches for Mod+Enter, including the numpad key', () {
      final run = parseShortcut('Mod+Enter');
      final enter = ShortcutKeyEvent.fromKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.numpadEnter,
          logicalKey: LogicalKeyboardKey.numpadEnter,
          timeStamp: Duration.zero,
        ),
      );
      expect(enter.key, 'Enter');
      expect(
        matchesShortcut(
          ShortcutKeyEvent(key: enter.key, ctrl: true),
          run,
          isMac: false,
        ),
        isTrue,
      );
    });

    test('the event key comes from the produced character, lowercased', () {
      final shiftedP = ShortcutKeyEvent.fromKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyP,
          logicalKey: LogicalKeyboardKey.keyP,
          character: 'P',
          timeStamp: Duration.zero,
        ),
      );
      expect(shiftedP.key, 'p');
      expect(shiftedP.codeKey, 'p');
      expect(codeToKey(PhysicalKeyboardKey.digit0), '0');
      expect(codeToKey(PhysicalKeyboardKey.digit7), '7');
      expect(codeToKey(PhysicalKeyboardKey.enter), isNull);
    });
  });

  group('GlobalCommandRegistry', () {
    late bool editable;
    late List<String>? owned;
    late List<String> fired;
    late GlobalCommandRegistry registry;

    setUp(() {
      editable = false;
      owned = null;
      fired = <String>[];
      registry =
          GlobalCommandRegistry(
            isMac: false,
            isEditableFocused: () => editable,
            focusedOwnedShortcuts: () => owned,
          )..register(<GlobalCommand>[
            for (final id in CommandId.values)
              createCommand(id, () => fired.add(id.wireName)),
          ]);
    });

    test('editable focus skips only allowInEditable:false commands', () {
      editable = true;
      expect(registry.handle(key('b', ctrl: true)), isFalse);
      expect(
        registry.handle(key('p', ctrl: true, shift: true)),
        isFalse,
        reason: 'add-workflow is not allowed in editable targets',
      );
      expect(registry.handle(key('k', ctrl: true)), isTrue);
      expect(registry.handle(key('l', ctrl: true)), isTrue);
      expect(registry.handle(key('a', ctrl: true, shift: true)), isTrue);
      expect(fired, <String>['open-search', 'goto-logs', 'add-agent']);
    });

    test('a focused owner of the chord wins, other chords still fire', () {
      owned = <String>['Ctrl+K'];
      expect(registry.handle(key('k', ctrl: true)), isFalse);
      expect(registry.handle(key('l', ctrl: true)), isTrue);
      expect(fired, <String>['goto-logs']);
    });

    // The web capture listener prevents the browser default for exactly the
    // chords [handle] will consume, before the engine sees the key.
    test('willHandle mirrors handle without running the command', () {
      expect(registry.willHandle(key('l', ctrl: true)), isTrue);
      expect(registry.willHandle(key('j', ctrl: true)), isFalse);
      owned = <String>['Ctrl+L'];
      expect(registry.willHandle(key('l', ctrl: true)), isFalse);
      expect(fired, isEmpty);
    });

    test('unmatched chords are not consumed; matched ones are', () {
      expect(registry.handle(key('j', ctrl: true)), isFalse);
      expect(registry.handle(key('k')), isFalse);
      expect(registry.handle(key('k', ctrl: true)), isTrue);
    });

    test('a throwing handler is consumed and does not break the registry', () {
      registry.register(<GlobalCommand>[
        GlobalCommand(
          id: CommandId.openSearch.wireName,
          shortcut: 'Mod+K',
          handler: () => throw StateError('boom'),
        ),
      ]);
      expect(registry.handle(key('k', ctrl: true)), isTrue);
      expect(registry.handle(key('b', ctrl: true)), isTrue);
      expect(fired, <String>['toggle-sidebar']);
    });

    test('unregister removes only its own commands; ids replace', () {
      final unregister = registry.register(<GlobalCommand>[
        GlobalCommand(
          id: 'toggle-sidebar',
          shortcut: 'Mod+B',
          allowInEditable: false,
          handler: () => fired.add('replacement'),
        ),
        GlobalCommand(shortcut: 'Mod+J', handler: () => fired.add('extra')),
      ]);
      expect(registry.handle(key('b', ctrl: true)), isTrue);
      expect(registry.handle(key('j', ctrl: true)), isTrue);
      expect(fired, <String>['replacement', 'extra']);
      unregister();
      expect(registry.handle(key('j', ctrl: true)), isFalse);
      expect(registry.isRegistered('open-search'), isTrue);
      expect(registry.invoke('toggle-sidebar'), isFalse);
      expect(registry.invoke('open-search'), isTrue);
    });

    test('a command without a shortcut is invocable but never matched', () {
      var ran = 0;
      registry.register(<GlobalCommand>[
        GlobalCommand(id: 'palette-only', handler: () => ran++),
      ]);
      expect(registry.invoke('palette-only'), isTrue);
      expect(ran, 1);
      expect(registry.invoke('missing'), isFalse);
    });
  });

  group('GlobalCommandsScope', () {
    testWidgets(
      'consumes Ctrl+B outside fields and skips it inside one',
      (
        tester,
      ) async {
        var toggles = 0;
        var searches = 0;
        final registry = GlobalCommandRegistry();
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: GlobalCommandsScope(
              registry: registry,
              child: RegisterGlobalCommands(
                commands: <GlobalCommand>[
                  createCommand(CommandId.toggleSidebar, () => toggles++),
                  createCommand(CommandId.openSearch, () => searches++),
                ],
                child: Material(child: TextField(focusNode: focus)),
              ),
            ),
          ),
        );

        Future<bool> chord(LogicalKeyboardKey k) async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          final handled = await tester.sendKeyDownEvent(k);
          await tester.sendKeyUpEvent(k);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          return handled;
        }

        expect(await chord(LogicalKeyboardKey.keyB), isTrue);
        expect(toggles, 1);

        focus.requestFocus();
        await tester.pump();
        await chord(LogicalKeyboardKey.keyB);
        expect(toggles, 1, reason: 'toggle-sidebar is blocked in editables');
        expect(await chord(LogicalKeyboardKey.keyK), isTrue);
        expect(searches, 1, reason: 'open-search is allowed in editables');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'an IME composition in the focused field swallows nothing',
      (tester) async {
        var searches = 0;
        final registry = GlobalCommandRegistry();
        final controller = TextEditingController();
        final focus = FocusNode();
        addTearDown(focus.dispose);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: GlobalCommandsScope(
              registry: registry,
              child: RegisterGlobalCommands(
                commands: <GlobalCommand>[
                  createCommand(CommandId.openSearch, () => searches++),
                ],
                child: Material(
                  child: TextField(controller: controller, focusNode: focus),
                ),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pump();
        controller.value = const TextEditingValue(
          text: 'ka',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        );
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        expect(searches, 0, reason: 'the keystroke belongs to the IME');

        controller.value = controller.value.copyWith(
          composing: TextRange.empty,
        );
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        expect(searches, 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  });
}
