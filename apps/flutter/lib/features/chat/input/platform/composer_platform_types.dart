import 'package:flutter/foundation.dart';

/// A file picked, dropped or pasted into the composer.
@immutable
class ComposerPickedFile {
  const ComposerPickedFile({
    required this.name,
    required this.bytes,
    this.mimeType = '',
  });

  final String name;
  final Uint8List bytes;

  /// The browser-reported type (often empty or `application/octet-stream`).
  final String mimeType;

  int get size => bytes.length;
}

/// What the web clipboard bridge asks of the focused composer.
abstract interface class ComposerClipboardTarget {
  /// Whether the composer's field currently has focus.
  bool get hasFocus;

  /// A paste: the plain text, the `text/x-sim-selection` payload (raw JSON)
  /// and any files. Returns whether the composer consumed the event (the
  /// bridge then cancels the browser's own insertion).
  bool onPaste({
    required String text,
    required String? selectionPayload,
    required List<ComposerPickedFile> files,
  });

  /// A copy (or cut when [cut]): the replacement plain text and optional
  /// selection payload, or `null` to let the browser copy natively.
  ({String text, String? selectionPayload})? onCopy({required bool cut});
}

/// OS file drag-and-drop over the composer.
abstract interface class ComposerDropTarget {
  /// Whether a global (logical pixel) point is over the composer.
  bool containsGlobal(double x, double y);
  void onDragEnter();
  void onDragLeave();
  void onDrop(List<ComposerPickedFile> files);
}

/// The custom clipboard MIME of a Sim selection (`selection-clipboard.ts`).
const String simSelectionMime = 'text/x-sim-selection';

/// Test seam: overrides the platform's `(pointer: coarse)` answer (the
/// touch half of `isTouchMobileViewport`). `null` asks the platform; only
/// tests set it.
bool? debugComposerCoarsePointer;
