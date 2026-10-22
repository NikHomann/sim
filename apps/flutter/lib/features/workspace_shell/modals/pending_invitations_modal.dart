import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/modals/create_workspace_modal.dart';
import 'package:sim_app/features/workspace_shell/switcher/identity_tile.dart';
import 'package:sim_design/sim_design.dart';

/// `invitationLabel`: organization invites by the organization, workspace
/// invites by the first workspace (`+N` for the rest).
String invitationLabel(InvitationDetails invitation) {
  if (invitation.kind == InvitationKind.organization) {
    return invitation.organizationName ?? 'Organization';
  }
  final first = invitation.grants.isEmpty
      ? null
      : invitation.grants.first.workspaceName;
  if (first != null && first.isNotEmpty) {
    final extra = invitation.grants.length - 1;
    return extra > 0 ? '$first +$extra' : first;
  }
  return 'Workspace';
}

/// `INVITATION_ERROR_MESSAGES` (`lib/invitations/error-messages.ts`).
const Map<String, String> invitationErrorMessages = <String, String>{
  'not-found': 'This invitation is invalid or no longer exists.',
  'invalid-token': 'This invitation link is invalid or has already been used.',
  'expired': 'This invitation has expired. Ask for a new one.',
  'already-processed': 'This invitation has already been accepted or declined.',
  'email-mismatch': 'This invitation was sent to a different email address.',
  'already-in-organization':
      'You are already in an organization. Leave it before accepting a new '
      'invitation.',
  'no-seats-available':
      'This organization has reached its seat limit. Ask an admin to add '
      'seats, then try again.',
  'upgrade-required':
      'The workspace owner needs an active paid plan before you can join. '
      'Ask them to update it, then try again.',
  'external-requires-paid-plan':
      'External collaborators need their own paid Sim plan. Upgrade your '
      'plan, or ask the organization to re-invite you as a member — that '
      'uses one of their seats instead.',
  'disclosure-outdated':
      'What accepting does changed since this list loaded. Reopen your '
      'invitations to see the updated details, then accept again.',
  'workspace-not-found':
      'The workspace this invitation points at could not be found.',
  'server-error':
      'Something went wrong processing the invitation. Please try again.',
};

/// `getInvitationErrorMessage(getErrorMessage(error, ''), fallback)`: the
/// thrown message is the route's machine code; unknown codes and network
/// errors fall back.
String invitationErrorMessage(Object error, String fallback) =>
    invitationErrorMessages[errorMessageOf(error, '')] ?? fallback;

/// Opens `ViewInvitationsModal` (`view-invitations-modal.tsx:66-222`,
/// `modal.invitations`). Accepting closes the modal and navigates to the
/// server's `redirectPath` ([onNavigate], default the router's `go`);
/// declining keeps it open.
Future<void> showPendingInvitationsModal(
  BuildContext context, {
  InvitationsCubit? invitations,
  SimToasts? toasts,
  void Function(String path)? onNavigate,
}) {
  final router = GoRouter.maybeOf(context);
  return showSimChipModal<void>(
    context,
    semanticsLabel: 'Pending invitations',
    builder: (context) => PendingInvitationsModal(
      invitations: invitations ?? locator<InvitationsCubit>(),
      toasts:
          toasts ??
          (locator.isRegistered<SimToasts>()
              ? locator<SimToasts>()
              : SimToasts.instance),
      onNavigate: onNavigate ?? (path) => router?.go(path),
      refetch: locator.isRegistered<QueryClient>()
          ? () => locator<QueryClient>().invalidateQueries(
              InvitationKeys.mine(),
            )
          : null,
    ),
  );
}

class PendingInvitationsModal extends StatefulWidget {
  const PendingInvitationsModal({
    required this.invitations,
    required this.toasts,
    required this.onNavigate,
    super.key,
    this.refetch,
  });

  final InvitationsCubit invitations;
  final SimToasts toasts;
  final void Function(String path) onNavigate;

  /// `invitationsQuery.refetch()` (forced); defaults to
  /// [InvitationsCubit.loadMine].
  final Future<void> Function()? refetch;

  @override
  State<PendingInvitationsModal> createState() =>
      _PendingInvitationsModalState();
}

class _PendingInvitationsModalState extends State<PendingInvitationsModal> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.invitations.loadMine());
  }

  void _refetch() {
    final refetch = widget.refetch;
    unawaited(refetch != null ? refetch() : widget.invitations.loadMine());
  }

  static bool _disclosureMissing(InvitationDetails inv) =>
      inv.membershipIntent == MembershipIntent.internal &&
      inv.joinPreview == null;

  Future<void> _accept(InvitationDetails inv) async {
    if (_busy || _disclosureMissing(inv)) return;
    final close = SimModalScope.of(context).close;
    setState(() => _busy = true);
    try {
      final result = await widget.invitations.accept(
        inv.id,
        disclosedWorkspaceIds: inv.joinPreview?.workspaceIdsToMove,
        disclosedOutcome: inv.joinPreview?.outcome,
      );
      widget.toasts.success('Joined ${invitationLabel(inv)}');
      close();
      widget.onNavigate(result.redirectPath);
    } on Object catch (error) {
      developer.log(
        'Failed to accept invitation',
        name: 'sim_app.invitations',
        error: error,
      );
      widget.toasts.error(
        invitationErrorMessage(
          error,
          'Could not accept the invitation. It may have expired.',
        ),
      );
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(InvitationDetails inv) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.invitations.decline(inv.id);
    } on Object catch (error) {
      developer.log(
        'Failed to decline invitation',
        name: 'sim_app.invitations',
        error: error,
      );
      widget.toasts.error(
        invitationErrorMessage(error, 'Could not decline the invitation.'),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _actions(InvitationDetails inv, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: <Widget>[
      Semantics(
        identifier: 'modal.invitations.decline',
        container: true,
        child: SimChip(
          label: 'Decline',
          semanticsLabel: 'Decline invitation to $label',
          enabled: !_busy,
          onPressed: () => unawaited(_decline(inv)),
        ),
      ),
      Semantics(
        identifier: 'modal.invitations.accept',
        container: true,
        child: SimChip(
          label: 'Accept',
          variant: SimChipVariant.primary,
          enabled: !_busy && !_disclosureMissing(inv),
          onPressed: () => unawaited(_accept(inv)),
        ),
      ),
    ],
  );

  /// One invitation (`view-invitations-modal.tsx:124-206`): the resource
  /// row with the actions inline when there are no details; otherwise the
  /// "Before you join" and "Workspace access" fields with the actions below.
  Widget _section(
    InvitationDetails inv,
    LoadState<List<InvitationDetails>> mine,
  ) {
    final singleGrant =
        inv.kind == InvitationKind.workspace && inv.grants.length == 1
        ? inv.grants.first
        : null;
    final preview = inv.joinPreview;
    final showJoinNotice = preview != null
        ? preview.outcome != JoinOutcome.external
        : inv.membershipIntent == MembershipIntent.internal;
    final showWorkspaceAccess = singleGrant == null && inv.grants.isNotEmpty;
    final hasDetails = showJoinNotice || showWorkspaceAccess;
    final label = invitationLabel(inv);
    final inviter = inv.inviterName;
    final actions = _actions(inv, label);
    return Semantics(
      identifier: 'modal.invitations.row',
      container: true,
      label: 'Invitation to $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              spacing: 12,
              children: <Widget>[
                Expanded(
                  child: _ResourceRow(
                    icon: singleGrant == null
                        ? null
                        : Semantics(
                            identifier: 'modal.invitations.row.tile',
                            container: true,
                            child: IdentityTile(
                              name: singleGrant.workspaceName,
                              logoUrl: singleGrant.workspaceLogoUrl,
                            ),
                          ),
                    title: label,
                    description: inviter != null && inviter.isNotEmpty
                        ? 'Invited by $inviter'
                        : 'Invited',
                    badge: singleGrant == null
                        ? null
                        : SimChipTag(
                            label: '${singleGrant.permission.name} access',
                            variant: SimChipTagVariant.gray,
                          ),
                  ),
                ),
                if (!hasDetails) actions,
              ],
            ),
          ),
          if (showJoinNotice)
            SimChipModalField(
              title: 'Before you join',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: <Widget>[
                  InvitationDisclosure(invitation: inv),
                  if (_disclosureMissing(inv))
                    SimChip(
                      label: 'Refresh invitation',
                      enabled: !_busy && !mine.isFetching,
                      onPressed: _refetch,
                    ),
                ],
              ),
            ),
          if (showWorkspaceAccess)
            SimChipModalField(
              title: 'Workspace access',
              child: InvitationWorkspaceAccess(grants: inv.grants),
            ),
          if (hasDetails)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(alignment: Alignment.centerRight, child: actions),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modal = SimModalScope.of(context);
    return BlocBuilder<InvitationsCubit, InvitationsState>(
      bloc: widget.invitations,
      builder: (context, state) {
        final mine = state.mine;
        final invitations = state.pending;
        final List<Widget> body;
        if (mine.hasError) {
          body = <Widget>[
            _QueryErrorState(
              message: errorMessageOf(
                mine.error ?? '',
                'Could not load invitations',
              ),
              retrying: mine.isFetching,
              onRetry: _refetch,
            ),
          ];
        } else if (!mine.hasData) {
          body = const <Widget>[_InlineEmptyState('Loading invitations…')];
        } else if (invitations.isEmpty) {
          body = const <Widget>[_InlineEmptyState('No pending invitations.')];
        } else {
          body = <Widget>[
            for (var i = 0; i < invitations.length; i++) ...<Widget>[
              if (i > 0) const SimChipModalSeparator(),
              _section(invitations[i], mine),
            ],
          ];
        }
        return Semantics(
          identifier: 'modal.invitations',
          container: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SimChipModalHeader(title: 'Invitations'),
              SimChipModalBody(children: body),
              if (invitations.isEmpty)
                SimChipModalFooterShell(
                  children: <Widget>[
                    SimChip(label: 'Done', onPressed: modal.close),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// `SettingsEmptyState variant='inline'`: centred muted `text-sm`, `py-4`.
class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: sim.text.sm.copyWith(color: sim.colors.textMuted),
      ),
    );
  }
}

/// `SettingsQueryErrorState variant='inline'`: the error message (an alert)
/// above a border chip "Try again" / "Retrying…".
class _QueryErrorState extends StatelessWidget {
  const _QueryErrorState({
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  final String message;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        spacing: 8,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: sim.text.sm.copyWith(color: sim.colors.textMuted),
            ),
          ),
          SimChip(
            label: retrying ? 'Retrying…' : 'Try again',
            variant: SimChipVariant.border,
            enabled: !retrying,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// `SettingsResourceRow flush` with a custom icon: icon, title with an
/// optional badge, muted description.
class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.title,
    this.icon,
    this.description,
    this.badge,
  });

  final Widget? icon;
  final String title;
  final String? description;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final description = this.description;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          spacing: 8,
          children: <Widget>[
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sim.text.sm.copyWith(color: c.textBody),
              ),
            ),
            ?badge,
          ],
        ),
        if (description != null)
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: sim.text.small.copyWith(color: c.textMuted),
          ),
      ],
    );
    final leading = icon;
    if (leading == null) return text;
    return Row(
      spacing: 8,
      children: <Widget>[
        leading,
        Expanded(child: text),
      ],
    );
  }
}

/// `InvitationDisclosure` (`app/invite/components/invitation-disclosure.tsx`)
/// with `showWorkspaceAccess={false}`: what accepting does to the viewer's
/// organization membership and personal workspaces.
class InvitationDisclosure extends StatelessWidget {
  const InvitationDisclosure({required this.invitation, super.key});

  final InvitationDetails invitation;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final base = sim.text.small.copyWith(color: sim.colors.textBody);
    final strong = base.copyWith(
      fontWeight: FontWeight.w500,
      fontVariations: const <FontVariation>[FontVariation('wght', 500)],
    );
    final preview = invitation.joinPreview;
    final outcome =
        preview?.outcome ??
        (invitation.membershipIntent == MembershipIntent.external
            ? JoinOutcome.external
            : null);
    final organizationName =
        preview?.organizationName ??
        (invitation.kind == InvitationKind.organization
            ? invitation.organizationName
            : null) ??
        'the workspace’s organization';
    Widget p(String text) => Text(text, style: base);
    String moving(int i) {
      final names = preview?.workspacesToMove ?? const <String>[];
      return i < names.length && names[i].isNotEmpty
          ? names[i]
          : 'Unnamed workspace';
    }

    final toMove = preview?.workspaceIdsToMove ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: <Widget>[
        if (outcome == JoinOutcome.willJoin) ...<Widget>[
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: 'You will join '),
                TextSpan(text: organizationName, style: strong),
                const TextSpan(text: ' as an organization '),
                TextSpan(text: invitation.role, style: strong),
                const TextSpan(text: '. This uses one organization seat.'),
              ],
            ),
            style: base,
          ),
          if (toMove.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: <Widget>[
                p(
                  'Your owned personal workspaces, including archived '
                  'workspaces, will move into the organization. Its '
                  'administrators will be able to manage them:',
                ),
                Semantics(
                  label: 'Workspaces moving into the organization',
                  container: true,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: <Widget>[
                        for (var i = 0; i < toMove.length; i++)
                          p('• ${moving(i)}'),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            p('You have no personal workspaces to move into the organization.'),
        ],
        if (outcome == JoinOutcome.alreadyMember)
          p(
            'You already belong to this organization. Your organization role '
            'will stay the same. No additional seat is used, and none of '
            'your personal workspaces will move.',
          ),
        if (outcome == JoinOutcome.blocked)
          p(
            'This invitation cannot currently be accepted. Try accepting to '
            'see what needs to be resolved, or contact the person who '
            'invited you.',
          ),
        if (outcome == null)
          p(
            'We could not load how this invitation affects your organization '
            'and personal workspaces. Refresh the invitation to review these '
            'details before accepting.',
          ),
      ],
    );
  }
}

/// `InvitationWorkspaceAccess`: one flush row per grant — identity tile,
/// workspace name (or "Unnamed workspace"), "{permission} access" tag.
class InvitationWorkspaceAccess extends StatelessWidget {
  const InvitationWorkspaceAccess({required this.grants, super.key});

  final List<InvitationGrant> grants;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Invited workspace access',
    container: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        for (final grant in grants)
          _ResourceRow(
            icon: IdentityTile(
              name: grant.workspaceName,
              logoUrl: grant.workspaceLogoUrl,
            ),
            title: switch (grant.workspaceName) {
              final name? when name.isNotEmpty => name,
              _ => 'Unnamed workspace',
            },
            badge: SimChipTag(
              label: '${grant.permission.name} access',
              variant: SimChipTagVariant.gray,
            ),
          ),
      ],
    ),
  );
}
