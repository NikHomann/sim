import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/panel/chat_panel_layout.dart';
import 'package:sim_app/features/home/panel/resource_registry.dart';
import 'package:sim_design/sim_design.dart';

/// Strip geometry (`RESOURCE_HEADER_CLASSES.stripGeometry`).
abstract final class ResourceStripGeometry {
  /// 40 + the 1px bottom border.
  static const double height = ResourceHeaderGeometry.controlsHeight + 1;
  static const double band = 26;
  static const double inlineStart = ResourceHeaderGeometry.endInset;
  static const double inlineEnd = ResourceHeaderGeometry.fixedReserve;
  static const double tabMinWidth = 112;
  static const double tabMaxWidth = 200;
  static const double laneGap = 8;
  static const double controlGap = 4;

  /// Tab chrome around the title: `px-2` start, 16px icon, `gap-1.5`, and
  /// the `pr-8` close slot.
  static const double tabChrome = 8 + 16 + 6 + 32;
}

/// A tab's label: the trimmed title, or the type's label when it is blank.
String resourceTabTitle(HomeResource resource) {
  final title = resource.title.trim();
  return title.isNotEmpty ? title : resourceConfig(resource.type).label;
}

/// Floating tab widths (`TAB_WIDTH.floating`, `min-w-28 max-w-[200px]
/// shrink`): each tab starts at its content width ([natural], capped at
/// 200), and when the row does not fit in [lane] the tabs shrink like CSS
/// flex items — in proportion to their size, none below 112 — after which
/// the row scrolls.
List<double> fitResourceTabWidths(
  List<double> natural,
  double lane, {
  double gap = ResourceStripGeometry.laneGap,
}) {
  final widths = <double>[
    for (final w in natural)
      w.clamp(
        ResourceStripGeometry.tabMinWidth,
        ResourceStripGeometry.tabMaxWidth,
      ),
  ];
  if (widths.isEmpty) return widths;
  final frozen = List<bool>.filled(widths.length, false);
  final bases = List<double>.of(widths);
  for (var pass = 0; pass < widths.length; pass++) {
    final total =
        widths.fold<double>(0, (sum, w) => sum + w) + gap * (widths.length - 1);
    final overflow = total - lane;
    if (overflow <= 0.0001) break;
    var scaled = 0.0;
    for (var i = 0; i < widths.length; i++) {
      if (!frozen[i]) scaled += bases[i];
    }
    if (scaled <= 0) break;
    var clamped = false;
    for (var i = 0; i < widths.length; i++) {
      if (frozen[i]) continue;
      final next = widths[i] - overflow * bases[i] / scaled;
      if (next <= ResourceStripGeometry.tabMinWidth) {
        widths[i] = ResourceStripGeometry.tabMinWidth;
        frozen[i] = true;
        clamped = true;
      } else {
        widths[i] = next;
      }
    }
    if (!clamped) break;
  }
  return widths;
}

/// `findNearestId` (`resource-tabs.tsx:82-95`): the nearest resource to
/// [index] (right first, then left at each distance) that is in [filter]
/// (or any when null).
String? findNearestResourceId(
  List<HomeResource> resources,
  int index,
  Set<String>? filter,
) {
  for (var offset = 1; offset < resources.length; offset++) {
    for (final candidate in <int>[index + offset, index - offset]) {
      if (candidate < 0 || candidate >= resources.length) continue;
      final id = resources[candidate].selectionId;
      if (filter == null || filter.contains(id)) return id;
    }
  }
  return null;
}

/// `tabDropIndex` for an unpinned strip: the final index for a drop into
/// gap [gapIndex], or null for a no-op.
int? resourceDropIndex(int fromIndex, int gapIndex, int length) {
  final bounded = gapIndex.clamp(0, length);
  final target = bounded > fromIndex ? bounded - 1 : bounded;
  return target == fromIndex ? null : target;
}

/// The resource panel's tab strip (`ResourceTabs`, `resource-tabs.tsx`):
/// floating tabs with single / Shift-range / Cmd-Ctrl-toggle selection,
/// middle-click and Delete closing, close-to-neighbour, multi-close, drag
/// reorder, and drag-out of one tab or the whole selection as
/// [HomeResourceDragData]; then the add control and the end actions.
class ResourceTabStrip extends StatefulWidget {
  const ResourceTabStrip({
    required this.resources,
    required this.activeId,
    required this.onSelect,
    required this.onClose,
    required this.onReorder,
    super.key,
    this.chatId,
    this.activityIds = const <String>{},
    this.addControl,
    this.endActions = const <Widget>[],
  });

  final List<HomeResource> resources;
  final String? activeId;
  final String? chatId;
  final Set<String> activityIds;

  /// `selectResource` (the panel claims the selection).
  final ValueChanged<String> onSelect;

  /// Removes these resources (`removeResource` per target).
  final ValueChanged<List<HomeResource>> onClose;

  /// The strip in its new order (`reorderResources`).
  final ValueChanged<List<HomeResource>> onReorder;

  /// The `+` picker (`AddResourceDropdown`), offset −6px with no tabs.
  final Widget? addControl;
  final List<Widget> endActions;

  @override
  State<ResourceTabStrip> createState() => ResourceTabStripState();
}

class ResourceTabStripState extends State<ResourceTabStrip> {
  Set<String> _selected = <String>{};
  String? _anchor;
  String? _draggingId;
  int? _dropTarget;
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};
  final GlobalKey _laneKey = GlobalKey();

  /// The multi-selection (more than one id), for tests.
  Set<String> get selectedIds => Set<String>.unmodifiable(_selected);

  @override
  void didUpdateWidget(ResourceTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId) {
      // A chat switch keeps this instance; stale ids must not carry over.
      _selected = <String>{};
      _anchor = null;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<HomeResource> get _resources => widget.resources;

  int _indexOf(String id) => _resources.indexWhere((r) => r.selectionId == id);

  /// `handleSelect` (`resource-tabs.tsx:369-420`).
  void select(String id, {bool shift = false, bool toggle = false}) {
    final index = _indexOf(id);
    if (index < 0) return;
    if (shift) {
      final anchorId = _anchor ?? widget.activeId;
      final anchorIndex = anchorId == null ? -1 : _indexOf(anchorId);
      if (anchorIndex != -1) {
        final start = math.min(anchorIndex, index);
        final end = math.max(anchorIndex, index);
        setState(
          () => _selected = <String>{
            for (var i = start; i <= end; i++) _resources[i].selectionId,
          },
        );
        widget.onSelect(id);
        return;
      }
    }
    if (toggle) {
      if (_selected.contains(id)) {
        final next = <String>{..._selected}..remove(id);
        setState(() => _selected = next);
        if (widget.activeId == id) {
          final fallback =
              findNearestResourceId(_resources, index, next) ??
              findNearestResourceId(_resources, index, null);
          if (fallback != null) widget.onSelect(fallback);
        }
      } else {
        setState(() => _selected = <String>{..._selected, id});
        widget.onSelect(id);
      }
      _anchor ??= id;
      return;
    }
    _anchor = id;
    setState(() => _selected = <String>{id});
    widget.onSelect(id);
  }

  void _selectFromPointer(String id) {
    final keyboard = HardwareKeyboard.instance;
    select(
      id,
      shift: keyboard.isShiftPressed,
      toggle: keyboard.isControlPressed || keyboard.isMetaPressed,
    );
  }

  /// `handleClose` (`resource-tabs.tsx:422-470`).
  void close(String id) {
    final index = _indexOf(id);
    if (index < 0) return;
    final resource = _resources[index];
    final isMulti = _selected.contains(id) && _selected.length > 1;
    final targets = isMulti
        ? <HomeResource>[
            for (final r in _resources)
              if (_selected.contains(r.selectionId)) r,
          ]
        : <HomeResource>[resource];
    if (!isMulti && widget.activeId == id) {
      final sameKind = <String>{
        for (final r in _resources)
          if (r.type == resource.type) r.selectionId,
      };
      final next =
          findNearestResourceId(_resources, index, sameKind) ??
          findNearestResourceId(_resources, index, null);
      if (next != null) widget.onSelect(next);
    }
    widget.onClose(targets);
    final removed = <String>{for (final t in targets) t.selectionId};
    setState(() => _selected = _selected.difference(removed));
    if (_anchor != null && removed.contains(_anchor)) _anchor = null;
  }

  /// `handleReorder`.
  void reorder(String id, int targetIndex) {
    final from = _indexOf(id);
    if (from < 0 || from == targetIndex) return;
    final next = <HomeResource>[..._resources];
    final moved = next.removeAt(from);
    next.insert(targetIndex, moved);
    widget.onReorder(next);
  }

  HomeResourceDragData _dragData(HomeResource resource) {
    final selected = <HomeResource>[
      for (final r in _resources)
        if (_selected.contains(r.selectionId)) r,
    ];
    if (selected.length > 1 && _selected.contains(resource.selectionId)) {
      return HomeResourceDragData(selected);
    }
    return HomeResourceDragData(<HomeResource>[resource]);
  }

  KeyEventResult _onTabKey(KeyEvent event, String id) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final index = _indexOf(id);
    if (index < 0) return KeyEventResult.ignored;
    final n = _resources.length;
    final key = event.logicalKey;
    HomeResource? target;
    if (key == LogicalKeyboardKey.arrowLeft) {
      target = _resources[(index - 1 + n) % n];
    } else if (key == LogicalKeyboardKey.arrowRight) {
      target = _resources[(index + 1) % n];
    } else if (key == LogicalKeyboardKey.home) {
      target = _resources.first;
    } else if (key == LogicalKeyboardKey.end) {
      target = _resources.last;
    } else if (key == LogicalKeyboardKey.delete) {
      close(id);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    select(target.selectionId);
    return KeyEventResult.handled;
  }

  /// The strip tab a single-tab drag carries, or null (a multi-selection
  /// or a foreign drag never reorders).
  String? _reorderId(HomeResourceDragData data) {
    if (data.isMulti) return null;
    final id = data.resources.single.selectionId;
    return _indexOf(id) < 0 ? null : id;
  }

  void _onDragMove(DragTargetDetails<HomeResourceDragData> details) {
    final dragged = _reorderId(details.data);
    if (dragged == null) return;
    final pointerX = details.offset.dx;
    var gap = _resources.length;
    for (var i = 0; i < _resources.length; i++) {
      final box = _keys[_resources[i].selectionId]?.currentContext
          ?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final left = box.localToGlobal(Offset.zero).dx;
      if (pointerX < left + box.size.width / 2) {
        gap = i;
        break;
      }
    }
    final from = _indexOf(dragged);
    final target = from < 0
        ? null
        : resourceDropIndex(from, gap, _resources.length);
    if (target != _dropTarget) setState(() => _dropTarget = target);
  }

  /// The tab's content width: chrome plus the title's single-line width.
  double _naturalTabWidth(BuildContext context, HomeResource resource) {
    final painter = TextPainter(
      text: TextSpan(
        text: resourceTabTitle(resource),
        style: SimTheme.of(context).text.caption,
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.maxIntrinsicWidth;
    painter.dispose();
    return ResourceStripGeometry.tabChrome + width;
  }

  bool _isBare(HomeResource r) =>
      r.selectionId != widget.activeId &&
      !(_selected.length > 1 && _selected.contains(r.selectionId));

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final resources = _resources;
    final multi = _selected.length > 1;
    final draggedIndex = _draggingId == null ? -1 : _indexOf(_draggingId!);
    return Semantics(
      identifier: 'home.panel.tabs',
      container: true,
      child: Container(
        height: ResourceStripGeometry.height,
        padding: const EdgeInsets.only(
          left: ResourceStripGeometry.inlineStart,
          right: ResourceStripGeometry.inlineEnd,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final controls =
                (widget.addControl == null
                    ? 0
                    : ResourceStripGeometry.band +
                          ResourceStripGeometry.controlGap) +
                widget.endActions.length *
                    (ResourceStripGeometry.band +
                        ResourceStripGeometry.controlGap);
            final lane = math.max(0, constraints.maxWidth - controls);
            final n = resources.length;
            final widths = fitResourceTabWidths(<double>[
              for (final r in resources) _naturalTabWidth(context, r),
            ], lane.toDouble());
            final tabs = <Widget>[
              for (var i = 0; i < n; i++)
                _buildTab(
                  resources[i],
                  index: i,
                  width: widths[i],
                  multi: multi,
                  showDivider:
                      i > 0 &&
                      _isBare(resources[i]) &&
                      _isBare(resources[i - 1]),
                  showDropBefore:
                      _dropTarget == i && draggedIndex >= 0 && draggedIndex > i,
                  showDropAfter:
                      _dropTarget == i && draggedIndex >= 0 && draggedIndex < i,
                ),
            ];
            return Row(
              spacing: ResourceStripGeometry.controlGap,
              children: <Widget>[
                if (n > 0)
                  Flexible(
                    child: DragTarget<HomeResourceDragData>(
                      key: _laneKey,
                      onWillAcceptWithDetails: (details) =>
                          _reorderId(details.data) != null,
                      onMove: _onDragMove,
                      onLeave: (_) => setState(() => _dropTarget = null),
                      onAcceptWithDetails: (details) {
                        final id = _reorderId(details.data);
                        final target = _dropTarget;
                        setState(() => _dropTarget = null);
                        if (id != null && target != null) reorder(id, target);
                      },
                      builder: (context, candidates, rejected) => SimScrollFade(
                        axis: Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            spacing: ResourceStripGeometry.laneGap,
                            children: tabs,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.addControl != null)
                  Transform.translate(
                    offset: Offset(n == 0 ? -6 : 0, 0),
                    child: widget.addControl,
                  ),
                if (widget.endActions.isNotEmpty) ...<Widget>[
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: ResourceStripGeometry.controlGap,
                    children: widget.endActions,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTab(
    HomeResource resource, {
    required int index,
    required double width,
    required bool multi,
    required bool showDivider,
    required bool showDropBefore,
    required bool showDropAfter,
  }) {
    final id = resource.selectionId;
    final active = id == widget.activeId;
    Widget tab = _ResourceTab(
      key: _keys.putIfAbsent(id, GlobalKey.new),
      resource: resource,
      width: width,
      active: active,
      selected: multi && _selected.contains(id) && !active,
      attention: widget.activityIds.contains(id),
      showDivider: showDivider,
      showDropBefore: showDropBefore,
      showDropAfter: showDropAfter,
      dragging: _draggingId == id,
      focusable: active || (widget.activeId == null && index == 0),
      onSelect: () => _selectFromPointer(id),
      onClose: () => close(id),
      onKeyEvent: (event) => _onTabKey(event, id),
    );
    tab = Draggable<HomeResourceDragData>(
      data: _dragData(resource),
      // The drop gap is read from the pointer, like React's `clientX`.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragFeedback(
        resources: _dragData(resource).resources,
        width: width,
      ),
      onDragStarted: () => setState(() => _draggingId = id),
      onDragEnd: (_) => setState(() {
        _draggingId = null;
        _dropTarget = null;
      }),
      child: tab,
    );
    if (index == 0) {
      tab = Semantics(
        identifier: 'home.panel.tabs.tab',
        container: true,
        child: tab,
      );
    }
    return tab;
  }
}

class _ResourceTab extends StatefulWidget {
  const _ResourceTab({
    required this.resource,
    required this.width,
    required this.active,
    required this.selected,
    required this.attention,
    required this.showDivider,
    required this.showDropBefore,
    required this.showDropAfter,
    required this.dragging,
    required this.focusable,
    required this.onSelect,
    required this.onClose,
    required this.onKeyEvent,
    super.key,
  });

  final HomeResource resource;
  final double width;
  final bool active;
  final bool selected;
  final bool attention;
  final bool showDivider;
  final bool showDropBefore;
  final bool showDropAfter;
  final bool dragging;
  final bool focusable;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final KeyEventResult Function(KeyEvent event) onKeyEvent;

  @override
  State<_ResourceTab> createState() => _ResourceTabState();
}

class _ResourceTabState extends State<_ResourceTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final resource = widget.resource;
    final title = resourceTabTitle(resource);
    final Color fill;
    final Color text;
    if (widget.active) {
      fill = c.surfaceActive;
      text = c.textPrimary;
    } else if (widget.selected) {
      fill = c.surface4;
      text = _hovered ? c.textPrimary : c.textSecondary;
    } else {
      fill = _hovered ? c.surfaceHover : const Color(0x00000000);
      text = _hovered ? c.textPrimary : c.textSecondary;
    }
    final showClose = widget.active || _hovered;
    final button = SimPressable(
      onPressed: widget.onSelect,
      onMiddleTap: widget.onClose,
      skipTraversal: !widget.focusable,
      selected: widget.active,
      semanticsLabel: widget.attention && !widget.active
          ? '$title, Background activity'
          : title,
      onKeyEvent: (node, event) => widget.onKeyEvent(event),
      builder: (context, state) => AnimatedContainer(
        duration: SimMotion.of(SimMotion.colors),
        height: ResourceStripGeometry.band,
        padding: const EdgeInsets.only(left: 8, right: 32),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(SimRadii.lg),
        ),
        child: Row(
          spacing: 6,
          children: <Widget>[
            SimIcon(resourceTabIcon(resource), size: 16, color: c.textIcon),
            Expanded(
              child: SimOverflowText(
                label: title,
                style: sim.text.caption.copyWith(color: text),
              ),
            ),
          ],
        ),
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Opacity(
        opacity: widget.dragging ? 0.3 : 1,
        child: SizedBox(
          width: widget.width,
          height: ResourceStripGeometry.band,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(child: button),
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
                  child: Center(child: _DropLine(color: c.textSubtle)),
                ),
              if (widget.showDropAfter)
                Positioned(
                  right: -1,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _DropLine(color: c.textSubtle)),
                ),
              Positioned(
                right: 2,
                top: 0,
                bottom: 0,
                child: Center(
                  child: showClose
                      ? SimButton(
                          variant: SimButtonVariant.ghostSecondary,
                          size: SimButtonSize.sm,
                          width: 24,
                          height: 24,
                          padding: EdgeInsets.zero,
                          semanticsLabel: 'Close $title',
                          onPressed: widget.onClose,
                          child: const SimIcon(SimIcons.x, size: 11),
                        )
                      : widget.attention && !widget.active
                      ? Padding(
                          padding: const EdgeInsets.only(right: 9),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.brandBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropLine extends StatelessWidget {
  const _DropLine({required this.color});

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

/// The drag image: every dragged tab side by side (`buildMultiDragImage`).
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.resources, required this.width});

  final List<HomeResource> resources;
  final double width;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return IgnorePointer(
      child: Opacity(
        opacity: 0.95,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: <Widget>[
            for (final r in resources)
              Container(
                width: width,
                height: ResourceStripGeometry.band,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: c.surfaceActive,
                  borderRadius: BorderRadius.circular(SimRadii.lg),
                ),
                child: Row(
                  spacing: 6,
                  children: <Widget>[
                    SimIcon(resourceTabIcon(r), size: 16, color: c.textIcon),
                    Expanded(
                      child: Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: sim.text.caption.copyWith(
                          color: c.textPrimary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `TabStripAction variant='subtle'` (26×26): icon actions in the strip.
class ResourceStripAction extends StatelessWidget {
  const ResourceStripAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
    this.tooltip,
  });

  final SimIconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    Widget action = SimButton(
      variant: SimButtonVariant.subtle,
      width: ResourceStripGeometry.band,
      height: ResourceStripGeometry.band,
      padding: EdgeInsets.zero,
      semanticsLabel: label,
      onPressed: onPressed,
      child: SimIcon(icon, size: 16, color: c.textIcon),
    );
    if (tooltip != null) {
      action = SimTooltip(message: tooltip, child: action);
    }
    return action;
  }
}
