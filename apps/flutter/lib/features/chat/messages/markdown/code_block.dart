import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/markdown/code_highlight.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_design/sim_design.dart';

/// Fenced code (`code` component, `chat-content.tsx:334-368`): a 1px
/// `--border` frame with 8px radius, a 35px header (language label + copy
/// button) on `--surface-4`, and a Prism-coloured mono 13/21 body on
/// `--surface-5` (dark `--code-bg`) that scrolls horizontally.
///
/// A [live] block (a fence still streaming) is re-highlighted at most every
/// [liveHighlightInterval]; in between, the text appended since the last
/// pass shows uncoloured, and live results stay out of the highlight cache.
class ChatCodeBlock extends StatefulWidget {
  const ChatCodeBlock({
    required this.code,
    required this.language,
    this.live = false,
    super.key,
  });

  /// The raw fence text (copied untrimmed).
  final String code;
  final String language;
  final bool live;

  static const double bodyFontSize = 13;
  static const double bodyLineHeight = 21;
  static const Duration liveHighlightInterval = Duration(milliseconds: 100);

  @override
  State<ChatCodeBlock> createState() => _ChatCodeBlockState();
}

class _ChatCodeBlockState extends State<ChatCodeBlock> {
  String? _highlighted;
  String? _language;
  List<List<ChatCodeToken>> _tokens = const <List<ChatCodeToken>>[];
  DateTime? _highlightedAt;
  Timer? _refresh;

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  List<List<ChatCodeToken>> _lines() {
    final code = widget.code;
    final language = widget.language;
    if (!widget.live) {
      _refresh?.cancel();
      _highlightedAt = null;
      return highlightCode(code, language);
    }
    final source = code.trimRight();
    final previous = _highlighted;
    if (previous != null && _language == language) {
      if (previous == source) return _tokens;
      final elapsed = clock.now().difference(_highlightedAt!);
      if (source.startsWith(previous) &&
          elapsed < ChatCodeBlock.liveHighlightInterval) {
        if (!(_refresh?.isActive ?? false)) {
          _refresh = Timer(
            ChatCodeBlock.liveHighlightInterval - elapsed,
            () => mounted ? setState(() {}) : null,
          );
        }
        return _withPlainTail(source.substring(previous.length));
      }
    }
    _tokens = highlightCode(code, language, cache: false);
    _highlighted = source;
    _language = language;
    _highlightedAt = clock.now();
    return _tokens;
  }

  /// The last highlight plus uncoloured [tail].
  List<List<ChatCodeToken>> _withPlainTail(String tail) {
    final lines = <List<ChatCodeToken>>[
      for (final line in _tokens) line,
    ];
    final parts = tail.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i == 0) {
        lines[lines.length - 1] = <ChatCodeToken>[
          ...lines.last,
          if (parts[i].isNotEmpty) ChatCodeToken(parts[i]),
        ];
      } else {
        lines.add(<ChatCodeToken>[
          if (parts[i].isNotEmpty) ChatCodeToken(parts[i]),
        ]);
      }
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    final language = widget.language;
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final bodyFill = sim.isDark ? c.codeBg : c.surface5;
    final base = ChatText.mono(
      ChatCodeBlock.bodyFontSize,
      lineHeight: ChatCodeBlock.bodyLineHeight,
      color: c.textPrimary,
    );
    if (code.isEmpty) {
      return ChatParity(
        'chat.code',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bodyFill,
            borderRadius: BorderRadius.circular(SimRadii.lg),
          ),
          child: Text('', style: base),
        ),
      );
    }
    final lines = _lines();
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      for (final token in lines[i]) {
        final color = prismTokenColor(token.type, c.brightness);
        spans.add(
          TextSpan(
            text: token.text,
            style: color == null ? null : TextStyle(color: color),
          ),
        );
      }
    }
    return ChatParity(
      'chat.code',
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(SimRadii.lg),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SimRadii.lg - 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ChatParity(
                'chat.code.header',
                child: Container(
                  // `px-4` with the copy button's `-mr-2`.
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: c.surface4,
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ChatParity(
                          'chat.code.lang',
                          child: Text(
                            language.isEmpty ? 'code' : language,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ChatText.inter(
                              context,
                              11,
                              lineHeight: 16.5,
                              color: c.textTertiary,
                              tracking: true,
                            ),
                          ),
                        ),
                      ),
                      _CopyCodeButton(code: code),
                    ],
                  ),
                ),
              ),
              ChatParity(
                'chat.code.body',
                child: ColoredBox(
                  color: bodyFill,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16),
                    child: Text.rich(
                      TextSpan(style: base, children: spans),
                      softWrap: false,
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

/// emcn `CopyCodeButton` (ghost, `px-1.5 py-0.5`, 14px icon → 26 × 18):
/// `Duplicate` → `Check` for 2000 ms; hover `--surface-5` + `--text-secondary`.
class _CopyCodeButton extends StatefulWidget {
  const _CopyCodeButton({required this.code});

  final String code;

  @override
  State<_CopyCodeButton> createState() => _CopyCodeButtonState();
}

class _CopyCodeButtonState extends State<_CopyCodeButton> {
  final ChatCopyState _copied = ChatCopyState(SimMotion.copiedReset);

  @override
  void dispose() {
    _copied.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await ChatScope.of(context).copy(widget.code);
    if (mounted) _copied.copied();
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return ChatParity(
      'chat.code.copy',
      child: ValueListenableBuilder<bool>(
        valueListenable: _copied,
        builder: (context, copied, _) => SimPressable(
          onPressed: _copy,
          semanticsLabel: copied ? 'Copied' : 'Copy code',
          builder: (context, state) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: state.hovered ? c.surface5 : null,
              borderRadius: BorderRadius.circular(SimRadii.sm),
            ),
            child: SimIcon(
              copied ? SimEmcnIcons.check : SimEmcnIcons.duplicate,
              color: state.hovered ? c.textSecondary : c.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
