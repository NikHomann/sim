import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sim_app/features/workspace_shell/chrome/sidebar_controller.dart';
import 'package:sim_design/sim_design.dart';

/// `SidebarChromeContext` (`sidebar-chrome-context.tsx`): what the hosted
/// sidebar reads from the chrome. Hover-peek never activates on web and
/// Windows (`workspace-chrome.tsx:240`), so [isPeeking] is always false here.
class SidebarChromeScope extends InheritedWidget {
  const SidebarChromeScope({
    required this.isCollapsed,
    required this.onToggle,
    required super.child,
    super.key,
    this.isPeeking = false,
  });

  final bool isCollapsed;
  final bool isPeeking;
  final VoidCallback onToggle;

  static SidebarChromeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SidebarChromeScope>();

  @override
  bool updateShouldNotify(SidebarChromeScope oldWidget) =>
      isCollapsed != oldWidget.isCollapsed ||
      isPeeking != oldWidget.isPeeking ||
      onToggle != oldWidget.onToggle;
}

/// The chrome row (`workspace-chrome.tsx:317-411`): the sidebar shell at the
/// rail width, the content pane with its 1px `--border` left edge on `--bg`,
/// and the 8px resize strip centred on the rail's right edge.
///
/// Dragging writes a per-frame width into a [ValueNotifier] that only the
/// rail box and the strip listen to, so neither the sidebar nor the content
/// subtree rebuilds during the drag; the width is committed (clamped and
/// persisted) once, on release, cancel or window blur.
class SidebarFrame extends StatefulWidget {
  const SidebarFrame({
    required this.controller,
    required this.sidebar,
    required this.content,
    super.key,
    this.fullscreen = false,
  });

  final SidebarController controller;
  final Widget sidebar;
  final Widget content;

  /// `/upgrade`: sidebar width 0 and inert, pane without its border.
  final bool fullscreen;

  @override
  State<SidebarFrame> createState() => _SidebarFrameState();
}

class _SidebarFrameState extends State<SidebarFrame>
    with WidgetsBindingObserver {
  final ValueNotifier<double?> _dragWidth = ValueNotifier<double?>(null);
  final GlobalKey _rowKey = GlobalKey(debugLabel: 'shell.chrome');
  int? _dragPointer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(SidebarFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onController);
    _dragWidth.dispose();
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  /// Window blur ends a drag like `pointercancel` (`use-sidebar-resize.ts`).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _endDrag();
  }

  double get _viewportWidth => MediaQuery.sizeOf(context).width;

  void _startDrag(PointerDownEvent event) {
    if (widget.controller.isCollapsed || widget.fullscreen) return;
    if (event.buttons != kPrimaryButton) return;
    _dragPointer = event.pointer;
    _dragWidth.value = widget.controller.renderedWidth(_viewportWidth);
  }

  void _moveDrag(PointerMoveEvent event) {
    if (event.pointer != _dragPointer) return;
    final box = _rowKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final x = box.globalToLocal(event.position).dx;
    _dragWidth.value = x.clamp(
      SidebarWidth.min,
      getMaxSidebarWidth(_viewportWidth),
    );
  }

  void _endDrag() {
    final last = _dragWidth.value;
    _dragPointer = null;
    if (last == null) return;
    _dragWidth.value = null;
    widget.controller.setSidebarWidth(last, viewportWidth: _viewportWidth);
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final controller = widget.controller;
    final collapsed = controller.isCollapsed;
    final fullscreen = widget.fullscreen;
    final committed = fullscreen
        ? 0.0
        : controller.renderedWidth(_viewportWidth);

    Widget rail = SidebarChromeScope(
      isCollapsed: collapsed,
      onToggle: controller.toggleCollapsed,
      child: widget.sidebar,
    );
    if (fullscreen) {
      rail = ExcludeSemantics(
        child: ExcludeFocus(child: IgnorePointer(child: rail)),
      );
    }

    final pane = Semantics(
      identifier: 'shell.content',
      container: true,
      child: Semantics(
        identifier: 'shell.content.pane',
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.bg,
            border: fullscreen
                ? null
                : Border(
                    left: BorderSide(
                      color: c.border,
                    ),
                  ),
          ),
          // `border-l` inside a border-box: the content starts after the
          // 1px border, so an opaque page cannot paint over the divider.
          child: Padding(
            padding: EdgeInsets.only(left: fullscreen ? 0 : 1),
            child: ClipRect(child: widget.content),
          ),
        ),
      ),
    );

    return ValueListenableBuilder<double?>(
      valueListenable: _dragWidth,
      child: rail,
      builder: (context, drag, railChild) {
        final width = drag ?? committed;
        return MouseRegion(
          cursor: drag != null
              ? SystemMouseCursors.resizeLeftRight
              : MouseCursor.defer,
          child: Stack(
            key: _rowKey,
            children: <Widget>[
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      identifier: 'shell.sidebar.shell',
                      container: true,
                      child: SizedBox(
                        width: width,
                        child: ClipRect(child: railChild),
                      ),
                    ),
                    Expanded(child: pane),
                  ],
                ),
              ),
              if (!fullscreen)
                Positioned(
                  left: width - SimLayout.sidebarResizeHandle / 2,
                  top: 0,
                  bottom: 0,
                  width: SimLayout.sidebarResizeHandle,
                  child: _ResizeHandle(
                    collapsed: collapsed,
                    onExpand: controller.toggleCollapsed,
                    onPointerDown: _startDrag,
                    onPointerMove: _moveDrag,
                    onPointerEnd: _endDrag,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// `shell.sidebar.resize-handle` (`sidebar.tsx:1916-1930`): transparent, an
/// `ew-resize` separator while expanded, an `e-resize` "Expand sidebar"
/// button while collapsed (click, Enter and Space expand). Always focusable.
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.collapsed,
    required this.onExpand,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerEnd,
  });

  final bool collapsed;
  final VoidCallback onExpand;
  final void Function(PointerDownEvent) onPointerDown;
  final void Function(PointerMoveEvent) onPointerMove;
  final VoidCallback onPointerEnd;

  @override
  Widget build(BuildContext context) {
    final strip = MouseRegion(
      cursor: collapsed
          ? SystemMouseCursors.resizeRight
          : SystemMouseCursors.resizeLeftRight,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: collapsed ? null : onPointerDown,
        onPointerMove: collapsed ? null : onPointerMove,
        onPointerUp: collapsed ? null : (_) => onPointerEnd(),
        onPointerCancel: collapsed ? null : (_) => onPointerEnd(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: collapsed ? onExpand : null,
          child: const SizedBox.expand(),
        ),
      ),
    );
    return Semantics(
      identifier: 'shell.sidebar.resize-handle',
      container: true,
      button: collapsed,
      label: collapsed ? 'Expand sidebar' : 'Resize sidebar',
      onTap: collapsed ? onExpand : null,
      child: Focus(
        onKeyEvent: (node, event) {
          if (!collapsed) return KeyEventResult.ignored;
          return handleKeyboardActivation(event, onExpand);
        },
        child: strip,
      ),
    );
  }
}
