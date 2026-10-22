import 'package:flutter/widgets.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/tokens/shadows.dart';

/// Port of `packages/emcn/src/components/label/label.tsx`: text-small,
/// `--text-primary`, leading-none; `muted` is the `ChipModalField` title
/// treatment (`text-[var(--text-muted)]`).
class SimLabel extends StatelessWidget {
  const SimLabel(
    this.text, {
    super.key,
    this.muted = false,
    this.required = false,
    this.enabled = true,
    this.color,
  });

  final String text;
  final bool muted;

  /// Appends the `*` marker in `--text-error`.
  final bool required;

  /// `peer-disabled:opacity-50`.
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final style = sim.text
        .style(13, height: 1)
        .copyWith(
          color: color ?? (muted ? c.textMuted : c.textPrimary),
        );
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Text.rich(
        TextSpan(
          text: text,
          children: <InlineSpan>[
            if (required)
              TextSpan(
                text: ' *',
                style: style.copyWith(color: c.textError),
              ),
          ],
        ),
        style: style,
      ),
    );
  }
}

/// `DashedDividerLine`: a 1.25px hairline of 6px `--border` dashes on 12px
/// periods (`repeating-linear-gradient` in `field-divider.tsx`).
class SimDashedDividerLine extends StatelessWidget {
  const SimDashedDividerLine({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1.25,
    width: double.infinity,
    child: CustomPaint(
      painter: _DashPainter(color ?? SimTheme.of(context).colors.border),
    ),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 12) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 6, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

/// Port of `packages/emcn/src/components/field-divider/field-divider.tsx`:
/// the dashed divider between fields in form-style panels (px-0.5 pt-4
/// pb-[13px]).
class SimFieldDivider extends StatelessWidget {
  const SimFieldDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(2, 16, 2, 13),
    child: SimDashedDividerLine(),
  );
}

/// Port of `packages/emcn/src/components/page-heading/page-heading.ts`:
/// Season, 26px (28px at >= 640px viewport), leading 1.15, tracking -0.01em,
/// `--text-primary`.
class SimPageHeading extends StatelessWidget {
  const SimPageHeading(this.text, {super.key, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final width = MediaQuery.maybeOf(context)?.size.width ?? 1024;
    return Text(
      text,
      textAlign: textAlign,
      style: sim.text
          .pageHeading(viewportWidth: width)
          .copyWith(
            color: sim.colors.textPrimary,
          ),
    );
  }
}

/// A keyboard key cap in the command-list treatment
/// (`apps/sim/.../command-list/command-list.tsx`): 26px wide, py-[3px],
/// text-caption `--text-tertiary` on `--surface-4`, rounded-sm, and the
/// `--shadow-kbd` / `--shadow-kbd-sm` drop. [raised] uses the 4px shadow with
/// the 2px lift; otherwise the 2px shadow.
class SimKbd extends StatelessWidget {
  const SimKbd(this.text, {super.key, this.raised = false, this.minWidth = 26});

  final String text;
  final bool raised;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Transform.translate(
      offset: Offset(0, raised ? -2 : 0),
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: c.surface4,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(SimRadii.sm),
          boxShadow: raised ? SimShadows.kbd : SimShadows.kbdSm,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: sim.text
              .mono(12)
              .copyWith(color: raised ? c.textPrimary : c.textTertiary),
        ),
      ),
    );
  }
}
