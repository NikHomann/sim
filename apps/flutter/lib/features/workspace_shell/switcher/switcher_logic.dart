/// The workspace switcher's rules, free of widgets
/// (`workspace-header.tsx`, `workspace-context-menu.tsx`,
/// `use-workspace-management.ts`).
library;

import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';

/// `WORKSPACE_SEARCH_THRESHOLD`: the search field appears at six or more
/// workspaces.
const int workspaceSearchThreshold = 6;

/// `resolveWorkspaceSwitchHref`: `/workspace/{target}`, or the same
/// settings section of the target when switching from a settings page.
/// `null` for a settings path without a section, where upstream throws and
/// the switch never navigates.
String? resolveWorkspaceSwitchHref({
  required String pathname,
  required String currentWorkspaceId,
  required String targetWorkspaceId,
}) {
  final target = '/workspace/$targetWorkspaceId';
  final settingsPrefix = '/workspace/$currentWorkspaceId/settings/';
  if (!pathname.startsWith(settingsPrefix)) return target;
  final section = pathname.substring(settingsPrefix.length).split('/').first;
  if (section.isEmpty) return null;
  return '$target/settings/$section';
}

/// `WorkspaceContextMenu`'s role policy.
@immutable
class WorkspaceMenuPolicy {
  const WorkspaceMenuPolicy({
    required this.canRename,
    required this.canUploadLogo,
    required this.canDelete,
    required this.showLeave,
  });

  /// Rename, Upload logo and Delete need `permissions === 'admin'`; Delete
  /// also needs a second workspace; Leave is hidden for the owner and for
  /// organization admins.
  factory WorkspaceMenuPolicy.of(
    Workspace workspace, {
    required int workspaceCount,
    required String? sessionUserId,
  }) {
    final admin = workspace.permissions == WorkspacePermission.admin;
    return WorkspaceMenuPolicy(
      canRename: admin,
      canUploadLogo: admin,
      canDelete: admin && workspaceCount > 1,
      showLeave:
          sessionUserId != null &&
          sessionUserId.isNotEmpty &&
          sessionUserId != workspace.ownerId &&
          !(workspace.isOrgAdmin ?? false),
    );
  }

  final bool canRename;
  final bool canUploadLogo;
  final bool canDelete;
  final bool showLeave;
}

/// The search-mode list state of the switcher: the query, the highlighted
/// workspace (tracked by id so it survives reorders) and whether the
/// highlight is keyboard-driven (only then drawn, and only then is Enter
/// armed). Recreated on every open, so nothing persists across opens.
class SwitcherSearch {
  String query = '';
  String? highlightedId;
  bool keyboardNav = false;

  /// `filteredWorkspaces`: case-insensitive substring of the trimmed query,
  /// in the given (pinned-first) order; unfiltered below the threshold.
  List<Workspace> filter(List<Workspace> workspaces) {
    final showSearch = workspaces.length >= workspaceSearchThreshold;
    final needle = query.trim().toLowerCase();
    if (!showSearch || needle.isEmpty) return workspaces;
    return [
      for (final w in workspaces)
        if (w.name.toLowerCase().contains(needle)) w,
    ];
  }

  /// `activeIndex`: the highlighted row's index, or 0 when it is missing.
  int activeIndex(List<Workspace> filtered) {
    final id = highlightedId;
    if (id == null) return 0;
    final index = filtered.indexWhere((w) => w.id == id);
    return index < 0 ? 0 : index;
  }

  /// Seeds the highlight to the first result whenever the current one is
  /// absent (on open, or after typing filtered it out).
  void seed(List<Workspace> filtered) {
    if (filtered.isEmpty) return;
    final id = highlightedId;
    if (id == null || !filtered.any((w) => w.id == id)) {
      highlightedId = filtered.first.id;
    }
  }

  /// Typing is keyboard intent: the cursor shows on the top result.
  void type(String value) {
    keyboardNav = true;
    query = value;
  }

  /// ArrowDown (`step` 1) / ArrowUp (`step` -1), wrapping.
  void move(List<Workspace> filtered, int step) {
    if (filtered.isEmpty) return;
    keyboardNav = true;
    final n = filtered.length;
    highlightedId = filtered[(activeIndex(filtered) + step + n) % n].id;
  }

  /// Pointer movement over a row: retargets without drawing.
  void hover(String workspaceId) {
    keyboardNav = false;
    highlightedId = workspaceId;
  }

  /// Enter: the highlighted workspace, only once a cursor is on screen.
  Workspace? enterTarget(List<Workspace> filtered) {
    if (!keyboardNav || filtered.isEmpty) return null;
    return filtered[activeIndex(filtered)];
  }
}
