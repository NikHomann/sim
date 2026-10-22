import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// Port of emcn `InputOTP` (`packages/emcn/src/components/input-otp/`): one
/// hidden numeric input over six 48×48 slots on an 8px gap — `--surface-5`
/// fill, 1px `--border-1`, radius 4, 18px digits; the active slot gets a
/// `--text-muted` border plus 1px ring and a blinking 24×1 caret; [invalid]
/// turns every border `--text-error`; [enabled] false dims the row to 50%.
class OtpInput extends StatefulWidget {
  const OtpInput({
    required this.value,
    required this.onChanged,
    super.key,
    this.length = 6,
    this.enabled = true,
    this.invalid = false,
    this.autofocus = false,
    this.identifier = 'auth.verify.otp',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int length;
  final bool enabled;
  final bool invalid;
  final bool autofocus;
  final String identifier;

  static const double slotSize = 48;
  static const double slotGap = 8;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode(debugLabel: 'OtpInput');
  AnimationController? _blink;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focus.addListener(_rebuild);
    if (!SimMotion.disabled) {
      _blink = AnimationController(vsync: this, duration: SimMotion.caretBlink);
      unawaited(_blink!.repeat());
    }
  }

  @override
  void didUpdateWidget(OtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_rebuild)
      ..dispose();
    _focus
      ..removeListener(_rebuild)
      ..dispose();
    _blink?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onChanged(String value) {
    if (value != widget.value) widget.onChanged(value);
  }

  int get _activeIndex {
    final selection = _controller.selection;
    final offset = selection.isValid
        ? selection.extentOffset
        : _controller.text.length;
    return offset.clamp(0, widget.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final text = _controller.text;
    final focused = _focus.hasFocus && widget.enabled;
    final active = _activeIndex;
    final width =
        widget.length * OtpInput.slotSize +
        (widget.length - 1) * OtpInput.slotGap;
    return Semantics(
      container: true,
      identifier: widget.identifier,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.5,
        child: SizedBox(
          width: width,
          height: OtpInput.slotSize,
          child: Stack(
            children: <Widget>[
              Row(
                spacing: OtpInput.slotGap,
                children: <Widget>[
                  for (var i = 0; i < widget.length; i++)
                    Semantics(
                      container: true,
                      identifier: '${widget.identifier}.slot.$i',
                      child: _Slot(
                        char: i < text.length ? text[i] : null,
                        active: focused && i == active,
                        invalid: widget.invalid,
                        blink: _blink,
                        colors: c,
                        style: sim.text.lg.copyWith(color: c.textPrimary),
                      ),
                    ),
                ],
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.enabled ? _focus.requestFocus : null,
                  child: Opacity(
                    opacity: 0,
                    child: EditableText(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      readOnly: !widget.enabled,
                      showCursor: false,
                      style: const TextStyle(fontSize: 1),
                      cursorColor: const Color(0x00000000),
                      backgroundCursorColor: const Color(0x00000000),
                      keyboardType: TextInputType.number,
                      autofillHints: const <String>[AutofillHints.oneTimeCode],
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(widget.length),
                      ],
                      onChanged: _onChanged,
                      rendererIgnoresPointer: true,
                      mouseCursor: SystemMouseCursors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.char,
    required this.active,
    required this.invalid,
    required this.blink,
    required this.colors,
    required this.style,
  });

  final String? char;
  final bool active;
  final bool invalid;
  final AnimationController? blink;
  final SimColors colors;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final borderColor = invalid
        ? colors.textError
        : active
        ? colors.textMuted
        : colors.border;
    Widget caret = Container(width: 1, height: 24, color: colors.textPrimary);
    final controller = blink;
    if (controller != null) {
      caret = AnimatedBuilder(
        animation: controller,
        builder: (context, child) =>
            Opacity(opacity: controller.value < 0.5 ? 1 : 0, child: child),
        child: caret,
      );
    }
    return Container(
      width: OtpInput.slotSize,
      height: OtpInput.slotSize,
      decoration: BoxDecoration(
        color: colors.surface5,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(SimRadii.sm),
        boxShadow: active
            ? <BoxShadow>[BoxShadow(color: colors.textMuted, spreadRadius: 1)]
            : null,
      ),
      alignment: Alignment.center,
      child: char != null
          ? Text(char!, style: style)
          : active
          ? caret
          : null,
    );
  }
}
