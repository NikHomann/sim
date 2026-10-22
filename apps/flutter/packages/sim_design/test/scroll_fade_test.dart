// Failure modes this file guards (SimScrollFade):
// - an edge flip (content starts or stops overflowing, or the region scrolls
//   off an edge) changes the widget type at the fade's slot (a bare listener
//   vs a ShaderMask), so everything below it is remounted: State below the
//   fade resets and the scroll position jumps back to 0;
// - the fade masks a region whose content fits (no edge hides anything);
// - the fade stops masking when an edge does hide content.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_design/sim_design.dart';

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    child: Text('$value', textDirection: TextDirection.ltr),
  );
}

Widget _fade({
  required ScrollController controller,
  required double contentHeight,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 200,
      height: 100,
      child: SimScrollFade(
        child: SingleChildScrollView(
          controller: controller,
          child: Column(
            children: <Widget>[
              const _Counter(),
              SizedBox(height: contentHeight),
            ],
          ),
        ),
      ),
    ),
  ),
);

bool _masked(WidgetTester tester) =>
    tester.layers.any((layer) => layer is ShaderMaskLayer);

void main() {
  testWidgets('state below the fade survives an edge flip', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    _CounterState counter() => tester.state(find.byType(_Counter));
    await tester.pumpWidget(
      _fade(controller: controller, contentHeight: 300),
    );
    await tester.pump();
    final before = counter()..value = 7;
    expect(_masked(tester), isTrue, reason: 'end edge hides content');

    controller.jumpTo(40);
    await tester.pump();
    expect(identical(counter(), before), isTrue);
    expect(controller.offset, 40);

    // Shrinking the content so it fits flips both edges off.
    await tester.pumpWidget(
      _fade(controller: controller, contentHeight: 10),
    );
    await tester.pump();
    expect(identical(counter(), before), isTrue);
    expect(counter().value, 7);
    expect(_masked(tester), isFalse, reason: 'nothing hidden, no mask');

    // And back: overflowing again turns the mask on without a remount.
    await tester.pumpWidget(
      _fade(controller: controller, contentHeight: 300),
    );
    await tester.pump();
    expect(identical(counter(), before), isTrue);
    expect(_masked(tester), isTrue);
  });
}
