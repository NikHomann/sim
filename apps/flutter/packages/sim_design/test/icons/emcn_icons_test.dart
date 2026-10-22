// Failure modes this file guards (generated emcn icon set):
// - a generated constant names an asset that was never copied into
//   `assets/icons/emcn/` (or the pubspec stops listing that directory), so
//   the icon throws "Unable to load asset" the first time it is shown;
// - a `.vec` was compiled by an incompatible `vector_graphics_compiler`, or a
//   source SVG uses a feature the decoder rejects, so it throws on decode
//   instead of drawing;
// - an icon renders as an empty box (load swallowed) in one theme only;
// - the generator drifts from the hand-ported set: an overlapping icon gets a
//   second copy instead of aliasing `SimIcons`, or two exports collapse onto
//   one constant name;
// - a `strokeWidth` override is ignored because the precompiled path cannot
//   rewrite geometry, or it rewrites a child's own `stroke-width` instead of
//   the root's (the CSS `[&_svg]:[stroke-width:N]` only sets the root).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_design/sim_design.dart';

/// Icons drawn: the picture widget vector_graphics mounts once the bytes have
/// loaded and decoded (flutter_svg mounts the same one for SVG sources).
final Finder _drawnPictures = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_RawPictureVectorGraphicWidget',
);

Widget _sheet(List<SimIconData> icons, {required bool dark}) => MaterialApp(
  theme: dark ? simDarkTheme() : simLightTheme(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Wrap(
        children: <Widget>[for (final icon in icons) SimIcon(icon)],
      ),
    ),
  ),
);

/// Lets the asset loads and decodes finish (real async work) and rebuilds.
Future<void> _settleLoads(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  test('every constant has a unique name and the alias set is SimIcons', () {
    expect(SimEmcnIcons.all, hasLength(192));
    expect(SimEmcnIcons.byExport, hasLength(192));
    expect(SimEmcnIcons.all.toSet(), hasLength(192), reason: 'duplicates');
    final aliased = SimEmcnIcons.all.where((i) => !i.name.startsWith('emcn/'));
    expect(aliased.toSet(), SimIcons.all.toSet());
    expect(identical(SimEmcnIcons.check, SimIcons.check), isTrue);
    expect(SimEmcnIcons.byExport['Workflow'], SimEmcnIcons.workflow);
    expect(SimEmcnIcons.byExport['X'], SimIcons.x);
  });

  test('assets/icons/emcn holds exactly the generated icons', () {
    final onDisk = Directory(
      'assets/icons/emcn',
    ).listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toSet();
    final expected = <String>{
      for (final icon in SimEmcnIcons.all.where((i) => i.precompiled)) ...[
        icon.assetPath.split('/').last,
        icon.vecAssetPath!.split('/').last,
      ],
    };
    expect(onDisk, expected);
  });

  testWidgets('every constant resolves to a bundled asset', (tester) async {
    final missing = <String>[];
    await tester.runAsync(() async {
      for (final icon in SimEmcnIcons.all) {
        for (final path in <String?>[icon.assetPath, icon.vecAssetPath]) {
          if (path == null) continue;
          try {
            await rootBundle.load('packages/sim_design/$path');
          } on Object {
            missing.add(path);
          }
        }
      }
    });
    expect(missing, isEmpty);
  });

  testWidgets('a missing asset is reported, not drawn silently', (
    tester,
  ) async {
    // Proves the render test below would catch an icon whose asset is gone.
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await tester.pumpWidget(
        _sheet(const <SimIconData>[
          SimIconData('emcn/not-an-icon', precompiled: true),
        ], dark: false),
      );
      await _settleLoads(tester);
    } finally {
      FlutterError.onError = previous;
    }
    expect(_drawnPictures, findsNothing);
    expect(errors, isNotEmpty);
  });

  for (final dark in <bool>[false, true]) {
    testWidgets('all ${SimEmcnIcons.all.length} icons draw at 14px '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_sheet(SimEmcnIcons.all, dark: dark));
      await _settleLoads(tester);

      expect(tester.takeException(), isNull);
      expect(_drawnPictures, findsNWidgets(SimEmcnIcons.all.length));
      for (final element in find.byType(SimIcon).evaluate()) {
        expect(element.size, const Size(14, 14));
      }
    });
  }

  testWidgets('a strokeWidth override renders the SVG source', (tester) async {
    await tester.pumpWidget(
      _sheet(const <SimIconData>[], dark: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: simLightTheme(),
        home: const Row(
          children: <Widget>[
            SimIcon(SimEmcnIcons.folder),
            SimIcon(SimEmcnIcons.folderPlus, strokeWidth: 1.25),
          ],
        ),
      ),
    );
    await _settleLoads(tester);
    expect(tester.takeException(), isNull);
    expect(_drawnPictures, findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(SimIcon).first,
        matching: find.byType(SvgPicture),
      ),
      findsNothing,
      reason: 'no override: the precompiled .vec is used',
    );
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final loader = svg.bytesLoader as SvgAssetLoader;
    final source = await tester.runAsync(
      () => rootBundle.load('packages/sim_design/${loader.assetName}'),
    );
    final patched = loader.provideSvg(source);
    // folder-plus: root stroke-width plus two children with their own.
    final root = RegExp(r'<svg\b[^>]*>').firstMatch(patched)!.group(0)!;
    expect(root, contains('stroke-width="1.25"'));
    expect(
      'stroke-width="1.25"'.allMatches(patched),
      hasLength(1),
      reason: 'children keep their own stroke-width',
    );
  });
}
