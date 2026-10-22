/// The switcher's mutations and navigation (`use-workspace-management.ts`,
/// `sidebar.tsx:1192-1247`), over [WorkspacesCubit].
library;

import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/switcher/switcher_logic.dart';

/// The message a failed request carries (`getErrorMessage(error, fallback)`).
String errorMessage(Object error, String fallback) {
  if (error is ApiClientError && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return fallback;
}

/// Switch, create, rename, delete, leave and pin, with the switcher's
/// follow-ups (navigating away from a deleted or left current workspace).
/// Navigation is the sidebar's [SidebarNavigator], whose in-app `go` runs
/// behind the settings dirty guard.
class WorkspaceSwitcherActions {
  WorkspaceSwitcherActions({
    required this.workspaces,
    required SidebarNavigator Function() navigator,
    required this.currentWorkspaceId,
    this.sessionUserId,
  }) : _navigator = navigator;

  final WorkspacesCubit workspaces;
  final SidebarNavigator Function() _navigator;
  final String Function() currentWorkspaceId;
  final String? Function()? sessionUserId;

  SidebarNavigator get navigator => _navigator();

  /// `handleWorkspaceSwitch` + `switchWorkspace`: the current workspace is a
  /// no-op; otherwise the router moves to the target (keeping a settings
  /// section) through the settings guard.
  void switchTo(Workspace target) {
    final current = currentWorkspaceId();
    if (target.id == current) return;
    _go(target.id, current);
  }

  void _go(String targetId, String currentId) {
    final href = resolveWorkspaceSwitchHref(
      pathname: navigator.location,
      currentWorkspaceId: currentId,
      targetWorkspaceId: targetId,
    );
    if (href != null) navigator.go(href);
  }

  /// `window.open('/workspace/{id}', '_blank')`.
  void openInNewTab(Workspace target) =>
      navigator.openInNewTab('/workspace/${target.id}');

  /// `handleCreateWorkspace`: create, then switch to it. Throws for the
  /// modal to show.
  Future<void> create(String name) async {
    final created = await workspaces.create(name: name);
    final current = currentWorkspaceId();
    if (created.id != current) _go(created.id, current);
  }

  /// `updateWorkspace(id, { name })`: errors are reported as `false`.
  Future<bool> rename(String workspaceId, String name) =>
      workspaces.update(workspaceId, name: name);

  Workspace? _nextAfter(String removedId, List<Workspace> snapshot) {
    for (final w in snapshot) {
      if (w.id != removedId) return w;
    }
    return null;
  }

  /// `confirmDeleteWorkspace`: deleting the current workspace moves to the
  /// first other one. Errors are swallowed (logged upstream).
  Future<void> delete(Workspace target) async {
    final snapshot = workspaces.state.ordered;
    try {
      await workspaces.delete(target.id);
    } on Object {
      return;
    }
    final current = currentWorkspaceId();
    if (target.id == current) {
      final next = _nextAfter(target.id, snapshot);
      if (next != null) _go(next.id, current);
    }
  }

  /// `handleLeaveWorkspace`: leaving the current workspace moves to the
  /// first other one. Rethrows for the caller's toast.
  Future<void> leave(Workspace target) async {
    final userId = sessionUserId?.call();
    if (userId == null || userId.isEmpty) return;
    final snapshot = workspaces.state.ordered;
    await workspaces.leave(workspaceId: target.id, userId: userId);
    final current = currentWorkspaceId();
    if (target.id == current) {
      final next = _nextAfter(target.id, snapshot);
      if (next != null) _go(next.id, current);
    }
  }

  /// `toggleWorkspacePin`: flips the cached pin state; a failed request
  /// (already rolled back by the cubit) is not surfaced.
  Future<void> togglePin(String workspaceId) async {
    final pinned = !workspaces.state.pinnedIds.contains(workspaceId);
    try {
      await workspaces.togglePin(workspaceId, pinned: pinned);
    } on Object {
      // The optimistic toggle was reverted; upstream only logs.
    }
  }
}
