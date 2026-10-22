import 'package:flutter/widgets.dart';
import 'package:sim_design/src/icons/sim_icons.dart';
import 'package:sim_design/src/widgets/chip/segmented_control.dart';

/// One segment of a [SimChipSwitch].
class SimChipSwitchOption<T> {
  const SimChipSwitchOption({
    required this.value,
    required this.label,
    this.child,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;

  /// Rich label (e.g. a discount badge inline); wins over [label].
  final Widget? child;
  final SimIconData? icon;
  final bool enabled;
}

/// Port of `packages/emcn/src/components/chip-switch/chip-switch.tsx`: a
/// segmented chip with the 30px outer height of `ChipDropdown` (22px compact),
/// no gap between segments. A boolean toggle stays `SimSwitch`.
class SimChipSwitch<T> extends StatelessWidget {
  const SimChipSwitch({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
    this.enabled = true,
    this.size = SimSegmentedSize.standard,
    this.semanticsLabel,
  });

  final List<SimChipSwitchOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final SimSegmentedSize size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => SimSegmentedControl<T>(
    segments: <SimSegment<T>>[
      for (final option in options)
        SimSegment<T>(
          value: option.value,
          label: option.child ?? Text(option.label),
          icon: option.icon,
          enabled: option.enabled,
        ),
    ],
    value: value,
    onChanged: onChanged,
    enabled: enabled,
    size: size,
    semanticsLabel: semanticsLabel,
  );
}

/// One item of a [SimChipButtonGroup].
class SimChipButtonGroupItem<T> {
  const SimChipButtonGroupItem({
    required this.value,
    required this.child,
    this.enabled = true,
  });

  final T value;
  final Widget child;
  final bool enabled;
}

/// Port of `packages/emcn/src/components/chip-button-group/chip-button-group.tsx`:
/// the same segmented chrome as [SimChipSwitch] with rich option content and
/// a 2px gap between segments (`gap: 'sm'`).
class SimChipButtonGroup<T> extends StatelessWidget {
  const SimChipButtonGroup({
    required this.items,
    required this.onChanged,
    super.key,
    this.value,
    this.enabled = true,
    this.size = SimSegmentedSize.standard,
    this.semanticsLabel,
  });

  final List<SimChipButtonGroupItem<T>> items;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final SimSegmentedSize size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => SimSegmentedControl<T>(
    segments: <SimSegment<T>>[
      for (final item in items)
        SimSegment<T>(
          value: item.value,
          label: item.child,
          enabled: item.enabled,
        ),
    ],
    value: value,
    onChanged: onChanged,
    enabled: enabled,
    size: size,
    gap: 2,
    semanticsLabel: semanticsLabel,
  );
}
