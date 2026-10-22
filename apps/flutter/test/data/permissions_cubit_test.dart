// Failure modes of PermissionsCubit (spec §4.3, §4.9, §7, §10 #37-38):
// 1. "Reconnecting..." appears only after `isReconnecting` held for
//    2000 ms: a 1500 ms blip never shows it; once shown it stays at least
//    1500 ms even when the flag clears at once (fake clock and timers);
// 2. `viewer.permissionType` drives canRead/canEdit/canAdmin; without the
//    viewer field the users list is scanned by the session email
//    (case-insensitive); an unknown viewer reads nothing and carries
//    "User not found in workspace";
// 3. offline mode and a blocked join for the current workflow force
//    read-only but keep canRead; a blocked join for another workflow does
//    not;
// 4. a 404 reads "Workspace not found or access denied", a 401
//    "Authentication required";
// 5. on a file viewer only the realtime slot is hidden (offline and join
//    blocked still show); the toast stream emits distinct lists;
// 6. `updatePermissions` writes the cache the query observes.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';

import 'support/mocks.dart';

void main() {
  late MockWorkspacesRepository workspaces;
  late QueryClient queryClient;

  setUp(() {
    workspaces = MockWorkspacesRepository();
    queryClient = QueryClient();
  });

  PermissionsCubit build() =>
      PermissionsCubit(workspaces: workspaces, queryClient: queryClient);

  void stubPermissions(WorkspacePermissions Function() answer) => when(
    () => workspaces.permissions(
      workspaceId,
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => answer());

  test('reconnecting toast: 2000 ms delay, 1500 ms minimum', () {
    fakeAsync((async) {
      final cubit = build();
      final seen = <List<PermissionToast>>[];
      final sub = cubit.toasts.listen(seen.add);

      cubit.setSocketState(isReconnecting: true);
      async.elapse(const Duration(milliseconds: 1500));
      cubit.setSocketState(isReconnecting: false);
      async.elapse(const Duration(milliseconds: 1000));
      expect(cubit.state.toasts, isEmpty, reason: 'a blip under 2000 ms');

      cubit.setSocketState(isReconnecting: true);
      async.elapse(const Duration(milliseconds: 1999));
      expect(cubit.state.toasts, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(cubit.state.toasts, [PermissionToast.reconnecting]);
      cubit.setSocketState(isReconnecting: false);
      async.elapse(const Duration(milliseconds: 1499));
      expect(cubit.state.toasts, [
        PermissionToast.reconnecting,
      ], reason: 'kept for 1500 ms');
      async.elapse(const Duration(milliseconds: 1));
      expect(cubit.state.toasts, isEmpty);
      async.flushMicrotasks();
      expect(seen, [
        <PermissionToast>[],
        [PermissionToast.reconnecting],
        <PermissionToast>[],
      ]);
      unawaited(sub.cancel());
      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });

  test('permission derivation: viewer field, email scan, not found', () async {
    stubPermissions(() => permissions(viewer: WorkspacePermission.write));
    final cubit = build()..setSessionEmail('Flutter-E2E@example.com');
    await cubit.load(workspaceId);
    expect(cubit.state.userPermissions.canEdit, isTrue);
    expect(cubit.state.userPermissions.canAdmin, isFalse);
    expect(cubit.state.userPermissions.canRead, isTrue);

    stubPermissions(
      () => permissions(
        users: [
          workspaceUser('flutter-e2e@example.com', WorkspacePermission.admin),
        ],
      ),
    );
    await cubit.refetch();
    expect(cubit.state.userPermissions.canAdmin, isTrue, reason: 'by email');

    stubPermissions(
      () => permissions(
        users: [
          workspaceUser('someone@example.com', WorkspacePermission.admin),
        ],
      ),
    );
    await cubit.refetch();
    expect(cubit.state.userPermissions.canRead, isFalse);
    expect(cubit.state.userPermissions.error, 'User not found in workspace');
    await cubit.close();
  });

  test('offline mode and blocked join force read-only', () async {
    stubPermissions(() => permissions(viewer: WorkspacePermission.admin));
    final cubit = build();
    await cubit.load(workspaceId);
    cubit.setOperationError(hasError: true);
    expect(cubit.state.userPermissions.canEdit, isFalse);
    expect(cubit.state.userPermissions.canAdmin, isFalse);
    expect(cubit.state.userPermissions.canRead, isTrue);
    expect(cubit.state.userPermissions.isOfflineMode, isTrue);
    expect(cubit.state.toasts, [PermissionToast.connectionUnavailable]);
    cubit
      ..setOperationError(hasError: false)
      ..setRoute(workflowId: 'wf-1')
      ..setSocketState(blockedJoinWorkflowId: 'wf-2');
    expect(cubit.state.userPermissions.canEdit, isTrue, reason: 'other wf');
    cubit.setSocketState(blockedJoinWorkflowId: 'wf-1');
    expect(cubit.state.userPermissions.canEdit, isFalse);
    expect(cubit.state.toasts, [PermissionToast.unableToConnect]);
    // Only the realtime slot is hidden on a file viewer (review finding 4).
    cubit
      ..setRoute(workflowId: 'wf-1', isFileViewer: true)
      ..setSocketState(isRetryingWorkflowJoin: true);
    expect(cubit.state.toasts, [PermissionToast.unableToConnect]);
    cubit.setRoute(isFileViewer: false);
    expect(cubit.state.toasts, [PermissionToast.joiningWorkflow]);
    await cubit.close();
  });

  test('404 and 401 messages', () async {
    when(
      () => workspaces.permissions(
        workspaceId,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => throw apiError(404, 'Workspace not found'));
    final cubit = build();
    await cubit.load(workspaceId);
    expect(
      cubit.state.permissionsError,
      'Workspace not found or access denied',
    );
    when(
      () => workspaces.permissions(
        workspaceId,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => throw apiError(401, 'Unauthorized'));
    await cubit.refetch();
    expect(cubit.state.permissionsError, 'Authentication required');
    await cubit.close();
  });

  test('updatePermissions writes the observed cache', () async {
    stubPermissions(() => permissions(viewer: WorkspacePermission.read));
    final cubit = build();
    await cubit.load(workspaceId);
    cubit.updatePermissions(permissions(viewer: WorkspacePermission.admin));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.userPermissions.canAdmin, isTrue);
    await cubit.close();
  });
}
