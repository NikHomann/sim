/// Wire shapes of `apps/sim/lib/api/contracts/{organizations,organization}.ts`
/// used in Phase 1 (`generated/contracts/{organizations,organization}.schema.json`):
/// the creator list, the surface context, whitelabel settings and plan seats.
library;

import 'package:sim_api/src/contracts/json.dart';
import 'package:sim_api/src/contracts/workspaces.dart';

/// One row of `GET /api/organizations`.
class CreatorOrganization extends ContractValue {
  const CreatorOrganization({
    required this.id,
    required this.name,
    required this.role,
  });

  factory CreatorOrganization.fromJson(JsonObject json) => CreatorOrganization(
    id: json.string('id'),
    name: json.string('name'),
    role: json.string('role'),
  );

  final String id;
  final String name;
  final String role;

  @override
  List<Object?> get props => [id, name, role];

  @override
  JsonObject toJson() => {'id': id, 'name': name, 'role': role};
}

/// `GET /api/organizations` → `{organizations, isMemberOfAnyOrg}`
/// (`organizations.ts:17-27`).
class CreatorOrganizations extends ContractValue {
  const CreatorOrganizations({
    required this.organizations,
    required this.isMemberOfAnyOrg,
  });

  factory CreatorOrganizations.fromJson(JsonObject json) =>
      CreatorOrganizations(
        organizations: json
            .objectList('organizations')
            .map(CreatorOrganization.fromJson)
            .toList(),
        isMemberOfAnyOrg: json.boolean('isMemberOfAnyOrg'),
      );

  final List<CreatorOrganization> organizations;
  final bool isMemberOfAnyOrg;

  @override
  List<Object?> get props => [organizations, isMemberOfAnyOrg];

  @override
  JsonObject toJson() => {
    'organizations': organizations.map((o) => o.toJson()).toList(),
    'isMemberOfAnyOrg': isMemberOfAnyOrg,
  };
}

/// `context.organization` of the surface context.
class SurfaceOrganization extends ContractValue {
  const SurfaceOrganization({
    required this.id,
    required this.name,
    required this.slug,
    required this.logo,
    required this.memberCount,
  });

  factory SurfaceOrganization.fromJson(JsonObject json) => SurfaceOrganization(
    id: json.string('id'),
    name: json.string('name'),
    slug: json.string('slug'),
    logo: json.stringOrNull('logo'),
    memberCount: json.integer('memberCount'),
  );

  final String id;
  final String name;
  final String slug;
  final String? logo;
  final int memberCount;

  @override
  List<Object?> get props => [id, name, slug, logo, memberCount];

  @override
  JsonObject toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'logo': logo,
    'memberCount': memberCount,
  };
}

/// `context.viewer` of the surface context.
class SurfaceViewer extends ContractValue {
  const SurfaceViewer({
    required this.role,
    required this.isAdmin,
    required this.canInviteMembers,
    required this.canConnectSearchIntegrations,
    required this.canUsePersonalApiKeys,
    required this.canUseSearchMcp,
  });

  factory SurfaceViewer.fromJson(JsonObject json) => SurfaceViewer(
    role: json.string('role'),
    isAdmin: json.boolean('isAdmin'),
    canInviteMembers: json.boolean('canInviteMembers'),
    canConnectSearchIntegrations: json.boolean('canConnectSearchIntegrations'),
    canUsePersonalApiKeys: json.boolean('canUsePersonalApiKeys'),
    canUseSearchMcp: json.boolean('canUseSearchMcp'),
  );

  /// `'owner' | 'admin' | 'member'`.
  final String role;
  final bool isAdmin;
  final bool canInviteMembers;
  final bool canConnectSearchIntegrations;
  final bool canUsePersonalApiKeys;
  final bool canUseSearchMcp;

  @override
  List<Object?> get props => [
    role,
    isAdmin,
    canInviteMembers,
    canConnectSearchIntegrations,
    canUsePersonalApiKeys,
    canUseSearchMcp,
  ];

  @override
  JsonObject toJson() => {
    'role': role,
    'isAdmin': isAdmin,
    'canInviteMembers': canInviteMembers,
    'canConnectSearchIntegrations': canConnectSearchIntegrations,
    'canUsePersonalApiKeys': canUsePersonalApiKeys,
    'canUseSearchMcp': canUseSearchMcp,
  };
}

/// `context.searchAccess`.
class SearchAccess extends ContractValue {
  const SearchAccess({
    required this.sourceMirrored,
    required this.memberScoped,
  });

  factory SearchAccess.fromJson(JsonObject json) => SearchAccess(
    sourceMirrored: json.boolean('sourceMirrored'),
    memberScoped: json.boolean('memberScoped'),
  );

  final bool sourceMirrored;
  final bool memberScoped;

  @override
  List<Object?> get props => [sourceMirrored, memberScoped];

  @override
  JsonObject toJson() => {
    'sourceMirrored': sourceMirrored,
    'memberScoped': memberScoped,
  };
}

/// `context.settingsFeatures`.
class SettingsFeatures extends ContractValue {
  const SettingsFeatures({
    required this.billingEnabled,
    required this.hasEnterprisePlan,
    required this.governanceActive,
    required this.hosted,
    required this.selfHosted,
  });

  factory SettingsFeatures.fromJson(JsonObject json) => SettingsFeatures(
    billingEnabled: json.boolean('billingEnabled'),
    hasEnterprisePlan: json.boolean('hasEnterprisePlan'),
    governanceActive: json.boolean('governanceActive'),
    hosted: json.boolean('hosted'),
    selfHosted: {
      for (final entry in json.object('selfHosted').entries)
        entry.key: entry.value == true,
    },
  );

  final bool billingEnabled;
  final bool hasEnterprisePlan;
  final bool governanceActive;
  final bool hosted;

  /// Section → enabled (`connected-accounts`, `access-control`, ...).
  final Map<String, bool> selfHosted;

  @override
  List<Object?> get props => [
    billingEnabled,
    hasEnterprisePlan,
    governanceActive,
    hosted,
    selfHosted,
  ];

  @override
  JsonObject toJson() => {
    'billingEnabled': billingEnabled,
    'hasEnterprisePlan': hasEnterprisePlan,
    'governanceActive': governanceActive,
    'hosted': hosted,
    'selfHosted': selfHosted,
  };
}

/// `context` of `GET /api/organizations/[id]/surface-context`
/// (`organization.ts:863-911`, spec §3.4).
class OrganizationSurfaceContext extends ContractValue {
  const OrganizationSurfaceContext({
    required this.organization,
    required this.viewer,
    required this.connectedAccountsAvailable,
    required this.mothershipAvailable,
    required this.canBuild,
    required this.searchAccess,
    required this.settingsFeatures,
    required this.deployment,
  });

  factory OrganizationSurfaceContext.fromJson(JsonObject json) =>
      OrganizationSurfaceContext(
        organization: SurfaceOrganization.fromJson(json.object('organization')),
        viewer: SurfaceViewer.fromJson(json.object('viewer')),
        connectedAccountsAvailable: json.boolean('connectedAccountsAvailable'),
        mothershipAvailable: json.boolean('mothershipAvailable'),
        canBuild: json.boolean('canBuild'),
        searchAccess: SearchAccess.fromJson(json.object('searchAccess')),
        settingsFeatures: SettingsFeatures.fromJson(
          json.object('settingsFeatures'),
        ),
        deployment: DeploymentShape.fromJson(json.object('deployment')),
      );

  final SurfaceOrganization organization;
  final SurfaceViewer viewer;
  final bool connectedAccountsAvailable;
  final bool mothershipAvailable;
  final bool canBuild;
  final SearchAccess searchAccess;
  final SettingsFeatures settingsFeatures;
  final DeploymentShape deployment;

  /// The organization has a home for this viewer (spec §8.1): the
  /// `o/[organizationId]/layout.tsx:63-67` redirect rule inverted.
  bool get hasOrganizationHome =>
      mothershipAvailable || searchAccess.memberScoped;

  @override
  List<Object?> get props => [
    organization,
    viewer,
    connectedAccountsAvailable,
    mothershipAvailable,
    canBuild,
    searchAccess,
    settingsFeatures,
    deployment,
  ];

  @override
  JsonObject toJson() => {
    'organization': organization.toJson(),
    'viewer': viewer.toJson(),
    'connectedAccountsAvailable': connectedAccountsAvailable,
    'mothershipAvailable': mothershipAvailable,
    'canBuild': canBuild,
    'searchAccess': searchAccess.toJson(),
    'settingsFeatures': settingsFeatures.toJson(),
    'deployment': deployment.toJson(),
  };
}

/// `GET /api/organizations/[id]/surface-context` → `{context, flags,
/// benchmarkEnabled}`.
class OrganizationSurface extends ContractValue {
  const OrganizationSurface({
    required this.context,
    required this.flags,
    required this.benchmarkEnabled,
  });

  factory OrganizationSurface.fromJson(JsonObject json) => OrganizationSurface(
    context: OrganizationSurfaceContext.fromJson(json.object('context')),
    flags: WorkspaceFeatureFlags.fromJson(json.object('flags')),
    benchmarkEnabled: json.boolean('benchmarkEnabled'),
  );

  final OrganizationSurfaceContext context;
  final WorkspaceFeatureFlags flags;
  final bool benchmarkEnabled;

  @override
  List<Object?> get props => [context, flags, benchmarkEnabled];

  @override
  JsonObject toJson() => {
    'context': context.toJson(),
    'flags': flags.toJson(),
    'benchmarkEnabled': benchmarkEnabled,
  };
}

/// `data` of `GET /api/organizations/[id]/whitelabel` (the PUT body shape,
/// `organization.ts:269-…`; every field optional).
class OrganizationWhitelabelSettings extends ContractValue {
  const OrganizationWhitelabelSettings({
    this.brandName,
    this.logoUrl,
    this.wordmarkUrl,
    this.primaryColor,
    this.primaryHoverColor,
    this.accentColor,
    this.accentHoverColor,
    this.supportEmail,
    this.documentationUrl,
    this.termsUrl,
    this.privacyUrl,
    this.hidePoweredBySim,
  });

  factory OrganizationWhitelabelSettings.fromJson(JsonObject json) =>
      OrganizationWhitelabelSettings(
        brandName: json.stringOrNull('brandName'),
        logoUrl: json.stringOrNull('logoUrl'),
        wordmarkUrl: json.stringOrNull('wordmarkUrl'),
        primaryColor: json.stringOrNull('primaryColor'),
        primaryHoverColor: json.stringOrNull('primaryHoverColor'),
        accentColor: json.stringOrNull('accentColor'),
        accentHoverColor: json.stringOrNull('accentHoverColor'),
        supportEmail: json.stringOrNull('supportEmail'),
        documentationUrl: json.stringOrNull('documentationUrl'),
        termsUrl: json.stringOrNull('termsUrl'),
        privacyUrl: json.stringOrNull('privacyUrl'),
        hidePoweredBySim: json.boolOrNull('hidePoweredBySim'),
      );

  final String? brandName;
  final String? logoUrl;
  final String? wordmarkUrl;
  final String? primaryColor;
  final String? primaryHoverColor;
  final String? accentColor;
  final String? accentHoverColor;
  final String? supportEmail;
  final String? documentationUrl;
  final String? termsUrl;
  final String? privacyUrl;
  final bool? hidePoweredBySim;

  @override
  List<Object?> get props => [
    brandName,
    logoUrl,
    wordmarkUrl,
    primaryColor,
    primaryHoverColor,
    accentColor,
    accentHoverColor,
    supportEmail,
    documentationUrl,
    termsUrl,
    privacyUrl,
    hidePoweredBySim,
  ];

  @override
  JsonObject toJson() => {
    'brandName': ?brandName,
    'logoUrl': ?logoUrl,
    'wordmarkUrl': ?wordmarkUrl,
    'primaryColor': ?primaryColor,
    'primaryHoverColor': ?primaryHoverColor,
    'accentColor': ?accentColor,
    'accentHoverColor': ?accentHoverColor,
    'supportEmail': ?supportEmail,
    'documentationUrl': ?documentationUrl,
    'termsUrl': ?termsUrl,
    'privacyUrl': ?privacyUrl,
    'hidePoweredBySim': ?hidePoweredBySim,
  };
}

/// `GET /api/organizations/[id]/whitelabel` → `{success, data, isEnterprise?}`.
class OrganizationWhitelabel extends ContractValue {
  const OrganizationWhitelabel({
    required this.success,
    required this.settings,
    this.isEnterprise,
  });

  factory OrganizationWhitelabel.fromJson(JsonObject json) =>
      OrganizationWhitelabel(
        success: json.boolean('success'),
        settings: OrganizationWhitelabelSettings.fromJson(json.object('data')),
        isEnterprise: json.boolOrNull('isEnterprise'),
      );

  final bool success;
  final OrganizationWhitelabelSettings settings;
  final bool? isEnterprise;

  @override
  List<Object?> get props => [success, settings, isEnterprise];

  @override
  JsonObject toJson() => {
    'success': success,
    'data': settings.toJson(),
    'isEnterprise': ?isEnterprise,
  };
}

/// `data` of `GET /api/organizations/[id]/billing-plan`
/// (`organization.ts:774-801`).
class OrganizationPlanSeats extends ContractValue {
  const OrganizationPlanSeats({
    required this.organizationId,
    required this.subscriptionPlan,
    required this.subscriptionStatus,
    required this.totalSeats,
    required this.usedSeats,
    required this.membersTotal,
    required this.hasEnterprisePlan,
  });

  factory OrganizationPlanSeats.fromJson(JsonObject json) =>
      OrganizationPlanSeats(
        organizationId: json.string('organizationId'),
        subscriptionPlan: json.stringOrNull('subscriptionPlan'),
        subscriptionStatus: json.stringOrNull('subscriptionStatus'),
        totalSeats: json.integer('totalSeats'),
        usedSeats: json.integer('usedSeats'),
        membersTotal: json.integer('membersTotal'),
        hasEnterprisePlan: json.boolean('hasEnterprisePlan'),
      );

  final String organizationId;
  final String? subscriptionPlan;
  final String? subscriptionStatus;
  final int totalSeats;
  final int usedSeats;
  final int membersTotal;
  final bool hasEnterprisePlan;

  @override
  List<Object?> get props => [
    organizationId,
    subscriptionPlan,
    subscriptionStatus,
    totalSeats,
    usedSeats,
    membersTotal,
    hasEnterprisePlan,
  ];

  @override
  JsonObject toJson() => {
    'organizationId': organizationId,
    'subscriptionPlan': subscriptionPlan,
    'subscriptionStatus': subscriptionStatus,
    'totalSeats': totalSeats,
    'usedSeats': usedSeats,
    'membersTotal': membersTotal,
    'hasEnterprisePlan': hasEnterprisePlan,
  };
}
