import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:sim_design/sim_design.dart';

/// Motion is zeroed (no animation outlives a test or leaks into a golden);
/// CI goldens (obscured text) always, platform goldens only outside CI
/// (`docs/port/04-test-plan.md` §1 L2).
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
