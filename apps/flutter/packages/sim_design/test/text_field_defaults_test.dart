// Failure modes of the text-field context-menu seam: the app cannot
// replace the context menu of `SimEditable` (its paste must run through the
// app's paste admission guard), so
// - an inherited `SimTextFieldDefaults.contextMenuBuilder` is ignored and
//   the platform toolbar opens;
// - a field's own `contextMenuBuilder` must win over the inherited one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_design/sim_design.dart';

Widget _app(Widget field, {EditableTextContextMenuBuilder? inherited}) =>
    MaterialApp(
      theme: simLightTheme(),
      builder: (context, child) => SimOverlayHost(child: child!),
      home: Scaffold(
        body: SimTextFieldDefaults(
          contextMenuBuilder: inherited,
          child: Center(child: SizedBox(width: 200, child: field)),
        ),
      ),
    );

EditableTextContextMenuBuilder? _builder(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).contextMenuBuilder;

void main() {
  testWidgets('the inherited builder supplies the context menu', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'hello');
    addTearDown(controller.dispose);
    Widget guarded(BuildContext context, EditableTextState state) =>
        const Text('guarded menu');
    await tester.pumpWidget(
      _app(SimEditable(controller: controller), inherited: guarded),
    );
    expect(_builder(tester), same(guarded));
  });

  testWidgets("a field's own builder wins", (tester) async {
    final controller = TextEditingController(text: 'hello');
    addTearDown(controller.dispose);
    Widget own(BuildContext context, EditableTextState state) =>
        const Text('own menu');
    await tester.pumpWidget(
      _app(
        SimEditable(controller: controller, contextMenuBuilder: own),
        inherited: (context, state) => const Text('guarded menu'),
      ),
    );
    expect(_builder(tester), same(own));
  });
}
