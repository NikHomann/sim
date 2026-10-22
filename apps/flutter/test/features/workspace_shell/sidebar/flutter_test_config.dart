import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:sim_design/sim_design.dart';

/// Motion zeroed for every sidebar test (chevrons, skeleton pulses, menu
/// fades) and the alchemist configuration of the L2 goldens: CI goldens
/// (obscured text) always, platform goldens outside CI.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SimMotion.scale = 0;
  final isCi = Platform.environment['CI'] == 'true';
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      theme: simLightTheme(),
      platformGoldensConfig: PlatformGoldensConfig(enabled: !isCi),
    ),
    run: testMain,
  );
}
