import 'package:sim_app/features/workspace_shell/shortcuts/shortcut_matcher.dart';

/// Off the web no browser binding competes. Returns the remover.
void Function() installShortcutCapture(
  bool Function(ShortcutKeyEvent event) willHandle,
) => () {};
