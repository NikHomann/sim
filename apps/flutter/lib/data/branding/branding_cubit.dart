import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';

/// The merged brand (`mergeOrgBrandConfig(settings, getBrandConfig())`):
/// instance defaults overridden by the host organization's whitelabel
/// settings when the viewer is a member.
class BrandConfig extends Equatable {
  const BrandConfig({
    this.name = 'Sim',
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
    this.hidePoweredBySim = false,
  });

  final String name;
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
  final bool hidePoweredBySim;

  /// Every non-empty organization value overrides the instance one.
  BrandConfig merge(OrganizationWhitelabelSettings? org) {
    if (org == null) return this;
    String? pick(String? value, String? fallback) =>
        value == null || value.isEmpty ? fallback : value;
    return BrandConfig(
      name: pick(org.brandName, name)!,
      logoUrl: pick(org.logoUrl, logoUrl),
      wordmarkUrl: pick(org.wordmarkUrl, wordmarkUrl),
      primaryColor: pick(org.primaryColor, primaryColor),
      primaryHoverColor: pick(org.primaryHoverColor, primaryHoverColor),
      accentColor: pick(org.accentColor, accentColor),
      accentHoverColor: pick(org.accentHoverColor, accentHoverColor),
      supportEmail: pick(org.supportEmail, supportEmail),
      documentationUrl: pick(org.documentationUrl, documentationUrl),
      termsUrl: pick(org.termsUrl, termsUrl),
      privacyUrl: pick(org.privacyUrl, privacyUrl),
      hidePoweredBySim: org.hidePoweredBySim ?? hidePoweredBySim,
    );
  }

  @override
  List<Object?> get props => [
    name,
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
}

/// State of [BrandingCubit].
class BrandingState extends Equatable {
  const BrandingState({
    this.organizationId,
    this.enabled = false,
    this.settings = const LoadState(),
    this.instance = const BrandConfig(),
  });

  final String? organizationId;

  /// `viewer.isHostOrganizationMember && hostOrganizationId != null`.
  final bool enabled;
  final LoadState<OrganizationWhitelabel> settings;
  final BrandConfig instance;

  /// `effectiveOrgSettings`: the query's settings when enabled, else none
  /// (a non-member gets instance branding only).
  OrganizationWhitelabelSettings? get effectiveSettings =>
      enabled ? settings.data?.settings : null;

  /// `useOrgBrandConfig()`.
  BrandConfig get brand => instance.merge(effectiveSettings);

  BrandingState copyWith({
    String? organizationId,
    bool clearOrganization = false,
    bool? enabled,
    LoadState<OrganizationWhitelabel>? settings,
    BrandConfig? instance,
  }) => BrandingState(
    organizationId: clearOrganization
        ? null
        : (organizationId ?? this.organizationId),
    enabled: enabled ?? this.enabled,
    settings: settings ?? this.settings,
    instance: instance ?? this.instance,
  );

  @override
  List<Object?> get props => [organizationId, enabled, settings, instance];
}

/// `BrandingProvider` (spec §4.9, §7): whitelabel settings of the host
/// organization (stale 60 s), fetched only for members of that
/// organization; instance defaults otherwise.
class BrandingCubit extends Cubit<BrandingState> {
  BrandingCubit({
    required OrganizationsRepository organizations,
    required QueryClient queryClient,
    BrandConfig instance = const BrandConfig(),
  }) : _organizations = organizations,
       _queryClient = queryClient,
       super(BrandingState(instance: instance));

  final OrganizationsRepository _organizations;
  final QueryClient _queryClient;
  QueryBinding<OrganizationWhitelabel>? _binding;

  /// Configures from the host context: enabled only when the viewer is a
  /// member of a host organization.
  Future<void> configure({
    required String? hostOrganizationId,
    required bool isHostOrganizationMember,
  }) async {
    final enabled = isHostOrganizationMember && hostOrganizationId != null;
    if (!enabled) {
      _binding?.dispose();
      _binding = null;
      emit(
        state.copyWith(
          clearOrganization: true,
          enabled: false,
          settings: const LoadState(),
        ),
      );
      return;
    }
    if (state.organizationId != hostOrganizationId || _binding == null) {
      _binding?.dispose();
      final query = _queryClient.query<OrganizationWhitelabel>(
        WhitelabelKeys.settings(hostOrganizationId),
        (token) =>
            _organizations.whitelabel(hostOrganizationId, cancelToken: token),
        staleTime: StaleTimes.whitelabel,
      );
      _binding = QueryBinding(query, _onQueryState);
      emit(
        state.copyWith(
          organizationId: hostOrganizationId,
          enabled: true,
          settings: LoadState.fromQuery(query.state),
        ),
      );
    }
    try {
      await _binding!.fetch();
    } on Object {
      // Instance branding stays in effect.
    }
  }

  void _onQueryState(QueryState<OrganizationWhitelabel> queryState) {
    if (isClosed) return;
    emit(state.copyWith(settings: LoadState.fromQuery(queryState)));
  }

  void reset() {
    _binding?.dispose();
    _binding = null;
    _queryClient.removeQueries(WhitelabelKeys.all);
    if (!isClosed) emit(BrandingState(instance: state.instance));
  }

  @override
  Future<void> close() {
    _binding?.dispose();
    return super.close();
  }
}
