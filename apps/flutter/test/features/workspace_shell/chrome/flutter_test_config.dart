import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_design/sim_design.dart';

/// Motion is zeroed so modal zooms, toast motion and spinners settle at once;
/// the bundled Season Sans face is loaded so widget tests lay text out at
/// real widths (the default test font is 1em per glyph); goldens are CI
/// goldens (obscured text) plus platform goldens outside CI, as in
/// `packages/sim_design/test/flutter_test_config.dart`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SimMotion.scale = 0;
  final season = FontLoader(SimFonts.season)
    ..addFont(
      rootBundle.load(
        'packages/sim_design/assets/fonts/SeasonSansUprightsVF.ttf',
      ),
    );
  await season.load();
  final isCi = Platform.environment['CI'] == 'true';
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      theme: simLightTheme(),
      platformGoldensConfig: PlatformGoldensConfig(enabled: !isCi),
    ),
    run: testMain,
  );
}
