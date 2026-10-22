import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';

/// `compareByOrder` (`sidebar/utils.ts:110-119`): `sortOrder` ascending, then
/// `createdAt` ascending (a missing date counts as 0), then the id. Ids are
/// compared by code unit; upstream uses `localeCompare`, which orders the
/// lowercase UUIDs the server issues identically.
int compareByOrder(
  ({num sortOrder, DateTime? createdAt, String id}) a,
  ({num sortOrder, DateTime? createdAt, String id}) b,
) {
  if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
  final timeA = a.createdAt?.millisecondsSinceEpoch ?? 0;
  final timeB = b.createdAt?.millisecondsSinceEpoch ?? 0;
  if (timeA != timeB) return timeA.compareTo(timeB);
  return a.id.compareTo(b.id);
}

/// One folder of the tree with its child folders (`FolderTreeNode`).
@immutable
class FolderNode {
  const FolderNode({
    required this.folder,
    required this.children,
    required this.level,
  });

  final Folder folder;
  final List<FolderNode> children;
  final int level;

  String get id => folder.id;
}

/// One sibling slot of the tree: folders and workflows share one ordering.
sealed class TreeEntry {
  const TreeEntry();

  String get id;
  num get sortOrder;
  DateTime? get createdAt;

  ({num sortOrder, DateTime? createdAt, String id}) get orderKey =>
      (sortOrder: sortOrder, createdAt: createdAt, id: id);
}

class TreeFolderEntry extends TreeEntry {
  const TreeFolderEntry(this.node);

  final FolderNode node;

  @override
  String get id => node.id;
  @override
  num get sortOrder => node.folder.sortOrder;
  @override
  DateTime? get createdAt => node.folder.createdAtDate;
}

class TreeWorkflowEntry extends TreeEntry {
  const TreeWorkflowEntry(this.workflow);

  final WorkflowListItem workflow;

  @override
  String get id => workflow.id;
  @override
  num get sortOrder => workflow.sortOrder;
  @override
  DateTime? get createdAt => workflow.createdAtDate;
}

/// The kind of a sibling in the reorder model (`SiblingItem.type`).
enum SiblingKind { folder, workflow }

/// `SiblingItem` of `use-drag-drop.ts`.
@immutable
class SiblingItem {
  const SiblingItem({
    required this.kind,
    required this.id,
    required this.sortOrder,
    required this.createdAt,
  });

  final SiblingKind kind;
  final String id;
  final num sortOrder;
  final DateTime? createdAt;

  ({num sortOrder, DateTime? createdAt, String id}) get orderKey =>
      (sortOrder: sortOrder, createdAt: createdAt, id: id);

  @override
  bool operator ==(Object other) =>
      other is SiblingItem &&
      other.kind == kind &&
      other.id == id &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(kind, id, sortOrder, createdAt);

  @override
  String toString() => 'SiblingItem(${kind.name} $id @$sortOrder)';
}

/// The sidebar's view of one workspace's folders and workflows: the folder
/// tree (`buildFolderTree`), the workflows grouped by folder
/// (`groupWorkflowsByFolder`), the interleaved sibling lists, the DFS id
/// orders the selection ranges walk, and the ancestor/descendant maps.
class SidebarTree {
  SidebarTree({
    required this.workspaceId,
    required List<Folder> folders,
    required List<WorkflowListItem> workflows,
  }) : folders = <String, Folder>{
         for (final f in folders)
           if (f.workspaceId == workspaceId) f.id: f,
       },
       workflows = <WorkflowListItem>[
         for (final w in workflows)
           if (w.workspaceId == workspaceId) w,
       ] {
    _build();
  }

  final String workspaceId;

  /// `useFolderMap` for this workspace.
  final Map<String, Folder> folders;

  /// This workspace's workflows in server order.
  final List<WorkflowListItem> workflows;

  late final List<FolderNode> rootFolders;
  final Map<String, FolderNode> _nodes = <String, FolderNode>{};
  final Map<String?, List<WorkflowListItem>> _workflowsByFolder =
      <String?, List<WorkflowListItem>>{};
  final List<String> orderedWorkflowIds = <String>[];
  final List<String> orderedFolderIds = <String>[];
  final Map<String, List<String>> folderAncestors = <String, List<String>>{};
  final Map<String, List<String>> folderDescendants = <String, List<String>>{};
  final Map<String, List<String>> folderDescendantWorkflows =
      <String, List<String>>{};
  final Map<String, List<String>> workflowAncestors = <String, List<String>>{};

  void _build() {
    List<FolderNode> build(String? parentId, int level) {
      final children =
          folders.values.where((f) => f.parentId == parentId).toList()
            ..sort((a, b) {
              final byOrder = a.sortOrder.compareTo(b.sortOrder);
              return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
            });
      return [
        for (final f in children)
          _nodes[f.id] = FolderNode(
            folder: f,
            children: build(f.id, level + 1),
            level: level,
          ),
      ];
    }

    rootFolders = build(null, 0);

    for (final w in workflows) {
      final key = w.folderId;
      (_workflowsByFolder[key] ??= <WorkflowListItem>[]).add(w);
    }
    for (final list in _workflowsByFolder.values) {
      list.sort(
        (a, b) => compareByOrder(
          (sortOrder: a.sortOrder, createdAt: a.createdAtDate, id: a.id),
          (sortOrder: b.sortOrder, createdAt: b.createdAtDate, id: b.id),
        ),
      );
    }

    void collect(List<TreeEntry> entries) {
      for (final entry in entries) {
        switch (entry) {
          case TreeWorkflowEntry(:final workflow):
            orderedWorkflowIds.add(workflow.id);
          case TreeFolderEntry(:final node):
            orderedFolderIds.add(node.id);
            collect(childrenOf(node.id));
        }
      }
    }

    collect(rootEntries);

    void maps(FolderNode node, List<String> ancestors) {
      folderAncestors[node.id] = ancestors;
      final workflowsHere = [
        for (final w
            in _workflowsByFolder[node.id] ?? const <WorkflowListItem>[])
          w.id,
      ];
      final descendants = <String>[];
      final descendantWorkflows = <String>[...workflowsHere];
      for (final child in node.children) {
        maps(child, [...ancestors, node.id]);
        descendants
          ..add(child.id)
          ..addAll(folderDescendants[child.id] ?? const <String>[]);
        descendantWorkflows.addAll(
          folderDescendantWorkflows[child.id] ?? const <String>[],
        );
      }
      folderDescendants[node.id] = descendants;
      folderDescendantWorkflows[node.id] = descendantWorkflows;
    }

    for (final node in rootFolders) {
      maps(node, const <String>[]);
    }
    for (final w in workflows) {
      final folderId = w.folderId;
      if (folderId != null && folderAncestors.containsKey(folderId)) {
        workflowAncestors[w.id] = [folderId, ...folderAncestors[folderId]!];
      }
    }
  }

  FolderNode? node(String folderId) => _nodes[folderId];

  /// The rendered workflows directly in [folderId] (`null` = root), sorted.
  List<WorkflowListItem> workflowsIn(String? folderId) =>
      _workflowsByFolder[folderId] ?? const <WorkflowListItem>[];

  /// `interleaveSiblings(folders, workflows)` of the root level.
  List<TreeEntry> get rootEntries =>
      _interleave(rootFolders, workflowsIn(null));

  /// `interleaveSiblings` of one folder's children.
  List<TreeEntry> childrenOf(String folderId) {
    final node = _nodes[folderId];
    if (node == null) return const <TreeEntry>[];
    return _interleave(node.children, workflowsIn(folderId));
  }

  bool hasChildren(String folderId) =>
      workflowsIn(folderId).isNotEmpty ||
      (_nodes[folderId]?.children.isNotEmpty ?? false);

  static List<TreeEntry> _interleave(
    List<FolderNode> folders,
    List<WorkflowListItem> workflows,
  ) {
    final entries = <TreeEntry>[
      for (final f in folders) TreeFolderEntry(f),
      for (final w in workflows) TreeWorkflowEntry(w),
    ]..sort((a, b) => compareByOrder(a.orderKey, b.orderKey));
    return entries;
  }

  /// `getFolderPath`: root-first ancestor chain ending at [folderId],
  /// truncated at the first missing link and guarded against cycles (an
  /// optimistic reorder can write one into the cache).
  List<Folder> folderPath(String? folderId) {
    final chain = <Folder>[];
    final visited = <String>{};
    var current = folderId;
    while (current != null && visited.add(current)) {
      final folder = folders[current];
      if (folder == null) break;
      chain.insert(0, folder);
      current = folder.parentId;
    }
    return chain;
  }

  /// `isFolderOrAncestorLocked(folderId)`.
  bool isFolderOrAncestorLocked(String? folderId) =>
      folderPath(folderId).any((f) => f.locked);

  /// `isFolderEffectivelyLocked`.
  bool folderEffectivelyLocked(Folder folder) =>
      folder.locked || isFolderOrAncestorLocked(folder.parentId);

  /// A locked ancestor (the folder's own flag excluded).
  bool folderInheritedLocked(Folder folder) =>
      isFolderOrAncestorLocked(folder.parentId);

  /// `isWorkflowEffectivelyLocked`.
  bool workflowEffectivelyLocked(WorkflowListItem workflow) =>
      workflow.locked || isFolderOrAncestorLocked(workflow.folderId);

  bool workflowInheritedLocked(WorkflowListItem workflow) =>
      isFolderOrAncestorLocked(workflow.folderId);

  WorkflowListItem? workflow(String id) {
    for (final w in workflows) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// `useCanDelete().canDeleteWorkflows`: refused when it would remove
  /// every workflow of the workspace.
  bool canDeleteWorkflows(Iterable<String> ids) {
    final present = workflows.map((w) => w.id).toSet();
    final deleting = ids.where(present.contains).length;
    return workflows.isNotEmpty && deleting < workflows.length;
  }

  /// `useCanDelete().canDeleteFolder`: empty folders always; otherwise only
  /// while workflows remain outside it.
  bool canDeleteFolder(String folderId) {
    final inside = _countWorkflowsIn(folderId, <String>{});
    if (inside == 0) return true;
    return inside < workflows.length;
  }

  int _countWorkflowsIn(String folderId, Set<String> seen) {
    if (!seen.add(folderId)) return 0;
    var count = workflows.where((w) => w.folderId == folderId).length;
    for (final f in folders.values) {
      if (f.parentId == folderId) count += _countWorkflowsIn(f.id, seen);
    }
    return count;
  }

  /// `collectWorkflowsInFolder(folderId).length > 0` (export / duplicate
  /// gating).
  bool folderHasWorkflows(String folderId) =>
      _countWorkflowsIn(folderId, <String>{}) > 0;

  /// The siblings of one folder scope (`getSiblingItems`), read from every
  /// folder and workflow of the workspace, sorted by [compareByOrder].
  List<SiblingItem> siblingsOf(String? folderId) {
    final items = <SiblingItem>[
      for (final f in folders.values)
        if (f.parentId == folderId)
          SiblingItem(
            kind: SiblingKind.folder,
            id: f.id,
            sortOrder: f.sortOrder,
            createdAt: f.createdAtDate,
          ),
      for (final w in workflows)
        if (w.folderId == folderId)
          SiblingItem(
            kind: SiblingKind.workflow,
            id: w.id,
            sortOrder: w.sortOrder,
            createdAt: w.createdAtDate,
          ),
    ]..sort((a, b) => compareByOrder(a.orderKey, b.orderKey));
    return items;
  }
}

/// `generateIncrementalName(entities, prefix)` (`lib/workspaces/naming.ts:20-33`).
String nextIncrementalName(Iterable<String> names, String prefix) {
  final pattern = RegExp('^${RegExp.escape(prefix)} (\\d+)\$');
  var highest = 0;
  for (final name in names) {
    final match = pattern.firstMatch(name);
    if (match == null) continue;
    final n = int.parse(match.group(1)!);
    if (n > highest) highest = n;
  }
  return '$prefix ${highest + 1}';
}

/// `generateDuplicateName` of `use-duplicate-folder.ts:30-41`: "X Copy",
/// then "X Copy 2", "X Copy 3"… avoiding [siblingNames].
String duplicateFolderName(String baseName, Set<String> siblingNames) {
  final trimmed = (baseName.isEmpty ? 'Untitled Folder' : baseName).trim();
  var candidate = '$trimmed Copy';
  var counter = 2;
  while (siblingNames.contains(candidate)) {
    candidate = '$trimmed Copy $counter';
    counter += 1;
  }
  return candidate;
}

/// `selectionActionLabel(action, count)` (`resource/selection-label.ts:11-22`).
String selectionActionLabel(String action, int selectedCount) =>
    selectedCount <= 1 ? action : '$action $selectedCount items';
