import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/home/panel/panel_geometry.dart';
import 'package:sim_design/sim_design.dart';

/// `RESOURCE_HEADER_CLASSES.layout` (`resource-tab-controls.ts:6`).
abstract final class ResourceHeaderGeometry {
  static const double controlsHeight = 40;
  static const double endInset = 16;
  static const double fixedReserve = 52;
  static const double toggleHitSize = 40;
  static const double toggleSize = 30;

  /// `adjacentEndPosition`: 16 + 40 + 1.
  static const double adjacentEnd = endInset + toggleHitSize + 1;
}

/// The panel's open/close easing `cubic-bezier(0.25,0.1,0.25,1)`.
const Curve panelCurve = Cubic(0.25, 0.1, 0.25, 1);

/// The panel's open/close duration.
const Duration panelDuration = Duration(milliseconds: 200);

/// `ChatPanelLayout` + `ChatPanelContent` (`chat-panel-layout.tsx`): the row
/// of chat column, divider and resource panel, with the collapse toggle
/// overlaid at the row's top-right, and the divider's drag and keyboard
/// resizing (`use-mothership-resize.ts`).
///
/// The panel is 50% of the row unless [preferredWidth] (the stored or
/// dragged px width) overrides it; that preference is re-clamped to
/// [maxPanelWidth] on every layout without a transition. Opening and
/// closing animate the width 200ms unless [skipTransition] or motion is
/// off.
class ChatPanelLayout extends StatefulWidget {
  const ChatPanelLayout({
    required this.chat,
    required this.panel,
    required this.collapsed,
    required this.onToggle,
    required this.onCommitWidth,
    super.key,
    this.preferredWidth,
    this.skipTransition = false,
    this.activityCount = 0,
    this.label = 'resource view',
    this.onResizeStart,
    this.onPanelInteraction,
  });

  final Widget chat;
  final Widget panel;
  final bool collapsed;
  final VoidCallback onToggle;

  /// A drag finished or a key moved the divider: remember this width.
  final ValueChanged<double> onCommitWidth;
  final double? preferredWidth;
  final bool skipTransition;

  /// Resources updated while collapsed (the toggle's dot).
  final int activityCount;
  final String label;

  /// A pointer went down on the divider.
  final VoidCallback? onResizeStart;

  /// Any pointer or key inside the panel (`onPointerDownCapture`).
  final VoidCallback? onPanelInteraction;

  @override
  State<ChatPanelLayout> createState() => ChatPanelLayoutState();
}

class ChatPanelLayoutState extends State<ChatPanelLayout>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: panelDuration,
    value: 1,
  );
  double _animateFrom = 0;

  /// The width the panel was last laid out at.
  double _renderedWidth = 0;
  double _rowWidth = 0;
  double _maxWidth = 0;

  // Drag state (single-flight).
  int? _dragPointer;
  PanelDragGeometry? _geometry;
  double? _lastGlobalX;
  double? _dragWidth;
  bool _frameScheduled = false;
  OverlayEntry? _cursorOverlay;

  final FocusNode _handleFocus = FocusNode(debugLabel: 'Resize resource view');
  bool _handleFocusVisible = false;

  /// The width the panel renders at now.
  double get renderedWidth => _renderedWidth;
  bool get isDragging => _dragPointer != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleFocus.addListener(_onHandleFocus);
  }

  @override
  void didUpdateWidget(ChatPanelLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapsed != widget.collapsed) {
      if (widget.collapsed) _cancelDrag();
      if (widget.skipTransition || SimMotion.disabled) {
        _open.value = 1;
      } else {
        _animateFrom = _renderedWidth;
        unawaited(
          _open.forward(from: 0).orCancel.catchError((Object _) {}),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeCursorOverlay();
    _handleFocus
      ..removeListener(_onHandleFocus)
      ..dispose();
    _open.dispose();
    super.dispose();
  }

  /// Window blur commits a live drag (`window` `blur` listener).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && isDragging) _finishDrag(true);
  }

  void _onHandleFocus() {
    final visible =
        _handleFocus.hasFocus &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (visible != _handleFocusVisible) {
      setState(() => _handleFocusVisible = visible);
    }
  }

  double _targetWidth(double viewport, double row) => resolvePanelWidth(
    collapsed: widget.collapsed,
    preferred: widget.preferredWidth,
    viewportWidth: viewport,
    containerWidth: row,
  );

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton || widget.collapsed) return;
    if (_dragPointer != null) return;
    final rowBox = context.findRenderObject();
    if (rowBox is! RenderBox) return;
    widget.onResizeStart?.call();
    final panelRight = rowBox.localToGlobal(Offset(rowBox.size.width, 0)).dx;
    final startLeft = panelRight - _renderedWidth;
    _dragPointer = event.pointer;
    _geometry = PanelDragGeometry(
      panelRight: panelRight,
      grabOffset: event.position.dx - startLeft,
      maxWidth: _maxWidth,
    );
    _lastGlobalX = null;
    setState(() => _dragWidth = _renderedWidth);
    _insertCursorOverlay();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _dragPointer) return;
    _lastGlobalX = event.position.dx;
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _frameScheduled = false;
      final x = _lastGlobalX;
      final geometry = _geometry;
      if (!mounted || x == null || geometry == null || !isDragging) return;
      setState(() => _dragWidth = panelWidthAt(x, geometry));
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _dragPointer) _finishDrag(true);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _dragPointer) _finishDrag(false);
  }

  void _cancelDrag() {
    if (isDragging) _finishDrag(false);
  }

  void _finishDrag(bool commit) {
    final x = _lastGlobalX;
    final geometry = _geometry;
    _dragPointer = null;
    _geometry = null;
    _lastGlobalX = null;
    _removeCursorOverlay();
    if (commit && x != null && geometry != null) {
      widget.onCommitWidth(panelWidthAt(x, geometry));
    }
    if (mounted) setState(() => _dragWidth = null);
  }

  void _insertCursorOverlay() {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _cursorOverlay = OverlayEntry(
      builder: (context) => const Positioned.fill(
        child: MouseRegion(cursor: SystemMouseCursors.resizeLeftRight),
      ),
    );
    overlay.insert(_cursorOverlay!);
  }

  void _removeCursorOverlay() {
    _cursorOverlay?.remove();
    _cursorOverlay = null;
  }

  KeyEventResult _onHandleKey(FocusNode node, KeyEvent event) {
    if (isDragging || widget.collapsed) return KeyEventResult.ignored;
    final key = readSeparatorKey(event);
    if (key == null) return KeyEventResult.ignored;
    final width = keyboardPanelWidth(key, _renderedWidth, _maxWidth);
    // Written instantly: the next key reads it before the next layout,
    // like React's fresh `getBoundingClientRect`.
    _renderedWidth = width;
    widget.onResizeStart?.call();
    widget.onCommitWidth(width);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final row = constraints.maxWidth;
        _rowWidth = row;
        _maxWidth = maxPanelWidth(viewport, row);
        return AnimatedBuilder(
          animation: _open,
          builder: (context, _) {
            final target = _dragWidth ?? _targetWidth(viewport, row);
            final t = panelCurve.transform(_open.value);
            final width = _open.value >= 1
                ? target
                : _animateFrom + (target - _animateFrom) * t;
            _renderedWidth = math.max(0, width);
            return _buildRow(context, _renderedWidth);
          },
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, double panelWidth) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final collapsed = widget.collapsed;
    final showBorder = panelWidth > 0.5;
    // The content keeps its open width while the box animates or sits at 0
    // (clipped), so it never lays out squeezed to nothing.
    final openWidth = resolvePanelWidth(
      collapsed: false,
      preferred: widget.preferredWidth,
      viewportWidth: MediaQuery.sizeOf(context).width,
      containerWidth: _rowWidth,
    );
    final contentWidth = math
        .max(
          0,
          math.max(_dragWidth ?? panelWidth, openWidth) - 1,
        )
        .toDouble();
    Widget panel = Container(
      width: panelWidth,
      padding: EdgeInsets.only(left: showBorder ? 1 : 0),
      decoration: BoxDecoration(color: c.bg),
      clipBehavior: Clip.hardEdge,
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: contentWidth,
        maxWidth: contentWidth,
        child: widget.panel,
      ),
    );
    if (showBorder) {
      panel = PixelSnappedLeftBorder(color: c.border, child: panel);
    }
    panel = Listener(
      onPointerDown: (_) => widget.onPanelInteraction?.call(),
      child: panel,
    );
    if (collapsed) {
      // `inert`: no focus, no pointer, no semantics while collapsed.
      panel = ExcludeFocus(
        child: IgnorePointer(child: ExcludeSemantics(child: panel)),
      );
    }
    return Semantics(
      identifier: 'home.row',
      container: true,
      child: ColoredBox(
        color: c.bg,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: widget.chat),
                  Semantics(
                    identifier: panelWidth > 0 ? 'home.panel' : null,
                    container: true,
                    child: panel,
                  ),
                ],
              ),
            ),
            // A 0px panel's semantics node has an empty rect and is dropped
            // from the tree; React still reports the collapsed panel's box
            // (row right edge, 0 wide), so a hair-wide stand-in carries the
            // id at that edge.
            if (panelWidth <= 0)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 0.01,
                child: Semantics(
                  identifier: 'home.panel',
                  container: true,
                  child: const SizedBox.expand(),
                ),
              ),
            if (!collapsed)
              Positioned(
                top: 0,
                bottom: 0,
                left: _rowWidth - panelWidth - 4,
                width: 8,
                child: _buildHandle(c),
              ),
            // The 30px button sits 16px from the edge; its invisible 40px
            // hit area (`::after`) is centred on it.
            Positioned(
              top: 0,
              right:
                  ResourceHeaderGeometry.endInset -
                  (ResourceHeaderGeometry.toggleHitSize -
                          ResourceHeaderGeometry.toggleSize) /
                      2,
              height: ResourceHeaderGeometry.controlsHeight,
              child: Center(child: _buildToggle(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(SimColors c) {
    final min = math.min(panelMinWidth, _maxWidth).round();
    return Semantics(
      identifier: 'home.panel.resize-handle',
      container: true,
      label: 'Resize ${widget.label}',
      value: '${_renderedWidth.round()}',
      hint: 'min $min, max ${_maxWidth.round()}',
      slider: true,
      child: Focus(
        focusNode: _handleFocus,
        onKeyEvent: _onHandleKey,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: _handleFocusVisible
                    ? Border.all(color: c.selection, width: 2)
                    : null,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final collapsed = widget.collapsed;
    final count = widget.activityCount;
    final label =
        '${collapsed ? 'Expand' : 'Collapse'} ${widget.label}'
        '${collapsed && count > 0 ? ', $count resource${count == 1 ? '' : 's'} updated' : ''}';
    return SizedBox.square(
      dimension: ResourceHeaderGeometry.toggleHitSize,
      child: SimPressable(
        onPressed: widget.onToggle,
        semanticsLabel: label,
        builder: (context, state) => Center(
          child: Semantics(
            identifier: 'home.panel.toggle',
            container: true,
            child: AnimatedContainer(
              duration: SimMotion.of(SimMotion.colors),
              width: ResourceHeaderGeometry.toggleSize,
              height: ResourceHeaderGeometry.toggleSize,
              decoration: BoxDecoration(
                color: state.hovered
                    ? c.surfaceActive
                    : const Color(0x00000000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Transform.flip(
                      flipX: true,
                      child: SimIcon(
                        SimEmcnIcons.panelLeft,
                        size: 16,
                        color: c.textIcon,
                      ),
                    ),
                    if (collapsed && count > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Semantics(
                          identifier: 'home.panel.toggle.dot',
                          container: true,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 1px left border painted on the device pixel grid, like Chrome's
/// pixel-snapped `border-l`: a panel whose edge falls on a half pixel
/// (`w-1/2` of an odd row, x 832.5 at 1440) gets a crisp line on the rounded
/// column (833) instead of two half-tone columns.
class PixelSnappedLeftBorder extends SingleChildRenderObjectWidget {
  const PixelSnappedLeftBorder({
    required this.color,
    super.key,
    super.child,
  });

  final Color color;

  @override
  RenderPixelSnappedLeftBorder createRenderObject(BuildContext context) =>
      RenderPixelSnappedLeftBorder(color);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPixelSnappedLeftBorder renderObject,
  ) {
    renderObject.color = color;
  }
}

/// Paints [color] as a 1px column at the rounded global x of its left edge,
/// over its child.
class RenderPixelSnappedLeftBorder extends RenderProxyBox {
  RenderPixelSnappedLeftBorder(this._color);

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!hasSize || size.isEmpty) return;
    final globalX = localToGlobal(Offset.zero).dx;
    final snap = globalX.roundToDouble() - globalX;
    context.canvas.drawRect(
      Rect.fromLTWH(offset.dx + snap, offset.dy, 1, size.height),
      Paint()..color = _color,
    );
  }
}
