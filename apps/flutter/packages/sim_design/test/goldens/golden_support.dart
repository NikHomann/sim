import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:sim_design/sim_design.dart';

/// Builds a scenario column for one theme. Dark scenarios sit on the dark
/// canvas colour so surfaces read against the right background.
Widget themedGroup({
  required bool dark,
  required List<GoldenTestScenario> scenarios,
  int columns = 2,
}) {
  final theme = dark ? simDarkTheme() : simLightTheme();
  final bg = dark ? SimColors.dark.bg : SimColors.light.bg;
  return Theme(
    data: theme,
    child: DefaultTextStyle(
      style: theme.textTheme.bodyMedium!,
      child: ColoredBox(
        color: bg,
        child: SimOverlayHost(
          child: GoldenTestGroup(columns: columns, children: scenarios),
        ),
      ),
    ),
  );
}

/// Registers the light and dark variants of one golden.
void themedGoldenTest(
  String name, {
  required String fileName,
  required List<GoldenTestScenario> Function({required bool dark}) scenarios,
  int columns = 2,
  BoxConstraints? constraints,
}) {
  for (final dark in <bool>[false, true]) {
    final suffix = dark ? 'dark' : 'light';
    // ignore: discarded_futures, goldenTest registers the test synchronously
    goldenTest(
      '$name ($suffix)',
      fileName: '${fileName}_$suffix',
      constraints: constraints ?? const BoxConstraints(),
      builder: () => themedGroup(
        dark: dark,
        scenarios: scenarios(dark: dark),
        columns: columns,
      ),
    );
  }
}

/// A fixed-width box so intrinsic chips and fields lay out predictably.
Widget boxed(Widget child, {double width = 240}) =>
    SizedBox(width: width, child: child);
