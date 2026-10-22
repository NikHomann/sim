// Failure modes (what a golden diff must catch, workspace-chrome.md and
// global-behaviours.md colour anchors and layout):
// - the shell frame: rail width, content pane border and fills (C1-C3)
// - the access-denied page composition (G5/G6, 448px column, disc, CTA)
// - the session-expired takeover covering everything on --bg (G4)
// - the loading surface: centred wordmark on --bg (C7)
// The sidebar slot is a stub here (the sidebar has its own goldens).

import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';

import 'support/shell_goldens.dart';
import 'support/shell_harness.dart';

const String home = '/workspace/$workspaceId/home';

void main() {
  shellGoldens('workspace shell', fileName: 'shell_home', location: home);

  shellGoldens(
    'workspace access denied',
    fileName: 'shell_access_denied',
    location: home,
    arrange: (h) => when(
      () =>
          h.runtime.hostContext(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => WorkspaceAccess.denied(error: apiError(403))),
  );

  shellGoldens(
    'session expired takeover',
    fileName: 'shell_session_expired',
    location: home,
    act: (tester, h) async {
      h.actionsLog.signOutGate = Completer<void>();
      h.sessionCubit.setSession(null);
      await tester.pump();
      await tester.pump();
    },
  );

  shellGoldens(
    'application loading',
    fileName: 'shell_loading',
    location: home,
    settle: false,
    arrange: (h) => when(
      () =>
          h.runtime.hostContext(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) => Completer<WorkspaceAccess>().future),
  );
}
