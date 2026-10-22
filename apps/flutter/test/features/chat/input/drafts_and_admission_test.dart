// Failure modes of draft persistence (`stores/mothership-drafts/store.ts`)
// and attachment admission (`lib/uploads/client/admission.ts`):
// 1. a corrupt envelope crashes the read or blocks later writes;
// 2. a v0 envelope keeps the dead `<ws>:workflow-copilot:<wf>` keys;
// 3. writing one key drops entries written by the React app / other tabs;
// 4. an empty draft is stored instead of deleting its key;
// 5. the 200ms debounce writes every keystroke, or drops the last payload
//    on flush (unmount), or writes after cancel (submit);
// 6. admission lets a 21st file (counting attached ones) through, accepts
//    a file over 5 GiB, or a selection over 25 GiB; messages differ from
//    upstream.

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/engine/stores/drafts_store.dart';
import 'package:sim_app/features/chat/input/composer_attachments.dart';
import 'package:sim_app/features/chat/input/composer_drafts.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';

import 'support/composer_harness.dart';

Map<String, Object?> envelope(MemoryDraftBackend backend) =>
    jsonDecode(backend.values[ComposerDraftStore.storageKey]!)
        as Map<String, Object?>;

Map<Object?, Object?> drafts(MemoryDraftBackend backend) =>
    (envelope(backend)['state']! as Map)['drafts']! as Map;

void main() {
  group('drafts', () {
    test(
      '1. a corrupt envelope reads empty and is replaced on write',
      () async {
        final backend = MemoryDraftBackend()
          ..values[ComposerDraftStore.storageKey] = '{not json';
        final store = ComposerDraftStore(MothershipDraftsStore(backend));
        expect(await store.read('ws:new'), isNull);
        await store.write('ws:new', const ComposerDraft(text: 'hi'));
        expect(drafts(backend)['ws:new'], {'text': 'hi'});
        expect(envelope(backend)['version'], 1);
      },
    );

    test('2. v0 legacy workflow-copilot keys are dropped', () async {
      final backend = MemoryDraftBackend()
        ..values[ComposerDraftStore.storageKey] = jsonEncode({
          'state': {
            'drafts': {
              'ws:workflow-copilot:wf': {'text': 'old'},
              'ws:new': {'text': 'keep'},
            },
          },
          'version': 0,
        });
      final store = ComposerDraftStore(MothershipDraftsStore(backend));
      await store.write('ws:c1', const ComposerDraft(text: 'x'));
      expect(drafts(backend).keys, unorderedEquals(['ws:new', 'ws:c1']));
    });

    test('3-4. other keys survive; an empty draft deletes its key', () async {
      final backend = MemoryDraftBackend();
      final store = ComposerDraftStore(MothershipDraftsStore(backend));
      await store.write(
        'ws:new',
        ComposerDraft(
          text: '@Alpha ',
          contexts: [ChatContext.workflow('w', 'Alpha')],
        ),
      );
      await store.write('ws:c1', const ComposerDraft(text: 'other'));
      await store.write('ws:new', const ComposerDraft());
      expect(drafts(backend).keys, ['ws:c1']);
      final restored = await store.read('ws:c1');
      expect(restored!.text, 'other');
      expect(ComposerDraftStore.draftKey('ws', null), 'ws:new');
      expect(ComposerDraftStore.draftKey('ws', 'c1'), 'ws:c1');
    });

    test('5. debounce coalesces, flush writes, cancel drops', () {
      fakeAsync((async) {
        final backend = MemoryDraftBackend();
        final autosave = DraftAutosave(
          ComposerDraftStore(MothershipDraftsStore(backend)),
        )..schedule('k', const ComposerDraft(text: 'a'));
        async.elapse(const Duration(milliseconds: 150));
        autosave.schedule('k', const ComposerDraft(text: 'ab'));
        async.elapse(const Duration(milliseconds: 150));
        expect(backend.values, isEmpty);
        async.elapse(const Duration(milliseconds: 60));
        expect(drafts(backend)['k'], {'text': 'ab'});

        autosave
          ..schedule('k', const ComposerDraft(text: 'abc'))
          ..flush();
        async.flushMicrotasks();
        expect(drafts(backend)['k'], {'text': 'abc'});

        autosave
          ..schedule('k', const ComposerDraft(text: 'abcd'))
          ..cancel();
        async.elapse(const Duration(seconds: 1));
        expect(drafts(backend)['k'], {'text': 'abc'});
      });
    });
  });

  group('6. admission', () {
    test('counts attached files toward the 20-file limit', () {
      expect(
        () => assertAttachmentAdmission(
          [(name: 'b', size: 1)],
          existing: [for (var i = 0; i < 20; i++) (name: '$i', size: 1)],
        ),
        throwsA(
          isA<AttachmentAdmissionError>().having(
            (e) => e.message,
            'message',
            'Select up to 20 files at a time.',
          ),
        ),
      );
      assertAttachmentAdmission(
        [(name: 'b', size: 1)],
        existing: [for (var i = 0; i < 19; i++) (name: '$i', size: 1)],
      );
    });

    test('per-file and aggregate byte limits', () {
      expect(
        () => assertAttachmentAdmission([
          (name: 'big.mov', size: composerMaxFileBytes + 1),
        ]),
        throwsA(
          isA<AttachmentAdmissionError>().having(
            (e) => e.message,
            'message',
            '"big.mov" is too large. Each file must be 5 GiB or smaller.',
          ),
        ),
      );
      expect(
        () => assertAttachmentAdmission([
          for (var i = 0; i < 6; i++) (name: '$i', size: composerMaxFileBytes),
        ]),
        throwsA(
          isA<AttachmentAdmissionError>().having(
            (e) => e.message,
            'message',
            'Select files totaling 25 GiB or less.',
          ),
        ),
      );
    });

    test('type resolution falls back to the extension', () {
      expect(resolveFileType('a.pdf', ''), 'application/pdf');
      expect(resolveFileType('a.png', 'application/octet-stream'), 'image/png');
      expect(resolveFileType('a.bin', 'text/x-custom'), 'text/x-custom');
    });
  });
}
