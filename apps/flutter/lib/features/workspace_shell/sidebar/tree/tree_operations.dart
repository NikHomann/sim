import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/creative_name.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_events.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/drop_logic.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_cubit.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_model.dart';
import 'package:sim_workflow/sim_workflow.dart' show generateUuidV4;

/// `/workspace/{ws}/w/{workflowId}` → the workflow id (`params.workflowId`).
String? workflowIdFromPath(String path) {
  final match = RegExp('^/workspace/[^/]+/w/([^/?#]+)').firstMatch(path);
  return match?.group(1);
}

/// The tree's mutations over the data cubits, with the navigation, scroll
/// events, selection resets and toasts the React hooks pair them with
/// (`use-workflow-operations`, `use-folder-operations`, `folder-item`,
/// `use-delete-*`, `use-duplicate-*`, `use-drag-drop`).
class TreeOperations {
  TreeOperations({
    required this.services,
    required this.workspaceId,
    math.Random? random,
    String Function()? idGenerator,
  }) : _random = random,
       _generateId = idGenerator ?? generateUuidV4;

  final SidebarServices services;
  final String workspaceId;
  final math.Random? _random;
  final String Function() _generateId;

  final ValueNotifier<bool> isCreatingWorkflow = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isCreatingFolder = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isDuplicating = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isDeleting = ValueNotifier<bool>(false);

  /// Set by [dispose] (a workspace switch rebinds the sidebar while
  /// requests may still be in flight); busy flags are no longer written.
  bool _disposed = false;

  void _setBusy(ValueNotifier<bool> flag, {required bool busy}) {
    if (!_disposed) flag.value = busy;
  }

  SidebarTreeCubit get tree => services.tree;

  /// The current tree over the cubits' cached lists.
  SidebarTree snapshot() => SidebarTree(
    workspaceId: workspaceId,
    folders: services.folders.state.items,
    workflows: services.workflows.state.items,
  );

  String? get activeWorkflowId =>
      workflowIdFromPath(services.navigator.location);

  String workflowHref(String id) => '/workspace/$workspaceId/w/$id';

  void _log(String message, Object error) =>
      developer.log(message, name: 'sim_app.sidebar', error: error);

  /// `handleCreateWorkflow` (`use-workflow-operations.ts:30-47`,
  /// `sidebar.tsx:1170-1177`) and `handleCreateWorkflowInFolder`
  /// (`folder-item.tsx:158-175`): optimistic create with a client id and a
  /// creative name, `markWorkflowCreating`, the parent folder expanded,
  /// navigation before the POST resolves, then the scroll-to-item event.
  void createWorkflow({String? folderId}) {
    final name = generateCreativeWorkflowName(_random);
    final id = _generateId();
    _setBusy(isCreatingWorkflow, busy: true);
    unawaited(
      services.workflows
          .create(name: name, id: id, folderId: folderId)
          .then<void>((_) {}, onError: (Object e) => _log('create workflow', e))
          .whenComplete(() => _setBusy(isCreatingWorkflow, busy: false)),
    );
    services.workflows.markWorkflowCreating(id);
    if (folderId != null) tree.setExpanded(folderId, expanded: true);
    services.navigator.go(workflowHref(id));
    SidebarEvents.scrollToItem(id);
  }

  /// Root "Create folder" (`use-folder-operations.ts:24-42`, "Folder N"
  /// from a fresh list) and "Create folder" in a folder
  /// (`folder-item.tsx:177-204`, "Subfolder N" among the parent's children,
  /// parent expanded, error toast). New folders are neither expanded nor
  /// renamed.
  Future<void> createFolder({String? parentId}) async {
    if (isCreatingFolder.value) return;
    _setBusy(isCreatingFolder, busy: true);
    try {
      final name = await _folderName(parentId);
      final created = await services.folders.create(
        name: name,
        parentId: parentId,
        id: _generateId(),
      );
      if (parentId != null && !tree.isClosed) {
        tree.setExpanded(parentId, expanded: true);
      }
      SidebarEvents.scrollToItem(created.id);
    } on Object catch (error) {
      _log('create folder', error);
      if (parentId != null) {
        services.toasts.error(
          error is ApiClientError && error.message.isNotEmpty
              ? error.message
              : 'Failed to create folder',
        );
      }
    } finally {
      _setBusy(isCreatingFolder, busy: false);
    }
  }

  Future<String> _folderName(String? parentId) async {
    final repository = services.foldersRepository;
    if (parentId == null) {
      if (repository != null) return repository.generateName(workspaceId);
      return FoldersRepository.nextFolderName(services.folders.state.items);
    }
    final folders = repository != null
        ? await repository.list(workspaceId: workspaceId)
        : services.folders.state.items;
    return nextIncrementalName(
      folders.where((f) => f.parentId == parentId).map((f) => f.name),
      'Subfolder',
    );
  }

  /// Workflow rename: optimistic `PUT`, rolled back on error (thrown).
  Future<void> renameWorkflow(String id, String name) =>
      services.workflows.update(id, WorkflowUpdate(name: name));

  /// Folder rename: non-optimistic `PUT ?resourceType=workflow` (thrown).
  Future<void> renameFolder(String id, String name) =>
      services.folders.update(id, FolderUpdate(name: name));

  /// Lock / Unlock (`workflow-item.tsx:179-186`, `folder-item.tsx:206-213`);
  /// refused while an ancestor folder holds the lock.
  void toggleWorkflowLock(WorkflowListItem workflow) {
    if (snapshot().workflowInheritedLocked(workflow)) return;
    unawaited(
      services.workflows
          .update(workflow.id, WorkflowUpdate(locked: !workflow.locked))
          .then<void>((_) {}, onError: (Object e) => _log('lock workflow', e)),
    );
  }

  void toggleFolderLock(Folder folder) {
    if (snapshot().folderInheritedLocked(folder)) return;
    unawaited(
      services.folders
          .update(folder.id, FolderUpdate(locked: !folder.locked))
          .then<void>((_) {}, onError: (Object e) => _log('lock folder', e)),
    );
  }

  /// Duplicate (`use-duplicate-workflow`, `use-duplicate-folder`,
  /// `use-duplicate-selection`): folders first, one at a time, as "X Copy"
  /// (then "X Copy 2"…) under the same parent; then workflows, one at a
  /// time, as "X (Copy)" in the same folder; the workflow selection is
  /// cleared (and the folder selection too when the selection hook ran: a
  /// mixed selection or several folders) and a single duplicated workflow
  /// (with no folders) is opened.
  Future<void> duplicate(CapturedSelection selection) async {
    if (isDuplicating.value) return;
    _setBusy(isDuplicating, busy: true);
    try {
      final current = snapshot();
      for (final folderId in selection.folderIds) {
        final folder = current.folders[folderId];
        if (folder == null) continue;
        final siblings = <String>{
          for (final f in services.folders.state.items)
            if (f.parentId == folder.parentId) f.name,
          folder.name,
        };
        await services.folders.duplicate(
          folderId,
          name: duplicateFolderName(folder.name, siblings),
          parentId: folder.parentId,
          sendParent: true,
          newId: _generateId(),
        );
      }
      final duplicated = <String>[];
      for (final workflowId in selection.workflowIds) {
        final source = current.workflow(workflowId);
        if (source == null) continue;
        final result = await services.workflows.duplicate(
          workflowId,
          name: '${source.name} (Copy)',
          description: source.description,
          folderId: source.folderId,
          sendFolder: true,
          newId: _generateId(),
        );
        duplicated.add(result.id);
      }
      tree.clearSelection();
      if (_usesSelectionHook(selection)) tree.clearFolderSelection();
      if (duplicated.length == 1 && selection.folderIds.isEmpty) {
        services.navigator.go(workflowHref(duplicated.single));
      }
    } on Object catch (error) {
      _log('duplicate', error);
    } finally {
      _setBusy(isDuplicating, busy: false);
    }
  }

  /// The menus run `use-*-selection` (which also clears the folder
  /// selection) for a mixed selection or several folders, else the single
  /// `use-delete-*` / `use-duplicate-*` hook (workflow selection only).
  static bool _usesSelectionHook(CapturedSelection selection) =>
      selection.isMixed || selection.folderIds.length > 1;

  /// Delete (`use-delete-workflow`, `use-delete-folder`,
  /// `use-delete-selection`). When the open workflow goes, navigation runs
  /// first: to the next remaining workflow after it in the cached list
  /// order, else the first remaining, else the workspace root. A single
  /// folder never navigates (mirrored as-is). Folders are deleted one at a
  /// time, then the remaining workflows in parallel; the workflow selection
  /// is cleared, the folder selection too for a mixed or multi-folder
  /// selection. Errors are rethrown so the modal stays open.
  Future<void> delete(CapturedSelection selection) async {
    if (isDeleting.value) return;
    _setBusy(isDeleting, busy: true);
    try {
      final list = [
        for (final w in services.workflows.state.items)
          if (w.workspaceId == workspaceId) w,
      ];
      final active = activeWorkflowId;
      final singleFolder =
          selection.folderIds.length == 1 && selection.workflowIds.isEmpty;
      final inFolders = singleFolder
          ? const <String>[]
          : [
              for (final w in list)
                if (w.folderId != null &&
                    selection.folderIds.contains(w.folderId))
                  w.id,
            ];
      final all = <String>{...selection.workflowIds, ...inFolders};
      final needsNavigation = active != null && all.contains(active);
      if (needsNavigation) {
        String? next;
        if (list.length > all.length) {
          final remaining = [
            for (final w in list)
              if (!all.contains(w.id)) w,
          ];
          final currentIndex = list.indexWhere((w) => w.id == active);
          final after = remaining.where(
            (w) => list.indexWhere((s) => s.id == w.id) > currentIndex,
          );
          next = after.isNotEmpty ? after.first.id : remaining.first.id;
        }
        services.navigator.go(
          next != null ? workflowHref(next) : '/workspace/$workspaceId',
        );
      }
      for (final folderId in selection.folderIds) {
        await services.folders.delete(folderId);
      }
      final standalone = selection.workflowIds.where(
        (id) => !inFolders.contains(id),
      );
      await Future.wait(standalone.map(services.workflows.delete));
      if (!tree.isClosed) {
        tree.clearSelection();
        if (_usesSelectionHook(selection)) tree.clearFolderSelection();
      }
    } finally {
      _setBusy(isDeleting, busy: false);
    }
  }

  /// The request half of `handleSelectionDrop`: both reorder `PUT`s are
  /// sent concurrently (`Promise.allSettled`); any rejection toasts "Only
  /// some items moved" (one of two failed) or "Failed to move items"; each
  /// cubit rolls its own slice back.
  Future<void> drop(DragSelection selection, DropIndicator indicator) async {
    final plan = planDrop(
      tree: snapshot(),
      selection: selection,
      indicator: indicator,
    );
    if (plan == null) return;
    final pending = <Future<Object?>>[
      if (plan.folderUpdates.isNotEmpty)
        services.folders.reorder(plan.folderUpdates),
      if (plan.workflowUpdates.isNotEmpty)
        services.workflows.reorder(plan.workflowUpdates),
    ];
    var failures = 0;
    await Future.wait(
      pending.map(
        (request) => request.then<void>(
          (_) {},
          onError: (Object error) {
            failures += 1;
            _log('reorder', error);
          },
        ),
      ),
    );
    if (failures == 0) {
      tree
        ..clearSelection()
        ..clearFolderSelection();
      return;
    }
    services.toasts.error(
      failures < pending.length
          ? 'Only some items moved'
          : 'Failed to move items',
    );
  }

  void dispose() {
    _disposed = true;
    isCreatingWorkflow.dispose();
    isCreatingFolder.dispose();
    isDuplicating.dispose();
    isDeleting.dispose();
  }
}
