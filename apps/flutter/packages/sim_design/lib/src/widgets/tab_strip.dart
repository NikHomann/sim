import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/interaction/pressable.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/widgets/button.dart';
import 'package:sim_design/src/widgets/overflow_text.dart';
import 'package:sim_design/src/widgets/scroll_fade.dart';
import 'package:sim_design/src/widgets/tooltip.dart';

/// How the tabs are drawn (`TabStripVariant`).
enum SimTabStripVariant { attached, floating, underline }

/// How a selection was initiated.
enum SimTabStripSelectionSource { pointer, keyboard }

/// One tab (`TabStripItem`).
class SimTabStripItem {
  const SimTabStripItem({
    required this.id,
    required this.title,
    this.icon,
    this.active = false,
    this.pinned = false,
    this.selected = false,
    this.tooltip,
    this.attention = false,
  });

  final String id;
  final String title;

  /// Leading glyph the caller owns (a favicon, a spinner, a status icon).
  final Widget? icon;
  final bool active;

  /// Pinned tabs render icon-only and cannot be closed; order them first.
  final bool pinned;

  /// In a multi-tab selection without being on screen (`--surface-active`).
  final bool selected;

  /// Fuller detail for the hover tooltip; otherwise the clipped title.
  final String? tooltip;

  /// Background activity in a tab the user is not viewing.
  final bool attention;
}

/// `tabDropIndex`: resolves a drop gap to a final index, or null for a
/// no-op. Pinned tabs occupy a leading partition that drops cannot cross.
int? tabDropIndex(List<SimTabStripItem> tabs, String draggedId, int gapIndex) {
  final fromIndex = tabs.indexWhere((t) => t.id == draggedId);
  if (fromIndex < 0) return null;
  final pinnedCount = tabs.where((t) => t.pinned).length;
  final dragged = tabs[fromIndex];
  final minGap = dragged.pinned ? 0 : pinnedCount;
  final maxGap = dragged.pinned ? pinnedCount : tabs.length;
  final bounded = gapIndex.clamp(minGap, maxGap);
  final target = bounded > fromIndex ? bounded - 1 : bounded;
  return target == fromIndex ? null : target;
}

/// `tabStripWheelPosition`: final scroll offset for a wheel gesture, or null.
double? tabStripWheelPosition(
  double scrollLeft,
  double scrollWidth,
  double clientWidth,
  double deltaX,
  double deltaY,
) {
  final max = (scrollWidth - clientWidth).clamp(0.0, double.infinity);
  if (max == 0) return null;
  final delta = deltaX.abs() >= deltaY.abs() ? deltaX : deltaY;
  if (delta == 0) return null;
  final next = (scrollLeft + delta).clamp(0.0, max);
  return next == scrollLeft ? null : next;
}

/// Port of `packages/emcn/src/components/tab-strip/tab-strip.tsx`: the
/// Chrome-style tab strip — selection, closing (button, middle click,
/// Delete), drag reordering with drop indicators and edge auto-scroll,
/// keyboard navigation (arrows wrap, Home/End), a new-tab button with its
/// limit tooltip, end actions, three variants and two sizes.
class SimTabStrip extends StatefulWidget {
  const SimTabStrip({
    required this.tabs,
    required this.onSelect,
    super.key,
    this.onClose,
    this.onReorder,
    this.onTabContextMenu,
    this.onNew,
    this.newTabLabel = 'New tab',
    this.maxTabs,
    this.newTabControl,
    this.endActions = const <Widget>[],
    this.variant = SimTabStripVariant.attached,
    this.large = false,
    this.dividers = true,
    this.maxTabWidth = SimLayout.tabStripMaxTabWidth,
  });

  final List<SimTabStripItem> tabs;
  final void Function(String id, SimTabStripSelectionSource source) onSelect;
  final ValueChanged<String>? onClose;
  final void Function(String id, int targetIndex)? onReorder;
  final void Function(String id, Offset globalPosition)? onTabContextMenu;
  final VoidCallback? onNew;
  final String newTabLabel;
  final int? maxTabs;

  /// Replaces the built-in new-tab button.
  final Widget? newTabControl;
  final List<Widget> endActions;
  final SimTabStripVariant variant;
  final bool large;
  final bool dividers;
  final double maxTabWidth;

  static const double dragEdgeZone = 40;
  static const double dragScrollSpeed = 8;

  @override
  State<SimTabStrip> createState() => _SimTabStripState();
}

class _SimTabStripState extends State<SimTabStrip>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};
  String? _draggedId;
  int? _dropTarget;
  Ticker? _autoScroll;
  int _autoScrollDirection = 0;
  String? _lastActive;

  double get _band =>
      widget.large ? SimLayout.tabStripLargeBand : SimLayout.tabStripBand;

  double get _height {
    if (!widget.large) return SimLayout.tabStripHeight;
    return widget.variant == SimTabStripVariant.attached
        ? SimLayout.tabStripLargeHeightAttached
        : SimLayout.tabStripLargeHeightFloating;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());
  }

  @override
  void didUpdateWidget(SimTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _scroll.dispose();
    super.dispose();
  }

  void _revealActive() {
    if (!mounted || !_scroll.hasClients) return;
    final active = widget.tabs.where((t) => t.active && !t.pinned).firstOrNull;
    if (active == null) return;
    final changed = _lastActive != active.id;
    _lastActive = active.id;
    final ctx = _keys[active.id]?.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final viewportBox = _scroll.position.context.storageContext
        .findRenderObject();
    if (viewportBox is! RenderBox) return;
    final left =
        box.localToGlobal(Offset.zero, ancestor: viewportBox).dx +
        _scroll.offset;
    final right = left + box.size.width;
    final viewLeft = _scroll.offset + SimLayout.scrollFadeBand;
    final viewRight =
        _scroll.offset + viewportBox.size.width - SimLayout.scrollFadeBand;
    double? target;
    if (left < viewLeft) {
      target = left - SimLayout.scrollFadeBand;
    } else if (right > viewRight) {
      target = right - viewportBox.size.width + SimLayout.scrollFadeBand;
    }
    if (target == null) return;
    final next = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if ((next - _scroll.offset).abs() < 1) return;
    if (SimMotion.disabled || !changed) {
      _scroll.jumpTo(next);
    } else {
      unawaited(
        _scroll.animateTo(
          next,
          duration: SimMotion.of(SimMotion.tabReveal),
          curve: SimMotion.tabEase,
        ),
      );
    }
  }

  void _stopAutoScroll() {
    _autoScroll?.dispose();
    _autoScroll = null;
    _autoScrollDirection = 0;
  }

  void _edgeScroll(double globalX) {
    final viewportBox = _scroll.hasClients
        ? _scroll.position.context.storageContext.findRenderObject()
        : null;
    if (viewportBox is! RenderBox) return;
    final dragged = widget.tabs.where((t) => t.id == _draggedId).firstOrNull;
    if (dragged?.pinned ?? false) {
      _stopAutoScroll();
      return;
    }
    final origin = viewportBox.localToGlobal(Offset.zero).dx;
    final width = viewportBox.size.width;
    final direction = globalX < origin + SimTabStrip.dragEdgeZone
        ? -1
        : globalX > origin + width - SimTabStrip.dragEdgeZone
        ? 1
        : 0;
    if (direction != 0 && direction == _autoScrollDirection) return;
    _stopAutoScroll();
    if (direction == 0) return;
    _autoScrollDirection = direction;
    _autoScroll = createTicker((_) {
      final before = _scroll.offset;
      final next = (before + direction * SimTabStrip.dragScrollSpeed).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.jumpTo(next);
      if (next == before) _stopAutoScroll();
    });
    unawaited(_autoScroll!.start());
  }

  void _onDragUpdate(String id, Offset globalPosition) {
    if (widget.onReorder == null) return;
    var gap = -1;
    for (var i = 0; i < widget.tabs.length; i++) {
      final box = _keys[widget.tabs[i].id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (globalPosition.dx < rect.left + rect.width / 2) {
        gap = i;
        break;
      }
    }
    if (gap < 0) gap = widget.tabs.length;
    final target = tabDropIndex(widget.tabs, id, gap);
    if (target != _dropTarget) setState(() => _dropTarget = target);
    _edgeScroll(globalPosition.dx);
  }

  void _onDragEnd() {
    final id = _draggedId;
    final target = _dropTarget;
    _stopAutoScroll();
    setState(() {
      _draggedId = null;
      _dropTarget = null;
    });
    if (id != null && target != null) widget.onReorder?.call(id, target);
  }

  KeyEventResult _onTabKey(KeyEvent event, String id) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final index = widget.tabs.indexWhere((t) => t.id == id);
    if (index < 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final n = widget.tabs.length;
    SimTabStripItem? target;
    if (key == LogicalKeyboardKey.arrowLeft) {
      target = widget.tabs[(index - 1 + n) % n];
    } else if (key == LogicalKeyboardKey.arrowRight) {
      target = widget.tabs[(index + 1) % n];
    } else if (key == LogicalKeyboardKey.home) {
      target = widget.tabs.first;
    } else if (key == LogicalKeyboardKey.end) {
      target = widget.tabs.last;
    } else if (key == LogicalKeyboardKey.delete) {
      if (widget.onClose != null && !widget.tabs[index].pinned) {
        widget.onClose!(id);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    } else {
      return KeyEventResult.ignored;
    }
    widget.onSelect(target.id, SimTabStripSelectionSource.keyboard);
    return KeyEventResult.handled;
  }

  bool _isBare(SimTabStripItem? tab) =>
      tab != null && !tab.active && !tab.selected;

  Widget _buildTab(
    SimTabStripItem tab,
    int laneIndex,
    List<SimTabStripItem> lane,
  ) {
    final index = widget.tabs.indexWhere((t) => t.id == tab.id);
    final previous = laneIndex > 0 ? lane[laneIndex - 1] : null;
    final draggedIndex = widget.tabs.indexWhere((t) => t.id == _draggedId);
    final activeIndex = widget.tabs.indexWhere((t) => t.active);
    return _Tab(
      key: _keys.putIfAbsent(tab.id, GlobalKey.new),
      tab: tab,
      variant: widget.variant,
      band: _band,
      large: widget.large,
      maxTabWidth: widget.maxTabWidth,
      showDivider:
          widget.dividers &&
          widget.variant == SimTabStripVariant.floating &&
          _isBare(tab) &&
          _isBare(previous),
      closeable: widget.onClose != null && !tab.pinned,
      draggable: widget.onReorder != null,
      dragging: _draggedId == tab.id,
      focusable: tab.active || (activeIndex < 0 && index == 0),
      showDropBefore:
          _dropTarget == index && draggedIndex >= 0 && draggedIndex > index,
      showDropAfter:
          _dropTarget == index && draggedIndex >= 0 && draggedIndex < index,
      onSelect: () =>
          widget.onSelect(tab.id, SimTabStripSelectionSource.pointer),
      onClose: widget.onClose == null ? null : () => widget.onClose!(tab.id),
      onContextMenu: widget.onTabContextMenu == null
          ? null
          : (pos) => widget.onTabContextMenu!(tab.id, pos),
      onKeyEvent: (event) => _onTabKey(event, tab.id),
      onDragStart: () => setState(() => _draggedId = tab.id),
      onDragUpdate: (pos) => _onDragUpdate(tab.id, pos),
      onDragEnd: _onDragEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final attached = widget.variant == SimTabStripVariant.attached;
    final pinned = widget.tabs.where((t) => t.pinned).toList();
    final regular = widget.tabs.where((t) => !t.pinned).toList();
    final atLimit =
        widget.maxTabs != null && widget.tabs.length >= widget.maxTabs!;
    final laneGap = attached ? 2.0 : 8.0;
    final laneAlign = attached
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.center;
    return Container(
      height: _height,
      padding: EdgeInsets.only(
        left: SimLayout.tabStripInline,
        right: SimLayout.tabStripInline,
        top: attached ? 4 : 0,
      ),
      decoration: widget.dividers
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            )
          : null,
      child: Row(
        crossAxisAlignment: laneAlign,
        spacing: 4,
        children: <Widget>[
          Flexible(
            child: Transform.translate(
              offset: Offset(0, attached ? 1 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: laneAlign,
                spacing: laneGap,
                children: <Widget>[
                  if (pinned.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: laneAlign,
                      spacing: laneGap,
                      children: <Widget>[
                        for (var i = 0; i < pinned.length; i++)
                          _buildTab(pinned[i], i, pinned),
                      ],
                    ),
                  Flexible(
                    child: SimScrollFade(
                      axis: Axis.horizontal,
                      child: Listener(
                        onPointerSignal: (signal) {
                          if (signal is! PointerScrollEvent ||
                              !_scroll.hasClients) {
                            return;
                          }
                          final next = tabStripWheelPosition(
                            _scroll.offset,
                            _scroll.position.maxScrollExtent +
                                _scroll.position.viewportDimension,
                            _scroll.position.viewportDimension,
                            signal.scrollDelta.dx,
                            signal.scrollDelta.dy,
                          );
                          if (next != null) _scroll.jumpTo(next);
                        },
                        child: SingleChildScrollView(
                          controller: _scroll,
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: laneAlign,
                            spacing: laneGap,
                            children: <Widget>[
                              for (var i = 0; i < regular.length; i++)
                                _buildTab(regular[i], i, regular),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.newTabControl != null)
            SizedBox(
              height: _band,
              child: Center(child: widget.newTabControl),
            )
          else if (widget.onNew != null)
            SimTooltip(
              message: atLimit
                  ? 'Maximum of ${widget.maxTabs} tabs'
                  : widget.newTabLabel,
              child: SimButton(
                variant: SimButtonVariant.ghostSecondary,
                size: SimButtonSize.sm,
                width: _band,
                height: _band,
                padding: EdgeInsets.zero,
                enabled: !atLimit,
                semanticsLabel: widget.newTabLabel,
                onPressed: widget.onNew,
                child: const SimIcon(SimIcons.plus),
              ),
            ),
          if (widget.endActions.isNotEmpty) ...<Widget>[
            const Spacer(),
            SizedBox(
              height: _band,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: widget.endActions,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.tab,
    required this.variant,
    required this.band,
    required this.large,
    required this.maxTabWidth,
    required this.showDivider,
    required this.closeable,
    required this.draggable,
    required this.dragging,
    required this.focusable,
    required this.showDropBefore,
    required this.showDropAfter,
    required this.onSelect,
    required this.onClose,
    required this.onContextMenu,
    required this.onKeyEvent,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    super.key,
  });

  final SimTabStripItem tab;
  final SimTabStripVariant variant;
  final double band;
  final bool large;
  final double maxTabWidth;
  final bool showDivider;
  final bool closeable;
  final bool draggable;
  final bool dragging;
  final bool focusable;
  final bool showDropBefore;
  final bool showDropAfter;
  final VoidCallback onSelect;
  final VoidCallback? onClose;
  final ValueChanged<Offset>? onContextMenu;
  final KeyEventResult Function(KeyEvent event) onKeyEvent;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final tab = widget.tab;
    final variant = widget.variant;
    final attached = variant == SimTabStripVariant.attached;
    final underline = variant == SimTabStripVariant.underline;

    Color fill;
    Color text;
    BoxBorder? border;
    BorderRadius radius;
    switch (variant) {
      case SimTabStripVariant.attached:
        radius = const BorderRadius.vertical(
          top: Radius.circular(SimRadii.button),
        );
        if (tab.active) {
          fill = c.bg;
          text = c.textPrimary;
          border = Border(
            top: BorderSide(color: c.border),
            left: BorderSide(color: c.border),
            right: BorderSide(color: c.border),
          );
        } else {
          fill = tab.selected
              ? c.surfaceActive
              : _hovered
              ? c.surface4
              : const Color(0x00000000);
          text = c.textBody;
          border = const Border(
            top: BorderSide(color: Color(0x00000000)),
            left: BorderSide(color: Color(0x00000000)),
            right: BorderSide(color: Color(0x00000000)),
          );
        }
      case SimTabStripVariant.floating:
        radius = BorderRadius.circular(SimRadii.lg);
        if (tab.active) {
          fill = c.surfaceActive;
          text = c.textPrimary;
        } else if (tab.selected) {
          fill = c.surface4;
          text = _hovered ? c.textPrimary : c.textSecondary;
        } else {
          fill = _hovered ? c.surfaceHover : const Color(0x00000000);
          text = _hovered ? c.textPrimary : c.textSecondary;
        }
      case SimTabStripVariant.underline:
        radius = BorderRadius.zero;
        fill = const Color(0x00000000);
        text = tab.active || tab.selected || _hovered
            ? c.textBody
            : c.textMuted;
        border = Border(
          bottom: BorderSide(
            color: tab.active ? c.textBody : const Color(0x00000000),
            width: 2,
          ),
        );
    }
    final showClose = widget.closeable && (tab.active || _hovered);
    final style = (widget.large ? sim.text.base : sim.text.caption).copyWith(
      color: text,
    );

    Widget button = SimPressable(
      onPressed: widget.onSelect,
      onSecondaryTapDown: widget.onContextMenu,
      onMiddleTap: widget.closeable ? widget.onClose : null,
      skipTraversal: !widget.focusable,
      selected: tab.active,
      semanticsLabel: tab.attention && !tab.active
          ? '${tab.title}, Background activity'
          : tab.title,
      onKeyEvent: (node, event) => widget.onKeyEvent(event),
      builder: (context, state) => AnimatedContainer(
        duration: SimMotion.of(SimMotion.colors),
        height: widget.band,
        padding: EdgeInsets.only(
          left: tab.pinned ? 0 : 8,
          right: tab.pinned ? 0 : (widget.closeable ? 32 : 8),
        ),
        decoration: BoxDecoration(
          color: fill,
          border: border,
          borderRadius: radius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: tab.pinned
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          spacing: 6,
          children: <Widget>[
            if (tab.icon != null) tab.icon!,
            if (!tab.pinned)
              Flexible(
                child: SimOverflowText(
                  label: tab.title,
                  style: style,
                  tooltipEnabled: tab.tooltip == null,
                ),
              ),
            if (tab.attention && !tab.active && !widget.closeable)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: c.brandBlue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
    if (tab.tooltip != null || tab.pinned) {
      button = SimTooltip(message: tab.tooltip ?? tab.title, child: button);
    }

    final width = tab.pinned
        ? 34.0
        : attached
        ? 156.0
        : null;
    Widget body = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: tab.pinned ? 34 : (attached ? 96 : 112),
            maxWidth: width ?? widget.maxTabWidth,
          ),
          child: SizedBox(width: width, child: button),
        ),
        if (widget.showDivider)
          Positioned(
            left: -4,
            top: 0,
            bottom: 0,
            child: Center(
              child: SizedBox(
                width: 1,
                height: 16,
                child: ColoredBox(color: c.border),
              ),
            ),
          ),
        if (widget.showDropBefore)
          Positioned(
            left: -1,
            top: 0,
            bottom: 0,
            child: Center(child: _DropIndicator(color: c.textSubtle)),
          ),
        if (widget.showDropAfter)
          Positioned(
            right: -1,
            top: 0,
            bottom: 0,
            child: Center(child: _DropIndicator(color: c.textSubtle)),
          ),
        if (widget.closeable)
          Positioned(
            right: 2,
            top: 0,
            bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                duration: SimMotion.of(SimMotion.colors),
                opacity: showClose ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !showClose,
                  child: SimButton(
                    variant: SimButtonVariant.ghostSecondary,
                    size: SimButtonSize.sm,
                    width: 24,
                    height: 24,
                    padding: EdgeInsets.zero,
                    semanticsLabel: 'Close ${tab.title}',
                    onPressed: widget.onClose,
                    child: const SimIcon(SimIcons.x, size: 11),
                  ),
                ),
              ),
            ),
          ),
        if (widget.closeable && tab.attention && !tab.active && !showClose)
          Positioned(
            right: 11,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: c.brandBlue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
    if (widget.draggable) {
      body = GestureDetector(
        onPanStart: (_) => widget.onDragStart(),
        onPanUpdate: (d) => widget.onDragUpdate(d.globalPosition),
        onPanEnd: (_) => widget.onDragEnd(),
        onPanCancel: widget.onDragEnd,
        child: body,
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Opacity(
        opacity: widget.dragging ? 0.3 : 1,
        child: Transform.translate(
          offset: Offset(0, underline ? 0 : 0),
          child: body,
        ),
      ),
    );
  }
}

class _DropIndicator extends StatelessWidget {
  const _DropIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 2,
    height: 16,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(SimRadii.full),
    ),
  );
}
