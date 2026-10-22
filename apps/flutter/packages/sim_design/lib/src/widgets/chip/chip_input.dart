import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/widgets/button.dart';
import 'package:sim_design/src/widgets/chip/chrome.dart';
import 'package:sim_design/src/widgets/fields/editable.dart';
import 'package:sim_design/src/widgets/tooltip.dart';

/// Port of `packages/emcn/src/components/chip-input/chip-input.tsx`: the
/// canonical single-line chip field — a 30px `rounded-lg` filled surface with
/// a 1px `--border` outline (error: `--text-error`), a leading 14px icon or
/// adornment at the chip's 1.5 gap, a trailing adornment, and no focus ring.
class SimChipInput extends StatelessWidget {
  const SimChipInput({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.icon,
    this.startAdornment,
    this.endAdornment,
    this.error = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.mono = false,
    this.onKeyEvent,
    this.cursor,
    this.semanticsLabel,
    this.editableKey,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;

  /// Leading icon, 14px in `--text-icon`.
  final SimIconData? icon;

  /// Custom leading content (e.g. a colour swatch); wins over [icon].
  final Widget? startAdornment;

  /// Trailing content (reveal / copy buttons).
  final Widget? endAdornment;
  final bool error;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// `font-mono` on the inner input.
  final bool mono;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final MouseCursor? cursor;
  final String? semanticsLabel;
  final GlobalKey<SimEditableState>? editableKey;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final textStyle = (mono ? sim.text.mono(14) : sim.text.sm).copyWith(
      color: c.textBody,
    );
    return Opacity(
      opacity: enabled ? 1 : SimChipChrome.fieldDisabledOpacity,
      child: Container(
        height: SimChipChrome.height,
        padding: const EdgeInsets.symmetric(
          horizontal: SimChipChrome.paddingX,
        ),
        decoration: SimChipChrome.fieldSurface(c, error: error),
        child: Row(
          spacing: SimChipChrome.gap,
          children: <Widget>[
            if (startAdornment != null)
              startAdornment!
            else if (icon != null)
              SimIcon(icon!, color: c.textIcon),
            Expanded(
              child: SimEditable(
                key: editableKey,
                controller: controller,
                focusNode: focusNode,
                placeholder: placeholder,
                style: textStyle,
                placeholderStyle: textStyle.copyWith(color: c.textMuted),
                enabled: enabled,
                readOnly: readOnly,
                obscureText: obscureText,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                inputFormatters: inputFormatters,
                maxLength: maxLength,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                autofocus: autofocus,
                onKeyEvent: onKeyEvent,
                cursor: cursor ?? SystemMouseCursors.text,
                semanticsLabel: semanticsLabel,
              ),
            ),
            ?endAdornment,
          ],
        ),
      ),
    );
  }
}

/// Port of `packages/emcn/src/components/chip-textarea/chip-textarea.tsx`:
/// the multi-line chip field (px-2 py-1.5). `viewOnly` renders a read-only
/// record at full opacity with the default cursor.
class SimChipTextarea extends StatelessWidget {
  const SimChipTextarea({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.error = false,
    this.enabled = true,
    this.readOnly = false,
    this.viewOnly = false,
    this.rows = 3,
    this.maxLines,
    this.minHeight,
    this.maxLength,
    this.onChanged,
    this.autofocus = false,
    this.mono = false,
    this.semanticsLabel,
    this.editableKey,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final bool error;
  final bool enabled;
  final bool readOnly;
  final bool viewOnly;

  /// Visible rows (`rows`); sets the minimum line count.
  final int rows;
  final int? maxLines;
  final double? minHeight;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool mono;
  final String? semanticsLabel;
  final GlobalKey<SimEditableState>? editableKey;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final textStyle = (mono ? sim.text.mono(14) : sim.text.sm).copyWith(
      color: c.textBody,
    );
    return Opacity(
      opacity: enabled ? 1 : SimChipChrome.fieldDisabledOpacity,
      child: Container(
        constraints: minHeight == null
            ? null
            : BoxConstraints(minHeight: minHeight!),
        padding: const EdgeInsets.symmetric(
          horizontal: SimChipChrome.paddingX,
          vertical: 6,
        ),
        decoration: SimChipChrome.fieldSurface(c, error: error),
        child: SimEditable(
          key: editableKey,
          controller: controller,
          focusNode: focusNode,
          placeholder: placeholder,
          style: textStyle,
          placeholderStyle: textStyle.copyWith(color: c.textMuted),
          enabled: enabled,
          readOnly: viewOnly || readOnly,
          minLines: rows,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          autofocus: autofocus,
          cursor: viewOnly ? MouseCursor.defer : SystemMouseCursors.text,
          semanticsLabel: semanticsLabel,
        ),
      ),
    );
  }
}

/// Port of `packages/emcn/src/components/chip-copy-input/chip-copy-input.tsx`:
/// a read-only [SimChipInput] at full opacity with a trailing copy button
/// (`Button variant='quiet' size='icon'`, 13px glyph) whose tooltip swaps to
/// "Copied!" for 2s.
class SimChipCopyInput extends StatefulWidget {
  const SimChipCopyInput({
    required this.value,
    super.key,
    this.copyLabel = 'Copy',
    this.icon,
    this.enabled = true,
    this.mono = false,
    this.semanticsLabel,
  });

  final String value;
  final String copyLabel;
  final SimIconData? icon;
  final bool enabled;
  final bool mono;
  final String? semanticsLabel;

  @override
  State<SimChipCopyInput> createState() => _SimChipCopyInputState();
}

class _SimChipCopyInputState extends State<SimChipCopyInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  bool _copied = false;
  Timer? _reset;

  @override
  void didUpdateWidget(SimChipCopyInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _reset?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(SimMotion.copiedReset, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) => SimChipInput(
    controller: _controller,
    readOnly: true,
    enabled: widget.enabled,
    icon: widget.icon,
    mono: widget.mono,
    cursor: MouseCursor.defer,
    semanticsLabel: widget.semanticsLabel,
    endAdornment: SimTooltip(
      message: _copied ? 'Copied!' : widget.copyLabel,
      child: SimButton(
        variant: SimButtonVariant.quiet,
        size: SimButtonSize.icon,
        semanticsLabel: widget.copyLabel,
        onPressed: _copy,
        child: SimIcon(
          _copied ? SimIcons.check : SimIcons.duplicate,
          size: 13,
          strokeWidth: 1.25,
        ),
      ),
    ),
  );
}
