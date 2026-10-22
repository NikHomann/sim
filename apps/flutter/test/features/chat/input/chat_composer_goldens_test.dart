// Failure modes a golden diff must catch (chat-input.md Layout + Tokens):
// the 16px-radius box with its 1px border, `--white` / dark `--surface-4`
// fill, the hero-only ambient shadow; the 32x30 round chips and their
// icons; the effort label in `--text-icon`; the 28px send circle (disabled
// #808080 empty, active #383838 / #E0E0E0 with text); the chip glyph (12px
// kind icon in the trigger slot, label as plain text); the attachment
// cards (`--surface-5` card, `--surface-7` / dark `--surface-3` tile,
// 48px media) — in light and dark, hero and conversation, at the 704px
// chat column. Each golden also asserts the geometry the image cannot.

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/input/chat_composer.dart';
import 'package:sim_design/sim_design.dart';

import 'support/composer_harness.dart';

enum _State { empty, chip, attachments }

const double _pad = 16;

void main() {
  for (final variant in ComposerVariant.values) {
    for (final state in _State.values) {
      for (final dark in [false, true]) {
        final hero = variant == ComposerVariant.hero;
        final single = hero ? 104.0 : 80.0;
        final height = single + (state == _State.attachments ? 54 : 0);
        final name =
            'chat_composer_${variant.name}_${state.name}_${dark ? 'dark' : 'light'}';
        late ChatComposerController controller;
        // goldenTest registers the test synchronously.
        // ignore: discarded_futures
        goldenTest(
          '$name geometry and paint',
          fileName: name,
          constraints: BoxConstraints.tight(
            Size(704 + 2 * _pad, height + 2 * _pad),
          ),
          pumpBeforeTest: (tester) async {
            await tester.pump();
            if (state == _State.attachments) {
              controller.loadQueuedMessage(
                const ComposerQueuedMessage(
                  content: 'Summarise these',
                  fileAttachments: [
                    ComposerFileAttachment(
                      id: 'a1',
                      key: 'k1',
                      filename: 'Quarterly report.pdf',
                      mediaType: 'application/pdf',
                      size: 1200,
                    ),
                    ComposerFileAttachment(
                      id: 'a2',
                      key: 'k2',
                      filename: 'chart.png',
                      mediaType: 'image/png',
                      size: 1200,
                    ),
                  ],
                ),
              );
            }
            await tester.pump();
            await tester.pump();
            // loadQueuedMessage focuses the field; goldens show no caret.
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pump();
          },
          whilePerforming: (tester) async {
            final root = tester.getRect(byParityId('chat-input.root'));
            expect(root.size, Size(704, height));
            final send = tester.getRect(byParityId('chat-input.send'));
            expect(send.size, const Size(28, 28));
            expect(root.right - send.right, 11);
            expect(root.bottom - send.bottom, 1 + 8 + 1);
            final add = tester.getRect(byParityId('chat-input.add'));
            expect(add.topLeft - root.topLeft, Offset(11, height - 1 - 8 - 30));
            if (state == _State.chip) {
              expect(byParityId('chat-input.chip'), findsOneWidget);
            }
            if (state == _State.attachments) {
              final card = tester.getRect(byParityId('chat-input.attachment'));
              expect(card.height, 48);
              expect(card.topLeft - root.topLeft, const Offset(11, 9));
            }
            return null;
          },
          builder: () {
            controller = ChatComposerController();
            if (state == _State.chip) {
              controller.editor.setText('Compare ');
              controller.appendContext(
                ChatContext.workflow('wf-1', 'Onboarding'),
              );
            }
            final theme = dark ? simDarkTheme() : simLightTheme();
            return Theme(
              data: theme,
              child: SimOverlayHost(
                child: ColoredBox(
                  color: dark ? SimColors.dark.bg : SimColors.light.bg,
                  child: Padding(
                    padding: const EdgeInsets.all(_pad),
                    child: ChatComposer(
                      workspaceId: workspaceId,
                      variant: variant,
                      controller: controller,
                      autofocus: false,
                      onSubmit: (_) {},
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }
    }
  }
}
