import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';

/// `AdminWorkspace` of `useAdminWorkspaces` (`workspace.ts:482-510`).
class AdminWorkspace extends Equatable {
  const AdminWorkspace({
    required this.id,
    required this.name,
    required this.isOwner,
    required this.ownerId,
    required this.canInvite,
    required this.organizationId,
    required this.workspaceMode,
  });

  final String id;
  final String name;
  final bool isOwner;
  final String ownerId;
  final bool canInvite;
  final String? organizationId;
  final WorkspaceMode workspaceMode;

  @override
  List<Object?> get props => [
    id,
    name,
    isOwner,
    ownerId,
    canInvite,
    organizationId,
    workspaceMode,
  ];
}

/// State of [WorkspacesCubit]: the active-scope list with its metadata.
class WorkspacesState extends Equatable {
  const WorkspacesState({
    this.list = const LoadState(),
    this.activeWorkspaceId,
  });

  final LoadState<WorkspaceList> list;

  /// The workspace the shell is in (set by the router through
  /// [WorkspacesCubit.setActiveWorkspace]).
  final String? activeWorkspaceId;

  List<Workspace> get workspaces => list.data?.workspaces ?? const [];
  Set<String> get pinnedIds =>
      (list.data?.pinnedWorkspaceIds ?? const []).toSet();
  WorkspaceCreationPolicy? get creationPolicy => list.data?.creationPolicy;
  String? get lastActiveWorkspaceId => list.data?.lastActiveWorkspaceId;

  /// `useOrderedWorkspacesQuery`: pinned first, server order otherwise.
  List<Workspace> get ordered {
    final pinned = pinnedIds;
    return [
      for (final w in workspaces)
        if (pinned.contains(w.id)) w,
      for (final w in workspaces)
        if (!pinned.contains(w.id)) w,
    ];
  }

  Workspace? get active {
    final id = activeWorkspaceId;
    if (id == null) return null;
    for (final w in workspaces) {
      if (w.id == id) return w;
    }
    return null;
  }

  Workspace? byId(String id) {
    for (final w in workspaces) {
      if (w.id == id) return w;
    }
    return null;
  }

  bool get isLoading => list.isLoading;
  Object? get error => list.error;

  /// A 401 on the list after a live session: stale auth cookies
  /// (`workspace/page.tsx:35-37`).
  bool get isStaleSession => list.isUnauthorized;

  /// The picker's blocked card: no workspace and creation refused.
  bool get isCreationBlocked =>
      list.hasData &&
      workspaces.isEmpty &&
      creationPolicy != null &&
      !creationPolicy!.canCreate;

  WorkspacesState copyWith({
    LoadState<WorkspaceList>? list,
    String? activeWorkspaceId,
    bool clearActive = false,
  }) => WorkspacesState(
    list: list ?? this.list,
    activeWorkspaceId: clearActive
        ? null
        : (activeWorkspaceId ?? this.activeWorkspaceId),
  );

  @override
  List<Object?> get props => [list, activeWorkspaceId];
}

/// `hooks/queries/workspace.ts` + `WorkspaceScopeSync` (spec §4.3, §6, §7):
/// the `list('active')` query (stale 30 s), the switcher ordering, pins,
/// creation policy, the serialised visit and pin-toggle mutations, and
/// create/update/delete/leave.
class WorkspacesCubit extends Cubit<WorkspacesState> {
  WorkspacesCubit({
    required WorkspacesRepository workspaces,
    required PinnedItemsRepository pinnedItems,
    required InvitationsRepository invitations,
    required QueryClient queryClient,
  }) : _workspaces = workspaces,
       _pinnedItems = pinnedItems,
       _invitations = invitations,
       _queryClient = queryClient,
       super(const WorkspacesState());

  final WorkspacesRepository _workspaces;
  final PinnedItemsRepository _pinnedItems;
  final InvitationsRepository _invitations;
  final QueryClient _queryClient;
  QueryBinding<WorkspaceList>? _binding;

  /// `scope: {id: 'workspace-visit'}`.
  final MutationScope _visitScope = MutationScope();

  /// `scope: {id: 'workspace-pin'}`.
  final MutationScope _pinScope = MutationScope();

  QueryKey get _listKey => WorkspaceKeys.list();

  Query<WorkspaceList> _query() {
    final existing = _binding;
    if (existing != null) return existing.query;
    final query = _queryClient.query<WorkspaceList>(
      _listKey,
      (token) => _workspaces.list(cancelToken: token),
      staleTime: StaleTimes.workspaceList,
    );
    _binding = QueryBinding(query, _onQueryState);
    _onQueryState(query.state);
    return query;
  }

  void _onQueryState(QueryState<WorkspaceList> queryState) {
    if (isClosed) return;
    emit(state.copyWith(list: LoadState.fromQuery(queryState)));
  }

  /// `useWorkspacesWithMetadata(enabled)`: call once signed in.
  Future<WorkspaceList?> load() async {
    try {
      _query();
      return await _binding!.fetch();
    } on Object {
      return null;
    }
  }

  Future<void> refetch() async {
    try {
      _query();
      await _binding!.refetch();
    } on Object {
      // Surfaced on the state.
    }
  }

  /// `useWorkspaceManagement`: every `workspaceId` change while signed in
  /// records a visit.
  void setActiveWorkspace(String? workspaceId) {
    if (workspaceId == state.activeWorkspaceId) return;
    emit(
      state.copyWith(
        activeWorkspaceId: workspaceId,
        clearActive: workspaceId == null,
      ),
    );
    if (workspaceId != null) unawaited(recordVisit(workspaceId));
  }

  /// `useRecordWorkspaceVisit`: optimistic move-to-front +
  /// `lastActiveWorkspaceId`, serialised, no rollback; `lists()` is
  /// invalidated only by the last queued visit.
  Future<void> recordVisit(String workspaceId) {
    _query();
    _queryClient.cancelQueries(_listKey);
    final old = _queryClient.getQueryData<WorkspaceList>(_listKey);
    final visited = old?.byId(workspaceId);
    if (old != null && visited != null) {
      _queryClient.setQueryData<WorkspaceList>(
        _listKey,
        old.copyWith(
          lastActiveWorkspaceId: workspaceId,
          workspaces: [
            visited,
            ...old.workspaces.where((w) => !identical(w, visited)),
          ],
        ),
      );
    }
    _binding?.sync();
    return _visitScope
        .run(
          () => _workspaces.recordVisit(workspaceId),
          onSettled: ({required isLast}) async {
            if (isLast) {
              await _queryClient.invalidateQueries(WorkspaceKeys.lists());
            }
          },
        )
        .catchError((Object _) {});
  }

  static List<String> _applyPinToggle(
    List<String> pinnedWorkspaceIds,
    String workspaceId, {
    required bool pinned,
  }) {
    final without = pinnedWorkspaceIds
        .where((id) => id != workspaceId)
        .toList();
    return pinned ? [...without, workspaceId] : without;
  }

  void _setPinned(String workspaceId, {required bool pinned}) {
    final old = _queryClient.getQueryData<WorkspaceList>(_listKey);
    if (old == null) return;
    _queryClient.setQueryData<WorkspaceList>(
      _listKey,
      old.copyWith(
        pinnedWorkspaceIds: _applyPinToggle(
          old.pinnedWorkspaceIds,
          workspaceId,
          pinned: pinned,
        ),
      ),
    );
    _binding?.sync();
  }

  /// `useToggleWorkspacePin`: optimistic toggle, 409/404 are success, the
  /// inverse toggle (not a snapshot) on error, serialised, `lists()`
  /// invalidated by the last queued toggle only. Throws the error after
  /// rolling back so the caller can toast it.
  Future<void> togglePin(String workspaceId, {required bool pinned}) {
    _query();
    _queryClient.cancelQueries(_listKey);
    _setPinned(workspaceId, pinned: pinned);
    return _pinScope.run(
      () async {
        try {
          await _pinnedItems.toggleWorkspacePin(
            workspaceId: workspaceId,
            pinned: pinned,
          );
        } on Object {
          _setPinned(workspaceId, pinned: !pinned);
          rethrow;
        }
      },
      onSettled: ({required isLast}) async {
        if (isLast) await _queryClient.invalidateQueries(WorkspaceKeys.lists());
      },
    );
  }

  /// `useCreateWorkspace`: prepends the row (creating the cache entry when
  /// empty) then invalidates `lists()` and `adminLists()`. Throws the
  /// `ApiClientError` (403 capability refusal, 409 membership race).
  Future<Workspace> create({
    required String name,
    bool? skipDefaultWorkflow,
  }) async {
    final created = await _workspaces.create(
      name: name,
      skipDefaultWorkflow: skipDefaultWorkflow,
    );
    final old = _queryClient.getQueryData<WorkspaceList>(_listKey);
    _queryClient.setQueryData<WorkspaceList>(
      _listKey,
      old == null
          ? WorkspaceList(workspaces: [created], lastActiveWorkspaceId: null)
          : old.copyWith(workspaces: [created, ...old.workspaces]),
    );
    _binding?.sync();
    await _queryClient.invalidateQueries(WorkspaceKeys.lists());
    await _queryClient.invalidateQueries(WorkspaceKeys.adminLists());
    return created;
  }

  /// `useUpdateWorkspace` through `updateWorkspace` of
  /// `use-workspace-management.ts:115-130`: not optimistic, errors are
  /// swallowed and reported as `false`; `lists()` + `detail(id)` invalidated
  /// once settled.
  Future<bool> update(
    String id, {
    String? name,
    String? logoUrl,
    bool clearLogo = false,
  }) async {
    try {
      await settledMutation(
        _queryClient,
        mutation: () => _workspaces.update(
          id,
          name: name,
          logoUrl: logoUrl,
          clearLogo: clearLogo,
        ),
        invalidate: [WorkspaceKeys.lists(), WorkspaceKeys.detail(id)],
      );
      return true;
    } on Object {
      return false;
    }
  }

  /// `useDeleteWorkspace`: `lists()` + `detail(id)` invalidated once
  /// settled; the error is rethrown for the modal.
  Future<void> delete(String id) => settledMutation(
    _queryClient,
    mutation: () => _workspaces.delete(id),
    invalidate: [WorkspaceKeys.lists(), WorkspaceKeys.detail(id)],
  );

  /// `useLeaveWorkspace`: `DELETE /api/workspaces/members/[selfId]`;
  /// `permissions(ws)`, `lists()`, `detail(ws)` invalidated once settled.
  Future<void> leave({required String workspaceId, required String userId}) =>
      settledMutation(
        _queryClient,
        mutation: () =>
            _invitations.removeMember(userId: userId, workspaceId: workspaceId),
        invalidate: [
          WorkspaceKeys.permissions(workspaceId),
          WorkspaceKeys.lists(),
          WorkspaceKeys.detail(workspaceId),
        ],
      );

  /// `useAdminWorkspaces(userId, organizationId?)`: `GET /api/workspaces`
  /// (default scope) filtered client-side to admin rows, stale 60 s.
  Future<List<AdminWorkspace>> adminWorkspaces(
    String userId, {
    String? organizationId,
  }) async {
    final list = await _queryClient.fetchQuery<WorkspaceList>(
      WorkspaceKeys.adminList(userId, organizationId ?? ''),
      (token) => _workspaces.listDefault(cancelToken: token),
      staleTime: StaleTimes.workspaceAdminList,
    );
    return [
      for (final w in list.workspaces)
        if (w.permissions == WorkspacePermission.admin &&
            (organizationId == null ||
                (w.organizationId == organizationId &&
                    w.workspaceMode == WorkspaceMode.organization)))
          AdminWorkspace(
            id: w.id,
            name: w.name,
            isOwner: w.ownerId == userId,
            ownerId: w.ownerId,
            canInvite: w.inviteMembersEnabled,
            organizationId: w.organizationId,
            workspaceMode: w.workspaceMode,
          ),
    ];
  }

  void reset() {
    _binding?.dispose();
    _binding = null;
    _queryClient.removeQueries(WorkspaceKeys.all);
    if (!isClosed) emit(const WorkspacesState());
  }

  @override
  Future<void> close() {
    _binding?.dispose();
    return super.close();
  }
}

extension on WorkspaceList {
  Workspace? byId(String id) {
    for (final w in workspaces) {
      if (w.id == id) return w;
    }
    return null;
  }
}
