// Failure modes of inline rename (use-item-rename.ts) and the help form
// (help-modal.tsx):
// 1. rename trims; empty or unchanged exits WITHOUT a request;
// 2. a failed save restores the original name and stays in edit mode;
// 3. Escape cancels and the blur that follows the exit does not save;
//    a second save while one is pending is ignored;
// 4. the input is focused with everything selected, Enter saves, blur
//    saves, and maxLength caps typing (folder 50);
// 5. help: subject and message are required (on submit only); a batch of
//    images is dropped whole when one is oversize or of the wrong type;
// 6. help submission sends the multipart fields (type, user agent, ids,
//    images), shows Submitting... / Success, clears the form and resets
//    the label after 2 s; a failure shows Error and keeps the form.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/sidebar/help/help_modal.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/inline_rename.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/platform/sidebar_browser.dart';

import 'support/harness.dart';

void main() {
  group('rename controller', () {
    late List<String> saved;
    late int exits;

    InlineRenameController controller({Error? failWith}) =>
        InlineRenameController(
          initialName: 'Ops',
          onSave: (name) async {
            saved.add(name);
            if (failWith != null) throw failWith;
          },
          onExit: () => exits++,
        );

    setUp(() {
      saved = <String>[];
      exits = 0;
    });

    test('empty or unchanged exits silently', () async {
      final empty = controller()..text.text = '   ';
      await empty.save();
      final same = controller()..text.text = ' Ops ';
      await same.save();
      expect(saved, isEmpty);
      expect(exits, 2);
      expect(empty.text.text, 'Ops');
    });

    test('saves the trimmed value once and exits', () async {
      final c = controller()..text.text = '  Platform ';
      await c.save();
      await c.save();
      c.cancel();
      expect(saved, <String>['Platform']);
      expect(exits, 1);
    });

    test('a failure restores the name and keeps editing', () async {
      final c = controller(failWith: StateError('409'))..text.text = 'Dup';
      await c.save();
      expect(saved, <String>['Dup']);
      expect(exits, 0);
      expect(c.text.text, 'Ops');
      expect(c.isSaving, isFalse);
    });

    test('Escape cancels; a later blur does not save', () async {
      final c = controller()
        ..text.text = 'Changed'
        ..cancel();
      await c.save();
      expect(saved, isEmpty);
      expect(exits, 1);
    });

    test('a save while one is pending is ignored', () async {
      final gate = Completer<void>();
      final c = InlineRenameController(
        initialName: 'A',
        onSave: (name) {
          saved.add(name);
          return gate.future;
        },
        onExit: () => exits++,
      )..text.text = 'B';
      final first = c.save();
      await c.save();
      gate.complete();
      await first;
      expect(saved, <String>['B']);
      expect(exits, 1);
    });
  });

  group('rename field', () {
    testWidgets('focus + select all, Enter saves, maxLength caps', (
      tester,
    ) async {
      final saved = <String>[];
      final c = InlineRenameController(
        initialName: 'Folder 1',
        onSave: (name) async => saved.add(name),
        onExit: () {},
      );
      await tester.pumpWidget(
        sidebarApp(
          Center(
            child: SizedBox(
              width: 200,
              child: InlineRenameField(controller: c, maxLength: 50),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        c.text.selection,
        const TextSelection(baseOffset: 0, extentOffset: 8),
      );
      await tester.enterText(find.byType(EditableText), 'x' * 80);
      expect(c.text.text.length, 50);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(saved, <String>['x' * 50]);
    });

    testWidgets('blur saves', (tester) async {
      final saved = <String>[];
      final c = InlineRenameController(
        initialName: 'A',
        onSave: (name) async => saved.add(name),
        onExit: () {},
      );
      final other = FocusNode();
      addTearDown(other.dispose);
      await tester.pumpWidget(
        sidebarApp(
          Column(
            children: <Widget>[
              SizedBox(width: 200, child: InlineRenameField(controller: c)),
              Focus(focusNode: other, child: const SizedBox(height: 10)),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'Renamed');
      other.requestFocus();
      await tester.pump();
      expect(saved, <String>['Renamed']);
    });
  });

  group('help form', () {
    PickedFile image(String name, {int size = 10, String type = 'image/png'}) =>
        PickedFile(name: name, bytes: Uint8List(size), mimeType: type);

    test('subject and message are required on submit', () async {
      final requests = <HelpRequest>[];
      final form = HelpFormController(
        submitRequest: (r) async => requests.add(r),
        userAgent: 'test-agent',
      );
      expect(form.subjectError, isNull);
      expect(await form.submit(), isFalse);
      expect(form.subjectError, 'Subject is required');
      expect(form.messageError, 'Message is required');
      expect(requests, isEmpty);
      form.dispose();
    });

    test('a batch with one bad file is dropped whole', () {
      final form =
          HelpFormController(
              submitRequest: (_) async {},
              userAgent: 'ua',
            )
            ..addImages(<PickedFile>[
              image('a.png'),
              image('b.bmp', type: 'image/bmp'),
            ])
            ..addImages(<PickedFile>[
              image('c.png', size: helpMaxImageBytes + 1),
            ]);
      expect(form.images, isEmpty);
      form.addImages(<PickedFile>[
        image('ok.png'),
        image('ok.gif', type: 'image/gif'),
      ]);
      expect(form.images.map((i) => i.name), <String>['ok.png', 'ok.gif']);
      form.dispose();
    });

    test('success posts the fields, clears, resets after 2 s', () {
      fakeAsync((async) {
        final requests = <HelpRequest>[];
        final form = HelpFormController(
          submitRequest: (r) async => requests.add(r),
          userAgent: 'ua',
          workspaceId: workspaceId,
          workflowId: 'w-empty',
        )..setType(HelpRequestType.featureRequest);
        form.subject.text = ' Hi ';
        form.message.text = 'Body';
        form.addImages(<PickedFile>[image('a.png')]);
        unawaited(form.submit());
        expect(form.submitLabel, 'Submitting...');
        async.flushMicrotasks();
        expect(form.submitLabel, 'Success');
        final request = requests.single;
        expect(request.toJson(), <String, String>{
          'subject': 'Hi',
          'message': 'Body',
          'type': 'feature_request',
          'workspaceId': workspaceId,
          'workflowId': 'w-empty',
          'userAgent': 'ua',
        });
        expect(request.images.single.filename, 'a.png');
        expect(form.subject.text, isEmpty);
        expect(form.images, isEmpty);
        expect(form.type, HelpRequestType.bug);
        async.elapse(helpSuccessResetDelay);
        expect(form.submitLabel, 'Submit');
        form.dispose();
      });
    });

    test('failure shows Error and keeps the form', () async {
      final form = HelpFormController(
        submitRequest: (_) async => throw StateError('500'),
        userAgent: 'ua',
      );
      form.subject.text = 'S';
      form.message.text = 'M';
      expect(await form.submit(), isFalse);
      expect(form.submitLabel, 'Error');
      expect(form.subject.text, 'S');
      form.dispose();
    });
  });
}
