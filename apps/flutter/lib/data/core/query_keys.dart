/// Key factories and `staleTime` constants of the Phase 1 queries
/// (`docs/port/specs/data-phase1.md` §4, `.claude/rules/sim-queries.md`).
/// The Dart keys are the same string arrays as the React ones, so the
/// invalidation prefixes of spec §6 match byte for byte.
library;

import 'package:sim_api/sim_api.dart';

/// `hooks/queries/session.ts`.
abstract final class SessionKeys {
  static const QueryKey all = ['session'];
  static QueryKey detail() => [...all, 'detail'];
}

/// `hooks/queries/workspace.ts:40-52`.
abstract final class WorkspaceKeys {
  static const QueryKey all = ['workspace'];
  static QueryKey lists() => [...all, 'list'];
  static QueryKey list([String scope = 'active']) => [
    ...lists(),
    'user',
    scope,
  ];
  static QueryKey details() => [...all, 'detail'];
  static QueryKey detail(String id) => [...details(), id];
  static QueryKey settings(String id) => [...detail(id), 'settings'];
  static QueryKey permissions(String id) => [...detail(id), 'permissions'];
  static QueryKey members(String id) => [...detail(id), 'members'];
  static QueryKey adminLists() => [...all, 'adminList'];
  static QueryKey adminList(String userId, [String organizationId = '']) => [
    ...adminLists(),
    userId,
    organizationId,
  ];
}

/// `hooks/queries/workspace-host.ts`.
abstract final class WorkspaceHostKeys {
  static const QueryKey all = ['workspace-host'];
  static QueryKey detail(String id) => [...all, 'detail', id];
}

/// The new feature-flags route (no React hook; spec §4.2).
abstract final class FeatureFlagKeys {
  static const QueryKey all = ['workspace-feature-flags'];
  static QueryKey detail(String id) => [...all, 'detail', id];
}

/// `GET /api/public-env` (fetched once per app start).
abstract final class PublicEnvKeys {
  static const QueryKey all = ['public-env'];
}

/// `hooks/queries/workspace-usage.ts`.
abstract final class WorkspaceUsageKeys {
  static const QueryKey all = ['workspace-usage'];
  static QueryKey creditAvailability(String id) => [
    ...all,
    'credit-availability',
    id,
  ];
  static QueryKey gate(String id) => [...all, 'gate', id];
}

/// `hooks/queries/utils/workflow-keys.ts`.
abstract final class WorkflowKeys {
  static const QueryKey all = ['workflows'];
  static QueryKey lists() => [...all, 'list'];
  static QueryKey list(String? workspaceId, [String scope = 'active']) => [
    ...lists(),
    workspaceId ?? '',
    scope,
  ];
  static QueryKey states() => [...all, 'state'];
  static QueryKey state(String workflowId) => [...states(), workflowId];
}

/// `selectorKeys.all`, invalidated with every workflow list.
abstract final class SelectorKeys {
  static const QueryKey all = ['selectors'];
}

/// `hooks/queries/utils/folder-keys.ts:41-51`.
abstract final class FolderKeys {
  static const QueryKey all = ['folders'];
  static QueryKey lists() => [...all, 'list'];
  static QueryKey resource([String type = 'workflow']) => [...lists(), type];
  static QueryKey list(
    String? workspaceId, [
    String scope = 'active',
    String type = 'workflow',
  ]) => [...resource(type), workspaceId ?? '', scope];
}

/// `hooks/queries/utils/pinned-item-keys.ts:14-21`.
abstract final class PinnedItemKeys {
  static const QueryKey all = ['pinnedItems'];
  static QueryKey lists() => [...all, 'list'];
  static QueryKey workspaceLists(String? workspaceId) => [
    ...lists(),
    workspaceId ?? '',
  ];
  static QueryKey list(String? workspaceId, [String? type]) => [
    ...workspaceLists(workspaceId),
    type ?? '',
  ];

  /// Index of the `resourceType` segment in [list], derived from the
  /// factory (`RESOURCE_TYPE_KEY_INDEX`).
  static final int resourceTypeIndex = workspaceLists('').length;
}

/// `hooks/queries/invitations.ts:36-51`.
abstract final class InvitationKeys {
  static const QueryKey all = ['invitations'];
  static QueryKey lists() => [...all, 'list'];
  static QueryKey list(String workspaceId) => [...lists(), workspaceId];
  static QueryKey details() => [...all, 'detail'];
  static QueryKey detail(
    String invitationId,
    String? token,
    String? viewerId,
  ) => [...details(), invitationId, token ?? '', viewerId ?? ''];
  static QueryKey mine() => [...all, 'mine'];
}

/// `hooks/queries/user-profile.ts`.
abstract final class UserProfileKeys {
  static const QueryKey all = ['userProfile'];
  static QueryKey profile() => [...all, 'profile'];
}

/// `hooks/queries/general-settings.ts`.
abstract final class GeneralSettingsKeys {
  static const QueryKey all = ['generalSettings'];
  static QueryKey settings() => [...all, 'settings'];
}

/// `hooks/queries/custom-blocks.ts`.
abstract final class CustomBlockKeys {
  static const QueryKey all = ['custom-blocks'];
  static QueryKey lists() => [...all, 'list'];
  static QueryKey list(String workspaceId) => [...lists(), workspaceId];
}

/// `hooks/queries/block-visibility.ts`.
abstract final class BlockVisibilityKeys {
  static const QueryKey all = ['block-visibility'];
  static QueryKey list(String workspaceId) => [...all, 'list', workspaceId];
}

/// `hooks/queries/providers.ts`.
abstract final class ProviderModelKeys {
  static const QueryKey all = ['provider-models'];
  static QueryKey list(ProviderName provider, String? workspaceId) => [
    ...all,
    'list',
    provider.wireName,
    workspaceId ?? '',
  ];
}

/// `ee/whitelabeling/hooks/whitelabel.ts`.
abstract final class WhitelabelKeys {
  static const QueryKey all = ['whitelabel'];
  static QueryKey settings(String organizationId) => [
    ...all,
    'settings',
    organizationId,
  ];
}

/// `hooks/queries/utils/organization-keys.ts`.
abstract final class OrganizationKeys {
  static const QueryKey all = ['organizations'];
  static QueryKey lists() => [...all, 'list'];
  static QueryKey detail(String id) => [...all, 'detail', id];
  static QueryKey roster(String id) => [...detail(id), 'roster'];
  static QueryKey billing(String id) => [...detail(id), 'billing'];
  static QueryKey planSeats(String id) => [...billing(id), 'plan-seats'];
  static QueryKey surfaceContext(String id) => [
    ...detail(id),
    'surface-context',
  ];
}

/// `workspaceCredentialKeys.all` (invalidated after invitation accept).
abstract final class WorkspaceCredentialKeys {
  static const QueryKey all = ['workspace-credentials'];
}

/// `hooks/queries/utils/subscription-keys.ts`.
abstract final class SubscriptionKeys {
  static const QueryKey all = ['subscription'];
  static QueryKey user() => [...all, 'user'];
}

/// `hooks/queries/utils/recently-deleted-keys.ts`.
abstract final class RecentlyDeletedKeys {
  static const QueryKey all = ['recentlyDeleted'];
  static QueryKey lists() => [...all, 'list'];
}

/// `hooks/queries/utils/integration-availability-keys.ts`.
abstract final class IntegrationAvailabilityKeys {
  static const QueryKey all = ['allowedIntegrations'];
  static QueryKey environments() => [...all, 'env'];
}

/// `hooks/queries/allowed-providers.ts`.
abstract final class AllowedProviderKeys {
  static const QueryKey all = ['allowedProviders'];
  static QueryKey blacklisted() => [...all, 'blacklisted'];
}

/// Named `staleTime` constants (spec §4; every hook exports one).
abstract final class StaleTimes {
  static const Duration session = Duration(minutes: 5);
  static const Duration workspaceHostContext = Duration(seconds: 30);
  static const Duration workspaceFeatureFlags = Duration(seconds: 30);
  static const Duration workspaceList = Duration(seconds: 30);
  static const Duration workspacePermissions = Duration(seconds: 30);
  static const Duration workspaceSettings = Duration(seconds: 30);
  static const Duration workspaceMembers = Duration(minutes: 5);
  static const Duration workspaceAdminList = Duration(seconds: 60);
  static const Duration workspaceUsage = Duration(seconds: 30);
  static const Duration workflowList = Duration(seconds: 60);
  static const Duration workflowState = Duration(seconds: 30);
  static const Duration folderList = Duration(seconds: 60);
  static const Duration pinnedItems = Duration(seconds: 60);
  static const Duration workspaceInvitationList = Duration(seconds: 30);
  static const Duration invitationDetails = Duration(seconds: 30);
  static const Duration myInvitations = Duration(seconds: 30);
  static const Duration userProfile = Duration(minutes: 5);
  static const Duration generalSettings = Duration(minutes: 60);
  static const Duration customBlockList = Duration(seconds: 60);
  static const Duration blockVisibility = Duration(seconds: 60);
  static const Duration providerModels = Duration(minutes: 5);
  static const Duration whitelabel = Duration(seconds: 60);
  static const Duration integrationAvailability = Duration(minutes: 5);
  static const Duration allowedProviders = Duration(minutes: 5);
  static const Duration organizationPlanSeats = Duration(seconds: 30);
  static const Duration recentlyDeleted = Duration.zero;

  /// Public env is read once per app start and never refetched.
  static const Duration publicEnv = Duration(days: 365);

  /// `IMPERSONATION_REFETCH_INTERVAL`.
  static const Duration impersonationRefetch = Duration(seconds: 60);
}
