import 'package:dio/dio.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/recently_deleted.dart';
import 'package:sim_api/src/repositories/contract_request.dart';

/// `GET /api/workspaces/[id]/recently-deleted` (spec §4.13): cursor paging
/// with `limit` 1..100 (default 50).
class RecentlyDeletedRepository {
  RecentlyDeletedRepository(this._http);

  final SimHttpClient _http;

  Future<RecentlyDeletedPage> list(
    String workspaceId, {
    RecentlyDeletedFilter type = RecentlyDeletedFilter.all,
    String? search,
    RecentlyDeletedSort sortBy = RecentlyDeletedSort.deleted,
    SortOrder sortOrder = SortOrder.desc,
    int? limit,
    String? cursor,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/workspaces/[id]/recently-deleted',
    params: {'id': workspaceId},
    query: {
      'type': type.name,
      'search': ?search,
      'sortBy': sortBy.name,
      'sortOrder': sortOrder.name,
      'limit': ?limit,
      'cursor': ?cursor,
    },
    decode: RecentlyDeletedPage.fromJson,
    cancelToken: cancelToken,
  );
}
