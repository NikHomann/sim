import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/commands.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/platform/shortcut_capture.dart';
import 'package:sim_app/features/workspace_shell/shortcuts/shortcut_matcher.dart';

/// `GlobalCommand`: a handler bound to an optional shortcut.
class GlobalCommand {
  const GlobalCommand({
    required this.handler,
    this.id,
    this.shortcut,
    this.allowInEditable,
  });

  /// Registry key; generated when absent. Registering an existing id replaces
  /// it in place (a JS `Map.set`).
  final String? id;
  final String? shortcut;

  /// Defaults to `true` when omitted (`register`, upstream 363-386).
  final bool? allowInEditable;
  final void Function() handler;
}

/// `createCommand`: a command whose id, shortcut and editable rule come from
/// [commandDefinitions]; only [handler] is supplied by the call site.
GlobalCommand createCommand(
  CommandId id,
  void Function() handler, {
  bool? allowInEditable,
}) {
  final definition = commandDefinitions[id]!;
  return GlobalCommand(
    id: id.wireName,
    shortcut: definition.shortcut,
    allowInEditable: allowInEditable ?? definition.allowInEditable,
    handler: handler,
  );
}

class _RegisteredCommand {
  _RegisteredCommand(this.command, this.parsed);

  final GlobalCommand command;
  final ParsedShortcut? parsed;

  bool get allowInEditable => command.allowInEditable ?? true;
}

/// The keydown matcher and registry of `GlobalCommandsProvider`
/// (`global-commands-provider.tsx:200-339`).
///
/// [handle] walks the registry in insertion order, skips commands without a
/// shortcut and `allowInEditable: false` commands while an editable target is
/// focused, yields to a focused [OwnedShortcuts] claiming the same chord, and
/// runs the first match (reporting it consumed so the browser's own binding,
/// e.g. `Mod+L` / `Mod+K`, never runs).
class GlobalCommandRegistry {
  GlobalCommandRegistry({
    bool? isMac,
    bool Function()? isEditableFocused,
    List<String>? Function()? focusedOwnedShortcuts,
    bool Function()? isComposing,
  }) : isMac = isMac ?? isMacPlatform(),
       _isComposing = isComposing ?? isFocusedTextComposing,
       _isEditableFocused = isEditableFocused ?? isEditableTextFocused,
       _focusedOwnedShortcuts =
           focusedOwnedShortcuts ?? OwnedShortcuts.ofPrimaryFocus;

  final bool isMac;
  final bool Function() _isEditableFocused;
  final List<String>? Function() _focusedOwnedShortcuts;
  final bool Function() _isComposing;
  final Map<String, _RegisteredCommand> _commands = {};
  int _nextId = 0;

  /// Registers [commands]; the returned callback unregisters exactly them.
  VoidCallback register(List<GlobalCommand> commands) {
    final created = <String>[];
    for (final command in commands) {
      final id = command.id ?? 'command-${_nextId++}';
      final shortcut = command.shortcut;
      _commands[id] = _RegisteredCommand(
        command,
        shortcut == null ? null : parseShortcut(shortcut),
      );
      created.add(id);
    }
    return () => created.forEach(_commands.remove);
  }

  bool isRegistered(String id) => _commands.containsKey(id);

  /// Runs a registered handler by id; `false` when unregistered.
  bool invoke(String id) {
    final entry = _commands[id];
    if (entry == null) return false;
    _run(entry);
    return true;
  }

  /// The keydown listener body; `true` when a command consumed the event.
  bool handle(ShortcutKeyEvent event) {
    final entry = _match(event);
    if (entry == null) return false;
    _run(entry);
    return true;
  }

  /// Whether [handle] would consume [event], without running anything (the
  /// web capture listener prevents the browser default for these).
  bool willHandle(ShortcutKeyEvent event) => _match(event) != null;

  _RegisteredCommand? _match(ShortcutKeyEvent event) {
    if (event.isComposing) return null;
    var editable = false;
    var editableKnown = false;
    for (final entry in _commands.values.toList()) {
      final parsed = entry.parsed;
      if (parsed == null) continue;
      if (!entry.allowInEditable) {
        if (!editableKnown) {
          editable = _isEditableFocused();
          editableKnown = true;
        }
        if (editable) continue;
      }
      if (!matchesShortcut(event, parsed, isMac: isMac)) continue;
      if (_ownedByFocus(parsed)) continue;
      return entry;
    }
    return null;
  }

  /// [handle] for a Flutter key event (down and repeat, like DOM keydown).
  bool handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    return handle(
      ShortcutKeyEvent.fromKeyEvent(event, isComposing: _isComposing()),
    );
  }

  bool _ownedByFocus(ParsedShortcut parsed) {
    final owned = _focusedOwnedShortcuts();
    if (owned == null || owned.isEmpty) return false;
    final target = parsed.signature(isMac: isMac);
    return owned
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .any((s) => parseShortcut(s).signature(isMac: isMac) == target);
  }

  void _run(_RegisteredCommand entry) {
    try {
      entry.command.handler();
    } on Object catch (error, stack) {
      developer.log(
        'Global command handler failed',
        name: 'sim_app.commands',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

/// Whether the primary focus sits in a text field (`input`, `textarea`,
/// contenteditable): its context has an [EditableText] ancestor or is one.
bool isEditableTextFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  if (context.widget is EditableText) return true;
  return context.findAncestorStateOfType<EditableTextState>() != null;
}

/// `event.isComposing`: the focused text field holds an IME composing
/// range (the keystroke belongs to the input method, not to a shortcut).
bool isFocusedTextComposing() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  final state = context is StatefulElement && context.state is EditableTextState
      ? context.state as EditableTextState
      : context.findAncestorStateOfType<EditableTextState>();
  return state?.textEditingValue.composing.isValid ?? false;
}

/// `data-owned-shortcuts`: an element (typically an editor) that binds a
/// chord itself; while focus is inside it the global command yields.
class OwnedShortcuts extends StatelessWidget {
  const OwnedShortcuts({
    required this.shortcuts,
    required this.child,
    super.key,
  });

  /// `Mod+K` style chords, compared by their platform-resolved signature.
  final List<String> shortcuts;
  final Widget child;

  /// The chords of the nearest [OwnedShortcuts] around the primary focus.
  static List<String>? ofPrimaryFocus() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    if (context.widget is OwnedShortcuts) {
      return (context.widget as OwnedShortcuts).shortcuts;
    }
    return context.findAncestorWidgetOfExactType<OwnedShortcuts>()?.shortcuts;
  }

  @override
  Widget build(BuildContext context) => child;
}

/// Installs a [GlobalCommandRegistry] as a capture-phase key listener (a
/// [HardwareKeyboard] handler runs before focus-tree dispatch) and exposes
/// it to descendants.
class GlobalCommandsScope extends StatefulWidget {
  const GlobalCommandsScope({
    required this.registry,
    required this.child,
    super.key,
  });

  final GlobalCommandRegistry registry;
  final Widget child;

  static GlobalCommandRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_GlobalCommandsInherited>()
      ?.registry;

  @override
  State<GlobalCommandsScope> createState() => _GlobalCommandsScopeState();
}

class _GlobalCommandsScopeState extends State<GlobalCommandsScope> {
  late final void Function() _removeCapture;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _removeCapture = installShortcutCapture(
      (event) => widget.registry.willHandle(event),
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _removeCapture();
    super.dispose();
  }

  bool _onKey(KeyEvent event) => widget.registry.handleKeyEvent(event);

  @override
  Widget build(BuildContext context) => _GlobalCommandsInherited(
    registry: widget.registry,
    child: widget.child,
  );
}

class _GlobalCommandsInherited extends InheritedWidget {
  const _GlobalCommandsInherited({
    required this.registry,
    required super.child,
  });

  final GlobalCommandRegistry registry;

  @override
  bool updateShouldNotify(_GlobalCommandsInherited oldWidget) =>
      registry != oldWidget.registry;
}

/// `useRegisterGlobalCommands`: registers [commands] on mount (handlers call
/// the latest closures because the widget re-reads [commands] on every
/// invocation) and unregisters on unmount.
class RegisterGlobalCommands extends StatefulWidget {
  const RegisterGlobalCommands({
    required this.commands,
    required this.child,
    super.key,
  });

  final List<GlobalCommand> commands;
  final Widget child;

  @override
  State<RegisterGlobalCommands> createState() => _RegisterGlobalCommandsState();
}

class _RegisterGlobalCommandsState extends State<RegisterGlobalCommands> {
  VoidCallback? _unregister;
  GlobalCommandRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = GlobalCommandsScope.maybeOf(context);
    if (registry == _registry) return;
    _unregister?.call();
    _registry = registry;
    _unregister = registry?.register([
      for (var i = 0; i < widget.commands.length; i++)
        GlobalCommand(
          id: widget.commands[i].id,
          shortcut: widget.commands[i].shortcut,
          allowInEditable: widget.commands[i].allowInEditable,
          handler: () => _latest(i),
        ),
    ]);
  }

  void _latest(int index) {
    if (index < widget.commands.length) widget.commands[index].handler();
  }

  @override
  void dispose() {
    _unregister?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
