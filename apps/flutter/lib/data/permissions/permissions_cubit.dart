import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/core/load_state.dart';
import 'package:sim_app/data/core/mutations.dart';
import 'package:sim_app/data/core/query_keys.dart';
import 'package:sim_app/data/core/stable_flag.dart';

/// The persistent connection toasts of `WorkspacePermissionsProvider`
/// (`workspace-permissions-provider.tsx:231-234`).
enum PermissionToast {
  reconnecting('Reconnecting...', PermissionToastSlot.realtime),
  joiningWorkflow('Joining workflow...', PermissionToastSlot.realtime),
  connectionUnavailable('Connection unavailable', PermissionToastSlot.offline),
  unableToConnect(
    'Unable to connect to workflow',
    PermissionToastSlot.joinBlocked,
  )
  ;

  const PermissionToast(this.title, this.slot);

  final String title;

  /// Each `usePersistentErrorToast` call owns one slot: a slot shows at
  /// most one toast, and a new message in a slot replaces the old one.
  final PermissionToastSlot slot;
}

/// The three `usePersistentErrorToast` calls of the provider.
enum PermissionToastSlot { realtime, offline, joinBlocked }

/// `useUserPermissions` result.
class UserPermissions extends Equatable {
  const UserPermissions({
    this.canRead = false,
    this.canEdit = false,
    this.canAdmin = false,
    this.userPermissions = WorkspacePermission.read,
    this.isLoading = false,
    this.error,
    this.isOfflineMode = false,
  });

  final bool canRead;
  final bool canEdit;
  final bool canAdmin;
  final WorkspacePermission userPermissions;
  final bool isLoading;
  final String? error;
  final bool isOfflineMode;

  @override
  List<Object?> get props => [
    canRead,
    canEdit,
    canAdmin,
    userPermissions,
    isLoading,
    error,
    isOfflineMode,
  ];
}

/// State of [PermissionsCubit].
class PermissionsState extends Equatable {
  const PermissionsState({
    this.workspaceId,
    this.permissions = const LoadState(),
    this.sessionEmail,
    this.hasOperationError = false,
    this.isReconnecting = false,
    this.isRetryingWorkflowJoin = false,
    this.blockedJoinWorkflowId,
    this.currentWorkflowId,
    this.isFileViewer = false,
    this.reconnectingStable = false,
  });

  final String? workspaceId;
  final LoadState<WorkspacePermissions> permissions;
  final String? sessionEmail;

  /// `useOperationQueueStore.hasOperationError`.
  final bool hasOperationError;
  final bool isReconnecting;
  final bool isRetryingWorkflowJoin;
  final String? blockedJoinWorkflowId;
  final String? currentWorkflowId;
  final bool isFileViewer;

  /// `isReconnecting` smoothed by the 2000 ms / 1500 ms stable flag.
  final bool reconnectingStable;

  WorkspacePermissions? get workspacePermissions => permissions.data;
  bool get permissionsLoading => permissions.isLoading;

  /// `permissionsError`: the `fetchWorkspacePermissions` rethrow messages
  /// for 404 and 401, else the error message.
  String? get permissionsError => switch (permissions.error) {
    null => null,
    final ApiClientError e when e.status == 404 =>
      'Workspace not found or access denied',
    final ApiClientError e when e.status == 401 => 'Authentication required',
    final ApiClientError e => e.message,
    final Object e => '$e',
  };

  bool get isOfflineMode => hasOperationError;
  bool get isJoinBlocked =>
      blockedJoinWorkflowId != null &&
      blockedJoinWorkflowId == currentWorkflowId;

  /// `useUserPermissions` (`use-user-permissions.ts:50-101`), with offline
  /// mode and a blocked join forcing read-only.
  UserPermissions get userPermissions {
    final base = _baseUserPermissions;
    if (isOfflineMode || isJoinBlocked) {
      return UserPermissions(
        canRead: base.canRead,
        userPermissions: base.userPermissions,
        isLoading: base.isLoading,
        error: base.error,
        isOfflineMode: isOfflineMode,
      );
    }
    return base;
  }

  UserPermissions get _baseUserPermissions {
    if (permissionsLoading) {
      return const UserPermissions(isLoading: true);
    }
    final data = workspacePermissions;
    final viewer = data?.viewer?.permissionType;
    if (viewer != null) {
      return UserPermissions(
        canRead: true,
        canEdit:
            viewer == WorkspacePermission.write ||
            viewer == WorkspacePermission.admin,
        canAdmin: viewer == WorkspacePermission.admin,
        userPermissions: viewer,
        error: permissionsError,
      );
    }
    final email = sessionEmail?.toLowerCase();
    WorkspaceUser? current;
    for (final user in data?.users ?? const <WorkspaceUser>[]) {
      if (email != null && user.email.toLowerCase() == email) {
        current = user;
        break;
      }
    }
    if (current == null) {
      return UserPermissions(
        error: permissionsError ?? 'User not found in workspace',
      );
    }
    final perms = current.permissionType;
    return UserPermissions(
      canRead: true,
      canEdit:
          perms == WorkspacePermission.write ||
          perms == WorkspacePermission.admin,
      canAdmin: perms == WorkspacePermission.admin,
      userPermissions: perms,
      error: permissionsError,
    );
  }

  /// The one realtime-status slot (`realtimeStatusMessage`,
  /// `workspace-permissions-provider.tsx:142-149`): nothing while offline or
  /// on a file viewer, else "Reconnecting..." over "Joining workflow...".
  PermissionToast? get realtimeToast {
    if (isOfflineMode || isFileViewer) return null;
    if (reconnectingStable) return PermissionToast.reconnecting;
    if (isRetryingWorkflowJoin) return PermissionToast.joiningWorkflow;
    return null;
  }

  /// The toasts to show, in display order: the realtime slot, then the
  /// offline and join-blocked toasts (shown on file viewers too).
  List<PermissionToast> get toasts {
    final realtime = realtimeToast;
    return [
      ?realtime,
      if (isOfflineMode) PermissionToast.connectionUnavailable,
      if (isJoinBlocked) PermissionToast.unableToConnect,
    ];
  }

  PermissionsState copyWith({
    String? workspaceId,
    LoadState<WorkspacePermissions>? permissions,
    String? sessionEmail,
    bool? hasOperationError,
    bool? isReconnecting,
    bool? isRetryingWorkflowJoin,
    String? blockedJoinWorkflowId,
    bool clearBlockedJoin = false,
    String? currentWorkflowId,
    bool clearCurrentWorkflow = false,
    bool? isFileViewer,
    bool? reconnectingStable,
  }) => PermissionsState(
    workspaceId: workspaceId ?? this.workspaceId,
    permissions: permissions ?? this.permissions,
    sessionEmail: sessionEmail ?? this.sessionEmail,
    hasOperationError: hasOperationError ?? this.hasOperationError,
    isReconnecting: isReconnecting ?? this.isReconnecting,
    isRetryingWorkflowJoin:
        isRetryingWorkflowJoin ?? this.isRetryingWorkflowJoin,
    blockedJoinWorkflowId: clearBlockedJoin
        ? null
        : (blockedJoinWorkflowId ?? this.blockedJoinWorkflowId),
    currentWorkflowId: clearCurrentWorkflow
        ? null
        : (currentWorkflowId ?? this.currentWorkflowId),
    isFileViewer: isFileViewer ?? this.isFileViewer,
    reconnectingStable: reconnectingStable ?? this.reconnectingStable,
  );

  @override
  List<Object?> get props => [
    workspaceId,
    permissions,
    sessionEmail,
    hasOperationError,
    isReconnecting,
    isRetryingWorkflowJoin,
    blockedJoinWorkflowId,
    currentWorkflowId,
    isFileViewer,
    reconnectingStable,
  ];
}

/// `WorkspacePermissionsProvider` (spec §4.3, §4.9, §7): the permissions
/// query (stale 30 s), `useUserPermissions`, the offline / join-blocked
/// read-only overrides and the persistent toasts with the "Reconnecting..."
/// anti-flicker (2000 ms delay, 1500 ms minimum).
class PermissionsCubit extends Cubit<PermissionsState> {
  PermissionsCubit({
    required WorkspacesRepository workspaces,
    required QueryClient queryClient,
    Duration reconnectingDelay = const Duration(milliseconds: 2000),
    Duration reconnectingMinVisible = const Duration(milliseconds: 1500),
  }) : _workspaces = workspaces,
       _queryClient = queryClient,
       super(const PermissionsState()) {
    _reconnecting = StableFlagController(
      ({required active}) {
        if (!isClosed) emit(state.copyWith(reconnectingStable: active));
      },
      delay: reconnectingDelay,
      minVisible: reconnectingMinVisible,
    );
  }

  final WorkspacesRepository _workspaces;
  final QueryClient _queryClient;
  late final StableFlagController _reconnecting;
  QueryBinding<WorkspacePermissions>? _binding;

  /// The toasts as a stream the shell shows (distinct lists only).
  Stream<List<PermissionToast>> get toasts =>
      stream.map((s) => s.toasts).distinct(_sameToasts);

  static bool _sameToasts(List<PermissionToast> a, List<PermissionToast> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Binds to [workspaceId] and fetches when stale.
  Future<WorkspacePermissions?> load(String workspaceId) async {
    if (state.workspaceId != workspaceId || _binding == null) {
      _binding?.dispose();
      final query = _queryClient.query<WorkspacePermissions>(
        WorkspaceKeys.permissions(workspaceId),
        (token) => _workspaces.permissions(workspaceId, cancelToken: token),
        staleTime: StaleTimes.workspacePermissions,
      );
      _binding = QueryBinding(query, _onQueryState);
      emit(
        state.copyWith(
          workspaceId: workspaceId,
          permissions: LoadState.fromQuery(query.state),
        ),
      );
    }
    try {
      return await _binding!.fetch();
    } on Object {
      return null;
    }
  }

  void _onQueryState(QueryState<WorkspacePermissions> queryState) {
    if (isClosed) return;
    emit(state.copyWith(permissions: LoadState.fromQuery(queryState)));
  }

  /// `refetchPermissions`.
  Future<void> refetch() async {
    try {
      await _binding?.refetch();
    } on Object {
      // Surfaced on the state.
    }
  }

  /// `updatePermissions` (`setQueryData`).
  void updatePermissions(WorkspacePermissions permissions) {
    final id = state.workspaceId;
    if (id == null) return;
    _queryClient.setQueryData(WorkspaceKeys.permissions(id), permissions);
  }

  void setSessionEmail(String? email) =>
      emit(state.copyWith(sessionEmail: email));

  /// The operation queue's error flag (`isOfflineMode`).
  void setOperationError({required bool hasError}) =>
      emit(state.copyWith(hasOperationError: hasError));

  /// The socket provider's flags.
  void setSocketState({
    bool? isReconnecting,
    bool? isRetryingWorkflowJoin,
    String? blockedJoinWorkflowId,
    bool clearBlockedJoin = false,
  }) {
    emit(
      state.copyWith(
        isReconnecting: isReconnecting,
        isRetryingWorkflowJoin: isRetryingWorkflowJoin,
        blockedJoinWorkflowId: blockedJoinWorkflowId,
        clearBlockedJoin: clearBlockedJoin,
      ),
    );
    if (isReconnecting != null) _reconnecting.setValue(value: isReconnecting);
  }

  /// The route's workflow id (`urlWorkflowId`) and file-viewer flag.
  void setRoute({String? workflowId, bool? isFileViewer}) => emit(
    state.copyWith(
      currentWorkflowId: workflowId,
      clearCurrentWorkflow: workflowId == null,
      isFileViewer: isFileViewer,
    ),
  );

  void clear() {
    _binding?.dispose();
    _binding = null;
    _reconnecting.setValue(value: false);
    if (!isClosed) emit(const PermissionsState());
  }

  void reset() {
    clear();
    _queryClient.removeQueries(WorkspaceKeys.details());
  }

  @override
  Future<void> close() {
    _reconnecting.dispose();
    _binding?.dispose();
    return super.close();
  }
}
