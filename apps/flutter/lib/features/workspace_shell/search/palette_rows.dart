/// Row chrome of the palette (`command-items.tsx`, `COMMAND_ITEM_CLASSNAME`,
/// `GROUP_HEADING_CLASSNAME`).
library;

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/search/palette_models.dart';
import 'package:sim_app/features/workspace_shell/switcher/identity_tile.dart';
import 'package:sim_design/sim_design.dart';

/// Palette geometry (`command-chrome.tsx`, `utils.ts:273-277`,
/// `sidebar/constants.ts:58-61`).
abstract final class PaletteMetrics {
  static const double maxWidth = 500;
  static const double edgeGutter = 16;
  static const double maxHalfWidth = 250;
  static const double topFraction = 0.15;
  static const double ringPadding = 3;
  static const double listMaxHeight = 448;
  static const double listPaddingX = 6;
  static const double listPaddingTop = 48;
  static const double listPaddingBottom = 6;
  static const double inputBandHeight = 48;
  static const double inputBandInset = 3;

  /// The input band's `gap-2`, and the input's `-ml-1` / `indent-1`
  /// on its `h-8` box.
  static const double inputGap = 8;
  static const double inputIndent = 4;
  static const double inputHeight = 32;

  /// Chrome's advance for `⇥` at `text-xs` (11px, 0.02em tracking) from
  /// the Windows symbol font (Segoe UI Symbol), measured 2026-10-22.
  static const double tabGlyphAdvance = 9.71875;
  static const double groupGap = 16;
  static const double rowGap = 1;
  static const double rowHeight = 30;
  static const double rowMarginX = 2;
  static const double headingHeight = 18;
  static const double headingGap = 8;
  static const double scrollMarginTop = 48;
  static const double scrollMarginBottom = 6;
  static const double clipInset = 3;
  static const double clipRadius = 13;

  /// Height of a group inside the list, including its top gap.
  static double groupExtent(PaletteGroup group, {required bool first}) {
    final n = group.entries.length;
    return (first ? 0 : groupGap) +
        (group.heading == null ? 0 : headingHeight + headingGap) +
        n * rowHeight +
        (n > 0 ? (n - 1) * rowGap : 0);
  }

  /// `ShortcutHint`: 40px, three equal columns.
  static const double shortcutWidth = 40;
}

/// `Date` meta of chats and logs: `Intl.DateTimeFormat('en-US', { month:
/// 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })`, e.g.
/// "Oct 21, 3:05 PM".
String formatPaletteDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '${months[date.month - 1]} ${date.day}, $hour12:$minute $period';
}

/// A group heading: 18px, `px-2`, 8px above the first row, 13px muted.
class PaletteGroupHeading extends StatelessWidget {
  const PaletteGroupHeading({
    required this.text,
    required this.groupKey,
    super.key,
  });

  final String text;
  final String groupKey;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    return Semantics(
      container: true,
      identifier: 'search.palette.group.$groupKey.heading',
      header: true,
      child: Container(
        height: PaletteMetrics.headingHeight,
        margin: const EdgeInsets.only(bottom: PaletteMetrics.headingGap),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: sim.text.small.copyWith(color: sim.colors.textMuted),
        ),
      ),
    );
  }
}

/// `ShortcutHint`: `⌘` centred in the middle column, the modifiers before it
/// in the first, the key after it in the last.
class PaletteShortcutHint extends StatelessWidget {
  const PaletteShortcutHint(this.shortcut, {super.key});

  final String shortcut;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    // `text-small` sets only the size: the line keeps the row's inherited
    // `text-sm` ratio (20/14), 18.57px at 13px.
    final style = sim.text.small.copyWith(
      color: sim.colors.textSubtle,
      height: 20 / 14,
    );
    final command = shortcut.indexOf('⌘');
    final slots = command == -1
        ? ['', '', shortcut]
        : [
            shortcut.substring(0, command),
            '⌘',
            shortcut.substring(command + 1),
          ];
    return Semantics(
      container: true,
      identifier: 'search.palette.row.shortcut',
      label: 'Keyboard shortcut $shortcut',
      excludeSemantics: true,
      child: SizedBox(
        width: PaletteMetrics.shortcutWidth,
        child: Row(
          children: [
            for (final slot in slots)
              Expanded(
                child: Text(
                  slot,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: style,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `ItemMeta`: right-aligned `--text-subtle` 13px with 8px left padding.
class PaletteItemMeta extends StatelessWidget {
  const PaletteItemMeta(this.meta, {super.key});

  final String meta;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        meta,
        maxLines: 1,
        softWrap: false,
        style: sim.text.small.copyWith(color: sim.colors.textSubtle),
      ),
    );
  }
}

/// `ItemFolderPath`: the folder receipt — head segments yield space to the
/// leaf (`[flex-shrink:9999]`), joined by " / ".
class PaletteFolderPath extends StatelessWidget {
  const PaletteFolderPath(this.folderPath, {super.key});

  final List<String> folderPath;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final style = sim.text.small.copyWith(color: sim.colors.textSubtle);
    final leaf = folderPath.last;
    final head = folderPath.length > 1
        ? folderPath.sublist(0, folderPath.length - 1).join(' / ')
        : null;
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return Semantics(
      container: true,
      identifier: 'search.palette.row.folder-path',
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth;
            final leafWidth = measure(leaf).ceilToDouble();
            final separatorWidth = head == null ? 0.0 : measure(' / ');
            final leafSlot = leafWidth.clamp(0.0, available);
            final headSlot = head == null
                ? 0.0
                : (available - leafSlot - separatorWidth).clamp(
                    0.0,
                    measure(head).ceilToDouble(),
                  );
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (head != null) ...[
                  SizedBox(
                    width: headSlot,
                    child: SimOverflowText(label: head, style: style),
                  ),
                  Text(' / ', style: style, maxLines: 1, softWrap: false),
                ],
                SizedBox(
                  width: leafSlot,
                  child: SimOverflowText(label: leaf, style: style),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// `BlockTile`: the block colour tile of canvas and integration rows. The
/// brand glyph arrives with the generated icon set (Phase 2).
class PaletteBlockTile extends StatelessWidget {
  const PaletteBlockTile({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      color: color,
      // `rounded-md`.
      borderRadius: BorderRadius.circular(SimRadii.md),
    ),
  );
}

/// One `[cmdk-item]`: 30px, `mx-0.5 px-2`, 8px gap, 8px radius, 14px
/// `--text-body`; the selected row is `--surface-active` with a 1px
/// `--border-1` border. Hover paints nothing: the pointer moves the
/// selection instead.
class PaletteRow extends StatelessWidget {
  const PaletteRow({
    required this.parityId,
    required this.label,
    required this.selected,
    required this.onHover,
    required this.onTap,
    super.key,
    this.leading,
    this.labelPrefix,
    this.currentSuffix = false,
    this.capLabel = false,
    this.trailing,
    this.enabled = true,
  });

  final String parityId;
  final String label;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;
  final Widget? leading;

  /// Muted lead-in before the label (tool operations: the service name).
  final String? labelPrefix;

  /// Appends " (current)".
  final bool currentSuffix;

  /// `max-w-[75%] shrink-0` name box (workflow, file and icon rows).
  final bool capLabel;
  final Widget? trailing;

  /// cmdk `data-[disabled=true]:pointer-events-none opacity-50`.
  final bool enabled;

  static Widget workflowGlyph(SimIconData icon) => SizedBox.square(
    dimension: 16,
    child: Center(child: SimIcon(icon)),
  );

  static Widget icon(SimIconData icon) => SimIcon(icon, size: 16);

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final style = sim.text.sm.copyWith(color: c.textBody);
    final prefix = labelPrefix;
    Widget name = SimOverflowText(
      label: prefix == null ? label : '$prefix $label',
      style: style,
      child: prefix == null
          ? null
          : Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$prefix ',
                    style: style.copyWith(color: c.textSubtle),
                  ),
                  TextSpan(text: label),
                ],
              ),
              style: style,
              maxLines: 1,
              softWrap: false,
            ),
    );
    if (currentSuffix) {
      name = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: name),
          Text(' (current)', style: style, maxLines: 1, softWrap: false),
        ],
      );
    }
    final content = LayoutBuilder(
      builder: (context, constraints) {
        if (capLabel) {
          // `max-w-[75%] shrink-0` name, then the receipt takes the rest.
          return Row(
            spacing: 8,
            children: [
              ?leading,
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.75,
                ),
                child: name,
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing ?? const SizedBox.shrink(),
                ),
              ),
            ],
          );
        }
        // The label fills the row; `ml-auto` trailing content sits at the end.
        return Row(
          spacing: 8,
          children: [
            ?leading,
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: name,
              ),
            ),
            ?trailing,
          ],
        );
      },
    );
    Widget box = Container(
      height: PaletteMetrics.rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? c.surfaceActive : const Color(0x00000000),
        border: Border.all(
          color: selected ? c.border : const Color(0x00000000),
        ),
        borderRadius: BorderRadius.circular(SimRadii.lg),
      ),
      child: content,
    );
    if (!enabled) box = Opacity(opacity: 0.5, child: box);
    // `w-full mx-0.5`: the `[cmdk-item]` box is as wide as the group and
    // shifted 2px in, so it overhangs the group by 2px on the end side.
    return Transform.translate(
      offset: const Offset(PaletteMetrics.rowMarginX, 0),
      child: Semantics(
        container: true,
        identifier: parityId,
        button: true,
        enabled: enabled,
        selected: selected,
        label: label,
        child: IgnorePointer(
          ignoring: !enabled,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onHover: (_) => onHover(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Semantics(
                container: true,
                identifier: selected ? 'search.palette.row.selected' : null,
                child: box,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds the row of one ranked entry (`renderSearchEntry`).
Widget buildPaletteEntryRow(
  PaletteEntry entry, {
  required bool selected,
  required VoidCallback onHover,
  required VoidCallback onTap,
}) {
  PaletteRow row({
    required String label,
    Widget? leading,
    String? labelPrefix,
    bool current = false,
    bool cap = false,
    Widget? trailing,
  }) => PaletteRow(
    enabled: entry.enabled,
    key: ValueKey(entry.parityId),
    parityId: entry.parityId,
    label: label,
    selected: selected,
    onHover: onHover,
    onTap: onTap,
    leading: leading,
    labelPrefix: labelPrefix,
    currentSuffix: current,
    capLabel: cap,
    trailing: trailing,
  );

  Widget? folder(List<String>? path) =>
      path == null || path.isEmpty ? null : PaletteFolderPath(path);

  return switch (entry.item) {
    final PaletteAction a => row(
      label: a.name,
      leading: PaletteRow.icon(a.icon),
      trailing: a.shortcut == null ? null : PaletteShortcutHint(a.shortcut!),
    ),
    final PaletteBlockItem b => row(
      label: b.name,
      leading: PaletteBlockTile(color: b.bgColor),
    ),
    final PaletteToolOperationItem o => row(
      label: o.name,
      labelPrefix: o.serviceName,
      leading: PaletteBlockTile(color: o.bgColor),
    ),
    final PaletteIntegrationItem i => row(
      label: i.name,
      leading: PaletteBlockTile(color: i.bgColor),
    ),
    final PaletteTaskItem t => row(
      label: t.name,
      trailing: t.date == null ? null : PaletteItemMeta(t.date!),
    ),
    final PaletteFolderedItem f => row(
      label: f.name,
      cap: true,
      current: entry.section == SearchSection.workflows && f.isCurrent,
      leading: switch (entry.section) {
        SearchSection.workflows => PaletteRow.workflowGlyph(
          SimEmcnIcons.workflow,
        ),
        SearchSection.files => PaletteRow.workflowGlyph(SimEmcnIcons.file),
        SearchSection.tables => PaletteRow.icon(SimEmcnIcons.table),
        _ => PaletteRow.icon(SimEmcnIcons.database),
      },
      trailing: folder(f.folderPath),
    ),
    final PaletteLogItem l => row(
      label: l.name,
      cap: true,
      leading: PaletteRow.icon(SimEmcnIcons.library),
      trailing: PaletteItemMeta(l.date),
    ),
    final PaletteWorkspaceItem w => row(
      label: w.name,
      current: w.isCurrent,
      leading: IdentityTile(name: w.name, logoUrl: w.logoUrl),
    ),
    final PalettePageItem p => row(
      label: p.name,
      leading: PaletteRow.icon(p.icon),
      trailing: p.shortcut == null ? null : PaletteShortcutHint(p.shortcut!),
    ),
    _ => row(label: entry.id),
  };
}
