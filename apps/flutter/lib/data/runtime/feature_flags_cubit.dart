import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';

/// State of [FeatureFlagsCubit]: every flag `false` until loaded
/// (`useFeatureFlag` → `flags[name] ?? false`).
class FeatureFlagsState extends Equatable {
  const FeatureFlagsState({
    this.workspaceId,
    this.result = const LoadState(),
    this.organizationFlags,
    this.organizationBenchmarkEnabled = false,
  });

  final String? workspaceId;
  final LoadState<FeatureFlagsResult> result;

  /// Flags of the organization surface (`/o/*`), when applied.
  final WorkspaceFeatureFlags? organizationFlags;
  final bool organizationBenchmarkEnabled;

  WorkspaceFeatureFlags get flags =>
      organizationFlags ??
      switch (result.data) {
        FeatureFlagsLoaded(:final response) => response.flags,
        _ => const WorkspaceFeatureFlags(),
      };

  DesktopExecutorStatus get desktopExecutor => switch (result.data) {
    FeatureFlagsLoaded(:final response) => response.desktopExecutor,
    _ => const DesktopExecutorStatus(),
  };

  bool flag(String name) => flags.flag(name);

  /// The server refused (403/404). Informational only: access is gated on
  /// the host context (`layout.tsx`), so a refused flags load leaves every
  /// flag off and never denies the workspace.
  bool get accessDenied => result.data is FeatureFlagsDenied;

  /// 429: the server's `Retry-After`, when it sent one.
  Duration? get retryAfter => switch (result.data) {
    FeatureFlagsRateLimited(:final retryAfter) => retryAfter,
    _ => null,
  };

  bool get isRateLimited => result.data is FeatureFlagsRateLimited;

  FeatureFlagsState copyWith({
    String? workspaceId,
    LoadState<FeatureFlagsResult>? result,
    WorkspaceFeatureFlags? organizationFlags,
    bool clearOrganization = false,
    bool? organizationBenchmarkEnabled,
  }) => FeatureFlagsState(
    workspaceId: workspaceId ?? this.workspaceId,
    result: result ?? this.result,
    organizationFlags: clearOrganization
        ? null
        : (organizationFlags ?? this.organizationFlags),
    organizationBenchmarkEnabled:
        !clearOrganization &&
        (organizationBenchmarkEnabled ?? this.organizationBenchmarkEnabled),
  );

  @override
  List<Object?> get props => [
    workspaceId,
    result,
    organizationFlags,
    organizationBenchmarkEnabled,
  ];
}

/// `FeatureFlagsProvider` (spec §3.2, §4.2, §7):
/// `GET /api/workspaces/[id]/feature-flags` per workspace, stale 30 s
/// (chosen like the host context),
/// 403/404 → denied, 429 → rate limited with `Retry-After`. The organization
/// surface variant (`applyOrganizationSurface`) adds `mothership-memory-spaces`
/// and maps `mothership-plan-mode` to `benchmarkEnabled`
/// (`o/[organizationId]/layout.tsx:100-110`).
class FeatureFlagsCubit extends Cubit<FeatureFlagsState> {
  FeatureFlagsCubit({
    required RuntimeConfigRepository runtimeConfig,
    required QueryClient queryClient,
  }) : _runtimeConfig = runtimeConfig,
       _queryClient = queryClient,
       super(const FeatureFlagsState());

  final RuntimeConfigRepository _runtimeConfig;
  final QueryClient _queryClient;
  QueryBinding<FeatureFlagsResult>? _binding;

  /// Fetches the flags of [workspaceId] (workspace entry and switch).
  Future<FeatureFlagsResult?> load(String workspaceId) async {
    if (state.workspaceId != workspaceId || _binding == null) {
      _binding?.dispose();
      final query = _queryClient.query<FeatureFlagsResult>(
        FeatureFlagKeys.detail(workspaceId),
        (token) => _runtimeConfig.featureFlags(workspaceId, cancelToken: token),
        staleTime: StaleTimes.workspaceFeatureFlags,
      );
      _binding = QueryBinding(query, _onQueryState);
      emit(
        FeatureFlagsState(
          workspaceId: workspaceId,
          result: LoadState.fromQuery(query.state),
        ),
      );
    }
    try {
      return await _binding!.fetch();
    } on Object {
      return null;
    }
  }

  void _onQueryState(QueryState<FeatureFlagsResult> queryState) {
    if (isClosed) return;
    emit(state.copyWith(result: LoadState.fromQuery(queryState)));
  }

  /// The organization surface's flags: `mothership-plan-mode` reads
  /// `benchmarkEnabled`, `mothership-memory-spaces` is carried through.
  void applyOrganizationSurface(OrganizationSurface surface) {
    final flags = surface.flags;
    emit(
      state.copyWith(
        organizationFlags: WorkspaceFeatureFlags(
          dashboards: flags.dashboards,
          workflowTests: flags.workflowTests,
          changelog: flags.changelog,
          mothershipModelSelector: flags.mothershipModelSelector,
          mothershipComputerUse: flags.mothershipComputerUse,
          mothershipPlanMode: surface.benchmarkEnabled,
          projects: flags.projects,
          mothershipMemorySpaces: flags.mothershipMemorySpaces ?? false,
        ),
        organizationBenchmarkEnabled: surface.benchmarkEnabled,
      ),
    );
  }

  /// Back to the workspace flags (leaving `/o/*`).
  void clearOrganizationSurface() =>
      emit(state.copyWith(clearOrganization: true));

  void reset() {
    _binding?.dispose();
    _binding = null;
    _queryClient.removeQueries(FeatureFlagKeys.all);
    if (!isClosed) emit(const FeatureFlagsState());
  }

  @override
  Future<void> close() {
    _binding?.dispose();
    return super.close();
  }
}
