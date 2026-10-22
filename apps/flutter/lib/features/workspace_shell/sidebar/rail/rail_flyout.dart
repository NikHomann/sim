import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/sidebar/rail/hover_menu.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/inline_rename.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_design/sim_design.dart';

/// `w-[220px]` of the rail flyout content.
const double railFlyoutWidth = 220;

/// `sideOffset={8}` of the rail flyout content.
const double railFlyoutSideOffset = 8;

/// `CollapsedSidebarMenu`: a rail trigger whose flyout menu opens on hover
/// (`side='right' align='start' sideOffset={8}`, 220px, no motion,
/// `modal={false}`) and closes 150ms after the pointer leaves the trigger,
/// the menu and its submenus, unless [controller] is locked.
class RailFlyout extends StatefulWidget {
  const RailFlyout({
    required this.controller,
    required this.trigger,
    required this.entries,
    super.key,
    this.flyoutParityId = 'shell.sidebar.rail.flyout',
  });

  final HoverMenuController controller;

  /// The trigger chip; it receives the flyout's open state.
  final Widget Function(BuildContext context, {required bool open}) trigger;
  final List<SimMenuEntry> Function() entries;
  final String flyoutParityId;

  @override
  State<RailFlyout> createState() => RailFlyoutState();
}

class RailFlyoutState extends State<RailFlyout> {
  final GlobalKey _triggerKey = GlobalKey(debugLabel: 'RailFlyout.trigger');
  SimOverlayEntry? _entry;
  SimOverlayController? _overlay;
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(RailFlyout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
    _entry?.markNeedsBuild();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overlay = SimOverlay.maybeOf(context);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _stopRoute();
    _entry?.remove();
    _entry = null;
    // The controller outlives this trigger (the section keeps it across a
    // collapse / expand round trip): leave it closed and unlocked, or the
    // next trigger would mount "open" with no flyout and hover could never
    // reopen it.
    widget.controller.reset();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final open = widget.controller.isOpen;
    final overlay = _overlay;
    if (open && _entry == null && overlay != null) {
      final triggerContext = _triggerKey.currentContext;
      if (triggerContext == null) return;
      final anchor = overlay.rectOf(triggerContext);
      late final SimOverlayEntry entry;
      entry = SimOverlayEntry(
        onDismissRequested: widget.controller.close,
        builder: (context) => SimAnchoredOverlay(
          anchor: anchor,
          side: SimSide.right,
          sideOffset: railFlyoutSideOffset,
          minWidth: railFlyoutWidth,
          maxWidth: railFlyoutWidth,
          maxHeight: SimMenuStyles.maxHeight,
          contentKey: entry.contentKey,
          child: Parity(
            widget.flyoutParityId,
            child: SimMenuList(
              entries: widget.entries,
              autofocus: false,
              parentEntry: entry,
              onRequestClose: widget.controller.close,
              decoration: SimMenuStyles.surface(SimTheme.of(context).colors),
            ),
          ),
        ),
      );
      _entry = entry;
      overlay.insert(entry);
      _startRoute();
    } else if (!open && _entry != null) {
      _entry!.remove();
      _entry = null;
      _stopRoute();
    }
    setState(() {});
  }

  void _startRoute() {
    if (_routed) return;
    _routed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  void _stopRoute() {
    if (!_routed) return;
    _routed = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
  }

  void _onPointer(PointerEvent event) {
    if (event is! PointerHoverEvent && event is! PointerMoveEvent) return;
    if (event.kind == PointerDeviceKind.touch) return;
    widget.controller.setPointerInside(inside: _isInside(event.position));
  }

  Rect? _globalRect(BuildContext? context) {
    final box = context?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Trigger, flyout content, or any submenu layer opened from it.
  bool _isInside(Offset global) {
    if (_globalRect(_triggerKey.currentContext)?.contains(global) ?? false) {
      return true;
    }
    final mine = _entry;
    final overlay = _overlay;
    if (mine == null || overlay == null) return false;
    for (final entry in overlay.entries) {
      var related = identical(entry, mine);
      for (var p = entry.parent; !related && p != null; p = p.parent) {
        related = identical(p, mine);
      }
      if (!related) continue;
      final rect = _globalRect(entry.contentKey.currentContext);
      if (rect != null && rect.contains(global)) return true;
    }
    return false;
  }

  /// The trigger's global rect (anchors action menus opened from rows).
  Rect? get triggerRect => _globalRect(_triggerKey.currentContext);

  @override
  Widget build(BuildContext context) => MouseRegion(
    key: _triggerKey,
    onEnter: (event) {
      if (event.kind == PointerDeviceKind.touch) return;
      widget.controller.open();
    },
    child: widget.trigger(context, open: widget.controller.isOpen),
  );
}

/// A flyout row (`dropdownMenuRowClass`, 28px, `text-small`) with what
/// `DropdownMenuItem` cannot carry in `SimMenuList`: a right-click handler,
/// a trailing "…" action (`DropdownMenuItemAction`, revealed on hover or
/// while its menu is open) and a custom trailing indicator.
class FlyoutRow extends StatefulWidget {
  const FlyoutRow({
    required this.label,
    super.key,
    this.active = false,
    this.enabled = true,
    this.onPressed,
    this.onSecondaryTapDown,
    this.onAction,
    this.actionOpen = false,
    this.actionLabel = 'Options',
    this.indicator,
    this.leading,
    this.parityId,
    this.onMiddleTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onPressed;

  /// Middle-click (`auxclick` on the link: open in a new tab).
  final VoidCallback? onMiddleTap;
  final void Function(Offset globalPosition)? onSecondaryTapDown;

  /// The "…" action; receives the action button's global rect.
  final void Function(Rect globalRect)? onAction;
  final bool actionOpen;
  final String actionLabel;
  final Widget? indicator;
  final Widget? leading;
  final String? parityId;

  @override
  State<FlyoutRow> createState() => _FlyoutRowState();
}

class _FlyoutRowState extends State<FlyoutRow> {
  bool _hovered = false;
  final GlobalKey _actionKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final showAction =
        widget.onAction != null && (widget.actionOpen || _hovered);
    final fill = widget.active || widget.actionOpen
        ? c.surfaceActive
        : _hovered && widget.enabled
        ? c.surfaceHover
        : const Color(0x00000000);
    Widget row = Container(
      height: SimMenuStyles.rowHeight(SimMenuRowSize.md),
      padding: EdgeInsets.only(
        left: SimMenuStyles.rowPaddingX,
        right: showAction ? 28 : SimMenuStyles.rowPaddingX,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(SimMenuStyles.rowRadius),
      ),
      child: Row(
        spacing: SimMenuStyles.rowGap,
        children: <Widget>[
          ?widget.leading,
          Expanded(
            child: SimOverflowText(
              label: widget.label,
              style: sim.text.small.copyWith(color: c.textBody),
              tooltipEnabled: false,
            ),
          ),
          if (!showAction) ?widget.indicator,
        ],
      ),
    );
    row = Stack(
      children: <Widget>[
        row,
        if (showAction)
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: SimMenuItemActionGlyph(
                key: _actionKey,
                label: widget.actionLabel,
                onPressed: () {
                  final box =
                      _actionKey.currentContext!.findRenderObject()!
                          as RenderBox;
                  widget.onAction!(box.localToGlobal(Offset.zero) & box.size);
                },
              ),
            ),
          ),
      ],
    );
    row = Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onPressed : null,
          onTertiaryTapUp: widget.onMiddleTap == null || !widget.enabled
              ? null
              : (_) => widget.onMiddleTap!(),
          onSecondaryTapDown: widget.onSecondaryTapDown == null
              ? null
              : (d) => widget.onSecondaryTapDown!(d.globalPosition),
          child: Semantics(
            button: true,
            enabled: widget.enabled,
            selected: widget.active,
            label: widget.label,
            child: row,
          ),
        ),
      ),
    );
    if (widget.parityId != null) row = Parity(widget.parityId!, child: row);
    return row;
  }
}

/// `EDIT_ROW_CLASS`: a flyout row while renaming — the active chip at
/// `text-small` holding a bare 100-character input.
class FlyoutEditRow extends StatelessWidget {
  const FlyoutEditRow({
    required this.controller,
    required this.semanticsLabel,
    super.key,
  });

  final InlineRenameController controller;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return Container(
      height: SimChipChrome.height,
      padding: const EdgeInsets.symmetric(horizontal: SimChipChrome.paddingX),
      decoration: BoxDecoration(
        color: c.surfaceActive,
        borderRadius: BorderRadius.circular(SimChipChrome.radius),
      ),
      alignment: Alignment.centerLeft,
      child: InlineRenameField(
        controller: controller,
        maxLength: 100,
        small: true,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}

/// `DropdownMenuItemAction` with the emcn "…" glyph (16px in an 18px slot).
class SimMenuItemActionGlyph extends StatelessWidget {
  const SimMenuItemActionGlyph({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: const SizedBox(
        width: 18,
        height: 18,
        child: Center(
          child: SimIcon(SimEmcnIcons.moreHorizontal, size: 16),
        ),
      ),
    ),
  );
}
