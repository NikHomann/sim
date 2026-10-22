import 'package:flutter/services.dart';

/// `BrowserContextMenu.enableContextMenu` / `disableContextMenu`.
Future<void> setBrowserContextMenuEnabled({required bool enabled}) => enabled
    ? BrowserContextMenu.enableContextMenu()
    : BrowserContextMenu.disableContextMenu();
