/// `GET /api/public-env` (`apps/sim/lib/api/contracts/public-env.ts`): the
/// flat `NEXT_PUBLIC_*` record and the `isTruthy`/`isFalsy` readers of
/// `lib/core/config/env.ts`, plus the browser fallback deployment shape of
/// `deployment-shape.ts:62-96` built from it.
library;

import 'package:sim_api/src/contracts/json.dart';
import 'package:sim_api/src/contracts/workspaces.dart';

/// The prefix every key must carry (`public-env.ts:17-19`).
const publicEnvPrefix = 'NEXT_PUBLIC_';

/// `isTruthy`: `'true' | '1'`, case-insensitive.
bool isTruthy(String? value) {
  final lower = value?.trim().toLowerCase();
  return lower == 'true' || lower == '1';
}

/// `isFalsy`: `'false' | '0'`, case-insensitive.
bool isFalsy(String? value) {
  final lower = value?.trim().toLowerCase();
  return lower == 'false' || lower == '0';
}

/// The `NEXT_PUBLIC_*` values of the server (`getEnv(key)` upstream).
class PublicEnv extends ContractValue {
  const PublicEnv(this.values);

  /// Decodes the flat object; a key without [publicEnvPrefix] or a non-string
  /// value fails validation like the zod contract.
  factory PublicEnv.fromJson(JsonObject json) {
    final values = <String, String>{};
    for (final entry in json.entries) {
      if (!entry.key.startsWith(publicEnvPrefix)) {
        throw ContractDecodeError(
          entry.key,
          'key lacks the $publicEnvPrefix prefix',
        );
      }
      final value = entry.value;
      if (value is! String) {
        throw ContractDecodeError(entry.key, 'expected a string');
      }
      values[entry.key] = value;
    }
    return PublicEnv(values);
  }

  static const empty = PublicEnv({});

  final Map<String, String> values;

  String? operator [](String key) => values[key];

  bool truthy(String key) => isTruthy(values[key]);
  bool falsy(String key) => isFalsy(values[key]);

  String? get appUrl => values['NEXT_PUBLIC_APP_URL'];
  String? get socketUrl => values['NEXT_PUBLIC_SOCKET_URL'];
  String? get turnstileSiteKey => values['NEXT_PUBLIC_TURNSTILE_SITE_KEY'];

  /// `!isFalsy(NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED)`: the login and
  /// signup pages show the email form unless it is explicitly off.
  bool get emailPasswordSignupEnabled =>
      !falsy('NEXT_PUBLIC_EMAIL_PASSWORD_SIGNUP_ENABLED');

  bool get ssoEnabled => truthy('NEXT_PUBLIC_SSO_ENABLED');
  bool get organizationsEnabled => truthy('NEXT_PUBLIC_ORGANIZATIONS_ENABLED');
  bool get enterpriseEnabled => truthy('NEXT_PUBLIC_ENTERPRISE_ENABLED');
  bool get invitationsDisabled => truthy('NEXT_PUBLIC_DISABLE_INVITATIONS');
  bool get publicApiDisabled => truthy('NEXT_PUBLIC_DISABLE_PUBLIC_API');
  bool get statusNoticePreview => truthy('NEXT_PUBLIC_STATUS_NOTICE_PREVIEW');
  bool get forkingEnabled => truthy('NEXT_PUBLIC_FORKING_ENABLED');

  /// `isHosted` (`env-flags.ts:49-65`): the app URL host is `sim.ai` or a
  /// subdomain, or `NEXT_PUBLIC_FORCE_HOSTED` (non-production only, which
  /// the client cannot tell; the flag is honoured as sent).
  bool get hosted {
    if (truthy('NEXT_PUBLIC_FORCE_HOSTED')) return true;
    final host = Uri.tryParse(appUrl ?? '')?.host ?? '';
    return host == 'sim.ai' || host.endsWith('.sim.ai');
  }

  /// `browserFallbackShape()` (`deployment-shape.ts:62-96`): the shape the
  /// `NEXT_PUBLIC_*` values resolve to, used outside a workspace and when
  /// the host context carries no `deployment`.
  DeploymentShape get fallbackDeploymentShape => DeploymentShape(
    hosted: hosted,
    billingEnabled: truthy('NEXT_PUBLIC_BILLING_ENABLED'),
    chatEnabled: !truthy('NEXT_PUBLIC_CHAT_DISABLED'),
    azureConfigured: truthy('NEXT_PUBLIC_AZURE_CONFIGURED'),
    cohereConfigured: truthy('NEXT_PUBLIC_COHERE_CONFIGURED'),
    features: DeploymentFeatures(
      accessControl: truthy('NEXT_PUBLIC_ACCESS_CONTROL_ENABLED'),
      auditLogs: truthy('NEXT_PUBLIC_AUDIT_LOGS_ENABLED'),
      customBlocks: truthy('NEXT_PUBLIC_CUSTOM_BLOCKS_ENABLED'),
      dataDrains: truthy('NEXT_PUBLIC_DATA_DRAINS_ENABLED'),
      dataRetention: truthy('NEXT_PUBLIC_DATA_RETENTION_ENABLED'),
      inbox: truthy('NEXT_PUBLIC_INBOX_ENABLED'),
      sandboxes: truthy('NEXT_PUBLIC_SANDBOXES_ENABLED'),
      scim: truthy('NEXT_PUBLIC_SCIM_ENABLED'),
      sessionPolicies: truthy('NEXT_PUBLIC_SESSION_POLICIES_ENABLED'),
      sso: truthy('NEXT_PUBLIC_SSO_ENABLED'),
      usageMonitoring: truthy('NEXT_PUBLIC_USAGE_MONITORING_ENABLED'),
      whitelabeling: truthy('NEXT_PUBLIC_WHITELABELING_ENABLED'),
    ),
  );

  @override
  List<Object?> get props => [values];

  @override
  JsonObject toJson() => Map<String, Object?>.of(values);
}
