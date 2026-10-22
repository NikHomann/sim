// Failure modes (what a golden diff must catch, entry-resolution.md §6
// cards): the 448px status card on --surface-1, the 40px --surface-3 disc,
// 18/14px copy and the primary + "Sign out" chips; the theme follows the
// viewer (not forced light).

import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';

import '../workspace_shell/chrome/support/shell_goldens.dart';

void main() {
  shellGoldens(
    'picker blocked card',
    fileName: 'entry_picker_blocked',
    location: '/workspace',
    arrange: (h) =>
        when(
          () => h.workspacesRepo.list(
            scope: any(named: 'scope'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => const WorkspaceList(
            workspaces: [],
            lastActiveWorkspaceId: null,
            creationPolicy: WorkspaceCreationPolicy(
              canCreate: false,
              workspaceMode: WorkspaceMode.personal,
              organizationId: null,
              maxWorkspaces: 1,
              currentWorkspaceCount: 0,
              reason: 'limit',
            ),
          ),
        ),
  );
}
