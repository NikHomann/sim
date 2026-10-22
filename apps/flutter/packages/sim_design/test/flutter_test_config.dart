import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:sim_design/sim_design.dart';

/// Alchemist configuration (`docs/port/04-test-plan.md` §1 L2): CI goldens
/// (obscured text) always; platform goldens only outside CI. Motion is zeroed
/// so skeleton pulses, enter animations and hover transitions never leak
/// into a capture.
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
