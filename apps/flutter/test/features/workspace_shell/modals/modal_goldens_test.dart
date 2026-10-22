// Failure modes (what a golden diff must catch, workspace-modals.md M1-M8):
// - the ChipModal chrome: 3px ring on --surface-4/-5, inner --bg panel,
//   header separator, --surface-3 footer band, 500px / 440px widths
// - the overlay tint over the shell
// - create: name field and the disabled primary; invite: emails field,
//   workspace / access dropdowns; delete: emphasised copy, red warning,
//   the type-to-confirm field and the destructive chip; invitations: the
//   resource row, the "Before you join" field with Refresh, the actions
//   below the details

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/modals/create_workspace_modal.dart';
import 'package:sim_app/features/workspace_shell/modals/invite_modal.dart';
import 'package:sim_app/features/workspace_shell/modals/pending_invitations_modal.dart';
import 'package:sim_app/features/workspace_shell/modals/workspace_confirm_modals.dart';

import '../chrome/support/shell_goldens.dart';
import '../chrome/support/shell_harness.dart';

const String home = '/workspace/$workspaceId/home';

BuildContext shellContext(WidgetTester tester) =>
    tester.element(find.text('Home'));

void main() {
  shellGoldens(
    'create workspace modal',
    fileName: 'modal_create_workspace',
    location: home,
    act: (tester, h) async => unawaited(
      showCreateWorkspaceModal(
        shellContext(tester),
        onConfirm: (_) async {},
      ),
    ),
  );

  shellGoldens(
    'invite modal',
    fileName: 'modal_invite',
    location: home,
    act: (tester, h) async => unawaited(
      showInviteModal(
        shellContext(tester),
        config: const InviteModalConfig(
          workspaceId: workspaceId,
          workspaceName: 'Flutter E2E workspace',
        ),
      ),
    ),
  );

  shellGoldens(
    'delete workspace modal',
    fileName: 'modal_delete_workspace',
    location: home,
    act: (tester, h) async => unawaited(
      showDeleteWorkspaceModal(
        shellContext(tester),
        workspaceName: workspace().name,
        onConfirm: () async {},
      ),
    ),
  );

  shellGoldens(
    'pending invitations modal',
    fileName: 'modal_pending_invitations',
    location: home,
    arrange: (h) =>
        when(
          () => h.invitationsRepo.listMine(
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => const [
            InvitationDetails(
              id: 'inv-1',
              kind: InvitationKind.workspace,
              email: 'flutter-e2e@example.com',
              organizationId: null,
              organizationName: null,
              membershipIntent: MembershipIntent.internal,
              role: 'member',
              status: 'pending',
              expiresAt: '2026-11-01T00:00:00.000Z',
              createdAt: '2026-10-21T00:00:00.000Z',
              inviterName: 'Ada',
              inviterEmail: 'ada@acme.io',
              grants: [
                InvitationGrant(
                  workspaceId: otherWorkspaceId,
                  workspaceName: 'Acme',
                  permission: WorkspacePermission.write,
                ),
              ],
            ),
          ],
        ),
    act: (tester, h) async =>
        unawaited(showPendingInvitationsModal(shellContext(tester))),
  );
}
