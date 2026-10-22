// Failure modes (workspace-modals.md):
// Create
// - "Create" enabled for a blank name; the name is sent untrimmed
// - a server error closes the modal or is not shown; a reopen keeps the
//   previous name or error
// - success does not close
// Invite
// - "Send invites" enabled without emails, without a workspace, or for a
//   viewer who cannot invite
// - an invalid or own address is sent
// - the batch body carries `membership` for a personal workspace
// - the address tags render outside the emails field surface (above the
//   text entry) instead of inline before it
// - a partial failure closes the modal or drops the failed addresses; the
//   composed headline / reason list / "And N more." is wrong
// Delete
// - "Delete" enabled before the exact name is typed; Enter confirms
// - a failure keeps the modal open (React logs and closes,
//   `workspace-header.tsx:436-445`)
// Leave
// - a failure closes the modal or shows no toast
// Invitations
// - accept does not toast, close and navigate to the server's redirectPath
// - an accept error shows a fixed string instead of the mapped error code
// - a single-workspace grant has no identity tile; an invitation with
//   details keeps its actions inline and "Refresh invitation" outside the
//   "Before you join" field
// - a load error offers no "Try again"
// Logo
// - an oversized or unsupported file is uploaded; the PATCH is skipped or
//   sent with something other than the completed session's path

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/modals/create_workspace_modal.dart';
import 'package:sim_app/features/workspace_shell/modals/invite_modal.dart';
import 'package:sim_app/features/workspace_shell/modals/logo_upload.dart';
import 'package:sim_app/features/workspace_shell/modals/pending_invitations_modal.dart';
import 'package:sim_app/features/workspace_shell/modals/workspace_confirm_modals.dart';
import 'package:sim_design/sim_design.dart';

import '../chrome/support/shell_harness.dart';

const String home = '/workspace/$workspaceId/home';

class MockUploadSessionClient extends Mock implements UploadSessionClient {}

class FakeUploadSource extends Fake implements UploadSource {}

Finder chip(String label) => find.descendant(
  of: find.byType(SimChip),
  matching: find.text(label),
);

bool chipEnabled(WidgetTester tester, String label) => tester
    .widget<SimChip>(
      find.ancestor(of: find.text(label), matching: find.byType(SimChip)).first,
    )
    .enabled;

void main() {
  late ShellHarness h;

  setUpAll(() {
    registerFallbackValue(FakeUploadSource());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() async {
    h = ShellHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  Future<BuildContext> openShell(WidgetTester tester) async {
    await h.pump(tester, home);
    await tester.pumpAndSettle();
    return tester.element(find.text('Home'));
  }

  group('create workspace', () {
    testWidgets('blank name disabled; trimmed name; error stays; success '
        'closes', (tester) async {
      final context = await openShell(tester);
      final names = <String>[];
      Future<void> create(String name) async {
        names.add(name);
        if (names.length == 1) throw apiError(403, 'Workspace limit reached');
      }

      unawaited(showCreateWorkspaceModal(context, onConfirm: create));
      await tester.pumpAndSettle();
      expect(byParityId('modal.create-workspace'), findsOneWidget);
      expect(chipEnabled(tester, 'Create'), isFalse);

      await tester.enterText(
        find.descendant(
          of: byParityId('modal.create-workspace.name'),
          matching: find.byType(EditableText),
        ),
        '   ',
      );
      await tester.pump();
      expect(chipEnabled(tester, 'Create'), isFalse);

      await tester.enterText(
        find.descendant(
          of: byParityId('modal.create-workspace.name'),
          matching: find.byType(EditableText),
        ),
        '  Acme  ',
      );
      await tester.pump();
      await tester.tap(chip('Create'));
      await tester.pumpAndSettle();
      expect(names, ['Acme']);
      expect(find.text('Workspace limit reached'), findsOneWidget);
      expect(byParityId('modal.create-workspace'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(byParityId('modal.create-workspace'), findsNothing);
      expect(names, ['Acme', 'Acme']);
    });

    testWidgets('reopening starts empty', (tester) async {
      final context = await openShell(tester);
      Future<void> create(String name) async {}
      unawaited(showCreateWorkspaceModal(context, onConfirm: create));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'Draft');
      await tester.tap(chip('Cancel'));
      await tester.pumpAndSettle();
      unawaited(showCreateWorkspaceModal(context, onConfirm: create));
      await tester.pumpAndSettle();
      expect(find.text('Draft'), findsNothing);
      expect(chipEnabled(tester, 'Create'), isFalse);
    });
  });

  group('invite', () {
    test('failure message: single, headline, distinct reasons, overflow', () {
      const a = BatchInvitationFailure(email: 'a@x.io', error: 'Reason A');
      expect(buildInviteFailureMessage(const [a], 3), 'Reason A');
      final many = <BatchInvitationFailure>[
        for (final r in ['R1', 'R2', 'R1', 'R3', 'R4', 'R5'])
          BatchInvitationFailure(email: '$r@x.io', error: r),
      ];
      expect(
        buildInviteFailureMessage(many, 6),
        'None of the 6 invitations could be sent. R1 R2 R3 And 2 more.',
      );
      expect(
        buildInviteFailureMessage(many.take(2).toList(), 5),
        '2 of 5 invitations could not be sent. R1 R2',
      );
    });

    Future<void> typeEmails(WidgetTester tester, String text) async {
      final field = find.descendant(
        of: byParityId('modal.invite.emails'),
        matching: find.byType(EditableText),
      );
      await tester.enterText(field, text);
      await tester.pump();
    }

    testWidgets('validation, body shape, partial failure keeps the failed', (
      tester,
    ) async {
      final context = await openShell(tester);
      when(
        () => h.invitationsRepo.sendBatch(
          workspaceIds: any(named: 'workspaceIds'),
          emails: any(named: 'emails'),
          permission: any(named: 'permission'),
          membership: any(named: 'membership'),
          organizationId: any(named: 'organizationId'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => const BatchInvitationResult(
          success: true,
          successful: ['ok@acme.io'],
          added: [],
          failed: [
            BatchInvitationFailure(
              email: 'no@acme.io',
              error: 'Already a member',
            ),
          ],
          invitations: [],
        ),
      );
      unawaited(
        showInviteModal(
          context,
          config: const InviteModalConfig(
            workspaceId: workspaceId,
            workspaceName: 'Flutter E2E workspace',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(chipEnabled(tester, 'Send invites'), isFalse);

      await typeEmails(
        tester,
        'not-an-email flutter-e2e@example.com OK@acme.io no@acme.io ',
      );
      expect(find.text('Invalid email format'), findsOneWidget);
      expect(chipEnabled(tester, 'Send invites'), isTrue);

      await tester.tap(chip('Send invites'));
      await tester.pumpAndSettle();
      final captured = verify(
        () => h.invitationsRepo.sendBatch(
          workspaceIds: captureAny(named: 'workspaceIds'),
          emails: captureAny(named: 'emails'),
          permission: captureAny(named: 'permission'),
          membership: captureAny(named: 'membership'),
          organizationId: captureAny(named: 'organizationId'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).captured;
      expect(captured[0], [workspaceId]);
      expect(captured[1], ['ok@acme.io', 'no@acme.io']);
      expect(captured[2], WorkspacePermission.write);
      expect(captured[3], isNull, reason: 'membership only for org invites');
      expect(captured[4], isNull);

      expect(byParityId('modal.invite'), findsOneWidget);
      expect(find.text('Already a member'), findsOneWidget);
      expect(find.text('no@acme.io'), findsOneWidget);
      expect(find.text('ok@acme.io'), findsNothing);
      expect(h.toasts.toasts.single.message, '1 invite sent');
    });

    testWidgets('a viewer who cannot invite sees the reason and no send', (
      tester,
    ) async {
      final context = await openShell(tester);
      unawaited(
        showInviteModal(
          context,
          config: const InviteModalConfig(
            workspaceId: workspaceId,
            canInvite: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Only administrators can invite new teammates'),
        findsOneWidget,
      );
      expect(chipEnabled(tester, 'Send invites'), isFalse);
    });

    testWidgets('address tags sit inside the field surface, inline before '
        'the entry', (tester) async {
      final context = await openShell(tester);
      unawaited(
        showInviteModal(
          context,
          config: const InviteModalConfig(workspaceId: workspaceId),
        ),
      );
      await tester.pumpAndSettle();
      await typeEmails(tester, 'ok@acme.io ');
      final tag = tester.getRect(
        find.ancestor(
          of: find.text('ok@acme.io'),
          matching: find.byType(SimChipTag),
        ),
      );
      final entry = tester.getRect(
        find.descendant(
          of: byParityId('modal.invite.emails'),
          matching: find.byType(EditableText),
        ),
      );
      // Same row: the entry starts right of the tag and overlaps it
      // vertically (not stacked below a separate input).
      expect(entry.left, greaterThan(tag.right));
      expect(entry.top, lessThan(tag.bottom));
      expect(entry.bottom, greaterThan(tag.top));
      // One surface: the block variant's 112px minimum holds both.
      final surface = tester.getRect(
        find
            .ancestor(
              of: find.byType(SimChipTag),
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.constraints?.minHeight == 112,
              ),
            )
            .first,
      );
      expect(surface.contains(tag.center), isTrue);
      expect(surface.contains(entry.center), isTrue);
    });
  });

  group('delete workspace', () {
    testWidgets('exact name enables; Enter never confirms; success closes', (
      tester,
    ) async {
      final context = await openShell(tester);
      var deletes = 0;
      unawaited(
        showDeleteWorkspaceModal(
          context,
          workspaceName: workspace().name,
          onConfirm: () async => deletes++,
        ),
      );
      await tester.pumpAndSettle();
      final input = find.descendant(
        of: byParityId('modal.delete-workspace.confirm-input'),
        matching: find.byType(EditableText),
      );
      await tester.enterText(input, 'flutter e2e workspace');
      await tester.pump();
      expect(chipEnabled(tester, 'Delete'), isFalse);
      await tester.enterText(input, 'Flutter E2E workspace');
      await tester.pump();
      expect(chipEnabled(tester, 'Delete'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(deletes, 0);
      expect(byParityId('modal.delete-workspace'), findsOneWidget);

      await tester.tap(chip('Delete'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(byParityId('modal.delete-workspace'), findsNothing);
    });

    testWidgets('a failure is logged and closes the modal', (tester) async {
      final context = await openShell(tester);
      unawaited(
        showDeleteWorkspaceModal(
          context,
          workspaceName: workspace().name,
          onConfirm: () async => throw apiError(500),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: byParityId('modal.delete-workspace.confirm-input'),
          matching: find.byType(EditableText),
        ),
        'Flutter E2E workspace',
      );
      await tester.pump();
      await tester.tap(chip('Delete'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(byParityId('modal.delete-workspace'), findsNothing);
    });
  });

  testWidgets('leave: failure toasts the reason and stays open', (
    tester,
  ) async {
    final context = await openShell(tester);
    unawaited(
      showLeaveWorkspaceModal(
        context,
        workspaceName: workspace().name,
        onConfirm: () async => throw apiError(403, 'Owners cannot leave'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(chip('Leave workspace'));
    await tester.pumpAndSettle();
    expect(byParityId('modal.leave-workspace'), findsOneWidget);
    final toast = h.toasts.toasts.single;
    expect(toast.message, "Couldn't leave workspace");
    expect(toast.description, 'Owners cannot leave');
  });

  testWidgets('invitations: accept toasts, closes and follows redirectPath', (
    tester,
  ) async {
    final context = await openShell(tester);
    const invitation = InvitationDetails(
      id: 'inv-1',
      kind: InvitationKind.workspace,
      email: 'flutter-e2e@example.com',
      organizationId: null,
      organizationName: null,
      membershipIntent: MembershipIntent.external,
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
    );
    when(
      () => h.invitationsRepo.listMine(cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => [invitation]);
    when(
      () => h.invitationsRepo.accept(
        any(),
        token: any(named: 'token'),
        disclosedWorkspaceIds: any(named: 'disclosedWorkspaceIds'),
        disclosedOutcome: any(named: 'disclosedOutcome'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => const AcceptedInvitation(
        redirectPath: '/workspace/$otherWorkspaceId/home',
        id: 'inv-1',
        kind: InvitationKind.workspace,
        organizationId: null,
        acceptedWorkspaceIds: [otherWorkspaceId],
      ),
    );
    when(
      () => h.invitationsRepo.listMine(cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => [invitation]);
    unawaited(showPendingInvitationsModal(context));
    await tester.pumpAndSettle();
    expect(byParityId('modal.invitations.row'), findsOneWidget);
    expect(find.text('Invited by Ada'), findsOneWidget);
    await tester.tap(chip('Accept'));
    await tester.pumpAndSettle();
    expect(h.toasts.toasts.single.message, 'Joined Acme');
    expect(byParityId('modal.invitations'), findsNothing);
    expect(h.location, '/workspace/$otherWorkspaceId/home');
  });

  group('invitations modal structure', () {
    InvitationDetails invite({
      MembershipIntent intent = MembershipIntent.external,
      List<InvitationGrant> grants = const [
        InvitationGrant(
          workspaceId: otherWorkspaceId,
          workspaceName: 'Acme',
          permission: WorkspacePermission.write,
        ),
      ],
    }) => InvitationDetails(
      id: 'inv-1',
      kind: InvitationKind.workspace,
      email: 'flutter-e2e@example.com',
      organizationId: null,
      organizationName: null,
      membershipIntent: intent,
      role: 'member',
      status: 'pending',
      expiresAt: '2026-11-01T00:00:00.000Z',
      createdAt: '2026-10-21T00:00:00.000Z',
      inviterName: 'Ada',
      inviterEmail: 'ada@acme.io',
      grants: grants,
    );

    void listMine(Future<List<InvitationDetails>> Function() answer) => when(
      () => h.invitationsRepo.listMine(cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) => answer());

    testWidgets('a single-workspace grant shows its identity tile', (
      tester,
    ) async {
      final context = await openShell(tester);
      listMine(() async => [invite()]);
      unawaited(showPendingInvitationsModal(context));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: byParityId('modal.invitations.row'),
          matching: find.text('A'),
        ),
        findsOneWidget,
        reason: 'IdentityTile initial of "Acme"',
      );
    });

    testWidgets('an accept error maps the server code to its sentence', (
      tester,
    ) async {
      final context = await openShell(tester);
      listMine(() async => [invite()]);
      when(
        () => h.invitationsRepo.accept(
          any(),
          token: any(named: 'token'),
          disclosedWorkspaceIds: any(named: 'disclosedWorkspaceIds'),
          disclosedOutcome: any(named: 'disclosedOutcome'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(apiError(409, 'no-seats-available'));
      unawaited(showPendingInvitationsModal(context));
      await tester.pumpAndSettle();
      await tester.tap(chip('Accept'));
      await tester.pumpAndSettle();
      expect(
        h.toasts.toasts.single.message,
        'This organization has reached its seat limit. Ask an admin to add '
        'seats, then try again.',
      );
      expect(byParityId('modal.invitations'), findsOneWidget);
    });

    testWidgets('an internal invite without its preview: "Before you join" '
        'holds Refresh, the actions sit below it', (tester) async {
      final context = await openShell(tester);
      listMine(() async => [invite(intent: MembershipIntent.internal)]);
      unawaited(showPendingInvitationsModal(context));
      await tester.pumpAndSettle();
      final field = find.ancestor(
        of: find.text('Before you join'),
        matching: find.byType(SimChipModalField),
      );
      expect(field, findsOneWidget);
      expect(
        find.descendant(of: field, matching: find.text('Refresh invitation')),
        findsOneWidget,
      );
      expect(chipEnabled(tester, 'Accept'), isFalse);
      expect(
        tester.getRect(find.text('Accept')).top,
        greaterThan(tester.getRect(field).bottom),
      );
    });

    testWidgets('several grants list under "Workspace access"', (
      tester,
    ) async {
      final context = await openShell(tester);
      listMine(
        () async => [
          invite(
            grants: const [
              InvitationGrant(
                workspaceId: 'a',
                workspaceName: 'Alpha',
                permission: WorkspacePermission.read,
              ),
              InvitationGrant(
                workspaceId: 'b',
                workspaceName: null,
                permission: WorkspacePermission.admin,
              ),
            ],
          ),
        ],
      );
      unawaited(showPendingInvitationsModal(context));
      await tester.pumpAndSettle();
      final field = find.ancestor(
        of: find.text('Workspace access'),
        matching: find.byType(SimChipModalField),
      );
      expect(
        find.descendant(of: field, matching: find.text('Unnamed workspace')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: field, matching: find.text('admin access')),
        findsOneWidget,
      );
    });

    testWidgets('a load error offers "Try again", which refetches', (
      tester,
    ) async {
      final context = await openShell(tester);
      var calls = 0;
      listMine(() async {
        calls++;
        throw apiError(500, 'Could not load invitations');
      });
      unawaited(showPendingInvitationsModal(context));
      await tester.pumpAndSettle();
      expect(find.text('Could not load invitations'), findsOneWidget);
      final before = calls;
      await tester.tap(chip('Try again'));
      await tester.pumpAndSettle();
      expect(calls, greaterThan(before));
    });
  });

  group('logo upload', () {
    late MockUploadSessionClient uploads;
    late List<String> errors;
    late WorkspaceLogoUploader uploader;

    setUp(() {
      uploads = MockUploadSessionClient();
      errors = <String>[];
      uploader = WorkspaceLogoUploader(
        uploads: uploads,
        workspaces: h.workspaces,
        onError: errors.add,
      );
    });

    test('rejects oversized and unsupported files without uploading', () async {
      const unsupportedPdf =
          'File "doc.pdf" is not a supported image format. Please use PNG, '
          'JPEG, GIF, SVG, or WebP.';
      expect(
        await uploader.upload(
          workspaceId: workspaceId,
          name: 'big.png',
          contentType: 'image/png',
          bytes: Uint8List(maxLogoBytes + 1),
        ),
        isNull,
      );
      expect(
        await uploader.upload(
          workspaceId: workspaceId,
          name: 'doc.pdf',
          contentType: 'application/pdf',
          bytes: Uint8List(10),
        ),
        isNull,
      );
      expect(errors, [
        'File "big.png" is too large. Maximum size is 5MB.',
        unsupportedPdf,
      ]);
      verifyNever(
        () => uploads.upload(
          body: any(named: 'body'),
          source: any(named: 'source'),
        ),
      );
    });

    test('uploads with purpose workspace_logo then patches the path', () async {
      when(
        () => uploads.upload(
          body: any(named: 'body'),
          source: any(named: 'source'),
          cancelToken: any(named: 'cancelToken'),
          onSession: any(named: 'onSession'),
        ),
      ).thenAnswer(
        (_) async => <String, Object?>{
          'purpose': 'workspace_logo',
          'result': <String, Object?>{'path': '/api/files/serve/logo.png'},
        },
      );
      when(
        () => h.workspacesRepo.update(
          any(),
          name: any(named: 'name'),
          logoUrl: any(named: 'logoUrl'),
          clearLogo: any(named: 'clearLogo'),
          billedAccountUserId: any(named: 'billedAccountUserId'),
          allowPersonalApiKeys: any(named: 'allowPersonalApiKeys'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => workspace());
      final path = await uploader.upload(
        workspaceId: workspaceId,
        name: 'logo.png',
        contentType: 'image/png',
        bytes: Uint8List(64),
      );
      expect(path, '/api/files/serve/logo.png');
      final body =
          verify(
                () => uploads.upload(
                  body: captureAny(named: 'body'),
                  source: any(named: 'source'),
                  cancelToken: any(named: 'cancelToken'),
                  onSession: any(named: 'onSession'),
                ),
              ).captured.single
              as Map<String, Object?>;
      expect(body, {
        'purpose': 'workspace_logo',
        'workspaceId': workspaceId,
        'name': 'logo.png',
        'contentType': 'image/png',
        'size': 64,
      });
      verify(
        () => h.workspacesRepo.update(
          workspaceId,
          name: any(named: 'name'),
          logoUrl: '/api/files/serve/logo.png',
          clearLogo: any(named: 'clearLogo'),
          billedAccountUserId: any(named: 'billedAccountUserId'),
          allowPersonalApiKeys: any(named: 'allowPersonalApiKeys'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });
  });
}
