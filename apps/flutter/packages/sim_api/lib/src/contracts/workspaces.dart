/// Wire shapes of `apps/sim/lib/api/contracts/workspaces.ts` used in Phase 1
/// (`generated/contracts/workspaces.schema.json`).
library;

import 'package:sim_api/src/contracts/json.dart';

/// `workspaceMode` of a workspace row.
enum WorkspaceMode implements WireNamed {
  personal('personal'),
  organization('organization'),
  grandfatheredShared('grandfathered_shared')
  ;

  const WorkspaceMode(this.wireName);

  @override
  final String wireName;
}

/// A viewer's permission on a workspace.
enum WorkspacePermission { admin, write, read }

/// `scope` of `GET /api/workspaces` and `GET /api/workflows`.
enum ListScope { active, archived, all }

/// `blockedReasonCode` of a creation policy.
enum CreationBlockedReason implements WireNamed {
  organizationSubscriptionInactive('organization-subscription-inactive'),
  permissionGroupDenied('permission-group-denied')
  ;

  const CreationBlockedReason(this.wireName);

  @override
  final String wireName;
}

/// `workspaceSchema` (`workspaces.ts:24-62`), normalised the way
/// `normalizeWorkspace` does: the invite fields default when absent.
class Workspace extends ContractValue {
  const Workspace({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.organizationId,
    required this.workspaceMode,
    this.color,
    this.logoUrl,
    this.role,
    this.membershipId,
    this.permissions,
    this.isOrgAdmin,
    this.billedAccountUserId,
    this.allowPersonalApiKeys,
    this.storageUsedBytes,
    this.inboxEnabled,
    this.inboxAddress,
    this.inboxProviderId,
    this.inboxSecretScope,
    this.inboxMountedSecrets,
    this.archivedAt,
    this.organizationAssignedAt,
    this.forkSyncNewWorkflowsExcluded,
    this.createdAt,
    this.updatedAt,
    this.inviteMembersEnabled = false,
    this.inviteDisabledReason,
    this.inviteUpgradeRequired = false,
    this.forkedFromWorkspaceId,
  });

  factory Workspace.fromJson(JsonObject json) => Workspace(
    id: json.string('id'),
    name: json.string('name'),
    color: json.stringOrNull('color'),
    logoUrl: json.stringOrNull('logoUrl'),
    ownerId: json.string('ownerId'),
    organizationId: json.stringOrNull('organizationId'),
    workspaceMode: json.enumValue('workspaceMode', WorkspaceMode.values),
    role: json.stringOrNull('role'),
    membershipId: json.stringOrNull('membershipId'),
    permissions: json.enumOrNull('permissions', WorkspacePermission.values),
    isOrgAdmin: json.boolOrNull('isOrgAdmin'),
    billedAccountUserId: json.stringOrNull('billedAccountUserId'),
    allowPersonalApiKeys: json.boolOrNull('allowPersonalApiKeys'),
    storageUsedBytes: json.numOrNull('storageUsedBytes'),
    inboxEnabled: json.boolOrNull('inboxEnabled'),
    inboxAddress: json.stringOrNull('inboxAddress'),
    inboxProviderId: json.stringOrNull('inboxProviderId'),
    inboxSecretScope: json.stringOrNull('inboxSecretScope'),
    inboxMountedSecrets: json.stringListOrNull('inboxMountedSecrets'),
    archivedAt: json.dateOrNull('archivedAt'),
    organizationAssignedAt: json.dateOrNull('organizationAssignedAt'),
    forkSyncNewWorkflowsExcluded: json.boolOrNull(
      'forkSyncNewWorkflowsExcluded',
    ),
    createdAt: json.dateOrNull('createdAt'),
    updatedAt: json.dateOrNull('updatedAt'),
    inviteMembersEnabled: json.boolOr('inviteMembersEnabled', fallback: false),
    inviteDisabledReason: json.stringOrNull('inviteDisabledReason'),
    inviteUpgradeRequired: json.boolOr(
      'inviteUpgradeRequired',
      fallback: false,
    ),
    forkedFromWorkspaceId: json.stringOrNull('forkedFromWorkspaceId'),
  );

  final String id;
  final String name;
  final String? color;
  final String? logoUrl;
  final String ownerId;
  final String? organizationId;
  final WorkspaceMode workspaceMode;
  final String? role;
  final String? membershipId;
  final WorkspacePermission? permissions;
  final bool? isOrgAdmin;
  final String? billedAccountUserId;
  final bool? allowPersonalApiKeys;
  final num? storageUsedBytes;
  final bool? inboxEnabled;
  final String? inboxAddress;
  final String? inboxProviderId;
  final String? inboxSecretScope;
  final List<String>? inboxMountedSecrets;
  final DateTime? archivedAt;
  final DateTime? organizationAssignedAt;
  final bool? forkSyncNewWorkflowsExcluded;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool inviteMembersEnabled;
  final String? inviteDisabledReason;
  final bool inviteUpgradeRequired;
  final String? forkedFromWorkspaceId;

  Workspace copyWith({String? name, String? logoUrl, bool clearLogo = false}) =>
      Workspace(
        id: id,
        name: name ?? this.name,
        color: color,
        logoUrl: clearLogo ? null : (logoUrl ?? this.logoUrl),
        ownerId: ownerId,
        organizationId: organizationId,
        workspaceMode: workspaceMode,
        role: role,
        membershipId: membershipId,
        permissions: permissions,
        isOrgAdmin: isOrgAdmin,
        billedAccountUserId: billedAccountUserId,
        allowPersonalApiKeys: allowPersonalApiKeys,
        storageUsedBytes: storageUsedBytes,
        inboxEnabled: inboxEnabled,
        inboxAddress: inboxAddress,
        inboxProviderId: inboxProviderId,
        inboxSecretScope: inboxSecretScope,
        inboxMountedSecrets: inboxMountedSecrets,
        archivedAt: archivedAt,
        organizationAssignedAt: organizationAssignedAt,
        forkSyncNewWorkflowsExcluded: forkSyncNewWorkflowsExcluded,
        createdAt: createdAt,
        updatedAt: updatedAt,
        inviteMembersEnabled: inviteMembersEnabled,
        inviteDisabledReason: inviteDisabledReason,
        inviteUpgradeRequired: inviteUpgradeRequired,
        forkedFromWorkspaceId: forkedFromWorkspaceId,
      );

  @override
  List<Object?> get props => [
    id,
    name,
    color,
    logoUrl,
    ownerId,
    organizationId,
    workspaceMode,
    role,
    membershipId,
    permissions,
    isOrgAdmin,
    billedAccountUserId,
    allowPersonalApiKeys,
    storageUsedBytes,
    inboxEnabled,
    inboxAddress,
    inboxProviderId,
    inboxSecretScope,
    inboxMountedSecrets,
    archivedAt,
    organizationAssignedAt,
    forkSyncNewWorkflowsExcluded,
    createdAt,
    updatedAt,
    inviteMembersEnabled,
    inviteDisabledReason,
    inviteUpgradeRequired,
    forkedFromWorkspaceId,
  ];

  @override
  JsonObject toJson() => {
    'id': id,
    'name': name,
    'color': ?color,
    'logoUrl': logoUrl,
    'ownerId': ownerId,
    'organizationId': organizationId,
    'workspaceMode': workspaceMode.wireName,
    'role': ?role,
    'membershipId': ?membershipId,
    'permissions': permissions?.name,
    'isOrgAdmin': ?isOrgAdmin,
    'billedAccountUserId': billedAccountUserId,
    'allowPersonalApiKeys': ?allowPersonalApiKeys,
    'storageUsedBytes': ?storageUsedBytes,
    'inboxEnabled': ?inboxEnabled,
    'inboxAddress': inboxAddress,
    'inboxProviderId': inboxProviderId,
    'inboxSecretScope': ?inboxSecretScope,
    'inboxMountedSecrets': ?inboxMountedSecrets,
    'archivedAt': archivedAt?.toIso8601String(),
    'organizationAssignedAt': organizationAssignedAt?.toIso8601String(),
    'forkSyncNewWorkflowsExcluded': ?forkSyncNewWorkflowsExcluded,
    'createdAt': ?createdAt?.toIso8601String(),
    'updatedAt': ?updatedAt?.toIso8601String(),
    'inviteMembersEnabled': inviteMembersEnabled,
    'inviteDisabledReason': inviteDisabledReason,
    'inviteUpgradeRequired': inviteUpgradeRequired,
    'forkedFromWorkspaceId': forkedFromWorkspaceId,
  };
}

/// `workspaceCreationPolicySchema` (`workspaces.ts:66-80`).
class WorkspaceCreationPolicy extends ContractValue {
  const WorkspaceCreationPolicy({
    required this.canCreate,
    required this.workspaceMode,
    required this.organizationId,
    required this.maxWorkspaces,
    required this.currentWorkspaceCount,
    required this.reason,
    this.blockedReasonCode,
  });

  factory WorkspaceCreationPolicy.fromJson(JsonObject json) =>
      WorkspaceCreationPolicy(
        canCreate: json.boolean('canCreate'),
        workspaceMode: json.enumValue('workspaceMode', WorkspaceMode.values),
        organizationId: json.stringOrNull('organizationId'),
        maxWorkspaces: json.numOrNull('maxWorkspaces'),
        currentWorkspaceCount: json.number('currentWorkspaceCount'),
        reason: json.stringOrNull('reason'),
        blockedReasonCode: json.enumOrNull(
          'blockedReasonCode',
          CreationBlockedReason.values,
        ),
      );

  final bool canCreate;
  final WorkspaceMode workspaceMode;
  final String? organizationId;
  final num? maxWorkspaces;
  final num currentWorkspaceCount;
  final String? reason;
  final CreationBlockedReason? blockedReasonCode;

  @override
  List<Object?> get props => [
    canCreate,
    workspaceMode,
    organizationId,
    maxWorkspaces,
    currentWorkspaceCount,
    reason,
    blockedReasonCode,
  ];

  @override
  JsonObject toJson() => {
    'canCreate': canCreate,
    'workspaceMode': workspaceMode.wireName,
    'organizationId': organizationId,
    'maxWorkspaces': maxWorkspaces,
    'currentWorkspaceCount': currentWorkspaceCount,
    'reason': reason,
    'blockedReasonCode': ?blockedReasonCode?.wireName,
  };
}

/// `GET /api/workspaces` → `{workspaces, lastActiveWorkspaceId,
/// pinnedWorkspaceIds, creationPolicy}` (`workspaces.ts:183-204`).
class WorkspaceList extends ContractValue {
  const WorkspaceList({
    required this.workspaces,
    required this.lastActiveWorkspaceId,
    this.pinnedWorkspaceIds = const [],
    this.creationPolicy,
  });

  factory WorkspaceList.fromJson(JsonObject json) => WorkspaceList(
    workspaces: json.objectList('workspaces').map(Workspace.fromJson).toList(),
    lastActiveWorkspaceId: json.stringOrNull('lastActiveWorkspaceId'),
    pinnedWorkspaceIds: json.stringListOrNull('pinnedWorkspaceIds') ?? const [],
    creationPolicy: switch (json.objectOrNull('creationPolicy')) {
      final policy? => WorkspaceCreationPolicy.fromJson(policy),
      null => null,
    },
  );

  final List<Workspace> workspaces;
  final String? lastActiveWorkspaceId;
  final List<String> pinnedWorkspaceIds;
  final WorkspaceCreationPolicy? creationPolicy;

  WorkspaceList copyWith({
    List<Workspace>? workspaces,
    String? lastActiveWorkspaceId,
    List<String>? pinnedWorkspaceIds,
  }) => WorkspaceList(
    workspaces: workspaces ?? this.workspaces,
    lastActiveWorkspaceId: lastActiveWorkspaceId ?? this.lastActiveWorkspaceId,
    pinnedWorkspaceIds: pinnedWorkspaceIds ?? this.pinnedWorkspaceIds,
    creationPolicy: creationPolicy,
  );

  @override
  List<Object?> get props => [
    workspaces,
    lastActiveWorkspaceId,
    pinnedWorkspaceIds,
    creationPolicy,
  ];

  @override
  JsonObject toJson() => {
    'workspaces': workspaces.map((w) => w.toJson()).toList(),
    'lastActiveWorkspaceId': lastActiveWorkspaceId,
    'pinnedWorkspaceIds': pinnedWorkspaceIds,
    'creationPolicy': creationPolicy?.toJson(),
  };
}

/// `deploymentFeaturesSchema` (`workspaces.ts:267-284`).
class DeploymentFeatures extends ContractValue {
  const DeploymentFeatures({
    this.accessControl = false,
    this.auditLogs = false,
    this.customBlocks = false,
    this.dataDrains = false,
    this.dataRetention = false,
    this.inbox = false,
    this.sandboxes = false,
    this.scim = false,
    this.sessionPolicies = false,
    this.sso = false,
    this.usageMonitoring = false,
    this.whitelabeling = false,
  });

  factory DeploymentFeatures.fromJson(JsonObject json) => DeploymentFeatures(
    accessControl: json.boolean('accessControl'),
    auditLogs: json.boolean('auditLogs'),
    customBlocks: json.boolean('customBlocks'),
    dataDrains: json.boolean('dataDrains'),
    dataRetention: json.boolean('dataRetention'),
    inbox: json.boolean('inbox'),
    sandboxes: json.boolean('sandboxes'),
    scim: json.boolean('scim'),
    sessionPolicies: json.boolean('sessionPolicies'),
    sso: json.boolean('sso'),
    usageMonitoring: json.boolean('usageMonitoring'),
    whitelabeling: json.boolean('whitelabeling'),
  );

  final bool accessControl;
  final bool auditLogs;
  final bool customBlocks;
  final bool dataDrains;
  final bool dataRetention;
  final bool inbox;
  final bool sandboxes;
  final bool scim;
  final bool sessionPolicies;
  final bool sso;
  final bool usageMonitoring;
  final bool whitelabeling;

  @override
  List<Object?> get props => [
    accessControl,
    auditLogs,
    customBlocks,
    dataDrains,
    dataRetention,
    inbox,
    sandboxes,
    scim,
    sessionPolicies,
    sso,
    usageMonitoring,
    whitelabeling,
  ];

  @override
  JsonObject toJson() => {
    'accessControl': accessControl,
    'auditLogs': auditLogs,
    'customBlocks': customBlocks,
    'dataDrains': dataDrains,
    'dataRetention': dataRetention,
    'inbox': inbox,
    'sandboxes': sandboxes,
    'scim': scim,
    'sessionPolicies': sessionPolicies,
    'sso': sso,
    'usageMonitoring': usageMonitoring,
    'whitelabeling': whitelabeling,
  };
}

/// `deploymentShapeSchema` (`workspaces.ts:286-298`). The defaults are the
/// "nothing configured" shape: every flag `false` except `chatEnabled`.
class DeploymentShape extends ContractValue {
  const DeploymentShape({
    this.hosted = false,
    this.billingEnabled = false,
    this.chatEnabled = true,
    this.azureConfigured = false,
    this.cohereConfigured = false,
    this.features = const DeploymentFeatures(),
  });

  factory DeploymentShape.fromJson(JsonObject json) => DeploymentShape(
    hosted: json.boolean('hosted'),
    billingEnabled: json.boolean('billingEnabled'),
    chatEnabled: json.boolean('chatEnabled'),
    azureConfigured: json.boolean('azureConfigured'),
    cohereConfigured: json.boolean('cohereConfigured'),
    features: DeploymentFeatures.fromJson(json.object('features')),
  );

  final bool hosted;
  final bool billingEnabled;
  final bool chatEnabled;
  final bool azureConfigured;
  final bool cohereConfigured;
  final DeploymentFeatures features;

  @override
  List<Object?> get props => [
    hosted,
    billingEnabled,
    chatEnabled,
    azureConfigured,
    cohereConfigured,
    features,
  ];

  @override
  JsonObject toJson() => {
    'hosted': hosted,
    'billingEnabled': billingEnabled,
    'chatEnabled': chatEnabled,
    'azureConfigured': azureConfigured,
    'cohereConfigured': cohereConfigured,
    'features': features.toJson(),
  };
}

/// `workspaceFeatureFlagsSchema` (`workspaces.ts:350-358`); the organization
/// surface adds `mothership-memory-spaces`. [flag] is `flags[name] ?? false`
/// like `useFeatureFlag`.
class WorkspaceFeatureFlags extends ContractValue {
  const WorkspaceFeatureFlags({
    this.dashboards = false,
    this.workflowTests = false,
    this.changelog = false,
    this.mothershipModelSelector = false,
    this.mothershipComputerUse = false,
    this.mothershipPlanMode = false,
    this.projects = false,
    this.mothershipMemorySpaces,
  });

  factory WorkspaceFeatureFlags.fromJson(JsonObject json) =>
      WorkspaceFeatureFlags(
        dashboards: json.boolean('dashboards'),
        workflowTests: json.boolean('workflow-tests'),
        changelog: json.boolean('changelog'),
        mothershipModelSelector: json.boolean('mothership-model-selector'),
        mothershipComputerUse: json.boolean('mothership-computer-use'),
        mothershipPlanMode: json.boolean('mothership-plan-mode'),
        projects: json.boolean('projects'),
        mothershipMemorySpaces: json.boolOrNull('mothership-memory-spaces'),
      );

  final bool dashboards;
  final bool workflowTests;
  final bool changelog;
  final bool mothershipModelSelector;
  final bool mothershipComputerUse;
  final bool mothershipPlanMode;
  final bool projects;
  final bool? mothershipMemorySpaces;

  /// `flags[name] ?? false` by wire name.
  bool flag(String name) => switch (name) {
    'dashboards' => dashboards,
    'workflow-tests' => workflowTests,
    'changelog' => changelog,
    'mothership-model-selector' => mothershipModelSelector,
    'mothership-computer-use' => mothershipComputerUse,
    'mothership-plan-mode' => mothershipPlanMode,
    'projects' => projects,
    'mothership-memory-spaces' => mothershipMemorySpaces ?? false,
    _ => false,
  };

  @override
  List<Object?> get props => [
    dashboards,
    workflowTests,
    changelog,
    mothershipModelSelector,
    mothershipComputerUse,
    mothershipPlanMode,
    projects,
    mothershipMemorySpaces,
  ];

  @override
  JsonObject toJson() => {
    'dashboards': dashboards,
    'workflow-tests': workflowTests,
    'changelog': changelog,
    'mothership-model-selector': mothershipModelSelector,
    'mothership-computer-use': mothershipComputerUse,
    'mothership-plan-mode': mothershipPlanMode,
    'projects': projects,
    'mothership-memory-spaces': ?mothershipMemorySpaces,
  };
}

/// `desktopExecutor` of the feature-flags response.
class DesktopExecutorStatus extends ContractValue {
  const DesktopExecutorStatus({
    this.available = false,
    this.registered = false,
  });

  factory DesktopExecutorStatus.fromJson(JsonObject json) =>
      DesktopExecutorStatus(
        available: json.boolean('available'),
        registered: json.boolean('registered'),
      );

  final bool available;
  final bool registered;

  @override
  List<Object?> get props => [available, registered];

  @override
  JsonObject toJson() => {'available': available, 'registered': registered};
}

/// `GET /api/workspaces/[id]/feature-flags` (`workspaces.ts:360-376`).
class WorkspaceFeatureFlagsResponse extends ContractValue {
  const WorkspaceFeatureFlagsResponse({
    required this.flags,
    required this.desktopExecutor,
  });

  factory WorkspaceFeatureFlagsResponse.fromJson(JsonObject json) =>
      WorkspaceFeatureFlagsResponse(
        flags: WorkspaceFeatureFlags.fromJson(json.object('flags')),
        desktopExecutor: DesktopExecutorStatus.fromJson(
          json.object('desktopExecutor'),
        ),
      );

  final WorkspaceFeatureFlags flags;
  final DesktopExecutorStatus desktopExecutor;

  @override
  List<Object?> get props => [flags, desktopExecutor];

  @override
  JsonObject toJson() => {
    'flags': flags.toJson(),
    'desktopExecutor': desktopExecutor.toJson(),
  };
}

/// `workspace` of the host context.
class HostWorkspace extends ContractValue {
  const HostWorkspace({
    required this.id,
    required this.name,
    required this.workspaceMode,
    required this.billedAccountUserId,
    this.allowPersonalApiKeys,
  });

  factory HostWorkspace.fromJson(JsonObject json) => HostWorkspace(
    id: json.string('id'),
    name: json.string('name'),
    workspaceMode: json.enumValue('workspaceMode', WorkspaceMode.values),
    billedAccountUserId: json.string('billedAccountUserId'),
    allowPersonalApiKeys: json.boolOrNull('allowPersonalApiKeys'),
  );

  final String id;
  final String name;
  final WorkspaceMode workspaceMode;
  final String billedAccountUserId;
  final bool? allowPersonalApiKeys;

  @override
  List<Object?> get props => [
    id,
    name,
    workspaceMode,
    billedAccountUserId,
    allowPersonalApiKeys,
  ];

  @override
  JsonObject toJson() => {
    'id': id,
    'name': name,
    'workspaceMode': workspaceMode.wireName,
    'billedAccountUserId': billedAccountUserId,
    'allowPersonalApiKeys': ?allowPersonalApiKeys,
  };
}

/// `ownerBilling` of the host context.
class OwnerBilling extends ContractValue {
  const OwnerBilling({
    required this.plan,
    required this.status,
    required this.isPaid,
    required this.isPro,
    required this.isTeam,
    required this.isEnterprise,
    required this.isOrgScoped,
    required this.organizationId,
    required this.billingInterval,
    required this.billingBlocked,
    required this.billingBlockedReason,
  });

  factory OwnerBilling.fromJson(JsonObject json) => OwnerBilling(
    plan: json.string('plan'),
    status: json.stringOrNull('status'),
    isPaid: json.boolean('isPaid'),
    isPro: json.boolean('isPro'),
    isTeam: json.boolean('isTeam'),
    isEnterprise: json.boolean('isEnterprise'),
    isOrgScoped: json.boolean('isOrgScoped'),
    organizationId: json.stringOrNull('organizationId'),
    billingInterval: json.string('billingInterval'),
    billingBlocked: json.boolean('billingBlocked'),
    billingBlockedReason: json.stringOrNull('billingBlockedReason'),
  );

  final String plan;
  final String? status;
  final bool isPaid;
  final bool isPro;
  final bool isTeam;
  final bool isEnterprise;
  final bool isOrgScoped;
  final String? organizationId;

  /// `'month' | 'year'`.
  final String billingInterval;
  final bool billingBlocked;

  /// `'payment_failed' | 'dispute' | null`.
  final String? billingBlockedReason;

  @override
  List<Object?> get props => [
    plan,
    status,
    isPaid,
    isPro,
    isTeam,
    isEnterprise,
    isOrgScoped,
    organizationId,
    billingInterval,
    billingBlocked,
    billingBlockedReason,
  ];

  @override
  JsonObject toJson() => {
    'plan': plan,
    'status': status,
    'isPaid': isPaid,
    'isPro': isPro,
    'isTeam': isTeam,
    'isEnterprise': isEnterprise,
    'isOrgScoped': isOrgScoped,
    'organizationId': organizationId,
    'billingInterval': billingInterval,
    'billingBlocked': billingBlocked,
    'billingBlockedReason': billingBlockedReason,
  };
}

/// `viewer` of the host context.
class HostViewer extends ContractValue {
  const HostViewer({
    required this.permission,
    required this.isHostOrganizationMember,
    required this.isHostOrganizationAdmin,
    this.organizationRole,
  });

  factory HostViewer.fromJson(JsonObject json) => HostViewer(
    permission: json.enumValue('permission', WorkspacePermission.values),
    isHostOrganizationMember: json.boolean('isHostOrganizationMember'),
    isHostOrganizationAdmin: json.boolean('isHostOrganizationAdmin'),
    organizationRole: json.stringOrNull('organizationRole'),
  );

  final WorkspacePermission permission;
  final bool isHostOrganizationMember;
  final bool isHostOrganizationAdmin;

  /// `'owner' | 'admin' | 'member' | null`.
  final String? organizationRole;

  @override
  List<Object?> get props => [
    permission,
    isHostOrganizationMember,
    isHostOrganizationAdmin,
    organizationRole,
  ];

  @override
  JsonObject toJson() => {
    'permission': permission.name,
    'isHostOrganizationMember': isHostOrganizationMember,
    'isHostOrganizationAdmin': isHostOrganizationAdmin,
    'organizationRole': organizationRole,
  };
}

/// `features` of the host context (optional on the wire).
class HostFeatures extends ContractValue {
  const HostFeatures({
    this.credentialGroups = false,
    this.organizationSearch,
    this.knowledgeMemberAccess,
    this.knowledgeSourceMirroredAccess,
  });

  factory HostFeatures.fromJson(JsonObject json) => HostFeatures(
    credentialGroups: json.boolean('credentialGroups'),
    organizationSearch: json.boolOrNull('organizationSearch'),
    knowledgeMemberAccess: json.boolOrNull('knowledgeMemberAccess'),
    knowledgeSourceMirroredAccess: json.boolOrNull(
      'knowledgeSourceMirroredAccess',
    ),
  );

  final bool credentialGroups;
  final bool? organizationSearch;
  final bool? knowledgeMemberAccess;
  final bool? knowledgeSourceMirroredAccess;

  @override
  List<Object?> get props => [
    credentialGroups,
    organizationSearch,
    knowledgeMemberAccess,
    knowledgeSourceMirroredAccess,
  ];

  @override
  JsonObject toJson() => {
    'credentialGroups': credentialGroups,
    'organizationSearch': ?organizationSearch,
    'knowledgeMemberAccess': ?knowledgeMemberAccess,
    'knowledgeSourceMirroredAccess': ?knowledgeSourceMirroredAccess,
  };
}

/// `GET /api/workspaces/[id]/host-context` (`workspaces.ts:302-335`).
/// `features` and `deployment` are optional for rolling compatibility: the
/// decoder defaults [features] and leaves [deployment] `null` so the app
/// falls back to the public-env shape.
class WorkspaceHostContext extends ContractValue {
  const WorkspaceHostContext({
    required this.workspace,
    required this.hostOrganizationId,
    required this.ownerBilling,
    required this.viewer,
    this.features = const HostFeatures(),
    this.deployment,
  });

  factory WorkspaceHostContext.fromJson(JsonObject json) =>
      WorkspaceHostContext(
        workspace: HostWorkspace.fromJson(json.object('workspace')),
        hostOrganizationId: json.stringOrNull('hostOrganizationId'),
        ownerBilling: OwnerBilling.fromJson(json.object('ownerBilling')),
        viewer: HostViewer.fromJson(json.object('viewer')),
        features: switch (json.objectOrNull('features')) {
          final features? => HostFeatures.fromJson(features),
          null => const HostFeatures(),
        },
        deployment: switch (json.objectOrNull('deployment')) {
          final shape? => DeploymentShape.fromJson(shape),
          null => null,
        },
      );

  final HostWorkspace workspace;
  final String? hostOrganizationId;
  final OwnerBilling ownerBilling;
  final HostViewer viewer;
  final HostFeatures features;
  final DeploymentShape? deployment;

  /// `canViewWorkspaceBillingSettings(hostContext, viewerId)`
  /// (`lib/billing/workspace-permissions.ts:11-41`).
  bool canViewBillingSettings({
    required String viewerId,
    required DeploymentShape shape,
  }) {
    if (!shape.billingEnabled) return false;
    if (hostOrganizationId != null) return viewer.isHostOrganizationAdmin;
    return workspace.billedAccountUserId == viewerId;
  }

  @override
  List<Object?> get props => [
    workspace,
    hostOrganizationId,
    ownerBilling,
    viewer,
    features,
    deployment,
  ];

  @override
  JsonObject toJson() => {
    'workspace': workspace.toJson(),
    'hostOrganizationId': hostOrganizationId,
    'ownerBilling': ownerBilling.toJson(),
    'viewer': viewer.toJson(),
    'features': features.toJson(),
    'deployment': ?deployment?.toJson(),
  };
}

/// One row of `GET /api/workspaces/[id]/permissions` (`workspaces.ts:117-131`).
class WorkspaceUser extends ContractValue {
  const WorkspaceUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.image,
    required this.permissionType,
    required this.isExternal,
    required this.joinedAt,
    required this.roleSource,
    required this.isOrgAdmin,
    required this.isBilledAccount,
  });

  factory WorkspaceUser.fromJson(JsonObject json) => WorkspaceUser(
    userId: json.string('userId'),
    email: json.string('email'),
    name: json.stringOrNull('name'),
    image: json.stringOrNull('image'),
    permissionType: json.enumValue(
      'permissionType',
      WorkspacePermission.values,
    ),
    isExternal: json.boolean('isExternal'),
    joinedAt: json.string('joinedAt'),
    roleSource: json.string('roleSource'),
    isOrgAdmin: json.boolean('isOrgAdmin'),
    isBilledAccount: json.boolean('isBilledAccount'),
  );

  final String userId;
  final String email;
  final String? name;
  final String? image;
  final WorkspacePermission permissionType;
  final bool isExternal;
  final String joinedAt;

  /// `'owner' | 'explicit' | 'org-admin'`.
  final String roleSource;
  final bool isOrgAdmin;
  final bool isBilledAccount;

  @override
  List<Object?> get props => [
    userId,
    email,
    name,
    image,
    permissionType,
    isExternal,
    joinedAt,
    roleSource,
    isOrgAdmin,
    isBilledAccount,
  ];

  @override
  JsonObject toJson() => {
    'userId': userId,
    'email': email,
    'name': name,
    'image': image,
    'permissionType': permissionType.name,
    'isExternal': isExternal,
    'joinedAt': joinedAt,
    'roleSource': roleSource,
    'isOrgAdmin': isOrgAdmin,
    'isBilledAccount': isBilledAccount,
  };
}

/// `viewer` of the permissions response.
class PermissionsViewer extends ContractValue {
  const PermissionsViewer({
    required this.userId,
    required this.isAdmin,
    required this.permissionType,
  });

  factory PermissionsViewer.fromJson(JsonObject json) => PermissionsViewer(
    userId: json.string('userId'),
    isAdmin: json.boolean('isAdmin'),
    permissionType: json.enumValue(
      'permissionType',
      WorkspacePermission.values,
    ),
  );

  final String userId;
  final bool isAdmin;
  final WorkspacePermission permissionType;

  @override
  List<Object?> get props => [userId, isAdmin, permissionType];

  @override
  JsonObject toJson() => {
    'userId': userId,
    'isAdmin': isAdmin,
    'permissionType': permissionType.name,
  };
}

/// `GET /api/workspaces/[id]/permissions` → `{users, total, viewer?}`.
class WorkspacePermissions extends ContractValue {
  const WorkspacePermissions({
    required this.users,
    required this.total,
    this.viewer,
  });

  factory WorkspacePermissions.fromJson(JsonObject json) =>
      WorkspacePermissions(
        users: json.objectList('users').map(WorkspaceUser.fromJson).toList(),
        total: json.integer('total'),
        viewer: switch (json.objectOrNull('viewer')) {
          final viewer? => PermissionsViewer.fromJson(viewer),
          null => null,
        },
      );

  final List<WorkspaceUser> users;
  final int total;
  final PermissionsViewer? viewer;

  @override
  List<Object?> get props => [users, total, viewer];

  @override
  JsonObject toJson() => {
    'users': users.map((u) => u.toJson()).toList(),
    'total': total,
    'viewer': ?viewer?.toJson(),
  };
}

/// One row of `GET /api/workspaces/[id]/members`.
class WorkspaceMember extends ContractValue {
  const WorkspaceMember({
    required this.userId,
    required this.name,
    required this.image,
  });

  factory WorkspaceMember.fromJson(JsonObject json) => WorkspaceMember(
    userId: json.string('userId'),
    name: json.string('name'),
    image: json.stringOrNull('image'),
  );

  final String userId;
  final String name;
  final String? image;

  @override
  List<Object?> get props => [userId, name, image];

  @override
  JsonObject toJson() => {'userId': userId, 'name': name, 'image': image};
}

/// One entry of the `PATCH /api/workspaces/[id]/permissions` body.
class PermissionUpdate extends ContractValue {
  const PermissionUpdate({required this.userId, required this.permissions});

  final String userId;
  final WorkspacePermission permissions;

  @override
  List<Object?> get props => [userId, permissions];

  @override
  JsonObject toJson() => {'userId': userId, 'permissions': permissions.name};
}

/// `GET /api/workspaces/[id]/credit-availability`.
class CreditAvailability extends ContractValue {
  const CreditAvailability({
    required this.remainingDollars,
    required this.scope,
  });

  factory CreditAvailability.fromJson(JsonObject json) => CreditAvailability(
    remainingDollars: json.numOrNull('remainingDollars'),
    scope: json.string('scope'),
  );

  final num? remainingDollars;

  /// `'payer' | 'member' | 'effective'`.
  final String scope;

  @override
  List<Object?> get props => [remainingDollars, scope];

  @override
  JsonObject toJson() => {'remainingDollars': remainingDollars, 'scope': scope};
}

/// `GET /api/workspaces/[id]/usage-gate`.
class UsageGate extends ContractValue {
  const UsageGate({
    required this.isExceeded,
    required this.message,
    required this.scope,
  });

  factory UsageGate.fromJson(JsonObject json) => UsageGate(
    isExceeded: json.boolean('isExceeded'),
    message: json.stringOrNull('message'),
    scope: json.stringOrNull('scope'),
  );

  final bool isExceeded;
  final String? message;

  /// `'actor' | 'payer' | 'member' | null`.
  final String? scope;

  @override
  List<Object?> get props => [isExceeded, message, scope];

  @override
  JsonObject toJson() => {
    'isExceeded': isExceeded,
    'message': message,
    'scope': scope,
  };
}
