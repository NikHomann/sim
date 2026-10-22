import 'dart:io' show Platform;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:sim_app/features/chat/input/platform/composer_platform_types.dart';

/// Desktop: plain-text clipboard only and no OS file drop (known gaps); the
/// Attach chip opens the native file dialog (`file_selector`) on Windows,
/// macOS and Linux.
const bool composerRichClipboard = false;
const bool composerFileDropSupported = false;
final bool composerFilePickerSupported =
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// Desktop has no `(pointer: coarse)` media query: never touch-mobile.
bool composerCoarsePointer() => debugComposerCoarsePointer ?? false;

void Function() installComposerClipboard(ComposerClipboardTarget target) =>
    () {};

void Function() installComposerFileDrop(ComposerDropTarget target) => () {};

/// The native multi-file dialog. [accept] is the web `accept` attribute
/// (`composerAcceptAttribute`): its `.ext` entries become the dialog's
/// extension filter, MIME wildcards are dropped (Windows filters by
/// extension only), so an accept list without extensions allows any file.
Future<List<ComposerPickedFile>> pickComposerFiles({
  required String accept,
}) async {
  final extensions = [
    for (final entry in accept.split(','))
      if (entry.trim().startsWith('.')) entry.trim().substring(1),
  ];
  final files = await openFiles(
    acceptedTypeGroups: [
      XTypeGroup(
        label: 'Files',
        extensions: extensions.isEmpty ? null : extensions,
      ),
    ],
  );
  return [
    for (final file in files)
      ComposerPickedFile(
        name: file.name,
        bytes: await file.readAsBytes(),
        mimeType: file.mimeType ?? '',
      ),
  ];
}
