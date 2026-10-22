import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icon.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/interaction/pressable.dart';
import 'package:sim_design/src/theme/sim_theme.dart';
import 'package:sim_design/src/tokens/colors.dart';
import 'package:sim_design/src/tokens/motion.dart';
import 'package:sim_design/src/tokens/radii.dart';
import 'package:sim_design/src/tokens/shadows.dart';

/// `focus-visible:ring-2 ring-[color-mix(--text-muted 30%)] ring-offset-2
/// ring-offset-[--surface-2]` as two spread shadows.
List<BoxShadow> simFocusRing(SimColors c) => <BoxShadow>[
  BoxShadow(color: c.surface2, spreadRadius: 2),
  BoxShadow(
    color: SimColors.mix(c.textMuted, const Color(0x00000000), 0.3),
    spreadRadius: 4,
  ),
];

/// Port of `packages/emcn/src/components/switch/switch.tsx`: a 36x20 track
/// (`--border` off, `--text-primary` on) with a 16px `--surface-2` thumb that
/// slides from 2px to 18px, a 12px extended hit area, `opacity-50` disabled.
class SimSwitch extends StatelessWidget {
  const SimSwitch({
    required this.value,
    super.key,
    this.onChanged,
    this.enabled = true,
    this.semanticsLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final interactive = enabled && onChanged != null;
    return Semantics(
      toggled: value,
      label: semanticsLabel,
      child: SimPressable(
        onPressed: interactive ? () => onChanged!(!value) : null,
        enabled: enabled,
        excludeSemantics: true,
        builder: (context, state) => Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedContainer(
              duration: SimMotion.of(SimMotion.colors),
              width: 36,
              height: 20,
              decoration: BoxDecoration(
                color: value ? c.textPrimary : c.border,
                borderRadius: BorderRadius.circular(SimRadii.full),
                boxShadow: state.focused ? simFocusRing(c) : null,
              ),
              child: AnimatedAlign(
                duration: SimMotion.of(SimMotion.colors),
                alignment: value
                    ? const Alignment(0.78, 0)
                    : const Alignment(-0.78, 0),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: c.surface2,
                    shape: BoxShape.circle,
                    boxShadow: SimShadows.xs,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum SimCheckboxSize { sm, md, lg }

/// Port of `packages/emcn/src/components/checkbox/checkbox.tsx`: a
/// rounded-sm box (14/16/20px) with a `--border` outline, filled
/// `--text-primary` when checked or indeterminate, a stroke-3 check (or
/// minus) in `--surface-2`, and a 12px extended hit area.
class SimCheckbox extends StatelessWidget {
  const SimCheckbox({
    required this.value,
    super.key,
    this.onChanged,
    this.size = SimCheckboxSize.md,
    this.enabled = true,
    this.semanticsLabel,
  });

  /// `null` is the indeterminate state.
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final SimCheckboxSize size;
  final bool enabled;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final interactive = enabled && onChanged != null;
    final box = switch (size) {
      SimCheckboxSize.sm => 14.0,
      SimCheckboxSize.md => 16.0,
      SimCheckboxSize.lg => 20.0,
    };
    final glyph = switch (size) {
      SimCheckboxSize.sm => 10.0,
      SimCheckboxSize.md => 14.0,
      SimCheckboxSize.lg => 16.0,
    };
    final on = value ?? true;
    return Semantics(
      checked: value,
      mixed: value == null,
      label: semanticsLabel,
      child: SimPressable(
        onPressed: interactive ? () => onChanged!(value != true) : null,
        enabled: enabled,
        excludeSemantics: true,
        builder: (context, state) => Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedContainer(
              duration: SimMotion.of(SimMotion.colors),
              width: box,
              height: box,
              decoration: BoxDecoration(
                color: on ? c.textPrimary : const Color(0x00000000),
                border: Border.all(color: on ? c.textPrimary : c.border),
                borderRadius: BorderRadius.circular(SimRadii.sm),
              ),
              child: on
                  ? Center(
                      child: SimIcon(
                        value == null ? SimIcons.minus : SimIcons.check,
                        size: glyph,
                        color: c.surface2,
                        strokeWidth: 3,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
