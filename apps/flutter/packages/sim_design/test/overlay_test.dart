// Failure modes this file guards (overlay host, modal layer, text fields in
// floating layers):
// - a modal's barrier is wrapped in a fade widget, so the `Positioned` it
//   returned is no longer a direct child of the layer's Stack and every
//   `openSimModal`/`showSimModal` throws "Incorrect use of ParentDataWidget";
// - the barrier stops covering the host (an outside tap lands on the page);
// - the barrier fades through an `Opacity` ancestor, which blanks the
//   backdrop the 2px blur samples, instead of scaling tint and blur;
// - a text field inside a modal, popover or menu has no `Overlay` ancestor,
//   so the first tap or keystroke (selection handles) and the context menu
//   throw "No Overlay widget found";
// - Escape inside a text field raises a `DismissIntent` the field forwards
//   to its ancestors, and with no `DismissAction` outside the Navigator the
//   forward asserts;
// - the dismiss action provided to the layer closes a second layer for the
//   same key press the host's key handler already handled.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_design/sim_design.dart';

/// An app whose [SimOverlayHost] wraps the Navigator, the way the shell
/// mounts it (`MaterialApp.builder`), so layers sit outside every route.
Widget harness(Widget home) => MaterialApp(
  theme: simLightTheme(),
  builder: (context, child) => SimOverlayHost(child: child!),
  home: Scaffold(body: Center(child: home)),
);

Future<void> selectAll(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// Taps, types, selects and shows the context menu in the one text field on
/// screen; every step needs the layer's Overlay and must not throw.
Future<void> exerciseField(
  WidgetTester tester,
  TextEditingController controller,
) async {
  await tester.tap(find.byType(EditableText));
  await tester.pump();
  expect(tester.takeException(), isNull, reason: 'tap into the field');
  await tester.enterText(find.byType(EditableText), 'hello');
  await tester.pump();
  expect(tester.takeException(), isNull, reason: 'typing');
  expect(controller.text, 'hello');

  await selectAll(tester);
  expect(tester.takeException(), isNull, reason: 'select all');
  expect(
    controller.selection,
    const TextSelection(baseOffset: 0, extentOffset: 5),
  );
  final editable = tester.state<EditableTextState>(find.byType(EditableText));
  expect(editable.renderEditable.selection?.isCollapsed, isFalse);

  expect(editable.showToolbar(), isTrue);
  await tester.pump();
  expect(tester.takeException(), isNull, reason: 'context menu');
  editable.hideToolbar();
  await tester.pump();
}

Future<void> pressEscape(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'Escape');
}

void main() {
  group('modal layer composition', () {
    testWidgets('openSimModal renders and the barrier covers the host', (
      tester,
    ) async {
      SimModalHandle<void>? handle;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => SimButton(
              onPressed: () => handle = openSimModal<void>(
                context,
                builder: (_) => const Text('Body'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Body'), findsOneWidget);
      expect(handle?.isOpen, isTrue);
      expect(
        tester.getRect(find.byType(SimOverlayBarrier)),
        tester.getRect(find.byType(SimOverlayHost)),
      );

      // Outside tap reaches the barrier, not the page, and dismisses.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(handle?.isOpen, isFalse);
      expect(find.text('Body'), findsNothing);
    });

    testWidgets('barrier fade scales tint and blur, not an Opacity ancestor', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              SimOverlayBarrier(blurSigma: 2, opacity: 0.5),
            ],
          ),
        ),
      );
      expect(find.byType(Opacity), findsNothing);
      final box = tester.widget<ColoredBox>(find.byType(ColoredBox));
      expect(box.color.a, closeTo(0x1A / 0xFF / 2, 0.001));
      final blur = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(blur.filter, ImageFilter.blur(sigmaX: 1, sigmaY: 1));
    });
  });

  group('text fields inside overlay layers', () {
    testWidgets('SimChipInput in a modal edits, selects and closes on Escape', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      SimModalHandle<void>? handle;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => SimButton(
              onPressed: () => handle = openSimModal<void>(
                context,
                builder: (_) => SizedBox(
                  width: 240,
                  child: SimChipInput(
                    controller: controller,
                    placeholder: 'Name',
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await exerciseField(tester, controller);

      await pressEscape(tester);
      expect(handle?.isOpen, isFalse);
      expect(find.byType(SimChipInput), findsNothing);
    });

    testWidgets(
      'SimChipInput in a popover edits, selects and closes on Escape',
      (
        tester,
      ) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        SimPopoverHandle? handle;
        await tester.pumpWidget(
          harness(
            Builder(
              builder: (context) => SimButton(
                onPressed: () => handle = SimPopover.show(
                  context,
                  builder: (_) => SizedBox(
                    width: 200,
                    child: SimChipInput(controller: controller),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(handle?.isOpen, isTrue);

        await exerciseField(tester, controller);

        await pressEscape(tester);
        expect(handle?.isOpen, isFalse);
        expect(find.byType(SimChipInput), findsNothing);
      },
    );

    testWidgets('menu search field edits, selects and closes on Escape', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      SimMenuHandle? handle;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => SimButton(
              onPressed: () => handle = SimDropdownMenu.show(
                context,
                entries: () => <SimMenuEntry>[
                  SimMenuSearch(controller: controller),
                  SimMenuItem(label: 'Alpha', onSelect: () {}),
                ],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(handle?.isOpen, isTrue);

      await exerciseField(tester, controller);

      await pressEscape(tester);
      expect(handle?.isOpen, isFalse);
      expect(find.byType(SimMenuSearchField), findsNothing);
    });

    testWidgets('one Escape in a field closes only the topmost layer', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      SimModalHandle<void>? outer;
      SimPopoverHandle? inner;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => SimButton(
              onPressed: () => outer = openSimModal<void>(
                context,
                builder: (modalContext) => SimButton(
                  onPressed: () => inner = SimPopover.show(
                    modalContext,
                    builder: (_) => SizedBox(
                      width: 200,
                      child: SimChipInput(controller: controller),
                    ),
                  ),
                  child: const Text('Nested'),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nested'));
      await tester.pumpAndSettle();
      expect(inner?.isOpen, isTrue);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await pressEscape(tester);
      expect(inner?.isOpen, isFalse);
      expect(outer?.isOpen, isTrue, reason: 'the modal below stays open');

      await pressEscape(tester);
      expect(outer?.isOpen, isFalse);
    });
  });

  // An owner that treats Escape and an outside press differently (the
  // workspace switcher cancels a rename on Escape but saves it on an
  // outside press) must be told which one closed the layer, not guess it
  // from the keyboard state.
  testWidgets('a dismissal carries its reason', (tester) async {
    final reasons = <SimDismissReason>[];
    late SimOverlayController overlay;
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) {
            overlay = SimOverlay.of(context);
            return const SizedBox(width: 10, height: 10);
          },
        ),
      ),
    );
    SimOverlayEntry open() {
      late final SimOverlayEntry entry;
      entry = SimOverlayEntry(
        onDismissRequested: () {
          reasons.add(entry.dismissReason);
          entry.remove();
        },
        builder: (context) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox(key: entry.contentKey, width: 40, height: 40),
        ),
      );
      overlay.insert(entry);
      return entry;
    }

    open();
    await tester.pump();
    await pressEscape(tester);
    open();
    await tester.pump();
    await tester.tapAt(const Offset(400, 400));
    await tester.pump();
    open().dismiss();
    await tester.pump();
    expect(reasons, <SimDismissReason>[
      SimDismissReason.escape,
      SimDismissReason.outsidePress,
      SimDismissReason.programmatic,
    ]);
  });
}
