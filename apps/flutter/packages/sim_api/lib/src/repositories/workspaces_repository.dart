import 'package:dio/dio.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/json.dart';
import 'package:sim_api/src/contracts/workspaces.dart';
import 'package:sim_api/src/repositories/contract_request.dart';

/// The workspace contracts of `hooks/queries/workspace.ts` (spec §4.3), one
/// method per contract. Host context and feature flags live in
/// `RuntimeConfigRepository`; workspace pins in `PinnedItemsRepository`.
class WorkspacesRepository {
  WorkspacesRepository(this._http);

  final SimHttpClient _http;

  /// `GET /api/workspaces?scope=` (`listWorkspacesContract`). With
  /// `scope=active` and no workspaces the server creates "My Workspace".
  Future<WorkspaceList> list({
    ListScope scope = ListScope.active,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/workspaces',
    query: {'scope': scope.name},
    decode: WorkspaceList.fromJson,
    cancelToken: cancelToken,
  );

  /// `GET /api/workspaces` without `scope` (`useAdminWorkspaces`).
  Future<WorkspaceList> listDefault({CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'GET',
        path: '/api/workspaces',
        decode: WorkspaceList.fromJson,
        cancelToken: cancelToken,
      );

  /// `GET /api/workspaces/[id]` → `{workspace}`.
  Future<Workspace> get(String id, {CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'GET',
        path: '/api/workspaces/[id]',
        params: {'id': id},
        decode: (json) => Workspace.fromJson(json.object('workspace')),
        cancelToken: cancelToken,
      );

  /// `POST /api/workspaces` `{name, skipDefaultWorkflow?}` → `{workspace}`.
  Future<Workspace> create({
    required String name,
    bool? skipDefaultWorkflow,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'POST',
    path: '/api/workspaces',
    body: {'name': name.trim(), 'skipDefaultWorkflow': ?skipDefaultWorkflow},
    decode: (json) => Workspace.fromJson(json.object('workspace')),
    cancelToken: cancelToken,
  );

  /// `PATCH /api/workspaces/[id]` → `{workspace}`. [clearLogo] sends
  /// `logoUrl: null`.
  Future<Workspace> update(
    String id, {
    String? name,
    String? logoUrl,
    bool clearLogo = false,
    String? billedAccountUserId,
    bool? allowPersonalApiKeys,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'PATCH',
    path: '/api/workspaces/[id]',
    params: {'id': id},
    body: {
      'name': ?name?.trim(),
      if (clearLogo || logoUrl != null) 'logoUrl': clearLogo ? null : logoUrl,
      'billedAccountUserId': ?billedAccountUserId,
      'allowPersonalApiKeys': ?allowPersonalApiKeys,
    },
    decode: (json) => Workspace.fromJson(json.object('workspace')),
    cancelToken: cancelToken,
  );

  /// `DELETE /api/workspaces/[id]` body `{}` → `{success: true}`.
  Future<void> delete(String id, {CancelToken? cancelToken}) =>
      _http.requestSuccess(
        method: 'DELETE',
        path: '/api/workspaces/[id]',
        params: {'id': id},
        body: const <String, Object?>{},
        cancelToken: cancelToken,
      );

  /// `POST /api/workspaces/[id]/visit` → `{success: true}`.
  Future<void> recordVisit(String id, {CancelToken? cancelToken}) =>
      _http.requestSuccess(
        method: 'POST',
        path: '/api/workspaces/[id]/visit',
        params: {'id': id},
        cancelToken: cancelToken,
      );

  /// `GET /api/workspaces/[id]/permissions` → `{users, total, viewer?}`.
  /// 404 and 401 stay `ApiClientError`; the permissions cubit maps them to
  /// the `fetchWorkspacePermissions` messages.
  Future<WorkspacePermissions> permissions(
    String id, {
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/workspaces/[id]/permissions',
    params: {'id': id},
    decode: WorkspacePermissions.fromJson,
    cancelToken: cancelToken,
  );

  /// `PATCH /api/workspaces/[id]/permissions` `{updates}` → `{message}`.
  Future<String> updatePermissions(
    String id, {
    required List<PermissionUpdate> updates,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'PATCH',
    path: '/api/workspaces/[id]/permissions',
    params: {'id': id},
    body: {'updates': updates.map((u) => u.toJson()).toList()},
    decode: (json) => json.string('message'),
    cancelToken: cancelToken,
  );

  /// `GET /api/workspaces/[id]/members` → `{members}`.
  Future<List<WorkspaceMember>> members(
    String id, {
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/workspaces/[id]/members',
    params: {'id': id},
    decode: (json) =>
        json.objectList('members').map(WorkspaceMember.fromJson).toList(),
    cancelToken: cancelToken,
  );

  /// `GET /api/workspaces/[id]/credit-availability`.
  Future<CreditAvailability> creditAvailability(
    String id, {
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/workspaces/[id]/credit-availability',
    params: {'id': id},
    decode: CreditAvailability.fromJson,
    cancelToken: cancelToken,
  );

  /// `GET /api/workspaces/[id]/usage-gate`.
  Future<UsageGate> usageGate(String id, {CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'GET',
        path: '/api/workspaces/[id]/usage-gate',
        params: {'id': id},
        decode: UsageGate.fromJson,
        cancelToken: cancelToken,
      );
}
