import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/home/home_http.dart';
import 'package:sim_app/features/home/shared/home_states.dart';
import 'package:sim_design/sim_design.dart';

/// A query's state as the boundary reads it.
@immutable
class AccessQueryState<T> {
  const AccessQueryState({
    this.data,
    this.error,
    this.isPending = true,
    this.isFetching = false,
  });

  final T? data;
  final Object? error;
  final bool isPending;
  final bool isFetching;

  bool get isError => error != null && data == null;

  /// `error.message`.
  String get errorMessage => switch (error) {
    final ApiClientError e => e.message,
    final Object e => '$e',
    null => '',
  };
}

/// One `discovery.entries[]` row for a feature target.
@immutable
class AccessEntry {
  const AccessEntry({
    required this.configKey,
    required this.state,
    this.label = '',
    this.reason,
    this.pendingRequestId,
  });

  final String configKey;

  /// `allowed`, `requestable`, or a denial state.
  final String state;
  final String label;
  final String? reason;
  final String? pendingRequestId;
}

/// `discoverAccessRequestsResponse`.
@immutable
class AccessDiscovery {
  const AccessDiscovery({
    required this.enabled,
    this.entries = const <AccessEntry>[],
  });

  final bool enabled;
  final List<AccessEntry> entries;
}

/// The two queries `PermissionAccessBoundary` reads: the user's permission
/// config (`GET /api/permission-groups/user?workspaceId=`) and the
/// workspace feature discovery (`GET /api/access-requests/discovery`).
abstract class HomeAccessSource {
  ValueListenable<AccessQueryState<Map<String, Object?>>> policy(
    String workspaceId,
  );
  Future<void> refetchPolicy(String workspaceId);
  ValueListenable<AccessQueryState<AccessDiscovery>> discovery(
    String workspaceId,
  );
  Future<void> refetchDiscovery(String workspaceId);
}

/// [HomeAccessSource] over [HomeHttp]. Without an HTTP client (builds with
/// no backend) the policy hides nothing and access requests are off.
class HttpHomeAccessSource implements HomeAccessSource {
  HttpHomeAccessSource(this.http);

  final HomeHttp? http;
  final Map<String, ValueNotifier<AccessQueryState<Map<String, Object?>>>>
  _policies = <String, ValueNotifier<AccessQueryState<Map<String, Object?>>>>{};
  final Map<String, ValueNotifier<AccessQueryState<AccessDiscovery>>>
  _discoveries = <String, ValueNotifier<AccessQueryState<AccessDiscovery>>>{};

  @override
  ValueListenable<AccessQueryState<Map<String, Object?>>> policy(
    String workspaceId,
  ) {
    final existing = _policies[workspaceId];
    if (existing != null) return existing;
    final notifier = _policies[workspaceId] =
        ValueNotifier<AccessQueryState<Map<String, Object?>>>(
          const AccessQueryState(),
        );
    unawaited(refetchPolicy(workspaceId));
    return notifier;
  }

  @override
  Future<void> refetchPolicy(String workspaceId) async {
    final notifier = _policies[workspaceId];
    if (notifier == null) return;
    final client = http;
    if (client == null) {
      notifier.value = const AccessQueryState(
        data: <String, Object?>{},
        isPending: false,
      );
      return;
    }
    final previous = notifier.value;
    notifier.value = AccessQueryState(
      data: previous.data,
      isPending: previous.data == null,
      isFetching: true,
    );
    try {
      final json = await client.get(
        '/api/permission-groups/user',
        query: <String, Object?>{'workspaceId': workspaceId},
      );
      final config = json is Map ? json['config'] : null;
      notifier.value = AccessQueryState(
        data: config is Map
            ? config.cast<String, Object?>()
            : const <String, Object?>{},
        isPending: false,
      );
    } on Object catch (error) {
      notifier.value = AccessQueryState(
        data: previous.data,
        error: error,
        isPending: false,
      );
    }
  }

  @override
  ValueListenable<AccessQueryState<AccessDiscovery>> discovery(
    String workspaceId,
  ) {
    final existing = _discoveries[workspaceId];
    if (existing != null) return existing;
    final notifier = _discoveries[workspaceId] =
        ValueNotifier<AccessQueryState<AccessDiscovery>>(
          const AccessQueryState(),
        );
    unawaited(refetchDiscovery(workspaceId));
    return notifier;
  }

  @override
  Future<void> refetchDiscovery(String workspaceId) async {
    final notifier = _discoveries[workspaceId];
    if (notifier == null) return;
    final client = http;
    if (client == null) {
      notifier.value = const AccessQueryState(
        data: AccessDiscovery(enabled: false),
        isPending: false,
      );
      return;
    }
    final previous = notifier.value;
    notifier.value = AccessQueryState(
      data: previous.data,
      isPending: previous.data == null,
      isFetching: true,
    );
    try {
      final json = await client.get(
        '/api/access-requests/discovery',
        query: <String, Object?>{
          'kind': 'workspace',
          'workspaceId': workspaceId,
          'targetKind': 'feature',
          'limit': 100,
          'offset': 0,
        },
      );
      final map = json is Map ? json : const <String, Object?>{};
      notifier.value = AccessQueryState(
        data: AccessDiscovery(
          enabled: map['enabled'] == true,
          entries: <AccessEntry>[
            for (final row in jsonList(map, 'entries'))
              if (row['target'] case final Map<Object?, Object?> target
                  when target['kind'] == 'feature' &&
                      target['configKey'] is String)
                AccessEntry(
                  configKey: target['configKey']! as String,
                  state: jsonString(row, 'state') ?? '',
                  label: jsonString(row, 'label') ?? '',
                  reason: jsonString(row, 'reason'),
                  pendingRequestId: jsonString(row, 'pendingRequestId'),
                ),
          ],
        ),
        isPending: false,
      );
    } on Object catch (error) {
      notifier.value = AccessQueryState(
        data: previous.data,
        error: error,
        isPending: false,
      );
    }
  }
}

/// `PermissionAccessBoundary configKey='hideCopilot'`
/// (`ee/access-requests/components/permission-access-boundary.tsx`):
///
/// * policy pending → "Checking access"; failed → "Unable to check access"
///   with "Try again";
/// * not blocked → [child];
/// * blocked: discovery pending/failed as above; access requests disabled →
///   [child] (the server enforces); entry allowed since → "Access updated"
///   with "Refresh access"; otherwise "Access required".
class PermissionAccessBoundary extends StatefulWidget {
  const PermissionAccessBoundary({
    required this.workspaceId,
    required this.source,
    required this.child,
    super.key,
    this.configKey = 'hideCopilot',
    this.onViewRequest,
    this.onRequestAccess,
  });

  final String workspaceId;
  final HomeAccessSource source;
  final String configKey;
  final Widget child;

  /// "View request" of a pending request.
  final ValueChanged<String>? onViewRequest;

  /// "Request access" (the request modal is a later phase).
  final ValueChanged<AccessEntry>? onRequestAccess;

  @override
  State<PermissionAccessBoundary> createState() =>
      _PermissionAccessBoundaryState();
}

class _PermissionAccessBoundaryState extends State<PermissionAccessBoundary> {
  late ValueListenable<AccessQueryState<Map<String, Object?>>> _policy;
  late ValueListenable<AccessQueryState<AccessDiscovery>> _discovery;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(PermissionAccessBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.source != widget.source) {
      _policy.removeListener(_changed);
      _discovery.removeListener(_changed);
      _bind();
    }
  }

  void _bind() {
    _policy = widget.source.policy(widget.workspaceId)..addListener(_changed);
    _discovery = widget.source.discovery(widget.workspaceId)
      ..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _policy.removeListener(_changed);
    _discovery.removeListener(_changed);
    super.dispose();
  }

  Widget _state(String title, String description, [List<Widget>? actions]) =>
      HomeEmptyState(
        title: title,
        description: description,
        actions: actions ?? const <Widget>[],
        parityId: 'home.access',
      );

  @override
  Widget build(BuildContext context) {
    final policy = _policy.value;
    if (policy.isPending) {
      return _state(
        'Checking access',
        'Loading your organization access policy.',
      );
    }
    if (policy.isError) {
      return _state('Unable to check access', policy.errorMessage, <Widget>[
        SimChip(
          label: 'Try again',
          onPressed: () =>
              unawaited(widget.source.refetchPolicy(widget.workspaceId)),
        ),
      ]);
    }
    final blocked = policy.data?[widget.configKey] == true;
    if (!blocked) return widget.child;
    final discovery = _discovery.value;
    if (discovery.isPending) {
      return _state(
        'Checking access',
        'Loading your organization access policy.',
      );
    }
    if (discovery.isError) {
      return _state('Unable to check access', discovery.errorMessage, <Widget>[
        SimChip(
          label: 'Try again',
          onPressed: () =>
              unawaited(widget.source.refetchDiscovery(widget.workspaceId)),
        ),
      ]);
    }
    final data = discovery.data ?? const AccessDiscovery(enabled: false);
    if (!data.enabled) return widget.child;
    AccessEntry? entry;
    for (final candidate in data.entries) {
      if (candidate.configKey == widget.configKey) {
        entry = candidate;
        break;
      }
    }
    if (entry?.state == 'allowed') {
      return _state(
        'Access updated',
        policy.isFetching
            ? 'Refreshing your permissions...'
            : 'Refresh to load your latest permissions.',
        <Widget>[
          SimChip(
            label: 'Refresh access',
            onPressed: () =>
                unawaited(widget.source.refetchPolicy(widget.workspaceId)),
          ),
        ],
      );
    }
    final requestable = entry != null && entry.state == 'requestable';
    final pending = entry?.pendingRequestId;
    return _state(
      'Access required',
      requestable
          ? (pending != null
                ? 'Your request is pending.'
                : 'Ask an administrator for access.')
          : (entry?.reason ?? 'Your organization restricts this feature.'),
      requestable
          ? <Widget>[
              if (pending != null)
                SimChip(
                  label: 'View request',
                  variant: SimChipVariant.primary,
                  semanticsLabel: 'View request for ${entry.label}',
                  onPressed: () => widget.onViewRequest?.call(pending),
                )
              else
                SimChip(
                  label: 'Request access',
                  variant: SimChipVariant.primary,
                  semanticsLabel: 'Request access to ${entry.label}',
                  onPressed: () => widget.onRequestAccess?.call(entry!),
                ),
            ]
          : null,
    );
  }
}
