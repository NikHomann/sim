import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';

/// State of [InvitationsCubit]: the viewer's pending invitations (switcher
/// menu, view-invitations modal) and the per-workspace pending rows
/// (teammates settings).
class InvitationsState extends Equatable {
  const InvitationsState({
    this.mine = const LoadState(),
    this.workspace = const {},
  });

  final LoadState<List<InvitationDetails>> mine;
  final Map<String, LoadState<List<PendingWorkspaceInvitation>>> workspace;

  List<InvitationDetails> get pending => mine.data ?? const [];

  /// The switcher renders the "View invitations" item only when non-empty.
  bool get hasPending => pending.isNotEmpty;

  List<PendingWorkspaceInvitation> forWorkspace(String workspaceId) =>
      workspace[workspaceId]?.data ?? const [];

  InvitationsState copyWith({
    LoadState<List<InvitationDetails>>? mine,
    Map<String, LoadState<List<PendingWorkspaceInvitation>>>? workspace,
  }) => InvitationsState(
    mine: mine ?? this.mine,
    workspace: workspace ?? this.workspace,
  );

  @override
  List<Object?> get props => [mine, workspace];
}

/// `hooks/queries/invitations.ts` (spec §4.4, §6): `mine()` on dropdown /
/// modal open (stale 30 s), accept / decline with their invalidation sets,
/// batch send, the per-workspace pending list, cancel, resend, remove
/// member and permission updates.
class InvitationsCubit extends Cubit<InvitationsState> {
  InvitationsCubit({
    required InvitationsRepository invitations,
    required WorkspacesRepository workspaces,
    required QueryClient queryClient,
    Future<void> Function()? refreshSession,
  }) : _invitations = invitations,
       _workspaces = workspaces,
       _queryClient = queryClient,
       _refreshSession = refreshSession,
       super(const InvitationsState());

  final InvitationsRepository _invitations;
  final WorkspacesRepository _workspaces;
  final QueryClient _queryClient;

  /// `refreshSessionQuery` (the session cubit's refresh).
  final Future<void> Function()? _refreshSession;
  QueryBinding<List<InvitationDetails>>? _mine;
  final Map<String, QueryBinding<List<PendingWorkspaceInvitation>>>
  _byWorkspace = {};

  /// `useMyPendingInvitations(enabled)`: bound when the dropdown opens.
  Future<List<InvitationDetails>?> loadMine() async {
    _mine ??= QueryBinding(
      _queryClient.query<List<InvitationDetails>>(
        InvitationKeys.mine(),
        (token) => _invitations.listMine(cancelToken: token),
        staleTime: StaleTimes.myInvitations,
      ),
      (s) {
        if (!isClosed) emit(state.copyWith(mine: LoadState.fromQuery(s)));
      },
    );
    emit(state.copyWith(mine: LoadState.fromQuery(_mine!.query.state)));
    try {
      return await _mine!.fetch();
    } on Object {
      return null;
    }
  }

  /// `useInvitationDetails(id, token, viewerId)`: viewer-scoped key, stale
  /// 30 s, no retry. Throws [InvitationError].
  Future<InvitationDetailsResponse> details(
    String invitationId, {
    required String? token,
    required String? viewerId,
  }) => _queryClient.fetchQuery<InvitationDetailsResponse>(
    InvitationKeys.detail(invitationId, token, viewerId),
    (cancel) => _invitations.details(
      invitationId,
      token: token,
      cancelToken: cancel,
    ),
    staleTime: StaleTimes.invitationDetails,
  );

  /// `useAcceptMyInvitation` / the invite page accept: on success
  /// `workspaceKeys.lists()`, `organizationKeys.all`,
  /// `workspaceCredentialKeys.all`, `subscriptionKeys.all` and a session
  /// refresh; `invitationKeys.mine()` once settled. Throws [InvitationError].
  Future<AcceptedInvitation> accept(
    String invitationId, {
    String? token,
    List<String>? disclosedWorkspaceIds,
    JoinOutcome? disclosedOutcome,
  }) => settledMutation(
    _queryClient,
    mutation: () async {
      final accepted = await _invitations.accept(
        invitationId,
        token: token,
        disclosedWorkspaceIds: disclosedWorkspaceIds,
        disclosedOutcome: disclosedOutcome,
      );
      try {
        await _refreshSession?.call();
      } on Object {
        // Best effort, like `invite.tsx:372-385`.
      }
      return accepted;
    },
    invalidateOnSuccess: [
      WorkspaceKeys.lists(),
      OrganizationKeys.all,
      WorkspaceCredentialKeys.all,
      SubscriptionKeys.all,
    ],
    invalidate: [InvitationKeys.mine()],
  );

  /// `useDeclineMyInvitation`: `mine()` once settled.
  Future<void> decline(String invitationId, {String? token}) => settledMutation(
    _queryClient,
    mutation: () => _invitations.reject(invitationId, token: token),
    invalidate: [InvitationKeys.mine()],
  );

  /// `usePendingInvitations(workspaceId)` (`retryOnMount: true`).
  Future<List<PendingWorkspaceInvitation>?> loadWorkspace(
    String workspaceId,
  ) async {
    final binding = _byWorkspace.putIfAbsent(
      workspaceId,
      () => QueryBinding(
        _queryClient.query<List<PendingWorkspaceInvitation>>(
          InvitationKeys.list(workspaceId),
          (token) =>
              _invitations.listWorkspace(workspaceId, cancelToken: token),
          staleTime: StaleTimes.workspaceInvitationList,
        ),
        (s) {
          if (isClosed) return;
          emit(
            state.copyWith(
              workspace: {
                ...state.workspace,
                workspaceId: LoadState.fromQuery(s),
              },
            ),
          );
        },
      ),
    );
    emit(
      state.copyWith(
        workspace: {
          ...state.workspace,
          workspaceId: LoadState.fromQuery(binding.query.state),
        },
      ),
    );
    try {
      return await binding.fetch();
    } on Object {
      return null;
    }
  }

  /// `useSendWorkspaceInvitations`: per workspace `list(ws)`,
  /// `permissions(ws)`, `members(ws)`; with an organization its roster,
  /// billing and detail — all once settled. A 2xx with `failed[]` is
  /// returned, not thrown.
  Future<BatchInvitationResult> sendBatch({
    required List<String> workspaceIds,
    required List<String> emails,
    WorkspacePermission? permission,
    InvitationMembership? membership,
    String? organizationId,
  }) => settledMutation(
    _queryClient,
    mutation: () => _invitations.sendBatch(
      workspaceIds: workspaceIds,
      emails: emails,
      permission: permission,
      membership: membership,
      organizationId: organizationId,
    ),
    invalidate: [
      for (final ws in workspaceIds) ...[
        InvitationKeys.list(ws),
        WorkspaceKeys.permissions(ws),
        WorkspaceKeys.members(ws),
      ],
      if (organizationId != null) ...[
        OrganizationKeys.roster(organizationId),
        OrganizationKeys.billing(organizationId),
        OrganizationKeys.detail(organizationId),
      ],
    ],
  );

  /// `useCancelWorkspaceInvitation`: `list(ws)` + org roster/billing.
  Future<CancelInvitationResult> cancel(
    String invitationId, {
    required String workspaceId,
    String? organizationId,
  }) => settledMutation(
    _queryClient,
    mutation: () => _invitations.cancel(invitationId, workspaceId: workspaceId),
    invalidate: [
      InvitationKeys.list(workspaceId),
      if (organizationId != null) ...[
        OrganizationKeys.roster(organizationId),
        OrganizationKeys.billing(organizationId),
      ],
    ],
  );

  /// `useResendWorkspaceInvitation`: `list(ws)`.
  Future<bool> resend(String invitationId, {required String workspaceId}) =>
      settledMutation(
        _queryClient,
        mutation: () => _invitations.resend(invitationId),
        invalidate: [InvitationKeys.list(workspaceId)],
      );

  /// `useRemoveWorkspaceMember`: `permissions(ws)`, `members(ws)`,
  /// `workspaceCredentialKeys.all`, org roster.
  Future<bool> removeMember({
    required String workspaceId,
    required String userId,
    String? organizationId,
  }) => settledMutation(
    _queryClient,
    mutation: () =>
        _invitations.removeMember(userId: userId, workspaceId: workspaceId),
    invalidate: [
      WorkspaceKeys.permissions(workspaceId),
      WorkspaceKeys.members(workspaceId),
      WorkspaceCredentialKeys.all,
      if (organizationId != null) OrganizationKeys.roster(organizationId),
    ],
  );

  /// `useUpdateWorkspacePermissions`: `permissions(ws)`, org roster. The
  /// `ApiClientError` carries the first validation issue for the toast.
  Future<String> updatePermissions({
    required String workspaceId,
    required List<PermissionUpdate> updates,
    String? organizationId,
  }) => settledMutation(
    _queryClient,
    mutation: () =>
        _workspaces.updatePermissions(workspaceId, updates: updates),
    invalidate: [
      WorkspaceKeys.permissions(workspaceId),
      if (organizationId != null) OrganizationKeys.roster(organizationId),
    ],
  );

  void reset() {
    _mine?.dispose();
    _mine = null;
    for (final binding in _byWorkspace.values) {
      binding.dispose();
    }
    _byWorkspace.clear();
    _queryClient.removeQueries(InvitationKeys.all);
    if (!isClosed) emit(const InvitationsState());
  }

  @override
  Future<void> close() {
    _mine?.dispose();
    for (final binding in _byWorkspace.values) {
      binding.dispose();
    }
    return super.close();
  }
}
