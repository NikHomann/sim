/// Wire shapes of `apps/sim/lib/api/contracts/invitations.ts`
/// (`generated/contracts/invitations.schema.json`) and the error-kind map of
/// `app/api/invitations/[id]/{accept,reject}/route.ts`.
library;

import 'package:sim_api/src/contracts/json.dart';
import 'package:sim_api/src/contracts/workspaces.dart';

/// `kind` of an invitation.
enum InvitationKind { organization, workspace }

/// `membershipIntent` of an invitation.
enum MembershipIntent { internal, external }

/// `outcome` of a join preview.
enum JoinOutcome implements WireNamed {
  willJoin('will-join'),
  alreadyMember('already-member'),
  external('external'),
  blocked('blocked')
  ;

  const JoinOutcome(this.wireName);

  @override
  final String wireName;
}

/// `membership` of a batch invitation.
enum InvitationMembership { member, admin, external }

/// Invitation error kinds (`invite.tsx:147-254`, `error-messages.ts`).
/// [fromStatus] is `codeFromStatus`, [parse] is `codeFromApiClientError`.
enum InvitationErrorCode implements WireNamed {
  notFound('not-found'),
  workspaceNotFound('workspace-not-found'),
  disclosureOutdated('disclosure-outdated'),
  invalidToken('invalid-token'),
  alreadyProcessed('already-processed'),
  expired('expired'),
  emailMismatch('email-mismatch'),
  alreadyInOrganization('already-in-organization'),
  noSeatsAvailable('no-seats-available'),
  upgradeRequired('upgrade-required'),
  externalRequiresPaidPlan('external-requires-paid-plan'),
  userNotFound('user-not-found'),
  unauthorized('unauthorized'),
  forbidden('forbidden'),
  invalidInvitation('invalid-invitation'),
  serverError('server-error'),
  networkError('network-error'),
  unknown('unknown')
  ;

  const InvitationErrorCode(this.wireName);

  @override
  final String wireName;

  /// The known code spelled [raw], or `null`.
  static InvitationErrorCode? parse(String? raw) {
    if (raw == null) return null;
    for (final code in values) {
      if (code != unknown && code.wireName == raw) return code;
    }
    return null;
  }

  /// `codeFromStatus` (`invite.tsx:256-263`).
  static InvitationErrorCode fromStatus(int status) => switch (status) {
    401 => unauthorized,
    403 => forbidden,
    404 => invalidInvitation,
    409 => alreadyInOrganization,
    >= 500 => serverError,
    _ => unknown,
  };

  /// The page requires a different account (`requiresAuth`).
  bool get requiresAuth => switch (this) {
    emailMismatch || userNotFound || unauthorized || forbidden => true,
    _ => false,
  };

  /// The page offers a retry (`canRetry`).
  bool get canRetry => switch (this) {
    disclosureOutdated ||
    noSeatsAvailable ||
    upgradeRequired ||
    externalRequiresPaidPlan ||
    serverError ||
    networkError => true,
    _ => false,
  };
}

/// One `grants[]` entry.
class InvitationGrant extends ContractValue {
  const InvitationGrant({
    required this.workspaceId,
    required this.workspaceName,
    required this.permission,
    this.workspaceLogoUrl,
  });

  factory InvitationGrant.fromJson(JsonObject json) => InvitationGrant(
    workspaceId: json.string('workspaceId'),
    workspaceName: json.stringOrNull('workspaceName'),
    workspaceLogoUrl: json.stringOrNull('workspaceLogoUrl'),
    permission: json.enumValue('permission', WorkspacePermission.values),
  );

  final String workspaceId;
  final String? workspaceName;
  final String? workspaceLogoUrl;
  final WorkspacePermission permission;

  @override
  List<Object?> get props => [
    workspaceId,
    workspaceName,
    workspaceLogoUrl,
    permission,
  ];

  @override
  JsonObject toJson() => {
    'workspaceId': workspaceId,
    'workspaceName': workspaceName,
    'workspaceLogoUrl': workspaceLogoUrl,
    'permission': permission.name,
  };
}

/// `invitationJoinPreviewSchema` (`invitations.ts:267-280`).
class InvitationJoinPreview extends ContractValue {
  const InvitationJoinPreview({
    required this.outcome,
    required this.organizationName,
    required this.workspacesToMove,
    required this.workspaceIdsToMove,
  });

  factory InvitationJoinPreview.fromJson(JsonObject json) =>
      InvitationJoinPreview(
        outcome: json.enumValue('outcome', JoinOutcome.values),
        organizationName: json.stringOrNull('organizationName'),
        workspacesToMove: json.stringList('workspacesToMove'),
        workspaceIdsToMove: json.stringList('workspaceIdsToMove'),
      );

  final JoinOutcome outcome;
  final String? organizationName;
  final List<String> workspacesToMove;
  final List<String> workspaceIdsToMove;

  @override
  List<Object?> get props => [
    outcome,
    organizationName,
    workspacesToMove,
    workspaceIdsToMove,
  ];

  @override
  JsonObject toJson() => {
    'outcome': outcome.wireName,
    'organizationName': organizationName,
    'workspacesToMove': workspacesToMove,
    'workspaceIdsToMove': workspaceIdsToMove,
  };
}

/// `invitationDetailsSchema` (`invitations.ts:180-216`). With [joinPreview]
/// set it is a `MyInvitation` row of `GET /api/invitations`.
class InvitationDetails extends ContractValue {
  const InvitationDetails({
    required this.id,
    required this.kind,
    required this.email,
    required this.organizationId,
    required this.organizationName,
    required this.membershipIntent,
    required this.role,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    required this.inviterName,
    required this.inviterEmail,
    required this.grants,
    this.joinPreview,
  });

  factory InvitationDetails.fromJson(JsonObject json) => InvitationDetails(
    id: json.string('id'),
    kind: json.enumValue('kind', InvitationKind.values),
    email: json.string('email'),
    organizationId: json.stringOrNull('organizationId'),
    organizationName: json.stringOrNull('organizationName'),
    membershipIntent: json.enumValue(
      'membershipIntent',
      MembershipIntent.values,
    ),
    role: json.string('role'),
    status: json.string('status'),
    expiresAt: json.string('expiresAt'),
    createdAt: json.string('createdAt'),
    inviterName: json.stringOrNull('inviterName'),
    inviterEmail: json.stringOrNull('inviterEmail'),
    grants: json.objectList('grants').map(InvitationGrant.fromJson).toList(),
    joinPreview: switch (json.objectOrNull('joinPreview')) {
      final preview? => InvitationJoinPreview.fromJson(preview),
      null => null,
    },
  );

  final String id;
  final InvitationKind kind;
  final String email;
  final String? organizationId;
  final String? organizationName;
  final MembershipIntent membershipIntent;
  final String role;
  final String status;
  final String expiresAt;
  final String createdAt;
  final String? inviterName;
  final String? inviterEmail;
  final List<InvitationGrant> grants;
  final InvitationJoinPreview? joinPreview;

  @override
  List<Object?> get props => [
    id,
    kind,
    email,
    organizationId,
    organizationName,
    membershipIntent,
    role,
    status,
    expiresAt,
    createdAt,
    inviterName,
    inviterEmail,
    grants,
    joinPreview,
  ];

  @override
  JsonObject toJson() => {
    'id': id,
    'kind': kind.name,
    'email': email,
    'organizationId': organizationId,
    'organizationName': organizationName,
    'membershipIntent': membershipIntent.name,
    'role': role,
    'status': status,
    'expiresAt': expiresAt,
    'createdAt': createdAt,
    'inviterName': inviterName,
    'inviterEmail': inviterEmail,
    'grants': grants.map((g) => g.toJson()).toList(),
    'joinPreview': joinPreview?.toJson(),
  };
}

/// `GET /api/invitations/[id]?token=` → `{invitation, joinPreview}`.
class InvitationDetailsResponse extends ContractValue {
  const InvitationDetailsResponse({
    required this.invitation,
    required this.joinPreview,
  });

  factory InvitationDetailsResponse.fromJson(JsonObject json) =>
      InvitationDetailsResponse(
        invitation: InvitationDetails.fromJson(json.object('invitation')),
        joinPreview: switch (json.objectOrNull('joinPreview')) {
          final preview? => InvitationJoinPreview.fromJson(preview),
          null => null,
        },
      );

  final InvitationDetails invitation;
  final InvitationJoinPreview? joinPreview;

  @override
  List<Object?> get props => [invitation, joinPreview];

  @override
  JsonObject toJson() => {
    'invitation': invitation.toJson(),
    'joinPreview': joinPreview?.toJson(),
  };
}

/// `POST /api/invitations/[id]/accept` response.
class AcceptedInvitation extends ContractValue {
  const AcceptedInvitation({
    required this.redirectPath,
    required this.id,
    required this.kind,
    required this.organizationId,
    required this.acceptedWorkspaceIds,
  });

  factory AcceptedInvitation.fromJson(JsonObject json) {
    final invitation = json.object('invitation');
    return AcceptedInvitation(
      redirectPath: json.string('redirectPath'),
      id: invitation.string('id'),
      kind: invitation.enumValue('kind', InvitationKind.values),
      organizationId: invitation.stringOrNull('organizationId'),
      acceptedWorkspaceIds: invitation.stringList('acceptedWorkspaceIds'),
    );
  }

  final String redirectPath;
  final String id;
  final InvitationKind kind;
  final String? organizationId;
  final List<String> acceptedWorkspaceIds;

  @override
  List<Object?> get props => [
    redirectPath,
    id,
    kind,
    organizationId,
    acceptedWorkspaceIds,
  ];

  @override
  JsonObject toJson() => {
    'success': true,
    'redirectPath': redirectPath,
    'invitation': {
      'id': id,
      'kind': kind.name,
      'organizationId': organizationId,
      'acceptedWorkspaceIds': acceptedWorkspaceIds,
    },
  };
}

/// One row of `GET /api/workspaces/invitations` (`pendingWorkspaceInvitationSchema`,
/// passthrough: unknown fields are kept in [extra]).
class PendingWorkspaceInvitation extends ContractValue {
  const PendingWorkspaceInvitation({
    required this.id,
    required this.workspaceId,
    required this.email,
    required this.permission,
    required this.status,
    required this.createdAt,
    this.token,
    this.membershipIntent,
    this.extra = const {},
  });

  factory PendingWorkspaceInvitation.fromJson(JsonObject json) =>
      PendingWorkspaceInvitation(
        id: json.string('id'),
        workspaceId: json.string('workspaceId'),
        email: json.string('email'),
        token: json.stringOrNull('token'),
        permission: json.enumValue('permission', WorkspacePermission.values),
        membershipIntent: json.enumOrNull(
          'membershipIntent',
          MembershipIntent.values,
        ),
        status: json.string('status'),
        createdAt: json.string('createdAt'),
        extra: {
          for (final entry in json.entries)
            if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
        },
      );

  static const _knownKeys = {
    'id',
    'workspaceId',
    'email',
    'token',
    'permission',
    'membershipIntent',
    'status',
    'createdAt',
  };

  final String id;
  final String workspaceId;
  final String email;
  final String? token;
  final WorkspacePermission permission;
  final MembershipIntent? membershipIntent;
  final String status;
  final String createdAt;
  final JsonObject extra;

  bool get isPending => status == 'pending';
  bool get isExternal => membershipIntent == MembershipIntent.external;

  @override
  List<Object?> get props => [
    id,
    workspaceId,
    email,
    token,
    permission,
    membershipIntent,
    status,
    createdAt,
    extra,
  ];

  @override
  JsonObject toJson() => {
    ...extra,
    'id': id,
    'workspaceId': workspaceId,
    'email': email,
    'token': ?token,
    'permission': permission.name,
    'membershipIntent': ?membershipIntent?.name,
    'status': status,
    'createdAt': createdAt,
  };
}

/// One `failed[]` entry of a batch send.
class BatchInvitationFailure extends ContractValue {
  const BatchInvitationFailure({required this.email, required this.error});

  factory BatchInvitationFailure.fromJson(JsonObject json) =>
      BatchInvitationFailure(
        email: json.string('email'),
        error: json.string('error'),
      );

  final String email;
  final String error;

  @override
  List<Object?> get props => [email, error];

  @override
  JsonObject toJson() => {'email': email, 'error': error};
}

/// One `invitations[]` entry of a batch send.
class BatchInvitationRow extends ContractValue {
  const BatchInvitationRow({
    required this.id,
    required this.email,
    required this.workspaceIds,
    required this.permission,
    required this.membershipIntent,
    this.instantAdd,
    this.outcome,
  });

  factory BatchInvitationRow.fromJson(JsonObject json) => BatchInvitationRow(
    id: json.string('id'),
    email: json.string('email'),
    workspaceIds: json.stringList('workspaceIds'),
    permission: json.enumValue('permission', WorkspacePermission.values),
    membershipIntent: json.enumValue(
      'membershipIntent',
      MembershipIntent.values,
    ),
    instantAdd: json.boolOrNull('instantAdd'),
    outcome: json.stringOrNull('outcome'),
  );

  final String id;
  final String email;
  final List<String> workspaceIds;
  final WorkspacePermission permission;
  final MembershipIntent membershipIntent;
  final bool? instantAdd;

  /// `'added' | 'updated' | 'unchanged'`.
  final String? outcome;

  @override
  List<Object?> get props => [
    id,
    email,
    workspaceIds,
    permission,
    membershipIntent,
    instantAdd,
    outcome,
  ];

  @override
  JsonObject toJson() => {
    'id': id,
    'email': email,
    'workspaceIds': workspaceIds,
    'permission': permission.name,
    'membershipIntent': membershipIntent.name,
    'instantAdd': ?instantAdd,
    'outcome': ?outcome,
  };
}

/// `POST /api/workspaces/invitations/batch` response
/// (`invitations.ts:87-136`). A 2xx with [failed] entries is a partial
/// failure.
class BatchInvitationResult extends ContractValue {
  const BatchInvitationResult({
    required this.success,
    required this.successful,
    required this.added,
    required this.failed,
    required this.invitations,
  });

  factory BatchInvitationResult.fromJson(JsonObject json) =>
      BatchInvitationResult(
        success: json.boolean('success'),
        successful: json.stringList('successful'),
        added: json.stringList('added'),
        failed: json
            .objectList('failed')
            .map(BatchInvitationFailure.fromJson)
            .toList(),
        invitations: json
            .objectList('invitations')
            .map(BatchInvitationRow.fromJson)
            .toList(),
      );

  final bool success;
  final List<String> successful;
  final List<String> added;
  final List<BatchInvitationFailure> failed;
  final List<BatchInvitationRow> invitations;

  bool get isPartialFailure => failed.isNotEmpty;

  @override
  List<Object?> get props => [success, successful, added, failed, invitations];

  @override
  JsonObject toJson() => {
    'success': success,
    'successful': successful,
    'added': added,
    'failed': failed.map((f) => f.toJson()).toList(),
    'invitations': invitations.map((i) => i.toJson()).toList(),
  };
}

/// `DELETE /api/invitations/[id]` → `{success, invitationCancelled}`.
class CancelInvitationResult extends ContractValue {
  const CancelInvitationResult({
    required this.success,
    required this.invitationCancelled,
  });

  factory CancelInvitationResult.fromJson(JsonObject json) =>
      CancelInvitationResult(
        success: json.boolean('success'),
        invitationCancelled: json.boolean('invitationCancelled'),
      );

  final bool success;
  final bool invitationCancelled;

  @override
  List<Object?> get props => [success, invitationCancelled];

  @override
  JsonObject toJson() => {
    'success': success,
    'invitationCancelled': invitationCancelled,
  };
}
