import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_design/sim_design.dart';

/// One cell's inline content and GFM alignment.
@immutable
class ChatTableCell {
  const ChatTableCell(this.content, {this.align = TextAlign.left});

  final InlineSpan content;
  final TextAlign align;
}

/// `MarkdownTable` (`chat-content.tsx:284-333`): a full-width horizontally
/// scrolling region with a 16px edge fade at hidden sides; the table is at
/// least the column width (`min-w-full`), columns size to content (extra
/// width shared in proportion to content width, as CSS auto layout does),
/// cells never wrap, th/td are Inter 14/24 with 12 × 8 padding and a 1px
/// `--border` rule under every row but the last.
class ChatMarkdownTable extends StatefulWidget {
  const ChatMarkdownTable({
    required this.header,
    required this.rows,
    super.key,
  });

  final List<ChatTableCell> header;
  final List<List<ChatTableCell>> rows;

  @override
  State<ChatMarkdownTable> createState() => _ChatMarkdownTableState();
}

class _ChatMarkdownTableState extends State<ChatMarkdownTable> {
  bool _overflowing = false;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final columns = widget.header.length;
    Widget cell(ChatTableCell cell, {required bool head, required bool rule}) {
      final style = ChatText.inter(
        context,
        14,
        lineHeight: 24,
        weight: head ? SimTextStyles.semibold : SimTextStyles.regular,
        color: c.textPrimary,
      );
      return ChatParity(
        head ? 'chat.table.th' : 'chat.table.td',
        child: Container(
          // The decoration's 1px rule adds to the padding (41px rows).
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: rule ? Border(bottom: BorderSide(color: c.border)) : null,
          ),
          child: Text.rich(
            TextSpan(style: style, children: <InlineSpan>[cell.content]),
            softWrap: false,
            textAlign: cell.align,
          ),
        ),
      );
    }

    // A rule sits inside each cell's 41px box (40 + 1); the last body row
    // has none and is 40px.
    final cells = <Widget>[
      for (final h in widget.header) cell(h, head: true, rule: true),
      for (var r = 0; r < widget.rows.length; r++)
        for (var col = 0; col < columns; col++)
          cell(
            col < widget.rows[r].length
                ? widget.rows[r][col]
                : const ChatTableCell(TextSpan(text: '')),
            head: false,
            rule: r < widget.rows.length - 1,
          ),
    ];
    final table = LayoutBuilder(
      builder: (context, constraints) => SimScrollFade(
        axis: Axis.horizontal,
        band: 16,
        onEdgesChanged: (edges) {
          final overflowing = edges.start || edges.end;
          if (overflowing != _overflowing) {
            setState(() => _overflowing = overflowing);
          }
        },
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _TableLayout(
            columns: columns,
            minWidth: constraints.maxWidth,
            children: cells,
          ),
        ),
      ),
    );
    return ChatParity(
      'chat.table',
      child: Semantics(
        label: _overflowing ? 'Scrollable table' : null,
        child: _overflowing ? Focus(child: table) : table,
      ),
    );
  }
}

class _TableLayout extends MultiChildRenderObjectWidget {
  const _TableLayout({
    required this.columns,
    required this.minWidth,
    required super.children,
  });

  final int columns;
  final double minWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTableLayout(columns: columns, minWidth: minWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTableLayout renderObject,
  ) {
    renderObject
      ..columns = columns
      ..minWidth = minWidth;
  }
}

class _TableParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTableLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TableParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TableParentData> {
  _RenderTableLayout({required int columns, required double minWidth})
    : _columns = columns,
      _minWidth = minWidth;

  int _columns;
  int get columns => _columns;
  set columns(int value) {
    if (value == _columns) return;
    _columns = value;
    markNeedsLayout();
  }

  double _minWidth;
  double get minWidth => _minWidth;
  set minWidth(double value) {
    if (value == _minWidth) return;
    _minWidth = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TableParentData) {
      child.parentData = _TableParentData();
    }
  }

  List<RenderBox> get _cells {
    final result = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      result.add(child);
      child = childAfter(child);
    }
    return result;
  }

  List<double> _columnWidths() {
    final cells = _cells;
    final widths = List<double>.filled(_columns, 0);
    for (var i = 0; i < cells.length; i++) {
      final col = i % _columns;
      widths[col] = math.max(
        widths[col],
        cells[i].getMaxIntrinsicWidth(double.infinity),
      );
    }
    final total = widths.fold<double>(0, (a, b) => a + b);
    if (total > 0 && total < _minWidth) {
      final scale = _minWidth / total;
      for (var i = 0; i < widths.length; i++) {
        widths[i] *= scale;
      }
    }
    return widths;
  }

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _columnWidths().fold<double>(0, (a, b) => a + b);

  @override
  double computeMinIntrinsicWidth(double height) =>
      computeMaxIntrinsicWidth(height);

  @override
  void performLayout() {
    final cells = _cells;
    if (_columns == 0 || cells.isEmpty) {
      size = constraints.constrain(Size.zero);
      return;
    }
    final widths = _columnWidths();
    final rows = (cells.length / _columns).ceil();
    var y = 0.0;
    for (var r = 0; r < rows; r++) {
      var rowHeight = 0.0;
      for (var col = 0; col < _columns; col++) {
        final index = r * _columns + col;
        if (index >= cells.length) break;
        cells[index].layout(
          BoxConstraints.tightFor(width: widths[col]),
          parentUsesSize: true,
        );
        rowHeight = math.max(rowHeight, cells[index].size.height);
      }
      var x = 0.0;
      for (var col = 0; col < _columns; col++) {
        final index = r * _columns + col;
        if (index >= cells.length) break;
        final cell = cells[index];
        if (cell.size.height != rowHeight) {
          cell.layout(
            BoxConstraints.tightFor(width: widths[col], height: rowHeight),
            parentUsesSize: true,
          );
        }
        (cell.parentData! as _TableParentData).offset = Offset(x, y);
        x += widths[col];
      }
      y += rowHeight;
    }
    size = constraints.constrain(
      Size(widths.fold<double>(0, (a, b) => a + b), y),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
