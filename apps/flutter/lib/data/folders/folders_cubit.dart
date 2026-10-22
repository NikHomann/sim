import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';
import 'package:sim_app/data/core/top_insertion_sort_order.dart';
import 'package:sim_workflow/sim_workflow.dart' show generateUuidV4;

/// State of [FoldersCubit]: the workflow folders of one workspace.
class FoldersState extends Equatable {
  const FoldersState({this.workspaceId, this.folders = const LoadState()});

  final String? workspaceId;
  final LoadState<List<Folder>> folders;

  List<Folder> get items => folders.data ?? const [];

  /// `useFolderMap`.
  Map<String, Folder> get byId => {for (final f in items) f.id: f};

  bool get isLoading => folders.isLoading;
  Object? get error => folders.error;

  FoldersState copyWith({
    String? workspaceId,
    LoadState<List<Folder>>? folders,
  }) => FoldersState(
    workspaceId: workspaceId ?? this.workspaceId,
    folders: folders ?? this.folders,
  );

  @override
  List<Object?> get props => [workspaceId, folders];
}

/// `hooks/queries/folders.ts` for workflow folders (spec §4.5, §6):
/// `list(ws,'active','workflow')` (stale 60 s) and the create / update /
/// delete / restore / duplicate / reorder mutations with their optimistic
/// rows and invalidation prefixes.
class FoldersCubit extends Cubit<FoldersState> {
  FoldersCubit({
    required FoldersRepository folders,
    required QueryClient queryClient,
    String Function()? idGenerator,
    DateTime Function()? now,
  }) : _folders = folders,
       _queryClient = queryClient,
       _generateId = idGenerator ?? generateUuidV4,
       _now = now ?? DateTime.now,
       super(const FoldersState());

  final FoldersRepository _folders;
  final QueryClient _queryClient;
  final String Function() _generateId;
  final DateTime Function() _now;
  QueryBinding<List<Folder>>? _binding;

  static const FolderResourceType _type = FolderResourceType.workflow;

  String get _workspaceId {
    final id = state.workspaceId;
    if (id == null) throw StateError('FoldersCubit has no workspace');
    return id;
  }

  QueryKey _listKey([String? workspaceId]) =>
      FolderKeys.list(workspaceId ?? _workspaceId);

  /// Binds to [workspaceId] and fetches when stale.
  Future<List<Folder>?> load(String workspaceId) async {
    if (state.workspaceId != workspaceId || _binding == null) {
      _binding?.dispose();
      final query = _queryClient.query<List<Folder>>(
        _listKey(workspaceId),
        (token) => _folders.list(workspaceId: workspaceId, cancelToken: token),
        staleTime: StaleTimes.folderList,
      );
      _binding = QueryBinding(query, _onQueryState);
      emit(
        FoldersState(
          workspaceId: workspaceId,
          folders: LoadState.fromQuery(query.state),
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

  void _onQueryState(QueryState<List<Folder>> queryState) {
    if (isClosed) return;
    emit(state.copyWith(folders: LoadState.fromQuery(queryState)));
  }

  List<WorkflowListItem> _cachedWorkflows() =>
      _queryClient.getQueryData<List<WorkflowListItem>>(
        WorkflowKeys.list(_workspaceId),
      ) ??
      const [];

  Folder _optimisticFolder({
    required String id,
    required String name,
    required String? parentId,
    required num sortOrder,
  }) {
    final now = _now().toIso8601String();
    return Folder(
      id: id,
      resourceType: _type,
      name: name,
      userId: '',
      workspaceId: _workspaceId,
      parentId: parentId,
      locked: false,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  /// `useCreateFolder`: temp row with `getTopInsertionSortOrder`, replaced
  /// by the server row on success, snapshot restored on error, the list
  /// invalidated once settled. Without [name] the "Folder N" rule runs on
  /// the cached list (`generateFolderName` fetches it upstream; the cache
  /// holds the same rows).
  Future<Folder> create({
    String? name,
    String? parentId,
    String? id,
    int? sortOrder,
  }) {
    final workspaceId = _workspaceId;
    final tempId = id ?? _generateId();
    final current = _queryClient.getQueryData<List<Folder>>(_listKey()) ?? [];
    final folderName = name ?? FoldersRepository.nextFolderName(current);
    final order =
        sortOrder ??
        getTopInsertionSortOrder(
          workflows: _cachedWorkflows(),
          folders: current,
          workspaceId: workspaceId,
          parentId: parentId,
        );
    return optimisticMutation<List<Folder>, Folder>(
      _queryClient,
      key: _listKey(),
      update: (previous) => [
        ...?previous,
        _optimisticFolder(
          id: tempId,
          name: folderName,
          parentId: parentId,
          sortOrder: order,
        ),
      ],
      mutation: () => _folders.create(
        id: tempId,
        name: folderName,
        workspaceId: workspaceId,
        parentId: parentId,
        // Only a caller-chosen order goes to the server; otherwise it
        // computes the top insertion itself (`useCreateFolder`).
        sortOrder: sortOrder,
      ),
      onSuccess: (created) => _replace(tempId, created),
      onApplied: _sync,
      invalidate: [_listKey()],
    );
  }

  void _replace(String tempId, Folder created) {
    final current = _queryClient.getQueryData<List<Folder>>(_listKey());
    if (current == null) return;
    _queryClient.setQueryData<List<Folder>>(_listKey(), [
      for (final f in current)
        if (f.id == tempId) created else if (f.id != created.id) f,
    ]);
  }

  /// `useUpdateFolder`: not optimistic; `resource('workflow')` (every
  /// workspace's workflow-folder lists) invalidated once settled.
  Future<Folder> update(String id, FolderUpdate update) => settledMutation(
    _queryClient,
    mutation: () => _folders.update(id, update: update),
    invalidate: [FolderKeys.resource()],
  );

  /// `useDeleteFolderMutation`: `resource('workflow')` + cascaded workflow
  /// lists (active + archived) + selectors once settled.
  Future<FolderCascadeResult> delete(String id) => settledMutation(
    _queryClient,
    mutation: () => _folders.delete(id),
    invalidate: [
      FolderKeys.resource(),
      ..._workflowListPrefixes(archived: true),
    ],
  );

  /// `useRestoreFolder`: recently-deleted lists + `resource('workflow')` +
  /// cascaded workflow lists once settled.
  Future<FolderCascadeResult> restore(String id) => settledMutation(
    _queryClient,
    mutation: () => _folders.restore(id, workspaceId: _workspaceId),
    invalidate: [
      RecentlyDeletedKeys.lists(),
      FolderKeys.resource(),
      ..._workflowListPrefixes(archived: true),
    ],
  );

  /// `useDuplicateFolderMutation`: optimistic insert like create (parent =
  /// [parentId] ?? source parent); `list(ws)` prefix + workflow lists once
  /// settled.
  Future<Folder> duplicate(
    String sourceId, {
    required String name,
    String? parentId,
    bool sendParent = false,
    String? newId,
  }) {
    final workspaceId = _workspaceId;
    final current = _queryClient.getQueryData<List<Folder>>(_listKey()) ?? [];
    final source = current.where((f) => f.id == sourceId).firstOrNull;
    final targetParent = sendParent ? parentId : (parentId ?? source?.parentId);
    final tempId = newId ?? _generateId();
    final order = getTopInsertionSortOrder(
      workflows: _cachedWorkflows(),
      folders: current,
      workspaceId: workspaceId,
      parentId: targetParent,
    );
    return optimisticMutation<List<Folder>, Folder>(
      _queryClient,
      key: _listKey(),
      update: (previous) => [
        ...?previous,
        _optimisticFolder(
          id: tempId,
          name: name,
          parentId: targetParent,
          sortOrder: order,
        ),
      ],
      mutation: () => _folders.duplicate(
        sourceId,
        name: name,
        workspaceId: workspaceId,
        parentId: targetParent,
        sendParent: sendParent || targetParent != null,
        newId: tempId,
      ),
      onSuccess: (created) => _replace(tempId, created),
      onApplied: _sync,
      invalidate: [
        [...FolderKeys.resource(), workspaceId],
        ..._workflowListPrefixes(),
      ],
    );
  }

  /// `useReorderFolders`: `sortOrder`/`parentId` applied to the matching
  /// rows, snapshot rollback, `list(ws,'active','workflow')` once settled.
  Future<ReorderResult> reorder(List<FolderReorderUpdate> updates) {
    final byId = {for (final u in updates) u.id: u};
    return optimisticMutation<List<Folder>, ReorderResult>(
      _queryClient,
      key: _listKey(),
      update: (previous) => [
        for (final f in previous ?? const <Folder>[])
          if (byId[f.id] case final u?)
            f.copyWith(
              sortOrder: u.sortOrder,
              parentId: u.movesParent ? u.parentId : null,
              clearParent: u.clearParent,
            )
          else
            f,
      ],
      mutation: () =>
          _folders.reorder(workspaceId: _workspaceId, updates: updates),
      onApplied: _sync,
      invalidate: [_listKey()],
    );
  }

  List<QueryKey> _workflowListPrefixes({bool archived = false}) => [
    WorkflowKeys.list(_workspaceId),
    if (archived) WorkflowKeys.list(_workspaceId, 'archived'),
    SelectorKeys.all,
  ];

  void clear() {
    _binding?.dispose();
    _binding = null;
    if (!isClosed) emit(const FoldersState());
  }

  void reset() {
    clear();
    _queryClient.removeQueries(FolderKeys.all);
  }

  @override
  Future<void> close() {
    _binding?.dispose();
    return super.close();
  }
}
