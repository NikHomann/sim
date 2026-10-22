import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/overlay/overlay_manager.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/breakpoints.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/tokens/z.dart';
import 'package:sim_design/src/widgets/button.dart';
import 'package:sim_design/src/widgets/fields/editable.dart';

/// `MODAL_SIZES`: max widths 440 / 500 / 600 / 800 / 1200 at 90vw (95vw full).
enum SimModalSize { sm, md, lg, xl, full }

double simModalMaxWidth(SimModalSize size) => switch (size) {
  SimModalSize.sm => SimLayout.modalSm,
  SimModalSize.md => SimLayout.modalMd,
  SimModalSize.lg => SimLayout.modalLg,
  SimModalSize.xl => SimLayout.modalXl,
  SimModalSize.full => SimLayout.modalFull,
};

/// Handle to an open modal.
class SimModalHandle<T> {
  SimModalHandle._(this._entry, this._result);

  final SimOverlayEntry _entry;
  final Completer<T?> _result;

  Future<T?> get closed => _result.future;
  bool get isOpen => _entry.isMounted;

  /// Closes the modal with an optional result (plays the exit animation).
  void close([T? result]) {
    if (!_result.isCompleted) _result.complete(result);
    _entry.dismiss();
  }
}

/// Scope read by modal content: dismissal, the dismiss interlock, and the
/// registry of text inputs for initial focus (`focusFirstTextInput`).
class SimModalScope extends InheritedWidget {
  const SimModalScope({
    required this.close,
    required this.dismissDisabled,
    required this.registry,
    required super.child,
    super.key,
  });

  final void Function([Object? result]) close;
  final bool dismissDisabled;
  final SimModalRegistry registry;

  static SimModalScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SimModalScope>();

  static SimModalScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No SimModalScope above this widget');
    return scope!;
  }

  /// `useModalDismissDisabled`.
  static bool dismissDisabledOf(BuildContext context) =>
      maybeOf(context)?.dismissDisabled ?? false;

  @override
  bool updateShouldNotify(SimModalScope oldWidget) =>
      dismissDisabled != oldWidget.dismissDisabled ||
      registry != oldWidget.registry;
}

/// Tracks the text inputs mounted inside a modal so initial focus can land on
/// the first one, with the caret at the end.
class SimModalRegistry {
  final List<SimEditableState> _inputs = <SimEditableState>[];
  bool _focusedInitially = false;

  void register(SimEditableState input) {
    if (!_inputs.contains(input)) _inputs.add(input);
    if (!_focusedInitially) {
      _focusedInitially = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (input.mounted) input.focus();
      });
    }
  }

  void unregister(SimEditableState input) => _inputs.remove(input);

  bool get hasInputs => _inputs.isNotEmpty;
}

/// Registers a [SimEditable] with the enclosing modal for initial focus.
class SimModalAutoFocus extends StatefulWidget {
  const SimModalAutoFocus({
    required this.editableKey,
    required this.child,
    super.key,
  });

  final GlobalKey<SimEditableState> editableKey;
  final Widget child;

  @override
  State<SimModalAutoFocus> createState() => _SimModalAutoFocusState();
}

class _SimModalAutoFocusState extends State<SimModalAutoFocus> {
  SimModalRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = SimModalScope.maybeOf(context)?.registry;
    if (registry != _registry) {
      final state = widget.editableKey.currentState;
      if (state != null) _registry?.unregister(state);
      _registry = registry;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final s = widget.editableKey.currentState;
        if (s != null && mounted) _registry?.register(s);
      });
    }
  }

  @override
  void dispose() {
    final state = widget.editableKey.currentState;
    if (state != null) _registry?.unregister(state);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Port of `packages/emcn/src/components/modal/modal.tsx`: a centred dialog
/// over a `bg-black/10` overlay blurred 2px, zooming in from 95% over 200ms,
/// closed by Escape and outside taps unless `dismissDisabled`. The content
/// box is `rounded-xl` on `--bg` with a 1px foreground/10 ring, at most 84vh
/// tall, 90vw wide up to the size cap. [bare] strips the chrome so a
/// self-styled surface (`SimChipModal`) owns its appearance.
///
/// [sidebarInset] reproduces `padding-left: var(--sidebar-width)` so sizes up
/// to `xl` centre within the content area; `full` ignores it.
Future<T?> showSimModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  SimModalSize size = SimModalSize.md,
  bool bare = false,
  bool Function()? dismissDisabled,
  String? semanticsLabel,
  double sidebarInset = 0,
  Color? overlayColor,
  double overlayBlur = SimLayout.modalOverlayBlur,
}) => openSimModal<T>(
  context,
  builder: builder,
  size: size,
  bare: bare,
  dismissDisabled: dismissDisabled,
  semanticsLabel: semanticsLabel,
  sidebarInset: sidebarInset,
  overlayColor: overlayColor,
  overlayBlur: overlayBlur,
).closed;

/// Like [showSimModal] but returns the handle so the caller can close it.
SimModalHandle<T> openSimModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  SimModalSize size = SimModalSize.md,
  bool bare = false,
  bool Function()? dismissDisabled,
  String? semanticsLabel,
  double sidebarInset = 0,
  Color? overlayColor,
  double overlayBlur = SimLayout.modalOverlayBlur,
}) {
  final overlay = SimOverlay.of(context);
  final result = Completer<T?>();
  final animation = SimLayerAnimation();
  final registry = SimModalRegistry();
  late final SimOverlayEntry entry;
  late final SimModalHandle<T> handle;
  entry = SimOverlayEntry(
    z: SimZ.modal,
    modal: true,
    onDismissRequested: () {
      if (dismissDisabled?.call() ?? false) return;
      if (!result.isCompleted) result.complete(null);
      animation.close(entry.remove);
    },
    onRemoved: () {
      if (!result.isCompleted) result.complete(null);
    },
    builder: (context) => _ModalLayer(
      animation: animation,
      size: size,
      bare: bare,
      dismissDisabled: dismissDisabled,
      semanticsLabel: semanticsLabel,
      sidebarInset: sidebarInset,
      overlayColor: overlayColor,
      overlayBlur: overlayBlur,
      contentKey: entry.contentKey,
      registry: registry,
      close: ([value]) => handle.close(value as T?),
      builder: builder,
    ),
  );
  handle = SimModalHandle<T>._(entry, result);
  overlay.insert(entry);
  return handle;
}

class _ModalLayer extends StatefulWidget {
  const _ModalLayer({
    required this.animation,
    required this.size,
    required this.bare,
    required this.dismissDisabled,
    required this.semanticsLabel,
    required this.sidebarInset,
    required this.overlayColor,
    required this.overlayBlur,
    required this.contentKey,
    required this.registry,
    required this.close,
    required this.builder,
  });

  final SimLayerAnimation animation;
  final SimModalSize size;
  final bool bare;
  final bool Function()? dismissDisabled;
  final String? semanticsLabel;
  final double sidebarInset;
  final Color? overlayColor;
  final double overlayBlur;
  final GlobalKey contentKey;
  final SimModalRegistry registry;
  final void Function([Object? result]) close;
  final WidgetBuilder builder;

  @override
  State<_ModalLayer> createState() => _ModalLayerState();
}

class _ModalLayerState extends State<_ModalLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SimMotion.of(SimMotion.modal),
    value: SimMotion.disabled ? 1 : 0,
  );
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'SimModal');

  @override
  void initState() {
    super.initState();
    widget.animation.controller = _controller;
    if (!SimMotion.disabled) unawaited(_controller.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scope.requestFocus();
      // No text input claimed focus: move to the first focusable control.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.registry.hasInputs) _scope.nextFocus();
      });
    });
  }

  @override
  void dispose() {
    if (widget.animation.controller == _controller) {
      widget.animation.controller = null;
    }
    _controller.dispose();
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final media = MediaQuery.maybeOf(context);
    final viewport = media?.size ?? const Size(1280, 800);
    final mobile = SimBreakpoints.isMobile(viewport.width);
    final full = widget.size == SimModalSize.full;
    final widthFraction = full
        ? SimLayout.modalFullWidthFraction
        : SimLayout.modalWidthFraction;
    final maxWidth = simModalMaxWidth(widget.size);
    final ringColor = sim.isDark
        ? SimColors.white.withValues(alpha: 0.1)
        : SimColors.black.withValues(alpha: 0.1);
    final dismissDisabled = widget.dismissDisabled?.call() ?? false;

    Widget content = SimModalScope(
      close: widget.close,
      dismissDisabled: dismissDisabled,
      registry: widget.registry,
      child: Builder(builder: widget.builder),
    );
    content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: viewport.width * widthFraction < maxWidth
            ? viewport.width * widthFraction
            : maxWidth,
        maxHeight: viewport.height * SimLayout.modalMaxHeightFraction,
      ),
      child: DefaultTextStyle.merge(
        style: sim.text.small.copyWith(color: c.textPrimary),
        child: widget.bare
            ? content
            : ClipRRect(
                borderRadius: BorderRadius.circular(SimRadii.modal),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(SimRadii.modal),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: ringColor,
                        spreadRadius: SimLayout.borderWidth,
                      ),
                    ],
                  ),
                  child: content,
                ),
              ),
      ),
    );
    content = KeyedSubtree(key: widget.contentKey, child: content);
    content = FocusScope(
      node: _scope,
      child: FocusTraversalGroup(
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: widget.semanticsLabel,
          explicitChildNodes: true,
          child: content,
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            SimOverlayBarrier(
              color: widget.overlayColor ?? const Color(0x1A000000),
              blurSigma: widget.overlayBlur,
              opacity: t,
            ),
            Padding(
              padding: EdgeInsets.only(
                left: full || mobile ? 0 : widget.sidebarInset,
              ),
              child: Center(
                child: Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: SimMotion.zoomStart + (1 - SimMotion.zoomStart) * t,
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: content,
    );
  }
}

/// `ModalHeader`: title (text-base `--text-primary`, leading none) and the
/// close button (ghost, 16px glyph, 14px extended hit area); px-4 pt-4 pb-2.
class SimModalHeader extends StatelessWidget {
  const SimModalHeader({required this.title, super.key, this.showClose = true});

  final String title;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final scope = SimModalScope.maybeOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        spacing: 8,
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: sim.text
                  .style(15, height: 1)
                  .copyWith(color: c.textPrimary),
            ),
          ),
          if (showClose)
            SimButton(
              variant: SimButtonVariant.ghost,
              width: 16,
              height: 16,
              padding: EdgeInsets.zero,
              hitSlop: const EdgeInsets.all(14),
              enabled: !(scope?.dismissDisabled ?? false),
              semanticsLabel: 'Close',
              onPressed: scope?.close,
              child: const SimIcon(SimIcons.x, size: 16),
            ),
        ],
      ),
    );
  }
}

/// `ModalBody`: the scrolling content area, px-4 pt-3 pb-4.
class SimModalBody extends StatelessWidget {
  const SimModalBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Flexible(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: child,
    ),
  );
}

/// `ModalFooter`: right-aligned actions on a `--surface-3` @ 50% bar with a
/// top `--border`, px-4 py-3.
class SimModalFooter extends StatelessWidget {
  const SimModalFooter({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface3.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 8,
        children: children,
      ),
    );
  }
}

/// `ModalTabsList` + `ModalTabsTrigger`: text-small tabs (px-1 pb-2,
/// `--text-secondary`, active `--text-primary`) under a 1px sliding indicator.
class SimModalTabs extends StatelessWidget {
  const SimModalTabs({
    required this.tabs,
    required this.value,
    required this.onChanged,
    super.key,
    this.enabled = true,
  });

  final List<SimModalTab> tabs;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
          child: Row(
            spacing: 16,
            children: <Widget>[
              for (final tab in tabs)
                _ModalTabTrigger(
                  label: tab.label,
                  active: tab.value == value,
                  onPressed: () => onChanged(tab.value),
                  textColor: c.textSecondary,
                  activeColor: c.textPrimary,
                  style: sim.text.small,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SimModalTab {
  const SimModalTab({required this.value, required this.label});

  final String value;
  final String label;
}

class _ModalTabTrigger extends StatefulWidget {
  const _ModalTabTrigger({
    required this.label,
    required this.active,
    required this.onPressed,
    required this.textColor,
    required this.activeColor,
    required this.style,
  });

  final String label;
  final bool active;
  final VoidCallback onPressed;
  final Color textColor;
  final Color activeColor;
  final TextStyle style;

  @override
  State<_ModalTabTrigger> createState() => _ModalTabTriggerState();
}

class _ModalTabTriggerState extends State<_ModalTabTrigger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPressed,
      child: Semantics(
        button: true,
        selected: widget.active,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
              child: AnimatedDefaultTextStyle(
                duration: SimMotion.of(SimMotion.colors),
                style: widget.style.copyWith(
                  color: widget.active || _hovered
                      ? widget.activeColor
                      : widget.textColor,
                ),
                child: Text(widget.label),
              ),
            ),
            AnimatedContainer(
              duration: SimMotion.of(SimMotion.modalTabIndicator),
              curve: SimMotion.easeOut,
              height: 1,
              color: widget.active
                  ? widget.activeColor
                  : const Color(0x00000000),
            ),
          ],
        ),
      ),
    ),
  );
}
