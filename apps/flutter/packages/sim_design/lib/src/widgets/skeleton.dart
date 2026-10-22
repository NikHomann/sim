import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';

/// Port of `packages/emcn/src/components/skeleton/skeleton.tsx`: a
/// `--surface-active` rounded-md block pulsing between 100% and 50% opacity
/// on Tailwind's 2s `animate-pulse` curve; static when motion is off.
class SimSkeleton extends StatefulWidget {
  const SimSkeleton({
    super.key,
    this.width,
    this.height,
    this.radius = SimRadii.md,
    this.child,
  });

  final double? width;
  final double? height;
  final double radius;
  final Widget? child;

  @override
  State<SimSkeleton> createState() => _SimSkeletonState();
}

class _SimSkeletonState extends State<SimSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (!SimMotion.disabled) {
      _controller = AnimationController(vsync: this, duration: SimMotion.pulse);
      unawaited(_controller!.repeat());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: SimTheme.of(context).colors.surfaceActive,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: widget.child,
    );
    final controller = _controller;
    if (controller == null) return box;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // 0 -> 50%: 1 -> .5; 50% -> 100%: .5 -> 1, eased per half.
        final t = controller.value;
        final half = t < 0.5 ? t * 2 : (1 - t) * 2;
        final opacity = 1 - 0.5 * SimMotion.pulseCurve.transform(half);
        return Opacity(opacity: opacity, child: child);
      },
      child: box,
    );
  }
}
