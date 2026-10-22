import 'package:dio/dio.dart';
import 'package:sim_api/src/client/api_client_error.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/json.dart';
import 'package:sim_api/src/contracts/organizations.dart';
import 'package:sim_api/src/repositories/contract_request.dart';

/// Outcome of `GET /api/organizations/[id]/surface-context`: a 403 (not a
/// member, unknown organization) is "no organization home" for the entry
/// resolution (spec §8.1), not an error.
sealed class OrganizationAccess {
  const OrganizationAccess();

  const factory OrganizationAccess.granted(OrganizationSurface surface) =
      OrganizationAccessGranted;

  const factory OrganizationAccess.denied({ApiClientError? error}) =
      OrganizationAccessDenied;

  OrganizationSurface? get surfaceOrNull => switch (this) {
    OrganizationAccessGranted(:final surface) => surface,
    OrganizationAccessDenied() => null,
  };

  bool get isDenied => this is OrganizationAccessDenied;
}

final class OrganizationAccessGranted extends OrganizationAccess {
  const OrganizationAccessGranted(this.surface);

  final OrganizationSurface surface;
}

final class OrganizationAccessDenied extends OrganizationAccess {
  const OrganizationAccessDenied({this.error});

  final ApiClientError? error;
}

/// The organization reads of spec §3.4, §4.9 and §4.10 used in Phase 1.
class OrganizationsRepository {
  OrganizationsRepository(this._http);

  final SimHttpClient _http;

  /// `GET /api/organizations` → `{organizations, isMemberOfAnyOrg}`.
  Future<CreatorOrganizations> list({CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'GET',
        path: '/api/organizations',
        decode: CreatorOrganizations.fromJson,
        cancelToken: cancelToken,
      );

  /// `GET /api/organizations/[id]/surface-context`; 403 →
  /// [OrganizationAccess.denied].
  Future<OrganizationAccess> surfaceContext(
    String organizationId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final surface = await _http.requestContract(
        method: 'GET',
        path: '/api/organizations/[id]/surface-context',
        params: {'id': organizationId},
        decode: OrganizationSurface.fromJson,
        cancelToken: cancelToken,
      );
      return OrganizationAccess.granted(surface);
    } on ApiClientError catch (error) {
      if (error.status == 403) return OrganizationAccess.denied(error: error);
      rethrow;
    }
  }

  /// `GET /api/organizations/[id]/whitelabel` → `{success, data,
  /// isEnterprise?}`.
  Future<OrganizationWhitelabel> whitelabel(
    String organizationId, {
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/organizations/[id]/whitelabel',
    params: {'id': organizationId},
    decode: OrganizationWhitelabel.fromJson,
    cancelToken: cancelToken,
  );

  /// `GET /api/organizations/[id]/billing-plan` → `data`.
  Future<OrganizationPlanSeats> planSeats(
    String organizationId, {
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/organizations/[id]/billing-plan',
    params: {'id': organizationId},
    decode: (json) => OrganizationPlanSeats.fromJson(json.object('data')),
    cancelToken: cancelToken,
  );
}
