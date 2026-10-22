import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/widgets/fields/editable.dart';

/// Port of `packages/emcn/src/components/input/input.tsx` (`INPUT_CLASS`):
/// rounded-sm, 1px `--border`, `--surface-5` fill, px-2 py-1.5, text-sm
/// `--text-primary`, muted placeholder, no outline, `disabled:opacity-50`.
/// For chip-styled surfaces use `SimChipInput` instead.
class SimInput extends StatelessWidget {
  const SimInput({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
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
    this.style,
    this.onKeyEvent,
    this.semanticsLabel,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
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
  final TextStyle? style;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface5,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(SimRadii.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SimEditable(
            controller: controller,
            focusNode: focusNode,
            placeholder: placeholder,
            style: (style ?? sim.text.sm).copyWith(color: c.textPrimary),
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
            semanticsLabel: semanticsLabel,
          ),
        ),
      ),
    );
  }
}

/// Port of `packages/emcn/src/components/textarea/textarea.tsx`: the
/// multi-line sibling of [SimInput] with py-2 and no resize handle.
class SimTextarea extends StatelessWidget {
  const SimTextarea({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.enabled = true,
    this.readOnly = false,
    this.minLines = 3,
    this.maxLines,
    this.maxLength,
    this.onChanged,
    this.autofocus = false,
    this.style,
    this.semanticsLabel,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final bool enabled;
  final bool readOnly;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextStyle? style;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface5,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(SimRadii.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SimEditable(
            controller: controller,
            focusNode: focusNode,
            placeholder: placeholder,
            style: (style ?? sim.text.sm).copyWith(color: c.textPrimary),
            enabled: enabled,
            readOnly: readOnly,
            minLines: minLines,
            maxLines: maxLines,
            maxLength: maxLength,
            onChanged: onChanged,
            autofocus: autofocus,
            semanticsLabel: semanticsLabel,
          ),
        ),
      ),
    );
  }
}
