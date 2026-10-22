import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/features/auth/invite/invite_cubit.dart';
import 'package:sim_app/features/auth/shared/auth_api.dart';
import 'package:sim_app/features/auth/shared/auth_scope.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_bits.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_shell.dart';
import 'package:sim_design/sim_design.dart';

/// `/invite/:id` (`invite-accept.md`).
class InvitePage extends StatefulWidget {
  const InvitePage({required this.inviteId, required this.query, super.key});

  final String inviteId;
  final Map<String, String> query;

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  InviteCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final deps = AuthScope.of(context);
    _cubit = InviteCubit(
      api: deps.api,
      navigator: deps.navigator,
      sessionStore: deps.sessionStore,
      timers: deps.timers,
      origin: deps.origin,
      inviteId: widget.inviteId,
      query: widget.query,
    );
    unawaited(_cubit!.load());
  }

  @override
  void dispose() {
    unawaited(_cubit?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<InviteCubit>.value(
    value: _cubit!,
    child: const InviteView(),
  );
}

/// One card action (`InviteAction`).
class InviteAction {
  const InviteAction({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final bool loading;
}

/// The invite card under the shell with the support footer; expects an
/// [InviteCubit] above.
class InviteView extends StatelessWidget {
  const InviteView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InviteCubit>();
    return AuthShell(
      onHome: cubit.returnHome,
      footer: SupportFooter(onContact: cubit.contactSupport),
      child: BlocBuilder<InviteCubit, InviteState>(
        builder: (context, state) => switch (state.phase) {
          InvitePhase.loading => const InviteStatusCard.loading(
            description: 'Loading invitation...',
          ),
          InvitePhase.signedOut => _signedOut(cubit, state),
          InvitePhase.error => _error(cubit, state),
          InvitePhase.accepted => InviteStatusCard(
            title: 'Welcome!',
            description:
                'You have successfully joined ${state.displayName}. Redirecting...',
            actions: <InviteAction>[
              InviteAction(
                label: 'Return to Home',
                onPressed: cubit.returnHome,
              ),
            ],
          ),
          InvitePhase.invitation => _invitation(cubit, state),
        },
      ),
    );
  }

  /// `signedOutPrompt`.
  Widget _signedOut(InviteCubit cubit, InviteState state) {
    final signIn = InviteAction(label: 'Sign in', onPressed: cubit.goToLogin);
    final String description;
    final List<InviteAction> actions;
    if (state.registrationDisabled) {
      description = 'Account creation is disabled on this instance';
      actions = <InviteAction>[signIn];
    } else if (state.isNewUser) {
      description = 'Create an account to join this workspace on Sim';
      actions = <InviteAction>[
        InviteAction(label: 'Create an account', onPressed: cubit.goToSignup),
        InviteAction(
          label: 'I already have an account',
          onPressed: cubit.goToLogin,
        ),
      ];
    } else {
      description = 'Sign in to your account to accept this invitation';
      actions = <InviteAction>[
        signIn,
        InviteAction(
          label: 'Create an account',
          onPressed: () => cubit.goToSignup(isNewUser: true),
        ),
      ];
    }
    return InviteStatusCard(
      title: "You've been invited!",
      description: description,
      actions: <InviteAction>[
        ...actions,
        InviteAction(label: 'Return to Home', onPressed: cubit.returnHome),
      ],
    );
  }

  Widget _error(InviteCubit cubit, InviteState state) {
    final error = state.error!;
    final home = InviteAction(
      label: 'Return to Home',
      onPressed: cubit.returnHome,
    );
    if (error.code == 'email-mismatch') {
      return InviteStatusCard(
        title: 'Wrong Account',
        description: error.message,
        actions: <InviteAction>[
          InviteAction(
            label: 'Sign in with a different account',
            onPressed: cubit.signInWithDifferentAccount,
            loading: state.signingOut,
          ),
          home,
        ],
      );
    }
    if (error.code == 'already-in-organization') {
      return InviteStatusCard(
        title: 'Already Part of a Team',
        description: error.message,
        actions: <InviteAction>[
          InviteAction(
            label: 'Manage Team Settings',
            onPressed: cubit.goToEntry,
          ),
          home,
        ],
      );
    }
    if (error.requiresAuth) {
      return InviteStatusCard(
        title: 'Authentication Required',
        description: error.message,
        actions: <InviteAction>[
          InviteAction(
            label: 'Sign in to continue',
            onPressed: cubit.goToLogin,
          ),
          if (!state.registrationDisabled)
            InviteAction(
              label: 'Create an account',
              onPressed: cubit.goToSignup,
            ),
          home,
        ],
      );
    }
    return InviteStatusCard(
      title: 'Invitation Error',
      description: error.message,
      isExpiredError: error.code == 'expired',
      onRequestNewInvitation: cubit.returnHome,
      actions: <InviteAction>[
        if (error.canRetry)
          InviteAction(label: 'Try Again', onPressed: cubit.tryAgain),
        home,
      ],
    );
  }

  Widget _invitation(InviteCubit cubit, InviteState state) {
    final invitation = state.invitation!;
    final isOrg = invitation.kind == 'organization';
    return InviteStatusCard(
      title: isOrg ? 'Organization Invitation' : 'Workspace Invitation',
      description: "You've been invited to join ${state.displayName}.",
      details: InvitationDisclosure(
        invitation: invitation,
        joinPreview: state.joinPreview,
      ),
      actions: <InviteAction>[
        InviteAction(
          label: 'Accept Invitation',
          onPressed: cubit.accept,
          enabled: !state.accepting && !state.isDisclosureMissing,
          loading: state.accepting,
        ),
        if (state.isDisclosureMissing)
          InviteAction(
            label: 'Refresh invitation',
            onPressed: cubit.refresh,
            enabled: !state.refetching,
          ),
        InviteAction(label: 'Return to Home', onPressed: cubit.returnHome),
      ],
    );
  }
}

/// Port of `status-card.tsx`: 32px / 48px title (−0.025em), 16px muted
/// description, then the `mt-8` action block (12px gaps) — details first,
/// the expired-only primary "Request New Invitation", the first action as a
/// primary chip, the rest as bordered chips.
class InviteStatusCard extends StatelessWidget {
  const InviteStatusCard({
    required this.title,
    required this.description,
    super.key,
    this.details,
    this.actions = const <InviteAction>[],
    this.isExpiredError = false,
    this.onRequestNewInvitation,
  }) : loading = false;

  const InviteStatusCard.loading({required this.description, super.key})
    : title = 'Loading',
      details = null,
      actions = const <InviteAction>[],
      isExpiredError = false,
      onRequestNewInvitation = null,
      loading = true;

  final String title;
  final String description;
  final Widget? details;
  final List<InviteAction> actions;
  final bool isExpiredError;
  final VoidCallback? onRequestNewInvitation;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final header = Semantics(
      container: true,
      identifier: 'invite.card.header',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: <Widget>[
          Semantics(
            container: true,
            identifier: 'invite.card.title',
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: sim.text
                  .style(32)
                  .copyWith(color: c.textPrimary, letterSpacing: -0.025 * 32),
            ),
          ),
          Semantics(
            container: true,
            identifier: 'invite.card.description',
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: sim.text.md.copyWith(color: c.textMuted),
            ),
          ),
        ],
      ),
    );
    if (loading) {
      return Semantics(
        container: true,
        identifier: 'invite.card',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            header,
            Semantics(
              container: true,
              identifier: 'invite.card.loader',
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: SimSpinner(size: 32, color: c.textMuted),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      container: true,
      identifier: 'invite.card',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          Semantics(
            container: true,
            identifier: 'invite.card.actions',
            child: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: <Widget>[
                  ?details,
                  if (isExpiredError)
                    AuthSubmitButton(
                      label: 'Request New Invitation',
                      loadingLabel: '',
                      identifier: 'invite.card.requestNew',
                      onPressed: onRequestNewInvitation,
                    ),
                  for (final (index, action) in actions.indexed)
                    index == 0
                        ? AuthSubmitButton(
                            label: action.label,
                            loadingLabel: '${action.label}...',
                            identifier: 'invite.card.action.$index',
                            enabled: action.enabled,
                            loading: action.loading,
                            onPressed: action.onPressed,
                          )
                        : AuthChipButton(
                            label: action.label,
                            loadingLabel: '${action.label}...',
                            identifier: 'invite.card.action.$index',
                            enabled: action.enabled,
                            loading: action.loading,
                            onPressed: action.onPressed,
                          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Port of `invitation-disclosure.tsx`: the join-preview copy (13px
/// `--text-body`, 12px gaps) and the workspace-access rows.
class InvitationDisclosure extends StatelessWidget {
  const InvitationDisclosure({
    required this.invitation,
    required this.joinPreview,
    super.key,
  });

  final InviteDetails invitation;
  final InviteJoinPreview? joinPreview;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final body = sim.text.small.copyWith(color: c.textBody);
    final strong = SimTextStyles.weight(body, SimTextStyles.medium);
    final preview = joinPreview;
    final outcome =
        preview?.outcome ??
        (invitation.membershipIntent == 'external' ? 'external' : null);
    final organizationName =
        preview?.organizationName ??
        (invitation.kind == 'organization'
            ? invitation.organizationName
            : null) ??
        'the workspace’s organization';
    return Semantics(
      container: true,
      identifier: 'invite.details',
      child: DefaultTextStyle(
        style: body,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: <Widget>[
            if (outcome == 'will-join') ...<Widget>[
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    const TextSpan(text: 'You will join '),
                    TextSpan(text: organizationName, style: strong),
                    const TextSpan(text: ' as an organization '),
                    TextSpan(text: invitation.role ?? '', style: strong),
                    const TextSpan(text: '. This uses one organization seat.'),
                  ],
                ),
              ),
              if (preview != null && preview.workspaceIdsToMove.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Your owned personal workspaces, including archived '
                      'workspaces, will move into the organization. Its '
                      'administrators will be able to manage them:',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 4,
                        children: <Widget>[
                          for (final (i, _)
                              in preview.workspaceIdsToMove.indexed)
                            Text(
                              '• ${(i < preview.workspacesToMove.length ? preview.workspacesToMove[i] : null) ?? 'Unnamed workspace'}',
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  'You have no personal workspaces to move into the organization.',
                ),
            ],
            if (outcome == 'already-member')
              const Text(
                'You already belong to this organization. Your organization '
                'role will stay the same. No additional seat is used, and none '
                'of your personal workspaces will move.',
              ),
            if (outcome == 'blocked')
              const Text(
                'This invitation cannot currently be accepted. Try accepting to '
                'see what needs to be resolved, or contact the person who '
                'invited you.',
              ),
            if (outcome == null)
              const Text(
                'We could not load how this invitation affects your '
                'organization and personal workspaces. Refresh the invitation '
                'to review these details before accepting.',
              ),
            if (invitation.grants.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: <Widget>[
                  Text(
                    'Workspace access',
                    style: sim.text.caption.copyWith(color: c.textMuted),
                  ),
                  Semantics(
                    container: true,
                    identifier: 'invite.details.access',
                    label: 'Invited workspace access',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: <Widget>[
                        for (final grant in invitation.grants)
                          _WorkspaceAccessRow(grant: grant),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// `getWorkspaceInitial`.
String workspaceInitial(String? name) {
  final stripped = (name ?? '')
      .replaceAll(RegExp('workspace', caseSensitive: false), '')
      .trim();
  final first = stripped.isNotEmpty
      ? stripped[0]
      : (name != null && name.isNotEmpty ? name[0] : 'W');
  return first.toUpperCase();
}

/// `SettingsResourceRow flush` with a 16px `IdentityTile` and a gray
/// `ChipTag` "{permission} access".
class _WorkspaceAccessRow extends StatelessWidget {
  const _WorkspaceAccessRow({required this.grant});

  final InviteGrant grant;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 10,
      children: <Widget>[
        Expanded(
          child: Row(
            spacing: 10,
            children: <Widget>[
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: c.surface6,
                  borderRadius: BorderRadius.circular(SimRadii.identityTile16),
                ),
                alignment: Alignment.center,
                child: Text(
                  workspaceInitial(grant.workspaceName),
                  style: sim.text.micro.copyWith(color: c.textIcon, height: 1),
                ),
              ),
              Flexible(
                child: Text(
                  grant.workspaceName?.isNotEmpty ?? false
                      ? grant.workspaceName!
                      : 'Unnamed workspace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sim.text.sm.copyWith(color: c.textBody),
                ),
              ),
            ],
          ),
        ),
        SimChipTag(
          label: '${grant.permission} access',
          variant: SimChipTagVariant.gray,
        ),
      ],
    );
  }
}
