import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// The save/cancel rules of `use-item-rename.ts` (and the flyout variant,
/// `use-flyout-inline-rename.ts`): the value is trimmed; empty or unchanged
/// exits without a request; otherwise the save callback runs with the input
/// disabled, success exits, failure keeps editing with the original name
/// restored. Exiting is idempotent, so the blur that follows an Escape or a
/// finished save never saves again.
class InlineRenameController {
  InlineRenameController({
    required this.initialName,
    required Future<void> Function(String name) onSave,
    required VoidCallback onExit,
    this.onSavingChanged,
  }) : _onSave = onSave,
       _onExit = onExit,
       text = TextEditingController(text: initialName);

  final String initialName;
  final Future<void> Function(String name) _onSave;
  final VoidCallback _onExit;
  final ValueChanged<bool>? onSavingChanged;
  final TextEditingController text;

  bool _saving = false;
  bool _done = false;

  bool get isSaving => _saving;
  bool get isDone => _done;

  void _exit() {
    if (_done) return;
    _done = true;
    _onExit();
  }

  /// Enter and blur.
  Future<void> save() async {
    if (_done || _saving) return;
    final trimmed = text.text.trim();
    if (trimmed.isEmpty || trimmed == initialName) {
      text.text = initialName;
      _exit();
      return;
    }
    _saving = true;
    onSavingChanged?.call(true);
    try {
      await _onSave(trimmed);
      _saving = false;
      onSavingChanged?.call(false);
      _exit();
    } on Object catch (error) {
      developer.log('Rename failed', name: 'sim_app.sidebar', error: error);
      text.text = initialName;
      _saving = false;
      onSavingChanged?.call(false);
    }
  }

  /// Escape.
  void cancel() {
    if (_done || _saving) return;
    text.text = initialName;
    _exit();
  }

  void dispose() => text.dispose();
}

/// The bare rename `<input>`: transparent, `--text-body`, no outline,
/// focused with all text selected on mount; Enter saves, Escape cancels,
/// blur saves; disabled while the request is pending.
class InlineRenameField extends StatefulWidget {
  const InlineRenameField({
    required this.controller,
    super.key,
    this.maxLength,
    this.small = false,
    this.semanticsLabel,
  });

  final InlineRenameController controller;
  final int? maxLength;

  /// `text-small` (flyout rows) instead of `text-sm`.
  final bool small;
  final String? semanticsLabel;

  @override
  State<InlineRenameField> createState() => _InlineRenameFieldState();
}

class _InlineRenameFieldState extends State<InlineRenameField> {
  final FocusNode _focus = FocusNode(debugLabel: 'InlineRename');
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.controller.text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.controller.text.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      _hadFocus = true;
      widget.controller.text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.text.length,
      );
      return;
    }
    if (_hadFocus && !widget.controller.isSaving) {
      unawaited(widget.controller.save());
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      unawaited(widget.controller.save());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.controller.cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final style = (widget.small ? sim.text.small : sim.text.sm).copyWith(
      color: sim.colors.textBody,
    );
    return ListenableBuilder(
      listenable: widget.controller.text,
      builder: (context, _) => SimEditable(
        controller: widget.controller.text,
        focusNode: _focus,
        style: style,
        maxLength: widget.maxLength,
        enabled: !widget.controller.isSaving,
        autocorrect: false,
        enableSuggestions: false,
        onKeyEvent: _onKey,
        semanticsLabel: widget.semanticsLabel,
      ),
    );
  }
}
