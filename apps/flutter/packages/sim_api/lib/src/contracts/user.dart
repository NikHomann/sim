/// Wire shapes of `apps/sim/lib/api/contracts/user.ts` used in Phase 1
/// (`generated/contracts/user.schema.json`): profile and settings.
library;

import 'package:sim_api/src/contracts/json.dart';

/// `GET /api/users/me/profile` → `user` (`user.ts:8-14`).
class UserProfile extends ContractValue {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.image,
    this.emailVerified,
  });

  factory UserProfile.fromJson(JsonObject json) => UserProfile(
    id: json.string('id'),
    name: json.string('name'),
    email: json.string('email'),
    image: json.stringOrNull('image'),
    emailVerified: json.boolOrNull('emailVerified'),
  );

  final String id;
  final String name;
  final String email;
  final String? image;
  final bool? emailVerified;

  UserProfile copyWith({
    String? name,
    String? image,
    bool clearImage = false,
  }) => UserProfile(
    id: id,
    name: name ?? this.name,
    email: email,
    image: clearImage ? null : (image ?? this.image),
    emailVerified: emailVerified,
  );

  @override
  List<Object?> get props => [id, name, email, image, emailVerified];

  @override
  JsonObject toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'image': image,
    'emailVerified': ?emailVerified,
  };
}

/// `theme` of the user settings.
enum ThemeSetting { system, light, dark }

/// `emailPreferences` of the user settings.
class EmailPreferences extends ContractValue {
  const EmailPreferences({
    this.unsubscribeAll,
    this.unsubscribeMarketing,
    this.unsubscribeUpdates,
    this.unsubscribeNotifications,
  });

  factory EmailPreferences.fromJson(JsonObject json) => EmailPreferences(
    unsubscribeAll: json.boolOrNull('unsubscribeAll'),
    unsubscribeMarketing: json.boolOrNull('unsubscribeMarketing'),
    unsubscribeUpdates: json.boolOrNull('unsubscribeUpdates'),
    unsubscribeNotifications: json.boolOrNull('unsubscribeNotifications'),
  );

  final bool? unsubscribeAll;
  final bool? unsubscribeMarketing;
  final bool? unsubscribeUpdates;
  final bool? unsubscribeNotifications;

  @override
  List<Object?> get props => [
    unsubscribeAll,
    unsubscribeMarketing,
    unsubscribeUpdates,
    unsubscribeNotifications,
  ];

  @override
  JsonObject toJson() => {
    'unsubscribeAll': ?unsubscribeAll,
    'unsubscribeMarketing': ?unsubscribeMarketing,
    'unsubscribeUpdates': ?unsubscribeUpdates,
    'unsubscribeNotifications': ?unsubscribeNotifications,
  };
}

/// `userSettingsApiSchema` (`user.ts:136-156`): the `data` of
/// `GET /api/users/me/settings`. Defaults follow the zod schema.
class UserSettings extends ContractValue {
  const UserSettings({
    this.theme = ThemeSetting.system,
    this.autoConnect = true,
    this.telemetryEnabled = true,
    this.emailPreferences = const EmailPreferences(),
    this.billingUsageNotificationsEnabled = true,
    this.superUserModeEnabled = false,
    this.mothershipEnvironment = 'default',
    this.errorNotificationsEnabled = true,
    this.snapToGridSize = 0,
    this.showActionBar = true,
    this.autoFocusOnClick = true,
    this.copilotAutoAllowedTools = const [],
    this.timezone,
    this.lastActiveWorkspaceId,
  });

  factory UserSettings.fromJson(JsonObject json) => UserSettings(
    theme: json.enumOrNull('theme', ThemeSetting.values) ?? ThemeSetting.system,
    autoConnect: json.boolOr('autoConnect', fallback: true),
    telemetryEnabled: json.boolOr('telemetryEnabled', fallback: true),
    emailPreferences: switch (json.objectOrNull('emailPreferences')) {
      final prefs? => EmailPreferences.fromJson(prefs),
      null => const EmailPreferences(),
    },
    billingUsageNotificationsEnabled: json.boolOr(
      'billingUsageNotificationsEnabled',
      fallback: true,
    ),
    superUserModeEnabled: json.boolOr('superUserModeEnabled', fallback: false),
    mothershipEnvironment: json.string('mothershipEnvironment'),
    errorNotificationsEnabled: json.boolOr(
      'errorNotificationsEnabled',
      fallback: true,
    ),
    snapToGridSize: json.numOrNull('snapToGridSize') ?? 0,
    showActionBar: json.boolOr('showActionBar', fallback: true),
    autoFocusOnClick: json.boolOr('autoFocusOnClick', fallback: true),
    copilotAutoAllowedTools: json.stringList('copilotAutoAllowedTools'),
    timezone: json.stringOrNull('timezone'),
    lastActiveWorkspaceId: json.stringOrNull('lastActiveWorkspaceId'),
  );

  final ThemeSetting theme;
  final bool autoConnect;
  final bool telemetryEnabled;
  final EmailPreferences emailPreferences;
  final bool billingUsageNotificationsEnabled;
  final bool superUserModeEnabled;

  /// `'default' | 'dev' | 'staging' | 'prod'`.
  final String mothershipEnvironment;
  final bool errorNotificationsEnabled;
  final num snapToGridSize;
  final bool showActionBar;
  final bool autoFocusOnClick;
  final List<String> copilotAutoAllowedTools;
  final String? timezone;
  final String? lastActiveWorkspaceId;

  /// `{...previous, [key]: value}` by wire key, the optimistic update of
  /// `useUpdateGeneralSetting`; unknown keys leave the settings unchanged.
  UserSettings withSetting(String key, Object? value) =>
      UserSettings.fromJson({...toJson(), key: value});

  @override
  List<Object?> get props => [
    theme,
    autoConnect,
    telemetryEnabled,
    emailPreferences,
    billingUsageNotificationsEnabled,
    superUserModeEnabled,
    mothershipEnvironment,
    errorNotificationsEnabled,
    snapToGridSize,
    showActionBar,
    autoFocusOnClick,
    copilotAutoAllowedTools,
    timezone,
    lastActiveWorkspaceId,
  ];

  @override
  JsonObject toJson() => {
    'theme': theme.name,
    'autoConnect': autoConnect,
    'telemetryEnabled': telemetryEnabled,
    'emailPreferences': emailPreferences.toJson(),
    'billingUsageNotificationsEnabled': billingUsageNotificationsEnabled,
    'superUserModeEnabled': superUserModeEnabled,
    'mothershipEnvironment': mothershipEnvironment,
    'errorNotificationsEnabled': errorNotificationsEnabled,
    'snapToGridSize': snapToGridSize,
    'showActionBar': showActionBar,
    'autoFocusOnClick': autoFocusOnClick,
    'copilotAutoAllowedTools': copilotAutoAllowedTools,
    'timezone': timezone,
    'lastActiveWorkspaceId': lastActiveWorkspaceId,
  };
}
