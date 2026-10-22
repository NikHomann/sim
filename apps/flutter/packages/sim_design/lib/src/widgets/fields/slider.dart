import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/shadows.dart';
import 'package:sim_design/src/widgets/fields/toggles.dart';

/// Port of `packages/emcn/src/components/slider/slider.tsx`: a 6px
/// `--border` track with a `--text-primary` range and a 14px round thumb with
/// `shadow-xs` and a 15px extended hit area; arrow keys step, Home/End jump,
/// PageUp/PageDown move ten steps (Radix defaults).
class SimSlider extends StatefulWidget {
  const SimSlider({
    required this.value,
    super.key,
    this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.enabled = true,
    this.semanticsLabel,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final double step;
  final bool enabled;
  final String? semanticsLabel;

  @override
  State<SimSlider> createState() => _SimSliderState();
}

class _SimSliderState extends State<SimSlider> {
  final FocusNode _focus = FocusNode(debugLabel: 'SimSlider');
  final GlobalKey _box = GlobalKey();
  bool _focused = false;

  double get _width {
    final box = _box.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.width : 200;
  }

  static const double _thumb = 14;
  static const double _track = 6;
  static const double _hit = 15;

  bool get _interactive => widget.enabled && widget.onChanged != null;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  double _snap(double raw) {
    final span = widget.max - widget.min;
    if (span <= 0) return widget.min;
    final stepped = ((raw - widget.min) / widget.step).round() * widget.step;
    return (widget.min + stepped).clamp(widget.min, widget.max);
  }

  void _emit(double value) {
    final next = _snap(value);
    if (next != widget.value) widget.onChanged?.call(next);
  }

  void _fromPointer(double dx, double width) {
    final usable = width - _thumb;
    final t = ((dx - _thumb / 2) / usable).clamp(0.0, 1.0);
    _emit(widget.min + t * (widget.max - widget.min));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_interactive) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final big = widget.step * 10;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _emit(widget.value + widget.step);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _emit(widget.value - widget.step);
    } else if (key == LogicalKeyboardKey.home) {
      _emit(widget.min);
    } else if (key == LogicalKeyboardKey.end) {
      _emit(widget.max);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _emit(widget.value + big);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _emit(widget.value - big);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final span = widget.max - widget.min;
    final t = span <= 0
        ? 0.0
        : ((widget.value - widget.min) / span).clamp(0.0, 1.0);
    return Semantics(
      slider: true,
      label: widget.semanticsLabel,
      value: widget.value.toStringAsFixed(0),
      enabled: widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.5,
        child: Focus(
          focusNode: _focus,
          canRequestFocus: _interactive,
          onKeyEvent: _onKey,
          onFocusChange: (v) => setState(() => _focused = v),
          child: MouseRegion(
            cursor: _interactive
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _interactive
                  ? (d) {
                      _focus.requestFocus();
                      _fromPointer(d.localPosition.dx, _width);
                    }
                  : null,
              onHorizontalDragUpdate: _interactive
                  ? (d) => _fromPointer(d.localPosition.dx, _width)
                  : null,
              child: SizedBox(
                key: _box,
                width: double.infinity,
                height: _thumb + 2 * _hit,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Container(
                        height: _track,
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: t,
                            child: ColoredBox(color: c.textPrimary),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment(2 * t - 1, 0),
                      child: Container(
                        width: _thumb,
                        height: _thumb,
                        decoration: BoxDecoration(
                          color: c.textPrimary,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            ...SimShadows.xs,
                            if (_focused) ...simFocusRing(c),
                          ],
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
