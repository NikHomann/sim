import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';
import 'package:sim_app/data/core/top_insertion_sort_order.dart';
import 'package:sim_workflow/sim_workflow.dart' show generateUuidV4;

/// State of [WorkflowsCubit]: the active workflows of one workspace plus
/// the `markWorkflowCreating/Created` handshake of the sidebar.
class WorkflowsState extends Equatable {
  const WorkflowsState({
    this.workspaceId,
    this.workflows = const LoadState(),
    this.creatingWorkflowId,
    this.createdWorkflowId,
  });

  final String? workspaceId;
  final LoadState<List<WorkflowListItem>> workflows;

  /// The client-generated id the sidebar navigated to before the response.
  final String? creatingWorkflowId;

  /// The id whose creation completed (`markWorkflowCreated(id)`), `null`
  /// after a failure.
  final String? createdWorkflowId;

  List<WorkflowListItem> get items => workflows.data ?? const [];

  /// `useWorkflowMap`.
  Map<String, WorkflowListItem> get byId => {for (final w in items) w.id: w};

  /// The sidebar's view (`use-workflow-operations.ts:18-24`): this
  /// workspace's rows, newest first.
  List<WorkflowListItem> get forSidebar {
    final rows = items.where((w) => w.workspaceId == workspaceId).toList()
      ..sort((a, b) {
        final left = a.createdAtDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAtDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    return rows;
  }

  bool get isLoading => workflows.isLoading;
  Object? get error => workflows.error;

  WorkflowsState copyWith({
    String? workspaceId,
    LoadState<List<WorkflowListItem>>? workflows,
    String? creatingWorkflowId,
    bool clearCreating = false,
    String? createdWorkflowId,
    bool clearCreated = false,
  }) => WorkflowsState(
    workspaceId: workspaceId ?? this.workspaceId,
    workflows: workflows ?? this.workflows,
    creatingWorkflowId: clearCreating
        ? null
        : (creatingWorkflowId ?? this.creatingWorkflowId),
    createdWorkflowId: clearCreated
        ? null
        : (createdWorkflowId ?? this.createdWorkflowId),
  );

  @override
  List<Object?> get props => [
    workspaceId,
    workflows,
    creatingWorkflowId,
    createdWorkflowId,
  ];
}

/// `hooks/queries/workflows.ts` (spec §4.6, §6): `list(ws,'active')`
/// (stale 60 s), the optimistic create / duplicate / update / delete /
/// reorder mutations, restore, and `invalidateWorkflowLists`.
class WorkflowsCubit extends Cubit<WorkflowsState> {
  WorkflowsCubit({
    required WorkflowsRepository workflows,
    required QueryClient queryClient,
    String Function()? idGenerator,
    DateTime Function()? now,
  }) : _workflows = workflows,
       _queryClient = queryClient,
       _generateId = idGenerator ?? generateUuidV4,
       _now = now ?? DateTime.now,
       super(const WorkflowsState());

  final WorkflowsRepository _workflows;
  final QueryClient _queryClient;
  final String Function() _generateId;
  final DateTime Function() _now;
  QueryBinding<List<WorkflowListItem>>? _binding;

  String get _workspaceId {
    final id = state.workspaceId;
    if (id == null) throw StateError('WorkflowsCubit has no workspace');
    return id;
  }

  QueryKey _listKey([String? workspaceId]) =>
      WorkflowKeys.list(workspaceId ?? _workspaceId);

  /// Binds to [workspaceId] and fetches when stale.
  Future<List<WorkflowListItem>?> load(String workspaceId) async {
    if (state.workspaceId != workspaceId || _binding == null) {
      _binding?.dispose();
      final query = _queryClient.query<List<WorkflowListItem>>(
        _listKey(workspaceId),
        (token) =>
            _workflows.list(workspaceId: workspaceId, cancelToken: token),
        staleTime: StaleTimes.workflowList,
      );
      _binding = QueryBinding(query, _onQueryState);
      emit(
        WorkflowsState(
          workspaceId: workspaceId,
          workflows: LoadState.fromQuery(query.state),
        ),
      );
    }
    try {
      return await _binding!.fetch();
    } on Object {
      return null;
    }
  }

  void _sync() => _binding?.sync();

  void _onQueryState(QueryState<List<WorkflowListItem>> queryState) {
    if (isClosed) return;
    emit(state.copyWith(workflows: LoadState.fromQuery(queryState)));
  }

  /// `invalidateWorkflowLists(ws, scopes)` + `selectorKeys.all`.
  Future<void> invalidateLists({
    String? workspaceId,
    List<String> scopes = const ['active'],
  }) async {
    final ws = workspaceId ?? _workspaceId;
    for (final scope in scopes) {
      await _queryClient.invalidateQueries(WorkflowKeys.list(ws, scope));
    }
    await _queryClient.invalidateQueries(SelectorKeys.all);
  }

  List<QueryKey> _listPrefixes({bool archived = false}) => [
    WorkflowKeys.list(_workspaceId),
    if (archived) WorkflowKeys.list(_workspaceId, 'archived'),
    SelectorKeys.all,
  ];

  List<Folder> _cachedFolders() =>
      _queryClient.getQueryData<List<Folder>>(FolderKeys.list(_workspaceId)) ??
      const [];

  List<WorkflowListItem> _cached() =>
      _queryClient.getQueryData<List<WorkflowListItem>>(_listKey()) ?? const [];

  WorkflowListItem _optimisticRow({
    required String id,
    required String name,
    required String? description,
    required String? folderId,
    required num sortOrder,
  }) {
    final now = _now().toIso8601String();
    return WorkflowListItem(
      id: id,
      name: name,
      description: description ?? '',
      workspaceId: _workspaceId,
      folderId: folderId,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
      archivedAt: null,
      locked: false,
    );
  }

  void _replace(String tempId, WorkflowListItem row) {
    final current = _queryClient.getQueryData<List<WorkflowListItem>>(
      _listKey(),
    );
    if (current == null) return;
    _queryClient.setQueryData<List<WorkflowListItem>>(_listKey(), [
      for (final w in current)
        if (w.id == tempId) row else if (w.id != row.id) w,
    ]);
  }

  /// `markWorkflowCreating(id)`: the sidebar navigates to the new id before
  /// the response.
  void markWorkflowCreating(String? id) =>
      emit(state.copyWith(creatingWorkflowId: id, clearCreating: id == null));

  /// `markWorkflowCreated(id)` (`null` after a failed create).
  void markWorkflowCreated(String? id) =>
      emit(state.copyWith(createdWorkflowId: id, clearCreated: id == null));

  /// `useCreateWorkflow`: temp row with the client id (or a fresh UUID) and
  /// the top-insertion sort order; `markWorkflowCreated(id)` on success and
  /// the server row replaces the temp one; snapshot + `markWorkflowCreated(null)`
  /// on error; active + archived lists invalidated once settled. The name
  /// comes from the caller (`generateCreativeWorkflowName()` lives in the
  /// sidebar feature).
  Future<CreatedWorkflow> create({
    required String name,
    String? id,
    String? description,
    String? folderId,
    int? sortOrder,
    bool deduplicate = true,
  }) {
    final workspaceId = _workspaceId;
    final tempId = id ?? _generateId();
    final order =
        sortOrder ??
        getTopInsertionSortOrder(
          workflows: _cached(),
          folders: _cachedFolders(),
          workspaceId: workspaceId,
          parentId: folderId,
        );
    return optimisticMutation<List<WorkflowListItem>, CreatedWorkflow>(
      _queryClient,
      key: _listKey(),
      update: (previous) => [
        ...?previous,
        _optimisticRow(
          id: tempId,
          name: name,
          description: description,
          folderId: folderId,
          sortOrder: order,
        ),
      ],
      mutation: () => _workflows.create(
        id: tempId,
        name: name,
        description: description,
        workspaceId: workspaceId,
        folderId: folderId,
        sendFolder: true,
        // Only a caller-chosen order goes to the server; otherwise it
        // computes the top insertion itself (`useCreateWorkflow`).
        sortOrder: sortOrder,
        deduplicate: deduplicate,
      ),
      onSuccess: (created) {
        _replace(tempId, created.toListItem());
        markWorkflowCreated(created.id);
      },
      onError: (snapshot) {
        if (snapshot != null) {
          _queryClient.setQueryData<List<WorkflowListItem>>(
            _listKey(),
            snapshot,
          );
        } else {
          _queryClient.removeQueries(_listKey());
        }
        markWorkflowCreated(null);
      },
      onApplied: _sync,
      invalidate: _listPrefixes(archived: true),
    );
  }

  /// `useDuplicateWorkflowMutation`: optimistic insert at the top of the
  /// target folder with `id = newId ?? generateId()`; replaced on success,
  /// rolled back on error; active list invalidated once settled.
  Future<DuplicatedWorkflow> duplicate(
    String sourceId, {
    required String name,
    String? description,
    String? folderId,
    bool sendFolder = false,
    String? newId,
  }) {
    final workspaceId = _workspaceId;
    final tempId = newId ?? _generateId();
    final order = getTopInsertionSortOrder(
      workflows: _cached(),
      folders: _cachedFolders(),
      workspaceId: workspaceId,
      parentId: folderId,
    );
    return optimisticMutation<List<WorkflowListItem>, DuplicatedWorkflow>(
      _queryClient,
      key: _listKey(),
      update: (previous) => [
        ...?previous,
        _optimisticRow(
          id: tempId,
          name: name,
          description: description,
          folderId: folderId,
          sortOrder: order,
        ),
      ],
      mutation: () => _workflows.duplicate(
        sourceId,
        name: name,
        description: description,
        workspaceId: workspaceId,
        folderId: folderId,
        sendFolder: sendFolder || folderId != null,
        newId: tempId,
      ),
      onSuccess: (created) => _replace(tempId, created.toListItem(_now())),
      onApplied: _sync,
      invalidate: _listPrefixes(),
    );
  }

  /// `useUpdateWorkflow` (rename, move, lock): optimistic merge of the
  /// metadata + `updatedAt: now` into the row; rollback; active list
  /// invalidated once settled.
  Future<WorkflowListItem> update(String id, WorkflowUpdate update) =>
      optimisticMutation<List<WorkflowListItem>, WorkflowListItem>(
        _queryClient,
        key: _listKey(),
        update: (previous) => [
          for (final w in previous ?? const <WorkflowListItem>[])
            if (w.id == id)
              w.copyWith(
                name: update.name,
                description: update.description,
                folderId: update.movesFolder ? update.folderId : null,
                clearFolder: update.clearFolder,
                sortOrder: update.sortOrder,
                locked: update.locked,
                forkSyncExcluded: update.forkSyncExcluded,
                updatedAt: _now().toIso8601String(),
              )
            else
              w,
        ],
        mutation: () => _workflows.update(id, update: update),
        onSuccess: (row) => _replace(id, row),
        onApplied: _sync,
        invalidate: _listPrefixes(),
      );

  /// `useDeleteWorkflowMutation`: optimistic removal, rollback, active +
  /// archived lists invalidated once settled.
  Future<void> delete(String id) =>
      optimisticMutation<List<WorkflowListItem>, void>(
        _queryClient,
        key: _listKey(),
        update: (previous) => [
          for (final w in previous ?? const <WorkflowListItem>[])
            if (w.id != id) w,
        ],
        mutation: () => _workflows.delete(id),
        onApplied: _sync,
        invalidate: _listPrefixes(archived: true),
      );

  /// `useReorderWorkflows`: optimistic `sortOrder`/`folderId` per row,
  /// rollback, active list invalidated once settled.
  Future<ReorderResult> reorder(List<WorkflowReorderUpdate> updates) {
    final byId = {for (final u in updates) u.id: u};
    return optimisticMutation<List<WorkflowListItem>, ReorderResult>(
      _queryClient,
      key: _listKey(),
      update: (previous) => [
        for (final w in previous ?? const <WorkflowListItem>[])
          if (byId[w.id] case final u?)
            w.copyWith(
              sortOrder: u.sortOrder,
              folderId: u.movesFolder ? u.folderId : null,
              clearFolder: u.clearFolder,
            )
          else
            w,
      ],
      mutation: () =>
          _workflows.reorder(workspaceId: _workspaceId, updates: updates),
      onApplied: _sync,
      invalidate: _listPrefixes(),
    );
  }

  /// `useRestoreWorkflow`: recently-deleted lists + active and archived
  /// lists invalidated once settled.
  Future<void> restore(String id) => settledMutation(
    _queryClient,
    mutation: () => _workflows.restore(id),
    invalidate: [RecentlyDeletedKeys.lists(), ..._listPrefixes(archived: true)],
  );

  /// `workspace-workflows-changed`: workflow lists (active + archived) and
  /// workflow folders (active + archived) of [workspaceId].
  Future<void> onWorkspaceWorkflowsChanged(String workspaceId) async {
    await invalidateLists(
      workspaceId: workspaceId,
      scopes: const ['active', 'archived'],
    );
    await _queryClient.invalidateQueries(FolderKeys.list(workspaceId));
    await _queryClient.invalidateQueries(
      FolderKeys.list(workspaceId, 'archived'),
    );
  }

  void clear() {
    _binding?.dispose();
    _binding = null;
    if (!isClosed) emit(const WorkflowsState());
  }

  void reset() {
    clear();
    _queryClient.removeQueries(WorkflowKeys.all);
  }

  @override
  Future<void> close() {
    _binding?.dispose();
    return super.close();
  }
}
