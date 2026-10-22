// Failure modes of the mounted composer (chat-input.md Layout, States,
// Interactions, checklist rows 1-5, 14-16, 36-42, 55-61, 66-72, 79-81):
// 1. geometry: the hero is not 104px / the conversation not 80px tall for
//    one line, the box is wider than 704, the 56px hero editor minimum or
//    the 200px cap is missing (autosize grows the page instead of
//    scrolling);
// 2. send/stop: the empty composer sends, the enabled colour is wrong, an
//    uploading attachment does not block send, streaming does not show
//    Stop or Stop does not reach the host, the submission carries
//    sentinels / stale contexts / uploading files, the composer is not
//    cleared after submit;
// 3. keys through the real field: Enter does not submit (or submits on a
//    touch-mobile viewport), Shift+Enter does not insert a newline, ArrowUp
//    on empty does not recall, Shift+Tab does not cycle the hero mode;
// 4. caret menus: the `@` menu opens below the caret, steals focus, does not
//    filter, or Enter submits instead of picking; the Skills chip does not
//    insert `/` and open the skills menu; the `@` lists load on page load
//    instead of first focus;
// 5. attachments: the 21st file is admitted, the card shows no uploading
//    state, removing an uploading card does not abort it, a failed upload
//    keeps the card;
// 6. drafts: typing is not saved after 200ms under `<ws>:new`, the draft is
//    not restored on remount (chips included), submit does not clear it.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/engine/stores/drafts_store.dart';
import 'package:sim_app/features/chat/input/chat_composer.dart';
import 'package:sim_app/features/chat/input/model/chat_tokens.dart';
import 'package:sim_app/features/chat/input/platform/composer_platform.dart'
    show debugComposerCoarsePointer;
import 'package:sim_design/sim_design.dart';

import 'support/composer_harness.dart';

const alphaWorkflow = ComposerResource(
  type: ComposerResourceType.workflow,
  id: 'wf-1',
  name: 'Alpha',
);

List<ComposerResourceGroup> inventory() => const [
  ComposerResourceGroup(ComposerResourceType.workflow, [
    alphaWorkflow,
    ComposerResource(
      type: ComposerResourceType.workflow,
      id: 'wf-2',
      name: 'Beta flow',
    ),
  ]),
  ComposerResourceGroup(ComposerResourceType.table, [
    ComposerResource(
      type: ComposerResourceType.table,
      id: 't-1',
      name: 'Leads',
    ),
  ]),
];

Color circleColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: byParityId('chat-input.send'),
      matching: find.byType(Container),
    ),
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  group('1. geometry', () {
    testWidgets('hero single line is 104px tall, conversation 80px', (
      tester,
    ) async {
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          variant: ComposerVariant.hero,
          onSubmit: (_) {},
          autofocus: false,
        ),
        width: 900,
      );
      final root = tester.getRect(byParityId('chat-input.root'));
      expect(root.width, 704);
      expect(root.height, 104);
      expect(tester.getSize(byParityId('chat-input.editor')).height, 56);
      expect(tester.getSize(byParityId('chat-input.toolbar')).height, 30);

      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          onSubmit: (_) {},
          autofocus: false,
        ),
      );
      expect(tester.getSize(byParityId('chat-input.root')).height, 80);
      expect(tester.getSize(byParityId('chat-input.textarea')).height, 32);
    });

    testWidgets('round chips are 32x30, send 28px, add chip inset 11px', (
      tester,
    ) async {
      await pumpComposer(
        tester,
        ChatComposer(workspaceId: workspaceId, onSubmit: (_) {}),
      );
      final root = tester.getRect(byParityId('chat-input.root'));
      final add = tester.getRect(byParityId('chat-input.add'));
      expect(add.size, const Size(32, 30));
      expect(add.left - root.left, 11);
      final attach = tester.getRect(byParityId('chat-input.attach'));
      expect(attach.left - add.right, 4);
      expect(tester.getSize(byParityId('chat-input.send')), const Size(28, 28));
      final send = tester.getRect(byParityId('chat-input.send'));
      expect(root.right - send.right, 11);
    });

    testWidgets('autosize grows to 200px, then the editor scrolls', (
      tester,
    ) async {
      await pumpComposer(
        tester,
        ChatComposer(workspaceId: workspaceId, onSubmit: (_) {}),
      );
      await tester.enterText(editableField, 'one\ntwo\nthree');
      await tester.pump();
      expect(
        tester.getSize(byParityId('chat-input.editor')).height,
        3 * 24 + 8,
      );
      await tester.enterText(editableField, List.filled(20, 'line').join('\n'));
      await tester.pump();
      expect(tester.getSize(byParityId('chat-input.editor')).height, 200);
      expect(
        tester.getSize(byParityId('chat-input.root')).height,
        1 + 8 + 200 + 30 + 8 + 1,
      );
    });
  });

  group('2. send and stop', () {
    testWidgets('disabled when empty, enabled with text, submits plain text '
        'and active contexts, then clears', (tester) async {
      final submissions = <ComposerSubmission>[];
      final controller = ChatComposerController();
      addTearDown(controller.dispose);
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          controller: controller,
          onSubmit: submissions.add,
        ),
      );
      expect(circleColor(tester), const Color(0xFF808080));
      await tester.tap(byParityId('chat-input.send'));
      expect(submissions, isEmpty);

      controller.editor.insertSkill(
        const ComposerSkill(id: 's1', name: 'triage'),
      );
      controller.appendContext(ChatContext.workflow('wf-1', 'Alpha'));
      await tester.pump();
      expect(circleColor(tester), const Color(0xFF383838));
      await tester.tap(byParityId('chat-input.send'));
      await tester.pump();
      expect(submissions.single.text, '/triage @Alpha ');
      expect(submissions.single.contexts.map((c) => c.kind), [
        ChatContextKind.skill,
        ChatContextKind.workflow,
      ]);
      expect(submissions.single.effort, ComposerEffort.high);
      expect(controller.editor.text, isEmpty);
      expect(controller.editor.contexts, isEmpty);
    });

    testWidgets('streaming shows Stop in the active colour and calls onStop', (
      tester,
    ) async {
      var stops = 0;
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          onSubmit: (_) {},
          isStreaming: true,
          onStop: () => stops++,
        ),
        dark: true,
      );
      expect(find.bySemanticsLabel('Stop generation'), findsOneWidget);
      expect(circleColor(tester), const Color(0xFFE0E0E0));
      await tester.tap(byParityId('chat-input.send'));
      expect(stops, 1);
    });

    testWidgets('an uploading attachment blocks send and Enter', (
      tester,
    ) async {
      final uploader = FakeUploader();
      final submissions = <ComposerSubmission>[];
      final controller = ChatComposerController(text: 'hi');
      addTearDown(controller.dispose);
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          controller: controller,
          uploader: uploader,
          onSubmit: submissions.add,
        ),
      );
      final adding = controller.addFiles([
        ComposerPickedFile(name: 'a.pdf', bytes: Uint8List(3)),
      ]);
      await tester.pump();
      expect(circleColor(tester), const Color(0xFF808080));
      await tester.showKeyboard(editableField);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(submissions, isEmpty);
      uploader.pending.single.complete((key: 'k1', path: '/p/a.pdf'));
      await adding;
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(submissions.single.fileAttachments.single.key, 'k1');
      expect(
        submissions.single.fileAttachments.single.mediaType,
        'application/pdf',
      );
    });
  });

  group('3. keys through the field', () {
    testWidgets('Enter submits, Shift+Enter inserts a newline', (tester) async {
      final submissions = <ComposerSubmission>[];
      await pumpComposer(
        tester,
        ChatComposer(workspaceId: workspaceId, onSubmit: submissions.add),
      );
      await tester.enterText(editableField, 'hello');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(submissions, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(submissions.single.text, 'hello');
    });

    testWidgets('touch-mobile (<768px + coarse pointer): Enter does not '
        'submit; widening the viewport restores Enter-to-send', (
      tester,
    ) async {
      debugComposerCoarsePointer = true;
      addTearDown(() => debugComposerCoarsePointer = null);
      final submissions = <ComposerSubmission>[];
      await pumpComposer(
        tester,
        ChatComposer(workspaceId: workspaceId, onSubmit: submissions.add),
        width: 360,
        viewport: const Size(375, 812),
      );
      await tester.enterText(editableField, 'hello');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(submissions, isEmpty);

      tester.view.physicalSize = const Size(1440, 900);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(submissions.single.text, 'hello');
    });

    testWidgets('a narrow window with a fine pointer still submits on Enter', (
      tester,
    ) async {
      debugComposerCoarsePointer = false;
      addTearDown(() => debugComposerCoarsePointer = null);
      final submissions = <ComposerSubmission>[];
      await pumpComposer(
        tester,
        ChatComposer(workspaceId: workspaceId, onSubmit: submissions.add),
        width: 360,
        viewport: const Size(375, 812),
      );
      await tester.enterText(editableField, 'hello');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(submissions.single.text, 'hello');
    });

    testWidgets('ArrowUp on empty recalls the queued tail', (tester) async {
      var recalls = 0;
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          onSubmit: (_) {},
          onEditQueuedTail: () => recalls++,
        ),
      );
      await tester.showKeyboard(editableField);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(recalls, 1);
    });

    testWidgets('Shift+Tab cycles Build/Plan in the hero', (tester) async {
      final modes = <ComposerMode>[];
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          variant: ComposerVariant.hero,
          planModeEnabled: true,
          onModeChange: modes.add,
          onSubmit: (_) {},
        ),
      );
      expect(byParityId('chat-input.mode'), findsOneWidget);
      await tester.showKeyboard(editableField);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(modes, [ComposerMode.plan]);
    });

    testWidgets('no mode selector without the plan flag or outside the hero', (
      tester,
    ) async {
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          variant: ComposerVariant.hero,
          onModeChange: (_) {},
          onSubmit: (_) {},
        ),
      );
      expect(byParityId('chat-input.mode'), findsNothing);
    });
  });

  group('4. caret menus', () {
    testWidgets('@ opens the mention menu above the caret, keeps focus, '
        'filters, and Enter picks the row', (tester) async {
      final source = FakeContextSource(groups: inventory());
      final added = <ChatContext>[];
      final submissions = <ComposerSubmission>[];
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          contextSource: source,
          onSubmit: submissions.add,
          onContextAdd: added.add,
        ),
        alignment: Alignment.bottomCenter,
      );
      await tester.showKeyboard(editableField);
      await tester.pump();
      expect(source.inventoryLoads, 1, reason: 'warmed on first focus');
      await tester.enterText(editableField, 'see @');
      await tester.pump();
      await tester.pump();
      final menu = tester.getRect(byParityId('chat-input.plus-menu'));
      final field = tester.getRect(byParityId('chat-input.textarea'));
      expect(menu.bottom, lessThanOrEqualTo(field.top + 4 - 8 + 0.01));
      expect(menu.width, 360);
      expect(find.text('Workflows'), findsOneWidget);
      expect(find.text('Tables'), findsOneWidget);
      expect(editableState(tester).widget.focusNode.hasFocus, isTrue);

      await tester.enterText(editableField, 'see @bet');
      await tester.pump();
      expect(find.text('Leads'), findsNothing);
      expect(find.text('Beta flow'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submissions, isEmpty);
      expect(editableState(tester).widget.controller.text, 'see @Beta flow ');
      expect(added.single.field('workflowId'), 'wf-2');
      expect(byParityId('chat-input.plus-menu'), findsNothing);
      expect(editableState(tester).widget.focusNode.hasFocus, isTrue);
    });

    testWidgets('a hovered row is clickable without losing focus', (
      tester,
    ) async {
      final source = FakeContextSource(groups: inventory());
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          contextSource: source,
          onSubmit: (_) {},
        ),
        alignment: Alignment.bottomCenter,
      );
      await tester.showKeyboard(editableField);
      await tester.enterText(editableField, '@');
      await tester.pump();
      await tester.tap(find.text('Leads'));
      await tester.pump();
      expect(
        editableState(tester).widget.controller.text,
        '@Leads ',
      );
      expect(editableState(tester).widget.focusNode.hasFocus, isTrue);
    });

    testWidgets('Escape closes the menu and the token stays dismissed', (
      tester,
    ) async {
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          contextSource: FakeContextSource(groups: inventory()),
          onSubmit: (_) {},
        ),
        alignment: Alignment.bottomCenter,
      );
      await tester.showKeyboard(editableField);
      await tester.enterText(editableField, '@a');
      await tester.pump();
      expect(byParityId('chat-input.plus-menu'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(byParityId('chat-input.plus-menu'), findsNothing);
      await tester.enterText(editableField, '@al');
      await tester.pump();
      expect(byParityId('chat-input.plus-menu'), findsNothing);
    });

    testWidgets('Skills chip inserts / and opens the skills menu', (
      tester,
    ) async {
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          contextSource: FakeContextSource(
            skills: const [ComposerSkill(id: 's1', name: 'triage')],
            mcpServers: const [ComposerMcpServer(id: 'm1', name: 'Linear')],
          ),
          onSubmit: (_) {},
        ),
        alignment: Alignment.bottomCenter,
      );
      await tester.tap(byParityId('chat-input.skills'));
      await tester.pump();
      await tester.pump();
      expect(editableState(tester).widget.controller.text, '/');
      expect(byParityId('chat-input.skills-menu'), findsOneWidget);
      expect(find.text('triage'), findsOneWidget);
      expect(find.text('Linear'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        editableState(tester).widget.controller.text,
        '${skillChipTrigger}Linear ',
      );
    });

    testWidgets('empty skills list shows the empty row', (tester) async {
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          contextSource: FakeContextSource(),
          onSubmit: (_) {},
        ),
        alignment: Alignment.bottomCenter,
      );
      await tester.tap(byParityId('chat-input.skills'));
      await tester.pump();
      await tester.pump();
      expect(find.text('No skills or MCP servers'), findsOneWidget);
    });
  });

  group('5. attachments', () {
    testWidgets('cards, uploading veil, remove aborts, 20-file limit', (
      tester,
    ) async {
      final uploader = FakeUploader();
      final toasts = SimToasts();
      final controller = ChatComposerController();
      addTearDown(controller.dispose);
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          controller: controller,
          uploader: uploader,
          toasts: toasts,
          onSubmit: (_) {},
        ),
        toasts: toasts,
      );
      final adding = controller.addFiles([
        ComposerPickedFile(name: 'report.pdf', bytes: Uint8List(10)),
        ComposerPickedFile(name: 'photo.png', bytes: Uint8List(10)),
      ]);
      await tester.pump();
      expect(byParityId('chat-input.attachments'), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      final card = tester.getRect(byParityId('chat-input.attachment'));
      expect(card.height, 48);
      final media = tester.getSize(
        find
            .descendant(
              of: find.bySemanticsLabel('Preview photo.png'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(media, const Size(48, 48));
      final remove = tester.widget<Visibility>(
        find.ancestor(
          of: byParityId('chat-input.attachment.remove'),
          matching: find.byType(Visibility),
        ),
      );
      expect(remove.visible, isFalse, reason: 'remove hidden while uploading');

      uploader.pending[1].completeError(StateError('boom'));
      await tester.pump();
      expect(find.text('photo.png'), findsNothing);
      expect(toasts.toasts.single.message, 'Couldn\'t upload "photo.png"');

      uploader.pending[0].complete((key: 'k', path: '/p'));
      await adding;
      await tester.pump();

      await controller.addFiles([
        for (var i = 0; i < 20; i++)
          ComposerPickedFile(name: 'f$i.txt', bytes: Uint8List(1)),
      ]);
      await tester.pump();
      expect(toasts.toasts.last.message, "Couldn't add files");
      expect(
        toasts.toasts.last.description,
        'Select up to 20 files at a time.',
      );
      expect(uploader.names, hasLength(2));
    });

    testWidgets('removing a card aborts its upload', (tester) async {
      final uploader = FakeUploader();
      final controller = ChatComposerController();
      addTearDown(controller.dispose);
      await pumpComposer(
        tester,
        ChatComposer(
          workspaceId: workspaceId,
          controller: controller,
          uploader: uploader,
          onSubmit: (_) {},
        ),
      );
      // Observed rather than awaited: awaiting a future in the fake-async
      // test zone that never settles hangs until the 10-minute timeout
      // instead of failing here.
      var settled = false;
      unawaited(
        controller
            .addFiles([
              ComposerPickedFile(name: 'a.txt', bytes: Uint8List(1)),
            ])
            .whenComplete(() => settled = true),
      );
      await tester.pump();
      expect(uploader.pending, hasLength(1));
      expect(settled, isFalse);
      controller.loadQueuedMessage(const ComposerQueuedMessage(content: 'x'));
      await tester.pump();
      expect(uploader.cancelled, 1);
      // The aborted upload settles (no card comes back).
      expect(settled, isTrue);
      expect(uploader.cancelled, 1);
      expect(find.text('a.txt'), findsNothing);
    });
  });

  group('6. drafts', () {
    testWidgets('saved after 200ms under <ws>:new, restored on remount with '
        'chips, cleared on submit', (tester) async {
      final backend = MemoryDraftBackend();
      final store = ComposerDraftStore(MothershipDraftsStore(backend));
      final controller = ChatComposerController();
      addTearDown(controller.dispose);
      Widget composer(
        ChatComposerController c,
        ValueChanged<ComposerSubmission> s,
      ) => ChatComposer(
        workspaceId: workspaceId,
        controller: c,
        draftStore: store,
        onSubmit: s,
      );
      await pumpComposer(tester, composer(controller, (_) {}));
      controller.appendContext(ChatContext.workflow('wf-1', 'Alpha'));
      await tester.pump(const Duration(milliseconds: 150));
      expect(backend.values, isEmpty);
      await tester.pump(const Duration(milliseconds: 60));
      final saved =
          jsonDecode(backend.values[ComposerDraftStore.storageKey]!)
              as Map<String, Object?>;
      expect(saved['version'], 1);
      final drafts = (saved['state']! as Map)['drafts'] as Map;
      expect(drafts.keys, ['$workspaceId:new']);
      expect((drafts['$workspaceId:new'] as Map)['text'], '@Alpha ');

      await tester.pumpWidget(const SizedBox());
      final restored = ChatComposerController();
      addTearDown(restored.dispose);
      final submissions = <ComposerSubmission>[];
      await pumpComposer(tester, composer(restored, submissions.add));
      await tester.pump();
      expect(restored.editor.text, '@Alpha ');
      expect(restored.editor.contexts.single.field('workflowId'), 'wf-1');

      await tester.tap(byParityId('chat-input.send'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(submissions.single.contexts, hasLength(1));
      final after =
          jsonDecode(backend.values[ComposerDraftStore.storageKey]!)
              as Map<String, Object?>;
      expect((after['state']! as Map)['drafts'], isEmpty);
    });
  });
}
