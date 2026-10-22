import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Port of `packages/emcn/src/lib/keyboard.ts`: Enter and Space activate.
bool isKeyboardActivation(KeyEvent event) =>
    event is KeyDownEvent &&
    (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space);

/// Runs [action] when [event] is an activation key and reports the event as
/// handled (the `preventDefault` of the upstream helper); ignores every other
/// key so the caller can keep its own handling.
KeyEventResult handleKeyboardActivation(KeyEvent event, VoidCallback action) {
  if (!isKeyboardActivation(event)) return KeyEventResult.ignored;
  action();
  return KeyEventResult.handled;
}

/// Whether the current focus highlight is keyboard-driven (`:focus-visible`).
bool get isFocusVisibleMode =>
    FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

/// Plain Enter with no modifiers and not a repeat (`isPlainEnter` in
/// `chip-modal.tsx`).
bool isPlainEnter(KeyEvent event) =>
    event is KeyDownEvent &&
    (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
    !HardwareKeyboard.instance.isAltPressed &&
    !HardwareKeyboard.instance.isControlPressed &&
    !HardwareKeyboard.instance.isMetaPressed &&
    !HardwareKeyboard.instance.isShiftPressed;
