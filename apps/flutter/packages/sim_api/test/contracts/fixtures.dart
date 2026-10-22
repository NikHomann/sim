// Wire bodies as the seeded docker stack returns them (captured with curl
// against the proxy), including the fields the zod schemas do not list.

const workspaceId = '44098e20-360c-53b2-adb0-efed21a7919c';
const userId = '74ec8a68-36ee-5159-a49a-3fb9d373ba32';
const folderId = 'a21eb9d7-7350-580a-bd4b-5f96e6796149';
const workflowId = '94cb2172-79b9-5f9b-a15e-210e57132b5c';

Map<String, Object?> liveWorkspaceJson() => {
  'id': workspaceId,
  'name': 'Flutter E2E workspace',
  'color': '#33C482',
  'logoUrl': null,
  'ownerId': userId,
  'organizationId': null,
  'workspaceMode': 'grandfathered_shared',
  'billedAccountUserId': userId,
  'storageUsedBytes': 0,
  'allowPersonalApiKeys': true,
  'inboxEnabled': false,
  'inboxAddress': null,
  'inboxProviderId': null,
  'inboxSecretScope': 'all',
  'inboxMountedSecrets': <String>[],
  'archivedAt': null,
  'organizationAssignedAt': null,
  'forkedFromWorkspaceId': null,
  'forkSyncNewWorkflowsExcluded': false,
  'createdAt': '2026-10-21T09:48:13.097Z',
  'updatedAt': '2026-10-21T09:48:13.097Z',
  'role': 'owner',
  'permissions': 'admin',
  'isOrgAdmin': false,
  'inviteMembersEnabled': true,
  'inviteDisabledReason': null,
  'inviteUpgradeRequired': false,
};

Map<String, Object?> liveWorkspaceListJson() => {
  'workspaces': [liveWorkspaceJson()],
  'lastActiveWorkspaceId': workspaceId,
  'pinnedWorkspaceIds': <String>[],
  'creationPolicy': {
    'canCreate': true,
    'workspaceMode': 'personal',
    'organizationId': null,
    'billedAccountUserId': userId,
    'maxWorkspaces': null,
    'currentWorkspaceCount': 1,
    'reason': null,
    'status': 200,
    'observedOrganizationId': null,
    'governingPermissionGroupOrganizationId': null,
  },
};

Map<String, Object?> liveHostContextJson() => {
  'workspace': {
    'id': workspaceId,
    'name': 'Flutter E2E workspace',
    'workspaceMode': 'grandfathered_shared',
    'billedAccountUserId': userId,
    'allowPersonalApiKeys': true,
  },
  'hostOrganizationId': null,
  'ownerBilling': {
    'plan': 'free',
    'status': null,
    'isPaid': false,
    'isPro': false,
    'isTeam': false,
    'isEnterprise': false,
    'isOrgScoped': false,
    'organizationId': null,
    'billingInterval': 'month',
    'billingBlocked': false,
    'billingBlockedReason': null,
  },
  'viewer': {
    'permission': 'admin',
    'isHostOrganizationMember': false,
    'isHostOrganizationAdmin': false,
    'organizationRole': null,
  },
  'features': {
    'credentialGroups': false,
    'organizationSearch': false,
    'knowledgeMemberAccess': false,
    'knowledgeSourceMirroredAccess': false,
  },
  'deployment': {
    'hosted': false,
    'billingEnabled': false,
    'chatEnabled': true,
    'azureConfigured': false,
    'cohereConfigured': false,
    'features': {
      'accessControl': false,
      'auditLogs': false,
      'customBlocks': false,
      'dataDrains': false,
      'dataRetention': false,
      'inbox': true,
      'sandboxes': false,
      'scim': false,
      'sessionPolicies': true,
      'sso': false,
      'usageMonitoring': false,
      'whitelabeling': true,
    },
  },
};

Map<String, Object?> featureFlagsJson({bool dashboards = true}) => {
  'dashboards': dashboards,
  'workflow-tests': false,
  'changelog': false,
  'mothership-model-selector': false,
  'mothership-computer-use': false,
  'mothership-plan-mode': false,
  'projects': false,
};

Map<String, Object?> liveFolderJson({
  String id = folderId,
  String name = 'E2E folder',
  String? parentId,
  num sortOrder = 0,
}) => {
  'id': id,
  'projectId': null,
  'resourceType': 'workflow',
  'name': name,
  'userId': userId,
  'workspaceId': workspaceId,
  'parentId': parentId,
  'locked': false,
  'sortOrder': sortOrder,
  'createdAt': '2026-10-21T09:48:13.097Z',
  'updatedAt': '2026-10-21T09:48:13.097Z',
  'deletedAt': null,
};

Map<String, Object?> liveWorkflowJson({
  String id = workflowId,
  String name = 'Empty workflow',
  String? folderId,
  num sortOrder = 0,
}) => {
  'id': id,
  'name': name,
  'description': 'No blocks: the empty canvas state.',
  'workspaceId': workspaceId,
  'folderId': folderId,
  'sortOrder': sortOrder,
  'createdAt': '2026-10-21T09:48:13.097Z',
  'updatedAt': '2026-10-21T09:48:13.097Z',
  'archivedAt': null,
  'locked': false,
  'forkSyncExcluded': false,
  'isDeployed': false,
};

Map<String, Object?> liveSettingsJson() => {
  'data': {
    'theme': 'system',
    'autoConnect': true,
    'telemetryEnabled': true,
    'emailPreferences': <String, Object?>{},
    'billingUsageNotificationsEnabled': true,
    'superUserModeEnabled': false,
    'mothershipEnvironment': 'default',
    'errorNotificationsEnabled': true,
    'snapToGridSize': 0,
    'showActionBar': true,
    'autoFocusOnClick': true,
    'copilotAutoAllowedTools': <String>[],
    'timezone': null,
    'lastActiveWorkspaceId': null,
  },
};

Map<String, Object?> liveProfileJson() => {
  'user': {
    'id': userId,
    'name': 'Flutter E2E',
    'email': 'flutter-e2e@example.com',
    'image': null,
    'emailVerified': true,
  },
};

Map<String, Object?> invitationDetailsJson({String id = 'inv-1'}) => {
  'invitation': {
    'id': id,
    'kind': 'workspace',
    'email': 'invitee@example.com',
    'organizationId': null,
    'organizationName': null,
    'membershipIntent': 'internal',
    'role': 'member',
    'status': 'pending',
    'expiresAt': '2026-11-01T00:00:00.000Z',
    'createdAt': '2026-10-21T00:00:00.000Z',
    'inviterName': 'Flutter E2E',
    'inviterEmail': 'flutter-e2e@example.com',
    'grants': [
      {
        'workspaceId': workspaceId,
        'workspaceName': 'Flutter E2E workspace',
        'permission': 'write',
      },
    ],
  },
  'joinPreview': {
    'outcome': 'will-join',
    'organizationName': null,
    'workspacesToMove': <String>[],
    'workspaceIdsToMove': <String>[],
  },
};

Map<String, Object?> surfaceContextJson({String organizationId = 'org-1'}) => {
  'context': {
    'organization': {
      'id': organizationId,
      'name': 'Org',
      'slug': 'org',
      'logo': null,
      'memberCount': 3,
    },
    'viewer': {
      'role': 'member',
      'isAdmin': false,
      'canInviteMembers': false,
      'canConnectSearchIntegrations': false,
      'canUsePersonalApiKeys': true,
      'canUseSearchMcp': false,
    },
    'connectedAccountsAvailable': false,
    'mothershipAvailable': true,
    'canBuild': true,
    'searchAccess': {'sourceMirrored': false, 'memberScoped': false},
    'settingsFeatures': {
      'billingEnabled': false,
      'hasEnterprisePlan': false,
      'governanceActive': false,
      'hosted': false,
      'selfHosted': {'connected-accounts': true, 'sso': false},
    },
    'deployment': liveHostContextJson()['deployment'],
  },
  'flags': {...featureFlagsJson(), 'mothership-memory-spaces': true},
  'benchmarkEnabled': true,
};
