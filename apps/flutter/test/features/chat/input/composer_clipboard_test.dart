// Failure modes of the desktop clipboard path composed with the real shell
// paste guard (`PasteAdmissionGuard` from the workspace chrome sits above
// every composer in the app):
// 1. the guard's generic "too large for this editor" toast fires instead of
//    the chat warning, or the oversized text lands in the field;
// 2. Ctrl+V of portable chip links pastes raw markdown;
// 3. Ctrl+C of a chip range copies raw `@label` / EM SPACE text;
// 4. Ctrl+X of a chip range leaves the text in place.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/input/chat_composer.dart';
import 'package:sim_app/features/workspace_shell/chrome/paste_admission_guard.dart';
import 'package:sim_design/sim_design.dart';

import 'support/composer_harness.dart';

void main() {
  late String? clipboard;

  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.getData':
              return clipboard == null ? null : {'text': clipboard};
            case 'Clipboard.setData':
              clipboard = (call.arguments as Map)['text'] as String?;
              return null;
            case 'Clipboard.hasStrings':
              return {'value': clipboard != null};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<ChatComposerController> mount(
    WidgetTester tester,
    SimToasts toasts,
  ) async {
    final controller = ChatComposerController();
    addTearDown(controller.dispose);
    await pumpComposer(
      tester,
      PasteAdmissionGuard(
        toasts: toasts,
        installCapture: (_) => () {},
        child: ChatComposer(
          workspaceId: workspaceId,
          controller: controller,
          toasts: toasts,
          onSubmit: (_) {},
        ),
      ),
      toasts: toasts,
    );
    await tester.showKeyboard(editableField);
    await tester.pump();
    return controller;
  }

  Future<void> chord(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  testWidgets(
    '1. oversized paste shows the chat warning and inserts nothing',
    (tester) async {
      final toasts = SimToasts();
      final controller = await mount(tester, toasts);
      clipboard = 'x' * 1000001;
      await chord(tester, LogicalKeyboardKey.keyV);
      await tester.pump();
      expect(controller.editor.text, isEmpty);
      expect(toasts.toasts.single.message, 'Paste is too large for a message');
      expect(
        toasts.toasts.single.description,
        startsWith('Messages support up to 1,000,000 characters.'),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    '2. portable links paste as chips',
    (tester) async {
      final controller = await mount(tester, SimToasts());
      clipboard = 'see [Alpha](sim:workflow/wf-1)';
      await chord(tester, LogicalKeyboardKey.keyV);
      await tester.pump();
      expect(controller.editor.text, 'see @Alpha');
      expect(controller.editor.contexts.single.field('workflowId'), 'wf-1');
      expect(byParityId('chat-input.chip'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    '3-4. copy writes links, cut removes the range',
    (tester) async {
      final controller = await mount(tester, SimToasts());
      controller.appendContext(ChatContext.workflow('wf-1', 'Alpha'));
      await tester.pump();
      controller.editor.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.editor.text.length,
      );
      await tester.pump();
      await chord(tester, LogicalKeyboardKey.keyC);
      expect(clipboard, '[Alpha](sim:workflow/wf-1) ');
      await chord(tester, LogicalKeyboardKey.keyX);
      expect(controller.editor.text, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
