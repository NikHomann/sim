import 'package:dio/dio.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/folders.dart';
import 'package:sim_api/src/contracts/json.dart';
import 'package:sim_api/src/contracts/workflows.dart';
import 'package:sim_api/src/repositories/contract_request.dart';

/// `{success: true, deletedItems?}` / `{success: true, restoredItems?}`.
class FolderCascadeResult {
  const FolderCascadeResult({this.counts});

  final FolderCascadeCounts? counts;
}

/// The folder contracts of `hooks/queries/folders.ts` (spec §4.5).
class FoldersRepository {
  FoldersRepository(this._http);

  final SimHttpClient _http;

  /// `GET /api/folders?workspaceId&scope&resourceType` → `{folders}`.
  Future<List<Folder>> list({
    required String workspaceId,
    FolderScope scope = FolderScope.active,
    FolderResourceType resourceType = FolderResourceType.workflow,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/folders',
    query: {
      'workspaceId': workspaceId,
      'scope': scope.name,
      'resourceType': resourceType.wireName,
    },
    decode: (json) => json.objectList('folders').map(Folder.fromJson).toList(),
    cancelToken: cancelToken,
  );

  /// `POST /api/folders` → `{folder}`. A root folder sends `parentId: null`
  /// whenever [parentId] is null.
  Future<Folder> create({
    required String name,
    required String workspaceId,
    String? id,
    FolderResourceType resourceType = FolderResourceType.workflow,
    String? parentId,
    int? sortOrder,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'POST',
    path: '/api/folders',
    body: {
      'id': ?id,
      'resourceType': resourceType.wireName,
      'name': name.trim(),
      'workspaceId': workspaceId,
      'parentId': parentId,
      'sortOrder': ?sortOrder,
    },
    decode: (json) => Folder.fromJson(json.object('folder')),
    cancelToken: cancelToken,
  );

  /// `PUT /api/folders/[id]?resourceType=` → `{folder}`.
  Future<Folder> update(
    String id, {
    required FolderUpdate update,
    FolderResourceType resourceType = FolderResourceType.workflow,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'PUT',
    path: '/api/folders/[id]',
    params: {'id': id},
    query: {'resourceType': resourceType.wireName},
    body: update.toJson(),
    decode: (json) => Folder.fromJson(json.object('folder')),
    cancelToken: cancelToken,
  );

  /// `DELETE /api/folders/[id]?resourceType=` → `{success, deletedItems?}`.
  Future<FolderCascadeResult> delete(
    String id, {
    FolderResourceType resourceType = FolderResourceType.workflow,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'DELETE',
    path: '/api/folders/[id]',
    params: {'id': id},
    query: {'resourceType': resourceType.wireName},
    decode: (json) => FolderCascadeResult(
      counts: switch (json.objectOrNull('deletedItems')) {
        final counts? => FolderCascadeCounts.fromJson(counts),
        null => null,
      },
    ),
    cancelToken: cancelToken,
  );

  /// `POST /api/folders/[id]/restore` `{workspaceId, resourceType}`.
  Future<FolderCascadeResult> restore(
    String id, {
    required String workspaceId,
    FolderResourceType resourceType = FolderResourceType.workflow,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'POST',
    path: '/api/folders/[id]/restore',
    params: {'id': id},
    body: {'workspaceId': workspaceId, 'resourceType': resourceType.wireName},
    decode: (json) => FolderCascadeResult(
      counts: switch (json.objectOrNull('restoredItems')) {
        final counts? => FolderCascadeCounts.fromJson(counts),
        null => null,
      },
    ),
    cancelToken: cancelToken,
  );

  /// `POST /api/folders/[id]/duplicate` `{name, workspaceId?, parentId?,
  /// newId?}` → `{folder}`. `parentId` is sent (possibly `null`) only with
  /// [sendParent].
  Future<Folder> duplicate(
    String id, {
    required String name,
    String? workspaceId,
    String? parentId,
    bool sendParent = false,
    String? newId,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'POST',
    path: '/api/folders/[id]/duplicate',
    params: {'id': id},
    body: {
      'name': name,
      'workspaceId': ?workspaceId,
      if (sendParent || parentId != null) 'parentId': parentId,
      'newId': ?newId,
    },
    decode: (json) => Folder.fromJson(json.object('folder')),
    cancelToken: cancelToken,
  );

  /// `PUT /api/folders/reorder` `{workspaceId, resourceType, updates}`.
  Future<ReorderResult> reorder({
    required String workspaceId,
    required List<FolderReorderUpdate> updates,
    FolderResourceType resourceType = FolderResourceType.workflow,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'PUT',
    path: '/api/folders/reorder',
    body: {
      'workspaceId': workspaceId,
      'resourceType': resourceType.wireName,
      'updates': updates.map((u) => u.toJson()).toList(),
    },
    decode: ReorderResult.fromJson,
    cancelToken: cancelToken,
  );

  /// `generateFolderName(ws)` (`naming.ts:46-52`): `GET /api/folders?workspaceId`
  /// then `generateIncrementalName(rootFolders, 'Folder')`.
  Future<String> generateName(
    String workspaceId, {
    CancelToken? cancelToken,
  }) async {
    final folders = await _http.requestContract(
      method: 'GET',
      path: '/api/folders',
      query: {'workspaceId': workspaceId},
      decode: (json) =>
          json.objectList('folders').map(Folder.fromJson).toList(),
      cancelToken: cancelToken,
    );
    return nextFolderName(folders);
  }

  /// `generateIncrementalName(rootFolders, 'Folder')` (`naming.ts:19-33`):
  /// one past the highest "Folder N" among the root folders, else 1.
  static String nextFolderName(List<Folder> folders) {
    final pattern = RegExp(r'^Folder (\d+)$');
    var highest = 0;
    for (final folder in folders) {
      if (folder.parentId != null) continue;
      final match = pattern.firstMatch(folder.name);
      if (match == null) continue;
      final n = int.parse(match.group(1)!);
      if (n > highest) highest = n;
    }
    return 'Folder ${highest + 1}';
  }
}
