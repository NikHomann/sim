import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// `ShimmerText` (`shimmer-text.module.css`): the text paints from a
/// gradient `--text-body` 40% → gray-400 (dark gray-50) 50% →
/// `--text-body` 60%, 200% wide, swept from left to right over 2.2 s.
/// With motion off the text rests in [restColor] (`--shimmer-rest`).
class ChatShimmer extends StatefulWidget {
  const ChatShimmer({required this.child, this.restColor, super.key});

  final Widget child;

  /// `--shimmer-rest`; defaults to `--text-body`.
  final Color? restColor;

  static const Duration period = Duration(milliseconds: 2200);

  @override
  State<ChatShimmer> createState() => _ChatShimmerState();
}

class _ChatShimmerState extends State<ChatShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ChatShimmer.period,
    );
    if (!SimMotion.disabled) unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    if (SimMotion.disabled) {
      return DefaultTextStyle.merge(
        style: TextStyle(color: widget.restColor ?? c.textBody),
        child: widget.child,
      );
    }
    final band = sim.isDark ? SimColors.gray[0] : SimColors.gray[4];
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          // background-position 100% → -100% on a 200%-wide gradient moves
          // the band's centre from x = 0 to x = 2w.
          final w = math.max(bounds.width, 1).toDouble();
          final shift = -w + 2 * w * _controller.value;
          return LinearGradient(
            colors: <Color>[
              c.textBody,
              c.textBody,
              band,
              c.textBody,
              c.textBody,
            ],
            stops: const <double>[0, 0.4, 0.5, 0.6, 1],
          ).createShader(Rect.fromLTWH(shift, 0, 2 * w, bounds.height));
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}
