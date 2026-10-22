import 'package:dio/dio.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/json.dart';
import 'package:sim_api/src/contracts/workflows.dart';
import 'package:sim_api/src/contracts/workspaces.dart';
import 'package:sim_api/src/repositories/contract_request.dart';

/// The workflow list contracts of `hooks/queries/workflows.ts` (spec §4.6).
class WorkflowsRepository {
  WorkflowsRepository(this._http);

  final SimHttpClient _http;

  /// `GET /api/workflows?workspaceId&scope=` → `{data}`.
  Future<List<WorkflowListItem>> list({
    required String workspaceId,
    ListScope scope = ListScope.active,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/workflows',
    query: {'workspaceId': workspaceId, 'scope': scope.name},
    decode: (json) =>
        json.objectList('data').map(WorkflowListItem.fromJson).toList(),
    cancelToken: cancelToken,
  );

  /// `POST /api/workflows` (`createWorkflowContract`). `folderId` is sent
  /// (possibly `null`) only with [sendFolder].
  Future<CreatedWorkflow> create({
    required String name,
    String? id,
    String? description,
    String? workspaceId,
    String? folderId,
    bool sendFolder = false,
    int? sortOrder,
    bool? deduplicate,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'POST',
    path: '/api/workflows',
    body: {
      'id': ?id,
      'name': name,
      'description': ?description,
      'workspaceId': ?workspaceId,
      if (sendFolder || folderId != null) 'folderId': folderId,
      'sortOrder': ?sortOrder,
      'deduplicate': ?deduplicate,
    },
    decode: CreatedWorkflow.fromJson,
    cancelToken: cancelToken,
  );

  /// `POST /api/workflows/[id]/duplicate` (`duplicateWorkflowContract`).
  Future<DuplicatedWorkflow> duplicate(
    String id, {
    required String name,
    String? description,
    String? workspaceId,
    String? folderId,
    bool sendFolder = false,
    String? newId,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'POST',
    path: '/api/workflows/[id]/duplicate',
    params: {'id': id},
    body: {
      'name': name,
      'description': ?description,
      'workspaceId': ?workspaceId,
      if (sendFolder || folderId != null) 'folderId': folderId,
      'newId': ?newId,
    },
    decode: DuplicatedWorkflow.fromJson,
    cancelToken: cancelToken,
  );

  /// `PUT /api/workflows/[id]` → `{workflow}`.
  Future<WorkflowListItem> update(
    String id, {
    required WorkflowUpdate update,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'PUT',
    path: '/api/workflows/[id]',
    params: {'id': id},
    body: update.toJson(),
    decode: (json) => WorkflowListItem.fromJson(json.object('workflow')),
    cancelToken: cancelToken,
  );

  /// `DELETE /api/workflows/[id]` → `{success: true}` (soft delete).
  Future<void> delete(String id, {CancelToken? cancelToken}) =>
      _http.requestSuccess(
        method: 'DELETE',
        path: '/api/workflows/[id]',
        params: {'id': id},
        cancelToken: cancelToken,
      );

  /// `PUT /api/workflows/reorder` `{workspaceId, updates}`.
  Future<ReorderResult> reorder({
    required String workspaceId,
    required List<WorkflowReorderUpdate> updates,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'PUT',
    path: '/api/workflows/reorder',
    body: {
      'workspaceId': workspaceId,
      'updates': updates.map((u) => u.toJson()).toList(),
    },
    decode: ReorderResult.fromJson,
    cancelToken: cancelToken,
  );

  /// `POST /api/workflows/[id]/restore` → `{success: true}`.
  Future<void> restore(String id, {CancelToken? cancelToken}) =>
      _http.requestSuccess(
        method: 'POST',
        path: '/api/workflows/[id]/restore',
        params: {'id': id},
        cancelToken: cancelToken,
      );

  /// `GET /api/workflows/[id]` → `data` reduced to the fields the picker
  /// redirect reads (`?redirect_workflow=`).
  Future<WorkflowSummary> summary(String id, {CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'GET',
        path: '/api/workflows/[id]',
        params: {'id': id},
        decode: (json) => WorkflowSummary.fromJson(json.object('data')),
        cancelToken: cancelToken,
      );
}
