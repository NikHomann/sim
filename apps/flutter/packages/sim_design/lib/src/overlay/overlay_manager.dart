import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/z.dart';

/// Why a layer was asked to close (Radix's `onEscapeKeyDown` vs
/// `onPointerDownOutside`).
enum SimDismissReason {
  /// Escape reached the layer.
  escape,

  /// A pointer went down outside the layer's branch.
  outsidePress,

  /// The owner (or anything else) called [SimOverlayEntry.dismiss].
  programmatic,
}

/// One floating layer managed by [SimOverlayHost].
///
/// Mirrors Radix's `DismissableLayer`: a layer closes on a pointer-down
/// outside its [contentKey] widget (and outside any layer that names it as
/// [parent], the way a submenu is a branch of its menu) and on Escape. A
/// [modal] layer swallows outside pointer events; a non-modal one lets them
/// reach the surface underneath while still dismissing.
class SimOverlayEntry {
  SimOverlayEntry({
    required this.builder,
    this.z = SimZ.popover,
    this.dismissOnOutsideTap = true,
    this.dismissOnEscape = true,
    this.modal = false,
    this.parent,
    this.onDismissRequested,
    this.onRemoved,
    GlobalKey? contentKey,
  }) : contentKey = contentKey ?? GlobalKey(debugLabel: 'SimOverlayEntry');

  final WidgetBuilder builder;

  /// Position on the [SimZ] ladder; equal values keep insertion order.
  final int z;
  final bool dismissOnOutsideTap;
  final bool dismissOnEscape;
  final bool modal;
  final SimOverlayEntry? parent;

  /// Called when the host wants this layer closed. When null the host removes
  /// the entry directly; owners that animate out set it and call [remove].
  final VoidCallback? onDismissRequested;
  final VoidCallback? onRemoved;

  /// Attach to the layer's visible content; its bounds define "inside".
  final GlobalKey contentKey;

  SimOverlayController? _controller;
  int _sequence = 0;

  bool get isMounted => _controller != null;

  /// Why the current (or last) dismissal was requested; read it inside
  /// [onDismissRequested] to tell Escape from an outside press.
  SimDismissReason get dismissReason => _dismissReason;
  SimDismissReason _dismissReason = SimDismissReason.programmatic;

  /// Requests dismissal the way an outside tap or Escape would.
  void dismiss({SimDismissReason reason = SimDismissReason.programmatic}) {
    _dismissReason = reason;
    if (onDismissRequested != null) {
      onDismissRequested!();
    } else {
      remove();
    }
  }

  /// Removes the layer immediately.
  void remove() => _controller?._remove(this);

  /// Re-runs [builder].
  void markNeedsBuild() => _controller?._notify();

  bool _contains(Offset hostLocal) {
    final box = contentKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return false;
    final host = _controller?._hostBox;
    if (host == null) return false;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: host);
    return (topLeft & box.size).contains(hostLocal);
  }

  bool _isAncestorOf(SimOverlayEntry other) {
    for (var p = other.parent; p != null; p = p.parent) {
      if (identical(p, this)) return true;
    }
    return false;
  }
}

/// The enter/exit tween of one floating layer, shared between the entry's
/// dismiss callback (which reverses it) and the layer's [State], which owns
/// the [AnimationController] because it supplies the vsync, and disposes it.
/// The holder itself needs no disposal: [SimOverlayEntry.onRemoved] runs
/// before the layer is unmounted, so it must outlive the State.
class SimLayerAnimation {
  AnimationController? controller;
  bool _closing = false;

  /// Reverses the tween and calls [onDone] once it has; at once when there is
  /// no controller yet or motion is disabled. A second call is a no-op.
  void close(VoidCallback onDone) {
    if (_closing) return;
    _closing = true;
    final c = controller;
    if (c == null || SimMotion.disabled) {
      onDone();
      return;
    }
    c.reverse().whenCompleteOrCancel(onDone);
  }
}

/// Owns the ordered layer list of one [SimOverlayHost].
class SimOverlayController extends ChangeNotifier {
  final List<SimOverlayEntry> _entries = <SimOverlayEntry>[];
  int _counter = 0;
  RenderBox? _hostBox;
  bool _disposed = false;

  List<SimOverlayEntry> get entries =>
      List<SimOverlayEntry>.unmodifiable(_entries);

  bool get hasModalLayer => _entries.any((e) => e.modal);

  /// Inserts [entry] at its [SimOverlayEntry.z] position.
  void insert(SimOverlayEntry entry) {
    assert(entry._controller == null, 'entry is already shown');
    entry
      .._controller = this
      .._sequence = _counter++;
    _entries
      ..add(entry)
      ..sort((a, b) {
        final byZ = a.z.compareTo(b.z);
        return byZ != 0 ? byZ : a._sequence.compareTo(b._sequence);
      });
    _notify();
  }

  void _remove(SimOverlayEntry entry) {
    if (!_entries.remove(entry)) return;
    entry._controller = null;
    entry.onRemoved?.call();
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    if (_phase == SchedulerPhase.idle ||
        _phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      scheduleMicrotask(() {
        if (!_disposed) notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final entry in _entries) {
      entry._controller = null;
    }
    _entries.clear();
    super.dispose();
  }

  SchedulerPhase get _phase => WidgetsBinding.instance.schedulerPhase;

  /// Whether the Escape key event being dispatched right now was already
  /// handled by the host's hardware-keyboard handler. The focus system then
  /// raises a [DismissIntent] for the same key press (an [EditableText]
  /// forwards it from its own action map), and the layer's dismiss action
  /// must not close a second layer for it.
  bool _escapeConsumed = false;

  void _consumeEscape() {
    _escapeConsumed = true;
    // Both dispatches of one key press run synchronously; the next microtask
    // is after them and before any later key press.
    scheduleMicrotask(() => _escapeConsumed = false);
  }

  /// Converts a global offset into the host's coordinate space.
  Offset globalToHost(Offset global) =>
      _hostBox?.globalToLocal(global) ?? global;

  /// The host's size (the "viewport" for collision handling).
  Size get hostSize => _hostBox?.size ?? Size.zero;

  /// Rect of [context]'s render box in host coordinates.
  Rect rectOf(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: _hostBox);
    return topLeft & box.size;
  }

  /// Dismisses the topmost layer that dismisses on Escape; `true` if one did.
  bool dismissTopmostOnEscape() {
    for (final entry in _entries.reversed) {
      if (entry.dismissOnEscape) {
        entry.dismiss(reason: SimDismissReason.escape);
        return true;
      }
      if (entry.modal) return true;
    }
    return false;
  }

  void _handlePointerDown(Offset hostLocal) {
    // Walk from the top. A layer whose content (or any branch of it) holds the
    // point stops the walk: the tap belongs to it. A modal layer stops the
    // walk after dismissing itself, since nothing beneath it can be reached.
    for (final entry in _entries.reversed.toList()) {
      final insideBranch =
          entry._contains(hostLocal) ||
          _entries.any((e) => entry._isAncestorOf(e) && e._contains(hostLocal));
      if (insideBranch) return;
      if (entry.dismissOnOutsideTap) {
        entry.dismiss(reason: SimDismissReason.outsidePress);
      }
      if (entry.modal) return;
    }
  }
}

/// Provides the [SimOverlayController] to descendants.
class SimOverlay extends InheritedWidget {
  const SimOverlay({
    required this.controller,
    required super.child,
    super.key,
  });

  final SimOverlayController controller;

  static SimOverlayController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SimOverlay>();
    assert(
      scope != null,
      'No SimOverlayHost found above this widget. Wrap the app (e.g. in '
      'MaterialApp.builder) with SimOverlayHost.',
    );
    return scope!.controller;
  }

  static SimOverlayController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SimOverlay>()?.controller;

  @override
  bool updateShouldNotify(SimOverlay oldWidget) =>
      controller != oldWidget.controller;
}

/// The overlay manager: stacks every [SimOverlayEntry] above [child] by the
/// [SimZ] ladder and closes layers on outside pointer-down and Escape.
///
/// Place it once near the root, inside the [MediaQuery]/[Directionality] the
/// app provides (for example from `MaterialApp.builder`).
class SimOverlayHost extends StatefulWidget {
  const SimOverlayHost({required this.child, super.key, this.controller});

  final Widget child;
  final SimOverlayController? controller;

  @override
  State<SimOverlayHost> createState() => _SimOverlayHostState();
}

class _SimOverlayHostState extends State<SimOverlayHost> {
  late SimOverlayController _controller =
      widget.controller ?? SimOverlayController();
  final GlobalKey _stackKey = GlobalKey(debugLabel: 'SimOverlayHost');

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void didUpdateWidget(SimOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller &&
        widget.controller != null) {
      _controller.removeListener(_rebuild);
      _controller = widget.controller!;
      _controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _controller.removeListener(_rebuild);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    _controller._consumeEscape();
    return _controller.dismissTopmostOnEscape();
  }

  void _onPointerDown(PointerDownEvent event) {
    final box = _stackKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    _controller._hostBox = box;
    _controller._handlePointerDown(box.globalToLocal(event.position));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _controller.entries;
    return SimOverlay(
      controller: _controller,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        child: Stack(
          key: _stackKey,
          fit: StackFit.passthrough,
          children: <Widget>[
            _HostBoxBinder(controller: _controller, child: widget.child),
            for (final entry in entries)
              Positioned.fill(
                child: _LayerScope(
                  controller: _controller,
                  entry: entry,
                  // A nested stack so a layer may position itself with
                  // Positioned (the toast stack does) or fill the host.
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[Builder(builder: entry.builder)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Records the host's render box on the controller after layout.
class _HostBoxBinder extends SingleChildRenderObjectWidget {
  const _HostBoxBinder({required this.controller, required super.child});

  final SimOverlayController controller;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHostBoxBinder(controller);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderHostBoxBinder renderObject,
  ) {
    renderObject.controller = controller;
  }
}

class _RenderHostBoxBinder extends RenderProxyBox {
  _RenderHostBoxBinder(this.controller);

  SimOverlayController controller;

  @override
  void performLayout() {
    super.performLayout();
    final p = parent;
    controller._hostBox = p is RenderBox ? p : this;
  }
}

/// The environment every layer needs and the [Navigator] would otherwise
/// provide, since the host sits outside it: an [Overlay] for text selection
/// handles, toolbars and magnifiers, and a [DismissIntent] target so Escape
/// inside an [EditableText] resolves to an action. A modal layer also traps
/// focus inside itself; layers below stay inert.
class _LayerScope extends StatelessWidget {
  const _LayerScope({
    required this.controller,
    required this.entry,
    required this.child,
  });

  final SimOverlayController controller;
  final SimOverlayEntry entry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var body = child;
    if (entry.modal) {
      body = FocusScope(
        debugLabel: 'SimOverlay modal',
        child: FocusTraversalGroup(child: body),
      );
    }
    return Actions(
      actions: <Type, Action<Intent>>{
        DismissIntent: _DismissLayerAction(controller),
      },
      child: Overlay.wrap(child: body),
    );
  }
}

/// Escape raised as a [DismissIntent] closes the topmost layer, unless the
/// host's key handler already did so for the same key press.
class _DismissLayerAction extends DismissAction {
  _DismissLayerAction(this.controller);

  final SimOverlayController controller;

  @override
  Object? invoke(DismissIntent intent) {
    if (!controller._escapeConsumed) controller.dismissTopmostOnEscape();
    return null;
  }
}

/// Full-screen barrier used by modal layers: absorbs pointer events outside
/// the content and paints [color] (`bg-black/10`), optionally blurred.
///
/// It fills whatever it is placed in (a layer's expanding [Stack]), so it may
/// sit under any wrapper. [opacity] scales both the tint and the blur: an
/// [Opacity] ancestor would blank the backdrop the blur samples, so a fade
/// must go through this parameter.
class SimOverlayBarrier extends StatelessWidget {
  const SimOverlayBarrier({
    super.key,
    this.color = const Color(0x1A000000),
    this.blurSigma = 0,
    this.opacity = 1,
  });

  final Color color;
  final double blurSigma;

  /// `0..1`, the enter/exit progress of the layer.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final t = opacity.clamp(0.0, 1.0);
    final sigma = blurSigma * t;
    Widget barrier = ColoredBox(color: color.withValues(alpha: color.a * t));
    if (sigma > 0) {
      barrier = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: barrier,
      );
    }
    return Semantics(
      container: true,
      child: AbsorbPointer(child: SizedBox.expand(child: barrier)),
    );
  }
}
