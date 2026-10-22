import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/home/home_http.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/panel/resource_registry.dart';

/// One candidate row of the add-resource menu (`AvailableItem`).
@immutable
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    this.folderId,
    this.parentId,
    this.sortOrder,
    this.executionId,
    this.workflowName,
    this.time,
    this.status,
    this.path,
  });

  final String id;
  final String name;

  /// Files: the canonical VFS path, when the list carries one.
  final String? path;
  final String? folderId;
  final String? parentId;
  final num? sortOrder;

  /// Logs: the run, its workflow, the relative time and the raw status.
  final String? executionId;
  final String? workflowName;
  final String? time;
  final String? status;
}

/// `AvailableResources`: the families (already filtered and in
/// [resourceMenuOrder]), the table / knowledge-base folder structures, and
/// whether any list is still pending.
@immutable
class ResourceInventory {
  const ResourceInventory({
    this.groups = const <HomeResourceType, List<InventoryItem>>{},
    this.tableFolders = const <InventoryItem>[],
    this.knowledgeBaseFolders = const <InventoryItem>[],
    this.isHydrating = false,
  });

  final Map<HomeResourceType, List<InventoryItem>> groups;
  final List<InventoryItem> tableFolders;
  final List<InventoryItem> knowledgeBaseFolders;
  final bool isHydrating;

  List<InventoryItem> itemsOf(HomeResourceType type) =>
      groups[type] ?? const <InventoryItem>[];
}

/// Loads the add-resource inventory of a workspace. The lists are fetched
/// only when the menu opens (`useAvailableResources({enabled: open})`).
abstract class ResourceInventorySource {
  /// Starts (or reuses) the list requests and reports the inventory as the
  /// lists arrive. [excluded] families are dropped; `dashboard` and `test`
  /// also need their flags.
  ValueListenable<ResourceInventory> load(
    String workspaceId, {
    required Set<HomeResourceType> excluded,
    required bool dashboardsEnabled,
    required bool testsEnabled,
  });

  /// `GET /api/workspaces/{id}/files?scope=active` (30 s stale; [force]
  /// bypasses the cache). Throws when the list could not be read.
  Future<List<InventoryItem>> workspaceFiles(
    String workspaceId, {
    bool force = false,
  });
}

/// The workspace table list query (`['tables','list',ws,'active']`),
/// shared by the add menu and the suggested-actions signals.
QueryKey tableListKey(String workspaceId) => <Object?>[
  'tables',
  'list',
  workspaceId,
  'active',
];

/// The knowledge-base list query (`['knowledge','list',ws,'active']`).
QueryKey knowledgeBaseListKey(String workspaceId) => <Object?>[
  'knowledge',
  'list',
  workspaceId,
  'active',
];

/// `GET /api/table?workspaceId&scope=active` (`data.tables`).
Future<List<InventoryItem>> fetchTableList(
  HomeHttp http,
  QueryClient queries,
  String workspaceId,
) => queries.fetchQuery<List<InventoryItem>>(
  tableListKey(workspaceId),
  (_) async {
    final json = await http.get(
      '/api/table',
      query: <String, Object?>{'workspaceId': workspaceId, 'scope': 'active'},
    );
    return inventoryItems(json is Map ? json['data'] : null, 'tables');
  },
  staleTime: const Duration(seconds: 30),
);

/// `GET /api/knowledge?workspaceId&scope=active&includeCounts=false`.
Future<List<InventoryItem>> fetchKnowledgeBaseList(
  HomeHttp http,
  QueryClient queries,
  String workspaceId,
) => queries.fetchQuery<List<InventoryItem>>(
  knowledgeBaseListKey(workspaceId),
  (_) async => inventoryItems(
    await http.get(
      '/api/knowledge',
      query: <String, Object?>{
        'workspaceId': workspaceId,
        'scope': 'active',
        'includeCounts': false,
      },
    ),
    'data',
  ),
  staleTime: const Duration(seconds: 30),
);

/// One list row as a candidate (`id` required).
InventoryItem? inventoryItem(
  Map<String, Object?> json, {
  String nameKey = 'name',
}) {
  final id = jsonString(json, 'id');
  if (id == null) return null;
  return InventoryItem(
    id: id,
    name: jsonString(json, nameKey) ?? '',
    folderId: jsonString(json, 'folderId'),
    parentId: jsonString(json, 'parentId'),
    sortOrder: json['sortOrder'] is num ? json['sortOrder']! as num : null,
    path: jsonString(json, 'path'),
  );
}

/// `json[key]` rows as candidates.
List<InventoryItem> inventoryItems(
  Object? json,
  String? key, {
  String nameKey = 'name',
}) => <InventoryItem>[
  for (final row in jsonList(json, key)) ?inventoryItem(row, nameKey: nameKey),
];

/// `formatRelativeTime` (`packages/utils/src/formatting.ts:171-201`).
String formatRelativeTime(DateTime date, DateTime now) {
  final seconds = now.difference(date).inSeconds;
  if (seconds < 60) return 'just now';
  if (seconds < 3600) return '${seconds ~/ 60}m ago';
  if (seconds < 86400) return '${seconds ~/ 3600}h ago';
  if (seconds < 604800) return '${seconds ~/ 86400}d ago';
  if (seconds < 2592000) return '${seconds ~/ 604800}w ago';
  if (seconds < 31536000) return '${seconds ~/ 2592000}mo ago';
  return '${seconds ~/ 31536000}y ago';
}

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// `formatDate(x).compact` (`MMM d HH:mm:ss`, local time).
String formatCompactDate(DateTime date) {
  final local = date.toLocal();
  return '${_months[local.month - 1]} ${local.day} '
      '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
}

/// [ResourceInventorySource] over the workspace cubits (workflows and
/// their folders) and [HomeHttp] (every other list), cached per workspace
/// in the [QueryClient] under the React Query keys' shapes.
class HttpResourceInventorySource implements ResourceInventorySource {
  HttpResourceInventorySource({
    required this.http,
    required this.queries,
    this.workflows,
    this.folders,
    DateTime Function()? now,
  }) : _now = now ?? (() => clock.now());

  final HomeHttp? http;
  final QueryClient queries;
  final WorkflowsCubit? workflows;
  final FoldersCubit? folders;
  final DateTime Function() _now;

  static const Duration _stale = Duration(seconds: 30);

  Future<List<InventoryItem>> _fetch(
    QueryKey key,
    String path,
    Map<String, Object?> query,
    List<InventoryItem> Function(Object? json) decode, {
    bool force = false,
  }) {
    final client = http;
    if (client == null) return Future<List<InventoryItem>>.value(const []);
    return queries.fetchQuery<List<InventoryItem>>(
      key,
      (_) async => decode(await client.get(path, query: query)),
      staleTime: _stale,
      force: force,
    );
  }

  Future<List<InventoryItem>> _files(
    String workspaceId, {
    bool force = false,
  }) => _fetch(
    <Object?>['workspace-files', 'list', workspaceId, 'active'],
    '/api/workspaces/$workspaceId/files',
    const <String, Object?>{'scope': 'active'},
    (json) => inventoryItems(json, 'files'),
    force: force,
  );

  @override
  Future<List<InventoryItem>> workspaceFiles(
    String workspaceId, {
    bool force = false,
  }) => _files(workspaceId, force: force);

  @override
  ValueListenable<ResourceInventory> load(
    String workspaceId, {
    required Set<HomeResourceType> excluded,
    required bool dashboardsEnabled,
    required bool testsEnabled,
  }) {
    final result = ValueNotifier<ResourceInventory>(
      const ResourceInventory(isHydrating: true),
    );
    final lists = <String, List<InventoryItem>>{};
    var pending = 0;

    void publish() {
      final hidden = <HomeResourceType>{
        ...excluded,
        if (!dashboardsEnabled) HomeResourceType.dashboard,
        if (!testsEnabled) HomeResourceType.test,
      };
      final groups = <HomeResourceType, List<InventoryItem>>{};
      void put(HomeResourceType type, String list) {
        if (hidden.contains(type)) return;
        groups[type] = lists[list] ?? const <InventoryItem>[];
      }

      for (final type in resourceMenuOrder) {
        switch (type) {
          case HomeResourceType.workflow:
            put(type, 'workflows');
          case HomeResourceType.folder:
            put(type, 'folders');
          case HomeResourceType.table:
            put(type, 'tables');
          case HomeResourceType.dashboard:
            put(type, 'dashboard');
          case HomeResourceType.test:
            put(type, 'tests');
          case HomeResourceType.file:
            put(type, 'files');
          case HomeResourceType.filefolder:
            put(type, 'fileFolders');
          case HomeResourceType.knowledgebase:
            put(type, 'knowledgeBases');
          case HomeResourceType.task:
            put(type, 'chats');
          case HomeResourceType.log:
            put(type, 'logs');
          case HomeResourceType.integration:
          case HomeResourceType.browser:
          case HomeResourceType.terminal:
          case HomeResourceType.generic:
          case HomeResourceType.sources:
          case HomeResourceType.search:
            // Integrations are mention-only here (excluded by the tab
            // menu); browser and terminal are desktop-only.
            break;
        }
      }
      result.value = ResourceInventory(
        groups: groups,
        tableFolders: lists['tableFolders'] ?? const <InventoryItem>[],
        knowledgeBaseFolders:
            lists['knowledgeBaseFolders'] ?? const <InventoryItem>[],
        isHydrating: pending > 0,
      );
    }

    void track(String name, Future<List<InventoryItem>> future) {
      pending++;
      unawaited(
        future
            .then(
              (items) => lists[name] = items,
              onError: (Object _) => lists[name] = const <InventoryItem>[],
            )
            .whenComplete(() {
              pending--;
              publish();
            }),
      );
    }

    final workflowsCubit = workflows;
    track(
      'workflows',
      workflowsCubit == null
          ? _fetch(
              <Object?>['workflows', 'list', workspaceId],
              '/api/workflows',
              <String, Object?>{'workspaceId': workspaceId},
              (json) => inventoryItems(json, 'data'),
            )
          : workflowsCubit
                .load(workspaceId)
                .then(
                  (rows) => <InventoryItem>[
                    for (final w in rows ?? const <WorkflowListItem>[])
                      if (w.workspaceId == null || w.workspaceId == workspaceId)
                        InventoryItem(
                          id: w.id,
                          name: w.name,
                          folderId: w.folderId,
                          sortOrder: w.sortOrder,
                        ),
                  ],
                ),
    );
    final foldersCubit = folders;
    track(
      'folders',
      foldersCubit == null
          ? _fetch(
              <Object?>['folders', 'list', workspaceId],
              '/api/folders',
              <String, Object?>{'workspaceId': workspaceId},
              (json) => inventoryItems(json, 'folders'),
            )
          : foldersCubit
                .load(workspaceId)
                .then(
                  (rows) => <InventoryItem>[
                    for (final f in rows ?? const <Folder>[])
                      InventoryItem(
                        id: f.id,
                        name: f.name,
                        parentId: f.parentId,
                        sortOrder: f.sortOrder,
                      ),
                  ],
                ),
    );
    final client = http;
    track(
      'tables',
      client == null
          ? Future<List<InventoryItem>>.value(const <InventoryItem>[])
          : fetchTableList(client, queries, workspaceId),
    );
    if (!excluded.contains(HomeResourceType.table)) {
      track(
        'tableFolders',
        _fetch(
          <Object?>['folders', 'list', workspaceId, 'table'],
          '/api/folders',
          <String, Object?>{
            'workspaceId': workspaceId,
            'resourceType': 'table',
          },
          (json) => inventoryItems(json, 'folders'),
        ),
      );
    }
    if (dashboardsEnabled && !excluded.contains(HomeResourceType.dashboard)) {
      track(
        'dashboard',
        _fetch(
          <Object?>['dashboards', 'workspace', workspaceId],
          '/api/workspaces/$workspaceId/dashboard',
          const <String, Object?>{},
          (json) {
            final dashboard = json is Map ? json['dashboard'] : null;
            if (dashboard is! Map) return const <InventoryItem>[];
            final item = inventoryItem(dashboard.cast<String, Object?>());
            return <InventoryItem>[?item];
          },
        ),
      );
    }
    if (testsEnabled && !excluded.contains(HomeResourceType.test)) {
      track(
        'tests',
        _fetch(
          <Object?>['workflow-tests', workspaceId],
          '/api/workspaces/$workspaceId/tests',
          const <String, Object?>{},
          (json) => <InventoryItem>[
            for (final t in jsonList(json, 'tests'))
              if (jsonString(t, 'name') case final name?)
                InventoryItem(id: name, name: jsonString(t, 'title') ?? name),
          ],
        ),
      );
    }
    track('files', _files(workspaceId));
    if (!excluded.contains(HomeResourceType.knowledgebase)) {
      track(
        'knowledgeBaseFolders',
        _fetch(
          <Object?>['folders', 'list', workspaceId, 'knowledge_base'],
          '/api/folders',
          <String, Object?>{
            'workspaceId': workspaceId,
            'resourceType': 'knowledge_base',
          },
          (json) => inventoryItems(json, 'folders'),
        ),
      );
    }
    track(
      'fileFolders',
      _fetch(
        <Object?>['workspace-file-folders', 'list', workspaceId, 'active'],
        '/api/workspaces/$workspaceId/files/folders',
        const <String, Object?>{'scope': 'active'},
        (json) => inventoryItems(json, 'folders'),
      ),
    );
    track(
      'knowledgeBases',
      client == null
          ? Future<List<InventoryItem>>.value(const <InventoryItem>[])
          : fetchKnowledgeBaseList(client, queries, workspaceId),
    );
    track(
      'chats',
      _fetch(
        <Object?>['mothership-chats', 'list', workspaceId, 'active'],
        '/api/mothership/chats',
        <String, Object?>{'workspaceId': workspaceId, 'scope': 'active'},
        (json) => inventoryItems(json, 'data', nameKey: 'title'),
      ),
    );
    track(
      'logs',
      _fetch(
        <Object?>['logs', 'list', workspaceId, 'dropdown'],
        '/api/logs',
        <String, Object?>{
          'workspaceId': workspaceId,
          'limit': 50,
          'sortBy': 'date',
          'sortOrder': 'desc',
        },
        (json) {
          final now = _now();
          return <InventoryItem>[
            for (final log in jsonList(json, 'data'))
              if (jsonString(log, 'id') case final id?) _logItem(id, log, now),
          ];
        },
      ),
    );
    publish();
    return result;
  }

  static InventoryItem _logItem(
    String id,
    Map<String, Object?> log,
    DateTime now,
  ) {
    final workflow = log['workflow'];
    final workflowName =
        (workflow is Map ? workflow['name'] as String? : null) ??
        jsonString(log, 'workflowId') ??
        'Unknown';
    final created = DateTime.tryParse(jsonString(log, 'createdAt') ?? '');
    return InventoryItem(
      id: id,
      name: created == null
          ? workflowName
          : '$workflowName · ${formatCompactDate(created)}',
      executionId: jsonString(log, 'executionId'),
      workflowName: workflowName,
      time: created == null ? null : formatRelativeTime(created, now),
      status: jsonString(log, 'status'),
    );
  }
}

/// `resourceFromItem` (`resource-from-item.ts`), stamped with the
/// workspace like `WorkspaceResourceMenuContent.select`.
HomeResource resourceFromItem(
  HomeResourceType type,
  InventoryItem item,
  String workspaceId,
) => HomeResource(
  type: type,
  id: item.id,
  title: item.name,
  workspaceId: workspaceId,
  executionId: item.executionId,
);

/// A node of a browse tree (`ResourceTreeNode`).
sealed class ResourceTreeNode {
  const ResourceTreeNode();
}

class ResourceTreeItem extends ResourceTreeNode {
  const ResourceTreeItem(this.item);

  final InventoryItem item;
}

class ResourceTreeFolder extends ResourceTreeNode {
  const ResourceTreeFolder({
    required this.id,
    required this.name,
    required this.children,
  });

  final String id;
  final String name;
  final List<ResourceTreeNode> children;
}

/// `buildResourceFolderTree` (`resource-folder-tree.ts`): nests items into
/// their folders; orphans surface at the root; levels sort by name (or by
/// `sortOrder` for workflows) with folders and items interleaved; cycles
/// are unreachable and skipped; [pruneEmpty] drops folders without items.
List<ResourceTreeNode> buildResourceFolderTree(
  List<InventoryItem> items,
  List<InventoryItem> folders, {
  bool orderBySortOrder = false,
  bool pruneEmpty = false,
}) {
  final known = <String>{for (final f in folders) f.id};
  String? parentOf(String? id) => id != null && known.contains(id) ? id : null;
  final foldersByParent = <String?, List<InventoryItem>>{};
  for (final f in folders) {
    (foldersByParent[parentOf(f.parentId)] ??= <InventoryItem>[]).add(f);
  }
  final itemsByFolder = <String?, List<InventoryItem>>{};
  for (final i in items) {
    (itemsByFolder[parentOf(i.folderId)] ??= <InventoryItem>[]).add(i);
  }
  int compare(InventoryItem a, InventoryItem b) => orderBySortOrder
      ? (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0)
      : a.name.toLowerCase().compareTo(b.name.toLowerCase());

  final visiting = <String>{};
  List<ResourceTreeNode> level(String? parentId) {
    final entries = <(InventoryItem, ResourceTreeNode)>[];
    for (final folder in foldersByParent[parentId] ?? const <InventoryItem>[]) {
      if (!visiting.add(folder.id)) continue;
      final children = level(folder.id);
      visiting.remove(folder.id);
      if (pruneEmpty && children.isEmpty) continue;
      entries.add((
        folder,
        ResourceTreeFolder(
          id: folder.id,
          name: folder.name,
          children: children,
        ),
      ));
    }
    for (final item in itemsByFolder[parentId] ?? const <InventoryItem>[]) {
      entries.add((item, ResourceTreeItem(item)));
    }
    entries.sort((a, b) => compare(a.$1, b.$1));
    return <ResourceTreeNode>[for (final e in entries) e.$2];
  }

  return level(null);
}
