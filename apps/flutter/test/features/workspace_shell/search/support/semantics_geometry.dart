import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The global rect of the semantics node carrying [identifier], as the web
/// engine places its `flt-semantics` element (the parity tool's Flutter
/// box): the node's own rect, clipped like the framework clips it, through
/// every ancestor transform. Semantics must be enabled.
Rect semanticsRectOf(WidgetTester tester, String identifier) {
  final node = tester.getSemantics(
    find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == identifier,
    ),
  );
  var rect = node.rect;
  for (SemanticsNode? n = node; n != null; n = n.parent) {
    final transform = n.transform;
    if (transform != null) rect = MatrixUtils.transformRect(transform, rect);
  }
  return rect;
}
