// Failure modes this file guards (parity `Semantics.identifier` hooks):
// - an identifier passed to a menu item, sub-trigger or popover item never
//   reaches the rendered row, so a parity check cannot find it;
// - two tagged rows merge into one semantics node and only one identifier
//   survives (the rows are not separate nodes);
// - the menu / popover surface identifier lands on nothing (no container
//   node) or on a node outside the floating layer;
// - a toast's identifier is dropped between `SimToasts.show` and the card,
//   or tags the shared notifications region instead of its own card;
// - tagging changes layout (an extra wrapper adds size), i.e. visuals move.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_design/sim_design.dart';

Widget _harness(Widget home) => MaterialApp(
  theme: simLightTheme(),
  builder: (context, child) => SimOverlayHost(child: child!),
  home: Scaffold(body: Center(child: home)),
);

Widget _list(List<SimMenuEntry> entries, {String? surfaceId}) => SizedBox(
  width: 220,
  child: SimMenuList(
    autofocus: false,
    semanticsIdentifier: surfaceId,
    entries: () => entries,
  ),
);

void main() {
  testWidgets('menu items keep their own identifier on separate nodes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        _list(<SimMenuEntry>[
          SimMenuItem(
            label: 'Rename',
            onSelect: () {},
            semanticsIdentifier: 'shell.menu.rename',
          ),
          SimMenuItem(
            label: 'Delete',
            onSelect: () {},
            semanticsIdentifier: 'shell.menu.delete',
          ),
          const SimMenuSub(
            label: 'Move to',
            entries: <SimMenuEntry>[],
            semanticsIdentifier: 'shell.menu.move',
          ),
          const SimMenuItem(label: 'Untagged'),
        ]),
      ),
    );
    final rename = find.bySemanticsIdentifier('shell.menu.rename');
    expect(rename, findsOneWidget);
    expect(find.bySemanticsIdentifier('shell.menu.delete'), findsOneWidget);
    expect(find.bySemanticsIdentifier('shell.menu.move'), findsOneWidget);
    final renameNode = tester.getSemantics(rename);
    expect(renameNode.label, startsWith('Rename'));
    expect(
      tester.getSemantics(find.bySemanticsIdentifier('shell.menu.delete')).id,
      isNot(renameNode.id),
    );
    expect(tester.getSemantics(find.text('Untagged')).identifier, isEmpty);
    handle.dispose();
  });

  testWidgets('a separator carries its identifier without moving rows', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    Future<double> secondRowTop({required bool tagged}) async {
      await tester.pumpWidget(
        _harness(
          _list(<SimMenuEntry>[
            const SimMenuItem(label: 'A'),
            SimMenuSeparator(semanticsIdentifier: tagged ? 'shell.sep' : null),
            const SimMenuItem(label: 'B'),
          ]),
        ),
      );
      return tester.getTopLeft(find.text('B')).dy;
    }

    final plain = await secondRowTop(tagged: false);
    final tagged = await secondRowTop(tagged: true);
    expect(find.bySemanticsIdentifier('shell.sep'), findsOneWidget);
    expect(tagged, plain);
    handle.dispose();
  });

  testWidgets('tagging a row does not change its layout', (tester) async {
    await tester.pumpWidget(
      _harness(
        _list(<SimMenuEntry>[
          const SimMenuItem(label: 'A'),
          const SimMenuItem(label: 'B', semanticsIdentifier: 'shell.menu.b'),
        ]),
      ),
    );
    final rows = find.byType(SimMenuRow);
    expect(tester.getSize(rows.at(0)), tester.getSize(rows.at(1)));
  });

  testWidgets('a dropdown menu surface carries its identifier', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) => GestureDetector(
            key: const Key('trigger'),
            behavior: HitTestBehavior.opaque,
            onTap: () => SimDropdownMenu.show(
              context,
              semanticsIdentifier: 'shell.menu.workflow',
              entries: () => <SimMenuEntry>[
                SimMenuItem(
                  label: 'Open',
                  onSelect: () {},
                  semanticsIdentifier: 'shell.menu.open',
                ),
              ],
            ),
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    expect(find.bySemanticsIdentifier('shell.menu.workflow'), findsNothing);
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pumpAndSettle();
    final surface = find.bySemanticsIdentifier('shell.menu.workflow');
    expect(surface, findsOneWidget);
    final item = find.bySemanticsIdentifier('shell.menu.open');
    expect(item, findsOneWidget);
    expect(
      find.descendant(of: find.byType(SimMenuList), matching: item),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a popover surface and its items carry identifiers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) => GestureDetector(
            key: const Key('trigger'),
            behavior: HitTestBehavior.opaque,
            onTap: () => SimPopover.show(
              context,
              semanticsIdentifier: 'shell.popover.switcher',
              builder: (context) => const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SimPopoverItem(
                    label: 'Workspace',
                    semanticsIdentifier: 'shell.popover.workspace',
                  ),
                ],
              ),
            ),
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier('shell.popover.switcher'),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsIdentifier('shell.popover.workspace'))
          .label,
      startsWith('Workspace'),
    );
    handle.dispose();
  });

  testWidgets('a toast card carries its own identifier', (tester) async {
    final handle = tester.ensureSemantics();
    final toasts = SimToasts(idGenerator: () => 't');
    await tester.pumpWidget(
      _harness(
        SimToastStack(
          controller: toasts,
          semanticsIdentifier: 'shell.toast.stack',
        ),
      ),
    );
    toasts.success('Saved', semanticsIdentifier: 'shell.toast.saved');
    await tester.pumpAndSettle();

    final card = find.bySemanticsIdentifier('shell.toast.saved');
    expect(card, findsOneWidget);
    final region = find.bySemanticsIdentifier('shell.toast.stack');
    expect(region, findsOneWidget);
    expect(tester.getSemantics(card).id, isNot(tester.getSemantics(region).id));
    expect(
      tester.getSemantics(region).label,
      'Notifications',
      reason: 'the region keeps its own label',
    );
    toasts.dismissAll();
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    handle.dispose();
  });
}
