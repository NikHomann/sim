import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/activity/activity_status.dart';
import 'package:sim_app/features/chat/messages/activity/countdown.dart';
import 'package:sim_app/features/chat/messages/activity/permission_card.dart';
import 'package:sim_app/features/chat/messages/activity/thinking_loader.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/streaming/smooth_text.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_design/sim_design.dart';

/// One tool call as a static activity row, or its permission card while it
/// awaits approval (`ToolCallItem`). Rows never shimmer; only the lane's
/// live header does.
class ChatToolCallRow extends StatelessWidget {
  const ChatToolCallRow({
    required this.tool,
    this.outstandingIds = const <String>[],
    super.key,
  });

  final ChatToolCallView tool;
  final List<String> outstandingIds;

  @override
  Widget build(BuildContext context) {
    if (tool.state == ChatToolState.awaitingApproval) {
      return ChatPermissionCard(tool: tool, outstandingIds: outstandingIds);
    }
    final countdown = tool.countdown;
    final icon = SimIcon(tool.icon ?? SimEmcnIcons.wrench);
    return ChatParity(
      'chat.tool.call',
      child: countdown == null
          ? ChatActivityStatus(label: tool.title, icon: icon)
          : ChatCountdownBuilder(
              countdown: countdown,
              builder: (context, elapsed) => ChatActivityStatus(
                label: countdown.title(elapsed),
                icon: icon,
              ),
            ),
    );
  }
}

/// A lane of agent activity (`AgentGroupView`): the main lane renders its
/// tool runs only; a subagent lane renders a collapsible header over its
/// items (collapsed by default, forced open by a pending permission).
class ChatAgentGroup extends StatefulWidget {
  const ChatAgentGroup({
    required this.group,
    this.streaming = false,
    this.outstandingIds = const <String>[],
    super.key,
  });

  final ChatAgentGroupView group;
  final bool streaming;
  final List<String> outstandingIds;

  @override
  State<ChatAgentGroup> createState() => _ChatAgentGroupState();
}

class _ChatAgentGroupState extends State<ChatAgentGroup> {
  bool _expanded = false;

  ChatAgentGroupView get group => widget.group;

  bool get _collapsible {
    final meaningful = group.items.where(_hasContent).toList();
    return meaningful.length > 1 ||
        meaningful.any(
          (item) =>
              item is! ChatAgentToolItem ||
              item.tool.state == ChatToolState.error ||
              item.tool.state == ChatToolState.rejected ||
              item.tool.state == ChatToolState.awaitingApproval,
        );
  }

  static bool _hasContent(ChatAgentItem item) => switch (item) {
    ChatAgentTextItem(:final content) => content.trim().isNotEmpty,
    ChatAgentToolItem() => true,
    ChatAgentNestedItem(:final group) => group.hasContent,
  };

  Widget _item(ChatAgentItem item, int index) => switch (item) {
    ChatAgentToolItem(:final tool) => ChatToolCallRow(
      tool: tool,
      outstandingIds: widget.outstandingIds,
    ),
    ChatAgentNestedItem(group: final nested) => ChatActivityTextColumn(
      child: ChatAgentGroup(
        group: nested,
        streaming: widget.streaming,
        outstandingIds: widget.outstandingIds,
      ),
    ),
    ChatAgentTextItem(:final content, :final streaming) =>
      content.trim().isEmpty
          ? const SizedBox.shrink()
          : ChatActivityTextColumn(
              child: ChatNarration(content: content, streaming: streaming),
            ),
  };

  @override
  Widget build(BuildContext context) {
    if (!group.hasContent) return const SizedBox.shrink();
    final c = SimTheme.of(context).colors;
    final error = group.error;
    final errorLine = error == null
        ? null
        : ChatActivityTextColumn(
            child: ChatParity(
              'chat.agent.error',
              child: Text(
                error,
                style: ChatText.inter(
                  context,
                  12,
                  lineHeight: 18,
                  color: c.textTertiary,
                  tracking: true,
                ),
              ),
            ),
          );
    if (group.isMain) {
      return ChatParity(
        'chat.agent.group',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: <Widget>[
            ..._mainLane(),
            ?errorLine,
          ],
        ),
      );
    }
    final pending = group.hasPendingPermission;
    final liveWithoutTool =
        group.isLive &&
        !group.items.any(
          (i) =>
              i is ChatAgentToolItem && i.tool.state == ChatToolState.executing,
        );
    final icon = liveWithoutTool
        ? const ChatThinkingLoader(size: 14)
        : SimIcon(group.icon ?? SimEmcnIcons.blimp);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: <Widget>[
        for (var i = 0; i < group.items.length; i++) _item(group.items[i], i),
      ],
    );
    Widget header(String label) => ChatActivityDisclosure(
      label: label,
      icon: icon,
      active: group.isLive && error == null,
      collapsible: _collapsible,
      expanded: pending || _expanded,
      expandedLabel: pending ? null : group.expandedLabel,
      onToggle: () => setState(() => _expanded = !(pending || _expanded)),
      streaming: widget.streaming,
      unbounded: pending,
      body: body,
    );
    return ChatParity(
      'chat.agent.group',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: <Widget>[
          if (group.labelCountdown != null && error == null)
            ChatCountdownBuilder(
              countdown: group.labelCountdown!,
              builder: (context, elapsed) =>
                  header(group.labelCountdown!.activeTitle(elapsed)),
            )
          else
            header(error != null ? group.agentName : group.label),
          ?errorLine,
        ],
      ),
    );
  }

  /// Consecutive main-lane tools form one run with a paced header
  /// (`MainAgentActivity` + `ToolActivityGroup`).
  List<Widget> _mainLane() {
    final widgets = <Widget>[];
    final run = <ChatToolCallView>[];
    void flush() {
      if (run.isEmpty) return;
      widgets.add(
        _ToolRun(
          key: ValueKey<String>(run.first.id),
          tools: List<ChatToolCallView>.of(run),
          group: group,
          streaming: widget.streaming,
          outstandingIds: widget.outstandingIds,
        ),
      );
      run.clear();
    }

    for (var i = 0; i < group.items.length; i++) {
      final item = group.items[i];
      if (item is ChatAgentToolItem &&
          item.tool.state != ChatToolState.awaitingApproval) {
        run.add(item.tool);
      } else {
        flush();
        widgets.add(_item(item, i));
      }
    }
    flush();
    return widgets;
  }
}

class _ToolRun extends StatefulWidget {
  const _ToolRun({
    required this.tools,
    required this.group,
    required this.streaming,
    required this.outstandingIds,
    super.key,
  });

  final List<ChatToolCallView> tools;
  final ChatAgentGroupView group;
  final bool streaming;
  final List<String> outstandingIds;

  @override
  State<_ToolRun> createState() => _ToolRunState();
}

class _ToolRunState extends State<_ToolRun> {
  bool _expanded = false;

  /// `getActivityHeaderTool`: newest running, else last non-failed, else last.
  ChatToolCallView get _header {
    final tools = widget.tools;
    return tools.lastWhere(
      (t) => t.state == ChatToolState.executing,
      orElse: () => tools.lastWhere(
        (t) =>
            t.state != ChatToolState.error && t.state != ChatToolState.rejected,
        orElse: () => tools.last,
      ),
    );
  }

  String _summary() {
    final tools = widget.tools;
    if (tools.length == 1) return tools.single.title;
    final succeeded = tools
        .where((t) => t.state == ChatToolState.success)
        .toList();
    final group = widget.group;
    final interruptions = <String>[];
    final stopped = tools
        .where(
          (t) =>
              t.state == ChatToolState.cancelled ||
              t.state == ChatToolState.interrupted,
        )
        .length;
    final skipped = tools.where((t) => t.state == ChatToolState.skipped).length;
    if (stopped > 0) interruptions.add('$stopped stopped');
    if (skipped > 0) interruptions.add('$skipped skipped');
    if (group.completedTitle != null && succeeded.length == tools.length) {
      return group.completedTitle!;
    }
    // `getToolActivitySummary`: the only successful call keeps its title;
    // several name their distinct actions ("Navigated, read pages, clicked
    // elements"); a call without a phrase falls back to its title.
    final parts = succeeded.length == 1
        ? <String>[succeeded.single.title]
        : chatActivitySummaryActions(<ChatActivityPhrase>[
            for (final t in succeeded)
              t.activityPhrase ?? ChatActivityPhrase(chatPhraseCase(t.title)),
          ], 3);
    final summary = parts.isEmpty || parts.first.isEmpty
        ? '${tools.length} tool ${tools.length == 1 ? 'call' : 'calls'}'
        : <String>[
            parts.first[0].toUpperCase() + parts.first.substring(1),
            ...parts.skip(1),
          ].join(', ');
    return <String>[summary, ...interruptions].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final tools = widget.tools;
    final header = _header;
    final working = tools.any((t) => !t.state.isDone);
    final live = widget.group.isLive && working;
    final label = working ? (header.activeTitle ?? header.title) : _summary();
    final collapsible = tools.length > 1;
    Widget disclosureWith(String label) => ChatActivityDisclosure(
      label: label,
      icon: SimIcon(header.icon ?? SimEmcnIcons.wrench),
      active: live,
      collapsible: collapsible,
      expanded: _expanded,
      expandedLabel: collapsible ? widget.group.expandedLabel : null,
      onToggle: () => setState(() => _expanded = !_expanded),
      streaming: working && widget.streaming,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: <Widget>[
          for (final tool in tools)
            ChatToolCallRow(tool: tool, outstandingIds: widget.outstandingIds),
        ],
      ),
    );
    final countdown = working ? header.countdown : null;
    final disclosure = countdown == null
        ? disclosureWith(label)
        : ChatCountdownBuilder(
            countdown: countdown,
            builder: (context, elapsed) =>
                disclosureWith(countdown.activeTitle(elapsed)),
          );
    // A one-call run is that call's row (`ToolCallItem` + `renderStatus`).
    return tools.length == 1
        ? ChatParity('chat.tool.call', child: disclosure)
        : disclosure;
  }
}

/// Narration row (`NarrationText`): `--text-tertiary` 15/20 with inline
/// markdown (bold 600, italic, `code` mono 12, links as their label); the
/// live tail is paced like top-level text.
class ChatNarration extends StatefulWidget {
  const ChatNarration({
    required this.content,
    this.streaming = false,
    super.key,
  });

  final String content;
  final bool streaming;

  @override
  State<ChatNarration> createState() => _ChatNarrationState();
}

class _ChatNarrationState extends State<ChatNarration>
    with SingleTickerProviderStateMixin {
  late final SmoothTextPacer _pacer = SmoothTextPacer(
    content: widget.content,
    streaming: widget.streaming && !SimMotion.disabled,
  );
  Ticker? _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(ChatNarration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pacer.update(
      widget.content,
      streaming: widget.streaming && !SimMotion.disabled,
    );
    if (SimMotion.disabled) _pacer.snap();
    _arm();
  }

  void _arm() {
    if (!_pacer.hasBacklog) return;
    final ticker = _ticker ??= createTicker(_onTick);
    if (!ticker.isActive) {
      _last = Duration.zero;
      unawaited(ticker.start());
    }
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _last;
    _last = elapsed;
    if (_pacer.tick(dt)) setState(() {});
    if (!_pacer.hasBacklog) _ticker?.stop();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final style = ChatText.inter(
      context,
      15,
      lineHeight: 20,
      color: c.textTertiary,
      tracking: true,
    );
    return ChatParity(
      'chat.agent.narration',
      child: Text.rich(
        TextSpan(
          style: style,
          children: renderInlineMarkdown(_pacer.visible.trim(), style),
        ),
      ),
    );
  }
}

final RegExp _inlineToken = RegExp(
  r'(\*{3}[^\s*](?:[^*\n]*[^\s*])?\*{3}|\*\*[^\s*](?:[^*\n]*[^\s*])?\*\*|\*[^\s*](?:[^*\n]*[^\s*])?\*|`[^`\n]+`|\[[^\]\n]+\]\([^\s)]+\))',
);
final RegExp _linkToken = RegExp(r'^\[([^\]\n]+)\]\([^\s)]+\)$');

/// Port of `renderInlineMarkdown` (`agent-group/inline-markdown.tsx`).
List<InlineSpan> renderInlineMarkdown(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in _inlineToken.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(_inlineTokenSpan(match.group(0)!, style));
    cursor = match.end;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return spans;
}

InlineSpan _inlineTokenSpan(String part, TextStyle style) {
  final bold = SimTextStyles.weight(style, SimTextStyles.semibold);
  if (part.length > 6 && part.startsWith('***') && part.endsWith('***')) {
    final s = bold.copyWith(fontStyle: FontStyle.italic);
    return TextSpan(
      style: s,
      children: renderInlineMarkdown(part.substring(3, part.length - 3), s),
    );
  }
  if (part.length > 4 && part.startsWith('**') && part.endsWith('**')) {
    return TextSpan(
      style: bold,
      children: renderInlineMarkdown(part.substring(2, part.length - 2), bold),
    );
  }
  if (part.length > 2 && part.startsWith('`') && part.endsWith('`')) {
    return TextSpan(
      text: part.substring(1, part.length - 1),
      style: ChatText.mono(12, color: style.color),
    );
  }
  if (part.length > 2 && part.startsWith('*') && part.endsWith('*')) {
    final s = style.copyWith(fontStyle: FontStyle.italic);
    return TextSpan(
      style: s,
      children: renderInlineMarkdown(part.substring(1, part.length - 1), s),
    );
  }
  final link = _linkToken.firstMatch(part);
  if (link != null) {
    return TextSpan(children: renderInlineMarkdown(link.group(1)!, style));
  }
  return TextSpan(text: part);
}

/// A `task` (watch) row (`WatchActivity`): the normal activity row, active
/// while pending.
class ChatWatchRow extends StatelessWidget {
  const ChatWatchRow({required this.segment, super.key});

  final ChatWatchSegment segment;

  @override
  Widget build(BuildContext context) {
    final row = ChatActivityStatus(
      label: segment.label,
      active: segment.pending,
    );
    final tooltip = segment.tooltip;
    return ChatParity(
      'chat.watch',
      child: tooltip == null || tooltip.isEmpty
          ? row
          : SimTooltip(message: tooltip, child: row),
    );
  }
}
