// Failure modes a golden diff must catch: the trigger chip (tile, name,
// chevron), the 256px menu surface (bg, border, 12px radius, shadow, 4px
// padding), the search chip field at six workspaces, pinned-first rows with
// the pin indicator, the current row's surface-active fill, the full-width
// separator and the footer rows — in light and dark. The test also asserts
// the menu geometry (width, offset, row box) the image cannot.

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/workspace_shell/switcher/workspace_switcher.dart';
import 'package:sim_design/sim_design.dart';

import '../../search/support/shell_fixtures.dart';

void main() {
  late ShellFixture fixture;

  setUp(() async {
    fixture = ShellFixture(
      workspaces: [
        ws(workspaceId, name: 'Acme'),
        for (final n in ['Beta', 'Gamma', 'Delta', 'Epsilon', 'Zeta'])
          ws(n, name: n),
      ],
      pinned: ['Gamma'],
    );
    await fixture.load();
  });

  tearDown(() => fixture.dispose());

  for (final dark in [false, true]) {
    final suffix = dark ? 'dark' : 'light';
    // goldenTest registers the test synchronously.
    // ignore: discarded_futures
    goldenTest(
      'workspace switcher menu open ($suffix)',
      fileName: 'workspace_switcher_$suffix',
      constraints: BoxConstraints.tight(const Size(320, 560)),
      whilePerforming: (tester) async {
        await tester.tap(byParityId('workspace.switcher.trigger'));
        await tester.pumpAndSettle();
        // Geometry the image alone would not pin down: the 256px menu 8px
        // below the trigger, rows 30px tall starting 1px border + 4px
        // padding inside the surface.
        final trigger = tester.getRect(
          byParityId('workspace.switcher.trigger'),
        );
        final menu = tester.getRect(byParityId('workspace.switcher.menu'));
        expect(menu.width, 256);
        expect(menu.top, trigger.bottom + 8);
        final row = tester.getRect(
          byParityId('workspace.switcher.menu.row.$workspaceId'),
        );
        expect(row.height, 30);
        expect(row.left, menu.left + 5);
        return null;
      },
      builder: () => Theme(
        data: dark ? simDarkTheme() : simLightTheme(),
        child: SimOverlayHost(
          child: SizedBox.expand(
            child: ColoredBox(
              color: dark ? SimColors.dark.surface1 : SimColors.light.surface1,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: 143,
                    child: WorkspaceSwitcherChip(
                      workspaceId: workspaceId,
                      collapsed: false,
                      dependencies: WorkspaceSwitcherDependencies(
                        workspaces: fixture.workspaces,
                        invitations: fixture.invitationsCubit,
                        permissions: fixture.permissions,
                        session: fixture.session,
                        deploymentShape: fixture.deploymentShape,
                      ),
                    ),
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
