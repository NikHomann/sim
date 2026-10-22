// Failure modes a golden diff must catch (workspace-sidebar.md §Layout,
// sidebar-workflow-tree.md §Rows):
// - header lane: switcher chip, Search/Collapse chips, 8px insets;
// - nav block, section titles, 16px section gaps, empty Chats row;
// - tree: interleaved order, active route row fill, chevron/folder glyphs,
//   the open folder's guide line, 20px indent and nested folder;
// - footer: avatar initial on the user colour, help chip hard right;
// - collapsed rail: 32px chips on the 48px rail, help above profile;
// - light and dark tokens.
// CI goldens obscure text, so they capture structure and colour, not
// glyph shapes; the geometry is asserted before the capture.

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_design/sim_design.dart';

import '../support/harness.dart';

void main() {
  late SidebarHarness h;

  setUp(() async {
    h = SidebarHarness();
    await h.load();
    h.tree.setExpanded('f-e2e', expanded: true);
  });

  tearDown(() => h.dispose());

  Widget sidebar({required bool collapsed}) => SizedBox(
    width: collapsed ? 48 : 224,
    height: 640,
    child: SidebarEnvironment(
      services: h.services(),
      child: WorkspaceSidebar(workspaceId: workspaceId, collapsed: collapsed),
    ),
  );

  for (final dark in <bool>[false, true]) {
    final suffix = dark ? 'dark' : 'light';
    // ignore: discarded_futures, goldenTest registers the test synchronously
    goldenTest(
      'workspace sidebar ($suffix)',
      fileName: 'workspace_sidebar_$suffix',
      whilePerforming: (tester) async {
        await tester.pumpAndSettle();
        // The expanded scenario: 8px header inset, 32×30 header chips, the
        // nav 16px below the header, 30px tree rows 2px apart.
        final search = tester.getRect(
          byParity('shell.sidebar.header.search').first,
        );
        expect(search.size, const Size(32, 30));
        final header = tester.getRect(byParity('shell.sidebar.header').first);
        expect(search.top, header.top + 8);
        final nav = tester.getRect(byParity('shell.sidebar.nav').first);
        expect(nav.top, search.bottom + 16);
        final empty = tester.getRect(
          byParity('sidebar.tree.workflow-row.w-empty').first,
        );
        final folder = tester.getRect(
          byParity('sidebar.tree.folder-row.f-e2e').first,
        );
        expect(empty.height, 30);
        expect(folder.top, empty.bottom + 2);
        return null;
      },
      builder: () => Theme(
        data: dark ? simDarkTheme() : simLightTheme(),
        child: Builder(
          builder: (context) => ColoredBox(
            color: SimTheme.of(context).colors.bg,
            child: SimOverlayHost(
              child: GoldenTestGroup(
                columns: 2,
                children: <GoldenTestScenario>[
                  GoldenTestScenario(
                    name: 'expanded 224px',
                    child: sidebar(collapsed: false),
                  ),
                  GoldenTestScenario(
                    name: 'collapsed 48px',
                    child: sidebar(collapsed: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
