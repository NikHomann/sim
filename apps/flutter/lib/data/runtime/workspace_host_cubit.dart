import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';
import 'package:sim_app/data/runtime/deployment_shape_cubit.dart';

/// State of [WorkspaceHostCubit].
class WorkspaceHostState extends Equatable {
  const WorkspaceHostState({this.workspaceId, this.access = const LoadState()});

  final String? workspaceId;
  final LoadState<WorkspaceAccess> access;

  WorkspaceHostContext? get context => access.data?.contextOrNull;

  /// The route answered 403: render `WorkspaceAccessDenied`.
  bool get accessDenied => access.data?.isDenied ?? false;
  bool get isLoading => access.isLoading;
  Object? get error => access.error;

  WorkspacePermission? get viewerPermission => context?.viewer.permission;

  WorkspaceHostState copyWith({
    String? workspaceId,
    LoadState<WorkspaceAccess>? access,
  }) => WorkspaceHostState(
    workspaceId: workspaceId ?? this.workspaceId,
    access: access ?? this.access,
  );

  @override
  List<Object?> get props => [workspaceId, access];
}

/// `WorkspaceHostProvider` (spec §4.2, §7): `['workspace-host','detail',id]`,
/// stale 30 s, refetched on workspace switch; a 403 is the access-denied
/// page; a granted context seeds [DeploymentShapeCubit].
class WorkspaceHostCubit extends Cubit<WorkspaceHostState> {
  WorkspaceHostCubit({
    required RuntimeConfigRepository runtimeConfig,
    required QueryClient queryClient,
    DeploymentShapeCubit? deploymentShape,
  }) : _runtimeConfig = runtimeConfig,
       _queryClient = queryClient,
       _deploymentShape = deploymentShape,
       super(const WorkspaceHostState());

  final RuntimeConfigRepository _runtimeConfig;
  final QueryClient _queryClient;
  final DeploymentShapeCubit? _deploymentShape;
  QueryBinding<WorkspaceAccess>? _binding;

  /// Binds to [workspaceId] (re-using the cached entry) and fetches when
  /// stale. Never throws: failures land on the state.
  Future<WorkspaceAccess?> load(String workspaceId) async {
    if (state.workspaceId != workspaceId || _binding == null) {
      _binding?.dispose();
      final query = _queryClient.query<WorkspaceAccess>(
        WorkspaceHostKeys.detail(workspaceId),
        (token) => _runtimeConfig.hostContext(workspaceId, cancelToken: token),
        staleTime: StaleTimes.workspaceHostContext,
      );
      _binding = QueryBinding(query, _onQueryState);
      emit(
        WorkspaceHostState(
          workspaceId: workspaceId,
          access: LoadState.fromQuery(query.state),
        ),
      );
      _seedFrom(query.state.data);
    }
    try {
      return await _binding!.fetch();
    } on Object {
      return null;
    }
  }

  Future<void> refetch() async {
    try {
      await _binding?.refetch();
    } on Object {
      // Surfaced on the state.
    }
  }

  void _onQueryState(QueryState<WorkspaceAccess> queryState) {
    if (isClosed) return;
    emit(state.copyWith(access: LoadState.fromQuery(queryState)));
    _seedFrom(queryState.data);
  }

  void _seedFrom(WorkspaceAccess? access) {
    final deployment = access?.contextOrNull?.deployment;
    if (deployment != null) _deploymentShape?.seed(deployment);
  }

  /// Leaves the workspace scope (workspace exit) without touching the cache.
  void clear() {
    _binding?.dispose();
    _binding = null;
    if (!isClosed) emit(const WorkspaceHostState());
  }

  /// Store reset: also drops the cached contexts.
  void reset() {
    clear();
    _queryClient.removeQueries(WorkspaceHostKeys.all);
  }

  @override
  Future<void> close() {
    _binding?.dispose();
    return super.close();
  }
}
