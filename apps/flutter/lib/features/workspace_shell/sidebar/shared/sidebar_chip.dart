import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// The sidebar's chip pill: `chipVariants({active, fullWidth})` — 30px tall,
/// `px-2`, 6px gap, `rounded-lg`, `text-sm` — with the aside's
/// `[&_.group.cursor-pointer]:duration-0`, so hover and active fills switch
/// in one frame (unlike [SimChip], which eases its colours).
class SidebarChip extends StatelessWidget {
  const SidebarChip({
    super.key,
    this.icon,
    this.leading,
    this.label,
    this.content,
    this.trailing,
    this.active = false,
    this.width,
    this.onPressed,
    this.onSecondaryTapDown,
    this.onMiddleTap,
    this.enabled = true,
    this.semanticsLabel,
    this.isLink = false,
    this.focusNode,
    this.onKeyEvent,
    this.textStyle,
    this.alignment = MainAxisAlignment.start,
    this.onHoverChanged,
    this.cursor,
    this.canRequestFocus = true,
    this.excludeSemantics = false,
    this.hug = false,
  });

  /// Hugs its content instead of filling the row (`max-w-full` chips).
  final bool hug;

  /// Leading 16px glyph in `--text-icon` (`chipContentIconClass`).
  final SimIconData? icon;

  /// Pre-rendered leading content (avatar, tile); wins over [icon].
  final Widget? leading;

  /// Single-line label, faded on overflow.
  final String? label;

  /// Free content in place of [label] (fills the remaining width).
  final Widget? content;
  final Widget? trailing;
  final bool active;

  /// Fixed width (the 32px rail chip); `null` fills the row.
  final double? width;
  final VoidCallback? onPressed;
  final void Function(Offset globalPosition)? onSecondaryTapDown;
  final VoidCallback? onMiddleTap;
  final bool enabled;
  final String? semanticsLabel;
  final bool isLink;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final TextStyle? textStyle;
  final MainAxisAlignment alignment;
  final ValueChanged<bool>? onHoverChanged;
  final MouseCursor? cursor;
  final bool canRequestFocus;
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return SimPressable(
      onPressed: onPressed,
      onSecondaryTapDown: onSecondaryTapDown,
      onMiddleTap: onMiddleTap,
      enabled: enabled,
      semanticsLabel: semanticsLabel ?? label,
      isLink: isLink,
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      onHoverChanged: onHoverChanged,
      cursor: cursor,
      canRequestFocus: canRequestFocus,
      excludeSemantics: excludeSemantics,
      selected: active ? true : null,
      builder: (context, state) {
        final paint = resolveChipPaint(
          c,
          active: active,
          hovered: state.hovered,
          focused: state.focused,
        );
        final children = <Widget>[];
        if (leading != null) {
          children.add(leading!);
        } else if (icon != null) {
          children.add(
            SimIcon(
              icon!,
              size: SimChipChrome.contentIconSize,
              color: paint.icon,
            ),
          );
        }
        final style = textStyle ?? sim.text.sm.copyWith(color: paint.text);
        if (content != null) {
          children.add(
            hug ? Flexible(child: content!) : Expanded(child: content!),
          );
        } else if (label != null) {
          final text = SimOverflowText(
            label: label!,
            style: style,
            tooltipEnabled: false,
          );
          children.add(hug ? Flexible(child: text) : Expanded(child: text));
        }
        if (trailing != null) children.add(trailing!);
        return Opacity(
          opacity: enabled ? 1 : SimChipChrome.disabledOpacity,
          child: Container(
            height: SimChipChrome.height,
            width: width ?? (hug ? null : double.infinity),
            padding: const EdgeInsets.symmetric(
              horizontal: SimChipChrome.paddingX,
            ),
            decoration: BoxDecoration(
              color: paint.fill,
              borderRadius: BorderRadius.circular(SimChipChrome.radius),
            ),
            child: DefaultTextStyle.merge(
              style: style,
              child: Row(
                mainAxisSize: hug ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: alignment,
                spacing: SimChipChrome.gap,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The 32×30 icon-only chip of the header (Search, Collapse) and footer
/// (Help): `Chip leftIcon` with no label.
class SidebarIconChip extends StatelessWidget {
  const SidebarIconChip({
    required this.icon,
    required this.semanticsLabel,
    super.key,
    this.onPressed,
    this.width = SimLayout.sidebarRailChip,
    this.active = false,
    this.canRequestFocus = true,
  });

  final SimIconData icon;
  final String semanticsLabel;
  final VoidCallback? onPressed;
  final double? width;
  final bool active;
  final bool canRequestFocus;

  @override
  Widget build(BuildContext context) => SidebarChip(
    icon: icon,
    width: width,
    active: active,
    semanticsLabel: semanticsLabel,
    onPressed: onPressed,
    canRequestFocus: canRequestFocus,
  );
}

/// `RowActions` + `SidebarRowAction` (`row-actions.tsx`,
/// `sidebar-row-actions.tsx`): an 18×18 slot holding an optional indicator
/// (lock, pin, dot) that gives way to the "…" action on row hover or focus,
/// and keeps the action while its menu is [open]. Hidden when there is
/// neither an indicator nor an open menu and the row is not revealed.
///
/// Like `handleMorePointerDown`, the "…" records at pointer-down whether its
/// menu was open: that press already closes the menu (outside press), so
/// the click that follows must not reopen it, however long the exit
/// animation runs.
class SidebarRowActions extends StatefulWidget {
  const SidebarRowActions({
    required this.revealed,
    required this.actionLabel,
    required this.onAction,
    super.key,
    this.indicator,
    this.open = false,
    this.revealOnHover = true,
    this.indicatorParityId,
    this.actionsParityId,
    this.actionIconSize = 16,
  });

  final Widget? indicator;

  /// The "…" glyph: 16px on tree rows, 14px on chat rows.
  final double actionIconSize;
  final bool revealed;
  final bool open;
  final bool revealOnHover;
  final String actionLabel;
  final void Function(Rect globalRect) onAction;
  final String? indicatorParityId;
  final String? actionsParityId;

  @override
  State<SidebarRowActions> createState() => _SidebarRowActionsState();
}

class _SidebarRowActionsState extends State<SidebarRowActions> {
  bool _openAtPointerDown = false;

  void _onPressed(Rect rect) {
    final wasOpen = _openAtPointerDown;
    _openAtPointerDown = false;
    if (wasOpen) return;
    widget.onAction(rect);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final showAction = w.open || (w.revealOnHover && w.revealed);
    if (!showAction && w.indicator == null) return const SizedBox.shrink();
    Widget slot = SizedBox.square(
      dimension: 18,
      child: showAction
          ? Listener(
              onPointerDown: (_) => _openAtPointerDown = w.open,
              child: _RowActionButton(
                label: w.actionLabel,
                onPressed: _onPressed,
                iconSize: w.actionIconSize,
              ),
            )
          : Center(
              child: w.indicatorParityId == null
                  ? w.indicator
                  : Semantics(
                      identifier: w.indicatorParityId,
                      container: true,
                      child: w.indicator,
                    ),
            ),
    );
    if (w.actionsParityId != null) {
      slot = Semantics(
        identifier: w.actionsParityId,
        container: true,
        child: slot,
      );
    }
    return slot;
  }
}

class _RowActionButton extends StatelessWidget {
  const _RowActionButton({
    required this.label,
    required this.onPressed,
    required this.iconSize,
  });

  final String label;
  final double iconSize;
  final void Function(Rect globalRect) onPressed;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return SimPressable(
      semanticsLabel: label,
      onPressed: () {
        final box = context.findRenderObject()! as RenderBox;
        onPressed(box.localToGlobal(Offset.zero) & box.size);
      },
      builder: (context, state) => Container(
        decoration: BoxDecoration(
          color: state.hovered ? c.surfaceActive : null,
          borderRadius: BorderRadius.circular(SimRadii.sm),
        ),
        alignment: Alignment.center,
        child: SimIcon(
          SimEmcnIcons.moreHorizontal,
          size: iconSize,
          color: c.textIcon,
        ),
      ),
    );
  }
}

/// Whether the platform's primary modifier (Cmd on macOS, Ctrl elsewhere)
/// or either of them is held, read at click time.
bool get isModifierPressed =>
    HardwareKeyboard.instance.isMetaPressed ||
    HardwareKeyboard.instance.isControlPressed;

bool get isShiftPressed => HardwareKeyboard.instance.isShiftPressed;
