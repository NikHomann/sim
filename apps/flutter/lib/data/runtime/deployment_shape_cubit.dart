import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/query_keys.dart';

/// State of [DeploymentShapeCubit]: the public env and the seeded shape.
class DeploymentShapeState extends Equatable {
  const DeploymentShapeState({
    this.publicEnv = const LoadState(),
    this.seeded,
  });

  final LoadState<PublicEnv> publicEnv;

  /// The server-resolved shape from the workspace host context, when seeded.
  final DeploymentShape? seeded;

  PublicEnv get env => publicEnv.data ?? PublicEnv.empty;

  /// `getDeploymentShape()`: the seeded shape, else the `NEXT_PUBLIC_*`
  /// fallback (`deployment-shape.ts:62-66`).
  DeploymentShape get shape => seeded ?? env.fallbackDeploymentShape;

  bool get isReady => publicEnv.isReady;

  /// A 5xx on public env: the app cannot start (spec §4.2).
  bool get failedToStart => publicEnv.hasError && !publicEnv.hasData;

  DeploymentShapeState copyWith({
    LoadState<PublicEnv>? publicEnv,
    DeploymentShape? seeded,
    bool clearSeeded = false,
  }) => DeploymentShapeState(
    publicEnv: publicEnv ?? this.publicEnv,
    seeded: clearSeeded ? null : (seeded ?? this.seeded),
  );

  @override
  List<Object?> get props => [publicEnv, seeded];
}

/// The root `public-env` read plus the `deployment-shape` store (spec §3.1,
/// §7): [loadPublicEnv] once at app start, [seed] from every host context
/// (a no-op for a structurally equal shape, so a refetch never notifies
/// listeners for nothing).
class DeploymentShapeCubit extends Cubit<DeploymentShapeState> {
  DeploymentShapeCubit({
    required RuntimeConfigRepository runtimeConfig,
    required QueryClient queryClient,
  }) : _runtimeConfig = runtimeConfig,
       _queryClient = queryClient,
       super(const DeploymentShapeState());

  final RuntimeConfigRepository _runtimeConfig;
  final QueryClient _queryClient;

  /// `GET /api/public-env`, fetched once; the result is cached under
  /// `['public-env']` and never refetched.
  Future<PublicEnv?> loadPublicEnv() async {
    emit(
      state.copyWith(
        publicEnv: state.publicEnv.copyWith(
          status: LoadStatus.loading,
          isFetching: true,
        ),
      ),
    );
    try {
      final env = await _queryClient.fetchQuery<PublicEnv>(
        PublicEnvKeys.all,
        (token) => _runtimeConfig.publicEnv(cancelToken: token),
        staleTime: StaleTimes.publicEnv,
      );
      if (!isClosed) emit(state.copyWith(publicEnv: LoadState.ready(env)));
      return env;
    } on Object catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            publicEnv: state.publicEnv.copyWith(
              status: LoadStatus.error,
              error: error,
              isFetching: false,
            ),
          ),
        );
      }
      return null;
    }
  }

  /// `seedDeploymentShape` (`deployment-shape.ts:97-120`).
  void seed(DeploymentShape shape) {
    if (state.seeded == shape) return;
    emit(state.copyWith(seeded: shape));
  }

  /// Drops the seeded shape (sign-out). The public env is deployment
  /// configuration, not user data, and survives.
  void reset() => emit(state.copyWith(clearSeeded: true));
}
