import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_design/sim_design.dart';

/// Motion is zeroed (paced reveal, fades, shimmer and loader settle at
/// once; streaming tests opt back in); Inter and the bundled chat mono face
/// are loaded so text lays out at real widths; goldens are CI goldens
/// (obscured text) plus platform goldens outside CI.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SimMotion.scale = 0;
  final inter = FontLoader(SimFonts.inter)
    ..addFont(
      rootBundle.load('packages/sim_design/assets/fonts/InterVariable.ttf'),
    );
  final mono = FontLoader(chatMonoFamily)
    ..addFont(
      rootBundle.load(
        'lib/features/chat/messages/fonts/JetBrainsMono-Regular.ttf',
      ),
    );
  await Future.wait(<Future<void>>[inter.load(), mono.load()]);
  final isCi = Platform.environment['CI'] == 'true';
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      theme: simLightTheme(),
      platformGoldensConfig: PlatformGoldensConfig(enabled: !isCi),
    ),
    run: testMain,
  );
}
