// Golden helper: one shell screen at 1440x900 in light and dark, driven by
// the harness (real cubits over mocked repositories).

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_harness.dart';

Future<void> settleShell(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pumpAndSettle();
  }
}

/// Registers `<fileName>_light` and `<fileName>_dark` for the app at
/// [location]; [arrange] stubs before pumping, [act] runs once settled
/// (open a modal, expire the session).
void shellGoldens(
  String description, {
  required String fileName,
  required String location,
  void Function(ShellHarness h)? arrange,
  Future<void> Function(WidgetTester tester, ShellHarness h)? act,
  bool settle = true,
}) {
  group(description, () {
    late ShellHarness h;

    setUp(() async {
      h = ShellHarness();
      await h.setUp();
      arrange?.call(h);
    });

    tearDown(() => h.tearDown());

    for (final dark in <bool>[false, true]) {
      final suffix = dark ? 'dark' : 'light';
      // ignore: discarded_futures, goldenTest registers the test synchronously
      goldenTest(
        '$description ($suffix)',
        fileName: '${fileName}_$suffix',
        constraints: BoxConstraints.tight(shellViewport),
        pumpWidget: (tester, widget) async {
          tester.view.physicalSize = shellViewport;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(widget);
        },
        pumpBeforeTest: (tester) async {
          if (settle) {
            await settleShell(tester);
          } else {
            await tester.pump();
            await tester.pump();
          }
          if (act != null) {
            await act(tester, h);
            if (settle) await settleShell(tester);
          }
        },
        builder: () => h.app(
          location,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        ),
      );
    }
  });
}
