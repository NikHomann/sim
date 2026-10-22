import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/assistant_message.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_app/features/chat/messages/widgets/user_message.dart';
import 'package:sim_design/sim_design.dart';

/// Lets the page jump the transcript to its last row (the user's own send).
class ChatTranscriptController extends ChangeNotifier {
  int _jumps = 0;

  void jumpToBottom() {
    _jumps++;
    notifyListeners();
  }
}

/// Transcript geometry (`mothership-chat.tsx:149-177`, `globals.css:217`).
abstract final class ChatTranscriptMetrics {
  static const double columnMaxWidth = 704;
  static const double desktopBreakpoint = 768;
  static const double paddingXDesktop = 24;
  static const double paddingXMobile = 12;
  static const double paddingTop = 16;
  static const double paddingBottom = 8;
  static const double fadeBand = 16;

  /// `[scrollbar-gutter:stable_both-edges]` reserves Chrome's thin
  /// (`scrollbar-width: thin`, `globals.css`) 10px scrollbar track on both
  /// sides of the scroll box, scrolling or not: the column starts at
  /// 10 + 24 = 34px.
  static const double scrollbarGutter = 10;

  /// `use-auto-scroll.ts`: re-attach within 5px moving down; idle-follow
  /// 800 ms after the stream ends.
  static const double reattachDistance = 5;
  static const Duration settleFollow = Duration(milliseconds: 800);

  /// Overscan: rows stay built ~6 rows beyond the viewport.
  static const double cacheExtent = 6 * 280;
}

/// The chat transcript (`chat.transcript`): a lazily built (virtualised)
/// list centred in a 704px column with 24px side padding (12 below an md
/// viewport) inside the 10px scrollbar gutters,
/// 16px top / 8px bottom padding and 16px top/bottom fades that show only
/// while content hides past that edge. While the last row streams or
/// reveals the view sticks to the bottom; an upward scroll detaches it and
/// a downward scroll within 5px of the bottom re-attaches it. Opening or
/// switching chats (a new [chatId]) and [ChatTranscriptController.jumpToBottom]
/// jump to the last row.
class ChatTranscript extends StatefulWidget {
  const ChatTranscript({
    required this.messages,
    this.chatId,
    this.isLoading = false,
    this.isStreaming = false,
    this.callbacks = const ChatMessageCallbacks(),
    this.controller,
    super.key,
  });

  final List<ChatMessageView> messages;
  final String? chatId;
  final bool isLoading;

  /// The chat's stream is open (`isStreamActive`).
  final bool isStreaming;
  final ChatMessageCallbacks callbacks;
  final ChatTranscriptController? controller;

  @override
  State<ChatTranscript> createState() => _ChatTranscriptState();
}

class _ChatTranscriptState extends State<ChatTranscript>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  Ticker? _chase;
  bool _stuck = true;
  bool _programmatic = false;
  bool _lastRowAnimating = false;
  DateTime? _followUntil;
  Object? _scrolledFor = const Object();
  int _seenJumps = 0;

  bool get _following =>
      widget.isStreaming ||
      _lastRowAnimating ||
      (_followUntil != null && clock.now().isBefore(_followUntil!));

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerJump);
    _scheduleInitialJump();
  }

  @override
  void didUpdateWidget(ChatTranscript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerJump);
      widget.controller?.addListener(_onControllerJump);
    }
    if (oldWidget.isStreaming && !widget.isStreaming) {
      _followUntil = clock.now().add(ChatTranscriptMetrics.settleFollow);
    }
    _scheduleInitialJump();
    _armChase();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerJump);
    _chase?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Once per chat: a pending chat persisting its id (null → id) is the same
  /// conversation and does not re-jump.
  void _scheduleInitialJump() {
    if (widget.messages.isEmpty || _scrolledFor == widget.chatId) return;
    final pendingPersist = _scrolledFor == null && widget.chatId != null;
    _scrolledFor = widget.chatId;
    if (pendingPersist) return;
    _jumpToBottom();
  }

  void _onControllerJump() {
    final jumps = widget.controller?._jumps ?? 0;
    if (jumps == _seenJumps) return;
    _seenJumps = jumps;
    _jumpToBottom();
  }

  /// Lazily built rows only know their extent once laid out, so the jump is
  /// repeated over a few frames until the end is stable.
  void _jumpToBottom([int attempts = 4]) {
    _stuck = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      _programmatic = true;
      _scroll.jumpTo(max);
      _programmatic = false;
      if (attempts > 1) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _scroll.hasClients &&
              _scroll.position.maxScrollExtent != max) {
            _jumpToBottom(attempts - 1);
          }
        });
      }
    });
  }

  void _armChase() {
    if (!_following || !_stuck) return;
    final chase = _chase ??= createTicker(_onChase);
    if (!chase.isActive) unawaited(chase.start());
  }

  void _onChase(Duration _) {
    if (!mounted || !_scroll.hasClients || !_stuck || !_following) {
      _chase?.stop();
      return;
    }
    final position = _scroll.position;
    final gap = position.maxScrollExtent - position.pixels;
    if (gap <= 0.5) return;
    _programmatic = true;
    _scroll.jumpTo(
      SimMotion.disabled
          ? position.maxScrollExtent
          : position.pixels + math.max(1, gap * 0.18),
    );
    _programmatic = false;
  }

  bool _onScroll(ScrollNotification notification) {
    if (_programmatic || notification.depth != 0) return false;
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final m = notification.metrics;
      if (delta < 0) {
        _stuck = false;
      } else if (delta > 0 &&
          m.maxScrollExtent - m.pixels <=
              ChatTranscriptMetrics.reattachDistance) {
        _stuck = true;
        _armChase();
      }
    }
    return false;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && event.scrollDelta.dy < 0) {
      _stuck = false;
    }
  }

  void _onLastRowAnimating(bool animating) {
    if (animating == _lastRowAnimating) return;
    _lastRowAnimating = animating;
    if (!animating) {
      _followUntil = clock.now().add(ChatTranscriptMetrics.settleFollow);
    }
    _armChase();
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return ChatScope(
      callbacks: widget.callbacks,
      child: ChatParity(
        'chat.root',
        child: ChatTextDefaults(
          child: ColoredBox(
            color: c.bg,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // `md:` is a viewport media query, not the column width: a
                // half-width chat beside the resource panel stays desktop.
                final desktop =
                    MediaQuery.sizeOf(context).width >=
                    ChatTranscriptMetrics.desktopBreakpoint;
                final px =
                    (desktop
                        ? ChatTranscriptMetrics.paddingXDesktop
                        : ChatTranscriptMetrics.paddingXMobile) +
                    ChatTranscriptMetrics.scrollbarGutter;
                final messages = widget.messages;
                final columnWidth = math
                    .max(
                      0,
                      math.min(
                        ChatTranscriptMetrics.columnMaxWidth,
                        constraints.maxWidth - 2 * px,
                      ),
                    )
                    .toDouble();
                // The column is centred by equal side insets (>= px).
                final side = (constraints.maxWidth - columnWidth) / 2;
                final padding = EdgeInsets.fromLTRB(
                  side,
                  ChatTranscriptMetrics.paddingTop,
                  side,
                  ChatTranscriptMetrics.paddingBottom,
                );
                final olderCallbacks = widget.callbacks.withoutOptionSelect();
                final Widget list;
                if (widget.isLoading && messages.isEmpty) {
                  list = SingleChildScrollView(
                    padding: padding,
                    child: const ChatParity(
                      'chat.transcript.column',
                      child: ChatSkeleton(),
                    ),
                  );
                } else {
                  list = CustomScrollView(
                    controller: _scroll,
                    cacheExtent: ChatTranscriptMetrics.cacheExtent,
                    semanticChildCount: messages.length,
                    slivers: <Widget>[
                      SliverPadding(
                        padding: padding,
                        sliver: SliverSemantics(
                          container: true,
                          identifier: 'chat.transcript.column',
                          sliver: SliverList.builder(
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isLast = index == messages.length - 1;
                              final row = switch (message) {
                                ChatUserMessageView() => ChatUserMessage(
                                  message: message,
                                  desktop: desktop,
                                ),
                                ChatAssistantMessageView() =>
                                  ChatAssistantMessage(
                                    message: message,
                                    isLast: isLast,
                                    desktop: desktop,
                                    onAnimatingChanged: isLast
                                        ? _onLastRowAnimating
                                        : null,
                                  ),
                              };
                              return KeyedSubtree(
                                key: ValueKey<String>(message.id),
                                child: isLast
                                    ? row
                                    : ChatScope(
                                        callbacks: olderCallbacks,
                                        child: row,
                                      ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return ChatParity(
                  'chat.transcript',
                  child: Listener(
                    onPointerSignal: _onPointerSignal,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: SimScrollFade(
                        band: ChatTranscriptMetrics.fadeBand,
                        child: NotificationListener<ScrollMetricsNotification>(
                          onNotification: (_) {
                            _armChase();
                            return false;
                          },
                          child: list,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
