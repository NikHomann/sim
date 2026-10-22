import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

import 'golden_support.dart';

void main() {
  themedGoldenTest(
    'Menus and tooltips',
    fileName: 'menus',
    scenarios: ({required dark}) => <GoldenTestScenario>[
      GoldenTestScenario(
        name: 'dropdown menu',
        child: boxed(
          Builder(
            builder: (context) => SimMenuList(
              autofocus: false,
              decoration: SimMenuStyles.surface(SimTheme.of(context).colors),
              entries: () => <SimMenuEntry>[
                const SimMenuLabel('Actions'),
                SimMenuItem(
                  label: 'Rename',
                  icon: SimIcons.check,
                  onSelect: () {},
                ),
                SimMenuItem(
                  label: 'Duplicate',
                  shortcut: '⌘D',
                  onSelect: () {},
                ),
                const SimMenuItem(label: 'Disabled', enabled: false),
                const SimMenuItem(
                  label: 'Selected',
                  selected: true,
                  active: true,
                ),
                const SimMenuItem(label: 'Checked', checked: true),
                const SimMenuItem(label: 'Radio', radio: true),
                const SimMenuSub(label: 'Move to', entries: <SimMenuEntry>[]),
                const SimMenuSeparator(),
                SimMenuItem(label: 'Delete', onSelect: () {}),
              ],
            ),
          ),
          width: 220,
        ),
      ),
      GoldenTestScenario(
        name: 'menu search + small rows',
        child: boxed(
          Builder(
            builder: (context) => SimMenuList(
              autofocus: false,
              decoration: SimMenuStyles.surface(SimTheme.of(context).colors),
              entries: () => <SimMenuEntry>[
                const SimMenuSearch(),
                const SimMenuItem(label: 'Small row', size: SimMenuRowSize.sm),
                const SimMenuItem(label: 'Large row', size: SimMenuRowSize.lg),
              ],
            ),
          ),
          width: 200,
        ),
      ),
      GoldenTestScenario(
        name: 'tooltip surface',
        child: const SimTooltipSurface(child: Text('Clear console  ⌘D')),
      ),
      GoldenTestScenario(
        name: 'overflow text',
        child: boxed(
          const SimOverflowText(
            label: 'This label is far too long for the box it sits in',
          ),
          width: 140,
        ),
      ),
    ],
  );

  themedGoldenTest(
    'Chip modal',
    fileName: 'chip_modal',
    columns: 1,
    constraints: const BoxConstraints(maxWidth: 560),
    scenarios: ({required dark}) => <GoldenTestScenario>[
      GoldenTestScenario(
        name: 'form',
        child: SizedBox(
          width: 440,
          child: SimChipModalSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SimChipModalHeader(
                  title: 'Invite team members',
                  icon: SimIcons.bell,
                ),
                SimChipModalBody(
                  children: <Widget>[
                    SimChipModalField.input(
                      title: 'Name',
                      controller: TextEditingController(text: 'Ada'),
                      required: true,
                      hint: 'Lowercase letters, numbers, and hyphens',
                    ),
                    SimChipModalField.dropdown(
                      title: 'Invite as',
                      value: 'admin',
                      options: const <SimChipDropdownOption>[
                        SimChipDropdownOption(value: 'admin', label: 'Admin'),
                      ],
                      onChanged: (_) {},
                      error: 'Pick a role',
                    ),
                    SimChipModalField.copy(title: 'ID', value: 'ws_01'),
                  ],
                ),
                SimChipModalFooter(
                  primaryAction: SimChipModalAction(
                    label: 'Send invites',
                    onPressed: () {},
                  ),
                  secondaryActions: <Widget>[
                    SimChip(
                      label: 'Delete',
                      variant: SimChipVariant.destructive,
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      GoldenTestScenario(
        name: 'legacy modal chrome',
        child: SizedBox(
          width: 440,
          child: Builder(
            builder: (context) {
              final c = SimTheme.of(context).colors;
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(SimRadii.modal),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SimModalHeader(title: 'Settings'),
                    SimModalTabs(
                      value: 'a',
                      onChanged: (_) {},
                      tabs: const <SimModalTab>[
                        SimModalTab(value: 'a', label: 'General'),
                        SimModalTab(value: 'b', label: 'Advanced'),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Text('Body content'),
                    ),
                    SimModalFooter(
                      children: <Widget>[
                        SimButton(
                          onPressed: () {},
                          child: const Text('Cancel'),
                        ),
                        SimButton(
                          variant: SimButtonVariant.primary,
                          onPressed: () {},
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}
