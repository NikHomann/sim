// Failure modes of the editor's focus wiring: a disposed (or re-pointed)
// PromptEditor leaves `focusNode.onKeyEvent` pointing at its dead state, so
// a host-owned node keeps routing keys into a defunct handler; another
// owner's handler is clobbered on dispose.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/input/composer_controller.dart';
import 'package:sim_app/features/chat/input/widgets/prompt_editor.dart';
import 'package:sim_design/sim_design.dart';

Widget _host(Widget child) => MaterialApp(
  theme: simLightTheme(),
  builder: (context, c) => SimOverlayHost(child: c ?? const SizedBox()),
  home: Scaffold(body: child),
);

PromptEditor _editor(ComposerController controller, FocusNode node) =>
    PromptEditor(
      controller: controller,
      focusNode: node,
      placeholder: ValueNotifier<String>(''),
      menus: const PromptEditorMenus(),
      onResourcePicked: (_) {},
    );

void main() {
  testWidgets('dispose clears the key handler it installed', (tester) async {
    final controller = ComposerController();
    final node = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(node.dispose);
    await tester.pumpWidget(_host(_editor(controller, node)));
    expect(node.onKeyEvent, isNotNull);
    await tester.pumpWidget(_host(const SizedBox()));
    expect(node.onKeyEvent, isNull);
  });

  testWidgets('swapping the focus node clears the old node handler', (
    tester,
  ) async {
    final controller = ComposerController();
    final a = FocusNode();
    final b = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await tester.pumpWidget(_host(_editor(controller, a)));
    await tester.pumpWidget(_host(_editor(controller, b)));
    expect(a.onKeyEvent, isNull);
    expect(b.onKeyEvent, isNotNull);
  });

  testWidgets('dispose keeps a handler someone else installed', (
    tester,
  ) async {
    final controller = ComposerController();
    final node = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(node.dispose);
    await tester.pumpWidget(_host(_editor(controller, node)));
    KeyEventResult other(FocusNode _, KeyEvent _) => KeyEventResult.ignored;
    node.onKeyEvent = other;
    await tester.pumpWidget(_host(const SizedBox()));
    expect(node.onKeyEvent, same(other));
  });
}
