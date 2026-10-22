import 'package:flutter/widgets.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/breakpoints.dart';
import 'package:sim_design/src/tokens/layout.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/shadows.dart';

/// Port of `packages/emcn/src/components/details-panel/details-panel.tsx`:
/// a non-modal details sidebar sliding in from the right edge (200ms
/// ease-out) on `--bg` with a left `--border` and `shadow-md`, plus an
/// external 8px resize handle at its left edge (`cursor: ew-resize`). Place
/// it inside the parent's [Stack]; width state stays with the caller. Below
/// the `md` breakpoint it spans the full width and hides the handle.
class SimDetailsPanel extends StatelessWidget {
  const SimDetailsPanel({
    required this.open,
    required this.width,
    required this.child,
    super.key,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.resizeLabel = 'Resize panel',
    this.semanticsLabel,
  });

  final bool open;
  final double width;
  final Widget child;
  final VoidCallback? onResizeStart;

  /// Called with the horizontal pointer delta (positive = pointer moved right,
  /// i.e. the panel should shrink).
  final ValueChanged<double>? onResizeUpdate;
  final VoidCallback? onResizeEnd;
  final String resizeLabel;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final viewport = MediaQuery.maybeOf(context)?.size.width ?? 1280;
    final mobile = SimBreakpoints.isMobile(viewport);
    final panelWidth = mobile ? viewport : width;
    final duration = SimMotion.of(SimMotion.detailsPanel);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: panelWidth,
          child: AnimatedSlide(
            duration: duration,
            curve: SimMotion.easeOut,
            offset: Offset(open ? 0 : 1, 0),
            child: ExcludeFocus(
              excluding: !open,
              child: IgnorePointer(
                ignoring: !open,
                child: Semantics(
                  container: true,
                  label: semanticsLabel,
                  child: ClipRect(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.bg,
                        border: Border(left: BorderSide(color: c.border)),
                        boxShadow: SimShadows.md,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (open && !mobile)
          Positioned(
            top: 0,
            bottom: 0,
            right: width - 4,
            width: SimLayout.sidebarResizeHandle,
            child: Semantics(
              label: resizeLabel,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => onResizeStart?.call(),
                  onHorizontalDragUpdate: (d) =>
                      onResizeUpdate?.call(d.delta.dx),
                  onHorizontalDragEnd: (_) => onResizeEnd?.call(),
                  onHorizontalDragCancel: onResizeEnd,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
