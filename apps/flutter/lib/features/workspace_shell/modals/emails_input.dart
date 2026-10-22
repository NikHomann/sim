import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sim_app/features/auth/shared/email_validation.dart';
import 'package:sim_design/sim_design.dart';

/// One token of the emails field (`TagItem`).
@immutable
class EmailToken {
  const EmailToken(this.value, {this.error});

  final String value;

  /// The validation reason; `null` for an accepted address.
  final String? error;

  bool get isValid => error == null;
}

/// Splits pasted or typed text on whitespace, commas and semicolons.
final RegExp emailSeparators = RegExp(r'[\s,;]+');

/// `addValues` of `ChipEmailsInput`: each raw value is normalised (trimmed,
/// lowercased), duplicates (valid or not) are dropped, a syntax failure
/// becomes an invalid token "Invalid email format", then [validate] may
/// reject it with its own reason.
List<EmailToken> addEmailTokens(
  List<EmailToken> current,
  Iterable<String> raws, {
  String? Function(String email)? validate,
}) {
  final next = <EmailToken>[...current];
  final seen = current.map((t) => t.value).toSet();
  for (final raw in raws) {
    final email = normalizeEmail(raw);
    if (email.isEmpty || seen.contains(email)) continue;
    seen.add(email);
    if (!isValidEmailSyntax(email)) {
      next.add(EmailToken(email, error: 'Invalid email format'));
      continue;
    }
    final reason = validate?.call(email);
    next.add(EmailToken(email, error: reason));
  }
  return next;
}

/// `derivePlaceholderWithTags`: "Enter emails" → "Add email"; anything not
/// starting with "Enter" → "Add another".
String placeholderWithTags(String placeholder) {
  const prefix = 'enter';
  if (placeholder.length < prefix.length ||
      placeholder.substring(0, prefix.length).toLowerCase() != prefix) {
    return 'Add another';
  }
  final rest = placeholder.substring(prefix.length);
  final noun = rest.trim();
  if (rest == noun || noun.isEmpty) return 'Add another';
  final singular = noun.toLowerCase().endsWith('s')
      ? noun.substring(0, noun.length - 1)
      : noun;
  return 'Add $singular';
}

/// `min-h-[112px]` / `max-h-48` of `TagInput variant='block'`.
const double emailsFieldMinHeight = 112;
const double emailsFieldMaxHeight = 192;

/// `ChipEmailsInput` (block variant): the tokens and, inline after them, the
/// text entry inside one field surface. Enter, comma, space and paste
/// commit; Backspace on an empty entry removes the last token. [onChanged] receives the valid addresses;
/// invalid tokens stay visible (error surface) with the first reason shown
/// inside the control. A [value] that differs from the valid tokens (the
/// parent replacing the list) resets the tokens to it.
class EmailsInput extends StatefulWidget {
  const EmailsInput({
    required this.value,
    required this.onChanged,
    super.key,
    this.validate,
    this.placeholder = 'Enter emails',
    this.enabled = true,
  });

  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final String? Function(String email)? validate;
  final String placeholder;
  final bool enabled;

  @override
  State<EmailsInput> createState() => _EmailsInputState();
}

class _EmailsInputState extends State<EmailsInput> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'EmailsInput');
  List<EmailToken> _tokens = const [];

  @override
  void initState() {
    super.initState();
    _tokens = [for (final v in widget.value) EmailToken(v)];
    _text.addListener(_onTextEdited);
  }

  void _onTextEdited() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(EmailsInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final valid = _valid(_tokens);
    if (!listEquals(valid, widget.value)) {
      _tokens = [for (final v in widget.value) EmailToken(v)];
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  static List<String> _valid(List<EmailToken> tokens) => [
    for (final t in tokens)
      if (t.isValid) t.value,
  ];

  void _commit(Iterable<String> raws) {
    final before = _valid(_tokens);
    final next = addEmailTokens(_tokens, raws, validate: widget.validate);
    if (next.length == _tokens.length) return;
    setState(() => _tokens = next);
    final after = _valid(next);
    if (!listEquals(before, after)) widget.onChanged(after);
  }

  void _removeAt(int index) {
    final wasValid = _tokens[index].isValid;
    setState(() => _tokens = [..._tokens]..removeAt(index));
    if (wasValid) widget.onChanged(_valid(_tokens));
  }

  void _onTextChanged(String text) {
    if (!emailSeparators.hasMatch(text)) return;
    final parts = text.split(emailSeparators);
    final remainder = parts.removeLast();
    _commit(parts);
    _text.value = TextEditingValue(
      text: remainder,
      selection: TextSelection.collapsed(offset: remainder.length),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (isPlainEnter(event)) {
      if (_text.text.trim().isEmpty) return KeyEventResult.ignored;
      _commit([_text.text]);
      _text.clear();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _text.text.isEmpty &&
        _tokens.isNotEmpty) {
      _removeAt(_tokens.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The entry's width: its text or placeholder (`size=` upstream), at
  /// least a caret, at most the row.
  double _entryWidth(TextStyle style, String placeholder, double maxWidth) {
    final shown = _text.text.length > placeholder.length
        ? _text.text
        : placeholder;
    final painter = TextPainter(
      text: TextSpan(text: shown, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width + 4;
    painter.dispose();
    return width.clamp(4, maxWidth).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final firstError = _tokens.where((t) => !t.isValid).firstOrNull?.error;
    final placeholder = _tokens.isEmpty
        ? widget.placeholder
        : placeholderWithTags(widget.placeholder);
    final style = sim.text.sm.copyWith(color: c.textBody, height: 20 / 14);
    // `TagInput variant='block'`: one field surface (min 112, max 192,
    // px-2 py-2, wrap gap 8, items top-aligned) holding the tags and,
    // inline after them, the 20px text entry.
    final surface = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _focus.requestFocus : null,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: emailsFieldMinHeight,
          maxHeight: emailsFieldMaxHeight,
        ),
        padding: const EdgeInsets.all(8),
        decoration: SimChipChrome.fieldSurface(c),
        child: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (var i = 0; i < _tokens.length; i++)
                  SimChipTag(
                    label: _tokens[i].value,
                    variant: SimChipTagVariant.invite,
                    invalid: !_tokens[i].isValid,
                    rightIcon: widget.enabled ? SimIcons.x : null,
                    rightIconLabel: 'Remove ${_tokens[i].value}',
                    rightIconEnabled: widget.enabled,
                    onRightIconPressed: () => _removeAt(i),
                  ),
                SizedBox(
                  height: 20,
                  width: _entryWidth(style, placeholder, constraints.maxWidth),
                  child: SimEditable(
                    controller: _text,
                    focusNode: _focus,
                    placeholder: placeholder,
                    style: style,
                    placeholderStyle: style.copyWith(color: c.textMuted),
                    enabled: widget.enabled,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: _onTextChanged,
                    onKeyEvent: _onKey,
                    semanticsLabel: 'Emails',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Opacity(
      opacity: widget.enabled ? 1 : SimChipChrome.fieldDisabledOpacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: <Widget>[
          surface,
          if (firstError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                firstError,
                style: sim.text.caption.copyWith(color: c.textError),
              ),
            ),
        ],
      ),
    );
  }
}
