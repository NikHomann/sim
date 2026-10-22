import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/activity/agent_group.dart';
import 'package:sim_app/features/chat/messages/activity/thinking_loader.dart';
import 'package:sim_app/features/chat/messages/markdown/copy_text.dart';
import 'package:sim_app/features/chat/messages/markdown/special_tags.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/streaming/chat_text_content.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_app/features/chat/messages/widgets/interactions.dart';
import 'package:sim_app/features/chat/messages/widgets/message_actions.dart';
import 'package:sim_app/features/chat/messages/widgets/user_message.dart';
import 'package:sim_design/sim_design.dart';

/// `MessagePhase` (`deriveMessagePhase`).
enum ChatMessagePhase { streaming, revealing, settled }

/// Tail-slot geometry: `mt-[10px] flex h-[36px] items-center` shared by the
/// shimmer and the actions row so the swap never moves layout.
abstract final class ChatTailMetrics {
  static const double gap = 10;
  static const double height = 36;
  static const double segmentGap = 16;
  static const double activityGap = 8;

  /// `STREAM_IDLE_DELAY_MS`.
  static const Duration streamIdle = Duration(milliseconds: 1500);
  static const Duration slotFade = Duration(milliseconds: 200);
}

/// `AssistantMessageRow` + `MessageContent`: the segment stack (16px apart,
/// 8px between consecutive activity rows), then the fixed tail slot holding
/// the Thinking shimmer (last message, not settled) or the actions row
/// (settled), or the "Stopped by user" row; 24px bottom padding (+16 when
/// the turn ends in an interaction card).
class ChatAssistantMessage extends StatefulWidget {
  const ChatAssistantMessage({
    required this.message,
    this.isLast = false,
    this.desktop = true,
    this.onAnimatingChanged,
    super.key,
  });

  final ChatAssistantMessageView message;
  final bool isLast;
  final bool desktop;

  /// The row is streaming or still revealing (drives transcript follow).
  final ValueChanged<bool>? onAnimatingChanged;

  @override
  State<ChatAssistantMessage> createState() => _ChatAssistantMessageState();
}

class _ChatAssistantMessageState extends State<ChatAssistantMessage> {
  bool _trailingRevealing = false;
  bool _trailingPainting = false;
  bool _trailingPendingTag = false;
  bool _idle = false;
  Timer? _idleTimer;
  String? _activityKey;
  ChatMessagePhase? _reportedPhase;

  /// The trailing question the user dismissed (its raw tag is its identity,
  /// so a later question in the same turn is not inherited).
  String? _dismissedQuestion;

  ChatAssistantMessageView get m => widget.message;

  @override
  void initState() {
    super.initState();
    _restartIdle();
  }

  @override
  void didUpdateWidget(ChatAssistantMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _restartIdle();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  /// Every visible stream change restarts the 1500 ms quiet-period clock.
  void _restartIdle() {
    final key = _visibleActivityKey();
    if (!m.isStreaming) {
      _idleTimer?.cancel();
      _idle = false;
      _activityKey = key;
      return;
    }
    if (key == _activityKey && _idleTimer != null) return;
    _activityKey = key;
    _idle = false;
    _idleTimer?.cancel();
    _idleTimer = Timer(ChatTailMetrics.streamIdle, () {
      if (mounted) setState(() => _idle = true);
    });
  }

  String _visibleActivityKey() => m.segments
      .map(
        (s) => switch (s) {
          ChatTextSegment(:final content) => 'text:${content.length}',
          ChatAgentGroupSegment(:final group) => 'group:${_groupKey(group)}',
          ChatToolCallSegment(:final tool) =>
            'tool:${tool.id}:${tool.state.name}:${tool.title}',
          _ => s.runtimeType.toString(),
        },
      )
      .join('|');

  String _groupKey(ChatAgentGroupView g) => g.items
      .map(
        (i) => switch (i) {
          ChatAgentTextItem(:final content) => 't${content.length}',
          ChatAgentToolItem(:final tool) =>
            '${tool.id}:${tool.state.name}:${tool.title}',
          ChatAgentNestedItem(:final group) => '[${_groupKey(group)}]',
        },
      )
      .join(',');

  bool _visible(ChatSegment s) => switch (s) {
    ChatTextSegment(:final content) => content.trim().isNotEmpty,
    ChatAgentGroupSegment(:final group) => group.hasContent,
    ChatOptionsSegment(:final options) => options.isNotEmpty,
    ChatStoppedSegment() => false,
    _ => true,
  };

  static bool _isActivity(ChatSegment s) =>
      s is ChatAgentGroupSegment ||
      s is ChatToolCallSegment ||
      s is ChatWatchSegment;

  String? get _questionKey {
    for (final s in m.segments.reversed) {
      if (s is ChatStoppedSegment) continue;
      if (s is ChatQuestionSegment) return identityHashCode(s).toString();
      if (s is ChatTextSegment) {
        final text = s.content.trim();
        final at = text.lastIndexOf('<question>');
        return at < 0 ? null : text.substring(at);
      }
      return null;
    }
    return null;
  }

  bool get _endsWithQuestion {
    for (final s in m.segments.reversed) {
      if (s is ChatStoppedSegment) continue;
      if (s is ChatQuestionSegment) return true;
      if (s is ChatTextSegment) return s.content.trim().endsWith('</question>');
      return false;
    }
    return false;
  }

  bool get _endsWithCredential {
    for (final s in m.segments.reversed) {
      if (s is ChatStoppedSegment) continue;
      if (s is ChatCredentialSegment) return true;
      if (s is ChatTextSegment) {
        return s.content.trim().endsWith('</credential>');
      }
      return false;
    }
    return false;
  }

  List<String> _pendingPermissionIds() {
    final ids = <String>[];
    void visit(ChatAgentGroupView g) {
      for (final item in g.items) {
        switch (item) {
          case ChatAgentToolItem(:final tool)
              when tool.state == ChatToolState.awaitingApproval:
            ids.add(tool.id);
          case ChatAgentNestedItem(:final group):
            visit(group);
          default:
        }
      }
    }

    for (final s in m.segments) {
      if (s is ChatAgentGroupSegment) visit(s.group);
      if (s is ChatToolCallSegment &&
          s.tool.state == ChatToolState.awaitingApproval) {
        ids.add(s.tool.id);
      }
    }
    return ids;
  }

  Widget _segment(
    ChatSegment segment,
    int index,
    int revealTail,
    List<String> pending,
  ) {
    final streaming = m.isStreaming;
    Widget fadeIn(Widget child) =>
        streaming ? _StreamFadeIn(child: child) : child;
    return switch (segment) {
      ChatTextSegment() => ChatTextContent(
        key: ValueKey<String>(segment.id),
        segment: segment,
        messageId: m.id,
        questionAnswers: m.questionAnswers,
        credentialRecap: m.credentialRecap,
        onRevealingChanged: index == revealTail
            ? (v) => setState(() => _trailingRevealing = v)
            : null,
        onPaintingChanged: index == revealTail
            ? (v) => setState(() => _trailingPainting = v)
            : null,
        onPendingTagChanged: index == revealTail
            ? (v) => setState(() => _trailingPendingTag = v)
            : null,
      ),
      ChatAgentGroupSegment(:final group) => fadeIn(
        ChatAgentGroup(
          key: ValueKey<String>(group.id),
          group: group,
          streaming: streaming,
          outstandingIds: pending,
        ),
      ),
      ChatToolCallSegment(:final tool) => ChatToolCallRow(
        tool: tool,
        outstandingIds: pending,
      ),
      ChatOptionsSegment(:final options) => fadeIn(
        ChatOptionChips(options: options),
      ),
      ChatWatchSegment() => ChatWatchRow(segment: segment),
      ChatStoppedSegment() => const SizedBox.shrink(),
      _ => ChatBlockSegment(
        segment: segment,
        messageId: m.id,
        questionAnswers: m.questionAnswers,
        credentialRecap: m.credentialRecap,
      ),
    };
  }

  void _reportPhase(ChatMessagePhase phase) {
    if (phase == _reportedPhase) return;
    _reportedPhase = phase;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onAnimatingChanged?.call(phase != ChatMessagePhase.settled);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final segments = m.segments;
    final visible = <int>[
      for (var i = 0; i < segments.length; i++)
        if (_visible(segments[i])) i,
    ];
    final last = segments.isEmpty ? null : segments.last;
    final stopped = last is ChatStoppedSegment;
    final revealTail =
        stopped &&
            segments.length >= 2 &&
            segments[segments.length - 2] is ChatTextSegment
        ? segments.length - 2
        : (last is ChatTextSegment ? segments.length - 1 : -1);
    final revealing = revealTail >= 0 && _trailingRevealing;
    final phase = m.isStreaming
        ? ChatMessagePhase.streaming
        : (revealing ? ChatMessagePhase.revealing : ChatMessagePhase.settled);
    _reportPhase(phase);

    if (visible.isEmpty && !m.isStreaming && !widget.isLast) {
      return const SizedBox.shrink();
    }

    final thinkingExpanded = phase != ChatMessagePhase.settled && !stopped;
    final anyLive = segments.any(
      (s) => s is ChatAgentGroupSegment && s.group.isLive,
    );
    final pendingAgents =
        m.isStreaming &&
        segments.any(
          (s) =>
              s is ChatAgentGroupSegment &&
              s.group.items.any(
                (i) => i is ChatAgentToolItem && !i.tool.state.isDone,
              ),
        );
    final showShimmer =
        thinkingExpanded &&
        (visible.isEmpty ||
            _trailingPendingTag ||
            (((pendingAgents && revealTail < 0) || _idle) &&
                !_trailingPainting &&
                !anyLive));

    final endsWithQuestion = _endsWithQuestion;
    final endsWithCredential = _endsWithCredential;
    final dismissed =
        endsWithQuestion &&
        _dismissedQuestion != null &&
        _dismissedQuestion == _questionKey;
    final hasContent = segments.isNotEmpty;
    // `shouldShowAssistantMessageActions`: settled, with content, and not
    // ending in an active question/credential card.
    final actionsEligible =
        phase == ChatMessagePhase.settled &&
        hasContent &&
        (!(endsWithQuestion || endsWithCredential) || dismissed);
    final showsInteractionCard =
        (endsWithQuestion && !dismissed) || endsWithCredential;
    final textSegments = segments.whereType<ChatTextSegment>().map(
      (s) => s.content,
    );
    final sources = collectMessageSources(textSegments);
    final pending = _pendingPermissionIds();

    final stack = <Widget>[];
    for (var k = 0; k < visible.length; k++) {
      final i = visible[k];
      if (k > 0) {
        final prev = segments[visible[k - 1]];
        final cur = segments[i];
        final endsInCard =
            prev is ChatAgentGroupSegment && prev.group.hasPendingPermission;
        stack.add(
          SizedBox(
            height: _isActivity(prev) && _isActivity(cur) && !endsInCard
                ? ChatTailMetrics.activityGap
                : ChatTailMetrics.segmentGap,
          ),
        );
      }
      stack.add(_segment(segments[i], i, revealTail, pending));
    }

    final actions = actionsEligible
        ? ChatMessageActions(
            message: m,
            copyText: messageCopyText(m),
            sources: sources,
            compact: !widget.desktop,
          )
        : null;

    Widget? tail;
    if (thinkingExpanded && widget.isLast) {
      tail = Padding(
        padding: const EdgeInsets.only(top: ChatTailMetrics.gap),
        child: ChatParity(
          'chat.message.tail',
          child: SizedBox(
            height: ChatTailMetrics.height,
            child: ExcludeSemantics(
              excluding: !showShimmer,
              child: AnimatedOpacity(
                duration: SimMotion.of(ChatTailMetrics.slotFade),
                curve: SimMotion.easeOut,
                opacity: showShimmer ? 1 : 0,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: ChatParity(
                    'chat.message.thinking',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ChatThinkingLoader(label: m.thinkingLabel),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else if (stopped) {
      final c = SimTheme.of(context).colors;
      tail = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: ChatTailMetrics.gap),
            child: ChatParity(
              'chat.message.stopped',
              child: Row(
                spacing: 8,
                children: <Widget>[
                  SimIcon(SimEmcnIcons.circleStop, size: 16, color: c.textIcon),
                  Text(
                    'Stopped by user',
                    style: ChatText.inter(
                      context,
                      14,
                      lineHeight: 21,
                      color: c.textBody,
                      tracking: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (actions != null)
            Padding(
              padding: const EdgeInsets.only(top: ChatTailMetrics.gap),
              child: actions,
            ),
        ],
      );
    } else if (actions != null) {
      tail = Padding(
        padding: const EdgeInsets.only(top: ChatTailMetrics.gap),
        child: ChatParity(
          'chat.message.tail',
          child: SizedBox(
            height: ChatTailMetrics.height,
            // Below md the 44px targets overflow the 36px slot, as upstream.
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: actions,
            ),
          ),
        ),
      );
    }

    final callbacks = ChatScope.of(context);
    final resolveMessageImageUrl = callbacks.resolveMessageImageUrl;
    final requestId = m.requestId;
    return ChatScope(
      callbacks: callbacks.copyWith(
        onQuestionDismiss: (id) {
          setState(() => _dismissedQuestion = _questionKey);
          callbacks.onQuestionDismiss?.call(id);
        },
        resolveImageUrl: resolveMessageImageUrl == null
            ? null
            : (src) => resolveMessageImageUrl(src, requestId),
      ),
      child: ChatParity(
        'chat.message.assistant',
        child: Padding(
          padding: EdgeInsets.only(
            bottom: ChatRowMetrics.rowGap + (showsInteractionCard ? 16 : 0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (stack.isNotEmpty)
                ChatParity(
                  'chat.message.assistant.segments',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: stack,
                  ),
                ),
              ?tail,
            ],
          ),
        ),
      ),
    );
  }
}

/// `animate-stream-fade-in`: opacity 0 → 1 over 300 ms ease-out.
class _StreamFadeIn extends StatelessWidget {
  const _StreamFadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: SimMotion.disabled ? 1 : 0, end: 1),
    duration: SimMotion.of(SimMotion.streamFadeIn),
    curve: SimMotion.easeOut,
    builder: (context, opacity, child) =>
        Opacity(opacity: opacity, child: child),
    child: child,
  );
}
