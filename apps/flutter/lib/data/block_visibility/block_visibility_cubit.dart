import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';

/// State of [BlockVisibilityCubit]: the hydrated projection
/// (`blocks/visibility/client.ts`). `hydrated` is `false` until the first
/// non-empty projection lands (the store's `state === null`).
class BlockVisibilityState extends Equatable {
  const BlockVisibilityState({
    this.workspaceId,
    this.projection = const LoadState(),
    this.visibility = const BlockVisibility(),
    this.hydrated = false,
  });

  final String? workspaceId;
  final LoadState<BlockVisibility> projection;

  /// The overlay the registry reads; fail-closed (empty) until hydrated.
  final BlockVisibility visibility;
  final bool hydrated;

  Set<String> get revealed => visibility.revealed;
  Set<String> get disabled => visibility.disabled;
  Set<String> get previewTagged => visibility.previewTagged;

  BlockVisibilityState copyWith({
    String? workspaceId,
    LoadState<BlockVisibility>? projection,
    BlockVisibility? visibility,
    bool? hydrated,
  }) => BlockVisibilityState(
    workspaceId: workspaceId ?? this.workspaceId,
    projection: projection ?? this.projection,
    visibility: visibility ?? this.visibility,
    hydrated: hydrated ?? this.hydrated,
  );

  @override
  List<Object?> get props => [workspaceId, projection, visibility, hydrated];
}

/// `BlockVisibilityLoader` + `blocks/visibility/client.ts` (spec §4.9, §7):
/// `['block-visibility','list',ws]`, stale 60 s. On a workspace switch,
/// while the new projection is in flight, [resetForSwitch] drops reveals and
/// preview tags but carries the kill-switch (`disabled`) entries over;
/// [hydrate] applies a projection with a deep-equal guard.
class BlockVisibilityCubit extends Cubit<BlockVisibilityState> {
  BlockVisibilityCubit({
    required BlocksRepository blocks,
    required QueryClient queryClient,
  }) : _blocks = blocks,
       _queryClient = queryClient,
       super(const BlockVisibilityState());

  final BlocksRepository _blocks;
  final QueryClient _queryClient;
  QueryBinding<BlockVisibility>? _binding;

  Future<BlockVisibility?> load(String workspaceId) async {
    if (state.workspaceId != workspaceId || _binding == null) {
      _binding?.dispose();
      final query = _queryClient.query<BlockVisibility>(
        BlockVisibilityKeys.list(workspaceId),
        (token) => _blocks.visibility(workspaceId, cancelToken: token),
        staleTime: StaleTimes.blockVisibility,
      );
      _binding = QueryBinding(query, _onQueryState);
      emit(
        state.copyWith(
          workspaceId: workspaceId,
          projection: LoadState.fromQuery(query.state),
        ),
      );
      _apply(query.state.data);
    }
    try {
      return await _binding!.fetch();
    } on Object {
      return null;
    }
  }

  void _onQueryState(QueryState<BlockVisibility> queryState) {
    if (isClosed) return;
    emit(state.copyWith(projection: LoadState.fromQuery(queryState)));
    _apply(queryState.data);
  }

  /// The loader effect: `data == null` → reset for switch, else hydrate.
  void _apply(BlockVisibility? data) {
    if (data == null) {
      resetForSwitch();
    } else {
      hydrate(data);
    }
  }

  /// `hydrateBlockVisibility`: no-op before the first non-empty projection
  /// and for an equal projection.
  void hydrate(BlockVisibility next) {
    final isEmpty =
        next.revealed.isEmpty &&
        next.disabled.isEmpty &&
        next.previewTagged.isEmpty;
    if (!state.hydrated && isEmpty) return;
    if (state.hydrated && state.visibility == next) return;
    emit(state.copyWith(visibility: next, hydrated: true));
  }

  /// `resetBlockVisibilityForSwitch`: fail-closed while a switch's fetch is
  /// in flight, keeping the kill-switch entries.
  void resetForSwitch() {
    if (!state.hydrated) return;
    hydrate(BlockVisibility(disabled: state.visibility.disabled));
  }

  void clear() {
    _binding?.dispose();
    _binding = null;
    if (!isClosed) {
      emit(
        BlockVisibilityState(
          visibility: state.visibility,
          hydrated: state.hydrated,
        ),
      );
    }
  }

  void reset() {
    _binding?.dispose();
    _binding = null;
    _queryClient.removeQueries(BlockVisibilityKeys.all);
    if (!isClosed) emit(const BlockVisibilityState());
  }

  @override
  Future<void> close() {
    _binding?.dispose();
    return super.close();
  }
}
