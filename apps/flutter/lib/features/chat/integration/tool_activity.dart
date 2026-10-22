/// Completed-activity phrases, port of `lib/mothership/tools/activity.ts`
/// (`TOOL_ACTIVITIES` and the `sim_cli` resource vocabulary,
/// `resolveToolActivity`, `getToolActivitySummaryActions`): a finished run of
/// several calls reads "Navigated, read pages, clicked elements".
library;

import 'package:sim_app/features/chat/integration/tool_display.dart'
    show firstWordOf, getToolCompletedTitle, getToolDisplayTitle;
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';

/// One call to phrase (`ToolActivitySubject`). [title] is the call's
/// success-tense title (`getToolStatusDisplayTitle(displayTitle, 'success',
/// …)`), the fallback for a call the catalog does not know.
class ToolActivitySubject {
  const ToolActivitySubject({
    required this.toolName,
    this.params,
    this.title = '',
  });

  final String toolName;
  final Map<String, Object?>? params;
  final String title;
}

/// A tool whose action depends on one enumerated argument
/// (`OperationActivity`).
class _Operation {
  const _Operation(
    this.label,
    this.parameter,
    this.operations, {
    this.defaultOperation,
  });

  final String label;
  final String parameter;
  final String? defaultOperation;
  final Map<String, ChatActivityPhrase> operations;
}

typedef _P = ChatActivityPhrase;

const _pageNavigation = _P.shared(verb: 'navigated', object: 'pages');
const _pageReading = _P.shared(verb: 'read', object: 'pages');
const _pageSearching = _P.shared(verb: 'searched', object: 'pages');
const _pageScrolling = _P.shared(verb: 'scrolled', object: 'pages');

const _deploymentActivity = _Operation('used deployments', 'action', {
  'deploy': _P('deployed workflows'),
  'undeploy': _P('undeployed workflows'),
}, defaultOperation: 'deploy');

const Map<String, _P> _queryUserTableOperations = {
  'get': _P('read tables'),
  'get_schema': _P('read tables'),
  'get_row': _P('read rows'),
  'query_rows': _P('searched rows'),
};

const Map<String, _P> _tableManageOperations = {
  'create': _P('created tables'),
  'create_from_file': _P('created tables'),
  'import_file': _P('imported table data'),
  'rename': _P('renamed tables'),
};

const Map<String, _P> _tableRowsOperations = {
  'insert_row': _P('added rows'),
  'batch_insert_rows': _P('added rows'),
  'update_row': _P('updated rows'),
  'batch_update_rows': _P('updated rows'),
  'delete_row': _P('deleted rows'),
  'batch_delete_rows': _P('deleted rows'),
  'update_rows_by_filter': _P('updated rows'),
  'delete_rows_by_filter': _P('deleted rows'),
};

const Map<String, _P> _tableColumnsOperations = {
  'add_column': _P('edited table columns'),
  'rename_column': _P('edited table columns'),
  'delete_column': _P('edited table columns'),
  'update_column': _P('edited table columns'),
};

const Map<String, _P> _tableAutomationsOperations = {
  'list_workflow_outputs': _P('read table automations'),
  'add_workflow_group': _P('edited table automations'),
  'update_workflow_group': _P('edited table automations'),
  'delete_workflow_group': _P('edited table automations'),
  'add_workflow_group_output': _P('edited table automations'),
  'delete_workflow_group_output': _P('edited table automations'),
  'run_column': _P('ran table automations'),
  'cancel_table_runs': _P('stopped table runs'),
};

const Map<String, _P> _tableEnrichmentsOperations = {
  'list_enrichments': _P('read table enrichments'),
  'add_enrichment': _P('configured enrichments'),
};

const Map<String, _P> _editedMedia = {
  'overlay_audio': _P('edited media'),
  'mix_audio': _P('edited media'),
  'concat': _P('edited media'),
  'trim': _P('edited media'),
  'scale_pad': _P('edited media'),
  'overlay_image': _P('edited media'),
  'add_text': _P('edited media'),
  'fade': _P('edited media'),
  'extract_audio': _P('edited media'),
  'convert': _P('edited media'),
  'thumbnail': _P('edited media'),
  'probe': _P('inspected media'),
};

/// `TOOL_ACTIVITIES` (`activity.ts:140-484`): a phrase or an operation
/// table per tool name.
const Map<String, Object> toolActivities = {
  'apply_file_edit': _P('edited files'),
  'browser_batch': _P('ran page actions'),
  'browser_click': _P('clicked elements'),
  'browser_click_at': _P('clicked elements'),
  'browser_close_tab': _P('closed tabs'),
  'browser_drag': _P('dragged elements'),
  'browser_extract': _pageReading,
  'browser_fill_form': _P('filled forms'),
  'browser_find': _pageSearching,
  'browser_go_back': _pageNavigation,
  'browser_go_forward': _pageNavigation,
  'browser_hover': _P('hovered over elements'),
  'browser_insert_text': _P('entered text'),
  'browser_list_downloads': _P('listed downloads'),
  'browser_list_sessions': _P('checked signed-in sites'),
  'browser_list_tabs': _P('listed tabs'),
  'browser_navigate': _pageNavigation,
  'browser_open_tab': _P('opened tabs'),
  'browser_open_url': _pageNavigation,
  'browser_press_key': _P('pressed keys'),
  'browser_read_text': _pageReading,
  'browser_reload': _pageNavigation,
  'browser_request_takeover': _P('resumed browser control'),
  'browser_save_download': _P('saved downloads'),
  'browser_screenshot': _P('captured screenshots'),
  'browser_scroll': _pageScrolling,
  'browser_select_option': _P('selected options'),
  'browser_set_checked': _P('updated selections'),
  'browser_snapshot': _pageReading,
  'browser_switch_tab': _P('switched tabs'),
  'browser_type': _P('entered text'),
  'browser_upload_file': _P('uploaded files'),
  'browser_wait_for': _P('waited'),
  'browser_zoom': _Operation('adjusted page zoom', 'action', {
    'in': _P('adjusted page zoom'),
    'out': _P('adjusted page zoom'),
    'reset': _P('adjusted page zoom'),
  }),
  'call_integration_tool': _P('used integrations'),
  'cancel_workflow_run': _P('stopped workflow runs'),
  'cli_help': _P('read the CLI reference'),
  'connect_slack_bot': _P('connected integrations'),
  'context_compaction': _P('summarized context'),
  'cp': _P('copied resources'),
  'create_empty_file': _P('created files'),
  'create_workflow': _P('created workflows'),
  'create_workspace_mcp_server': _P('created MCP servers'),
  'delete_workspace_mcp_server': _P('deleted MCP servers'),
  'deploy_as_api': _deploymentActivity,
  'deploy_as_chat': _deploymentActivity,
  'deploy_as_mcp': _deploymentActivity,
  'diff_workflows': _P('compared workflows'),
  'download_file': _P('downloaded files'),
  'edit_workflow': _P('edited workflows'),
  'extract_doc_assets': _P('extracted document assets'),
  'ffmpeg': _Operation('used media tools', 'operation', _editedMedia),
  'generate_api_key': _P('created API keys'),
  'generate_audio': _P('generated audio'),
  'generate_image': _P('generated images'),
  'generate_video': _P('generated video'),
  'get_block_outputs': _P('read workflow outputs'),
  'get_block_upstream_references': _P('read workflows'),
  'get_deployed_workflow_state': _P('read deployments'),
  'get_deployment_status': _P('read deployments'),
  'get_workflow_data': _P('read workflows'),
  'get_workflow_run_options': _P('read workflows'),
  'glob': _P('found files'),
  'grep': _P('searched files'),
  'import_local_files': _P('imported local files'),
  'interrupt_agent': _P('stopped agents'),
  'list_deployment_versions': _P('read deployments'),
  'list_integration_tools': _P('read integration tools'),
  'list_integrations': _P('read integrations'),
  'list_workspace_mcp_servers': _P('read MCP servers'),
  'list_workspaces': _P.shared(verb: 'listed', object: 'workspaces'),
  'list_user_projects': _P.shared(verb: 'listed', object: 'projects'),
  'load_deployment': _P('loaded workflow versions'),
  'load_integration_tool': _P('loaded integration tools'),
  'load_skill': _P('loaded skills'),
  'load_slide_layout': _P('loaded slide layouts'),
  'manage_credential': _Operation('managed credentials', 'operation', {
    'rename': _P('renamed credentials'),
    'delete': _P('deleted credentials'),
  }),
  'manage_custom_tool': _Operation('managed custom tools', 'operation', {
    'add': _P('created custom tools'),
    'edit': _P('edited custom tools'),
    'delete': _P('deleted custom tools'),
    'list': _P('read custom tools'),
  }),
  'manage_knowledge_base': _Operation('used knowledge bases', 'operation', {
    'create': _P('created knowledge bases'),
    'get': _P('read knowledge bases'),
    'query': _P('searched sources'),
    'add_file': _P('added source documents'),
    'update': _P('updated knowledge bases'),
    'delete_document': _P('deleted source documents'),
    'update_document': _P('updated source documents'),
    'list_tags': _P('read source tags'),
    'create_tag': _P('edited source tags'),
    'update_tag': _P('edited source tags'),
    'delete_tag': _P('edited source tags'),
    'get_tag_usage': _P('read source tags'),
    'add_connector': _P('created connections'),
    'update_connector': _P('edited connections'),
    'delete_connector': _P('deleted connections'),
    'sync_connector': _P('synced sources'),
  }),
  'manage_mcp_connection': _Operation('managed connections', 'operation', {
    'add': _P('created connections'),
    'edit': _P('edited connections'),
    'delete': _P('deleted connections'),
    'list': _P('read connections'),
  }),
  'manage_sandbox': _Operation('managed sandboxes', 'operation', {
    'add': _P('created sandboxes'),
    'edit': _P('edited sandboxes'),
    'delete': _P('deleted sandboxes'),
    'list': _P('read sandboxes'),
  }),
  'manage_skill': _Operation('managed skills', 'operation', {
    'add': _P('created skills'),
    'edit': _P('edited skills'),
    'delete': _P('deleted skills'),
    'list': _P('read skills'),
  }),
  'mkdir': _P('created folders'),
  'mv': _P('moved resources'),
  'oauth_get_auth_link': _P('prepared sign-in links'),
  'oauth_request_access': _P('requested access'),
  'open_resource': _P('opened resources'),
  'prepare_file_edit': _Operation('prepared file edits', 'operation', {
    'create': _P('prepared file edits'),
    'append': _P('prepared file edits'),
    'update': _P('prepared file edits'),
    'patch': _P('prepared file edits'),
  }),
  'promote_to_live': _P('deployed workflows'),
  'publish_custom_block': _Operation('managed custom blocks', 'action', {
    'deploy': _P('published custom blocks'),
    'undeploy': _P('unpublished custom blocks'),
  }, defaultOperation: 'deploy'),
  'query_logs': _P('read logs'),
  'query_user_table': _Operation(
    'read tables',
    'operation',
    _queryUserTableOperations,
  ),
  'read': _P('read files'),
  'read_document': _P.shared(verb: 'read', object: 'documents'),
  'read_local_file': _P('read local files'),
  'read_output': _P('read tool outputs'),
  'redeploy': _P('deployed workflows'),
  'remember': _P('updated memory'),
  'restore_resource': _P('restored resources'),
  'rm': _P('deleted resources'),
  'run_block': _P('ran workflows'),
  'run_code': _P('ran code'),
  'run_enrichment': _P('ran enrichments'),
  'run_from_block': _P('ran workflows'),
  'run_function': _P('ran code'),
  'run_workflow': _P('ran workflows'),
  'run_workflow_until_block': _P('ran workflows'),
  'save_upload': _Operation('used uploaded files', 'operation', {
    'save': _P('saved files'),
    'import': _P('imported workflows'),
    'extract': _P('extracted files'),
  }, defaultOperation: 'save'),
  'search_docs': _P('read documentation'),
  'search_integration_tools': _P('found integrations'),
  'search_knowledge_base': _Operation('searched sources', 'operation', {
    'get': _P('read knowledge bases'),
    'query': _P('searched sources'),
    'list_tags': _P('read source tags'),
  }),
  'search_library_docs': _P('read documentation'),
  'search_sources': _Operation('checked search sources', 'action', {
    'list': _P('read search sources'),
    'get': _P('read search sources'),
    'providers': _P('read search sources'),
    'setup': _P('set up search sources'),
    'approve': _P('updated search sources'),
  }),
  'search_workspace': _P.shared(verb: 'searched', object: 'documents'),
  'set_block_enabled': _P('edited workflows'),
  'set_environment_variables': _P('updated environment variables'),
  'set_global_workflow_variables': _P('updated workflow variables'),
  'settings': _Operation('checked settings', 'action', {
    'list': _P.shared(verb: 'read', object: 'settings'),
    'get': _P.shared(verb: 'read', object: 'settings'),
    'describe': _P.shared(verb: 'read', object: 'settings'),
    'open': _P.shared(verb: 'opened', object: 'settings'),
    'update': _P.shared(verb: 'updated', object: 'settings'),
    'execute': _P.shared(verb: 'updated', object: 'settings'),
  }),
  'share_file': _Operation('managed file sharing', 'action', {
    'share': _P('shared files'),
    'unshare': _P('stopped sharing files'),
  }, defaultOperation: 'share'),
  'steer_agent': _P('guided agents'),
  'table_automations': _Operation(
    'used table automations',
    'operation',
    _tableAutomationsOperations,
  ),
  'table_columns': _Operation(
    'used table columns',
    'operation',
    _tableColumnsOperations,
  ),
  'table_enrichments': _Operation(
    'used table enrichments',
    'operation',
    _tableEnrichmentsOperations,
  ),
  'table_manage': _Operation(
    'used tables',
    'operation',
    _tableManageOperations,
  ),
  'table_rows': _Operation('used tables', 'operation', _tableRowsOperations),
  'table_views': _Operation('used table views', 'operation', {
    'list_views': _P('read table views'),
    'get_view': _P('read table views'),
    'create_view': _P('edited table views'),
    'update_view': _P('edited table views'),
    'delete_view': _P('edited table views'),
    'set_default_view': _P('edited table views'),
  }),
  'tail_agent': _P('read agent progress'),
  'task': _P('delegated tasks'),
  'terminal': _Operation('used the terminal', 'operation', {
    'run': _P('ran commands'),
    'read': _P('read terminal output'),
    'input': _P('sent terminal input'),
    'kill': _P('stopped commands'),
    'cwd': _P('checked terminal locations'),
    'list': _P('listed terminals'),
    'new': _P('opened terminals'),
    'switch': _P('switched terminals'),
    'close': _P('closed terminals'),
    'panes': _P('listed terminal panes'),
    'handoff': _P('handed over terminal control'),
  }),
  'terminal_cwd': _P('checked terminal locations'),
  'terminal_input': _P('sent terminal input'),
  'terminal_kill': _P('stopped commands'),
  'terminal_read': _P('read terminal output'),
  'terminal_run': _P('ran commands'),
  'update_deployment_version': _P('updated deployment details'),
  'update_workspace_mcp_server': _P('updated MCP servers'),
  'user_table': _Operation('used tables', 'operation', {
    ..._queryUserTableOperations,
    ..._tableManageOperations,
    ..._tableRowsOperations,
    ..._tableColumnsOperations,
    ..._tableAutomationsOperations,
    ..._tableEnrichmentsOperations,
  }),
  'wait': _P('waited'),
  'wait_agents': _P('waited'),
  'web_crawl': _P('read web pages'),
  'web_fetch': _P('read web pages'),
  'web_scrape': _P('read web pages'),
  'web_search': _P('searched the web'),
  'workspaces': _P.shared(verb: 'created', object: 'workspaces'),
};

/// `CLI_ACTIVITY_OVERRIDES` (`activity.ts:493-511`).
const Map<String, _P> _cliActivityOverrides = {
  'cli_credentials_connect': _P('created connection links'),
  'cli_credentials_reconnect': _P('created connection links'),
  'cli_docs_search': _P('searched Sim docs'),
  'cli_files_mkdir': _P.shared(verb: 'created', object: 'file folders'),
  'cli_knowledge_mkdir': _P.shared(
    verb: 'created',
    object: 'knowledge folders',
  ),
  'cli_tables_mkdir': _P.shared(verb: 'created', object: 'table folders'),
  'cli_tables_upsert': _P.shared(verb: 'wrote', object: 'table rows'),
  'cli_workflows_mkdir': _P.shared(
    verb: 'created',
    object: 'workflow folders',
  ),
  'cli_grep': _P('searched the workspace'),
  'cli_integrations_list': _P('found integration actions'),
  'cli_knowledge_tags_cleanup': _P('cleaned up knowledge tags'),
  'cli_reference': _P('read the CLI reference'),
  'cli_search_query': _P('searched the workspace'),
  'cli_search_read': _P('read documents'),
  'cli_to_sandbox': _P('saved results'),
  'cli_workflows_rollback': _P('rolled back workflows'),
  'cli_workflows_runs_wait': _P('waited for workflow runs'),
};

/// `CLI_ACTIVITY_OBJECTS` (`activity.ts:518-576`).
const Map<String, String> _cliActivityObjects = {
  'audit_logs': 'audit logs',
  'billing_logs': 'billing logs',
  'billing_status': 'billing status',
  'blocks': 'blocks',
  'chat_deployments': 'chat deployments',
  'connector_types': 'connector types',
  'credentials': 'credentials',
  'credentials_providers': 'credential providers',
  'custom_tools': 'custom tools',
  'files': 'files',
  'files_folders': 'file folders',
  'files_share': 'file sharing',
  'knowledge': 'knowledge bases',
  'knowledge_chunks': 'knowledge chunks',
  'knowledge_connectors': 'knowledge connectors',
  'knowledge_connectors_documents': 'connector documents',
  'knowledge_documents': 'documents',
  'knowledge_folders': 'knowledge folders',
  'knowledge_tags': 'knowledge tags',
  'logs': 'run logs',
  'mcp_servers': 'MCP servers',
  'mcp_servers_tools': 'MCP server tools',
  'meta': 'platform status',
  'outputs': 'tool outputs',
  'search_sources': 'search sources',
  'secrets': 'secrets',
  'settings': 'settings',
  'skills': 'skills',
  'skills_editors': 'skill editors',
  'tables': 'tables',
  'tables_cancel_runs': 'table runs',
  'tables_columns': 'table columns',
  'tables_dispatches': 'table runs',
  'tables_enrichment': 'enrichment runs',
  'tables_exports': 'table exports',
  'tables_folders': 'table folders',
  'tables_groups': 'workflow groups',
  'tables_imports': 'table imports',
  'tables_rows': 'table rows',
  'tables_views': 'table views',
  'tools': 'integration operations',
  'workflow': 'workflows',
  'workflow_blocks': 'workflow blocks',
  'workflow_deps': 'workflow inputs',
  'workflow_mcp_servers': 'workflow MCP servers',
  'workflow_mcp_servers_tools': 'workflow MCP tools',
  'workflow_trace': 'run traces',
  'workflows': 'workflows',
  'workflows_activate': 'workflow versions',
  'workflows_chat': 'chat deployments',
  'workflows_deployment': 'deployments',
  'workflows_deps': 'workflow inputs',
  'workflows_folders': 'workflow folders',
  'workflows_runs': 'workflow runs',
  'workflows_variables': 'workflow variables',
  'workflows_versions': 'workflow versions',
  'workspaces': 'workspaces',
  'workspaces_members': 'workspace members',
};

/// `CLI_ACTIVITY_PREFIXES`: longest prefix first.
final List<String> _cliActivityPrefixes = _cliActivityObjects.keys.toList()
  ..sort((a, b) => b.length - a.length);

/// `resolveCliActivity` (`activity.ts:582-591`): a `sim_cli` command reads
/// as "`<past command verb> <resource>`", e.g. "listed tables".
_P? _resolveCliActivity(String toolName) {
  final override = _cliActivityOverrides[toolName];
  if (override != null) return override;
  if (!toolName.startsWith('cli_')) return null;
  final path = toolName.substring('cli_'.length);
  final prefix = _cliActivityPrefixes
      .where((key) => path == key || path.startsWith('${key}_'))
      .firstOrNull;
  if (prefix == null) return null;
  final verb = getToolCompletedTitle(
    firstWordOf(getToolDisplayTitle(toolName)),
  );
  return verb == null || verb.isEmpty
      ? null
      : _P.shared(
          verb: verb.toLowerCase(),
          object: _cliActivityObjects[prefix]!,
        );
}

/// `resolveToolActivity` (`activity.ts:612-638`): the catalog phrase (an
/// unknown operation falls back to the tool's label), else the `sim_cli`
/// resource phrase, else a phrase from the call's own completed title, else
/// a neutral summary.
ChatActivityPhrase resolveToolActivity(ToolActivitySubject subject) {
  final name = subject.toolName;
  final activity = toolActivities[name];
  if (activity is ChatActivityPhrase) return activity;
  if (activity is _Operation) {
    final params = subject.params;
    final operation = params != null && params.containsKey(activity.parameter)
        ? params[activity.parameter]
        : activity.defaultOperation;
    return (operation is String ? activity.operations[operation] : null) ??
        _P(activity.label);
  }
  final cli = _resolveCliActivity(name);
  if (cli != null) return cli;
  final title = subject.title.trim();
  if (title.isNotEmpty) return _P(chatPhraseCase(subject.title));
  return _P(name.startsWith('browser_') ? 'used the browser' : 'used tools');
}

/// `getToolActivitySummaryActions` over calls.
List<String> toolActivitySummaryActions(
  List<ToolActivitySubject> tools,
  int limit,
) => chatActivitySummaryActions(tools.map(resolveToolActivity), limit);
