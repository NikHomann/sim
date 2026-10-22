import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/shared/auth_scope.dart';
import 'package:sim_design/sim_design.dart';

import 'fakes.dart';

/// The reference viewport of the parity captures.
const Size authViewport = Size(1440, 900);

/// Mounts an auth page the way the app does (Material app, overlay host,
/// auth scope) at the 1440×900 viewport.
Future<void> pumpAuthPage(
  WidgetTester tester,
  Widget page, {
  required FakeAuthDeps deps,
  Size size = authViewport,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: simLightTheme(),
      builder: (context, child) =>
          SimOverlayHost(child: child ?? const SizedBox.shrink()),
      home: KeyedSubtree(
        key: ObjectKey(deps),
        child: AuthScope(deps: deps.deps, child: page),
      ),
    ),
  );
}

/// Finds the [Semantics] widget carrying a parity id (no semantics tree
/// needed).
Finder byParityId(String identifier) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == identifier,
  description: 'parity id $identifier',
);
