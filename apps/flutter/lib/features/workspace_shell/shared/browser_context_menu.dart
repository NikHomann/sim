import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/shared/platform/browser_menu.dart';

/// Turns the browser's own context menu off while mounted (web), so a
/// right-click on a tree row, chat row, nav chip or switcher row shows only
/// the Flutter menu. Several mounts share one switch: the browser menu comes
/// back when the last one unmounts.
class SuppressBrowserContextMenu extends StatefulWidget {
  const SuppressBrowserContextMenu({required this.child, super.key});

  final Widget child;

  /// The platform switch; tests replace it.
  @visibleForTesting
  static Future<void> Function({required bool enabled}) setEnabled =
      setBrowserContextMenuEnabled;

  static int _mounted = 0;

  /// How many mounts currently hold the browser menu off.
  @visibleForTesting
  static int get activeCount => _mounted;

  @override
  State<SuppressBrowserContextMenu> createState() =>
      _SuppressBrowserContextMenuState();
}

class _SuppressBrowserContextMenuState
    extends State<SuppressBrowserContextMenu> {
  @override
  void initState() {
    super.initState();
    if (SuppressBrowserContextMenu._mounted++ == 0) {
      unawaited(SuppressBrowserContextMenu.setEnabled(enabled: false));
    }
  }

  @override
  void dispose() {
    if (--SuppressBrowserContextMenu._mounted == 0) {
      unawaited(SuppressBrowserContextMenu.setEnabled(enabled: true));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
