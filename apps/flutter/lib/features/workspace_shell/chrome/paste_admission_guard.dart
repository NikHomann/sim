import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sim_app/features/workspace_shell/chrome/platform/paste_capture.dart';
import 'package:sim_design/sim_design.dart';

/// `PASTE_LIMITS` (`packages/utils/src/paste.ts`) used by the shell.
abstract final class PasteLimits {
  /// The crash-only fallback for controls without a downstream contract.
  static const int defaultBytes = 32 * 1024 * 1024;
}

/// `data-paste-max-bytes` / `data-paste-max-characters`: the ceiling a
/// specialised editor publishes for its subtree. The nearest one wins.
class PasteLimit extends InheritedWidget {
  const PasteLimit({
    required super.child,
    super.key,
    this.maxBytes,
    this.maxCharacters,
  });

  final int? maxBytes;
  final int? maxCharacters;

  static PasteLimit? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PasteLimit>();

  @override
  bool updateShouldNotify(PasteLimit oldWidget) =>
      maxBytes != oldWidget.maxBytes ||
      maxCharacters != oldWidget.maxCharacters;
}

/// UTF-8 length without encoding (`utf8ByteLengthRange`); lone surrogates
/// count as the 3-byte replacement scalar like `TextEncoder`.
int utf8ByteLength(String value) {
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final code = value.codeUnitAt(i);
    if (code <= 0x7f) {
      bytes += 1;
    } else if (code <= 0x7ff) {
      bytes += 2;
    } else if (code >= 0xd800 && code <= 0xdbff && i + 1 < value.length) {
      final next = value.codeUnitAt(i + 1);
      if (next >= 0xdc00 && next <= 0xdfff) {
        bytes += 4;
        i++;
      } else {
        bytes += 3;
      }
    } else {
      bytes += 3;
    }
  }
  return bytes;
}

/// A refused paste (`TextPasteAdmission` with `accepted: false`).
@immutable
class PasteRejection {
  const PasteRejection({required this.byCharacters, required this.limit});

  final bool byCharacters;
  final int limit;
}

/// `assessTextPaste` for the payload bounds the guard applies: characters
/// first, then bytes (UTF-16 length is a lower bound of the UTF-8 length).
PasteRejection? assessTextPaste(
  String text, {
  required int maxBytes,
  int? maxCharacters,
}) {
  if (maxCharacters != null && text.length > maxCharacters) {
    return PasteRejection(byCharacters: true, limit: maxCharacters);
  }
  if (text.length > maxBytes) {
    return PasteRejection(byCharacters: false, limit: maxBytes);
  }
  if (text.length * 3 <= maxBytes) return null;
  if (utf8ByteLength(text) > maxBytes) {
    return PasteRejection(byCharacters: false, limit: maxBytes);
  }
  return null;
}

/// `formatPasteLimit`.
String formatPasteLimit(int bytes) {
  if (bytes >= 1000000 && bytes % 1000000 == 0) return '${bytes ~/ 1000000} MB';
  if (bytes >= 1024 * 1024) {
    final mebibytes = bytes / (1024 * 1024);
    final shown = mebibytes == mebibytes.roundToDouble()
        ? mebibytes.round().toString()
        : mebibytes.toStringAsFixed(1);
    return '$shown MiB';
  }
  return '${(bytes / 1024).round()} KiB';
}

String _groupThousands(int value) {
  final digits = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Checks [text] against [limit] (the [PasteLimit] nearest to the field,
/// or [PasteLimits.defaultBytes] without one) and, when it is too large, shows the
/// warning toast. Returns whether the paste is refused.
bool rejectOversizedPaste(
  String text, {
  required SimToasts toasts,
  PasteLimit? limit,
}) {
  if (text.isEmpty) return false;
  final rejection = assessTextPaste(
    text,
    maxBytes: limit?.maxBytes ?? PasteLimits.defaultBytes,
    maxCharacters: limit?.maxCharacters,
  );
  if (rejection == null) return false;
  final shown = rejection.byCharacters
      ? '${_groupThousands(rejection.limit)} characters'
      : formatPasteLimit(rejection.limit);
  toasts.warning(
    'Paste is too large for this editor',
    description:
        'The clipboard content was left unchanged. This editor supports '
        'up to $shown.',
  );
  return true;
}

PasteLimit? _limitOf(BuildContext? context) =>
    context == null ? null : PasteLimit.maybeOf(context);

/// `PasteAdmissionGuard` (`app/_shell/paste-admission-guard.tsx`): refuses
/// a paste over the nearest [PasteLimit] (or [PasteLimits.defaultBytes])
/// with the warning toast, leaving the field unchanged, on every paste path:
///
/// - keyboard paste through [PasteTextIntent] (desktop): this overrides the
///   action (EditableText's actions are overridable from an ancestor);
/// - on web, where the browser pastes natively into the engine's hidden
///   input and the intent never runs: a capture-phase DOM `paste` listener
///   ([installPasteCapture]) checks the payload against the focused field;
/// - the selection toolbar's "Paste", which calls `pasteText` directly:
///   fields route their context menu through
///   [pasteGuardedContextMenuBuilder], which reads this guard's
///   [PasteAdmissionScope].
class PasteAdmissionGuard extends StatefulWidget {
  const PasteAdmissionGuard({
    required this.toasts,
    required this.child,
    super.key,
    this.readClipboard,
    this.installCapture = installPasteCapture,
  });

  final SimToasts toasts;
  final Widget child;

  /// Test seam; defaults to `Clipboard.getData('text/plain')`.
  final Future<String?> Function()? readClipboard;

  /// Test seam for the web capture listener.
  final void Function() Function(PasteCaptureDecision reject) installCapture;

  @override
  State<PasteAdmissionGuard> createState() => _PasteAdmissionGuardState();
}

class _PasteAdmissionGuardState extends State<PasteAdmissionGuard> {
  late final void Function() _removeCapture;

  Future<String?> _readClipboard() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  @override
  void initState() {
    super.initState();
    _removeCapture = widget.installCapture(
      (text) => rejectOversizedPaste(
        text,
        toasts: widget.toasts,
        limit: _limitOf(FocusManager.instance.primaryFocus?.context),
      ),
    );
  }

  @override
  void dispose() {
    _removeCapture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final read = widget.readClipboard ?? _readClipboard;
    return PasteAdmissionScope(
      toasts: widget.toasts,
      readClipboard: read,
      child: Actions(
        actions: <Type, Action<Intent>>{
          PasteTextIntent: _GuardedPasteAction(
            toasts: widget.toasts,
            readClipboard: read,
          ),
        },
        child: widget.child,
      ),
    );
  }
}

/// What a field's toolbar needs from the [PasteAdmissionGuard] above it.
class PasteAdmissionScope extends InheritedWidget {
  const PasteAdmissionScope({
    required this.toasts,
    required this.readClipboard,
    required super.child,
    super.key,
  });

  final SimToasts toasts;
  final Future<String?> Function() readClipboard;

  static PasteAdmissionScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PasteAdmissionScope>();

  @override
  bool updateShouldNotify(PasteAdmissionScope oldWidget) =>
      toasts != oldWidget.toasts || readClipboard != oldWidget.readClipboard;
}

/// The toolbar "Paste" through the guard: reads the clipboard, refuses an
/// oversized payload (toast, toolbar closed, field unchanged), else runs the
/// field's own paste. Without a guard above the field it pastes directly.
Future<void> guardedToolbarPaste(EditableTextState state) async {
  final scope = PasteAdmissionScope.maybeOf(state.context);
  if (scope == null) {
    await state.pasteText(SelectionChangedCause.toolbar);
    return;
  }
  final limit = PasteLimit.maybeOf(state.context);
  final text = await scope.readClipboard() ?? '';
  if (!state.mounted) return;
  if (rejectOversizedPaste(text, toasts: scope.toasts, limit: limit)) {
    state.hideToolbar();
    return;
  }
  await state.pasteText(SelectionChangedCause.toolbar);
}

/// An `EditableText.contextMenuBuilder` whose "Paste" goes through
/// [guardedToolbarPaste]; the other buttons are the field's own.
Widget pasteGuardedContextMenuBuilder(
  BuildContext context,
  EditableTextState state,
) {
  final items = <ContextMenuButtonItem>[
    for (final item in state.contextMenuButtonItems)
      if (item.type == ContextMenuButtonType.paste)
        item.copyWith(onPressed: () => unawaited(guardedToolbarPaste(state)))
      else
        item,
  ];
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: state.contextMenuAnchors,
    buttonItems: items,
  );
}

class _GuardedPasteAction extends ContextAction<PasteTextIntent> {
  _GuardedPasteAction({required this.toasts, required this.readClipboard});

  final SimToasts toasts;
  final Future<String?> Function() readClipboard;

  @override
  bool isEnabled(PasteTextIntent intent, [BuildContext? context]) =>
      callingAction?.isEnabled(intent) ?? true;

  @override
  Object? invoke(PasteTextIntent intent, [BuildContext? context]) {
    final fallback = callingAction;
    final limit = _limitOf(context);
    unawaited(() async {
      final text = await readClipboard() ?? '';
      if (rejectOversizedPaste(text, toasts: toasts, limit: limit)) return;
      fallback?.invoke(intent);
    }());
    return null;
  }
}
