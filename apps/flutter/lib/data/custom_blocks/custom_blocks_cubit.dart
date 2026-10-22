import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';

/// One entry of the client custom-block overlay
/// (`hydrateClientCustomBlocks`): disabled blocks stay resolvable but are
/// hidden from the toolbar; the icon falls back to the organization logo.
class CustomBlockOverlayEntry extends Equatable {
  const CustomBlockOverlayEntry({
    required this.block,
    required this.hideFromToolbar,
    required this.iconUrl,
  });

  final CustomBlock block;
  final bool hideFromToolbar;
  final String? iconUrl;

  @override
  List<Object?> get props => [block, hideFromToolbar, iconUrl];
}

/// State of [CustomBlocksCubit].
class CustomBlocksState extends Equatable {
  const CustomBlocksState({
    this.workspaceId,
    this.response = const LoadState(),
    this.fallbackIconUrl,
    this.overlayVersion = 0,
  });

  final String? workspaceId;
  final LoadState<CustomBlocksResponse> response;

  /// The organization logo (from branding) used when a block has no icon.
  final String? fallbackIconUrl;

  /// Bumped on every data change so the registry overlay rebuilds.
  final int overlayVersion;

  bool get enabled => response.data?.enabled ?? false;
  List<CustomBlock> get blocks => response.data?.customBlocks ?? const [];

  List<CustomBlockOverlayEntry> get overlay => [
    for (final block in blocks)
      CustomBlockOverlayEntry(
        block: block,
        hideFromToolbar: !block.enabled,
        iconUrl: block.iconUrl ?? fallbackIconUrl,
      ),
  ];

  CustomBlocksState copyWith({
    String? workspaceId,
    LoadState<CustomBlocksResponse>? response,
    String? fallbackIconUrl,
    bool clearFallback = false,
    int? overlayVersion,
  }) => CustomBlocksState(
    workspaceId: workspaceId ?? this.workspaceId,
    response: response ?? this.response,
    fallbackIconUrl: clearFallback
        ? null
        : (fallbackIconUrl ?? this.fallbackIconUrl),
    overlayVersion: overlayVersion ?? this.overlayVersion,
  );

  @override
  List<Object?> get props => [
    workspaceId,
    response,
    fallbackIconUrl,
    overlayVersion,
  ];
}

/// `CustomBlocksLoader` (spec §4.9, §7): `['custom-blocks','list',ws]`,
/// stale 60 s, overlay rebuilt (version bump) on every data change.
class CustomBlocksCubit extends Cubit<CustomBlocksState> {
  CustomBlocksCubit({
    required BlocksRepository blocks,
    required QueryClient queryClient,
  }) : _blocks = blocks,
       _queryClient = queryClient,
       super(const CustomBlocksState());

  final BlocksRepository _blocks;
  final QueryClient _queryClient;
  QueryBinding<CustomBlocksResponse>? _binding;

  Future<CustomBlocksResponse?> load(String workspaceId) async {
    if (state.workspaceId != workspaceId || _binding == null) {
      _binding?.dispose();
      final query = _queryClient.query<CustomBlocksResponse>(
        CustomBlockKeys.list(workspaceId),
        (token) => _blocks.customBlocks(workspaceId, cancelToken: token),
        staleTime: StaleTimes.customBlockList,
      );
      _binding = QueryBinding(query, _onQueryState);
      emit(
        state.copyWith(
          workspaceId: workspaceId,
          response: LoadState.fromQuery(query.state),
          overlayVersion: state.overlayVersion + 1,
        ),
      );
    }
    try {
      return await _binding!.fetch();
    } on Object {
      return null;
    }
  }

  void _onQueryState(QueryState<CustomBlocksResponse> queryState) {
    if (isClosed) return;
    final load = LoadState<CustomBlocksResponse>.fromQuery(queryState);
    final changed = load.data != state.response.data;
    emit(
      state.copyWith(
        response: load,
        overlayVersion: changed ? state.overlayVersion + 1 : null,
      ),
    );
  }

  /// The organization logo from the branding cubit.
  void setFallbackIcon(String? url) {
    if (url == state.fallbackIconUrl) return;
    emit(
      state.copyWith(
        fallbackIconUrl: url,
        clearFallback: url == null,
        overlayVersion: state.overlayVersion + 1,
      ),
    );
  }

  /// `['custom-blocks','list']` after publish / update / delete.
  Future<void> invalidate() =>
      _queryClient.invalidateQueries(CustomBlockKeys.lists());

  void clear() {
    _binding?.dispose();
    _binding = null;
    if (!isClosed) {
      emit(CustomBlocksState(overlayVersion: state.overlayVersion + 1));
    }
  }

  void reset() {
    clear();
    _queryClient.removeQueries(CustomBlockKeys.all);
  }

  @override
  Future<void> close() {
    _binding?.dispose();
    return super.close();
  }
}
