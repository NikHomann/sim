import 'package:flutter/widgets.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/tokens/shadows.dart';
import 'package:sim_design/src/widgets/chip/chrome.dart';

/// Row height of a menu: `md` 28px at text-small, `sm` 24px at text-caption,
/// `lg` the 30px chip geometry (sidebar-aligned rows).
enum SimMenuRowSize { sm, md, lg }

/// Port of `MENU_STYLES` (`packages/emcn/src/components/dropdown-menu/styles.ts`):
/// the shared chrome of action menus, picker lists and their floating
/// surfaces.
abstract final class SimMenuStyles {
  /// `surface`: rounded-xl, 1px `--border`, `--bg`, `--text-body`, shadow-medium.
  static BoxDecoration surface(SimColors c) => BoxDecoration(
    color: c.bg,
    border: Border.all(color: c.border),
    borderRadius: BorderRadius.circular(SimRadii.menu),
    boxShadow: SimShadows.medium,
  );

  /// Inverted surface (`colorScheme='inverted'` popovers): dark chrome on a
  /// light page, standard surfaces in dark mode.
  static BoxDecoration invertedSurface(SimColors c) => BoxDecoration(
    color: c.surfaceInverted,
    border: Border.all(color: c.borderInverted),
    borderRadius: BorderRadius.circular(SimRadii.menu),
    boxShadow: SimShadows.medium,
  );

  /// `padding: 'p-1'`.
  static const EdgeInsets padding = EdgeInsets.all(SimLayout.menuPadding);

  /// `rowLayout`: items-center, chip gap, chip radius, px-2.
  static const double rowPaddingX = SimChipChrome.paddingX;
  static const double rowGap = SimChipChrome.gap;
  static const double rowRadius = SimChipChrome.radius;

  /// `pl-7` inset for rows beside a check/radio slot.
  static const double insetPadding = 28;

  static double rowHeight(SimMenuRowSize size) => switch (size) {
    SimMenuRowSize.sm => SimLayout.menuRowHeightSm,
    SimMenuRowSize.md => SimLayout.menuRowHeight,
    SimMenuRowSize.lg => SimChipChrome.height,
  };

  static TextStyle rowStyle(SimTheme sim, SimMenuRowSize size) =>
      switch (size) {
        SimMenuRowSize.sm => sim.text.caption,
        SimMenuRowSize.md => sim.text.small,
        SimMenuRowSize.lg => sim.text.sm,
      };

  /// `heading`: h-[28px] px-2 `--text-muted` text-caption.
  static const double headingHeight = 28;

  /// `selectionIcon`: ml-auto 14px `--text-icon`.
  static const double selectionIconSize = 14;

  /// `separator`: mx-2 my-1 1px `--border`.
  static const EdgeInsets separatorMargin = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 4,
  );

  /// `search`: the chip field surface, my-0.5, h-[28px], chip gap, px-2.
  static const double searchHeight = 28;
  static const EdgeInsets searchMargin = EdgeInsets.symmetric(vertical: 2);

  static const double minWidth = SimLayout.menuMinWidth;
  static const double maxWidth = SimLayout.menuMaxWidth;
  static const double submenuMaxWidth = SimLayout.submenuMaxWidth;
  static const double maxHeight = SimLayout.menuMaxHeight;
  static const double sideOffset = SimLayout.menuSideOffset;
}

/// `DropdownMenuSeparator`.
class SimMenuSeparatorLine extends StatelessWidget {
  const SimMenuSeparatorLine({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: SimMenuStyles.separatorMargin,
    child: SizedBox(
      height: SimLayout.borderWidth,
      child: ColoredBox(color: color ?? SimTheme.of(context).colors.border),
    ),
  );
}

/// `DropdownMenuLabel`: a section heading one text step below its rows.
class SimMenuHeading extends StatelessWidget {
  const SimMenuHeading(this.text, {super.key, this.inset = false, this.color});

  final String text;
  final bool inset;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    return Container(
      height: SimMenuStyles.headingHeight,
      padding: EdgeInsets.only(
        left: inset ? SimMenuStyles.insetPadding : SimMenuStyles.rowPaddingX,
        right: SimMenuStyles.rowPaddingX,
      ),
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: sim.text.caption.copyWith(color: color ?? sim.colors.textMuted),
      ),
    );
  }
}
