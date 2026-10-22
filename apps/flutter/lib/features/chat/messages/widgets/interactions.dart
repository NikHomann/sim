import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_design/sim_design.dart';

/// `InteractionCard` chrome (`interaction-card.tsx:27-45`): 16px radius,
/// 1px `--border-1`, `--white` (dark `--surface-4`), padding 10 × 8, an
/// optional title row (`px-2 py-2`, prompt `text-sm --text-primary`).
class ChatInteractionCard extends StatelessWidget {
  const ChatInteractionCard({
    required this.children,
    this.title,
    this.actions,
    this.parityId,
    super.key,
  });

  final String? title;
  final Widget? actions;
  final List<Widget> children;
  final String? parityId;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: sim.isDark ? c.surface4 : SimColors.white,
        border: Border.all(color: c.border1),
        borderRadius: BorderRadius.circular(SimRadii.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                spacing: 8,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title!,
                      style: ChatText.inter(
                        context,
                        14,
                        lineHeight: 20,
                        color: c.textPrimary,
                        tracking: true,
                      ),
                    ),
                  ),
                  ?actions,
                ],
              ),
            ),
          ...children,
        ],
      ),
    );
    return parityId == null ? card : ChatParity(parityId!, child: card);
  }
}

/// `INTERACTION_CARD_ROW_CLASSES`: `flex items-center gap-2 px-2 py-2`,
/// `border-t` between rows, hover/selected `--surface-5`.
class ChatInteractionRow extends StatelessWidget {
  const ChatInteractionRow({
    required this.label,
    this.leading,
    this.trailing,
    this.divided = false,
    this.selected = false,
    this.onPressed,
    this.enabled = true,
    this.parityId,
    this.labelColor,
    super.key,
  });

  final String label;
  final Widget? leading;
  final Widget? trailing;
  final bool divided;
  final bool selected;
  final VoidCallback? onPressed;
  final bool enabled;
  final String? parityId;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final row = SimPressable(
      enabled: enabled && onPressed != null,
      onPressed: onPressed,
      semanticsLabel: label,
      builder: (context, state) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected || state.hovered ? c.surface5 : null,
          border: divided ? Border(top: BorderSide(color: c.border)) : null,
        ),
        child: Row(
          spacing: 8,
          children: <Widget>[
            ?leading,
            Expanded(
              child: Text(
                label,
                style: ChatText.inter(
                  context,
                  14,
                  lineHeight: 20,
                  color: labelColor ?? c.textBody,
                  tracking: true,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
    return parityId == null ? row : ChatParity(parityId!, child: row);
  }
}

/// The `options` content block (`options.tsx`): wrapping round border chips.
class ChatOptionChips extends StatelessWidget {
  const ChatOptionChips({required this.options, super.key});

  final List<ChatOptionView> options;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final select = ChatScope.of(context).onOptionSelect;
    return ChatParity(
      'chat.options',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final option in options)
            SimChip(
              label: option.label,
              variant: SimChipVariant.border,
              shape: SimChipShape.round,
              onPressed: select == null ? null : () => select(option.id),
            ),
        ],
      ),
    );
  }
}

/// `<options>` tag (`OptionsDisplay`): "Suggested follow-ups" with numbered
/// rows; on older messages (no select callback) the rows are disabled and
/// the label toggles their visibility.
class ChatFollowUps extends StatefulWidget {
  const ChatFollowUps({required this.options, super.key});

  final List<ChatOptionView> options;

  @override
  State<ChatFollowUps> createState() => _ChatFollowUpsState();
}

class _ChatFollowUpsState extends State<ChatFollowUps> {
  bool _collapsedByUser = false;

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) return const SizedBox.shrink();
    final c = SimTheme.of(context).colors;
    final select = ChatScope.of(context).onOptionSelect;
    final disabled = select == null;
    final expanded = !disabled || !_collapsedByUser;
    final sm = ChatText.inter(context, 14, lineHeight: 20, tracking: true);
    final label = Text(
      'Suggested follow-ups',
      style: sm.copyWith(color: c.textBody),
    );
    return ChatParity(
      'chat.followups',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (disabled)
            Align(
              alignment: Alignment.centerLeft,
              child: SimPressable(
                onPressed: () =>
                    setState(() => _collapsedByUser = !_collapsedByUser),
                semanticsLabel: 'Suggested follow-ups',
                builder: (context, state) => Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: <Widget>[
                    label,
                    AnimatedRotation(
                      duration: SimMotion.of(SimMotion.sidebarChevron),
                      turns: expanded ? 0 : -0.25,
                      child: SimIcon(
                        SimEmcnIcons.chevronDown,
                        color: c.textIcon,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            label,
          ChatExpandable(
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (var i = 0; i < widget.options.length; i++)
                          ChatInteractionRow(
                            label: widget.options[i].label,
                            divided: i > 0,
                            enabled: !disabled,
                            onPressed: disabled
                                ? null
                                : () => select(widget.options[i].id),
                            leading: SizedBox.square(
                              dimension: 16,
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: sm.copyWith(color: c.textIcon),
                                ),
                              ),
                            ),
                            trailing: SimIcon(
                              SimEmcnIcons.arrowRight,
                              size: 16,
                              color: c.textIcon,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// `<mothership-error>`: `p.text-small.italic.leading-[20px] --text-secondary`.
class ChatErrorText extends StatelessWidget {
  const ChatErrorText({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return ChatParity(
      'chat.error',
      child: Text(
        message,
        style: ChatText.inter(
          context,
          13,
          lineHeight: 20,
          color: c.textSecondary,
          tracking: true,
        ).copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

/// Credential / usage-upgrade cards: interaction-card chrome with one row
/// per item (the flows behind them are Phase 4).
class ChatCredentialCard extends StatelessWidget {
  const ChatCredentialCard({required this.items, this.recap, super.key});

  final List<ChatCredentialItemView> items;

  /// Submitted or abandoned: `InteractionCardRecap`
  /// (`interaction-card.tsx:52-67`), one label + status per row.
  final List<ChatCredentialRecapItem>? recap;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final recap = this.recap;
    if (recap != null) {
      final sm = ChatText.inter(context, 14, lineHeight: 20, tracking: true);
      return ChatInteractionCard(
        parityId: 'chat.credential',
        children: <Widget>[
          for (final row in recap)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: <Widget>[
                  Text(row.label, style: sm.copyWith(color: c.textPrimary)),
                  Text(row.status, style: sm.copyWith(color: c.textMuted)),
                ],
              ),
            ),
        ],
      );
    }
    return ChatInteractionCard(
      parityId: 'chat.credential',
      children: <Widget>[
        for (var i = 0; i < items.length; i++)
          ChatInteractionRow(
            label: items[i].label,
            divided: i > 0,
            enabled: false,
            trailing: SimIcon(
              items[i].done ? SimEmcnIcons.check : SimEmcnIcons.arrowRight,
              size: 16,
              color: c.textIcon,
            ),
          ),
      ],
    );
  }
}

/// `formatQuestionAnswerMessage`: one `Prompt — Answer` line per question.
String formatQuestionAnswerMessage(
  List<ChatQuestionView> questions,
  List<String> answers,
) => <String>[
  for (var i = 0; i < questions.length; i++)
    '${questions[i].prompt} — ${i < answers.length ? answers[i] : ''}',
].join('\n');

/// `<question>` card (`question.tsx`): single-select rows answer on click,
/// multi-select rows toggle with a Continue/Submit row, a "Something else"
/// free-text row, a `‹ N of M ›` stepper and dismiss; answered → recap.
class ChatQuestionCard extends StatefulWidget {
  const ChatQuestionCard({
    required this.questions,
    this.answers,
    this.messageId,
    super.key,
  });

  final List<ChatQuestionView> questions;

  /// Transcript answers (renders the recap).
  final List<String>? answers;
  final String? messageId;

  @override
  State<ChatQuestionCard> createState() => _ChatQuestionCardState();
}

enum _Phase { active, answered, dismissed }

class _ChatQuestionCardState extends State<ChatQuestionCard> {
  _Phase _phase = _Phase.active;
  int _step = 0;
  late List<List<String>> _selected = <List<String>>[
    for (final _ in widget.questions) <String>[],
  ];
  late List<String> _customs = <String>[for (final _ in widget.questions) ''];
  late List<bool> _customChecked = <bool>[
    for (final _ in widget.questions) false,
  ];
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<ChatQuestionView> get _qs => widget.questions;

  @override
  void didUpdateWidget(ChatQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questions.length != widget.questions.length) {
      _selected = <List<String>>[for (final _ in widget.questions) <String>[]];
      _customs = <String>[for (final _ in widget.questions) ''];
      _customChecked = <bool>[for (final _ in widget.questions) false];
      _step = 0;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _customFor(int i, List<String> customs) =>
      _qs[i].type == ChatQuestionType.multiSelect && !_customChecked[i]
      ? ''
      : customs[i];

  String _answerFor(int i, List<String> selected, String custom) {
    final ordered = _qs[i].options
        .map((o) => o.label)
        .where(selected.contains)
        .toList();
    if (custom.trim().isNotEmpty) ordered.add(custom.trim());
    return ordered.join(', ');
  }

  List<String> _commitCustom() {
    final next = List<String>.of(_customs);
    next[_step] = _text.text.trim();
    _customs = next;
    return next;
  }

  void _finish(List<List<String>> selections, List<String> customs) {
    if (_step < _qs.length - 1) {
      setState(() {
        _step++;
        _text.text = customs[_step];
      });
      return;
    }
    setState(() => _phase = _Phase.answered);
    ChatScope.of(context).onOptionSelect?.call(
      formatQuestionAnswerMessage(_qs, <String>[
        for (var i = 0; i < _qs.length; i++)
          _answerFor(i, selections[i], _customFor(i, customs)),
      ]),
    );
  }

  bool _stepAnswered(int i) {
    if (_selected[i].isNotEmpty) return true;
    final text = i == _step ? _text.text : _customs[i];
    if (text.trim().isEmpty) return false;
    return _qs[i].type != ChatQuestionType.multiSelect || _customChecked[i];
  }

  void _goTo(int step) {
    _commitCustom();
    setState(() {
      _step = step;
      _text.text = _customs[step];
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final callbacks = ChatScope.of(context);
    final disabled = callbacks.onOptionSelect == null;
    final transcript = widget.answers;
    final local = _phase == _Phase.answered
        ? <String>[
            for (var i = 0; i < _qs.length; i++)
              _answerFor(i, _selected[i], _customFor(i, _customs)),
          ]
        : null;
    final recap = transcript ?? local;
    final sm = ChatText.inter(context, 14, lineHeight: 20, tracking: true);
    if (_qs.isNotEmpty && recap != null) {
      return ChatInteractionCard(
        parityId: 'chat.question',
        children: <Widget>[
          for (var i = 0; i < _qs.length; i++)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: <Widget>[
                  Text(_qs[i].prompt, style: sm.copyWith(color: c.textPrimary)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: <Widget>[
                      for (final part in _answerParts(
                        _qs[i],
                        i < recap.length ? recap[i] : '',
                      ))
                        Text(part, style: sm.copyWith(color: c.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    }
    if (_qs.isEmpty || _phase == _Phase.dismissed) {
      return const SizedBox.shrink();
    }
    final q = _qs[_step];
    final isLast = _step == _qs.length - 1;
    final isMulti = q.type == ChatQuestionType.multiSelect;
    final selected = _selected[_step];
    final canSubmitStep = !disabled && _stepAnswered(_step);
    final canSubmitText = !disabled && _text.text.trim().isNotEmpty;

    Widget iconButton(
      SimIconData icon,
      String label,
      VoidCallback? onPressed,
    ) => SimPressable(
      enabled: onPressed != null,
      onPressed: onPressed,
      semanticsLabel: label,
      builder: (context, state) => Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: SimIcon(icon, color: c.textIcon),
      ),
    );

    void submitSingleText() {
      final customs = _commitCustom();
      final selections = List<List<String>>.of(_selected);
      selections[_step] = <String>[];
      _selected = selections;
      _finish(selections, customs);
    }

    void submitMulti() => _finish(_selected, _commitCustom());

    return ChatInteractionCard(
      parityId: 'chat.question',
      title: q.prompt,
      actions: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: <Widget>[
          if (_qs.length > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: <Widget>[
                iconButton(
                  SimEmcnIcons.chevronLeft,
                  'Previous question',
                  _step == 0 ? null : () => _goTo(_step - 1),
                ),
                Text(
                  '${_step + 1} of ${_qs.length}',
                  style: sm.copyWith(
                    color: c.textMuted,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                iconButton(
                  SimEmcnIcons.chevronRight,
                  'Next question',
                  isLast || (!disabled && !_stepAnswered(_step))
                      ? null
                      : () => _goTo(_step + 1),
                ),
              ],
            ),
          Visibility(
            visible: !disabled,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: iconButton(SimEmcnIcons.x, 'Dismiss', () {
              setState(() => _phase = _Phase.dismissed);
              final id = widget.messageId;
              if (id != null) callbacks.onQuestionDismiss?.call(id);
            }),
          ),
        ],
      ),
      children: <Widget>[
        for (var i = 0; i < q.options.length; i++)
          ChatInteractionRow(
            parityId: 'chat.question.option',
            label: q.options[i].label,
            divided: i > 0,
            selected: selected.contains(q.options[i].label),
            enabled: !disabled,
            onPressed: disabled
                ? null
                : () {
                    final label = q.options[i].label;
                    final selections = List<List<String>>.of(_selected);
                    if (isMulti) {
                      final current = List<String>.of(selections[_step]);
                      current.contains(label)
                          ? current.remove(label)
                          : current.add(label);
                      selections[_step] = current;
                      setState(() => _selected = selections);
                      return;
                    }
                    selections[_step] = <String>[label];
                    _selected = selections;
                    final customs = List<String>.of(_customs)..[_step] = '';
                    _customs = customs;
                    _text.clear();
                    _finish(selections, customs);
                  },
            leading: isMulti
                ? _QuestionCheckbox(
                    checked: selected.contains(q.options[i].label),
                  )
                : null,
            trailing: isMulti
                ? null
                : SimIcon(SimEmcnIcons.arrowRight, size: 16, color: c.textIcon),
          ),
        ChatParity(
          'chat.question.freeText',
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: q.options.isNotEmpty
                  ? Border(top: BorderSide(color: c.border))
                  : null,
            ),
            child: Row(
              spacing: 8,
              children: <Widget>[
                if (isMulti)
                  GestureDetector(
                    onTap: disabled
                        ? null
                        : () => setState(() {
                            _customChecked[_step] = !_customChecked[_step];
                            if (_customChecked[_step]) _focus.requestFocus();
                          }),
                    child: _QuestionCheckbox(checked: _customChecked[_step]),
                  ),
                Expanded(
                  child: Focus(
                    onFocusChange: (focused) {
                      if (!isMulti) return;
                      if (focused) {
                        setState(() => _customChecked[_step] = true);
                      } else if (_text.text.trim().isEmpty) {
                        setState(() => _customChecked[_step] = false);
                      }
                    },
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (event.logicalKey == LogicalKeyboardKey.escape) {
                        node.unfocus();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.enter) {
                        if (isMulti && canSubmitStep) {
                          submitMulti();
                          return KeyEventResult.handled;
                        }
                        if (!isMulti && canSubmitText) {
                          submitSingleText();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: SimEditable(
                      controller: _text,
                      focusNode: _focus,
                      enabled: !disabled,
                      placeholder: 'Something else',
                      semanticsLabel: q.prompt,
                      onChanged: (_) => setState(() {}),
                      style: sm.copyWith(color: c.textBody),
                      placeholderStyle: sm.copyWith(color: c.textMuted),
                    ),
                  ),
                ),
                if (!isMulti)
                  SimPressable(
                    enabled: canSubmitText,
                    onPressed: submitSingleText,
                    semanticsLabel: 'Submit answer',
                    builder: (context, state) => SimIcon(
                      SimEmcnIcons.arrowRight,
                      size: 16,
                      color: canSubmitText ? c.textBody : c.textIcon,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (isMulti)
          ChatInteractionRow(
            label: isLast ? 'Submit' : 'Continue',
            divided: true,
            enabled: canSubmitStep,
            labelColor: canSubmitStep ? c.textBody : c.textMuted,
            onPressed: canSubmitStep ? submitMulti : null,
            leading: const SizedBox.square(dimension: 16),
            trailing: SimIcon(
              SimEmcnIcons.arrowRight,
              size: 16,
              color: c.textIcon,
            ),
          ),
      ],
    );
  }

  /// `answerPartsForDisplay`.
  List<String> _answerParts(ChatQuestionView q, String answer) {
    if (q.type != ChatQuestionType.multiSelect) return <String>[answer];
    final parts = <String>[];
    var remaining = answer;
    for (final option in q.options) {
      if (remaining == option.label) {
        parts.add(option.label);
        remaining = '';
        break;
      }
      if (remaining.startsWith('${option.label}, ')) {
        parts.add(option.label);
        remaining = remaining.substring(option.label.length + 2);
      }
    }
    if (remaining.isNotEmpty) parts.add(remaining);
    return parts.isEmpty ? <String>[answer] : parts;
  }
}

class _QuestionCheckbox extends StatelessWidget {
  const _QuestionCheckbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return SizedBox.square(
      dimension: 16,
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: checked ? c.textPrimary : null,
            border: Border.all(color: checked ? c.textPrimary : c.border),
            borderRadius: BorderRadius.circular(SimRadii.sm),
          ),
          child: checked
              ? SimIcon(SimEmcnIcons.check, size: 10, color: c.surface2)
              : null,
        ),
      ),
    );
  }
}
