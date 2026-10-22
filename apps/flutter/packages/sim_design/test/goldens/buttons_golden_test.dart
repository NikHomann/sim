import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

import 'golden_support.dart';

void main() {
  themedGoldenTest(
    'Button variants',
    fileName: 'button',
    columns: 4,
    scenarios: ({required dark}) => <GoldenTestScenario>[
      for (final variant in SimButtonVariant.values)
        GoldenTestScenario(
          name: variant.name,
          child: SimButton(
            variant: variant,
            onPressed: () {},
            child: Text(variant.name),
          ),
        ),
      GoldenTestScenario(
        name: 'sm',
        child: SimButton(
          size: SimButtonSize.sm,
          onPressed: () {},
          child: const Text('Small'),
        ),
      ),
      GoldenTestScenario(
        name: 'icon quiet',
        child: SimButton(
          variant: SimButtonVariant.quiet,
          size: SimButtonSize.icon,
          onPressed: () {},
          child: const SimIcon(SimIcons.x, size: 16, strokeWidth: 1.25),
        ),
      ),
      GoldenTestScenario(
        name: 'icon ghost',
        child: SimButton(
          variant: SimButtonVariant.ghost,
          size: SimButtonSize.icon,
          onPressed: () {},
          child: const SimIcon(SimIcons.duplicate, size: 13),
        ),
      ),
      GoldenTestScenario(
        name: 'disabled primary',
        child: SimButton(
          variant: SimButtonVariant.primary,
          enabled: false,
          onPressed: () {},
          child: const Text('Disabled'),
        ),
      ),
      GoldenTestScenario(
        name: 'badges',
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final v in SimBadgeVariant.values)
              SimBadge(label: v.name, variant: v, dot: true),
            const SimBadge(
              label: 'sm',
              size: SimBadgeSize.sm,
              icon: SimIcons.check,
            ),
            const SimBadge(
              label: 'lg',
              size: SimBadgeSize.lg,
              variant: SimBadgeVariant.blue,
              icon: SimIcons.check,
            ),
          ],
        ),
      ),
      GoldenTestScenario(
        name: 'kbd',
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: <Widget>[SimKbd('⌘'), SimKbd('K', raised: true)],
        ),
      ),
    ],
  );
}
