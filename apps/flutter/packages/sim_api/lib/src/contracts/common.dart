/// Wire shapes of `apps/sim/lib/api/contracts/common.ts` used in Phase 1
/// (`generated/contracts/common.schema.json`): the `settings/allowed-*`
/// reads and the help form.
library;

import 'package:sim_api/src/contracts/json.dart';

/// `integrationAvailability[]` entry of `GET /api/settings/allowed-integrations`.
class IntegrationAvailability extends ContractValue {
  const IntegrationAvailability({
    required this.type,
    required this.state,
    required this.oauthAvailable,
  });

  factory IntegrationAvailability.fromJson(JsonObject json) =>
      IntegrationAvailability(
        type: json.string('type'),
        state: json.string('state'),
        oauthAvailable: json.boolean('oauthAvailable'),
      );

  final String type;

  /// `'ready' | 'limited' | 'unavailable' | 'misconfigured'`.
  final String state;
  final bool oauthAvailable;

  @override
  List<Object?> get props => [type, state, oauthAvailable];

  @override
  JsonObject toJson() => {
    'type': type,
    'state': state,
    'oauthAvailable': oauthAvailable,
  };
}

/// `oauthServiceAvailability[]` entry.
class OauthServiceAvailability extends ContractValue {
  const OauthServiceAvailability({
    required this.providerId,
    required this.available,
  });

  factory OauthServiceAvailability.fromJson(JsonObject json) =>
      OauthServiceAvailability(
        providerId: json.string('providerId'),
        available: json.boolean('available'),
      );

  final String providerId;
  final bool available;

  @override
  List<Object?> get props => [providerId, available];

  @override
  JsonObject toJson() => {'providerId': providerId, 'available': available};
}

/// `GET /api/settings/allowed-integrations` (`common.ts:56-84`).
class AllowedIntegrations extends ContractValue {
  const AllowedIntegrations({
    required this.allowedIntegrations,
    required this.integrationAvailability,
    required this.oauthServiceAvailability,
  });

  factory AllowedIntegrations.fromJson(JsonObject json) => AllowedIntegrations(
    allowedIntegrations: json.stringListOrNull('allowedIntegrations'),
    integrationAvailability: json
        .objectList('integrationAvailability')
        .map(IntegrationAvailability.fromJson)
        .toList(),
    oauthServiceAvailability: json
        .objectList('oauthServiceAvailability')
        .map(OauthServiceAvailability.fromJson)
        .toList(),
  );

  /// `null` means every integration is allowed.
  final List<String>? allowedIntegrations;
  final List<IntegrationAvailability> integrationAvailability;
  final List<OauthServiceAvailability> oauthServiceAvailability;

  @override
  List<Object?> get props => [
    allowedIntegrations,
    integrationAvailability,
    oauthServiceAvailability,
  ];

  @override
  JsonObject toJson() => {
    'allowedIntegrations': allowedIntegrations,
    'integrationAvailability': integrationAvailability
        .map((i) => i.toJson())
        .toList(),
    'oauthServiceAvailability': oauthServiceAvailability
        .map((o) => o.toJson())
        .toList(),
  };
}

/// `GET /api/settings/allowed-providers` → `{blacklistedProviders}`.
class AllowedProviders extends ContractValue {
  const AllowedProviders({required this.blacklistedProviders});

  factory AllowedProviders.fromJson(JsonObject json) => AllowedProviders(
    blacklistedProviders: json.stringList('blacklistedProviders'),
  );

  final List<String> blacklistedProviders;

  @override
  List<Object?> get props => [blacklistedProviders];

  @override
  JsonObject toJson() => {'blacklistedProviders': blacklistedProviders};
}

/// `type` of a help request (`common.ts:7-16`).
enum HelpRequestType implements WireNamed {
  bug('bug'),
  feedback('feedback'),
  featureRequest('feature_request'),
  other('other')
  ;

  const HelpRequestType(this.wireName);

  @override
  final String wireName;
}

/// One screenshot attached to a help request (`image_<n>` multipart part).
class HelpImage {
  const HelpImage({
    required this.filename,
    required this.bytes,
    required this.contentType,
  });

  final String filename;
  final List<int> bytes;

  /// `image/jpeg`, `image/png`, `image/webp` or `image/gif`.
  final String contentType;
}

/// The `POST /api/help` multipart form (`help/route.ts:29-117`).
class HelpRequest extends ContractValue {
  const HelpRequest({
    required this.subject,
    required this.message,
    required this.type,
    required this.userAgent,
    this.workspaceId,
    this.workflowId,
    this.images = const [],
  });

  final String subject;
  final String message;
  final HelpRequestType type;
  final String userAgent;
  final String? workspaceId;
  final String? workflowId;
  final List<HelpImage> images;

  @override
  List<Object?> get props => [
    subject,
    message,
    type,
    userAgent,
    workspaceId,
    workflowId,
    images.length,
  ];

  /// The text fields of the form (the images are added as file parts).
  @override
  Map<String, String> toJson() => {
    'subject': subject,
    'message': message,
    'type': type.wireName,
    'workspaceId': ?workspaceId,
    'workflowId': ?workflowId,
    'userAgent': userAgent,
  };
}
