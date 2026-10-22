import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/src/interaction/pressable.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/widgets/chip/chrome.dart';

/// `buttonVariants` variant axis (`packages/emcn/src/components/button/button.tsx`).
enum SimButtonVariant {
  base,
  active,
  threeD,
  outline,
  primary,
  destructive,
  secondary,
  tertiary,
  ghost,
  subtle,
  ghostSecondary,
  quiet,
}

/// `sm` (11px text, px-1.5 py-1), `md` (12px, px-2 py-1.5), `icon` (20px square,
/// rounded-sm, glyph stroke 1.25).
enum SimButtonSize { sm, md, icon }

/// `iconPadding`: symmetric padding for icon actions sized by content.
enum SimButtonIconPadding { sm, md }

/// Resolved paint of a button for one interaction state.
class SimButtonPaint {
  const SimButtonPaint({
    required this.fill,
    required this.text,
    this.border,
    this.shadows,
    this.lift = 0,
  });

  final Color fill;
  final Color text;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;

  /// `3d` hover lifts the button 2px.
  final double lift;
}

/// Resolves `buttonVariants` (plus the `size='icon'` compound variants) for a
/// state.
SimButtonPaint resolveButtonPaint(
  SimColors c, {
  required SimButtonVariant variant,
  required SimButtonSize size,
  bool hovered = false,
}) {
  const transparent = Color(0x00000000);
  final isDark = c.brightness == Brightness.dark;
  final iconMuted = size == SimButtonSize.icon;
  switch (variant) {
    case SimButtonVariant.base:
      return SimButtonPaint(
        fill: hovered ? (isDark ? c.surface5 : c.surface6) : c.surface4,
        text: hovered ? c.textPrimary : c.textSecondary,
        border: Border.all(color: c.border),
      );
    case SimButtonVariant.active:
      return SimButtonPaint(
        fill: hovered ? (isDark ? c.border : c.surface6) : c.surface5,
        text: c.textPrimary,
        border: Border.all(color: c.border),
      );
    case SimButtonVariant.threeD:
      return SimButtonPaint(
        fill: transparent,
        text: hovered ? c.textPrimary : c.textTertiary,
        border: Border(
          top: BorderSide(color: c.border),
          left: BorderSide(color: c.border),
          right: BorderSide(color: c.border),
        ),
        shadows: <BoxShadow>[
          BoxShadow(color: c.border, offset: Offset(0, hovered ? 4 : 2)),
        ],
        lift: hovered ? 2 : 0,
      );
    case SimButtonVariant.outline:
      return SimButtonPaint(
        fill: transparent,
        text: hovered ? c.textPrimary : c.textSecondary,
        border: Border.all(color: hovered ? c.textSecondary : c.textMuted),
      );
    case SimButtonVariant.primary:
      return SimButtonPaint(
        fill: hovered
            ? SimChipChrome.primaryHoverFill(c)
            : SimChipChrome.primaryFill(c),
        text: SimChipChrome.primaryText(c),
      );
    case SimButtonVariant.destructive:
      return SimButtonPaint(
        fill: SimChipChrome.destructiveFill(c, hovered: hovered),
        text: SimColors.white,
      );
    case SimButtonVariant.secondary:
      return SimButtonPaint(fill: c.brandSecondary, text: c.textPrimary);
    case SimButtonVariant.tertiary:
      return SimButtonPaint(
        fill: hovered ? c.brandAccentHover : c.brandAccent,
        text: c.textInverse,
      );
    case SimButtonVariant.ghost:
      return SimButtonPaint(
        fill: transparent,
        text: hovered
            ? c.textPrimary
            : iconMuted
            ? c.textIconMuted
            : c.textSecondary,
      );
    case SimButtonVariant.subtle:
      return SimButtonPaint(
        fill: hovered ? c.surface4 : transparent,
        text: c.textBody,
      );
    case SimButtonVariant.ghostSecondary:
      return SimButtonPaint(
        fill: transparent,
        text: hovered ? c.textPrimary : c.textMuted,
      );
    case SimButtonVariant.quiet:
      return SimButtonPaint(
        fill: hovered ? c.surfaceActive : transparent,
        text: iconMuted ? c.textIconMuted : c.textSecondary,
      );
  }
}

/// Port of `packages/emcn/src/components/button/button.tsx`: 12 variants,
/// 3 sizes, 5px radius (4px for `icon`), `disabled:opacity-70`, no focus ring.
/// The child is the button's content; icon glyphs are sized at the call site.
class SimButton extends StatelessWidget {
  const SimButton({
    required this.child,
    super.key,
    this.onPressed,
    this.variant = SimButtonVariant.base,
    this.size = SimButtonSize.md,
    this.iconPadding,
    this.enabled = true,
    this.semanticsLabel,
    this.focusNode,
    this.autofocus = false,
    this.hitSlop = EdgeInsets.zero,
    this.width,
    this.height,
    this.padding,
    this.onSecondaryTapDown,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final SimButtonVariant variant;
  final SimButtonSize size;
  final SimButtonIconPadding? iconPadding;
  final bool enabled;
  final String? semanticsLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Extends the hit area without enlarging the visible box
  /// (`before:absolute before:inset-[-14px]`).
  final EdgeInsets hitSlop;

  /// Layout-only overrides (`size-[16px] p-0` on modal close buttons).
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final void Function(Offset globalPosition)? onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final isIcon = size == SimButtonSize.icon;
    final resolvedPadding =
        padding ??
        switch (iconPadding) {
          SimButtonIconPadding.sm => const EdgeInsets.all(4),
          SimButtonIconPadding.md => const EdgeInsets.all(6),
          null => switch (size) {
            SimButtonSize.sm => const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 4,
            ),
            SimButtonSize.md => const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            SimButtonSize.icon => EdgeInsets.zero,
          },
        };
    final textStyle = switch (size) {
      SimButtonSize.sm => sim.text.style(11),
      SimButtonSize.md => sim.text.style(12),
      SimButtonSize.icon => sim.text.style(12),
    };
    final radius = isIcon ? SimRadii.buttonIcon : SimRadii.button;
    return SimPressable(
      onPressed: onPressed,
      onSecondaryTapDown: onSecondaryTapDown,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticsLabel: semanticsLabel,
      cursor: enabled ? null : MouseCursor.defer,
      builder: (context, state) {
        final paint = resolveButtonPaint(
          c,
          variant: variant,
          size: size,
          hovered: state.hovered,
        );
        final box = AnimatedContainer(
          duration: SimMotion.of(SimMotion.colors),
          width: width ?? (isIcon ? 20 : null),
          height: height ?? (isIcon ? 20 : null),
          padding: resolvedPadding,
          transform: Matrix4.translationValues(0, -paint.lift, 0),
          decoration: BoxDecoration(
            color: paint.fill,
            border: paint.border,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: paint.shadows,
          ),
          child: DefaultTextStyle.merge(
            style: textStyle.copyWith(color: paint.text),
            maxLines: 1,
            softWrap: false,
            child: IconTheme.merge(
              data: IconThemeData(color: paint.text),
              child: Center(widthFactor: 1, heightFactor: 1, child: child),
            ),
          ),
        );
        final body = Opacity(opacity: enabled ? 1 : 0.7, child: box);
        if (hitSlop == EdgeInsets.zero) return body;
        return _HitSlop(slop: hitSlop, child: body);
      },
    );
  }
}

/// Extends the hit region of its child by [slop] on each side.
class _HitSlop extends SingleChildRenderObjectWidget {
  const _HitSlop({required this.slop, required super.child});

  final EdgeInsets slop;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitSlop(slop);

  @override
  void updateRenderObject(BuildContext context, _RenderHitSlop renderObject) {
    renderObject.slop = slop;
  }
}

class _RenderHitSlop extends RenderProxyBox {
  _RenderHitSlop(this.slop);

  EdgeInsets slop;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final inflated = Rect.fromLTWH(
      -slop.left,
      -slop.top,
      size.width + slop.horizontal,
      size.height + slop.vertical,
    );
    if (!inflated.contains(position)) return false;
    if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  bool hitTestSelf(Offset position) => true;
}
