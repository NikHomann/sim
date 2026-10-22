import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/markdown/chat_sanitize.dart';
import 'package:sim_app/features/chat/messages/markdown/markdown_repair.dart';
import 'package:sim_app/features/chat/messages/markdown/markdown_view.dart';
import 'package:sim_app/features/chat/messages/markdown/special_tags.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/streaming/smooth_text.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_app/features/chat/messages/widgets/interactions.dart';
import 'package:sim_design/sim_design.dart';

/// `ChatContent` (`chat-content.tsx`): one text segment, sanitised, paced
/// while it streams (`useSmoothText`), parsed for special tags, and laid out
/// as a `space-y-4` stack of inline markdown groups and block tags. Newly
/// revealed words fade in over 220 ms (off after 6000 revealed chars and
/// whenever motion is off).
class ChatTextContent extends StatefulWidget {
  const ChatTextContent({
    required this.segment,
    this.messageId,
    this.questionAnswers,
    this.credentialRecap,
    this.onRevealingChanged,
    this.onPaintingChanged,
    this.onPendingTagChanged,
    super.key,
  });

  final ChatTextSegment segment;
  final String? messageId;
  final List<String>? questionAnswers;
  final List<ChatCredentialRecapItem>? credentialRecap;

  /// Streaming or still draining the paced backlog (`onRevealStateChange`).
  final ValueChanged<bool>? onRevealingChanged;

  /// Text is visibly painting (`onStreamActivityChange`).
  final ValueChanged<bool>? onPaintingChanged;

  /// A special tag is mid-stream (`onPendingTagChange`).
  final ValueChanged<bool>? onPendingTagChanged;

  static const Duration fadeDuration = Duration(milliseconds: 220);
  static const int fadeMaxRevealedChars = 6000;

  @override
  State<ChatTextContent> createState() => _ChatTextContentState();
}

class _FadeChunk {
  _FadeChunk(this.sourceStart, this.startedAt);

  final int sourceStart;
  final DateTime startedAt;
}

class _ChatTextContentState extends State<ChatTextContent>
    with SingleTickerProviderStateMixin {
  late String _display = sanitizeChatDisplayContent(widget.segment.content);
  late final SmoothTextPacer _pacer = SmoothTextPacer(
    content: _display,
    streaming: _paced,
  );
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  late bool _streamedThisSession = widget.segment.streaming;
  bool _fadeCutoff = false;
  final List<_FadeChunk> _chunks = <_FadeChunk>[];
  int _snapEpoch = SmoothTextSnap.epoch.value;

  bool? _reportedRevealing;
  bool? _reportedPainting;
  bool? _reportedPending;

  bool get _paced => widget.segment.streaming && !SimMotion.disabled;
  bool get _revealing => widget.segment.streaming || _pacer.hasBacklog;

  @override
  void initState() {
    super.initState();
    SmoothTextSnap.epoch.addListener(_onSnap);
    _arm();
  }

  @override
  void didUpdateWidget(ChatTextContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final display = sanitizeChatDisplayContent(widget.segment.content);
    if (display != _display &&
        !display.startsWith(_display) &&
        !_revealing &&
        _streamedThisSession) {
      // Replaced (not appended) content after settle re-arms the latches.
      _streamedThisSession = false;
      _fadeCutoff = false;
      _chunks.clear();
    }
    _display = display;
    if (widget.segment.streaming) _streamedThisSession = true;
    _pacer.update(display, streaming: _paced);
    if (SimMotion.disabled) _pacer.snap();
    _arm();
  }

  void _onSnap() {
    if (SmoothTextSnap.epoch.value == _snapEpoch) return;
    _snapEpoch = SmoothTextSnap.epoch.value;
    if (!_pacer.hasBacklog) return;
    setState(_pacer.snap);
  }

  void _arm() {
    if (!_pacer.hasBacklog && _chunks.isEmpty) return;
    final ticker = _ticker ??= createTicker(_onTick);
    if (!ticker.isActive) {
      _lastTick = Duration.zero;
      unawaited(ticker.start());
    }
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _lastTick;
    _lastTick = elapsed;
    final before = _pacer.revealed;
    final changed = _pacer.tick(dt);
    if (changed && _fadeActive) {
      _chunks.add(_FadeChunk(before, clock.now()));
    }
    if (!_fadeCutoff &&
        _pacer.revealed > ChatTextContent.fadeMaxRevealedChars) {
      _fadeCutoff = true;
    }
    final now = clock.now();
    _chunks.removeWhere(
      (chunk) =>
          now.difference(chunk.startedAt) >= ChatTextContent.fadeDuration,
    );
    if (changed || _chunks.isNotEmpty) setState(() {});
    if (!_pacer.hasBacklog && _chunks.isEmpty) {
      _ticker?.stop();
      setState(() {});
    }
  }

  bool get _fadeActive =>
      _streamedThisSession && !_fadeCutoff && !SimMotion.disabled;

  @override
  void dispose() {
    SmoothTextSnap.epoch.removeListener(_onSnap);
    _ticker?.dispose();
    super.dispose();
  }

  void _report(bool pending) {
    final revealing = _revealing;
    final painting = _pacer.hasBacklog;
    if (revealing == _reportedRevealing &&
        painting == _reportedPainting &&
        pending == _reportedPending) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (revealing != _reportedRevealing) {
        _reportedRevealing = revealing;
        widget.onRevealingChanged?.call(revealing);
      }
      if (painting != _reportedPainting) {
        _reportedPainting = painting;
        widget.onPaintingChanged?.call(painting);
      }
      if (pending != _reportedPending) {
        _reportedPending = pending;
        widget.onPendingTagChanged?.call(pending);
      }
    });
  }

  (String, bool, bool)? _layoutKey;
  late bool _pendingTag;
  late List<ChatRenderGroup> _groups;
  late List<String?> _markdown;

  /// Tag parsing, grouping and repair, redone only when the visible text
  /// (not the fade) changed.
  void _layout(String visible, bool revealing) {
    final repair = revealing || _streamedThisSession;
    final key = (visible, revealing, repair);
    if (key == _layoutKey) return;
    _layoutKey = key;
    final parsed = parseSpecialTags(visible, streaming: revealing);
    _pendingTag = parsed.hasPendingTag;
    _groups = buildRenderGroups(parsed.pieces);
    _markdown = <String?>[
      for (final group in _groups)
        if (group is ChatInlineGroup)
          repair ? repairStreamingMarkdown(group.markdown) : group.markdown
        else
          null,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visible = _pacer.visible;
    final revealing = _revealing;
    _layout(visible, revealing);
    _report(_pendingTag && revealing);
    final groups = _groups;
    final lastInline = groups.lastIndexWhere((g) => g is ChatInlineGroup);
    final fade = _chunks.isEmpty
        ? null
        : _ChunkFade(visible: visible, chunks: List<_FadeChunk>.of(_chunks));
    final children = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 16));
      final group = groups[i];
      switch (group) {
        case ChatInlineGroup():
          children.add(
            ChatMarkdown(
              markdown: _markdown[i]!,
              sources: group.sources,
              resources: group.resources,
              fade: i == lastInline ? fade : null,
              streaming: revealing && i == groups.length - 1,
            ),
          );
        case ChatBlockGroup(:final segment):
          children.add(
            ChatBlockSegment(
              segment: segment,
              messageId: widget.messageId,
              questionAnswers: widget.questionAnswers,
              credentialRecap: widget.credentialRecap,
            ),
          );
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return ChatParity(
      'chat.message.assistant.content',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Block-level special segments (question, follow-ups, error, credential,
/// options chips).
class ChatBlockSegment extends StatelessWidget {
  const ChatBlockSegment({
    required this.segment,
    this.messageId,
    this.questionAnswers,
    this.credentialRecap,
    super.key,
  });

  final ChatSegment segment;
  final String? messageId;
  final List<String>? questionAnswers;

  /// A settled credential card renders this recap instead of its rows.
  final List<ChatCredentialRecapItem>? credentialRecap;

  @override
  Widget build(BuildContext context) => switch (segment) {
    ChatQuestionSegment(:final questions) => ChatQuestionCard(
      questions: questions,
      answers: questionAnswers,
      messageId: messageId,
    ),
    ChatFollowUpsSegment(:final options) => ChatFollowUps(options: options),
    ChatOptionsSegment(:final options) => ChatOptionChips(options: options),
    ChatErrorSegment(:final message) => ChatErrorText(message: message),
    ChatCredentialSegment(:final items) => ChatCredentialCard(
      items: items,
      recap: credentialRecap,
    ),
    _ => const SizedBox.shrink(),
  };
}

/// Maps paced-reveal chunks (source offsets) onto rendered characters
/// counted from the end. Markdown syntax is stripped from the chunk text to
/// estimate how many rendered characters it produced.
class _ChunkFade implements ChatTextFade {
  _ChunkFade({required String visible, required List<_FadeChunk> chunks}) {
    final now = clock.now();
    for (final chunk in chunks) {
      final start = math.min(chunk.sourceStart, visible.length);
      final fromEnd = _renderedLength(visible.substring(start));
      final t =
          now.difference(chunk.startedAt).inMicroseconds /
          ChatTextContent.fadeDuration.inMicroseconds;
      _thresholds.add((fromEnd, t.clamp(0.0, 1.0)));
    }
    _thresholds.sort((a, b) => a.$1.compareTo(b.$1));
  }

  /// (characters from the end covered by the chunk, opacity), newest first.
  final List<(int, double)> _thresholds = <(int, double)>[];

  static final RegExp _syntax = RegExp(r'\]\([^)]*\)|[*_~`#>|\[\]]');

  static int _renderedLength(String source) =>
      source.replaceAll(_syntax, '').length;

  @override
  int get fadingChars => _thresholds.isEmpty ? 0 : _thresholds.last.$1;

  @override
  double opacityAt(int fromEnd) {
    for (final (threshold, opacity) in _thresholds) {
      if (fromEnd <= threshold) return opacity;
    }
    return 1;
  }
}
