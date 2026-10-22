import 'dart:async';

import 'package:sim_design/sim_design.dart';

/// Motion is zeroed for every auth test so spinners, skeleton pulses and the
/// OTP caret never leave an animation running (and goldens stay stable).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SimMotion.scale = 0;
  await testMain();
}
