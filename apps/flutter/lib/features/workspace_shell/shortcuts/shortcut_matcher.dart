import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// `isMacPlatform()` (`lib/core/utils/platform.ts:5-8`): `Mod` is Meta on
/// Apple platforms and Ctrl everywhere else. On web the target platform is
/// derived from the user agent, like the upstream regex.
bool isMacPlatform([TargetPlatform? platform]) {
  final p = platform ?? defaultTargetPlatform;
  return p == TargetPlatform.macOS || p == TargetPlatform.iOS;
}

/// `ParsedShortcut` (`global-commands-provider.tsx:200-213`).
@immutable
class ParsedShortcut {
  const ParsedShortcut({
    required this.key,
    this.mod = false,
    this.ctrl = false,
    this.meta = false,
    this.shift = false,
    this.alt = false,
  });

  /// The last `+` part; a single character is lowercased (`k`), longer names
  /// keep their case (`Enter`).
  final String key;
  final bool mod;
  final bool ctrl;
  final bool meta;
  final bool shift;
  final bool alt;

  /// The platform-resolved Ctrl requirement.
  bool expectedCtrl({required bool isMac}) => ctrl || (mod && !isMac);

  /// The platform-resolved Meta requirement.
  bool expectedMeta({required bool isMac}) => meta || (mod && isMac);

  /// `shortcutSignature`: `Mod+K`, `Cmd+K` and `Meta+K` compare equal on mac.
  String signature({required bool isMac}) =>
      '$key|${expectedCtrl(isMac: isMac) ? 1 : 0}|'
      '${expectedMeta(isMac: isMac) ? 1 : 0}|${shift ? 1 : 0}|${alt ? 1 : 0}';
}

/// `parseShortcut`: split on `+`, modifiers `mod`, `ctrl`,
/// `meta|cmd|command`, `shift`, `alt|option` (case-insensitive).
ParsedShortcut parseShortcut(String shortcut) {
  final parts = shortcut.split('+').map((p) => p.trim()).toList();
  final modifiers = parts
      .sublist(0, parts.length - 1)
      .map((p) => p.toLowerCase())
      .toSet();
  final last = parts.last;
  return ParsedShortcut(
    key: last.length == 1 ? last.toLowerCase() : last,
    mod: modifiers.contains('mod'),
    ctrl: modifiers.contains('ctrl'),
    meta:
        modifiers.contains('meta') ||
        modifiers.contains('cmd') ||
        modifiers.contains('command'),
    shift: modifiers.contains('shift'),
    alt: modifiers.contains('alt') || modifiers.contains('option'),
  );
}

/// The parts of a DOM `KeyboardEvent` the matcher reads, built from a
/// Flutter [KeyEvent] by [ShortcutKeyEvent.fromKeyEvent].
@immutable
class ShortcutKeyEvent {
  const ShortcutKeyEvent({
    required this.key,
    this.codeKey,
    this.ctrl = false,
    this.meta = false,
    this.shift = false,
    this.alt = false,
    this.isComposing = false,
  });

  /// Reads the produced character (`e.key`), the physical key (`e.code`,
  /// already reduced by `codeToKey`) and the modifier state at the time of
  /// [event].
  factory ShortcutKeyEvent.fromKeyEvent(
    KeyEvent event, {
    HardwareKeyboard? keyboard,
    bool isComposing = false,
  }) {
    final kb = keyboard ?? HardwareKeyboard.instance;
    return ShortcutKeyEvent(
      key: eventKeyOf(event),
      codeKey: codeToKey(event.physicalKey),
      ctrl: kb.isControlPressed,
      meta: kb.isMetaPressed,
      shift: kb.isShiftPressed,
      alt: kb.isAltPressed,
      isComposing: isComposing,
    );
  }

  /// `e.key`, lowercased when a single character.
  final String key;

  /// `codeToKey(e.code)`: `KeyX` → `x`, `DigitN` → `N`, else null.
  final String? codeKey;
  final bool ctrl;
  final bool meta;
  final bool shift;
  final bool alt;
  final bool isComposing;
}

/// `e.key` of a Flutter key event: the printable character when there is
/// one (so layouts that remap a letter keep their own key), `Enter` for both
/// Enter keys, else the logical key's label. Single characters are
/// lowercased like the matcher does.
String eventKeyOf(KeyEvent event) {
  final logical = event.logicalKey;
  if (logical == LogicalKeyboardKey.enter ||
      logical == LogicalKeyboardKey.numpadEnter) {
    return 'Enter';
  }
  final character = event.character;
  String key;
  if (character != null &&
      character.length == 1 &&
      character.codeUnitAt(0) >= 0x20 &&
      character.codeUnitAt(0) != 0x7f) {
    key = character;
  } else {
    key = logical.keyLabel;
  }
  return key.length == 1 ? key.toLowerCase() : key;
}

/// `codeToKey` over the USB HID usage of the physical key: letters
/// (`KeyA`..`KeyZ`) and the digit row (`Digit1`..`Digit0`).
String? codeToKey(PhysicalKeyboardKey physical) {
  final usage = physical.usbHidUsage;
  const keyA = 0x00070004;
  const keyZ = 0x0007001d;
  const digit1 = 0x0007001e;
  const digit9 = 0x00070026;
  const digit0 = 0x00070027;
  if (usage >= keyA && usage <= keyZ) {
    return String.fromCharCode('a'.codeUnitAt(0) + usage - keyA);
  }
  if (usage >= digit1 && usage <= digit9) return '${usage - digit1 + 1}';
  if (usage == digit0) return '0';
  return null;
}

/// `matchesShortcut` (`global-commands-provider.tsx:226-240`): the key
/// matches by character or physical key, and all four modifier states must
/// equal the platform-resolved expectation exactly.
bool matchesShortcut(
  ShortcutKeyEvent event,
  ParsedShortcut parsed, {
  required bool isMac,
}) {
  final keyMatches = event.key == parsed.key || event.codeKey == parsed.key;
  return keyMatches &&
      event.ctrl == parsed.expectedCtrl(isMac: isMac) &&
      event.meta == parsed.expectedMeta(isMac: isMac) &&
      event.shift == parsed.shift &&
      event.alt == parsed.alt;
}
