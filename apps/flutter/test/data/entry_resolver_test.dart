// Failure modes of resolveEntry (spec §8, §9, test plan Phase 1 L3 "entry
// resolution matrix"): one case per row of the decision table in the
// function's doc comment, so a wrong branch fails on that row:
// 1. home/o: pending → wait; signed out → login; error → load error;
//    signed in → picker (the organization landing, §8.1, is not ported);
// 2. picker: pending → wait; a clean null session → stale-session recovery
//    (never a bare /login that would loop); session error → load error;
// 3. picker: default-workspace creation pending/conflict (retry unused →
//    reload once, used → load error)/failed (→ login);
// 4. picker: workspaces pending → wait; 401 → recovery; other error → load
//    error; empty + blocked policy → blocked card; empty + allowed (or no
//    policy) → create "My Workspace";
// 5. picker: `?redirect_workflow=` wins over the workspace target; target is
//    the lastActive match, else the first row; `?redirect=` builds the
//    upgrade target and keeps the upgrade reason (the path and the reason
//    check are `workspaceDestination`'s, tested with the picker page).

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';

import 'support/mocks.dart';

void main() {
  EntryContext picker({
    EntrySession session = EntrySession.signedIn,
    EntryWorkspaces workspaces = const WorkspacesPending(),
    DefaultWorkspaceCreation creation = DefaultWorkspaceCreation.notAttempted,
    bool raceRetryUsed = false,
    EntryRedirectTarget? redirect,
    String? redirectWorkflowId,
    String? upgradeReason,
  }) => EntryContext(
    route: EntryRoute.workspacePicker,
    session: session,
    workspaces: workspaces,
    defaultWorkspaceCreation: creation,
    raceRetryUsed: raceRetryUsed,
    redirectTarget: redirect,
    redirectWorkflowId: redirectWorkflowId,
    upgradeReason: upgradeReason,
  );

  group('home and /o', () {
    for (final route in [EntryRoute.home, EntryRoute.organizationEntry]) {
      test('$route: session states', () {
        EntryDecision decide(EntrySession s) =>
            resolveEntry(EntryContext(route: route, session: s));
        expect(decide(EntrySession.pending), const EntryWait());
        expect(decide(EntrySession.signedOut), const EntryGoLogin());
        expect(decide(EntrySession.error), const EntryShowLoadError());
        expect(decide(EntrySession.signedIn), const EntryGoWorkspacePicker());
      });
    }
  });

  group('workspace picker', () {
    test('session states', () {
      expect(
        resolveEntry(picker(session: EntrySession.pending)),
        const EntryWait(),
      );
      expect(
        resolveEntry(picker(session: EntrySession.signedOut)),
        const EntryRecoverStaleSession(),
      );
      expect(
        resolveEntry(picker(session: EntrySession.error)),
        const EntryShowLoadError(),
      );
    });

    test('default workspace creation outcomes', () {
      expect(
        resolveEntry(picker(creation: DefaultWorkspaceCreation.pending)),
        const EntryWait(),
      );
      expect(
        resolveEntry(picker(creation: DefaultWorkspaceCreation.conflict)),
        const EntryReloadOnce(),
      );
      expect(
        resolveEntry(
          picker(
            creation: DefaultWorkspaceCreation.conflict,
            raceRetryUsed: true,
          ),
        ),
        const EntryShowLoadError(),
      );
      expect(
        resolveEntry(picker(creation: DefaultWorkspaceCreation.failed)),
        const EntryGoLogin(),
      );
    });

    test('workspace list states', () {
      expect(resolveEntry(picker()), const EntryWait());
      expect(
        resolveEntry(picker(workspaces: const WorkspacesFailed(status: 401))),
        const EntryRecoverStaleSession(),
      );
      expect(
        resolveEntry(picker(workspaces: const WorkspacesFailed(status: 500))),
        const EntryShowLoadError(),
      );
      expect(
        resolveEntry(picker(workspaces: const WorkspacesFailed(status: null))),
        const EntryShowLoadError(),
      );
    });

    test('empty list: blocked card or default creation', () {
      const blocked = WorkspaceCreationPolicy(
        canCreate: false,
        workspaceMode: WorkspaceMode.organization,
        organizationId: 'org',
        maxWorkspaces: 1,
        currentWorkspaceCount: 1,
        reason: 'limit',
        blockedReasonCode: CreationBlockedReason.permissionGroupDenied,
      );
      expect(
        resolveEntry(
          picker(
            workspaces: const WorkspacesLoaded(
              WorkspaceList(
                workspaces: [],
                lastActiveWorkspaceId: null,
                creationPolicy: blocked,
              ),
            ),
          ),
        ),
        const EntryShowBlocked(blocked),
      );
      expect(
        resolveEntry(
          picker(
            workspaces: WorkspacesLoaded(
              workspaceList(workspaces: const [], lastActiveWorkspaceId: null),
            ),
          ),
        ),
        const EntryCreateDefaultWorkspace(),
      );
      expect(
        resolveEntry(
          picker(
            workspaces: const WorkspacesLoaded(
              WorkspaceList(workspaces: [], lastActiveWorkspaceId: null),
            ),
          ),
        ),
        const EntryCreateDefaultWorkspace(),
      );
      expect(const EntryCreateDefaultWorkspace().name, 'My Workspace');
    });

    test('target: lastActive match, else first; redirects', () {
      final loaded = WorkspacesLoaded(
        workspaceList(lastActiveWorkspaceId: otherWorkspaceId),
      );
      expect(
        resolveEntry(picker(workspaces: loaded)),
        const EntryGoWorkspace(otherWorkspaceId),
      );
      expect(
        resolveEntry(
          picker(
            workspaces: WorkspacesLoaded(
              workspaceList(lastActiveWorkspaceId: 'gone'),
            ),
          ),
        ),
        const EntryGoWorkspace(workspaceId),
      );
      expect(
        resolveEntry(picker(workspaces: loaded, redirectWorkflowId: 'wf-1')),
        const EntryResolveWorkflowRedirect(
          'wf-1',
          fallbackWorkspaceId: otherWorkspaceId,
        ),
      );
      final settings = resolveEntry(
        picker(workspaces: loaded, redirect: EntryRedirectTarget.settings),
      );
      expect(
        settings,
        const EntryGoWorkspace(
          otherWorkspaceId,
          target: EntryRedirectTarget.settings,
        ),
      );
      final upgrade = resolveEntry(
        picker(
          workspaces: loaded,
          redirect: EntryRedirectTarget.upgrade,
          upgradeReason: 'seats',
        ),
      );
      expect(
        upgrade,
        const EntryGoWorkspace(
          otherWorkspaceId,
          target: EntryRedirectTarget.upgrade,
          upgradeReason: 'seats',
        ),
      );
    });
  });
}
