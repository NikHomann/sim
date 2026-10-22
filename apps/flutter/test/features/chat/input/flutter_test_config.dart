import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_design/sim_design.dart';

/// Motion zeroed (the hero placeholder stays on its static prefix, menus
/// and toasts settle at once); Season and Inter loaded so chips and toolbar
/// labels lay out at real widths; CI goldens (obscured text) always,
/// platform goldens outside CI.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SimMotion.scale = 0;
  final season = FontLoader(SimFonts.season)
    ..addFont(
      rootBundle.load(
        'packages/sim_design/assets/fonts/SeasonSansUprightsVF.ttf',
      ),
    );
  final inter = FontLoader(SimFonts.inter)
    ..addFont(
      rootBundle.load('packages/sim_design/assets/fonts/InterVariable.ttf'),
    );
  await Future.wait([season.load(), inter.load()]);
  final isCi = Platform.environment['CI'] == 'true';
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      theme: simLightTheme(),
      platformGoldensConfig: PlatformGoldensConfig(enabled: !isCi),
    ),
    run: testMain,
  );
}
