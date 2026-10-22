// Failure modes a golden diff must catch: the dialog ring and card
// (surface-4/5, 12px and 8px radii, 3px ring), the floating input band and
// its hint, group headings and the 30px rows with the selected row's
// surface-active fill and border and the shortcut hint grid (the capture
// ends inside the Pages group; rows below the fold are covered by the
// widget tests) — in light and dark. The test also asserts the geometry the
// image cannot: the 500px dialog 15% from the top and 30px rows inset by
// the list padding and `mx-0.5`.

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/workspace_shell/chrome/search_palette_controller.dart';
import 'package:sim_app/features/workspace_shell/search/search_palette.dart';
import 'package:sim_design/sim_design.dart';

import '../support/shell_fixtures.dart';

void main() {
  late ShellFixture fixture;

  setUp(() async {
    fixture = ShellFixture(
      workspaces: [
        ws(workspaceId, name: 'Acme'),
        ws('ws-2', name: 'Beta'),
      ],
      workflows: [
        workflow(id: 'wf-1', name: 'Onboarding', folderId: 'f-2'),
        workflow(id: 'wf-2', name: 'Daily report'),
      ],
      folders: [
        folder(id: 'f-1', name: 'Sales'),
        folder(id: 'f-2', name: 'Leads', parentId: 'f-1'),
      ],
    );
    await fixture.load();
  });

  tearDown(() => fixture.dispose());

  for (final dark in [false, true]) {
    final suffix = dark ? 'dark' : 'light';
    // goldenTest registers the test synchronously.
    // ignore: discarded_futures
    goldenTest(
      'search palette open ($suffix)',
      fileName: 'search_palette_$suffix',
      constraints: BoxConstraints.tight(const Size(900, 640)),
      whilePerforming: (tester) async {
        await tester.pumpAndSettle();
        final dialog = tester.getRect(byParityId('search.dialog'));
        expect(dialog.width, 500);
        expect(dialog.top, closeTo(640 * 0.15, 0.5));
        final list = tester.getRect(byParityId('search.palette.list'));
        final row = tester.getRect(byParityId('search.palette.row.selected'));
        expect(row.height, 30);
        expect(row.left, list.left + 6 + 2);
        return null;
      },
      builder: () {
        final controller = SearchPaletteController()..open();
        final theme = dark ? simDarkTheme() : simLightTheme();
        return Theme(
          data: theme,
          child: SimOverlayHost(
            child: ColoredBox(
              color: dark ? SimColors.dark.bg : SimColors.light.bg,
              child: SearchPaletteLayer(
                controller: controller,
                workspaceId: workspaceId,
                pathname: '/workspace/$workspaceId/w/wf-1',
                currentWorkflowId: 'wf-1',
                onCreateWorkflow: () {},
                onCreateFolder: () {},
                onImportWorkflow: () {},
                onNavigate: (_) {},
                dependencies: SearchPaletteDependencies(
                  workspaces: fixture.workspaces,
                  workflows: fixture.workflows,
                  folders: fixture.folders,
                  deploymentShape: fixture.deploymentShape,
                  permissions: fixture.permissions,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}
