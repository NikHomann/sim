import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';

/// The permission-group toggles the shell reads (`usePermissionConfig().config`
/// of `GET /api/permission-groups/user`): hidden tabs drop their sidebar
/// rows and palette pages, `hideCopilot` drops the Chats section, and
/// `disableInvitations` turns the switcher's invite into the billing link.
/// The one type the sidebar, the palette and the switcher share.
@immutable
class ShellPermissionConfig {
  const ShellPermissionConfig({
    this.hideCopilot = false,
    this.hideFilesTab = false,
    this.hideIntegrationsTab = false,
    this.hideTablesTab = false,
    this.hideKnowledgeBaseTab = false,
    this.disableInvitations = false,
  });

  /// The response body's `config`; `null` (no group applies) and missing
  /// keys hide nothing (`DEFAULT_PERMISSION_GROUP_CONFIG`).
  factory ShellPermissionConfig.fromResponse(Object? json) {
    final config = json is Map ? json['config'] : null;
    if (config is! Map) return const ShellPermissionConfig();
    bool flag(String key) => config[key] == true;
    return ShellPermissionConfig(
      hideCopilot: flag('hideCopilot'),
      hideFilesTab: flag('hideFilesTab'),
      hideIntegrationsTab: flag('hideIntegrationsTab'),
      hideTablesTab: flag('hideTablesTab'),
      hideKnowledgeBaseTab: flag('hideKnowledgeBaseTab'),
      disableInvitations: flag('disableInvitations'),
    );
  }

  final bool hideCopilot;
  final bool hideFilesTab;
  final bool hideIntegrationsTab;
  final bool hideTablesTab;
  final bool hideKnowledgeBaseTab;
  final bool disableInvitations;

  @override
  bool operator ==(Object other) =>
      other is ShellPermissionConfig &&
      other.hideCopilot == hideCopilot &&
      other.hideFilesTab == hideFilesTab &&
      other.hideIntegrationsTab == hideIntegrationsTab &&
      other.hideTablesTab == hideTablesTab &&
      other.hideKnowledgeBaseTab == hideKnowledgeBaseTab &&
      other.disableInvitations == disableInvitations;

  @override
  int get hashCode => Object.hash(
    hideCopilot,
    hideFilesTab,
    hideIntegrationsTab,
    hideTablesTab,
    hideKnowledgeBaseTab,
    disableInvitations,
  );
}

/// Loads [ShellPermissionConfig] per workspace (`useUserPermissionConfig`):
/// one request per workspace for the life of the source, the default config
/// until it answers or when it fails.
class ShellPermissionConfigSource {
  ShellPermissionConfigSource(this._fetch);

  /// `GET /api/permission-groups/user?workspaceId=`.
  factory ShellPermissionConfigSource.http(SimHttpClient http) =>
      ShellPermissionConfigSource(
        (workspaceId) => http.requestJson<ShellPermissionConfig>(
          method: 'GET',
          path: '/api/permission-groups/user',
          query: <String, Object?>{'workspaceId': workspaceId},
          decode: ShellPermissionConfig.fromResponse,
        ),
      );

  /// Always [config] (tests, and builds without an HTTP client).
  factory ShellPermissionConfigSource.fixed([
    ShellPermissionConfig config = const ShellPermissionConfig(),
  ]) => ShellPermissionConfigSource((_) async => config);

  final Future<ShellPermissionConfig> Function(String workspaceId) _fetch;
  final Map<String, ValueNotifier<ShellPermissionConfig>> _byWorkspace =
      <String, ValueNotifier<ShellPermissionConfig>>{};

  /// The config of [workspaceId]; the first call starts the request.
  ValueListenable<ShellPermissionConfig> of(String workspaceId) {
    final existing = _byWorkspace[workspaceId];
    if (existing != null) return existing;
    final notifier = ValueNotifier<ShellPermissionConfig>(
      const ShellPermissionConfig(),
    );
    _byWorkspace[workspaceId] = notifier;
    unawaited(
      _fetch(workspaceId).then(
        (config) => notifier.value = config,
        onError: (Object error) => developer.log(
          'permission config',
          name: 'sim_app.shell',
          error: error,
        ),
      ),
    );
    return notifier;
  }
}

ShellPermissionConfigSource? _sharedSource;

/// The app-wide [ShellPermissionConfigSource] over the locator's HTTP
/// client. Sign-out (`resetUserData`) drops it with the other user data.
ShellPermissionConfigSource get sharedPermissionConfigs {
  final existing = _sharedSource;
  if (existing != null) return existing;
  if (locator.isRegistered<UserDataResetRegistry>()) {
    locator<UserDataResetRegistry>().register(resetSharedPermissionConfigs);
  }
  return _sharedSource = locator.isRegistered<SimHttpClient>()
      ? ShellPermissionConfigSource.http(locator<SimHttpClient>())
      : ShellPermissionConfigSource.fixed();
}

/// Forgets the app-wide source (sign-out, tests).
void resetSharedPermissionConfigs() => _sharedSource = null;
