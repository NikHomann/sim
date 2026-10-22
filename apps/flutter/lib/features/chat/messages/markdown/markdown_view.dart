import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:sim_app/features/chat/messages/markdown/code_block.dart';
import 'package:sim_app/features/chat/messages/markdown/markdown_table.dart';
import 'package:sim_app/features/chat/messages/markdown/special_tags.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_app/features/chat/messages/widgets/chips.dart';
import 'package:sim_design/sim_design.dart';

/// Per-character opacity of the trailing streamed text (Streamdown's
/// `fadeIn` word animation). Indices count rendered text characters from
/// the end of the document.
abstract class ChatTextFade {
  /// Characters from the end that may still be below full opacity.
  int get fadingChars;

  /// Opacity of the character [fromEnd] characters before the end (1-based).
  double opacityAt(int fromEnd);
}

/// Tailwind Typography `prose-base` metrics as overridden by `PROSE_CLASSES`
/// (`chat-content.tsx:90-103`).
abstract final class ChatProse {
  static const double fontSize = 15;
  static const double lineHeight = 25;
  static const double paragraphMargin = 18.75;
  static const double headingTop = 24;
  static const double headingBottom = 12;
  static const double listMargin = 16;
  static const double nestedListMargin = 4;
  static const double listItemMargin = 4;
  static const double listIndent = 20;

  /// prose `ul > li` / `ol > li` `padding-inline-start: 0.375em`.
  static const double listItemPadding = 5.625;
  static const double taskIndent = 24;
  static const double taskGap = 8;
  static const double blockquoteMargin = 16;
  static const double blockquoteParagraph = 8;
  static const double hrMargin = 24;
  static const double tableMargin = 16;
  static const double codeMargin = 24;
  static const double imageMargin = 16;
  static const double imageMaxHeight = 360;

  /// `code` in prose-base: 0.875em of 15px.
  static const double inlineCodeSize = 13.125;

  /// h1..h6: font size and line height.
  static const List<(double, double)> headings = <(double, double)>[
    (36, 40),
    (24, 32),
    (20, 32),
    (16, 24),
    (15, 25),
    (15, 25),
  ];
}

/// One inline markdown group (`div[data-chat-find-content]` + Streamdown):
/// a margin-collapsing column of prose blocks whose first top and last
/// bottom margins are dropped (`[&>:first-child]:mt-0 [&>:last-child]:mb-0`).
///
/// Like Streamdown, the source is split into top-level blocks
/// ([splitChatMarkdownBlocks]) that are parsed and laid out once and reused
/// while the message streams: a delta re-parses and re-lays out only the
/// changed tail block, and the word fade re-renders only the blocks that
/// hold fading characters. Link recognizers and focus nodes live in the
/// state and survive rebuilds, so a tap that straddles a delta still lands.
class ChatMarkdown extends StatefulWidget {
  const ChatMarkdown({
    required this.markdown,
    this.sources = const <ChatSourceView>[],
    this.resources = const <ChatResourceView>[],
    this.fade,
    this.streaming = false,
    super.key,
  });

  final String markdown;
  final List<ChatSourceView> sources;
  final List<ChatResourceView> resources;
  final ChatTextFade? fade;

  /// The source is still growing: fenced code in the tail block is
  /// highlighted throttled and kept out of the highlight cache.
  final bool streaming;

  @override
  State<ChatMarkdown> createState() => _ChatMarkdownState();
}

/// One link's gesture recognizer and keyboard focus node, reused by index
/// across rebuilds of the block that owns it.
class _LinkHandle {
  _LinkHandle() {
    recognizer.onTap = () => open?.call();
  }

  final TapGestureRecognizer recognizer = TapGestureRecognizer();
  final FocusNode focus = FocusNode(debugLabel: 'chat.markdown.link');
  VoidCallback? open;

  void dispose() {
    recognizer.dispose();
    focus.dispose();
  }
}

/// The link handles of one block slot, handed out in document order.
class _LinkPool {
  final List<_LinkHandle> _handles = <_LinkHandle>[];
  int _cursor = 0;

  void begin() => _cursor = 0;

  _LinkHandle take(VoidCallback open) {
    if (_cursor == _handles.length) _handles.add(_LinkHandle());
    return _handles[_cursor++]..open = open;
  }

  /// Disposes the handles the last render did not use.
  void end() {
    while (_handles.length > _cursor) {
      _handles.removeLast().dispose();
    }
  }

  void dispose() {
    _cursor = 0;
    end();
  }
}

/// A parsed top-level block and its cached layout.
class _Chunk {
  _Chunk(this.source, this.pool) : nodes = parseChatMarkdown(source) {
    chars = _countChars(nodes);
  }

  final String source;
  final List<md.Node> nodes;
  final _LinkPool pool;
  late final int chars;

  /// Layout without fade; null when it must be (re)built.
  List<_Block>? blocks;
  bool blocksLive = false;
}

class _ChatMarkdownState extends State<ChatMarkdown> {
  String? _source;
  List<_Chunk> _chunks = const <_Chunk>[];
  SimTheme? _theme;
  ChatMessageCallbacks? _callbacks;
  List<ChatSourceView> _sources = const <ChatSourceView>[];
  List<ChatResourceView> _resources = const <ChatResourceView>[];

  @override
  void dispose() {
    for (final chunk in _chunks) {
      chunk.pool.dispose();
    }
    super.dispose();
  }

  void _sync() {
    final source = widget.markdown;
    if (source == _source) return;
    _source = source;
    final old = _chunks;
    final parts = splitChatMarkdownBlocks(source);
    _chunks = <_Chunk>[
      for (var i = 0; i < parts.length; i++)
        if (i < old.length && old[i].source == parts[i])
          old[i]
        else
          _Chunk(parts[i], i < old.length ? old[i].pool : _LinkPool()),
    ];
    for (var i = parts.length; i < old.length; i++) {
      old[i].pool.dispose();
    }
  }

  /// Cached layouts depend on the theme, the callbacks and the chip data.
  void _invalidateOnDependencies(SimTheme theme, ChatMessageCallbacks cb) {
    if (identical(theme, _theme) &&
        cb == _callbacks &&
        listEquals(widget.sources, _sources) &&
        listEquals(widget.resources, _resources)) {
      return;
    }
    _theme = theme;
    _callbacks = cb;
    _sources = widget.sources;
    _resources = widget.resources;
    for (final chunk in _chunks) {
      chunk.blocks = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    _invalidateOnDependencies(SimTheme.of(context), ChatScope.of(context));
    final fade = widget.fade;
    final total = _chunks.fold<int>(0, (sum, c) => sum + c.chars);
    final blocks = <_Block>[];
    var start = 0;
    for (var i = 0; i < _chunks.length; i++) {
      final chunk = _chunks[i];
      final live = widget.streaming && i == _chunks.length - 1;
      final fading =
          fade != null && total - (start + chunk.chars) < fade.fadingChars;
      var laidOut = fading ? null : chunk.blocks;
      if (laidOut == null || chunk.blocksLive != live) {
        chunk.pool.begin();
        laidOut = _MarkdownBuilder(
          context: context,
          sources: widget.sources,
          resources: widget.resources,
          fade: fading ? fade : null,
          links: chunk.pool,
          start: start,
          total: total,
          live: live,
        ).blocks(chunk.nodes);
        chunk.pool.end();
        chunk
          ..blocks = fading ? null : laidOut
          ..blocksLive = live;
      }
      blocks.addAll(laidOut);
      start += chunk.chars;
    }
    return ChatParity(
      'chat.markdown',
      child: _stack(blocks).widget,
    );
  }
}

/// Test probe: receives the source of every markdown parse.
@visibleForTesting
ValueChanged<String>? debugOnChatMarkdownParse;

/// GFM parse with raw HTML kept as literal text.
List<md.Node> parseChatMarkdown(String markdown) {
  debugOnChatMarkdownParse?.call(markdown);
  return md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ).parseLines(const LineSplitter().convert(markdown));
}

final RegExp _fenceLine = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');
final RegExp _definitionLine = RegExp(r'^ {0,3}\[[^\]]+\]:');
final RegExp _listMarker = RegExp(r'^ {0,3}(?:[-*+]|\d{1,9}[.)])(?:[ \t]|$)');
final RegExp _htmlStart = RegExp('^ {0,3}<');

/// Splits [markdown] into top-level blocks that parse the same on their own
/// as inside the whole document (Streamdown's `parseMarkdownIntoBlocks`).
/// It only splits at a blank line outside a fence followed by an unindented
/// line, and conservatively keeps together list items, HTML blocks and
/// anything after them; documents with link or footnote definitions (which
/// resolve document-wide) stay whole.
List<String> splitChatMarkdownBlocks(String markdown) {
  final lines = const LineSplitter().convert(markdown);
  if (lines.any(_definitionLine.hasMatch)) return <String>[markdown];
  final chunks = <String>[];
  var current = <String>[];
  var blanks = 0;
  var hasList = false;
  var hasHtml = false;
  String? fence;
  for (final line in lines) {
    if (fence != null) {
      current.add(line);
      final match = _fenceLine.firstMatch(line);
      if (match != null &&
          match.group(1)![0] == fence[0] &&
          match.group(1)!.length >= fence.length &&
          match.group(2)!.trim().isEmpty) {
        fence = null;
      }
      continue;
    }
    if (line.trim().isEmpty) {
      if (current.isNotEmpty) blanks++;
      continue;
    }
    if (blanks > 0) {
      final continues =
          line.startsWith(' ') ||
          line.startsWith('\t') ||
          hasHtml ||
          _htmlStart.hasMatch(line) ||
          (hasList && _listMarker.hasMatch(line));
      if (continues) {
        current.addAll(List<String>.filled(blanks, ''));
      } else {
        chunks.add(current.join('\n'));
        current = <String>[];
        hasList = false;
      }
      blanks = 0;
    }
    if (_listMarker.hasMatch(line)) hasList = true;
    if (_htmlStart.hasMatch(line)) hasHtml = true;
    final match = _fenceLine.firstMatch(line);
    // A backtick fence's info string cannot contain a backtick.
    if (match != null &&
        !(match.group(1)![0] == '`' && match[2]!.contains('`'))) {
      fence = match.group(1);
    }
    current.add(line);
  }
  if (current.isNotEmpty) chunks.add(current.join('\n'));
  return chunks;
}

/// A laid-out block and its CSS vertical margins.
class _Block {
  const _Block(this.widget, {this.top = 0, this.bottom = 0});

  final Widget widget;
  final double top;
  final double bottom;
}

/// Stacks [blocks] collapsing adjacent margins (max of the pair) and lifts
/// the first top / last bottom margin out for the parent to collapse.
_Block _stack(List<_Block> blocks) {
  if (blocks.isEmpty) return const _Block(SizedBox.shrink());
  if (blocks.length == 1) return blocks.single;
  final children = <Widget>[];
  for (var i = 0; i < blocks.length; i++) {
    if (i > 0) {
      final gap = math.max(blocks[i - 1].bottom, blocks[i].top);
      if (gap > 0) children.add(SizedBox(height: gap));
    }
    children.add(blocks[i].widget);
  }
  return _Block(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    ),
    top: blocks.first.top,
    bottom: blocks.last.bottom,
  );
}

const Set<String> _blockTags = <String>{
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'li',
  'blockquote',
  'pre',
  'table',
  'hr',
  'section',
  'div',
};

bool _isBlock(md.Node node) =>
    node is md.Element && _blockTags.contains(node.tag);

/// Visible inline characters (fenced code excluded), the fade's index space.
int _countChars(List<md.Node> nodes) {
  var count = 0;
  for (final node in nodes) {
    if (node is md.Text) {
      count += node.text.length;
    } else if (node is md.Element && node.tag == 'br') {
      count += 1;
    } else if (node is md.Element && node.tag != 'pre') {
      count += _countChars(node.children ?? const <md.Node>[]);
    }
  }
  return count;
}

class _MarkdownBuilder {
  _MarkdownBuilder({
    required this.context,
    required this.sources,
    required this.resources,
    required this.fade,
    required this.links,
    required int start,
    required this.total,
    required this.live,
  }) : sim = SimTheme.of(context),
       callbacks = ChatScope.of(context),
       _index = start;

  final BuildContext context;
  final List<ChatSourceView> sources;
  final List<ChatResourceView> resources;
  final ChatTextFade? fade;
  final _LinkPool links;
  final int total;

  /// Fenced code here may still be growing.
  final bool live;
  final SimTheme sim;
  final ChatMessageCallbacks callbacks;

  /// Rendered characters before the next run (the fade's index space).
  int _index;

  SimColors get c => sim.colors;

  /// Inside a blockquote every run is italic.
  bool _italic = false;

  TextStyle get _body {
    final style = ChatText.inter(
      context,
      ChatProse.fontSize,
      lineHeight: ChatProse.lineHeight,
      color: c.textPrimary,
    );
    return _italic ? style.copyWith(fontStyle: FontStyle.italic) : style;
  }

  List<_Block> blocks(List<md.Node> nodes, {_Context ctx = _Context.root}) {
    final result = <_Block>[];
    final inline = <md.Node>[];
    void flushInline() {
      if (inline.isEmpty) return;
      final nodes = List<md.Node>.of(inline);
      inline.clear();
      if (nodes.every((n) => n is md.Text && n.text.trim().isEmpty)) return;
      result.add(_Block(_paragraphText(nodes, _body)));
    }

    for (final node in nodes) {
      if (_isBlock(node)) {
        flushInline();
        final block = _block(node as md.Element, ctx);
        if (block != null) result.add(block);
      } else {
        inline.add(node);
      }
    }
    flushInline();
    return result;
  }

  Widget _paragraphText(List<md.Node> nodes, TextStyle style) => Text.rich(
    TextSpan(style: style, children: _inlines(nodes, style)),
  );

  _Block? _block(md.Element el, _Context ctx) {
    final children = el.children ?? const <md.Node>[];
    switch (el.tag) {
      case 'p':
        final image = _soleImage(el);
        if (image != null) return _imageBlock(image);
        final margin = switch (ctx) {
          _Context.listItem => 0.0,
          _Context.blockquote => ChatProse.blockquoteParagraph,
          _Context.root => ChatProse.paragraphMargin,
        };
        return _Block(
          ChatParity('chat.markdown.p', child: _paragraphText(children, _body)),
          top: margin,
          bottom: margin,
        );
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final level = int.parse(el.tag.substring(1));
        final (size, height) = ChatProse.headings[level - 1];
        final style = ChatText.inter(
          context,
          size,
          lineHeight: height,
          weight: SimTextStyles.semibold,
          color: c.textPrimary,
        );
        return _Block(
          ChatParity(
            'chat.markdown.${el.tag}',
            child: _paragraphText(children, style),
          ),
          top: ChatProse.headingTop,
          bottom: ChatProse.headingBottom,
        );
      case 'ul' || 'ol':
        return _list(el, nested: ctx == _Context.listItem);
      case 'blockquote':
        final wasItalic = _italic;
        _italic = true;
        final inner = blocks(children, ctx: _Context.blockquote);
        _italic = wasItalic;
        // `[&>p:first-child]:mt-0 [&>p:last-child]:mb-0`.
        final column = _stack(inner);
        return _Block(
          ChatParity(
            'chat.markdown.blockquote',
            child: Container(
              padding: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: c.border, width: 2)),
              ),
              child: column.widget,
            ),
          ),
          top: ChatProse.blockquoteMargin,
          bottom: ChatProse.blockquoteMargin,
        );
      case 'hr':
        return _Block(
          ChatParity(
            'chat.markdown.hr',
            child: Container(height: 1, color: c.border),
          ),
          top: ChatProse.hrMargin,
          bottom: ChatProse.hrMargin,
        );
      case 'pre':
        final code = children.whereType<md.Element>().firstOrNull;
        final text = (code ?? el).textContent;
        final languageClass = code?.attributes['class'] ?? '';
        final language =
            RegExp(r'language-(\w+)').firstMatch(languageClass)?.group(1) ?? '';
        return _Block(
          ChatCodeBlock(code: text, language: language, live: live),
          top: ChatProse.codeMargin,
          bottom: ChatProse.codeMargin,
        );
      case 'table':
        return _table(el);
      case 'li':
        return _Block(_stack(blocks(children, ctx: _Context.listItem)).widget);
      default:
        final inner = _stack(blocks(children, ctx: ctx));
        return inner;
    }
  }

  md.Element? _soleImage(md.Element p) {
    final nodes = (p.children ?? const <md.Node>[])
        .where((n) => !(n is md.Text && n.text.trim().isEmpty))
        .toList();
    if (nodes.length == 1 && nodes.single is md.Element) {
      final el = nodes.single as md.Element;
      if (el.tag == 'img') return el;
    }
    return null;
  }

  String? _imageSrc(md.Element img) {
    final src = img.attributes['src'] ?? '';
    if (src.isEmpty) return null;
    if (RegExp('^(https?:|data:)').hasMatch(src)) return src;
    return callbacks.resolveImageUrl?.call(src);
  }

  _Block? _imageBlock(md.Element img) {
    final src = _imageSrc(img);
    if (src == null) return null;
    return _Block(
      ChatMarkdownImage(src: src, alt: img.attributes['alt'] ?? ''),
      top: ChatProse.imageMargin,
      bottom: ChatProse.imageMargin,
    );
  }

  _Block _list(md.Element el, {required bool nested}) {
    final ordered = el.tag == 'ol';
    final isTaskList = (el.attributes['class'] ?? '').contains(
      'contains-task-list',
    );
    final start = int.tryParse(el.attributes['start'] ?? '') ?? 1;
    final items = (el.children ?? const <md.Node>[])
        .whereType<md.Element>()
        .toList();
    final rows = <_Block>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isTask = (item.attributes['class'] ?? '').contains(
        'task-list-item',
      );
      final content = _stack(
        blocks(item.children ?? const <md.Node>[], ctx: _Context.listItem),
      );
      Widget row;
      if (isTask) {
        row = content.widget;
      } else {
        final marker = ordered ? '${start + i}.' : '•';
        row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: ChatProse.listIndent + ChatProse.listItemPadding,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: ChatProse.listItemPadding + 4,
                ),
                child: Text(
                  marker,
                  textAlign: TextAlign.right,
                  style: _body,
                ),
              ),
            ),
            Expanded(child: content.widget),
          ],
        );
      }
      // `space-y-2` on task lists replaces the item margins.
      final margin = isTaskList ? 4.0 : ChatProse.listItemMargin;
      rows.add(
        _Block(
          ChatParity('chat.markdown.li', child: row),
          top: math.max(margin, content.top),
          bottom: math.max(margin, content.bottom),
        ),
      );
    }
    final stacked = _stack(rows);
    final margin = nested ? ChatProse.nestedListMargin : ChatProse.listMargin;
    return _Block(
      ChatParity(
        isTaskList
            ? 'chat.markdown.taskList'
            : (ordered ? 'chat.markdown.ol' : 'chat.markdown.ul'),
        child: stacked.widget,
      ),
      top: math.max(margin, stacked.top),
      bottom: math.max(margin, stacked.bottom),
    );
  }

  _Block _table(md.Element el) {
    final style = ChatText.inter(
      context,
      14,
      lineHeight: 24,
      color: c.textPrimary,
    );
    final headStyle = SimTextStyles.weight(style, SimTextStyles.semibold);
    TextAlign align(md.Element cell) => switch (cell.attributes['align']) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
    List<md.Element> rowsOf(String section) => <md.Element>[
      for (final part
          in (el.children ?? const <md.Node>[]).whereType<md.Element>())
        if (part.tag == section)
          ...(part.children ?? const <md.Node>[]).whereType<md.Element>(),
    ];
    final headRow = rowsOf('thead').firstOrNull;
    final header = <ChatTableCell>[
      for (final cell
          in (headRow?.children ?? const <md.Node>[]).whereType<md.Element>())
        ChatTableCell(
          TextSpan(
            style: headStyle,
            children: _inlines(cell.children ?? const <md.Node>[], headStyle),
          ),
          align: align(cell),
        ),
    ];
    final rows = <List<ChatTableCell>>[
      for (final row in rowsOf('tbody'))
        <ChatTableCell>[
          for (final cell
              in (row.children ?? const <md.Node>[]).whereType<md.Element>())
            ChatTableCell(
              TextSpan(
                style: style,
                children: _inlines(cell.children ?? const <md.Node>[], style),
              ),
              align: align(cell),
            ),
        ],
    ];
    return _Block(
      ChatMarkdownTable(header: header, rows: rows),
      top: ChatProse.tableMargin,
      bottom: ChatProse.tableMargin,
    );
  }

  TextStyle _faded(TextStyle style, double opacity) {
    final color = style.color ?? c.textPrimary;
    return style.copyWith(color: color.withValues(alpha: color.a * opacity));
  }

  /// Parity id of the runs being emitted (`chat.markdown.strong`, links).
  String? _spanId;

  /// The link the runs being emitted belong to.
  _LinkHandle? _link;

  /// Text with the streaming fade applied to its trailing characters.
  List<InlineSpan> _text(String text, TextStyle style) {
    final start = _index;
    _index += text.length;
    final fade = this.fade;
    final link = _link;
    TextSpan run(String text, TextStyle style) => TextSpan(
      text: text,
      style: style,
      recognizer: link?.recognizer,
      mouseCursor: link == null ? null : SystemMouseCursors.click,
      semanticsIdentifier: _spanId,
    );
    if (fade == null || total - _index >= fade.fadingChars) {
      return <InlineSpan>[run(text, style)];
    }
    final spans = <InlineSpan>[];
    var runStart = 0;
    double? runOpacity;
    for (var i = 0; i <= text.length; i++) {
      final opacity = i < text.length
          ? fade.opacityAt(total - (start + i))
          : -1.0;
      if (runOpacity != null && opacity != runOpacity) {
        spans.add(
          run(
            text.substring(runStart, i),
            runOpacity >= 1 ? style : _faded(style, runOpacity),
          ),
        );
        runStart = i;
      }
      runOpacity = opacity;
    }
    return spans;
  }

  List<InlineSpan> _inlines(List<md.Node> nodes, TextStyle style) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is md.Text) {
        spans.addAll(_text(node.text, style));
      } else if (node is md.Element) {
        spans.addAll(_inlineElement(node, style));
      }
    }
    return spans;
  }

  List<InlineSpan> _inlineElement(md.Element el, TextStyle style) {
    final children = el.children ?? const <md.Node>[];
    switch (el.tag) {
      case 'strong' || 'b':
        final outer = _spanId;
        _spanId ??= 'chat.markdown.strong';
        final spans = _inlines(
          children,
          SimTextStyles.weight(style, SimTextStyles.semibold),
        );
        _spanId = outer;
        return spans;
      case 'em' || 'i':
        return _inlines(children, style.copyWith(fontStyle: FontStyle.italic));
      case 'del' || 's':
        return _inlines(
          children,
          style.copyWith(
            decoration: TextDecoration.lineThrough,
            decorationColor: c.textTertiary,
            color: c.textTertiary,
          ),
        );
      case 'br':
        _index += 1;
        return const <InlineSpan>[TextSpan(text: '\n')];
      case 'code':
        return <InlineSpan>[_inlineCode(el.textContent, style)];
      case 'a':
        // A link nested in a link (autolink inside a label) is plain text.
        if (_link != null) return _inlines(children, style);
        return _anchor(el, style);
      case 'img':
        final src = _imageSrc(el);
        if (src == null) return const <InlineSpan>[];
        return <InlineSpan>[
          WidgetSpan(
            child: ChatMarkdownImage(src: src, alt: el.attributes['alt'] ?? ''),
          ),
        ];
      case 'input':
        final checked = el.attributes['checked'] == 'true';
        return <InlineSpan>[
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: ChatProse.taskGap),
              child: _TaskCheckbox(checked: checked),
            ),
          ),
        ];
      case 'sup':
        return _inlines(
          children,
          style.copyWith(fontSize: (style.fontSize ?? 15) * 0.75),
        );
      default:
        return _inlines(children, style);
    }
  }

  InlineSpan _inlineCode(String text, TextStyle style) {
    final size = ChatProse.inlineCodeSize * ((style.fontSize ?? 15) / 15);
    final faded =
        fade != null && total - (_index + text.length) < fade!.fadingChars
        ? fade!.opacityAt(math.max(1, total - _index))
        : 1.0;
    _index += text.length;
    final codeStyle = ChatText.mono(
      size,
      color: style.color ?? c.textPrimary,
    ).copyWith(fontStyle: FontStyle.normal);
    Widget chip = ChatParity(
      'chat.markdown.inlineCode',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: chatChipFill(c),
          borderRadius: BorderRadius.circular(SimRadii.sm),
        ),
        child: Text(text, style: codeStyle),
      ),
    );
    final link = _link;
    if (link != null) {
      // Code inside a link label feeds the link's own recognizer.
      chip = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Listener(
          onPointerDown: link.recognizer.addPointer,
          behavior: HitTestBehavior.opaque,
          child: chip,
        ),
      );
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Opacity(opacity: faded, child: chip),
    );
  }

  List<InlineSpan> _anchor(md.Element el, TextStyle style) {
    final href = el.attributes['href'] ?? '';
    final children = el.children ?? const <md.Node>[];
    if (href.startsWith(sourceLinkPrefix)) {
      final index = int.tryParse(href.substring(sourceLinkPrefix.length));
      final source = index != null && index < sources.length
          ? sources[index]
          : null;
      if (source == null) return _inlines(children, style);
      _index += el.textContent.length;
      return <InlineSpan>[
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ChatSourceChip(source: source),
        ),
      ];
    }
    if (href.startsWith(workspaceLinkPrefix)) {
      final index = int.tryParse(href.substring(workspaceLinkPrefix.length));
      final resource = index != null && index < resources.length
          ? resources[index]
          : null;
      if (resource == null) return _inlines(children, style);
      _index += el.textContent.length;
      final select = callbacks.onResourceSelect;
      return <InlineSpan>[
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ChatResourceChip(
            kind: resource.kind,
            title: resource.displayTitle,
            onSelect: select == null ? null : () => select(resource),
          ),
        ),
      ];
    }
    final linkStyle = style.copyWith(color: c.brandBlue);
    final external =
        RegExp('^https?://', caseSensitive: false).hasMatch(href) &&
        (Uri.tryParse(href)?.host.isNotEmpty ?? false);
    final open = callbacks.onOpenLink;
    if (open == null) {
      final outer = _spanId;
      _spanId = external ? 'chat.markdown.link.external' : 'chat.markdown.link';
      final spans = <InlineSpan>[
        if (external) _favicon(href),
        ..._inlines(children, linkStyle),
      ];
      _spanId = outer;
      return spans;
    }
    final link = links.take(() => open(href));
    final outer = _spanId;
    _spanId = external ? 'chat.markdown.link.external' : 'chat.markdown.link';
    _link = link;
    final label = _inlines(children, linkStyle);
    _link = null;
    _spanId = outer;
    return <InlineSpan>[
      if (external) _favicon(href),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _LinkFocus(
          link: link,
          length: TextSpan(children: label).toPlainText().length,
        ),
      ),
      ...label,
    ];
  }

  InlineSpan _favicon(String href) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChatSourceIcon(url: href),
    ),
  );
}

/// Keyboard focus target of one inline link: a zero-size placeholder right
/// before the label that takes Tab focus, opens the link on Enter and, while
/// focused in keyboard mode, outlines the label's text boxes with a 2px
/// `--text-primary` ring (`focus-visible:outline-2`).
class _LinkFocus extends StatefulWidget {
  const _LinkFocus({required this.link, required this.length});

  final _LinkHandle link;

  /// Label length in the paragraph's text (placeholders count one).
  final int length;

  @override
  State<_LinkFocus> createState() => _LinkFocusState();
}

class _LinkFocusState extends State<_LinkFocus> {
  bool _focused = false;
  FocusHighlightMode _mode = FocusManager.instance.highlightMode;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onMode);
    super.dispose();
  }

  void _onMode(FocusHighlightMode mode) {
    if (mounted && mode != _mode) setState(() => _mode = mode);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      widget.link.open?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: widget.link.focus,
    // The label's TextSpan already is the semantic link (tap action).
    includeSemantics: false,
    onKeyEvent: _onKey,
    onFocusChange: (focused) => setState(() => _focused = focused),
    child: _LinkOutline(
      length: widget.length,
      visible: _focused && _mode == FocusHighlightMode.traditional,
      color: SimTheme.of(context).colors.textPrimary,
    ),
  );
}

class _LinkOutline extends LeafRenderObjectWidget {
  const _LinkOutline({
    required this.length,
    required this.visible,
    required this.color,
  });

  final int length;
  final bool visible;
  final Color color;

  @override
  _RenderLinkOutline createRenderObject(BuildContext context) =>
      _RenderLinkOutline()
        ..length = length
        ..visible = visible
        ..color = color;

  @override
  void updateRenderObject(BuildContext context, _RenderLinkOutline r) => r
    ..length = length
    ..visible = visible
    ..color = color;
}

/// Zero-size placeholder that paints the outline around the [length]
/// characters following it in its parent paragraph.
class _RenderLinkOutline extends RenderBox {
  int _length = 0;
  int get length => _length;
  set length(int value) {
    if (value == _length) return;
    _length = value;
    markNeedsPaint();
  }

  bool _visible = false;
  bool get visible => _visible;
  set visible(bool value) {
    if (value == _visible) return;
    _visible = value;
    markNeedsPaint();
  }

  Color _color = const Color(0xFF000000);
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  /// Text offset just after the placeholder [slot] in [paragraph].
  int? _offsetIn(RenderParagraph paragraph, RenderBox slot) {
    var index = 0;
    for (var child = paragraph.firstChild; child != null;) {
      if (identical(child, slot)) break;
      index++;
      child = paragraph.childAfter(child);
    }
    var offset = 0;
    var placeholder = 0;
    int? found;
    paragraph.text.visitChildren((span) {
      if (span is PlaceholderSpan) {
        offset += 1;
        if (placeholder++ == index) {
          found = offset;
          return false;
        }
      } else if (span is TextSpan) {
        offset += span.text?.length ?? 0;
      }
      return true;
    });
    return found;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_visible || _length == 0) return;
    // The paragraph wraps each placeholder in its own semantics box.
    RenderObject slot = this;
    var paragraph = parent;
    while (paragraph != null && paragraph is! RenderParagraph) {
      slot = paragraph;
      paragraph = paragraph.parent;
    }
    if (paragraph is! RenderParagraph || slot is! RenderBox) return;
    final start = _offsetIn(paragraph, slot);
    final data = slot.parentData;
    if (start == null || data is! TextParentData || data.offset == null) {
      return;
    }
    final origin = offset - data.offset!;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _color;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + _length),
    );
    for (final box in boxes) {
      context.canvas.drawRect(
        box.toRect().shift(origin).inflate(1),
        paint,
      );
    }
  }
}

enum _Context { root, listItem, blockquote }

/// Disabled emcn `Checkbox size=sm` (14px, 4px radius).
class _TaskCheckbox extends StatelessWidget {
  const _TaskCheckbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return Opacity(
      opacity: 0.5,
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
    );
  }
}

/// Markdown image (`img` component): max 360px tall, 8px radius, 1px
/// `--border`, zoom cursor; tap opens a lightbox.
class ChatMarkdownImage extends StatelessWidget {
  const ChatMarkdownImage({required this.src, required this.alt, super.key});

  final String src;
  final String alt;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return ChatParity(
      'chat.markdown.image',
      child: Align(
        alignment: Alignment.centerLeft,
        child: SimPressable(
          cursor: SystemMouseCursors.zoomIn,
          semanticsLabel: alt.isEmpty ? 'Preview image' : 'Preview $alt',
          onPressed: () => showDialog<void>(
            context: context,
            barrierColor: const Color(0xCC000000),
            builder: (context) => GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                child: Center(child: Image.network(src, semanticLabel: alt)),
              ),
            ),
          ),
          builder: (context, state) => ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: ChatProse.imageMaxHeight,
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(SimRadii.lg),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(SimRadii.lg - 1),
                child: Image.network(
                  src,
                  fit: BoxFit.contain,
                  semanticLabel: alt,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
