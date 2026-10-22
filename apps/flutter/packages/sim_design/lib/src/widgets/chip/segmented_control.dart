import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/interaction/pressable.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/widgets/chip/chrome.dart';
import 'package:sim_design/src/widgets/scroll_fade.dart';

/// `size` of a segmented control: 30px, or 22px for dense settings rows.
enum SimSegmentedSize { standard, compact }

/// One segment.
class SimSegment<T> {
  const SimSegment({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final Widget label;
  final SimIconData? icon;
  final bool enabled;
}

/// Port of `packages/emcn/src/components/chip/segmented-control.ts`: the
/// 30px segmented chip shared by `ChipSwitch` and `ChipButtonGroup`. The
/// trough is the chip filled fill with a 2px inset; the selected segment
/// keeps its raised `--surface-2` (dark `--surface-6`) surface through hover.
/// Arrow keys move the selection the way a Radix radio group does.
class SimSegmentedControl<T> extends StatefulWidget {
  const SimSegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
    this.enabled = true,
    this.size = SimSegmentedSize.standard,
    this.gap = 0,
    this.semanticsLabel,
  });

  final List<SimSegment<T>> segments;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final SimSegmentedSize size;

  /// `gap: 'none'` (0) for `ChipSwitch`, `'sm'` (2) for `ChipButtonGroup`.
  final double gap;
  final String? semanticsLabel;

  @override
  State<SimSegmentedControl<T>> createState() => _SimSegmentedControlState<T>();
}

class _SimSegmentedControlState<T> extends State<SimSegmentedControl<T>> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(SimSegment<T> segment) {
    if (!widget.enabled || !segment.enabled) return;
    if (segment.value != widget.value) widget.onChanged(segment.value);
  }

  KeyEventResult _arrow(KeyEvent event, int index) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    int step;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown) {
      step = 1;
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp) {
      step = -1;
    } else {
      return KeyEventResult.ignored;
    }
    final n = widget.segments.length;
    for (var i = 1; i <= n; i++) {
      final candidate = widget.segments[(index + step * i + n * i) % n];
      if (candidate.enabled) {
        _select(candidate);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final compact = widget.size == SimSegmentedSize.compact;
    final height = compact ? 22.0 : SimChipChrome.height;
    final children = <Widget>[];
    for (var i = 0; i < widget.segments.length; i++) {
      final segment = widget.segments[i];
      final active = segment.value == widget.value;
      children.add(
        _Segment(
          active: active,
          enabled: widget.enabled && segment.enabled,
          compact: compact,
          icon: segment.icon,
          onPressed: () => _select(segment),
          onKeyEvent: (node, event) => _arrow(event, i),
          focusable: active || (widget.value == null && i == 0),
          child: segment.label,
        ),
      );
    }
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: SimChipChrome.filledFill(c),
          borderRadius: BorderRadius.circular(SimChipChrome.radius),
        ),
        child: SimScrollFade(
          axis: Axis.horizontal,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: widget.gap,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.active,
    required this.enabled,
    required this.compact,
    required this.onPressed,
    required this.onKeyEvent,
    required this.focusable,
    required this.child,
    this.icon,
  });

  final bool active;
  final bool enabled;
  final bool compact;
  final SimIconData? icon;
  final VoidCallback onPressed;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;
  final bool focusable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return SimPressable(
      onPressed: onPressed,
      enabled: enabled,
      selected: active,
      skipTraversal: !focusable,
      onKeyEvent: onKeyEvent,
      builder: (context, state) {
        final isDark = c.brightness == Brightness.dark;
        final fill = active
            ? (isDark ? c.surface6 : c.surface2)
            : const Color(0x00000000);
        final text = active
            ? c.textBody
            : (state.hovered ? c.textBody : c.textMuted);
        final style = (compact ? sim.text.xs : sim.text.sm).copyWith(
          color: text,
        );
        return Opacity(
          opacity: enabled ? 1 : SimChipChrome.disabledOpacity,
          child: AnimatedContainer(
            duration: SimMotion.of(SimMotion.colors),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : SimChipChrome.paddingX,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(SimRadii.segment),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: SimChipChrome.gap,
              children: <Widget>[
                if (icon != null) SimIcon(icon!, color: c.textIcon),
                DefaultTextStyle.merge(
                  style: style,
                  maxLines: 1,
                  softWrap: false,
                  child: child,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
