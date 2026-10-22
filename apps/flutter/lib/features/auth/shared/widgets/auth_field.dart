import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// `AUTH_CONTROL_HEIGHT = 'h-9'`: auth inputs and buttons are 36px tall.
const double authControlHeight = 36;

/// Port of `auth-field.tsx`: label row (13px label, optional right-aligned
/// action), the control 8px below, then the error list (12px `--text-error`
/// lines on a 4px gap).
class AuthField extends StatelessWidget {
  const AuthField({
    required this.label,
    required this.identifier,
    required this.child,
    super.key,
    this.errors = const <String>[],
    this.action,
    this.enabled = true,
  });

  final String label;

  /// `<prefix>.field` wraps the row, `<prefix>.label` the label.
  final String identifier;
  final Widget child;
  final List<String> errors;
  final Widget? action;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    return Semantics(
      container: true,
      identifier: '$identifier.field',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Semantics(
                container: true,
                identifier: '$identifier.label',
                child: SimLabel(label, enabled: enabled),
              ),
              ?action,
            ],
          ),
          child,
          if (errors.isNotEmpty)
            Semantics(
              container: true,
              identifier: '$identifier.errors',
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 4,
                children: <Widget>[
                  for (final error in errors)
                    Text(
                      error,
                      style: sim.text.caption.copyWith(
                        color: sim.colors.textError,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Port of `auth-input.tsx` (`ChipInput` + `h-9`): the chip field surface at
/// 36px — `--surface-5` fill, 1px `--border-1` (error: `--text-error`),
/// radius 8, 8px side padding, 14px `--text-body` text, no focus ring.
/// Enter submits through [onSubmit].
class AuthInput extends StatelessWidget {
  const AuthInput({
    required this.controller,
    required this.identifier,
    super.key,
    this.focusNode,
    this.placeholder,
    this.error = false,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmit,
    this.autofocus = false,
    this.endAdornment,
    this.semanticsLabel,
    this.tooltip,
  });

  final TextEditingController controller;
  final String identifier;
  final FocusNode? focusNode;
  final String? placeholder;
  final bool error;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;
  final bool autofocus;
  final Widget? endAdornment;
  final String? semanticsLabel;

  /// The native `title` tooltip (the name field's character rule).
  final String? tooltip;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (onSubmit == null || !isPlainEnter(event)) return KeyEventResult.ignored;
    onSubmit!();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final textStyle = sim.text.sm.copyWith(color: c.textBody);
    Widget field = Container(
      height: authControlHeight,
      padding: const EdgeInsets.symmetric(horizontal: SimChipChrome.paddingX),
      decoration: SimChipChrome.fieldSurface(c, error: error),
      child: Row(
        spacing: SimChipChrome.gap,
        children: <Widget>[
          Expanded(
            child: SimEditable(
              controller: controller,
              focusNode: focusNode,
              placeholder: placeholder,
              style: textStyle,
              placeholderStyle: textStyle.copyWith(color: c.textMuted),
              enabled: enabled,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              textInputAction: onSubmit == null
                  ? TextInputAction.next
                  : TextInputAction.done,
              onChanged: onChanged,
              onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
              onKeyEvent: _onKey,
              autofocus: autofocus,
              autocorrect: false,
              enableSuggestions: false,
              semanticsLabel: semanticsLabel ?? placeholder,
            ),
          ),
          ?endAdornment,
        ],
      ),
    );
    field = Opacity(
      opacity: enabled ? 1 : SimChipChrome.fieldDisabledOpacity,
      child: field,
    );
    if (tooltip != null) {
      field = SimTooltip(message: tooltip, child: field);
    }
    return Semantics(container: true, identifier: identifier, child: field);
  }
}

/// Port of `password-input.tsx`: an [AuthInput] masked by default with the
/// 14px eye toggle (`--text-icon`, hover `--text-primary`) at the right.
class PasswordInput extends StatefulWidget {
  const PasswordInput({
    required this.controller,
    required this.identifier,
    super.key,
    this.focusNode,
    this.placeholder,
    this.error = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmit,
    this.semanticsLabel,
  });

  final TextEditingController controller;
  final String identifier;
  final FocusNode? focusNode;
  final String? placeholder;
  final bool error;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;
  final String? semanticsLabel;

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return AuthInput(
      controller: widget.controller,
      identifier: widget.identifier,
      focusNode: widget.focusNode,
      placeholder: widget.placeholder,
      error: widget.error,
      enabled: widget.enabled,
      obscureText: !_revealed,
      keyboardType: TextInputType.visiblePassword,
      onChanged: widget.onChanged,
      onSubmit: widget.onSubmit,
      semanticsLabel: widget.semanticsLabel,
      endAdornment: Semantics(
        container: true,
        identifier: '${widget.identifier}.toggle',
        child: SimPressable(
          onPressed: () => setState(() => _revealed = !_revealed),
          enabled: widget.enabled,
          semanticsLabel: _revealed ? 'Hide password' : 'Show password',
          builder: (context, state) => SizedBox.square(
            dimension: SimChipChrome.fieldIconSize,
            child: SimIcon(
              _revealed ? SimIcons.eyeOff : SimIcons.eye,
              color: state.hovered ? c.textPrimary : c.textIcon,
            ),
          ),
        ),
      ),
    );
  }
}
