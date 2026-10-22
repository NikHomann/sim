import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/interaction/keyboard.dart';

/// Interaction flags handed to a [SimPressable] builder.
class SimInteractionState {
  const SimInteractionState({
    required this.hovered,
    required this.focused,
    required this.pressed,
    required this.enabled,
  });

  static const SimInteractionState idle = SimInteractionState(
    hovered: false,
    focused: false,
    pressed: false,
    enabled: true,
  );

  /// Pointer hover from a mouse (`hover-hover:`); never set by touch.
  final bool hovered;

  /// Keyboard focus with the focus highlight visible (`:focus-visible`).
  final bool focused;
  final bool pressed;
  final bool enabled;

  SimInteractionState copyWith({
    bool? hovered,
    bool? focused,
    bool? pressed,
    bool? enabled,
  }) => SimInteractionState(
    hovered: hovered ?? this.hovered,
    focused: focused ?? this.focused,
    pressed: pressed ?? this.pressed,
    enabled: enabled ?? this.enabled,
  );
}

typedef SimInteractionBuilder =
    Widget Function(BuildContext context, SimInteractionState state);

/// The one interactive primitive every emcn control is built on: hover via
/// [MouseRegion], press via [GestureDetector], keyboard activation on Enter
/// and Space (`lib/keyboard.ts`), focus tracking, a context-menu hook, and
/// button semantics. It paints nothing itself.
class SimPressable extends StatefulWidget {
  const SimPressable({
    required this.builder,
    super.key,
    this.onPressed,
    this.onSecondaryTapDown,
    this.onMiddleTap,
    this.onLongPress,
    this.enabled = true,
    this.cursor,
    this.focusNode,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.skipTraversal = false,
    this.semanticsLabel,
    this.isLink = false,
    this.selected,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.onHoverChanged,
    this.onFocusChanged,
    this.onKeyEvent,
    this.excludeSemantics = false,
  });

  final SimInteractionBuilder builder;
  final VoidCallback? onPressed;

  /// Right click (`onContextMenu`), with the global pointer position.
  final void Function(Offset globalPosition)? onSecondaryTapDown;

  /// Middle click (`onAuxClick` button 1).
  final VoidCallback? onMiddleTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final MouseCursor? cursor;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool canRequestFocus;
  final bool skipTraversal;
  final String? semanticsLabel;
  final bool isLink;
  final bool? selected;
  final HitTestBehavior hitTestBehavior;
  final ValueChanged<bool>? onHoverChanged;
  final ValueChanged<bool>? onFocusChanged;

  /// Runs before the activation keys; return `handled` to swallow a key.
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final bool excludeSemantics;

  @override
  State<SimPressable> createState() => _SimPressableState();
}

class _SimPressableState extends State<SimPressable> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;
  FocusNode? _ownedNode;

  FocusNode get _node =>
      widget.focusNode ??
      (_ownedNode ??= FocusNode(debugLabel: 'SimPressable'));

  bool get _interactive => widget.enabled && widget.onPressed != null;

  @override
  void didUpdateWidget(SimPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && (_hovered || _pressed)) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  void dispose() {
    _ownedNode?.dispose();
    super.dispose();
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHoverChanged?.call(value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final custom = widget.onKeyEvent?.call(node, event);
    if (custom == KeyEventResult.handled) return KeyEventResult.handled;
    if (!_interactive) return KeyEventResult.ignored;
    return handleKeyboardActivation(event, widget.onPressed!);
  }

  @override
  Widget build(BuildContext context) {
    final state = SimInteractionState(
      hovered: _hovered && widget.enabled,
      focused: _focused && isFocusVisibleMode,
      pressed: _pressed && widget.enabled,
      enabled: widget.enabled,
    );
    final cursor =
        widget.cursor ??
        (!widget.enabled
            ? SystemMouseCursors.forbidden
            : (_interactive || widget.onSecondaryTapDown != null)
            ? SystemMouseCursors.click
            : MouseCursor.defer);

    var child = widget.builder(context, state);
    child = Listener(
      onPointerDown: widget.onMiddleTap == null
          ? null
          : (event) {
              if (event.kind == PointerDeviceKind.mouse &&
                  event.buttons == kMiddleMouseButton &&
                  widget.enabled) {
                widget.onMiddleTap!();
              }
            },
      child: GestureDetector(
        behavior: widget.hitTestBehavior,
        onTapDown: _interactive ? (_) => _setPressed(true) : null,
        onTapUp: _interactive ? (_) => _setPressed(false) : null,
        onTapCancel: _interactive ? () => _setPressed(false) : null,
        onTap: _interactive ? widget.onPressed : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        onSecondaryTapDown: widget.onSecondaryTapDown == null || !widget.enabled
            ? null
            : (details) => widget.onSecondaryTapDown!(details.globalPosition),
        child: child,
      ),
    );
    child = MouseRegion(
      cursor: cursor,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: child,
    );
    child = Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      canRequestFocus: widget.canRequestFocus && widget.enabled,
      skipTraversal: widget.skipTraversal,
      onKeyEvent: _handleKey,
      onFocusChange: (value) {
        setState(() => _focused = value);
        widget.onFocusChanged?.call(value);
      },
      child: child,
    );
    if (widget.excludeSemantics) return child;
    return Semantics(
      container: true,
      button: !widget.isLink,
      link: widget.isLink,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.semanticsLabel,
      onTap: _interactive ? widget.onPressed : null,
      child: child,
    );
  }
}
