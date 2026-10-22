import 'dart:async';
import 'dart:developer' as developer;

import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/input/model/composer_resources.dart';

/// Where the composer's `@` / `+` / `/` menus and auto-mention get their
/// data. The composer calls [loadInventory] on first focus (or when `+`
/// opens), [loadSkills] / [loadMcpServers] / [loadIntegrations] on mount.
abstract interface class ComposerContextSource {
  /// The resource families for the workspace, in [resourceMenuOrder],
  /// without `test` (the composer excludes it). Integrations are included
  /// here so the `@` list can offer them (browse mode hides them).
  Future<List<ComposerResourceGroup>> loadInventory(String workspaceId);

  /// `GET /api/skills?workspaceId`.
  Future<List<ComposerSkill>> loadSkills(String workspaceId);

  /// Enabled MCP servers of the workspace (+ managed connectors).
  Future<List<ComposerMcpServer>> loadMcpServers(String workspaceId);

  /// The integration catalog for `@name` auto-mention.
  Future<List<ComposerIntegration>> loadIntegrations();
}

/// The fixed ids of the built-in skills (`builtin-skills.ts`); they carry no
/// owner workspace.
bool isBuiltinSkillId(String id) => id.startsWith('builtin-');

/// [ComposerContextSource] over the app's HTTP client and the Phase 1
/// repositories (workflows, folders); the other lists are plain requests
/// matching `hooks/queries/*`. Failed lists settle empty (an errored list
/// must not keep the `@` menu hydrating forever).
class HttpComposerContextSource implements ComposerContextSource {
  HttpComposerContextSource(
    this._http, {
    WorkflowsRepository? workflows,
    FoldersRepository? folders,
    this.integrations = const [],
    this.dashboardsEnabled = false,
  }) : _workflows = workflows ?? WorkflowsRepository(_http),
       _folders = folders ?? FoldersRepository(_http);

  final SimHttpClient _http;
  final WorkflowsRepository _workflows;
  final FoldersRepository _folders;

  /// The app has no bundled block catalog yet; the host may pass one.
  final List<ComposerIntegration> integrations;

  /// The `dashboards` workspace flag.
  final bool dashboardsEnabled;

  Future<List<T>> _safe<T>(String what, Future<List<T>> Function() load) async {
    try {
      return await load();
    } on Object catch (error) {
      developer.log(
        'Composer list $what failed',
        name: 'sim_app.composer',
        error: error,
      );
      return const [];
    }
  }

  Future<List<Map<Object?, Object?>>> _rows(
    String path, {
    required List<Object?> Function(Object? json) select,
    Map<String, Object?>? params,
    Map<String, Object?>? query,
  }) => _http.requestJson(
    method: 'GET',
    path: path,
    params: params,
    query: query,
    decode: (json) => [
      for (final row in select(json))
        if (row is Map) row,
    ],
  );

  static List<Object?> _list(Object? value) =>
      value is List ? value : const <Object?>[];

  static Object? _at(Object? json, String key) =>
      json is Map ? json[key] : null;

  static String _string(Map<Object?, Object?> row, String key) {
    final value = row[key];
    return value is String ? value : '';
  }

  @override
  Future<List<ComposerResourceGroup>> loadInventory(String workspaceId) async {
    final ws = {'workspaceId': workspaceId};
    final results = await Future.wait<List<ComposerResource>>([
      _safe('workflows', () async {
        final rows = await _workflows.list(workspaceId: workspaceId);
        return [
          for (final w in rows)
            ComposerResource(
              type: ComposerResourceType.workflow,
              id: w.id,
              name: w.name,
            ),
        ];
      }),
      _safe('folders', () async {
        final rows = await _folders.list(workspaceId: workspaceId);
        final tableFolders = await _safe(
          'table folders',
          () => _folders.list(
            workspaceId: workspaceId,
            resourceType: FolderResourceType.table,
          ),
        );
        final kbFolders = await _safe(
          'kb folders',
          () => _folders.list(
            workspaceId: workspaceId,
            resourceType: FolderResourceType.knowledgeBase,
          ),
        );
        return [
          for (final f in rows)
            ComposerResource(
              type: ComposerResourceType.folder,
              id: f.id,
              name: f.name,
            ),
          for (final f in tableFolders)
            ComposerResource(
              type: ComposerResourceType.folder,
              id: f.id,
              name: f.name,
              mentionFamily: 'Table folders',
            ),
          for (final f in kbFolders)
            ComposerResource(
              type: ComposerResourceType.folder,
              id: f.id,
              name: f.name,
              mentionFamily: 'Knowledge base folders',
            ),
        ];
      }),
      _safe('tables', () async {
        final rows = await _rows(
          '/api/table',
          query: {...ws, 'scope': 'active'},
          select: (json) => _list(_at(_at(json, 'data'), 'tables')),
        );
        return [
          for (final r in rows)
            ComposerResource(
              type: ComposerResourceType.table,
              id: _string(r, 'id'),
              name: _string(r, 'name'),
            ),
        ];
      }),
      _safe('files', () async {
        final rows = await _rows(
          '/api/workspaces/[id]/files',
          params: {'id': workspaceId},
          query: {'scope': 'active'},
          select: (json) => _list(_at(json, 'files')),
        );
        return [
          for (final r in rows)
            ComposerResource(
              type: ComposerResourceType.file,
              id: _string(r, 'id'),
              name: _string(r, 'name'),
            ),
        ];
      }),
      _safe('file folders', () async {
        final rows = await _rows(
          '/api/workspaces/[id]/files/folders',
          params: {'id': workspaceId},
          query: {'scope': 'active'},
          select: (json) => _list(_at(json, 'folders')),
        );
        return [
          for (final r in rows)
            ComposerResource(
              type: ComposerResourceType.filefolder,
              id: _string(r, 'id'),
              name: _string(r, 'name'),
            ),
        ];
      }),
      _safe('knowledge bases', () async {
        final rows = await _rows(
          '/api/knowledge',
          query: {...ws, 'scope': 'active'},
          select: (json) => _list(_at(json, 'data')),
        );
        return [
          for (final r in rows)
            ComposerResource(
              type: ComposerResourceType.knowledgebase,
              id: _string(r, 'id'),
              name: _string(r, 'name'),
            ),
        ];
      }),
      _safe('chats', () async {
        final rows = await _rows(
          '/api/mothership/chats',
          query: {...ws, 'scope': 'active'},
          select: (json) => _list(_at(json, 'data')),
        );
        return [
          for (final r in rows)
            ComposerResource(
              type: ComposerResourceType.task,
              id: _string(r, 'id'),
              name: _string(r, 'title').isEmpty
                  ? _string(r, 'name')
                  : _string(r, 'title'),
            ),
        ];
      }),
      _safe('logs', () async {
        final rows = await _rows(
          '/api/logs',
          query: {
            ...ws,
            'limit': 50,
            'sortBy': 'date',
            'sortOrder': 'desc',
          },
          select: (json) => _list(_at(json, 'data')),
        );
        return [
          for (final r in rows)
            () {
              final workflow = r['workflow'];
              final workflowName =
                  (workflow is Map ? workflow['name'] : null) as String? ??
                  (r['workflowId'] as String?) ??
                  'Unknown';
              final executionId = r['executionId'];
              return ComposerResource(
                type: ComposerResourceType.log,
                id: _string(r, 'id'),
                name:
                    '$workflowName · ${_compactDate(_string(r, 'createdAt'))}',
                mentionFamily: 'Logs',
                executionId: executionId is String ? executionId : null,
              );
            }(),
        ];
      }),
      if (dashboardsEnabled)
        _safe('dashboard', () async {
          final json = await _http.requestJson<Object?>(
            method: 'GET',
            path: '/api/workspaces/[id]/dashboard',
            params: {'id': workspaceId},
            decode: (json) => json,
          );
          final dashboard = _at(json, 'dashboard');
          if (dashboard is! Map) return const [];
          return [
            ComposerResource(
              type: ComposerResourceType.dashboard,
              id: '${dashboard['id']}',
              name: '${dashboard['name']}',
            ),
          ];
        }),
    ]);
    final byType = <ComposerResourceType, List<ComposerResource>>{};
    for (final list in results) {
      for (final item in list) {
        (byType[item.type] ??= []).add(item);
      }
    }
    byType[ComposerResourceType.integration] = [
      for (final i in integrations)
        ComposerResource(
          type: ComposerResourceType.integration,
          id: i.blockType,
          name: i.name,
        ),
    ];
    return [
      for (final type in resourceMenuOrder)
        if (type != ComposerResourceType.test &&
            type != ComposerResourceType.browser &&
            type != ComposerResourceType.terminal &&
            type != ComposerResourceType.generic &&
            (type != ComposerResourceType.dashboard || dashboardsEnabled))
          ComposerResourceGroup(type, byType[type] ?? const []),
    ];
  }

  static String _compactDate(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, $hh:$mm';
  }

  @override
  Future<List<ComposerSkill>> loadSkills(String workspaceId) =>
      _safe('skills', () async {
        final rows = await _rows(
          '/api/skills',
          query: {'workspaceId': workspaceId},
          select: (json) => _list(_at(json, 'data')),
        );
        return [
          for (final r in rows)
            ComposerSkill(
              id: _string(r, 'id'),
              name: _string(r, 'name'),
              workspaceId: r['workspaceId'] as String?,
              builtin: isBuiltinSkillId(_string(r, 'id')),
            ),
        ];
      });

  @override
  Future<List<ComposerMcpServer>> loadMcpServers(String workspaceId) async {
    final query = {'workspaceId': workspaceId};
    final shared = await _safe(
      'mcp servers',
      () => _rows(
        '/api/mcp/servers',
        query: query,
        select: (json) => _list(_at(_at(json, 'data'), 'servers')),
      ),
    );
    final managed = await _safe(
      'managed mcp',
      () => _rows(
        '/api/mcp/managed-connections',
        query: query,
        select: (json) => _list(_at(json, 'servers')),
      ),
    );
    return [
      for (final r in [
        ...shared.where((r) => r['credentialGroupId'] == null),
        ...managed,
      ])
        if (r['enabled'] != false &&
            (r['workspaceId'] == null || r['workspaceId'] == workspaceId))
          ComposerMcpServer(
            id: _string(r, 'id'),
            name: _string(r, 'name'),
            managedConnectorId: r['managedConnectorId'] as String?,
          ),
    ];
  }

  @override
  Future<List<ComposerIntegration>> loadIntegrations() async => integrations;
}
