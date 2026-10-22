import 'package:dio/dio.dart';
import 'package:sim_api/src/client/api_client_error.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/public_env.dart';
import 'package:sim_api/src/contracts/workspaces.dart';
import 'package:sim_api/src/repositories/contract_request.dart';

/// Outcome of `GET /api/workspaces/[id]/host-context`: the 403 the route
/// answers for an unreadable or unknown workspace is the access-denied page,
/// not an error (`workspace-host-provider.tsx:35-37`).
sealed class WorkspaceAccess {
  const WorkspaceAccess();

  const factory WorkspaceAccess.granted(WorkspaceHostContext context) =
      WorkspaceAccessGranted;

  const factory WorkspaceAccess.denied({ApiClientError? error}) =
      WorkspaceAccessDenied;

  WorkspaceHostContext? get contextOrNull => switch (this) {
    WorkspaceAccessGranted(:final context) => context,
    WorkspaceAccessDenied() => null,
  };

  bool get isDenied => this is WorkspaceAccessDenied;
}

final class WorkspaceAccessGranted extends WorkspaceAccess {
  const WorkspaceAccessGranted(this.context);

  final WorkspaceHostContext context;
}

final class WorkspaceAccessDenied extends WorkspaceAccess {
  const WorkspaceAccessDenied({this.error});

  final ApiClientError? error;
}

/// Outcome of `GET /api/workspaces/[id]/feature-flags` (spec §4.2, §9):
/// 403/404 are the same access-denied handling as the host context, a 429
/// carries the server's `Retry-After`.
sealed class FeatureFlagsResult {
  const FeatureFlagsResult();
}

final class FeatureFlagsLoaded extends FeatureFlagsResult {
  const FeatureFlagsLoaded(this.response);

  final WorkspaceFeatureFlagsResponse response;
}

final class FeatureFlagsDenied extends FeatureFlagsResult {
  const FeatureFlagsDenied(this.error);

  final ApiClientError error;
}

final class FeatureFlagsRateLimited extends FeatureFlagsResult {
  const FeatureFlagsRateLimited(this.error);

  final ApiClientError error;

  Duration? get retryAfter => error.retryAfter;
}

/// The runtime configuration reads of spec §4.2: public env, workspace host
/// context and workspace feature flags.
class RuntimeConfigRepository {
  RuntimeConfigRepository(this._http);

  final SimHttpClient _http;

  /// `GET /api/public-env` (unauthenticated, `Cache-Control: no-store`) →
  /// the flat `NEXT_PUBLIC_*` record; a key without the prefix fails
  /// validation (`ApiClientError{status: 200}`).
  Future<PublicEnv> publicEnv({CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'GET',
        path: '/api/public-env',
        decode: PublicEnv.fromJson,
        cancelToken: cancelToken,
      );

  /// `GET /api/workspaces/[id]/host-context`. A 403 is
  /// [WorkspaceAccess.denied]; 401 and other failures are thrown.
  Future<WorkspaceAccess> hostContext(
    String workspaceId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final context = await _http.requestContract(
        method: 'GET',
        path: '/api/workspaces/[id]/host-context',
        params: {'id': workspaceId},
        decode: WorkspaceHostContext.fromJson,
        cancelToken: cancelToken,
      );
      return WorkspaceAccess.granted(context);
    } on ApiClientError catch (error) {
      if (error.status == 403) return WorkspaceAccess.denied(error: error);
      rethrow;
    }
  }

  /// `GET /api/workspaces/[id]/feature-flags`. 403/404 →
  /// [FeatureFlagsDenied], 429 → [FeatureFlagsRateLimited] with the parsed
  /// `Retry-After`; 401 and 5xx are thrown.
  Future<FeatureFlagsResult> featureFlags(
    String workspaceId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _http.requestContract(
        method: 'GET',
        path: '/api/workspaces/[id]/feature-flags',
        params: {'id': workspaceId},
        decode: WorkspaceFeatureFlagsResponse.fromJson,
        cancelToken: cancelToken,
      );
      return FeatureFlagsLoaded(response);
    } on ApiClientError catch (error) {
      return switch (error.status) {
        403 || 404 => FeatureFlagsDenied(error),
        429 => FeatureFlagsRateLimited(error),
        _ => throw error,
      };
    }
  }
}
