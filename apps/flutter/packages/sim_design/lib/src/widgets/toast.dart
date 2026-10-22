import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/overlay/overlay_manager.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/tokens/z.dart';
import 'package:sim_design/src/widgets/button.dart';
import 'package:sim_design/src/widgets/chip/chip.dart';
import 'package:sim_design/src/widgets/chip/chrome.dart';

/// `ToastVariant`; the leading icon alone signals intent.
enum SimToastVariant { standard, info, success, warning, error }

SimIconData simToastIcon(SimToastVariant variant) => switch (variant) {
  SimToastVariant.standard => SimIcons.bell,
  SimToastVariant.info => SimIcons.circleInfo,
  SimToastVariant.success => SimIcons.circleCheck,
  SimToastVariant.warning => SimIcons.triangleAlert,
  SimToastVariant.error => SimIcons.circleAlert,
};

class SimToastAction {
  const SimToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// One toast (`ToastData`).
class SimToastData {
  const SimToastData({
    required this.id,
    required this.message,
    required this.variant,
    required this.duration,
    required this.persistAcrossRoutes,
    this.description,
    this.action,
    this.onDismiss,
    this.onUserDismiss,
    this.semanticsIdentifier,
  });

  final String id;
  final String message;
  final String? description;
  final SimToastVariant variant;
  final SimToastAction? action;

  /// Auto-dismiss delay; zero or negative persists.
  final Duration duration;
  final bool persistAcrossRoutes;

  /// Called once when the toast leaves the stack, however it was dismissed.
  final VoidCallback? onDismiss;

  /// Called when the user closes the toast or selects its action.
  final VoidCallback? onUserDismiss;

  /// `Semantics.identifier` on the toast card (e.g. `shell.toast.saved`);
  /// no visual effect.
  final String? semanticsIdentifier;
}

/// `orderToastStack`: front-to-back paint order — newest first, except that
/// ongoing status toasts (persistent, no action) sit behind every other toast
/// so a later status never hides an earlier toast's action.
List<SimToastData> orderToastStack(List<SimToastData> toasts) {
  bool isOngoingStatus(SimToastData t) =>
      t.duration <= Duration.zero && t.action == null;
  final newestFirst = toasts.reversed.toList();
  return <SimToastData>[
    ...newestFirst.where((t) => !isOngoingStatus(t)),
    ...newestFirst.where(isOngoingStatus),
  ];
}

/// The toast store (`ToastProvider` state): add, dismiss, dismiss all, sweep
/// on route change, and the eviction rule — beyond three toasts the oldest
/// auto-dismissable one is evicted first so a persistent toast is never
/// silently dropped. Actionable toasts persist unless given a `duration`.
class SimToasts extends ChangeNotifier {
  SimToasts({String Function()? idGenerator})
    : _nextId = idGenerator ?? _defaultId;

  static const Duration autoDismiss = Duration(seconds: 5);

  /// A process-wide instance for imperative `toast()` calls.
  static final SimToasts instance = SimToasts();

  final String Function() _nextId;
  final List<SimToastData> _toasts = <SimToastData>[];
  int _counter = 0;

  static int _globalCounter = 0;
  static String _defaultId() => 'toast-${++_globalCounter}';

  List<SimToastData> get toasts => List<SimToastData>.unmodifiable(_toasts);

  String show(
    String message, {
    String? description,
    SimToastVariant variant = SimToastVariant.standard,
    SimToastAction? action,
    Duration? duration,
    bool persistAcrossRoutes = false,
    VoidCallback? onDismiss,
    VoidCallback? onUserDismiss,
    String? semanticsIdentifier,
  }) {
    _counter++;
    final data = SimToastData(
      id: _nextId(),
      message: message,
      description: description,
      variant: variant,
      action: action,
      duration: duration ?? (action != null ? Duration.zero : autoDismiss),
      persistAcrossRoutes: persistAcrossRoutes,
      onDismiss: onDismiss,
      onUserDismiss: onUserDismiss,
      semanticsIdentifier: semanticsIdentifier,
    );
    _toasts.add(data);
    if (_toasts.length > SimLayout.toastStackLimit) {
      var evict = _toasts.indexWhere((t) => t.duration > Duration.zero);
      if (evict == -1) evict = 0;
      final removed = _toasts.removeAt(evict);
      removed.onDismiss?.call();
    }
    notifyListeners();
    return data.id;
  }

  String success(
    String message, {
    String? description,
    SimToastAction? action,
    Duration? duration,
    String? semanticsIdentifier,
  }) => show(
    message,
    description: description,
    variant: SimToastVariant.success,
    action: action,
    duration: duration,
    semanticsIdentifier: semanticsIdentifier,
  );
  String error(
    String message, {
    String? description,
    SimToastAction? action,
    Duration? duration,
    String? semanticsIdentifier,
  }) => show(
    message,
    description: description,
    variant: SimToastVariant.error,
    action: action,
    duration: duration,
    semanticsIdentifier: semanticsIdentifier,
  );
  String warning(
    String message, {
    String? description,
    SimToastAction? action,
    Duration? duration,
    String? semanticsIdentifier,
  }) => show(
    message,
    description: description,
    variant: SimToastVariant.warning,
    action: action,
    duration: duration,
    semanticsIdentifier: semanticsIdentifier,
  );
  String info(
    String message, {
    String? description,
    SimToastAction? action,
    Duration? duration,
    String? semanticsIdentifier,
  }) => show(
    message,
    description: description,
    variant: SimToastVariant.info,
    action: action,
    duration: duration,
    semanticsIdentifier: semanticsIdentifier,
  );

  void dismiss(String id) {
    final index = _toasts.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final removed = _toasts.removeAt(index);
    removed.onDismiss?.call();
    notifyListeners();
  }

  void dismissAll() {
    if (_toasts.isEmpty) return;
    final removed = List<SimToastData>.of(_toasts);
    _toasts.clear();
    for (final t in removed) {
      t.onDismiss?.call();
    }
    notifyListeners();
  }

  /// Route change: clears everything not flagged `persistAcrossRoutes`.
  void sweepRoute() {
    final removed = _toasts.where((t) => !t.persistAcrossRoutes).toList();
    if (removed.isEmpty) return;
    _toasts.removeWhere((t) => !t.persistAcrossRoutes);
    for (final t in removed) {
      t.onDismiss?.call();
    }
    notifyListeners();
  }

  int get count => _counter;
}

/// Geometry of one card in the stack (`ToastGeometry`).
class SimToastGeometry {
  const SimToastGeometry({
    required this.y,
    required this.scale,
    required this.height,
    required this.zIndex,
  });

  /// Lift from the bottom anchor (negative = upward).
  final double y;
  final double scale;
  final double height;
  final int zIndex;
}

/// `ToastProvider`'s layout: collapsed cards peek 13px above the front one and
/// shrink 5% per depth, clamped to the front card's height; expanded cards
/// fan out at their natural heights with 8px gaps.
List<SimToastGeometry> layoutToastStack(
  List<SimToastData> ordered,
  Map<String, double> heights, {
  required bool expanded,
}) {
  final frontHeight = ordered.isEmpty
      ? SimLayout.toastEstimatedHeight
      : heights[ordered.first.id] ?? SimLayout.toastEstimatedHeight;
  var cumulative = 0.0;
  final out = <SimToastGeometry>[];
  for (var index = 0; index < ordered.length; index++) {
    final natural =
        heights[ordered[index].id] ?? SimLayout.toastEstimatedHeight;
    final before = cumulative;
    cumulative += natural + SimLayout.toastExpandGap;
    out.add(
      SimToastGeometry(
        y: expanded ? -before : -index * SimLayout.toastCollapsedOffset,
        scale: expanded ? 1 : 1 - index * SimLayout.toastCollapsedScaleStep,
        height: expanded || index == 0 ? natural : frontHeight,
        zIndex: ordered.length - index,
      ),
    );
  }
  return out;
}

/// Port of `packages/emcn/src/components/toast/toast.tsx`'s viewport: mounts
/// the stack bottom-right at [SimZ.toast] (280px cards, 16px inset, or 12px
/// from a content boundary), fans it open on hover, pauses auto-dismiss
/// while hovered, animates reshuffles over 0.4s on `[0.22, 1, 0.36, 1]`.
/// Place it once in the app shell inside a [SimOverlayHost].
class SimToastStack extends StatefulWidget {
  const SimToastStack({
    super.key,
    this.controller,
    this.boundaryInsets,
    this.semanticsIdentifier,
  });

  final SimToasts? controller;

  /// `Semantics.identifier` on the notifications region.
  final String? semanticsIdentifier;

  /// Right/bottom distance of a content boundary from the viewport edge; the
  /// stack then sits 12px inside it instead of 16px from the viewport.
  final EdgeInsets? boundaryInsets;

  @override
  State<SimToastStack> createState() => _SimToastStackState();
}

class _SimToastStackState extends State<SimToastStack> {
  SimToasts get _toasts => widget.controller ?? SimToasts.instance;
  SimOverlayEntry? _entry;
  SimOverlayController? _overlay;
  final Map<String, Timer> _timers = <String, Timer>{};
  final Map<String, double> _heights = <String, double>{};
  final List<SimToastData> _leaving = <SimToastData>[];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _toasts.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overlay = SimOverlay.maybeOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(SimToastStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? SimToasts.instance).removeListener(_sync);
      _toasts.addListener(_sync);
    }
    _entry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _toasts.removeListener(_sync);
    for (final t in _timers.values) {
      t.cancel();
    }
    _entry?.remove();
    super.dispose();
  }

  void _sync() {
    final live = _toasts.toasts;
    final liveIds = live.map((t) => t.id).toSet();
    // Toasts that left the store animate out before being dropped.
    for (final id in _heights.keys.toList()) {
      if (!liveIds.contains(id) && !_leaving.any((t) => t.id == id)) {
        _heights.remove(id);
      }
    }
    if (live.isEmpty) _expanded = false;
    _reconcileTimers(live);
    final overlay = _overlay;
    final visible = live.isNotEmpty || _leaving.isNotEmpty;
    if (visible && _entry == null && overlay != null) {
      final entry = SimOverlayEntry(
        z: SimZ.toast,
        dismissOnOutsideTap: false,
        dismissOnEscape: false,
        builder: (context) => _ToastLayer(state: this),
      );
      _entry = entry;
      overlay.insert(entry);
    } else if (!visible && _entry != null) {
      _entry!.remove();
      _entry = null;
    } else {
      _entry?.markNeedsBuild();
    }
    if (mounted) setState(() {});
  }

  void _reconcileTimers(List<SimToastData> live) {
    if (live.isEmpty || _expanded) {
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
      return;
    }
    for (final t in live) {
      if (t.duration <= Duration.zero || _timers.containsKey(t.id)) continue;
      // Wall-clock, never motion-scaled: auto-dismiss is a timeout, not a
      // transition.
      _timers[t.id] = Timer(t.duration, () {
        _timers.remove(t.id);
        _dismiss(t.id);
      });
    }
    for (final id in _timers.keys.toList()) {
      if (!live.any((t) => t.id == id)) {
        _timers.remove(id)?.cancel();
      }
    }
  }

  void _dismiss(String id) {
    final data = _toasts.toasts.where((t) => t.id == id).firstOrNull;
    if (data != null) {
      _leaving.add(data);
      Timer(SimMotion.of(SimMotion.toastExit), () {
        _leaving.removeWhere((t) => t.id == id);
        _heights.remove(id);
        _sync();
      });
    }
    _toasts.dismiss(id);
  }

  void _setExpanded(bool value) {
    if (_expanded == value) return;
    _expanded = value;
    _reconcileTimers(_toasts.toasts);
    _entry?.markNeedsBuild();
  }

  void _measure(String id, double height) {
    if (_heights[id] == height) return;
    _heights[id] = height;
    _entry?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ToastLayer extends StatelessWidget {
  const _ToastLayer({required this.state});

  final _SimToastStackState state;

  @override
  Widget build(BuildContext context) {
    final live = state._toasts.toasts;
    final ordered = orderToastStack(live);
    final leaving = state._leaving;
    final geometry = layoutToastStack(
      ordered,
      state._heights,
      expanded: state._expanded,
    );
    final frontHeight = ordered.isEmpty
        ? SimLayout.toastEstimatedHeight
        : state._heights[ordered.first.id] ?? SimLayout.toastEstimatedHeight;
    final collapsedHeight =
        frontHeight +
        math.max(0, math.min(ordered.length, SimLayout.toastStackLimit) - 1) *
            SimLayout.toastCollapsedOffset;
    var expandedHeight = 0.0;
    for (final g in geometry) {
      expandedHeight = math.max(expandedHeight, -g.y + g.height);
    }
    final containerHeight = state._expanded
        ? (ordered.isEmpty ? frontHeight : expandedHeight)
        : collapsedHeight;
    final viewport = MediaQuery.maybeOf(context)?.size.width ?? 1280;
    final width = math.min(viewport - 32, SimLayout.toastWidth);
    final boundary = state.widget.boundaryInsets;
    final right = boundary == null
        ? SimLayout.toastViewportInset
        : boundary.right + SimLayout.toastBoundaryInset;
    final bottom = boundary == null
        ? SimLayout.toastViewportInset
        : boundary.bottom + SimLayout.toastBoundaryInset;
    final cards = <Widget>[];
    for (var i = ordered.length - 1; i >= 0; i--) {
      final toast = ordered[i];
      final g = geometry[i];
      cards.add(
        _ToastCard(
          key: ValueKey<String>(toast.id),
          toast: toast,
          geometry: g,
          width: width,
          leaving: false,
          onDismiss: () {
            toast.onUserDismiss?.call();
            state._dismiss(toast.id);
          },
          onMeasure: (h) => state._measure(toast.id, h),
        ),
      );
    }
    for (final toast in leaving) {
      cards.add(
        _ToastCard(
          key: ValueKey<String>('leaving-${toast.id}'),
          toast: toast,
          geometry: SimToastGeometry(
            y: 0,
            scale: 1,
            height: state._heights[toast.id] ?? SimLayout.toastEstimatedHeight,
            zIndex: 0,
          ),
          width: width,
          leaving: true,
          onDismiss: () {},
          onMeasure: (_) {},
        ),
      );
    }
    return Positioned(
      right: right,
      bottom: bottom,
      width: width,
      height: containerHeight,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'Notifications',
        identifier: state.widget.semanticsIdentifier,
        child: MouseRegion(
          onEnter: (_) => state._setExpanded(true),
          onExit: (_) => state._setExpanded(false),
          child: Stack(clipBehavior: Clip.none, children: cards),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.toast,
    required this.geometry,
    required this.width,
    required this.leaving,
    required this.onDismiss,
    required this.onMeasure,
    super.key,
  });

  final SimToastData toast;
  final SimToastGeometry geometry;
  final double width;
  final bool leaving;
  final VoidCallback onDismiss;
  final ValueChanged<double> onMeasure;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: SimMotion.of(SimMotion.toastStack),
    value: SimMotion.disabled ? 1 : 0,
  );
  final GlobalKey _contentKey = GlobalKey();
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    if (!SimMotion.disabled) unawaited(_enter.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(_ToastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _report() {
    final box = _contentKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize && mounted) {
      widget.onMeasure(box.size.height + 2 * SimLayout.borderWidth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final g = widget.geometry;
    final radius = g.height <= SimRadii.toastCompactMaxHeight
        ? SimRadii.toastCompact
        : SimRadii.toast;
    final duration = SimMotion.of(SimMotion.toastStack);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: _ToastContent(
            key: _contentKey,
            toast: widget.toast,
            expanded: _hovered,
            onDismiss: widget.onDismiss,
          ),
        ),
      ),
    );
    Widget body = AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final t = SimMotion.toast.transform(_enter.value);
        return Opacity(
          opacity: widget.leaving ? 1 : t,
          child: Transform.translate(
            offset: Offset(0, widget.leaving ? 0 : (1 - t) * g.height),
            child: child,
          ),
        );
      },
      child: card,
    );
    if (widget.leaving) {
      body = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1, end: 0),
        duration: SimMotion.of(SimMotion.toastExit),
        curve: SimMotion.easeIn,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.scale(scale: 0.95 + 0.05 * v, child: child),
        ),
        child: body,
      );
    }
    return AnimatedPositioned(
      duration: duration,
      curve: SimMotion.toast,
      right: 0,
      bottom: -g.y,
      width: widget.width,
      height: g.height,
      child: AnimatedScale(
        duration: duration,
        curve: SimMotion.toast,
        scale: g.scale,
        alignment: Alignment.bottomCenter,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: widget.toast.semanticsIdentifier == null
              ? body
              : Semantics(
                  container: true,
                  identifier: widget.toast.semanticsIdentifier,
                  child: body,
                ),
        ),
      ),
    );
  }
}

/// The card body: message (2 lines, revealed on hover), description (3 lines,
/// revealed on hover), optional full-width action chip; p-2 gap-2.
class _ToastContent extends StatelessWidget {
  const _ToastContent({
    required this.toast,
    required this.expanded,
    required this.onDismiss,
    super.key,
  });

  final SimToastData toast;
  final bool expanded;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final messageStyle = sim.text
        .style(14, height: 20 / 14)
        .copyWith(color: c.textBody);
    final descriptionStyle = sim.text
        .style(13, height: 18 / 13)
        .copyWith(color: c.textMuted);
    final body = _body(messageStyle, descriptionStyle, c);
    if (SimMotion.disabled) return body;
    return AnimatedSize(
      duration: SimMotion.of(SimMotion.toastResize),
      curve: SimMotion.toast,
      alignment: Alignment.topCenter,
      child: body,
    );
  }

  Widget _body(
    TextStyle messageStyle,
    TextStyle descriptionStyle,
    SimColors c,
  ) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: <Widget>[
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    WidgetSpan(
                      alignment: PlaceholderAlignment.top,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: SizedBox(
                          height: 20,
                          child: Center(
                            child: SimIcon(
                              simToastIcon(toast.variant),
                              size: SimChipChrome.contentIconSize,
                              color: c.textIcon,
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextSpan(text: toast.message),
                  ],
                ),
                style: messageStyle,
                maxLines: expanded ? null : 2,
                overflow: expanded ? TextOverflow.visible : TextOverflow.fade,
              ),
            ),
            SizedBox(
              height: 20,
              child: Center(
                child: SimButton(
                  variant: SimButtonVariant.quiet,
                  size: SimButtonSize.icon,
                  semanticsLabel: 'Dismiss notification',
                  onPressed: onDismiss,
                  child: const SimIcon(
                    SimIcons.x,
                    size: 16,
                    strokeWidth: 1.25,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (toast.description != null)
          Text(
            toast.description!,
            style: descriptionStyle,
            maxLines: expanded ? null : 3,
            overflow: expanded ? TextOverflow.visible : TextOverflow.fade,
          ),
        if (toast.action != null)
          SimChip(
            label: toast.action!.label,
            fullWidth: true,
            alignment: MainAxisAlignment.center,
            variant: SimChipVariant.filled,
            onPressed: () {
              toast.action!.onPressed();
              onDismiss();
            },
          ),
      ],
    ),
  );
}
