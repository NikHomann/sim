import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

import 'golden_support.dart';

void main() {
  themedGoldenTest(
    'Chip variants',
    fileName: 'chip',
    columns: 3,
    scenarios: ({required dark}) => <GoldenTestScenario>[
      for (final variant in SimChipVariant.values)
        GoldenTestScenario(
          name: variant.name,
          child: SimChip(
            label: 'Chip ${variant.name}',
            variant: variant,
            leftIcon: SimIcons.bell,
            onPressed: () {},
          ),
        ),
      GoldenTestScenario(
        name: 'active',
        child: SimChip(label: 'Active', active: true, onPressed: () {}),
      ),
      GoldenTestScenario(
        name: 'disabled',
        child: SimChip(
          label: 'Disabled',
          variant: SimChipVariant.primary,
          enabled: false,
          onPressed: () {},
        ),
      ),
      GoldenTestScenario(
        name: 'round + right icon',
        child: SimChip(
          label: 'Round',
          shape: SimChipShape.round,
          variant: SimChipVariant.outline,
          rightIcon: SimIcons.chevronDown,
          onPressed: () {},
        ),
      ),
      GoldenTestScenario(
        name: 'full width overflow',
        child: boxed(
          SimChip(
            label: 'A very long chip label that must clip with a fade',
            fullWidth: true,
            leftIcon: SimIcons.search,
            onPressed: () {},
          ),
          width: 180,
        ),
      ),
      GoldenTestScenario(
        name: 'link',
        child: SimChipLink(
          href: '/integrations',
          label: 'Integrations',
          leftIcon: SimIcons.chevronLeft,
          onPressed: () {},
        ),
      ),
    ],
  );

  themedGoldenTest(
    'Chip triggers and tags',
    fileName: 'chip_triggers',
    scenarios: ({required dark}) => <GoldenTestScenario>[
      GoldenTestScenario(
        name: 'dropdown filled',
        child: boxed(
          const SimChipDropdown(
            options: <SimChipDropdownOption>[
              SimChipDropdownOption(value: 'a', label: 'Admin'),
            ],
            value: 'a',
            fullWidth: true,
          ),
        ),
      ),
      GoldenTestScenario(
        name: 'dropdown placeholder',
        child: const SimChipDropdown(
          options: <SimChipDropdownOption>[],
          placeholder: 'Select role',
        ),
      ),
      GoldenTestScenario(
        name: 'dropdown ghost',
        child: const SimChipDropdown(
          options: <SimChipDropdownOption>[
            SimChipDropdownOption(value: 'a', label: 'Ghost'),
          ],
          value: 'a',
          variant: SimChipTriggerVariant.ghost,
          leftIcon: SimIcons.bell,
        ),
      ),
      GoldenTestScenario(
        name: 'select',
        child: const SimChipSelect(
          options: <SimChipSelectOption>[
            SimChipSelectOption(value: '7d', label: 'Last 7 days'),
          ],
          value: '7d',
        ),
      ),
      GoldenTestScenario(
        name: 'combobox',
        child: boxed(
          const SimChipCombobox(
            options: <SimComboboxOption>[
              SimComboboxOption(value: 'x', label: 'Source X'),
            ],
            value: 'x',
          ),
        ),
      ),
      GoldenTestScenario(
        name: 'switch',
        child: SimChipSwitch<String>(
          value: 'annual',
          onChanged: (_) {},
          options: const <SimChipSwitchOption<String>>[
            SimChipSwitchOption(value: 'annual', label: 'Annual'),
            SimChipSwitchOption(value: 'monthly', label: 'Monthly'),
          ],
        ),
      ),
      GoldenTestScenario(
        name: 'switch compact',
        child: SimChipSwitch<String>(
          value: 'b',
          size: SimSegmentedSize.compact,
          onChanged: (_) {},
          options: const <SimChipSwitchOption<String>>[
            SimChipSwitchOption(value: 'a', label: 'A'),
            SimChipSwitchOption(value: 'b', label: 'B', icon: SimIcons.check),
          ],
        ),
      ),
      GoldenTestScenario(
        name: 'button group',
        child: SimChipButtonGroup<String>(
          value: 'py',
          onChanged: (_) {},
          items: const <SimChipButtonGroupItem<String>>[
            SimChipButtonGroupItem(value: 'curl', child: Text('cURL')),
            SimChipButtonGroupItem(value: 'py', child: Text('Python')),
          ],
        ),
      ),
      GoldenTestScenario(
        name: 'tags',
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final v in SimChipTagVariant.values)
              if (v != SimChipTagVariant.workflow &&
                  v != SimChipTagVariant.brand)
                SimChipTag(label: v.name, variant: v),
            const SimChipTag(
              label: 'invalid',
              variant: SimChipTagVariant.invite,
              invalid: true,
              leftIcon: SimIcons.triangleAlert,
              rightIcon: SimIcons.x,
            ),
            const SimChipTag(
              label: 'brand',
              variant: SimChipTagVariant.brand,
              brandColor: Color(0xFF0062FF),
            ),
          ],
        ),
      ),
      GoldenTestScenario(
        name: 'workflow tones',
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final tone in SimChipTagTone.values)
              SimChipTag(
                label: tone.name,
                variant: SimChipTagVariant.workflow,
                tone: tone,
              ),
          ],
        ),
      ),
    ],
  );
}
