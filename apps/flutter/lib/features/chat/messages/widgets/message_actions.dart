import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_app/features/chat/messages/widgets/chips.dart';
import 'package:sim_design/sim_design.dart';

/// The settled actions row (`message-actions.tsx:167-233` + the sources
/// button, `message-content.tsx:1105-1117`): `gap-0.5`, 26px (44 below md)
/// buttons with 14px `--text-icon` glyphs and a `--surface-hover` hover;
/// Copy (Check for 1500 ms), Like, Dislike, Fork (Split rotated 90°), then
/// "N sources" when the reply cited any.
class ChatMessageActions extends StatefulWidget {
  const ChatMessageActions({
    required this.message,
    required this.copyText,
    this.sources = const <ChatSourceView>[],
    this.compact = false,
    super.key,
  });

  final ChatAssistantMessageView message;
  final String copyText;
  final List<ChatSourceView> sources;

  /// Below md the buttons are 44px touch targets.
  final bool compact;

  @override
  State<ChatMessageActions> createState() => _ChatMessageActionsState();
}

class _ChatMessageActionsState extends State<ChatMessageActions> {
  final ChatCopyState _copied = ChatCopyState(
    const Duration(milliseconds: 1500),
  );
  bool _forking = false;

  @override
  void dispose() {
    _copied.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    if (widget.copyText.isEmpty) return;
    await ChatScope.of(context).copy(widget.copyText);
    if (mounted) _copied.copied();
  }

  Future<void> _fork() async {
    final fork = ChatScope.of(context).onFork;
    if (fork == null || _forking) return;
    setState(() => _forking = true);
    try {
      await fork(widget.message.id);
    } finally {
      if (mounted) setState(() => _forking = false);
    }
  }

  void _feedback({required bool positive}) {
    unawaited(
      showSimChipModal<void>(
        context,
        semanticsLabel: 'Give feedback',
        builder: (_) => _FeedbackModal(
          positive: positive,
          requestId: widget.message.requestId,
          onSubmit: (text) => ChatScope.of(context).onFeedback?.call(
            widget.message.id,
            positive: positive,
            text: text,
          ),
          copy: ChatScope.of(context).copy,
        ),
      ),
    );
  }

  Widget _button({
    required String id,
    required String label,
    required String tooltip,
    required Widget icon,
    required VoidCallback? onPressed,
    bool pending = false,
  }) {
    final c = SimTheme.of(context).colors;
    final size = widget.compact ? 44.0 : 26.0;
    return ChatParity(
      id,
      child: SimTooltip(
        message: tooltip,
        preferAbove: true,
        child: SimPressable(
          onPressed: pending ? null : onPressed,
          semanticsLabel: label,
          builder: (context, state) => Opacity(
            opacity: pending ? 0.5 : 1,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: state.hovered ? c.surfaceHover : null,
                borderRadius: BorderRadius.circular(SimRadii.md),
              ),
              alignment: Alignment.center,
              child: IconTheme.merge(
                data: IconThemeData(color: c.textIcon),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final callbacks = ChatScope.of(context);
    final m = widget.message;
    final canCopy = widget.copyText.trim().isNotEmpty;
    final canFeedback = m.canFeedback;
    final canFork = m.canFork && callbacks.onFork != null;
    return ChatParity(
      'chat.message.actions',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: <Widget>[
          if (canCopy)
            ValueListenableBuilder<bool>(
              valueListenable: _copied,
              builder: (context, copied, _) => _button(
                id: 'chat.message.actions.copy',
                label: 'Copy message',
                tooltip: copied ? 'Copied message' : 'Copy message',
                icon: SimIcon(
                  copied ? SimEmcnIcons.check : SimEmcnIcons.duplicate,
                ),
                onPressed: _copy,
              ),
            ),
          if (canFeedback) ...<Widget>[
            _button(
              id: 'chat.message.actions.like',
              label: 'Like',
              tooltip: 'Good response',
              icon: const SimIcon(SimEmcnIcons.thumbsUp),
              onPressed: () => _feedback(positive: true),
            ),
            _button(
              id: 'chat.message.actions.dislike',
              label: 'Dislike',
              tooltip: 'Bad response',
              icon: const SimIcon(SimEmcnIcons.thumbsDown),
              onPressed: () => _feedback(positive: false),
            ),
          ],
          if (canFork)
            _button(
              id: 'chat.message.actions.fork',
              label: 'Fork in new chat',
              tooltip: 'Fork in new chat',
              icon: const RotatedBox(
                quarterTurns: 1,
                child: SimIcon(SimEmcnIcons.split),
              ),
              pending: _forking,
              onPressed: _fork,
            ),
          if (widget.sources.isNotEmpty)
            ChatMessageSources(
              sources: widget.sources,
              onViewAll: callbacks.onViewAllSources == null
                  ? null
                  : () => callbacks.onViewAllSources!(m.id),
            ),
        ],
      ),
    );
  }
}

/// "Give feedback" `ChipModal`: a 6-row textarea (min 140px), Cancel +
/// Submit, and "Copy ID" (copies the request id, "Copied" for 1500 ms) on
/// dislike. An empty submit just closes.
class _FeedbackModal extends StatefulWidget {
  const _FeedbackModal({
    required this.positive,
    required this.onSubmit,
    required this.copy,
    this.requestId,
  });

  final bool positive;
  final String? requestId;
  final ValueChanged<String> onSubmit;
  final Future<void> Function(String) copy;

  @override
  State<_FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<_FeedbackModal> {
  final TextEditingController _text = TextEditingController();
  final ChatCopyState _copiedId = ChatCopyState(
    const Duration(milliseconds: 1500),
  );

  @override
  void dispose() {
    _text.dispose();
    _copiedId.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isNotEmpty) widget.onSubmit(text);
    SimModalScope.of(context).close();
  }

  @override
  Widget build(BuildContext context) {
    final requestId = widget.requestId;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SimChipModalHeader(
          title: 'Give feedback',
          onClose: () => SimModalScope.of(context).close(),
        ),
        SimChipModalBody(
          children: <Widget>[
            SimChipModalField.textarea(
              title: 'Feedback',
              controller: _text,
              rows: 6,
              minHeight: 140,
              placeholder: widget.positive
                  ? 'Tell us what was helpful...'
                  : 'Tell us what went wrong...',
            ),
          ],
        ),
        SimChipModalFooter(
          onCancel: () => SimModalScope.of(context).close(),
          secondaryActions: <Widget>[
            if (!widget.positive && requestId != null)
              ValueListenableBuilder<bool>(
                valueListenable: _copiedId,
                builder: (context, copied, _) => SimChip(
                  label: copied ? 'Copied' : 'Copy ID',
                  onPressed: () async {
                    await widget.copy(requestId);
                    if (mounted) _copiedId.copied();
                  },
                ),
              ),
          ],
          primaryAction: SimChipModalAction(
            label: 'Submit',
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}

/// `MessageSources`: the "N sources" action button and its 420px popover of
/// dense source rows (max 320px, scroll fades) with "View all sources".
class ChatMessageSources extends StatefulWidget {
  const ChatMessageSources({required this.sources, this.onViewAll, super.key});

  final List<ChatSourceView> sources;
  final VoidCallback? onViewAll;

  @override
  State<ChatMessageSources> createState() => _ChatMessageSourcesState();
}

class _ChatMessageSourcesState extends State<ChatMessageSources> {
  SimPopoverHandle? _popover;

  @override
  void dispose() {
    _popover?.close();
    super.dispose();
  }

  void _open(BuildContext anchor) {
    if (_popover?.isOpen ?? false) {
      _popover!.close();
      return;
    }
    final popover = SimPopover.show(
      anchor,
      side: SimSide.top,
      sideOffset: 4,
      minWidth: 420,
      maxWidth: 420,
      semanticsIdentifier: 'chat.message.sources.popover',
      onClose: () {
        if (mounted) setState(() => _popover = null);
      },
      builder: (context) => _SourcesList(
        sources: widget.sources,
        onViewAll: widget.onViewAll == null
            ? null
            : () {
                _popover?.close();
                widget.onViewAll!();
              },
      ),
    );
    setState(() => _popover = popover);
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final count = widget.sources.length;
    final label = '$count ${count == 1 ? 'source' : 'sources'}';
    final open = _popover?.isOpen ?? false;
    return ChatParity(
      'chat.message.sources',
      child: SimTooltip(
        message: label,
        preferAbove: true,
        child: Builder(
          builder: (anchor) => SimPressable(
            onPressed: () => _open(anchor),
            semanticsLabel: label,
            builder: (context, state) => Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: open
                    ? c.surfaceActive
                    : (state.hovered ? c.surfaceHover : null),
                borderRadius: BorderRadius.circular(SimRadii.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: <Widget>[
                  SimIcon(SimEmcnIcons.bookOpen, color: c.textIcon),
                  Text(
                    '$count',
                    style: ChatText.inter(
                      context,
                      12,
                      lineHeight: 18,
                      color: c.textIcon,
                      tracking: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourcesList extends StatelessWidget {
  const _SourcesList({required this.sources, this.onViewAll});

  final List<ChatSourceView> sources;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SimScrollFade(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final source in sources)
                      ChatSourceCard(source: source),
                  ],
                ),
              ),
            ),
          ),
          if (onViewAll != null)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
              ),
              alignment: Alignment.centerLeft,
              child: SimChip(
                label: 'View all sources',
                leftIcon: SimEmcnIcons.bookOpen,
                onPressed: onViewAll,
              ),
            ),
        ],
      ),
    );
  }
}

/// Dense `SourceCard` row: 30px chip geometry, 16px icon slot, title
/// `text-sm --text-body`, site `text-caption --text-tertiary` (≤40%).
class ChatSourceCard extends StatelessWidget {
  const ChatSourceCard({required this.source, super.key});

  final ChatSourceView source;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final open = ChatScope.of(context).onOpenLink;
    return ChatParity(
      'chat.source.card',
      child: SimPressable(
        isLink: true,
        semanticsLabel: source.label,
        onPressed: open == null ? null : () => open(source.url),
        builder: (context, state) => Container(
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: state.hovered ? c.surfaceHover : null,
            borderRadius: BorderRadius.circular(SimRadii.lg),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              spacing: 8,
              children: <Widget>[
                SizedBox.square(
                  dimension: 16,
                  child: Center(child: ChatSourceIcon(url: source.url)),
                ),
                Expanded(
                  child: SimOverflowText(
                    label: source.label,
                    style: ChatText.inter(
                      context,
                      14,
                      lineHeight: 20,
                      color: c.textBody,
                      tracking: true,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.4,
                  ),
                  child: SimOverflowText(
                    label: source.siteLabel,
                    style: ChatText.inter(
                      context,
                      12,
                      lineHeight: 18,
                      color: c.textTertiary,
                      tracking: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
