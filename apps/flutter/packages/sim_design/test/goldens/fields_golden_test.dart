import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

import 'golden_support.dart';

void main() {
  themedGoldenTest(
    'Fields',
    fileName: 'fields',
    scenarios: ({required dark}) => <GoldenTestScenario>[
      GoldenTestScenario(
        name: 'chip input',
        child: boxed(
          SimChipInput(
            icon: SimIcons.search,
            placeholder: 'Search...',
            controller: TextEditingController(),
          ),
        ),
      ),
      GoldenTestScenario(
        name: 'chip input value + error',
        child: boxed(
          SimChipInput(
            controller: TextEditingController(text: 'my-skill'),
            error: true,
          ),
        ),
      ),
      GoldenTestScenario(
        name: 'chip input disabled',
        child: boxed(
          SimChipInput(
            controller: TextEditingController(text: 'read only'),
            enabled: false,
          ),
        ),
      ),
      GoldenTestScenario(
        name: 'chip copy input',
        child: boxed(const SimChipCopyInput(value: 'cred_01HXYZ')),
      ),
      GoldenTestScenario(
        name: 'chip textarea',
        child: boxed(
          SimChipTextarea(
            placeholder: 'Message',
            controller: TextEditingController(),
          ),
        ),
      ),
      GoldenTestScenario(
        name: 'input / textarea',
        child: boxed(
          Column(
            spacing: 8,
            children: <Widget>[
              SimInput(
                placeholder: 'Enter text...',
                controller: TextEditingController(),
              ),
              SimTextarea(
                controller: TextEditingController(text: 'Lorem ipsum'),
                minLines: 2,
              ),
            ],
          ),
        ),
      ),
      GoldenTestScenario(
        name: 'switch / checkbox',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SimSwitch(value: true, onChanged: (_) {}),
            SimSwitch(value: false, onChanged: (_) {}),
            const SimSwitch(value: true, enabled: false),
            SimCheckbox(value: true, onChanged: (_) {}),
            SimCheckbox(value: false, onChanged: (_) {}),
            SimCheckbox(
              value: null,
              size: SimCheckboxSize.lg,
              onChanged: (_) {},
            ),
            SimCheckbox(
              value: true,
              size: SimCheckboxSize.sm,
              onChanged: (_) {},
            ),
          ],
        ),
      ),
      GoldenTestScenario(
        name: 'slider',
        child: boxed(SimSlider(value: 40, onChanged: (_) {})),
      ),
      GoldenTestScenario(
        name: 'label / divider',
        child: boxed(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SimLabel('Email address', required: true),
              SimFieldDivider(),
              SimLabel('Hint', muted: true),
            ],
          ),
        ),
      ),
      GoldenTestScenario(
        name: 'skeleton / heading',
        child: boxed(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: <Widget>[
              SimSkeleton(width: 160, height: 14),
              SimPageHeading('Workflows'),
            ],
          ),
        ),
      ),
    ],
  );
}
