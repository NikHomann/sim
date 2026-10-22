import 'package:flutter/widgets.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/radii.dart';

/// `tableVariants`: the plain table, or the `list` treatment (2px row gaps,
/// no borders, 32px muted caption heads, muted caption cells, rounded rows).
enum SimTableVariant { standard, list }

/// Column sizing: a fixed width or a flex factor.
class SimTableColumn {
  const SimTableColumn({
    this.width,
    this.flex = 1,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final double? width;
  final int flex;
  final AlignmentGeometry alignment;
}

/// One body row.
class SimTableRow {
  const SimTableRow({required this.cells, this.onTap, this.selected = false});

  final List<Widget> cells;
  final VoidCallback? onTap;
  final bool selected;
}

/// Port of `packages/emcn/src/components/table/table.tsx`: text-small table
/// with a bordered header row (h-10, px-3 py-2, `--text-secondary`), bordered
/// body rows (last one open), px-3 py-2 cells, and an optional caption
/// (mt-4, `--text-muted`, text-sm). Scrolls horizontally when wider than its
/// box.
class SimTable extends StatelessWidget {
  const SimTable({
    required this.columns,
    required this.rows,
    super.key,
    this.header,
    this.footer,
    this.caption,
    this.variant = SimTableVariant.standard,
    this.minWidth,
  });

  final List<SimTableColumn> columns;
  final List<SimTableRow> rows;
  final List<Widget>? header;
  final List<Widget>? footer;
  final String? caption;
  final SimTableVariant variant;
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final list = variant == SimTableVariant.list;
    final cellPadding = list
        ? const EdgeInsets.all(8)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    final headStyle = list
        ? sim.text.caption.copyWith(color: c.textMuted)
        : sim.text.small.copyWith(color: c.textSecondary);
    final cellStyle = list
        ? sim.text.caption.copyWith(color: c.textMuted)
        : sim.text.small.copyWith(color: c.textPrimary);
    final border = BorderSide(color: c.border);

    Widget cell(Widget child, int index, TextStyle style, {double? height}) {
      final column = columns[index];
      final content = Container(
        height: height,
        padding: cellPadding,
        alignment: column.alignment,
        child: DefaultTextStyle.merge(style: style, child: child),
      );
      if (column.width != null) {
        return SizedBox(width: column.width, child: content);
      }
      return Expanded(flex: column.flex, child: content);
    }

    Widget rowBox(
      List<Widget> cells, {
      BoxDecoration? decoration,
      double? height,
    }) {
      final row = Row(children: cells);
      return Container(
        decoration: decoration,
        constraints: height == null ? null : BoxConstraints(minHeight: height),
        child: IntrinsicHeight(child: row),
      );
    }

    final children = <Widget>[];
    if (header != null) {
      children.add(
        rowBox(
          <Widget>[
            for (var i = 0; i < header!.length; i++)
              cell(header![i], i, headStyle),
          ],
          decoration: list
              ? null
              : BoxDecoration(border: Border(bottom: border)),
          height: list ? 32 : 40,
        ),
      );
    }
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final last = r == rows.length - 1;
      var built = rowBox(
        <Widget>[
          for (var i = 0; i < row.cells.length; i++)
            cell(row.cells[i], i, cellStyle),
        ],
        decoration: list
            ? BoxDecoration(
                color: row.selected ? c.surfaceActive : null,
                borderRadius: BorderRadius.circular(SimRadii.lg),
              )
            : BoxDecoration(
                color: row.selected ? c.surfaceActive : null,
                border: last ? null : Border(bottom: border),
              ),
      );
      if (row.onTap != null) {
        built = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: row.onTap,
            child: built,
          ),
        );
      }
      if (list && r > 0) children.add(const SizedBox(height: 2));
      children.add(built);
    }
    if (footer != null) {
      children.add(
        rowBox(
          <Widget>[
            for (var i = 0; i < footer!.length; i++)
              cell(footer![i], i, cellStyle),
          ],
          decoration: BoxDecoration(
            color: c.surface3.withValues(alpha: 0.5),
            border: Border(top: border),
          ),
        ),
      );
    }
    Widget table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (minWidth != null) {
      table = ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth!),
        child: table,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (minWidth != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minWidth, child: table),
          )
        else
          table,
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              caption!,
              style: sim.text.sm.copyWith(color: c.textMuted),
            ),
          ),
      ],
    );
  }
}
