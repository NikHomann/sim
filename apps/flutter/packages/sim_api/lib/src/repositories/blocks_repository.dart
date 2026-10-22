import 'package:dio/dio.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/blocks.dart';
import 'package:sim_api/src/repositories/contract_request.dart';

/// The workspace loader reads of spec §4.9: custom blocks, block
/// visibility and provider model lists.
class BlocksRepository {
  BlocksRepository(this._http);

  final SimHttpClient _http;

  /// `GET /api/custom-blocks?workspaceId` → `{enabled, customBlocks}`.
  Future<CustomBlocksResponse> customBlocks(
    String workspaceId, {
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/custom-blocks',
    query: {'workspaceId': workspaceId},
    decode: CustomBlocksResponse.fromJson,
    cancelToken: cancelToken,
  );

  /// `GET /api/blocks/visibility?workspaceId`.
  Future<BlockVisibility> visibility(
    String workspaceId, {
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/blocks/visibility',
    query: {'workspaceId': workspaceId},
    decode: BlockVisibility.fromJson,
    cancelToken: cancelToken,
  );

  /// `GET /api/providers/<provider>/models`; `?workspaceId` only for the
  /// providers whose route accepts it (`ollama-cloud`, `fireworks`,
  /// `together`, `baseten`). OpenRouter lists are de-duplicated.
  Future<ProviderModels> providerModels(
    ProviderName provider, {
    String? workspaceId,
    CancelToken? cancelToken,
  }) async {
    final models = await _http.requestContract(
      method: 'GET',
      path: provider.path,
      query: {
        if (provider.takesWorkspace) 'workspaceId': ?workspaceId,
      },
      decode: ProviderModels.fromJson,
      cancelToken: cancelToken,
    );
    return provider == ProviderName.openrouter ? models.deduplicated() : models;
  }
}
