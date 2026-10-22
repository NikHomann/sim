import 'package:dio/dio.dart';
import 'package:sim_api/src/client/api_client_error.dart';
import 'package:sim_api/src/client/sim_http_client.dart';
import 'package:sim_api/src/contracts/invitations.dart';
import 'package:sim_api/src/contracts/json.dart';
import 'package:sim_api/src/contracts/workspaces.dart';
import 'package:sim_api/src/repositories/contract_request.dart';

/// An invitation request that failed, with the error kind resolved the way
/// `codeFromApiClientError` does (`invite.tsx:256-274`): the body's `code`
/// when it is a known kind, else `body.error` when it is one, else by status
/// (401 `unauthorized`, 403 `forbidden`, 404 `invalid-invitation`, 409
/// `already-in-organization`, ≥500 `server-error`). Still an
/// [ApiClientError], so generic handling keeps working.
class InvitationError extends ApiClientError {
  InvitationError({
    required this.kind,
    required super.status,
    required super.message,
    super.body,
    super.rawBody,
    super.code,
    super.requestId,
    super.details,
    super.rateLimit,
  });

  factory InvitationError.from(ApiClientError error) => InvitationError(
    kind: kindOf(error),
    status: error.status,
    message: error.message,
    body: error.body,
    rawBody: error.rawBody,
    code: error.code,
    requestId: error.requestId,
    details: error.details,
    rateLimit: error.rateLimit,
  );

  final InvitationErrorCode kind;

  /// `codeFromApiClientError`.
  static InvitationErrorCode kindOf(ApiClientError error) {
    final fromCode = InvitationErrorCode.parse(error.code);
    if (fromCode != null) return fromCode;
    final body = error.body;
    if (body is Map) {
      final raw = body['error'];
      final fromBody = InvitationErrorCode.parse(raw is String ? raw : null);
      if (fromBody != null) return fromBody;
    }
    return InvitationErrorCode.fromStatus(error.status);
  }

  @override
  String toString() => 'InvitationError(${kind.wireName}, $status: $message)';
}

/// The invitation and membership contracts of `hooks/queries/invitations.ts`
/// (spec §4.4). The accept/reject/details calls rethrow as [InvitationError]
/// so the UI can branch on the kind.
class InvitationsRepository {
  InvitationsRepository(this._http);

  final SimHttpClient _http;

  Future<T> _invitationCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on InvitationError {
      rethrow;
    } on ApiClientError catch (error) {
      throw InvitationError.from(error);
    }
  }

  /// `GET /api/invitations/[id]?token=` → `{invitation, joinPreview}`.
  Future<InvitationDetailsResponse> details(
    String id, {
    String? token,
    CancelToken? cancelToken,
  }) => _invitationCall(
    () => _http.requestContract(
      method: 'GET',
      path: '/api/invitations/[id]',
      params: {'id': id},
      query: {'token': ?token},
      decode: InvitationDetailsResponse.fromJson,
      cancelToken: cancelToken,
    ),
  );

  /// `POST /api/invitations/[id]/accept` `{token?, disclosedWorkspaceIds?,
  /// disclosedOutcome?}`.
  Future<AcceptedInvitation> accept(
    String id, {
    String? token,
    List<String>? disclosedWorkspaceIds,
    JoinOutcome? disclosedOutcome,
    CancelToken? cancelToken,
  }) => _invitationCall(
    () => _http.requestContract(
      method: 'POST',
      path: '/api/invitations/[id]/accept',
      params: {'id': id},
      body: {
        'token': ?token,
        'disclosedWorkspaceIds': ?disclosedWorkspaceIds,
        'disclosedOutcome': ?disclosedOutcome?.wireName,
      },
      decode: AcceptedInvitation.fromJson,
      cancelToken: cancelToken,
    ),
  );

  /// `POST /api/invitations/[id]/reject` body `{}` (token optional).
  Future<void> reject(
    String id, {
    String? token,
    CancelToken? cancelToken,
  }) => _invitationCall(
    () => _http.requestContract(
      method: 'POST',
      path: '/api/invitations/[id]/reject',
      params: {'id': id},
      body: {'token': ?token},
      decode: (json) => json.boolean('success'),
      cancelToken: cancelToken,
    ),
  );

  /// `GET /api/invitations` → `{invitations}` (the viewer's pending ones).
  Future<List<InvitationDetails>> listMine({CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'GET',
        path: '/api/invitations',
        decode: (json) => json
            .objectList('invitations')
            .map(InvitationDetails.fromJson)
            .toList(),
        cancelToken: cancelToken,
      );

  /// `GET /api/workspaces/invitations` → every pending row the viewer
  /// administers; [listWorkspace] filters to one workspace like
  /// `fetchPendingInvitations`.
  Future<List<PendingWorkspaceInvitation>> listAllWorkspaceInvitations({
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'GET',
    path: '/api/workspaces/invitations',
    decode: (json) => json
        .objectList('invitations')
        .map(PendingWorkspaceInvitation.fromJson)
        .toList(),
    cancelToken: cancelToken,
  );

  Future<List<PendingWorkspaceInvitation>> listWorkspace(
    String workspaceId, {
    CancelToken? cancelToken,
  }) async {
    final rows = await listAllWorkspaceInvitations(cancelToken: cancelToken);
    return rows
        .where((row) => row.isPending && row.workspaceId == workspaceId)
        .toList();
  }

  /// `POST /api/workspaces/invitations/batch`. A 2xx with `failed[]` is a
  /// partial failure ([BatchInvitationResult.isPartialFailure]).
  Future<BatchInvitationResult> sendBatch({
    required List<String> workspaceIds,
    required List<String> emails,
    WorkspacePermission? permission,
    InvitationMembership? membership,
    String? organizationId,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'POST',
    path: '/api/workspaces/invitations/batch',
    body: {
      'workspaceIds': workspaceIds,
      'emails': emails.map((e) => e.trim()).toList(),
      'permission': ?permission?.name,
      'membership': ?membership?.name,
      'organizationId': ?organizationId,
    },
    decode: BatchInvitationResult.fromJson,
    cancelToken: cancelToken,
  );

  /// `DELETE /api/invitations/[id]?workspaceId=`.
  Future<CancelInvitationResult> cancel(
    String id, {
    String? workspaceId,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'DELETE',
    path: '/api/invitations/[id]',
    params: {'id': id},
    query: {'workspaceId': ?workspaceId},
    decode: CancelInvitationResult.fromJson,
    cancelToken: cancelToken,
  );

  /// `POST /api/invitations/[id]/resend` → `{success}`.
  Future<bool> resend(String id, {CancelToken? cancelToken}) =>
      _http.requestContract(
        method: 'POST',
        path: '/api/invitations/[id]/resend',
        params: {'id': id},
        decode: (json) => json.boolean('success'),
        cancelToken: cancelToken,
      );

  /// `DELETE /api/workspaces/members/[id]` body `{workspaceId}` → `{success}`.
  /// Leaving a workspace is the same call with the viewer's own id.
  Future<bool> removeMember({
    required String userId,
    required String workspaceId,
    CancelToken? cancelToken,
  }) => _http.requestContract(
    method: 'DELETE',
    path: '/api/workspaces/members/[id]',
    params: {'id': userId},
    body: {'workspaceId': workspaceId},
    decode: (json) => json.boolean('success'),
    cancelToken: cancelToken,
  );
}
