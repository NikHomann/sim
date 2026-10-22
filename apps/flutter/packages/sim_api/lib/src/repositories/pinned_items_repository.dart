import 'package:dio/dio.dart';
import 'package:sim_api/src/client/api_client_error.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/json.dart';
import 'package:sim_api/src/contracts/pinned_items.dart';
import 'package:sim_api/src/repositories/contract_request.dart';

/// The pinned-item contracts of `hooks/queries/pinned-items.ts` (spec §4.7)
/// and the workspace pin toggle of `hooks/queries/workspace.ts:213-280`.
class PinnedItemsRepository {
  PinnedItemsRepository(this._http);

  final SimHttpClient _http;

  /// `GET /api/pinned-items?workspaceId&resourceType?` → `{pinnedItems}`.
  Future<List<PinnedItem>> list({
    required String workspaceId,
    PinnedResourceType? resourceType,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/pinned-items',
    query: {
      'workspaceId': workspaceId,
      'resourceType': ?resourceType?.wireName,
    },
    decode: (json) =>
        json.objectList('pinnedItems').map(PinnedItem.fromJson).toList(),
    cancelToken: cancelToken,
  );

  /// `POST /api/pinned-items` → `{pinnedItem}`. 409 (already pinned) stays
  /// an `ApiClientError` here; the workspace toggle treats it as success.
  Future<PinnedItem> pin({
    required String workspaceId,
    required PinnedResourceType resourceType,
    required String resourceId,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'POST',
    path: '/api/pinned-items',
    body: {
      'workspaceId': workspaceId,
      'resourceType': resourceType.wireName,
      'resourceId': resourceId,
    },
    decode: (json) => PinnedItem.fromJson(json.object('pinnedItem')),
    cancelToken: cancelToken,
  );

  /// `DELETE /api/pinned-items/[resourceType]/[resourceId]` → `{success}`.
  Future<void> unpin({
    required PinnedResourceType resourceType,
    required String resourceId,
    CancelToken? cancelToken,
  }) => _http.requestSuccess(
    method: 'DELETE',
    path: '/api/pinned-items/[resourceType]/[resourceId]',
    params: {'resourceType': resourceType.wireName, 'resourceId': resourceId},
    cancelToken: cancelToken,
  );

  /// `useToggleWorkspacePin`'s `mutationFn`: pin
  /// (`{workspaceId: id, resourceType: 'workspace', resourceId: id}`) or
  /// unpin a workspace. A 409 on pin and a 404 on unpin mean the row is
  /// already in the requested end state and resolve normally; the return
  /// value says whether that happened.
  Future<bool> toggleWorkspacePin({
    required String workspaceId,
    required bool pinned,
    CancelToken? cancelToken,
  }) async {
    try {
      if (pinned) {
        await pin(
          workspaceId: workspaceId,
          resourceType: PinnedResourceType.workspace,
          resourceId: workspaceId,
          cancelToken: cancelToken,
        );
      } else {
        await unpin(
          resourceType: PinnedResourceType.workspace,
          resourceId: workspaceId,
          cancelToken: cancelToken,
        );
      }
      return false;
    } on ApiClientError catch (error) {
      final alreadyInEndState = pinned ? 409 : 404;
      if (error.status == alreadyInEndState) return true;
      rethrow;
    }
  }
}
