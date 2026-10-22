import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';
import 'package:sim_workflow/sim_workflow.dart' show generateUuidV4;

/// State of [PinnedItemsCubit]: the workflow and folder pins of a workspace
/// (`usePinnedIds(ws, 'workflow')` / `'folder'`).
class PinnedItemsState extends Equatable {
  const PinnedItemsState({
    this.workspaceId,
    this.workflows = const LoadState(),
    this.folders = const LoadState(),
  });

  final String? workspaceId;
  final LoadState<List<PinnedItem>> workflows;
  final LoadState<List<PinnedItem>> folders;

  Set<String> get workflowIds =>
      (workflows.data ?? const []).map((p) => p.resourceId).toSet();
  Set<String> get folderIds =>
      (folders.data ?? const []).map((p) => p.resourceId).toSet();

  bool isPinned(PinnedResourceType type, String resourceId) => switch (type) {
    PinnedResourceType.workflow => workflowIds.contains(resourceId),
    PinnedResourceType.folder => folderIds.contains(resourceId),
    _ => false,
  };

  PinnedItemsState copyWith({
    String? workspaceId,
    LoadState<List<PinnedItem>>? workflows,
    LoadState<List<PinnedItem>>? folders,
  }) => PinnedItemsState(
    workspaceId: workspaceId ?? this.workspaceId,
    workflows: workflows ?? this.workflows,
    folders: folders ?? this.folders,
  );

  @override
  List<Object?> get props => [workspaceId, workflows, folders];
}

/// `hooks/queries/pinned-items.ts` (spec §4.7): the typed lists (stale
/// 60 s) and the pin/unpin mutations, which update the type-scoped **and**
/// the unscoped list of the workspace, snapshot each for rollback, and
/// invalidate `workspaceLists(ws)` once settled.
class PinnedItemsCubit extends Cubit<PinnedItemsState> {
  PinnedItemsCubit({
    required PinnedItemsRepository pinnedItems,
    required QueryClient queryClient,
    String Function()? idGenerator,
    DateTime Function()? now,
  }) : _pinnedItems = pinnedItems,
       _queryClient = queryClient,
       _generateId = idGenerator ?? generateUuidV4,
       _now = now ?? DateTime.now,
       super(const PinnedItemsState());

  final PinnedItemsRepository _pinnedItems;
  final QueryClient _queryClient;
  final String Function() _generateId;
  final DateTime Function() _now;
  QueryBinding<List<PinnedItem>>? _workflows;
  QueryBinding<List<PinnedItem>>? _folders;

  String get _workspaceId {
    final id = state.workspaceId;
    if (id == null) throw StateError('PinnedItemsCubit has no workspace');
    return id;
  }

  QueryBinding<List<PinnedItem>> _bind(
    String workspaceId,
    PinnedResourceType type,
    void Function(QueryState<List<PinnedItem>>) onState,
  ) {
    final query = _queryClient.query<List<PinnedItem>>(
      PinnedItemKeys.list(workspaceId, type.wireName),
      (token) => _pinnedItems.list(
        workspaceId: workspaceId,
        resourceType: type,
        cancelToken: token,
      ),
      staleTime: StaleTimes.pinnedItems,
    );
    return QueryBinding(query, onState);
  }

  /// Binds both lists to [workspaceId] and fetches them.
  Future<void> load(String workspaceId) async {
    if (state.workspaceId != workspaceId || _workflows == null) {
      _workflows?.dispose();
      _folders?.dispose();
      _workflows = _bind(workspaceId, PinnedResourceType.workflow, (s) {
        if (!isClosed) emit(state.copyWith(workflows: LoadState.fromQuery(s)));
      });
      _folders = _bind(workspaceId, PinnedResourceType.folder, (s) {
        if (!isClosed) emit(state.copyWith(folders: LoadState.fromQuery(s)));
      });
      emit(
        PinnedItemsState(
          workspaceId: workspaceId,
          workflows: LoadState.fromQuery(_workflows!.query.state),
          folders: LoadState.fromQuery(_folders!.query.state),
        ),
      );
    }
    await Future.wait([
      _workflows!.fetch().catchError((Object _) => <PinnedItem>[]),
      _folders!.fetch().catchError((Object _) => <PinnedItem>[]),
    ]);
  }

  /// The cached lists a pin of [type] touches: the type-scoped one and the
  /// unscoped workspace list (`isAffectedListKey`).
  List<QueryKey> _affectedKeys(PinnedResourceType type) => [
    PinnedItemKeys.list(_workspaceId, type.wireName),
    PinnedItemKeys.list(_workspaceId),
  ];

  Future<R> _optimisticPin<R>({
    required PinnedResourceType type,
    required List<PinnedItem>? Function(List<PinnedItem>? old) update,
    required Future<R> Function() mutation,
  }) async {
    final workspaceId = _workspaceId;
    final keys = _affectedKeys(type);
    _cancel(keys);
    final snapshot = {
      for (final key in keys)
        queryHash(key): (key, _queryClient.getQueryData<List<PinnedItem>>(key)),
    };
    for (final key in keys) {
      final old = _queryClient.getQueryData<List<PinnedItem>>(key);
      if (old == null) continue;
      final next = update(old);
      if (next != null) _queryClient.setQueryData<List<PinnedItem>>(key, next);
    }
    _sync();
    try {
      return await mutation();
    } on Object {
      for (final (key, data) in snapshot.values) {
        if (data != null) {
          _queryClient.setQueryData<List<PinnedItem>>(key, data);
        }
      }
      _sync();
      rethrow;
    } finally {
      await _queryClient.invalidateQueries(
        PinnedItemKeys.workspaceLists(workspaceId),
      );
    }
  }

  void _sync() {
    _workflows?.sync();
    _folders?.sync();
  }

  void _cancel(List<QueryKey> keys) => keys.forEach(_queryClient.cancelQueries);

  /// `usePinItem`.
  Future<PinnedItem> pin(PinnedResourceType type, String resourceId) =>
      _optimisticPin(
        type: type,
        update: (old) {
          if (old == null) return null;
          if (old.any((item) => item.resourceId == resourceId)) return old;
          return [
            ...old,
            PinnedItem(
              id: _generateId(),
              userId: '',
              workspaceId: _workspaceId,
              resourceType: type,
              resourceId: resourceId,
              pinnedAt: _now().toIso8601String(),
            ),
          ];
        },
        mutation: () => _pinnedItems.pin(
          workspaceId: _workspaceId,
          resourceType: type,
          resourceId: resourceId,
        ),
      );

  /// `useUnpinItem`.
  Future<void> unpin(PinnedResourceType type, String resourceId) =>
      _optimisticPin(
        type: type,
        update: (old) =>
            old?.where((item) => item.resourceId != resourceId).toList(),
        mutation: () =>
            _pinnedItems.unpin(resourceType: type, resourceId: resourceId),
      );

  void clear() {
    _workflows?.dispose();
    _folders?.dispose();
    _workflows = null;
    _folders = null;
    if (!isClosed) emit(const PinnedItemsState());
  }

  void reset() {
    clear();
    _queryClient.removeQueries(PinnedItemKeys.all);
  }

  @override
  Future<void> close() {
    _workflows?.dispose();
    _folders?.dispose();
    return super.close();
  }
}
