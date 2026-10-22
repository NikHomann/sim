import 'package:dio/dio.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/common.dart';
import 'package:sim_api/src/repositories/contract_request.dart';

/// The `settings/allowed-*` reads of `hooks/queries/integration-availability.ts`
/// and `allowed-providers.ts` (spec §4.9).
class SettingsRepository {
  SettingsRepository(this._http);

  final SimHttpClient _http;

  /// `GET /api/settings/allowed-integrations`.
  Future<AllowedIntegrations> allowedIntegrations({CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'GET',
        path: '/api/settings/allowed-integrations',
        decode: AllowedIntegrations.fromJson,
        cancelToken: cancelToken,
      );

  /// `GET /api/settings/allowed-providers` → `{blacklistedProviders}`.
  Future<AllowedProviders> allowedProviders({CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'GET',
        path: '/api/settings/allowed-providers',
        decode: AllowedProviders.fromJson,
        cancelToken: cancelToken,
      );
}
