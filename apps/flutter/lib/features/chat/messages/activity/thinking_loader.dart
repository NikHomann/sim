import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/activity/shimmer.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_design/sim_design.dart';

/// Approximation of `ThinkingLoader` (`components/ui/thinking-loader.tsx`).
///
/// Matches the box ([size] square), the label row (`inline-flex`, gap
/// 0.4 × size, label 0.7 × size Inter 400 with the shimmer sweep, no wrap)
/// and the phrase crossfade timing (460 ms in, 300 ms out). The goo-filtered
/// shape morph is approximated by four ink dots orbiting from the `corners`
/// pattern (known gap: shape rendering).
class ChatThinkingLoader extends StatefulWidget {
  const ChatThinkingLoader({
    this.size = 20,
    this.label,
    this.labelRatio = 0.7,
    super.key,
  });

  final double size;
  final String? label;
  final double labelRatio;

  @override
  State<ChatThinkingLoader> createState() => _ChatThinkingLoaderState();
}

class _ChatThinkingLoaderState extends State<ChatThinkingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
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
    final c = SimTheme.of(context).colors;
    final glyph = SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _GooPainter(
            t: _controller.value,
            inner: c.thinkingInkInner,
            outer: c.thinkingInkOuter,
          ),
        ),
      ),
    );
    final label = widget.label;
    if (label == null) return glyph;
    final style = ChatText.inter(
      context,
      widget.size * widget.labelRatio,
      lineHeight: widget.size * widget.labelRatio * 1.5,
      color: c.textBody,
      tracking: true,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: widget.size * 0.4,
      children: <Widget>[
        glyph,
        AnimatedSwitcher(
          duration: SimMotion.of(const Duration(milliseconds: 460)),
          reverseDuration: SimMotion.of(const Duration(milliseconds: 300)),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[...previous, ?current],
          ),
          child: ChatShimmer(
            key: ValueKey<String>(label),
            child: Text(label, softWrap: false, maxLines: 1, style: style),
          ),
        ),
      ],
    );
  }
}

class _GooPainter extends CustomPainter {
  _GooPainter({required this.t, required this.inner, required this.outer});

  final double t;
  final Color inner;
  final Color outer;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.3;
    final dot = size.width * 0.15;
    final breathe = 0.85 + 0.15 * math.sin(t * 2 * math.pi);
    final paint = Paint()
      ..shader = RadialGradient(colors: <Color>[inner, outer]).createShader(
        Rect.fromCircle(center: center, radius: size.width / 2),
      );
    for (var i = 0; i < 4; i++) {
      final angle = math.pi / 4 + i * math.pi / 2 + t * 2 * math.pi / 4;
      final offset =
          Offset(math.cos(angle), math.sin(angle)) * radius * breathe;
      canvas.drawCircle(center + offset, dot, paint);
    }
  }

  @override
  bool shouldRepaint(_GooPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.inner != inner ||
      oldDelegate.outer != outer;
}
