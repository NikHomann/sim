// Failure modes (workspace-chrome.md "Paste anywhere editable",
// paste-admission-guard.tsx, packages/utils/src/paste.ts):
// - an oversized paste reaches the field (the editor would choke)
// - the field changes even though the paste was refused
// - no warning toast, or the limit is described wrongly (bytes vs
//   characters, MB vs MiB)
// - multi-byte text under the character count but over the byte limit
//   slips through
// - a paste within the limit is swallowed by the guard
// - the nearest published limit is ignored in favour of the default
// - web: the capture-phase DOM listener (the only path that sees a native
//   browser paste) lets an oversized payload through, or ignores the
//   focused field's limit (the DOM half itself needs the L5 web check)
// - the toolbar "Paste" (EditableTextState.pasteText, not the intent)
//   bypasses the guard

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/workspace_shell/chrome/paste_admission_guard.dart';
import 'package:sim_app/features/workspace_shell/chrome/platform/paste_capture.dart';
import 'package:sim_design/sim_design.dart';

void main() {
  test('limit wording matches formatPasteLimit', () {
    expect(formatPasteLimit(PasteLimits.defaultBytes), '32 MiB');
    expect(formatPasteLimit(5000000), '5 MB');
    expect(formatPasteLimit(1536 * 1024), '1.5 MiB');
    expect(formatPasteLimit(2048), '2 KiB');
    expect(utf8ByteLength('é😀'), 6);
  });

  group('PasteAdmissionGuard', () {
    late SimToasts toasts;
    late TextEditingController controller;
    late String clipboard;
    PasteCaptureDecision? capture;

    setUp(() {
      toasts = SimToasts();
      controller = TextEditingController(text: 'keep');
      clipboard = '';
    });

    tearDown(() => controller.dispose());

    Future<void> pumpField(
      WidgetTester tester, {
      int? maxBytes,
      int? maxCharacters,
    }) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, Object?>{'text': clipboard};
          }
          if (call.method == 'Clipboard.hasStrings') {
            return <String, Object?>{'value': clipboard.isNotEmpty};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      Widget field = Material(
        child: TextField(
          controller: controller,
          autofocus: true,
          contextMenuBuilder: pasteGuardedContextMenuBuilder,
        ),
      );
      if (maxBytes != null || maxCharacters != null) {
        field = PasteLimit(
          maxBytes: maxBytes,
          maxCharacters: maxCharacters,
          child: field,
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: PasteAdmissionGuard(
            toasts: toasts,
            installCapture: (reject) {
              capture = reject;
              return () => capture = null;
            },
            child: field,
          ),
        ),
      );
      await tester.pump();
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();
    }

    Future<void> paste(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'over the byte limit: refused, field unchanged, warning',
      (
        tester,
      ) async {
        await pumpField(tester, maxBytes: 2048);
        clipboard = 'x' * 3000;
        await paste(tester);
        expect(controller.text, 'keep');
        final toast = toasts.toasts.single;
        expect(toast.message, 'Paste is too large for this editor');
        expect(toast.variant, SimToastVariant.warning);
        expect(
          toast.description,
          'The clipboard content was left unchanged. This editor supports up '
          'to 2 KiB.',
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'multi-byte text over the byte limit is refused',
      (
        tester,
      ) async {
        await pumpField(tester, maxBytes: 1500);
        clipboard = 'é' * 1000;
        await paste(tester);
        expect(controller.text, 'keep');
        expect(toasts.toasts, hasLength(1));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'character limit is described in characters',
      (tester) async {
        await pumpField(tester, maxCharacters: 1000);
        clipboard = 'y' * 1001;
        await paste(tester);
        expect(controller.text, 'keep');
        expect(
          toasts.toasts.single.description,
          endsWith('up to 1,000 characters.'),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'within the limit the field pastes normally',
      (tester) async {
        await pumpField(tester);
        clipboard = ' pasted';
        await paste(tester);
        expect(controller.text, 'keep pasted');
        expect(toasts.toasts, isEmpty);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets('web capture: oversized refused against the focused limit', (
      tester,
    ) async {
      await pumpField(tester, maxCharacters: 10);
      expect(capture, isNotNull, reason: 'the DOM listener is installed');
      expect(capture!('short'), isFalse);
      expect(toasts.toasts, isEmpty);
      expect(capture!('x' * 11), isTrue, reason: 'nearest PasteLimit wins');
      expect(
        toasts.toasts.single.description,
        endsWith('up to 10 characters.'),
      );

      await tester.pumpWidget(const SizedBox());
      expect(capture, isNull, reason: 'removed with the guard');
    });

    testWidgets(
      'toolbar paste goes through the guard',
      (tester) async {
        await pumpField(tester, maxBytes: 2048);
        final state = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        clipboard = 'x' * 3000;
        await guardedToolbarPaste(state);
        await tester.pumpAndSettle();
        expect(controller.text, 'keep');
        expect(toasts.toasts, hasLength(1));

        clipboard = ' ok';
        await guardedToolbarPaste(state);
        await tester.pumpAndSettle();
        expect(controller.text, 'keep ok');

        final menu = pasteGuardedContextMenuBuilder(
          tester.element(find.byType(EditableText)),
          state,
        );
        expect(menu, isA<AdaptiveTextSelectionToolbar>());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  });
}
