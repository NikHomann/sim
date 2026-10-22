/// Tool-call display titles: a faithful port of
/// `apps/sim/lib/mothership/tools/display.ts` (name/argument-derived titles,
/// status-aware tense, the wait countdown, CLI helpers), the client
/// enrichment layer of
/// `apps/sim/app/workspace/[workspaceId]/home/hooks/stream/stream-helpers.ts`
/// (`resolveToolDisplayTitle`, `resolveStreamingToolDisplayTitle`,
/// `resolveIntegrationToolDisplayTitle`), `resolveNamedCliToolDisplayTitle`
/// from `apps/sim/lib/mothership/tools/client/resource-display.ts`, and the
/// non-hook core of `useToolCallTitle`
/// (`home/components/message-content/components/agent-group/tool-call-title.ts`).
///
/// The React layer reads workflow, block and resource names out of zustand
/// stores and the React Query cache; here those lookups come in through an
/// optional [ToolTitleContext]. Without one, every title degrades to the
/// shared name+args resolver ([getToolDisplayTitle]), exactly as the React
/// resolver does when its stores hold no match.
library;

import 'package:sim_app/features/chat/engine/engine.dart'
    show
        contextCompactionDisplayTitle,
        extractStreamingStringArgument,
        normalizeToolActivityDescription;

typedef _Args = Map<String, Object?>?;

/// Name lookups the React title layer reads from its client stores
/// (`useWorkflowRegistry`, `useWorkflowStore`, the React Query inventories,
/// `getBlock`). Every lookup is optional; a missing or `null` answer leaves
/// the title on its generic wording.
class ToolTitleContext {
  /// Creates a lookup context.
  const ToolTitleContext({
    this.workflowName,
    this.blockName,
    this.resourceName,
    this.blockTypeName,
    this.currentWorkflowId,
    this.workspaceId,
  });

  /// Workflow id → workflow name (`resolveWorkflowNameForDisplay`).
  final String? Function(String workflowId)? workflowName;

  /// Block id (in the open workflow) → block name
  /// (`resolveBlockNameForDisplay`, `useWorkflowStore.blocks[id].name`).
  final String? Function(String blockId)? blockName;

  /// Generic `resolveResourceDisplayName(type, id)`: `type` is one of
  /// `workflow`, `table`, `knowledgebase`, `file`, `filefolder`, `folder`,
  /// `skill`, `customtool`, `mcpserver`, `workspace`, `log`.
  final String? Function(String type, String id)? resourceName;

  /// Block type id → registry display name (`getBlock(type).name`).
  final String? Function(String blockType)? blockTypeName;

  /// The workflow open in the editor; a workflow-scoped tool without a
  /// `workflowId` targets it (`registry.hydration.workflowId`).
  final String? currentWorkflowId;

  /// The workspace in view (`ToolResourceContext.workspaceId`).
  final String? workspaceId;

  String? _resource(String type, Object? id) {
    final resourceId = _stringParam(id);
    if (resourceId == null) return null;
    if (type == 'workflow') {
      final name = _nonEmpty(workflowName?.call(resourceId));
      if (name != null) return name;
    }
    return _nonEmpty(resourceName?.call(type, resourceId));
  }

  String? _block(Object? blockId) {
    final id = _stringParam(blockId);
    if (id == null) return null;
    return _nonEmpty(blockName?.call(id));
  }
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// `CONTEXT_COMPACTION_DISPLAY_TITLE` (display.ts:27), shared with the
/// engine's `contextCompactionDisplayTitle`.
const String contextCompactionTitle = contextCompactionDisplayTitle;

// ---------------------------------------------------------------------------
// Argument readers (display.ts:40-84)
// ---------------------------------------------------------------------------

/// display.ts:40 `OPAQUE_ID_PATTERN`: a UUID never belongs in a human title.
final RegExp _opaqueIdPattern = RegExp(
  r'^(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9a-f]{32})$',
  caseSensitive: false,
);

Map<String, Object?>? _asRecord(Object? value) =>
    value is Map ? value.cast<String, Object?>() : null;

String _stringArg(_Args args, String key) {
  final value = args?[key];
  if (value is! String) return '';
  final trimmed = value.trim();
  return _opaqueIdPattern.hasMatch(trimmed) ? '' : trimmed;
}

String _stringValue(String? value) => _stringArg({'value': value}, 'value');

String _firstStringArg(_Args args, List<String> keys) {
  for (final key in keys) {
    final value = _stringArg(args, key);
    if (value.isNotEmpty) return value;
  }
  return '';
}

List<String> _stringArrayArg(_Args args, String key) {
  final value = args?[key];
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item,
  ];
}

String _nestedStringArg(_Args args, String parentKey, List<String> keys) {
  final parent = _asRecord(args?[parentKey]);
  if (parent == null) return '';
  return _firstStringArg(parent, keys);
}

Map<String, Object?>? _recordArg(_Args args, String key) =>
    _asRecord(args?[key]);

String _jsNumber(num value) =>
    value is double && value == value.truncateToDouble() && value.isFinite
    ? value.toInt().toString()
    : value.toString();

String _stringOrNumberArg(_Args args, String key) {
  final value = args?[key];
  if (value is String) return value.trim();
  if (value is num) return _jsNumber(value).trim();
  return '';
}

/// `truncate` from `@sim/utils/string`.
String _truncate(String value, int sliceLength, [String suffix = '...']) =>
    value.length > sliceLength
    ? value.substring(0, sliceLength) + suffix
    : value;

/// `stripVersionSuffix` from `@sim/utils/string`.
String _stripVersionSuffix(String value) =>
    value.replaceFirst(RegExp(r'_v\d+$'), '');

// ---------------------------------------------------------------------------
// Per-tool title helpers (display.ts:92-571)
// ---------------------------------------------------------------------------

Set<String> _operationVerbs(String op) => op.split('_').toSet();

/// display.ts:102 `splitTableTitle`.
String _splitTableTitle(String name, _Args args) {
  final verbs = _operationVerbs(_stringArg(args, 'operation'));
  bool isOp(List<String> candidates) => candidates.any(verbs.contains);
  final target = _firstStringArg(args, const [
    'columnName',
    'viewName',
    'name',
    'title',
  ]);
  final suffix = target.isNotEmpty ? ' $target' : '';
  final table = _stringArg(args, 'tableName');
  final inTable = table.isNotEmpty ? ' in $table' : '';
  final ofTable = table.isNotEmpty ? ' of $table' : '';
  final tableOr = table.isNotEmpty ? ' $table' : ' table';
  switch (name) {
    case 'settings':
      final verb =
          const {
            'list': 'Listing',
            'get': 'Reading',
            'update': 'Updating',
            'open': 'Opening',
            'execute': 'Managing',
          }[_stringArg(args, 'action')] ??
          'Reading';
      final subject = [
        _stringArg(args, 'scope'),
        _stringArg(args, 'section').replaceAll('-', ' '),
      ].where((s) => s.isNotEmpty).join(' ');
      return '$verb ${subject.isNotEmpty ? '$subject ' : ''}settings';
    case 'search_sources':
      final action = _stringArg(args, 'action');
      final subject = _stringArg(args, 'connectorType').replaceAll('_', ' ');
      final verb =
          const {
            'list': 'Listing',
            'get': 'Checking',
            'providers': 'Listing',
            'setup': 'Preparing',
            'approve': 'Updating',
          }[action] ??
          'Checking';
      final noun = action == 'providers'
          ? 'providers'
          : action == 'setup'
          ? 'setup'
          : 'sources';
      return '$verb ${subject.isNotEmpty ? '$subject ' : ''}search $noun';
    case 'table_manage':
      if (isOp(const ['create'])) {
        return 'Creating table${suffix.isNotEmpty ? suffix : (table.isNotEmpty ? ' $table' : '')}';
      }
      if (isOp(const ['delete'])) {
        return 'Deleting table${table.isNotEmpty ? ' $table' : suffix}';
      }
      if (isOp(const ['read', 'get', 'list'])) {
        return 'Reading${table.isNotEmpty ? ' $table' : ' table'}';
      }
      return 'Updating$tableOr';
    case 'table_rows':
      if (isOp(const ['insert', 'add', 'create'])) {
        return 'Adding rows${inTable.isNotEmpty ? ' to $table' : ''}';
      }
      if (isOp(const ['update'])) return 'Updating rows$inTable';
      if (isOp(const ['delete'])) return 'Deleting rows$inTable';
      if (isOp(const ['read', 'get', 'list', 'query'])) {
        return 'Reading rows$ofTable';
      }
      return 'Editing rows$ofTable';
    case 'table_columns':
      if (isOp(const ['add', 'create'])) return 'Adding column$suffix$inTable';
      if (isOp(const ['update'])) return 'Updating column$suffix$inTable';
      if (isOp(const ['delete'])) return 'Deleting column$suffix$inTable';
      if (isOp(const ['read', 'get', 'list'])) return 'Reading columns$ofTable';
      return 'Editing columns$ofTable';
    case 'table_automations':
      if (isOp(const ['read', 'get', 'list'])) {
        return 'Reading automations$ofTable';
      }
      if (isOp(const ['delete'])) return 'Removing automation$inTable';
      return 'Wiring automation$inTable';
    case 'table_enrichments':
      if (isOp(const ['read', 'get', 'list'])) {
        return 'Reading enrichments$ofTable';
      }
      if (isOp(const ['delete'])) return 'Removing enrichment$inTable';
      return 'Configuring enrichment$suffix$inTable';
    case 'table_views':
      if (isOp(const ['create'])) return 'Creating view$suffix$inTable';
      if (isOp(const ['delete'])) return 'Deleting view$suffix$inTable';
      if (isOp(const ['read', 'get', 'list'])) return 'Reading views$ofTable';
      return 'Editing views$ofTable';
    default:
      return 'Updating$tableOr';
  }
}

/// display.ts:179 `deploymentTitle`.
String _deploymentTitle(_Args args, String deploymentType) {
  final verb = _stringArg(args, 'action') == 'undeploy'
      ? 'Undeploying'
      : 'Deploying';
  final workflow = _firstStringArg(args, const [
    'workflowName',
    'name',
    'title',
  ]);
  return workflow.isNotEmpty
      ? '$verb $workflow as $deploymentType'
      : '$verb as $deploymentType';
}

/// display.ts:185 `resourceTypeLabel`.
String _resourceTypeLabel(String type) =>
    const {
      'knowledgebase': 'knowledge base',
      'file_folder': 'file folder',
      'log': 'logs',
    }[type] ??
    type;

/// display.ts:199 `namedOperationTitle`; each label is (verb, resource).
String _namedOperationTitle(
  _Args args,
  String target,
  String placeholder,
  Map<String, (String, String)> labels,
) {
  final display = labels[_stringArg(args, 'operation')];
  if (display == null) return placeholder;
  return '${display.$1} ${target.isNotEmpty ? target : display.$2}';
}

String _slice80(String value) =>
    value.length > 80 ? value.substring(0, 80) : value;

/// display.ts:211 `displayUrl`: host + path, no scheme/query noise. Mirrors
/// `new URL(raw)`, which throws (→ raw prefix) for anything without a scheme.
String _displayUrl(String raw) {
  if (raw.isEmpty) return '';
  final url = Uri.tryParse(raw);
  if (url == null || !url.hasScheme) return _slice80(raw);
  final host = url.hasPort ? '${url.host}:${url.port}' : url.host;
  final path = url.path == '/' || url.path.isEmpty ? '' : url.path;
  return _slice80('$host$path');
}

/// Human name for a block type id (display.ts:226 `blockDisplayName`): strip
/// the version suffix and title-case the snake_case stem (`slack_v2` →
/// `Slack`, `google_sheets_v2` → `Google Sheets`). When [lookup] (the block
/// registry, `getBlock(type)?.name`) knows the type, its name wins.
String blockDisplayName(
  String blockType, {
  String? Function(String blockType)? lookup,
}) {
  final stem = blockType.trim();
  if (stem.isEmpty) return blockType;
  final registered = _nonEmpty(lookup?.call(stem));
  return registered ?? humanizeDisplayIdentifier(stem);
}

/// display.ts:232 `truncateMiddle`.
String _truncateMiddle(String value, int maxChars) {
  final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= maxChars) return text;
  final head = ((maxChars - 1) / 2).ceil();
  final tail = ((maxChars - 1) / 2).floor();
  return '${text.substring(0, head)}…${text.substring(text.length - tail)}';
}

bool _isWorkflowArtifactPath(String path, String filename) {
  final trimmed = path.trim();
  return trimmed.startsWith('workflows/') && trimmed.endsWith('/$filename');
}

/// display.ts:245 `decodePathSegment` (`decodeURIComponent`, raw on error).
String _decodePathSegment(String segment) {
  try {
    return Uri.decodeComponent(segment);
  } on Object {
    return segment;
  }
}

/// display.ts:253 `pathLeaf`.
String _pathLeaf(String path) {
  final normalized = path.replaceFirst(RegExp(r'/+$'), '');
  final parts = normalized.split('/').where((s) => s.isNotEmpty);
  final leaf = parts.isEmpty ? normalized : parts.last;
  return _decodePathSegment(leaf.isEmpty ? normalized : leaf);
}

/// display.ts:259 `summarizeTargets`.
String _summarizeTargets(Iterable<String> targets, String fallback) {
  final normalized = [
    for (final t in targets)
      if (t.trim().isNotEmpty) t.trim(),
  ];
  if (normalized.isEmpty) return fallback;
  if (normalized.length == 1) return normalized[0];
  if (normalized.length == 2) return '${normalized[0]} and ${normalized[1]}';
  return '${normalized[0]}, ${normalized[1]}, and ${normalized.length - 2} more';
}

/// display.ts:267 `countedResourceTarget`.
String _countedResourceTarget(
  _Args args,
  String key,
  String singular,
  String plural,
) {
  final values = args?[key];
  return values is List && values.length > 1
      ? '${values.length} $plural'
      : singular;
}

String _firstOutputFileField(_Args args, String field) {
  final outputs = _asRecord(args?['outputs']);
  final files = outputs?['files'];
  if (files is! List) return '';
  for (final file in files) {
    final record = _asRecord(file);
    if (record == null) continue;
    final value = _stringArg(record, field);
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// display.ts:305 `createFileTitle`.
String _createFileTitle(_Args args) {
  final nestedArgs = _asRecord(args?['args']);
  String orElse(String a, String Function() b) => a.isNotEmpty ? a : b();
  final target = orElse(
    _firstOutputFileField(args, 'path'),
    () => orElse(
      _stringArg(args, 'fileName'),
      () => orElse(
        _firstOutputFileField(nestedArgs, 'path'),
        () => _stringArg(nestedArgs, 'fileName'),
      ),
    ),
  );
  final mode = orElse(
    _firstOutputFileField(args, 'mode'),
    () => _firstOutputFileField(nestedArgs, 'mode'),
  );
  final verb = mode == 'overwrite' ? 'Overwriting' : 'Creating';
  if (target.isEmpty) return '$verb file';
  return '$verb ${_pathLeaf(target)}';
}

/// display.ts:319 `ffmpegTitle`.
String _ffmpegTitle(_Args args) =>
    const {
      'overlay_audio': 'Adding audio to media',
      'mix_audio': 'Mixing audio',
      'concat': 'Combining media',
      'trim': 'Trimming media',
      'scale_pad': 'Resizing media',
      'overlay_image': 'Adding image to media',
      'add_text': 'Adding text to media',
      'fade': 'Adding fade to media',
      'extract_audio': 'Extracting audio',
      'convert': 'Converting media',
      'thumbnail': 'Creating thumbnail',
      'probe': 'Inspecting media',
    }[_stringArg(args, 'operation')] ??
    'Processing media';

/// display.ts:337 `knowledgeBaseTitle`.
String _knowledgeBaseTitle(_Args args) {
  final operation = _stringArg(args, 'operation');
  final operationArgs = _recordArg(args, 'args');
  final name = _stringArg(operationArgs, 'name');
  final tagName = _stringArg(operationArgs, 'tagDisplayName');
  final fileTarget = _summarizeTargets(
    _stringArrayArg(operationArgs, 'filePaths').map(_pathLeaf),
    'file',
  );
  final query = _stringArg(operationArgs, 'query');
  final titles = <String, String>{
    'create': 'Creating ${name.isNotEmpty ? name : 'knowledge base'}',
    'get': 'Reading knowledge base',
    'query': query.isNotEmpty
        ? 'Searching knowledge base for $query'
        : 'Searching knowledge base',
    'add_file': 'Adding $fileTarget to knowledge base',
    'update': 'Updating knowledge base',
    'delete':
        'Deleting ${_countedResourceTarget(operationArgs, 'knowledgeBaseIds', 'knowledge base', 'knowledge bases')}',
    'delete_document':
        'Deleting ${_countedResourceTarget(operationArgs, 'documentIds', 'document', 'documents')}',
    'update_document': 'Updating document',
    'list_tags': 'Listing knowledge base tags',
    'create_tag':
        'Creating ${tagName.isNotEmpty ? tagName : 'knowledge base tag'}',
    'update_tag':
        'Updating ${tagName.isNotEmpty ? tagName : 'knowledge base tag'}',
    'delete_tag': 'Deleting knowledge base tag',
    'get_tag_usage': 'Checking tag usage',
    'add_connector': 'Adding knowledge base connector',
    'update_connector': 'Updating knowledge base connector',
    'delete_connector': 'Deleting knowledge base connector',
    'sync_connector': 'Syncing knowledge base connector',
  };
  return titles[operation] ?? 'Managing knowledge base';
}

/// display.ts:370 `queryUserTableTitle`.
String _queryUserTableTitle(_Args args) =>
    const {
      'get': 'Reading table',
      'get_schema': 'Reading table schema',
      'get_row': 'Reading table row',
      'query_rows': 'Querying table',
    }[_stringArg(args, 'operation')] ??
    'Querying table';

/// display.ts:380 `searchKnowledgeBaseTitle`.
String _searchKnowledgeBaseTitle(_Args args) {
  final query = _stringArg(args, 'query');
  final operation = _stringArg(args, 'operation');
  if (operation == 'get') return 'Reading knowledge base';
  if (operation == 'list_tags') return 'Listing knowledge base tags';
  return query.isNotEmpty
      ? 'Searching knowledge base for $query'
      : 'Searching knowledge base';
}

/// display.ts:389 `manageSandboxTitle`.
String _manageSandboxTitle(_Args args) =>
    const {
      'add': 'Creating sandbox',
      'edit': 'Updating sandbox',
      'delete': 'Deleting sandbox',
      'list': 'Listing sandboxes',
    }[_stringArg(args, 'operation')] ??
    'Managing sandbox';

/// display.ts:399 `userTableTitle`.
String _userTableTitle(_Args args) {
  final operation = _stringArg(args, 'operation');
  final operationArgs = _recordArg(args, 'args');
  final name = _stringArg(operationArgs, 'name');
  final newName = _stringArg(operationArgs, 'newName');
  final columnName = _stringArg(operationArgs, 'columnName');
  final columnDefinitionName = _nestedStringArg(operationArgs, 'column', const [
    'name',
  ]);
  final columnTargets = [
    ..._stringArrayArg(operationArgs, 'columnNames'),
    if (columnName.isNotEmpty) columnName,
  ];

  switch (operation) {
    case 'create':
      return 'Creating ${name.isNotEmpty ? name : 'table'}';
    case 'create_from_file':
      return 'Creating table from file';
    case 'import_file':
      return 'Importing file into table';
    case 'get':
      return 'Reading table';
    case 'get_schema':
      return 'Reading table schema';
    case 'delete':
      return 'Deleting ${_countedResourceTarget(operationArgs, 'tableIds', 'table', 'tables')}';
    case 'rename':
      return newName.isNotEmpty
          ? 'Renaming table to $newName'
          : 'Renaming table';
    case 'insert_row':
      return 'Adding table row';
    case 'batch_insert_rows':
      return 'Adding ${_countedResourceTarget(operationArgs, 'rows', 'table row', 'table rows')}';
    case 'get_row':
      return 'Reading table row';
    case 'query_rows':
      return 'Querying table';
    case 'update_row':
      return 'Updating table row';
    case 'delete_row':
      return 'Deleting table row';
    case 'update_rows_by_filter':
    case 'batch_update_rows':
      return 'Updating table rows';
    case 'delete_rows_by_filter':
    case 'batch_delete_rows':
      return 'Deleting table rows';
    case 'add_column':
      return columnDefinitionName.isNotEmpty
          ? 'Adding column $columnDefinitionName'
          : 'Adding table column';
    case 'rename_column':
      if (columnName.isNotEmpty && newName.isNotEmpty) {
        return 'Renaming column $columnName to $newName';
      }
      return newName.isNotEmpty
          ? 'Renaming table column to $newName'
          : 'Renaming table column';
    case 'delete_column':
      return 'Deleting ${_summarizeTargets(columnTargets, 'table column')}';
    case 'update_column':
      return columnName.isNotEmpty
          ? 'Updating column $columnName'
          : 'Updating table column';
    case 'add_workflow_group':
      return 'Adding table workflow';
    case 'update_workflow_group':
      return 'Updating table workflow';
    case 'delete_workflow_group':
      return 'Deleting table workflow';
    case 'add_workflow_group_output':
      return 'Adding workflow output column';
    case 'delete_workflow_group_output':
      return 'Deleting workflow output column';
    case 'run_column':
      return 'Running table workflow';
    case 'cancel_table_runs':
      return 'Cancelling table runs';
    case 'list_workflow_outputs':
      return 'Listing workflow outputs';
    case 'list_enrichments':
      return 'Listing enrichments';
    case 'add_enrichment':
      return 'Adding ${name.isNotEmpty ? name : 'enrichment'}';
    default:
      return 'Managing table';
  }
}

/// display.ts:478 `materializeFileTitle`.
String _materializeFileTitle(_Args args) {
  final op = _stringArg(args, 'operation');
  final operation = op.isNotEmpty ? op : 'save';
  final targets = _stringArrayArg(args, 'fileNames').map(_pathLeaf);
  if (operation == 'import') {
    return 'Importing ${_summarizeTargets(targets, 'workflow')}';
  }
  if (operation == 'extract') {
    return 'Extracting ${_summarizeTargets(targets, 'archive')}';
  }
  return 'Saving ${_summarizeTargets(targets, 'file')}';
}

/// display.ts:490 `openResourceTitle`.
String _openResourceTitle(_Args args) {
  final resources = args?['resources'];
  if (resources is! List || resources.isEmpty) return 'Opening resource';
  if (resources.length > 1) return 'Opening ${resources.length} resources';
  final resource = _asRecord(resources[0]);
  if (resource == null) return 'Opening resource';
  final type = _stringArg(resource, 'type');
  return 'Opening ${type.isNotEmpty ? _resourceTypeLabel(type) : 'resource'}';
}

/// display.ts:500 `setGlobalWorkflowVariablesTitle`.
String _setGlobalWorkflowVariablesTitle(_Args args) {
  final workflow = _firstStringArg(args, const ['workflowName', 'name']);
  final scope = workflow.isNotEmpty ? ' in $workflow' : '';
  final operations = args?['operations'];
  if (operations is! List || operations.isEmpty) {
    return 'Setting workflow variables$scope';
  }
  final parsed = [
    for (final operation in operations) ?_asRecord(operation),
  ];
  final operationNames = [
    for (final operation in parsed) _stringArg(operation, 'operation'),
  ];
  final firstOperation = operationNames.isEmpty ? '' : operationNames.first;
  final allSameOperation =
      firstOperation.isNotEmpty &&
      operationNames.every((operation) => operation == firstOperation);
  const verbByOperation = {
    'add': 'Adding',
    'edit': 'Updating',
    'delete': 'Deleting',
  };
  final verb = allSameOperation
      ? (verbByOperation[firstOperation] ?? 'Updating')
      : 'Updating';
  if (parsed.length == 1) {
    final variableName = _stringArg(parsed[0], 'name');
    return '$verb workflow variable${variableName.isNotEmpty ? ' $variableName' : ''}$scope';
  }
  return '$verb ${parsed.length} workflow variables$scope';
}

/// Verb for an `mv` call (display.ts:539 `mvDisplayVerb`): a single source
/// whose parent matches the destination's (only the leaf changes) is a
/// rename; anything else is a move.
String mvDisplayVerb(String? source, String? destination) {
  if (source == null ||
      source.isEmpty ||
      destination == null ||
      destination.isEmpty ||
      RegExp(r'/\s*$').hasMatch(destination)) {
    return 'Moving';
  }
  List<String> segments(String path) => path
      .trim()
      .replaceAll(RegExp(r'^/+|/+$'), '')
      .split('/')
      .map(_decodePathSegment)
      .toList();
  final src = segments(source);
  final dst = segments(destination);
  if (src.length < 2 || dst.length < 2) return 'Moving';
  final sameParent =
      src.sublist(0, src.length - 1).join('/') ==
      dst.sublist(0, dst.length - 1).join('/');
  final leafChanged = src.last != dst.last;
  return sameParent && leafChanged ? 'Renaming' : 'Moving';
}

/// `prepare_file_edit` operation → present participle (display.ts:561,
/// tool-call-title.ts:21 `FILE_EDIT_VERBS`).
const Map<String, String> _fileEditVerbs = {
  'create': 'Creating',
  'append': 'Adding',
  'patch': 'Editing',
  'update': 'Writing',
  'rename': 'Renaming',
  'delete': 'Deleting',
};

/// display.ts:558 `workspaceFileTitle`.
String _workspaceFileTitle(_Args args) {
  final title = _stringArg(args, 'title');
  if (title.isEmpty) return '';
  final verb = _fileEditVerbs[_stringArg(args, 'operation')] ?? 'Writing';
  return '$verb $title';
}

/// display.ts:574 `TOOL_TITLES`: static fallback titles.
const Map<String, String> _toolTitles = {
  'call_integration_tool': 'Calling integration',
  'search_integration_tools': 'Finding the right integration',
  'load_integration_tool': 'Loading integration tools',
  'load_skill': 'Loading skill',
  'load_slide_layout': 'Loading slide layout',
  'read': 'Reading file',
  'search_library_docs': 'Searching library docs',
  'user_table': 'Managing table',
  'run_code': 'Running code',
  'query_user_table': 'Querying table',
  'table_manage': 'Updating table',
  'table_rows': 'Editing rows',
  'table_columns': 'Editing columns',
  'table_automations': 'Wiring automation',
  'table_enrichments': 'Configuring enrichment',
  'table_views': 'Editing views',
  'prepare_file_edit': 'Editing file',
  'apply_file_edit': 'Writing changes',
  'create_workflow': 'Creating workflow',
  'cancel_workflow_run': 'Cancelling workflow run',
  'edit_workflow': 'Editing workflow',
  'manage_knowledge_base': 'Managing knowledge base',
  'search_knowledge_base': 'Searching knowledge base',
  'search_workspace': 'Searching documents',
  'list_workspaces': 'Listing workspaces',
  'read_document': 'Reading document',
  'open_resource': 'Opening resource',
  'ffmpeg': 'Processing media',
  'get_deployment_status': 'Checking deployment status',
  'create_empty_file': 'Creating file',
  'create_file_folder': 'Creating folder',
  'create_workspace_mcp_server': 'Creating MCP server',
  'delete_workspace_mcp_server': 'Deleting MCP server',
  'deploy_as_api': 'Deploying as API',
  'deploy_as_chat': 'Deploying as chat',
  'publish_custom_block': 'Publishing custom block',
  'deploy_as_mcp': 'Deploying as MCP tool',
  'diff_workflows': 'Comparing workflows',
  'run_function': 'Running code',
  'generate_api_key': 'Generating API key',
  'get_account_billing': 'Checking plan and usage',
  'get_block_outputs': 'Reading block outputs',
  'get_block_upstream_references': 'Tracing block inputs',
  'get_deployed_workflow_state': 'Reading the deployed version',
  'get_enterprise_context': 'Checking enterprise access',
  'list_deployment_versions': 'Listing deployment versions',
  'get_workflow_data': 'Reading workflow',
  'get_workflow_run_options': 'Checking run settings',
  'list_file_folders': 'Listing folders',
  'list_integration_tools': 'Listing integration tools',
  'list_user_workspaces': 'Listing workspaces',
  'list_user_projects': 'Listing projects',
  'list_workspace_mcp_servers': 'Listing MCP servers',
  'load_deployment': 'Loading deployment',
  'save_upload': 'Saving upload',
  'connect_slack_bot': 'Connecting Slack bot',
  'manage_sandbox': 'Managing sandbox',
  'move_file': 'Moving file',
  'move_file_folder': 'Moving folder',
  'move_workflow': 'Moving workflow',
  'oauth_get_auth_link': 'Creating sign-in link',
  'oauth_request_access': 'Requesting access',
  'promote_to_live': 'Promoting to live',
  'redeploy': 'Redeploying API',
  'rename_file': 'Renaming file',
  'rename_file_folder': 'Renaming folder',
  'rename_workflow': 'Renaming workflow',
  'restore_resource': 'Restoring resource',
  'run_block': 'Running block',
  'search_docs': 'Searching Sim docs',
  'set_block_enabled': 'Toggling block',
  'set_environment_variables': 'Setting environment variables',
  'set_global_workflow_variables': 'Setting workflow variables',
  'update_deployment_version': 'Updating deployment',
  'update_workspace_mcp_server': 'Updating MCP server',
  'browser_go_back': 'Going back',
  'browser_go_forward': 'Going forward',
  'browser_reload': 'Reloading page',
  'browser_switch_tab': 'Switching tab',
  'browser_close_tab': 'Closing tab',
  'browser_list_tabs': 'Listing tabs',
  'browser_list_sessions': 'Checking signed-in sites',
  'browser_list_downloads': 'Checking downloads',
  'browser_save_download': 'Saving download to files',
  'browser_upload_file': 'Uploading file',
  'browser_snapshot': 'Scanning page',
  'browser_find': 'Finding page element',
  'browser_read_text': 'Reading page',
  'read_local_file': 'Reading local file',
  'import_local_files': 'Importing local files',
  'browser_screenshot': 'Taking screenshot',
  'browser_click': 'Clicking element',
  'browser_click_at': 'Clicking point',
  'browser_drag': 'Dragging element',
  'browser_select_option': 'Selecting option',
  'browser_fill_form': 'Filling form',
  'browser_batch': 'Running page actions',
  'browser_set_checked': 'Updating control',
  'browser_hover': 'Hovering element',
  'browser_zoom': 'Changing page zoom',
  'workflow': 'Workflow Agent',
  'run': 'Run Agent',
  'deploy': 'Deploy Agent',
  'auth': 'Auth Agent',
  'knowledge': 'Knowledge Agent',
  'table': 'Table Agent',
  'extensions': 'Extensions Agent',
  'research': 'Research Agent',
  'scout': 'Scout Agent',
  'search': 'Search Agent',
  'platform': 'Platform Agent',
  'file': 'File Agent',
  'media': 'Media Agent',
  'browser': 'Browser Agent',
  'superagent': 'Executing action',
  'respond': 'Gathering thoughts',
  'context_compaction': contextCompactionDisplayTitle,
};

/// `CLI_TOOL_TITLES` (lib/mothership/tools/cli-tool-display.ts:10).
const Map<String, String> _cliToolTitles = {
  'cli_audit_logs_get': 'Reading audit log',
  'cli_audit_logs_list': 'Listing audit logs',
  'cli_billing_logs': 'Reading billing logs',
  'cli_billing_status': 'Checking billing status',
  'cli_blocks_get': 'Reading block configuration',
  'cli_blocks_list': 'Listing available blocks',
  'cli_chat_deployments_list': 'Listing chat deployments',
  'cli_connector_types_list': 'Listing connector types',
  'cli_credentials_connect': 'Creating connection link',
  'cli_credentials_create': 'Creating credential',
  'cli_credentials_delete': 'Deleting credential',
  'cli_credentials_list': 'Listing credentials',
  'cli_credentials_providers_list': 'Listing credential providers',
  'cli_credentials_reconnect': 'Creating reconnection link',
  'cli_credentials_update': 'Updating credential',
  'cli_custom_tools_create': 'Creating custom tool',
  'cli_custom_tools_delete': 'Deleting custom tool',
  'cli_custom_tools_get': 'Reading custom tool',
  'cli_custom_tools_list': 'Listing custom tools',
  'cli_custom_tools_update': 'Updating custom tool',
  'cli_files_batch_delete': 'Deleting files',
  'cli_files_create': 'Creating file',
  'cli_files_delete': 'Deleting file',
  'cli_files_describe': 'Inspecting file',
  'cli_files_folders_create': 'Creating file folder',
  'cli_files_folders_delete': 'Deleting file folder',
  'cli_files_folders_list': 'Listing file folders',
  'cli_files_folders_move': 'Moving file folder',
  'cli_files_folders_restore': 'Restoring file folder',
  'cli_files_get': 'Reading file',
  'cli_files_list': 'Listing files',
  'cli_files_ls': 'Listing files',
  'cli_files_mkdir': 'Creating file',
  'cli_files_move': 'Moving file',
  'cli_files_read': 'Reading file',
  'cli_files_rename': 'Renaming file',
  'cli_files_restore': 'Restoring file',
  'cli_files_set_content': 'Writing file',
  'cli_files_share_get': 'Checking file sharing',
  'cli_files_share_set': 'Updating file sharing',
  'cli_files_unzip': 'Unzipping file',
  'cli_files_upload': 'Uploading file',
  'cli_knowledge_chunks_batch_update': 'Updating knowledge chunks',
  'cli_knowledge_chunks_create': 'Creating knowledge chunk',
  'cli_knowledge_chunks_delete': 'Deleting knowledge chunk',
  'cli_knowledge_chunks_get': 'Reading knowledge chunk',
  'cli_knowledge_chunks_list': 'Listing knowledge chunks',
  'cli_knowledge_chunks_update': 'Updating knowledge chunk',
  'cli_knowledge_connectors_create': 'Creating knowledge connector',
  'cli_knowledge_connectors_delete': 'Deleting knowledge connector',
  'cli_knowledge_connectors_documents_list': 'Listing connector documents',
  'cli_knowledge_connectors_documents_update': 'Updating connector documents',
  'cli_knowledge_connectors_get': 'Reading knowledge connector',
  'cli_knowledge_connectors_list': 'Listing knowledge connectors',
  'cli_knowledge_connectors_sync': 'Syncing knowledge connector',
  'cli_knowledge_connectors_update': 'Updating knowledge connector',
  'cli_knowledge_create': 'Creating knowledge base',
  'cli_knowledge_delete': 'Deleting knowledge base',
  'cli_knowledge_documents_batch_update': 'Updating documents',
  'cli_knowledge_documents_delete': 'Deleting document',
  'cli_knowledge_documents_get': 'Reading document',
  'cli_knowledge_documents_list': 'Listing documents',
  'cli_knowledge_documents_update': 'Updating document',
  'cli_knowledge_documents_upload': 'Uploading document',
  'cli_knowledge_folders_create': 'Creating knowledge folder',
  'cli_knowledge_folders_delete': 'Deleting knowledge folder',
  'cli_knowledge_folders_list': 'Listing knowledge folders',
  'cli_knowledge_folders_move': 'Moving knowledge folder',
  'cli_knowledge_from_workspace_files_create': 'Creating knowledge base',
  'cli_knowledge_get': 'Reading knowledge base',
  'cli_knowledge_list': 'Listing knowledge bases',
  'cli_knowledge_ls': 'Listing knowledge bases',
  'cli_knowledge_mkdir': 'Creating knowledge base',
  'cli_knowledge_mv': 'Moving knowledge base',
  'cli_knowledge_restore': 'Restoring knowledge base',
  'cli_knowledge_search': 'Searching knowledge base',
  'cli_knowledge_tags_cleanup': 'Cleaning up knowledge tags',
  'cli_knowledge_tags_create': 'Creating knowledge tag',
  'cli_knowledge_tags_delete': 'Deleting knowledge tag',
  'cli_knowledge_tags_list': 'Listing knowledge tags',
  'cli_knowledge_tags_next_slot': 'Checking knowledge tag slots',
  'cli_knowledge_tags_save': 'Saving knowledge tags',
  'cli_knowledge_tags_update': 'Updating knowledge tag',
  'cli_knowledge_tags_usage': 'Summarizing knowledge tag usage',
  'cli_knowledge_update': 'Updating knowledge base',
  'cli_logs_follow': 'Following run logs',
  'cli_logs_get': 'Reading run log',
  'cli_logs_list': 'Listing run logs',
  'cli_logs_stats': 'Summarizing run logs',
  'cli_mcp_servers_create': 'Creating MCP server',
  'cli_mcp_servers_delete': 'Deleting MCP server',
  'cli_mcp_servers_get': 'Reading MCP server',
  'cli_mcp_servers_list': 'Listing MCP servers',
  'cli_mcp_servers_tools_list': 'Listing MCP server tools',
  'cli_mcp_servers_update': 'Updating MCP server',
  'cli_meta_status': 'Checking platform status',
  'cli_secrets_delete': 'Deleting secret',
  'cli_secrets_list': 'Listing secrets',
  'cli_secrets_set': 'Saving secret',
  'cli_skills_create': 'Creating skill',
  'cli_skills_delete': 'Deleting skill',
  'cli_skills_editors_create': 'Granting skill editor',
  'cli_skills_editors_delete': 'Revoking skill editor',
  'cli_skills_editors_list': 'Listing skill editors',
  'cli_skills_get': 'Reading skill',
  'cli_skills_list': 'Listing skills',
  'cli_skills_update': 'Updating skill',
  'cli_tables_batch_delete': 'Deleting tables',
  'cli_tables_cancel_runs': 'Cancelling table runs',
  'cli_tables_columns_create': 'Creating table column',
  'cli_tables_columns_delete': 'Deleting table column',
  'cli_tables_columns_update': 'Updating table column',
  'cli_tables_create': 'Creating table',
  'cli_tables_delete': 'Deleting table',
  'cli_tables_dispatches_cancel': 'Cancelling table run',
  'cli_tables_dispatches_create': 'Starting table run',
  'cli_tables_dispatches_get': 'Reading table run',
  'cli_tables_dispatches_list': 'Listing table runs',
  'cli_tables_enrichment_get': 'Reading enrichment run',
  'cli_tables_exports_cancel': 'Cancelling table export',
  'cli_tables_exports_create': 'Creating table export',
  'cli_tables_exports_download': 'Downloading table export',
  'cli_tables_exports_get': 'Reading table export',
  'cli_tables_folders_create': 'Creating table folder',
  'cli_tables_folders_delete': 'Deleting table folder',
  'cli_tables_folders_list': 'Listing table folders',
  'cli_tables_folders_move': 'Moving table folder',
  'cli_tables_folders_restore': 'Restoring table folder',
  'cli_tables_get': 'Reading table',
  'cli_tables_groups_create': 'Creating workflow group',
  'cli_tables_groups_delete': 'Deleting workflow group',
  'cli_tables_groups_list': 'Listing workflow groups',
  'cli_tables_groups_update': 'Updating workflow group',
  'cli_tables_import': 'Importing table',
  'cli_tables_imports_cancel': 'Cancelling table import',
  'cli_tables_imports_get': 'Reading table import',
  'cli_tables_list': 'Listing tables',
  'cli_tables_ls': 'Listing tables',
  'cli_tables_mkdir': 'Creating table',
  'cli_tables_move': 'Moving table',
  'cli_tables_mv': 'Moving table',
  'cli_tables_restore': 'Restoring table',
  'cli_tables_rows_batch_delete': 'Deleting table rows',
  'cli_tables_rows_batch_update': 'Updating table rows',
  'cli_tables_rows_count': 'Counting table rows',
  'cli_tables_rows_create': 'Creating table row',
  'cli_tables_rows_delete': 'Deleting table row',
  'cli_tables_rows_enrich': 'Enriching table row',
  'cli_tables_rows_get': 'Reading table row',
  'cli_tables_rows_list': 'Listing table rows',
  'cli_tables_rows_query': 'Querying table rows',
  'cli_tables_rows_search': 'Searching table rows',
  'cli_tables_rows_update': 'Updating table row',
  'cli_tables_rows_update_each': 'Updating table rows',
  'cli_tables_update': 'Updating table',
  'cli_tables_upsert': 'Updating table',
  'cli_tables_views_create': 'Creating table view',
  'cli_tables_views_delete': 'Deleting table view',
  'cli_tables_views_get': 'Reading table view',
  'cli_tables_views_list': 'Listing table views',
  'cli_tables_views_update': 'Updating table view',
  'cli_tools_get': 'Reading integration operation',
  'cli_tools_list': 'Listing integration operations',
  'cli_workflow_mcp_servers_create': 'Creating workflow MCP server',
  'cli_workflow_mcp_servers_delete': 'Deleting workflow MCP server',
  'cli_workflow_mcp_servers_get': 'Reading workflow MCP server',
  'cli_workflow_mcp_servers_list': 'Listing workflow MCP servers',
  'cli_workflow_mcp_servers_tools_create': 'Publishing workflow as MCP tool',
  'cli_workflow_mcp_servers_tools_delete': 'Unpublishing workflow MCP tool',
  'cli_workflow_mcp_servers_tools_list': 'Listing workflow MCP tools',
  'cli_workflow_mcp_servers_update': 'Updating workflow MCP server',
  'cli_workflows_activate_create': 'Activating workflow version',
  'cli_workflows_chat_publish': 'Publishing chat deployment',
  'cli_workflows_chat_status': 'Checking chat deployment',
  'cli_workflows_chat_unpublish': 'Unpublishing chat deployment',
  'cli_workflows_create': 'Creating workflow',
  'cli_workflows_delete': 'Deleting workflow',
  'cli_workflows_deploy': 'Deploying workflow',
  'cli_workflows_deployment_status': 'Checking deployment status',
  'cli_workflows_deployment_update': 'Updating API access',
  'cli_workflows_duplicate_create': 'Duplicating workflow',
  'cli_workflows_export': 'Exporting workflow',
  'cli_workflows_folders_create': 'Creating workflow folder',
  'cli_workflows_folders_delete': 'Deleting workflow folder',
  'cli_workflows_folders_list': 'Listing workflow folders',
  'cli_workflows_folders_move': 'Moving workflow folder',
  'cli_workflows_get': 'Reading workflow',
  'cli_workflows_import': 'Importing workflow',
  'cli_workflows_list': 'Listing workflows',
  'cli_workflows_ls': 'Listing workflows',
  'cli_workflows_mkdir': 'Creating workflow',
  'cli_workflows_move': 'Moving workflow',
  'cli_workflows_mv': 'Moving workflow',
  'cli_workflows_operations_apply': 'Editing workflow',
  'cli_workflows_restore': 'Restoring workflow',
  'cli_workflows_revert_create': 'Reverting workflow',
  'cli_workflows_rollback': 'Rolling back workflow',
  'cli_workflows_run': 'Running workflow',
  'cli_workflows_runs_cancel': 'Cancelling workflow run',
  'cli_workflows_runs_get': 'Checking workflow run',
  'cli_workflows_runs_list': 'Listing workflow runs',
  'cli_workflows_runs_resume': 'Resuming workflow run',
  'cli_workflows_runs_wait': 'Waiting for workflow run',
  'cli_workflows_state_get': 'Reading workflow',
  'cli_workflows_state_replace': 'Rewriting workflow',
  'cli_workflows_undeploy': 'Undeploying workflow',
  'cli_workflows_update': 'Updating workflow',
  'cli_workflows_variables_update': 'Updating workflow variables',
  'cli_workflows_versions_get': 'Reading workflow version',
  'cli_workflows_versions_list': 'Listing workflow versions',
  'cli_workflows_versions_update': 'Updating workflow version',
  'cli_workspaces_get': 'Reading workspace',
  'cli_workspaces_list': 'Listing workspaces',
  'cli_workspaces_members': 'Listing workspace members',
  'cli_blocks_tips': 'Reading block guidance',
  'cli_docs_search': 'Searching Sim docs',
  'cli_files_grep': 'Searching file contents',
  'cli_files_view': 'Viewing file',
  'cli_grep': 'Searching the workspace',
  'cli_integrations_list': 'Finding connected integration actions',
  'cli_logs_query': 'Querying run history',
  'cli_outputs_get': 'Reading saved tool output',
  'cli_reference': 'Reading command reference',
  'cli_to_sandbox': 'Saving results',
  'cli_workflow_blocks': 'Listing workflow blocks',
  'cli_workflow_deps': 'Tracing block inputs',
  'cli_workflow_edges': 'Reading workflow wiring',
  'cli_workflow_grep': 'Searching workflow',
  'cli_workflow_lint': 'Validating workflow',
  'cli_workflow_trace': 'Analyzing run trace',
  'cli_workflows_grep': 'Searching workflows',
  'cli_workflows_deps': 'Tracing workflow inputs',
  'cli_workflows_api': 'Reading workflow API details',
  'cli_workflows_lint': 'Validating workflow',
  'cli_workflows_tools': 'Inspecting workflow tools',
  'cli_help': 'Checking CLI reference',
  'sim_cli': 'Running CLI command',
  'run_code': 'Running code',
  'load_skill': 'Loading skill',
  'read_output': 'Reading full output',
  'remember': 'Updating memory',
  'task': 'Delegating task',
};

/// display.ts:705 `ACRONYM_CASING`.
const Map<String, String> _acronymCasing = {
  'mcp': 'MCP',
  'api': 'API',
  'oauth': 'OAuth',
  'url': 'URL',
  'id': 'ID',
  'ai': 'AI',
};

/// Casing for [humanizeDisplayIdentifier].
enum IdentifierCasing {
  /// Only the first word capitalized (resource names appended to a verb).
  sentence,

  /// Every word capitalized (standalone tool-name fallbacks).
  title,
}

/// Humanize an internal identifier without leaking snake_case or kebab-case
/// (display.ts:719 `humanizeDisplayIdentifier`).
String humanizeDisplayIdentifier(
  String name, {
  IdentifierCasing casing = IdentifierCasing.title,
}) {
  final words = _stripVersionSuffix(
    name,
  ).split(RegExp('[-_]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return name;
  return [
    for (var index = 0; index < words.length; index++)
      _humanizeWord(words[index], index, casing),
  ].join(' ');
}

String _humanizeWord(String word, int index, IdentifierCasing casing) {
  final normalized = word.toLowerCase();
  final acronym = _acronymCasing[normalized];
  if (acronym != null) return acronym;
  if (casing == IdentifierCasing.sentence && index > 0) return normalized;
  return normalized[0].toUpperCase() + normalized.substring(1);
}

/// Final fallback: humanize a raw tool name (`manage_folder` → "Manage
/// Folder"), display.ts:740 `humanizeToolName`.
String humanizeToolName(String name) => humanizeDisplayIdentifier(name);

// ---------------------------------------------------------------------------
// Wait / agents / terminal (display.ts:745-851)
// ---------------------------------------------------------------------------

String _formatWaitTitle(int seconds, String reason) {
  final duration = seconds > 0 ? ' ${seconds}s' : '';
  return reason.isNotEmpty
      ? 'Waiting$duration for $reason'
      : 'Waiting$duration';
}

int _requestedWaitSeconds(_Args args) {
  final raw = args?['seconds'];
  return raw is num && raw.isFinite && raw > 0 ? raw.round() : 0;
}

String _waitTitle(_Args args) =>
    _formatWaitTitle(_requestedWaitSeconds(args), _stringArg(args, 'reason'));

/// display.ts:767 `humanizeAgentId`.
String _humanizeAgentId(String id) {
  final stem = id.replaceFirst(RegExp(r'-\d+$'), '');
  return stem.isNotEmpty ? humanizeDisplayIdentifier(stem) : id;
}

/// display.ts:773 `waitAgentsTitle`.
String _waitAgentsTitle(_Args args) {
  final raw = args?['agent_ids'];
  final ids = raw is List ? raw.whereType<String>().toList() : <String>[];
  final names = ids.map(_humanizeAgentId).toList();
  final anyMode = _stringArg(args, 'mode') == 'any';
  if (names.length == 1) return 'Waiting for ${names[0]}';
  if (names.length > 1) {
    final listed = '${names[0]} + ${names.length - 1}';
    return anyMode ? 'Waiting for the first of $listed' : 'Waiting for $listed';
  }
  return 'Waiting for agents';
}

/// The title of a pause that is still running, counting down what is left
/// (display.ts:794 `getWaitCountdownTitle`). At zero the number is dropped.
String getWaitCountdownTitle(Map<String, Object?>? args, int elapsedMs) {
  final elapsedSeconds = elapsedMs < 0 ? 0 : elapsedMs ~/ 1000;
  final remaining = _requestedWaitSeconds(args) - elapsedSeconds;
  return _formatWaitTitle(
    remaining < 0 ? 0 : remaining,
    _stringArg(args, 'reason'),
  );
}

const int _maxCommandTitleLength = 48;
const int _maxQuotedTitleValueLength = 32;

String _runningCommandTitle(String rawCommand) {
  final command = rawCommand.replaceAll(RegExp(r'\s+'), ' ');
  if (command.isEmpty) return 'Running command';
  return 'Running ${_truncate(command, _maxCommandTitleLength - 1, '…')}';
}

const Map<String, String> _terminalOperationTitles = {
  'read': 'Reading terminal',
  'input': 'Typing into terminal',
  'kill': 'Stopping command',
  'cwd': 'Checking terminal',
  'list': 'Listing terminals',
  'new': 'Opening terminal',
  'switch': 'Switching terminal',
  'close': 'Closing terminal',
  'panes': 'Listing tmux panes',
};

/// display.ts:839 `terminalTitle`.
String _terminalTitle(_Args args) {
  final operation = _stringArg(args, 'operation');
  final inner = _asRecord(args?['args']);
  if (operation == 'run') {
    return _runningCommandTitle(_stringArg(inner, 'command'));
  }
  if (operation == 'handoff') {
    final reason = _stringArg(inner, 'reason');
    return reason.isNotEmpty
        ? 'Waiting for you: $reason'
        : 'Waiting for you in the terminal';
  }
  return _terminalOperationTitles[operation] ?? 'Using terminal';
}

final RegExp _cliSettingsPattern = RegExp(
  r'^cli_settings_(account|organization|workspace)_(list|get|open|describe|update|execute)$',
);
final RegExp _cliSourcesPattern = RegExp(
  r'^cli_search_sources_(list|get|setup|approve|providers)$',
);
const Map<String, String> _cliRetrievalServices = {
  'cli_workspaces_create': 'workspaces',
  'cli_workspaces_list': 'list_workspaces',
  'cli_search_query': 'search_workspace',
  'cli_search_read': 'read_document',
};

/// display.ts:854 `cliServiceDisplay`: CLI services reuse the domain title
/// formatter, including the parsed invocation input on replay.
(String, Map<String, Object?>)? _cliServiceDisplay(String name, _Args args) {
  final settings = _cliSettingsPattern.firstMatch(name);
  final sources = _cliSourcesPattern.firstMatch(name);
  final serviceName = settings != null
      ? 'settings'
      : sources != null
      ? 'search_sources'
      : _cliRetrievalServices[name];
  if (serviceName == null) return null;
  final invocation = _recordArg(_recordArg(args, 'request'), 'invocation');
  if (invocation?['kind'] == 'service' && invocation?['name'] == serviceName) {
    return (
      serviceName,
      _recordArg(invocation, 'input') ?? <String, Object?>{},
    );
  }
  final positional = cliFirstPositional(name, args);
  final Map<String, Object?> input;
  if (settings != null) {
    input = {
      'scope': settings.group(1),
      'action': settings.group(2),
      'section': positional,
    };
  } else if (sources != null) {
    input = {
      'action': sources.group(1),
      'connectorType': _cliFlag(args, '--connector-type'),
      'approved': _cliFlag(args, '--approved') != 'false',
    };
  } else if (serviceName == 'workspaces') {
    input = {'action': 'create', 'name': _cliFlag(args, '--name')};
  } else {
    input = {};
  }
  return (serviceName, input);
}

// ---------------------------------------------------------------------------
// getToolDisplayTitle (display.ts:902)
// ---------------------------------------------------------------------------

final RegExp _mcpToolPattern = RegExp(r'^mcp-[^-]+-(.+)$');
final RegExp _blockSchemaPath = RegExp(r'^components/blocks/([^/]+)\.json$');
final RegExp _blockTipsPath = RegExp(
  r'^components/blocks/([^/]+)/README\.md$',
);
final RegExp _workflowArtifactPath = RegExp(r'^workflows/([^/]+)/([^/]+)$');

/// Resolve a tool-call display title from its name and arguments
/// (display.ts:902 `getToolDisplayTitle`). Argument-aware cases come first,
/// then the static map, then the CLI map, then a humanized fallback. Never
/// returns an empty string.
String getToolDisplayTitle(String name, [Map<String, Object?>? args]) {
  final service = _cliServiceDisplay(name, args);
  if (service != null) return getToolDisplayTitle(service.$1, service.$2);
  final mcpMatch = _mcpToolPattern.firstMatch(name)?.group(1);
  if (mcpMatch != null && mcpMatch.isNotEmpty) {
    return humanizeToolName(mcpMatch);
  }
  return _argumentAwareTitle(name, args) ??
      _toolTitles[name] ??
      _cliToolTitles[name] ??
      humanizeToolName(name);
}

String _withTarget(String target, String present, String absent) =>
    target.isNotEmpty ? present : absent;

String? _argumentAwareTitle(String name, _Args args) {
  String s(String key) => _stringArg(args, key);
  String first(List<String> keys) => _firstStringArg(args, keys);
  String? cliTitle() => _cliToolTitles[name];

  switch (name) {
    case 'workspaces':
      final workspaceName = s('name');
      return 'Creating workspace${workspaceName.isNotEmpty ? ': $workspaceName' : ''}';
    case 'settings':
      final scope = s('scope');
      final section = s('section');
      final operation = s('operation');
      final target =
          '${scope.isNotEmpty ? '$scope ' : ''}settings${section.isNotEmpty ? ': ${humanizeDisplayIdentifier(section, casing: IdentifierCasing.sentence)}' : ''}';
      final opSuffix = operation.isNotEmpty
          ? ' — ${humanizeDisplayIdentifier(operation, casing: IdentifierCasing.sentence)}'
          : '';
      switch (s('action')) {
        case 'list':
          return 'Listing $target';
        case 'get':
          return 'Reading $target';
        case 'open':
          return 'Opening $target';
        case 'update':
          return 'Updating $target';
        case 'describe':
          return 'Reading $target$opSuffix requirements';
        case 'execute':
          return 'Running $target$opSuffix';
        default:
          return 'Checking $target';
      }
    case 'search_sources':
      final connector = s('connectorType');
      final target = connector.isNotEmpty
          ? '${humanizeDisplayIdentifier(connector)} search sources'
          : 'search sources';
      switch (s('action')) {
        case 'list':
          return 'Listing $target';
        case 'get':
          return 'Reading search source details';
        case 'providers':
          return 'Listing search source providers';
        case 'setup':
          return 'Preparing $target setup';
        case 'approve':
          return '${args?['approved'] == false ? 'Disabling' : 'Enabling'} $target';
        default:
          return 'Checking search sources';
      }
    case 'cli_blocks_get':
      final block = _stringValue(cliFirstPositional(name, args));
      final operation = _cliFlag(args, '--operation');
      final operationName =
          block.isNotEmpty &&
              operation != null &&
              operation.startsWith('${block}_')
          ? operation.substring(block.length + 1)
          : operation;
      final subject = [
        if (block.isNotEmpty) blockDisplayName(block),
        if (operationName != null && operationName.isNotEmpty)
          humanizeToolName(operationName),
      ].join(' ');
      return subject.isNotEmpty ? 'Reading $subject configuration' : cliTitle();
    case 'cli_blocks_tips':
      final block = _stringValue(cliFirstPositional(name, args));
      return block.isNotEmpty
          ? 'Reading ${blockDisplayName(block)} guidance'
          : cliTitle();
    case 'cli_blocks_list':
    case 'cli_tools_list':
      final query = _cliFlag(args, '--search') ?? _cliFlag(args, '--query');
      return query != null
          ? 'Searching ${name == 'cli_blocks_list' ? 'blocks' : 'integration operations'} for ${_truncateMiddle(query, 60)}'
          : cliTitle();
    case 'cli_tools_get':
      final operation = _stringValue(cliFirstPositional(name, args));
      return operation.isNotEmpty
          ? 'Reading ${humanizeToolName(operation)} operation'
          : cliTitle();
    case 'cli_reference':
    case 'cli_docs_search':
    case 'cli_grep':
      final target = _stringValue(cliFirstPositional(name, args));
      return target.isNotEmpty
          ? '${cliTitle()} for ${_truncateMiddle(target, 60)}'
          : cliTitle();
    case 'cli_integrations_list':
      final query = _cliFlag(args, '--query');
      final service = _cliFlag(args, '--service');
      if (query != null) {
        return 'Finding integration actions for ${_truncateMiddle(query, 60)}';
      }
      return service != null
          ? 'Finding ${humanizeToolName(service)} actions'
          : cliTitle();
    case 'cli_files_read':
      final path = cliFirstPositional(name, args);
      return path != null && path.contains('/')
          ? 'Reading ${_pathLeaf(path)}'
          : cliTitle();
    case 'cli_files_view':
      final path = _stringValue(cliFirstPositional(name, args));
      return path.isNotEmpty ? 'Viewing ${_pathLeaf(path)}' : cliTitle();
    case 'cli_workflows_create':
    case 'cli_tables_create':
    case 'cli_files_create':
    case 'cli_knowledge_create':
      final title = _cliFlag(args, '--name') ?? _cliFlag(args, '--title');
      return title != null ? 'Creating $title' : cliTitle();
    case 'cli_workflows_operations_apply':
    case 'cli_workflows_state_replace':
      if (_stringArrayArg(args, 'args').contains('--dry-run')) {
        return 'Validating workflow changes';
      }
      return cliTitle() ?? humanizeToolName(name);
    case 'deploy_as_api':
      return _deploymentTitle(args, 'API');
    case 'deploy_as_chat':
      return _deploymentTitle(args, 'chat');
    case 'publish_custom_block':
      return '${s('action') == 'undeploy' ? 'Unpublishing' : 'Publishing'} custom block';
    case 'ffmpeg':
      return _ffmpegTitle(args);
    case 'manage_knowledge_base':
      return _knowledgeBaseTitle(args);
    case 'query_user_table':
      return _queryUserTableTitle(args);
    case 'table_manage':
    case 'table_rows':
    case 'table_columns':
    case 'table_automations':
    case 'table_enrichments':
    case 'table_views':
      return _splitTableTitle(name, args);
    case 'search_knowledge_base':
      return _searchKnowledgeBaseTitle(args);
    case 'manage_sandbox':
      return _manageSandboxTitle(args);
    case 'user_table':
      return _userTableTitle(args);
    case 'save_upload':
      return _materializeFileTitle(args);
    case 'open_resource':
      return _openResourceTitle(args);
    case 'wait':
      return _waitTitle(args);
    case 'wait_agents':
      return _waitAgentsTitle(args);
    case 'tail_agent':
      return 'Checking on ${_agentOr(s('agent_id'))}';
    case 'steer_agent':
      return 'Steering ${_agentOr(s('agent_id'))}';
    case 'interrupt_agent':
      return 'Stopping ${_agentOr(s('agent_id'))}';
    case 'terminal':
      return _terminalTitle(args);
    case 'terminal_run':
      return _runningCommandTitle(s('command'));
    case 'terminal_read':
      return 'Reading terminal';
    case 'terminal_input':
      return 'Typing into terminal';
    case 'terminal_kill':
      return 'Stopping command';
    case 'terminal_cwd':
      return 'Checking terminal';
    case 'terminal_list':
      return 'Listing terminals';
    case 'terminal_new':
      return 'Opening terminal';
    case 'terminal_switch':
      return 'Switching terminal';
    case 'terminal_close':
      return 'Closing terminal';
    case 'restore_resource':
      final type = s('type');
      return 'Restoring ${type.isNotEmpty ? _resourceTypeLabel(type) : 'resource'}';
    case 'load_deployment':
      final version = _stringOrNumberArg(args, 'version');
      if (version.isEmpty) return 'Loading deployment';
      return version == 'live'
          ? 'Loading live deployment'
          : 'Loading deployment version $version';
    case 'update_deployment_version':
      final version = _stringOrNumberArg(args, 'version');
      return version.isNotEmpty
          ? 'Updating deployment version $version'
          : 'Updating deployment';
    case 'generate_api_key':
      final keyName = s('name');
      return _withTarget(
        keyName,
        'Generating API key $keyName',
        'Generating API key',
      );
    case 'connect_slack_bot':
      final botName = s('displayName');
      return _withTarget(
        botName,
        'Connecting $botName',
        'Connecting Slack bot',
      );
    case 'list_integration_tools':
      final integration = s('integration');
      return integration.isNotEmpty
          ? 'Listing ${humanizeToolName(integration)} tools'
          : 'Listing integration tools';
    case 'set_environment_variables':
      final scope = s('scope');
      return 'Setting ${scope.isNotEmpty ? scope : 'workspace'} environment variables';
    case 'set_global_workflow_variables':
      return _setGlobalWorkflowVariablesTitle(args);
    case 'create_empty_file':
      return _createFileTitle(args);
    case 'share_file':
      final rawAction = s('action');
      final action = rawAction.isNotEmpty ? rawAction : 'share';
      final path = s('path');
      final named = first(const ['toolTitle', 'title']);
      final target = named.isNotEmpty
          ? named
          : (path.isNotEmpty ? _pathLeaf(path) : 'file');
      return action == 'unshare' ? 'Unsharing $target' : 'Sharing $target';
    case 'create_workflow':
      final target = first(const ['name', 'workflowName', 'title']);
      return 'Creating ${target.isNotEmpty ? target : 'workflow'}';
    case 'edit_workflow':
      final target = first(const ['workflowName', 'name', 'title']);
      return 'Editing ${target.isNotEmpty ? target : 'workflow'}';
    case 'create_workspace_mcp_server':
      final target = first(const ['name', 'serverName', 'title']);
      return 'Creating ${target.isNotEmpty ? target : 'MCP server'}';
    case 'update_workspace_mcp_server':
      final target = first(const ['name', 'serverName', 'title']);
      return 'Updating ${target.isNotEmpty ? target : 'MCP server'}';
    case 'delete_workspace_mcp_server':
      final target = first(const ['serverName', 'name', 'title']);
      return 'Deleting ${target.isNotEmpty ? target : 'MCP server'}';
    case 'web_search':
      final target = first(const ['toolTitle', 'title', 'query']);
      return target.isNotEmpty
          ? 'Searching online for "${_truncate(target, _maxQuotedTitleValueLength)}"'
          : 'Searching online';
    case 'task':
      final target = s('title');
      return target.isNotEmpty
          ? 'Delegating: ${_truncate(target, _maxQuotedTitleValueLength)}'
          : 'Delegating task';
    case 'search_docs':
      final target = first(const ['toolTitle', 'title', 'query']);
      return target.isNotEmpty
          ? 'Searching Sim docs for "${_truncate(target, _maxQuotedTitleValueLength)}"'
          : 'Searching Sim docs';
    case 'grep':
      final target = first(const ['toolTitle', 'title']);
      return _withTarget(target, 'Searching for $target', 'Searching');
    case 'glob':
      final target = first(const ['toolTitle', 'title']);
      return _withTarget(target, 'Finding $target', 'Finding files');
    case 'mv':
      return _mvTitle(args);
    case 'cp':
      final target = first(const ['toolTitle', 'title']);
      return _withTarget(target, 'Duplicating $target', 'Duplicating workflow');
    case 'mkdir':
      final path = s('path');
      if (path.isNotEmpty) return 'Creating folder ${_pathLeaf(path)}';
      final target = first(const ['toolTitle', 'title']);
      return _withTarget(target, 'Creating $target', 'Creating folder');
    case 'rm':
      final named = first(const ['toolTitle', 'title']);
      final target = named.isNotEmpty
          ? named
          : _summarizeTargets(
              _stringArrayArg(args, 'paths').map(_pathLeaf),
              'resource',
            );
      return _withTarget(target, 'Deleting $target', 'Deleting');
    case 'load_integration_tool':
      final integration = first(const ['integration', 'service', 'toolId']);
      return _withTarget(
        integration,
        'Loading $integration tools',
        'Loading integration tools',
      );
    case 'load_skill':
      final skill = first(const ['name', 'skillId', 'skill']);
      return _withTarget(skill, 'Loading skill $skill', 'Loading skill');
    case 'run_enrichment':
      final subject = _nestedStringArg(args, 'inputs', const [
        'fullName',
        'companyName',
        'domain',
        'email',
        'companyDomain',
      ]);
      return _withTarget(subject, 'Looking up $subject', 'Looking up data');
    case 'web_scrape':
      final url = s('url');
      return _withTarget(url, 'Scraping $url', 'Scraping page');
    case 'browser_navigate':
    case 'browser_open_url':
      final url = _displayUrl(s('url'));
      return _withTarget(url, 'Opening $url', 'Opening page');
    case 'browser_open_tab':
      final url = _displayUrl(s('url'));
      return _withTarget(url, 'Opening $url in a new tab', 'Opening new tab');
    case 'browser_wait_for':
      final text = s('text');
      final state = s('state');
      final url = s('urlContains');
      if (text.isNotEmpty) return 'Waiting for "$text"';
      if (state.isNotEmpty) return 'Waiting for element to be $state';
      return url.isNotEmpty
          ? 'Waiting for ${_displayUrl(url)}'
          : 'Waiting for page';
    case 'browser_find':
      final query = s('query');
      return query.isNotEmpty
          ? 'Finding "${_truncateMiddle(query, 32)}"'
          : 'Finding page element';
    case 'browser_set_checked':
      return args?['checked'] == false
          ? 'Unchecking control'
          : 'Checking control';
    case 'browser_zoom':
      final action = s('action');
      if (action == 'in') return 'Zooming in';
      if (action == 'out') return 'Zooming out';
      return action == 'reset' ? 'Resetting page zoom' : 'Changing page zoom';
    case 'generate_image':
    case 'generate_video':
    case 'generate_audio':
      final kind = name == 'generate_image'
          ? 'image'
          : name == 'generate_video'
          ? 'video'
          : 'audio';
      final named = first(const ['toolTitle', 'title']);
      final path = s('path');
      final target = named.isNotEmpty
          ? named
          : path.isNotEmpty
          ? _pathLeaf(path)
          : _firstOutputFileField(args, 'path');
      return target.isNotEmpty ? 'Generating $target' : 'Generating $kind';
    case 'download_file':
      final named = first(const ['fileName', 'toolTitle', 'title']);
      final path = s('path');
      final url = s('url');
      final target = named.isNotEmpty
          ? named
          : path.isNotEmpty
          ? _pathLeaf(path)
          : url.isNotEmpty
          ? _displayUrl(url)
          : '';
      return _withTarget(target, 'Downloading $target', 'Downloading file');
    case 'extract_doc_assets':
      final path = s('path');
      return path.isNotEmpty
          ? 'Extracting assets from ${_pathLeaf(path)}'
          : 'Extracting document assets';
    case 'search_library_docs':
      final library = first(const ['library_name', 'libraryName', 'library']);
      final query = s('query');
      if (library.isNotEmpty && query.isNotEmpty) {
        return 'Searching $library docs for $query';
      }
      if (library.isNotEmpty) return 'Searching $library docs';
      return query.isNotEmpty
          ? 'Searching library docs for $query'
          : 'Searching library docs';
    case 'run_code':
      final title = s('title');
      return title.isNotEmpty ? title : 'Running code';
    case 'browser_type':
    case 'browser_insert_text':
      final verb = name == 'browser_type' ? 'Typing' : 'Inserting';
      final text = s('text');
      return text.isNotEmpty
          ? '$verb "${_truncateMiddle(text, 32)}"'
          : '$verb text';
    case 'browser_press_key':
      final key = s('key');
      return _withTarget(key, 'Pressing $key', 'Pressing key');
    case 'browser_scroll':
      final direction = s('direction');
      return _withTarget(direction, 'Scrolling $direction', 'Scrolling page');
    case 'browser_extract':
      final instruction = s('instruction');
      return _withTarget(
        instruction,
        'Extracting $instruction',
        'Extracting page data',
      );
    case 'browser_request_takeover':
      final reason = s('reason');
      return _withTarget(
        reason,
        'Waiting for you: $reason',
        'Waiting for you in the browser',
      );
    case 'web_crawl':
      final url = s('url');
      return _withTarget(url, 'Crawling $url', 'Crawling website');
    case 'web_fetch':
      final urls = _stringArrayArg(args, 'urls');
      if (urls.length == 1) return 'Fetching ${urls[0]}';
      if (urls.length > 1) return 'Fetching ${urls.length} pages';
      return 'Fetching page';
    case 'manage_custom_tool':
      final named = first(const ['toolTitle', 'title', 'name']);
      final schema = _asRecord(args?['schema']);
      final target = named.isNotEmpty
          ? named
          : (schema != null
                ? _nestedStringArg(schema, 'function', const ['name'])
                : '');
      return _namedOperationTitle(args, target, 'Managing custom tool', const {
        'add': ('Creating', 'custom tool'),
        'edit': ('Updating', 'custom tool'),
        'delete': ('Deleting', 'custom tool'),
        'list': ('Viewing', 'custom tools'),
      });
    case 'manage_mcp_connection':
      final named = first(const ['serverName', 'name', 'title']);
      final target = named.isNotEmpty
          ? named
          : _nestedStringArg(args, 'config', const ['name']);
      return _namedOperationTitle(args, target, 'Managing MCP server', const {
        'add': ('Creating', 'MCP server'),
        'edit': ('Updating', 'MCP server'),
        'delete': ('Deleting', 'MCP server'),
        'list': ('Viewing', 'MCP servers'),
      });
    case 'manage_skill':
      final target = first(const ['name', 'skillName', 'title']);
      return _namedOperationTitle(args, target, 'Managing skill', const {
        'add': ('Creating', 'skill'),
        'edit': ('Updating', 'skill'),
        'delete': ('Deleting', 'skill'),
        'list': ('Viewing', 'skills'),
      });
    case 'manage_credential':
      if (s('operation') == 'rename') {
        final from = first(const [
          'previousDisplayName',
          'oldName',
          'credentialName',
        ]);
        final to = first(const ['displayName', 'newName', 'name', 'title']);
        if (from.isNotEmpty && to.isNotEmpty) return 'Renaming $from to $to';
        return _withTarget(
          to,
          'Renaming credential to $to',
          'Renaming credential',
        );
      }
      final target = first(const [
        'credentialName',
        'displayName',
        'name',
        'title',
      ]);
      return _namedOperationTitle(args, target, 'Managing credential', const {
        'delete': ('Deleting', 'credential'),
      });
    case 'get_deployment_status':
      final workflow = first(const ['workflowName', 'name']);
      return _withTarget(
        workflow,
        'Checking $workflow deployment status',
        'Checking deployment status',
      );
    case 'get_deployed_workflow_state':
      final workflow = first(const ['workflowName', 'name']);
      return _withTarget(
        workflow,
        'Reading deployed $workflow',
        'Reading the deployed version',
      );
    case 'get_workflow_run_options':
      final workflow = first(const ['workflowName', 'name']);
      return _withTarget(
        workflow,
        'Checking $workflow run settings',
        'Checking run settings',
      );
    case 'get_block_outputs':
      final workflow = first(const ['workflowName', 'name']);
      return _withTarget(
        workflow,
        'Reading $workflow block outputs',
        'Reading block outputs',
      );
    case 'get_block_upstream_references':
      final workflow = first(const ['workflowName', 'name']);
      return _withTarget(
        workflow,
        'Tracing $workflow block inputs',
        'Tracing block inputs',
      );
    case 'redeploy':
      final workflow = first(const ['workflowName', 'name']);
      return _withTarget(workflow, 'Redeploying $workflow', 'Redeploying API');
    case 'promote_to_live':
      final workflow = first(const ['workflowName', 'name']);
      final version = _stringOrNumberArg(args, 'version');
      if (workflow.isNotEmpty && version.isNotEmpty) {
        return 'Promoting $workflow version $version to live';
      }
      if (workflow.isNotEmpty) return 'Promoting $workflow to live';
      return version.isNotEmpty
          ? 'Promoting version $version to live'
          : 'Promoting to live';
    case 'run_workflow':
      final workflow = first(const ['workflowName', 'name']);
      return _withTarget(workflow, 'Running $workflow', 'Running workflow');
    case 'run_from_block':
      final block = first(const ['blockName', 'block_name', 'startBlockName']);
      final workflow = first(const ['workflowName', 'name']);
      if (block.isEmpty) return 'Running workflow';
      return workflow.isNotEmpty
          ? 'Running from $block in $workflow'
          : 'Running from $block';
    case 'run_workflow_until_block':
      final block = first(const ['blockName', 'block_name', 'untilBlockName']);
      final workflow = first(const ['workflowName', 'name']);
      if (block.isEmpty) {
        return _withTarget(workflow, 'Running $workflow', 'Running workflow');
      }
      return 'Running ${workflow.isNotEmpty ? workflow : 'workflow'} until $block';
    case 'run_block':
      final block = first(const ['blockName', 'block_name']);
      final workflow = first(const ['workflowName', 'name']);
      if (block.isEmpty) return 'Running block';
      return workflow.isNotEmpty
          ? 'Running $block in $workflow'
          : 'Running $block';
    case 'set_block_enabled':
      final block = first(const ['blockName', 'block_name']);
      final workflow = first(const ['workflowName', 'name']);
      final enabled = args?['enabled'];
      final verb = enabled == false
          ? 'Disabling'
          : enabled == true
          ? 'Enabling'
          : 'Toggling';
      if (block.isEmpty) return '$verb block';
      return workflow.isNotEmpty ? '$verb $block in $workflow' : '$verb $block';
    case 'query_logs':
      final title = s('title');
      if (title.isNotEmpty) return title;
      final workflowName = s('workflowName');
      final scope = workflowName.isNotEmpty ? ' for $workflowName' : '';
      switch (s('view')) {
        case 'stats':
          return 'Analyzing run stats$scope';
        case 'trace':
          return 'Reading execution trace';
        case 'overview':
          return 'Reading execution overview';
        case 'full':
          return 'Reading execution details';
        case 'list':
          return 'Querying logs$scope';
        default:
          return s('executionId').isNotEmpty
              ? 'Reading execution trace'
              : 'Querying logs$scope';
      }
    case 'read':
      return _readTitle(s('path'));
    case 'prepare_file_edit':
    case 'run_function':
      final title = name == 'prepare_file_edit'
          ? _workspaceFileTitle(args)
          : s('title');
      return title.isNotEmpty ? title : null;
  }
  return null;
}

String _agentOr(String agentId) {
  final humanized = _humanizeAgentId(agentId);
  return humanized.isNotEmpty ? humanized : 'agent';
}

String _mvTitle(_Args args) {
  final sources = _stringArrayArg(args, 'sources');
  final destination = _stringArg(args, 'destination');
  final verb = sources.length == 1
      ? mvDisplayVerb(sources[0], destination)
      : 'Moving';
  if (verb == 'Renaming' && sources.isNotEmpty && destination.isNotEmpty) {
    return 'Renaming ${_pathLeaf(sources[0])} to ${_pathLeaf(destination)}';
  }
  final target = _firstStringArg(args, const ['toolTitle', 'title']);
  if (target.isNotEmpty) return '$verb $target';
  if (sources.isNotEmpty && destination.isNotEmpty) {
    final what = _summarizeTargets(sources.map(_pathLeaf), 'files');
    return '$verb $what to ${_pathLeaf(destination)}';
  }
  return verb;
}

String? _readTitle(String path) {
  if (_isWorkflowArtifactPath(path, 'lint.json')) {
    return 'Validating workflow state';
  }
  final blockSchema = _blockSchemaPath.firstMatch(path);
  if (blockSchema != null) {
    return 'Loading ${blockDisplayName(_decodePathSegment(blockSchema.group(1)!))}';
  }
  final blockTips = _blockTipsPath.firstMatch(path);
  if (blockTips != null) {
    return 'Loading ${blockDisplayName(_decodePathSegment(blockTips.group(1)!))} tips';
  }
  final artifact = _workflowArtifactPath.firstMatch(path);
  if (artifact != null) {
    final file = artifact.group(2)!;
    final part =
        const {
          'meta.json': 'meta',
          'state.json': 'state',
          'deployment.json': 'deployment',
          'README.md': 'notes',
        }[file] ??
        _decodePathSegment(file);
    return 'Reading ${_decodePathSegment(artifact.group(1)!)} $part';
  }
  if (path.isNotEmpty) return 'Reading ${_pathLeaf(path)}';
  return null;
}

// ---------------------------------------------------------------------------
// CLI helpers (display.ts:1504-1566)
// ---------------------------------------------------------------------------

final RegExp _shortWorkspaceFlag = RegExp('^-w.+');

List<String> _cliArgv(_Args args, Map<String, Object?>? invocation) =>
    invocation?['kind'] == 'cli'
    ? _stringArrayArg(invocation, 'argv')
    : _stringArrayArg(args, 'args');

/// First positional after the synthetic CLI command path
/// (display.ts:1504 `cliFirstPositional`).
String? cliFirstPositional(String name, [Map<String, Object?>? args]) {
  final invocation = _recordArg(_recordArg(args, 'request'), 'invocation');
  if (invocation?['kind'] == 'augmentation') {
    final positionals = _stringArrayArg(invocation, 'positionals');
    return positionals.isEmpty ? null : positionals.first;
  }
  final argv = _cliArgv(args, invocation);
  final tokens = <String>[];
  for (var i = 0; i < argv.length; i++) {
    final token = argv[i];
    if (token == '--output' || token == '--workspace' || token == '-w') {
      i++;
      continue;
    }
    if (token.startsWith('--output=') ||
        token.startsWith('--workspace=') ||
        _shortWorkspaceFlag.hasMatch(token)) {
      continue;
    }
    if (token.startsWith('-')) break;
    tokens.add(token);
  }
  final joined = StringBuffer('cli');
  for (var i = 0; i < tokens.length; i++) {
    joined.write('_${tokens[i].replaceAll('-', '_')}');
    if (joined.toString() == name) {
      return i + 1 < tokens.length ? tokens[i + 1] : null;
    }
  }
  return null;
}

/// display.ts:1533 `cliFlag`: a display-safe flag value (opaque ids dropped).
String? _cliFlag(_Args args, String flag) {
  final value = _stringValue(cliFlagValue(args, flag));
  return value.isEmpty ? null : value;
}

/// Canonical flag value, ids included (display.ts:1538 `cliFlagValue`).
String? cliFlagValue(Map<String, Object?>? args, String flag) {
  final values = cliFlagValues(args, flag);
  return values.isEmpty ? null : values.first;
}

/// Every value of a variadic flag (display.ts:1543 `cliFlagValues`).
List<String> cliFlagValues(Map<String, Object?>? args, String flag) {
  final invocation = _recordArg(_recordArg(args, 'request'), 'invocation');
  if (invocation?['kind'] == 'augmentation') {
    final value = _recordArg(
      invocation,
      'flags',
    )?[flag.replaceFirst(RegExp('^-+'), '')];
    return value is String && value.trim().isNotEmpty
        ? [value.trim()]
        : const [];
  }
  final argv = _cliArgv(args, invocation);
  final values = <String>[];
  for (var i = 0; i < argv.length; i++) {
    final token = argv[i];
    if (token == '--') break;
    if (token == flag) {
      for (
        var next = i + 1;
        next < argv.length && !argv[next].startsWith('-');
        next++
      ) {
        values.add(argv[next]);
      }
    } else if (token.startsWith('$flag=')) {
      values.add(token.substring(flag.length + 1));
    } else if (flag == '-w' && _shortWorkspaceFlag.hasMatch(token)) {
      values.add(token.substring(2));
    }
  }
  return [
    for (final value in values)
      if (value.trim().isNotEmpty) value.trim(),
  ];
}

// ---------------------------------------------------------------------------
// Status-aware tense (display.ts:1575-1820)
// ---------------------------------------------------------------------------

/// display.ts:1575 `COMPLETED_VERB_REWRITES`: present participle → past
/// tense, applied to the leading word only.
const Map<String, String> completedVerbRewrites = {
  'Accessing': 'Accessed',
  'Adding': 'Added',
  'Applying': 'Applied',
  'Cancelling': 'Cancelled',
  'Calling': 'Called',
  'Checking': 'Checked',
  'Changing': 'Changed',
  'Clicking': 'Clicked',
  'Closing': 'Closed',
  'Combining': 'Combined',
  'Comparing': 'Compared',
  'Completing': 'Completed',
  'Converting': 'Converted',
  'Crawling': 'Crawled',
  'Creating': 'Created',
  'Deleting': 'Deleted',
  'Connecting': 'Connected',
  'Deploying': 'Deployed',
  'Dragging': 'Dragged',
  'Inserting': 'Inserted',
  'Publishing': 'Published',
  'Unpublishing': 'Unpublished',
  'Analyzing': 'Analyzed',
  'Disabling': 'Disabled',
  'Downloading': 'Downloaded',
  'Duplicating': 'Duplicated',
  'Editing': 'Edited',
  'Enabling': 'Enabled',
  'Executing': 'Executed',
  'Extracting': 'Extracted',
  'Fading': 'Faded',
  'Finding': 'Found',
  'Filling': 'Filled',
  'Gathering': 'Gathered',
  'Generating': 'Generated',
  'Going': 'Went',
  'Fetching': 'Fetched',
  'Tracing': 'Traced',
  'Wiring': 'Wired',
  'Configuring': 'Configured',
  'Looking': 'Looked',
  'Rotating': 'Rotated',
  'Hovering': 'Hovered',
  'Importing': 'Imported',
  'Inspecting': 'Inspected',
  'Listing': 'Listed',
  'Loading': 'Loaded',
  'Managing': 'Managed',
  'Mixing': 'Mixed',
  'Moving': 'Moved',
  'Opening': 'Opened',
  'Overwriting': 'Overwrote',
  'Preparing': 'Prepared',
  'Pressing': 'Pressed',
  'Processing': 'Processed',
  'Promoting': 'Promoted',
  'Querying': 'Queried',
  'Reading': 'Read',
  'Redeploying': 'Redeployed',
  'Reloading': 'Reloaded',
  'Removing': 'Removed',
  'Renaming': 'Renamed',
  'Requesting': 'Requested',
  'Resetting': 'Reset',
  'Resizing': 'Resized',
  'Restoring': 'Restored',
  'Running': 'Ran',
  'Saving': 'Saved',
  'Scanning': 'Scanned',
  'Scraping': 'Scraped',
  'Scrolling': 'Scrolled',
  'Searching': 'Searched',
  'Selecting': 'Selected',
  'Setting': 'Set',
  'Sharing': 'Shared',
  'Steering': 'Steered',
  'Stopping': 'Stopped',
  'Summarizing': 'Summarized',
  'Switching': 'Switched',
  'Syncing': 'Synced',
  'Taking': 'Took',
  'Toggling': 'Toggled',
  'Trimming': 'Trimmed',
  'Typing': 'Typed',
  'Unchecking': 'Unchecked',
  'Undeploying': 'Undeployed',
  'Unsharing': 'Unshared',
  'Updating': 'Updated',
  'Using': 'Used',
  'Validating': 'Validated',
  'Viewing': 'Viewed',
  'Waiting': 'Waited',
  'Writing': 'Wrote',
  'Zooming': 'Zoomed',
  'Activating': 'Activated',
  'Browsing': 'Browsed',
  'Cleaning': 'Cleaned',
  'Counting': 'Counted',
  'Delegating': 'Delegated',
  'Enriching': 'Enriched',
  'Exporting': 'Exported',
  'Following': 'Followed',
  'Granting': 'Granted',
  'Indexing': 'Indexed',
  'Reconnecting': 'Reconnected',
  'Resuming': 'Resumed',
  'Reverting': 'Reverted',
  'Revoking': 'Revoked',
  'Rewriting': 'Rewrote',
  'Rolling': 'Rolled',
  'Starting': 'Started',
  'Unzipping': 'Unzipped',
  'Uploading': 'Uploaded',
};

final Map<String, String> _activeVerbRewrites = {
  for (final entry in completedVerbRewrites.entries) entry.value: entry.key,
};

/// The past-tense form of a resolved title for a successful call
/// (display.ts:1699 `getToolCompletedTitle`), or `null` when no leading
/// gerund rewrite is known.
String? getToolCompletedTitle(String title) {
  final firstWord = firstWordOf(title);
  final past = completedVerbRewrites[firstWord];
  return past == null ? null : past + title.substring(firstWord.length);
}

/// display.ts:1716 `getToolActiveTitle`.
String _getToolActiveTitle(String title) {
  final firstWord = firstWordOf(title);
  final active = _activeVerbRewrites[firstWord];
  return active == null ? title : active + title.substring(firstWord.length);
}

/// The title of a call described as work in progress, as an open activity
/// header shows its latest call (display.ts:1727 `getToolInProgressTitle`):
/// a succeeded call returns to its in-progress verb; any other status keeps
/// its status-aware title.
String getToolInProgressTitle(
  String title,
  String status, {
  String? toolName,
  String? activityDescription,
}) => status == 'success'
    ? _getToolActiveTitle(
        getToolStatusDisplayTitle(
          title,
          'executing',
          toolName: toolName,
          activityDescription: activityDescription,
        ),
      )
    : getToolStatusDisplayTitle(
        title,
        status,
        toolName: toolName,
        activityDescription: activityDescription,
      );

const Set<String> _terminalTitlePrefixes = {
  'Failed',
  'Attempted',
  'Skipped',
  'Stopped',
};

/// The leading word of a title (display.ts:1744 `firstWordOf`).
String firstWordOf(String title) {
  final spaceIndex = title.indexOf(' ');
  return spaceIndex == -1 ? title : title.substring(0, spaceIndex);
}

String _stripColon(String word) => word.replaceFirst(RegExp(r':$'), '');

bool _statesTerminalOutcome(String title) =>
    _terminalTitlePrefixes.contains(_stripColon(firstWordOf(title)));

/// display.ts:1755 `getToolOutcomeTitle`.
String _getToolOutcomeTitle(
  String title,
  String outcome, {
  required bool preserveExistingOutcome,
}) {
  if (preserveExistingOutcome && _statesTerminalOutcome(title)) return title;
  final firstWord = firstWordOf(title);
  final statedOutcome = _stripColon(firstWord);
  if (!preserveExistingOutcome &&
      (_terminalTitlePrefixes.contains(statedOutcome) ||
          statedOutcome == 'Completed')) {
    return outcome + title.substring(statedOutcome.length);
  }
  if (completedVerbRewrites.containsKey(firstWord)) {
    return '$outcome ${firstWord[0].toLowerCase()}${firstWord.substring(1)}${title.substring(firstWord.length)}';
  }
  return '$outcome: $title';
}

/// display.ts:1776 `getNeutralToolActionTitle`: error rows describe the
/// action without failure badges or claims of completion.
String _getNeutralToolActionTitle(String title) {
  var action = title;
  while (action.isNotEmpty) {
    final firstWord = firstWordOf(action);
    final prefix = _stripColon(firstWord).toLowerCase();
    if (!const {'failed', 'stopped', 'skipped', 'completed'}.contains(prefix)) {
      break;
    }
    action = action.substring(firstWord.length).trimLeft();
  }
  if (action.isEmpty) return 'Tool activity';
  if (action == title) return title;
  final firstWord = firstWordOf(action);
  final gerund = firstWord[0].toUpperCase() + firstWord.substring(1);
  return completedVerbRewrites.containsKey(gerund)
      ? gerund + action.substring(firstWord.length)
      : action;
}

/// Resolve a tool title at the rendering boundary
/// (display.ts:1796 `getToolStatusDisplayTitle`). A model-authored
/// [activityDescription] replaces [title]. [status] is the wire string:
/// - `success`: known past-tense rewrite ("Reading x" → "Read x"), else
///   unchanged; `browser_request_takeover` reads "Resumed browser control";
/// - `error` / `rejected`: a neutral action, stripped of outcome prefixes;
/// - `cancelled` / `aborted` / `interrupted`: "Stopped …";
/// - `skipped`: "Skipped …";
/// - `awaiting_approval`: "Waiting for approval: …";
/// - anything else (`executing`): unchanged.
String getToolStatusDisplayTitle(
  String title,
  String status, {
  String? toolName,
  String? activityDescription,
}) {
  final description = normalizeToolActivityDescription(activityDescription);
  final resolved = description ?? title;
  if (status == 'success' && toolName == 'browser_request_takeover') {
    return 'Resumed browser control';
  }
  if (status == 'success') return getToolCompletedTitle(resolved) ?? resolved;
  if (status == 'error' || status == 'rejected') {
    return _getNeutralToolActionTitle(resolved);
  }
  if (status == 'cancelled' || status == 'aborted' || status == 'interrupted') {
    return _getToolOutcomeTitle(
      resolved,
      'Stopped',
      preserveExistingOutcome: description == null,
    );
  }
  if (status == 'skipped') {
    return _getToolOutcomeTitle(
      resolved,
      'Skipped',
      preserveExistingOutcome: description == null,
    );
  }
  if (status == 'awaiting_approval' &&
      !resolved.startsWith('Waiting for approval: ')) {
    return 'Waiting for approval: $resolved';
  }
  return resolved;
}

final RegExp _streamingArgsArray = RegExp(r'"args"\s*:\s*\[([^\]]*)');
final RegExp _completeStringToken = RegExp(r'"((?:[^"\\]|\\.)*)"');

/// Whether [candidate] names a known `cli_*` command (the title catalog or
/// the service display table): the recognizer the engine's
/// `refineStreamingCliToolName` needs (`CliToolNameRecognizer`).
bool isKnownCliToolName(String candidate) =>
    _cliToolTitles.containsKey(candidate) ||
    _cliServiceDisplay(candidate, null) != null;

/// Refines a streaming `sim_cli` call's derived name from its partial
/// argument JSON (display.ts:1835 `refineStreamingCliToolName`), so the row
/// upgrades from "Running CLI command" to the specific verb while the
/// arguments stream. Only names the title registry knows are returned.
String? refineStreamingCliToolName(String streamingArgs) {
  final argsBody = _streamingArgsArray.firstMatch(streamingArgs)?.group(1);
  if (argsBody == null || argsBody.isEmpty) return null;
  final tokens = [
    for (final match in _completeStringToken.allMatches(argsBody))
      match.group(1) ?? '',
  ];
  if (tokens.contains('--help') || tokens.contains('-h')) return 'cli_help';
  final path = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token == '--output' || token == '--workspace' || token == '-w') {
      i++;
      continue;
    }
    if (token.startsWith('-')) break;
    path.add(token);
  }
  for (var length = path.length < 4 ? path.length : 4; length >= 1; length--) {
    final candidate =
        'cli_${path.sublist(0, length).join('_').replaceAll('-', '_')}';
    if (_cliToolTitles.containsKey(candidate) ||
        _cliServiceDisplay(candidate, null) != null) {
      return candidate;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Client enrichment (stream-helpers.ts)
// ---------------------------------------------------------------------------

String? _stringParam(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// stream-helpers.ts:122 `resolveTargetWorkflowName`.
String? _resolveTargetWorkflowName(_Args args, ToolTitleContext? context) {
  final explicitName =
      _stringParam(args?['workflowName']) ?? _stringParam(args?['name']);
  if (explicitName != null) return explicitName;
  return context?._resource(
    'workflow',
    args?['workflowId'] ?? context.currentWorkflowId,
  );
}

/// Row text for an integration-gateway call
/// (stream-helpers.ts:184 `resolveIntegrationToolDisplayTitle`): the
/// model-authored `description`, readable as soon as it completes in the
/// still-streaming arguments; after the engine rebinds the row to the exact
/// operation, the preserved [integrationDescription].
String? resolveIntegrationToolDisplayTitle({
  required String name,
  Map<String, Object?>? args,
  String? streamingArgs,
  String? integrationDescription,
}) {
  if (name == 'call_integration_tool') {
    final description =
        _stringParam(args?['description']) ??
        extractStreamingStringArgument(streamingArgs, 'description')?.trim();
    return description == null || description.isEmpty ? null : description;
  }
  return integrationDescription;
}

const Set<String> _tableScopedToolIds = {
  'table_automations',
  'table_columns',
  'table_enrichments',
  'table_manage',
  'table_rows',
  'table_views',
};

const Set<String> _workflowScopedToolIds = {
  'deploy_as_api',
  'diff_workflows',
  'list_deployment_versions',
  'publish_custom_block',
  'deploy_as_chat',
  'deploy_as_mcp',
  'get_block_outputs',
  'get_block_upstream_references',
  'get_deployed_workflow_state',
  'get_deployment_status',
  'get_workflow_data',
  'get_workflow_run_options',
  'promote_to_live',
  'redeploy',
  'run_block',
  'set_block_enabled',
  'set_global_workflow_variables',
};

/// The title enriched with live workflow/block/table names
/// (stream-helpers.ts:233 `resolveToolDisplayTitle`). Without [context] (or
/// when it resolves nothing) this is [getToolDisplayTitle].
String resolveToolDisplayTitle(
  String name, [
  Map<String, Object?>? args,
  ToolTitleContext? context,
]) {
  String? workflow(Object? id) => context?._resource('workflow', id);
  String? block(Object? id) => context?._block(id);

  if (name == 'run_workflow') {
    final workflowName = workflow(args?['workflowId']);
    return workflowName != null ? 'Running $workflowName' : 'Running workflow';
  }
  if (name == 'run_from_block') {
    final workflowName = workflow(args?['workflowId']);
    final blockName = block(args?['startBlockId']);
    if (workflowName != null && blockName != null) {
      return 'Running $workflowName from $blockName';
    }
    if (workflowName != null) return 'Running $workflowName';
    if (blockName != null) return 'Running from $blockName';
    return 'Running workflow';
  }
  if (name == 'run_workflow_until_block') {
    final workflowName = workflow(args?['workflowId']);
    final blockName = block(args?['stopAfterBlockId']);
    if (workflowName != null && blockName != null) {
      return 'Running $workflowName until $blockName';
    }
    if (workflowName != null) return 'Running $workflowName';
    if (blockName != null) return 'Running until $blockName';
    return 'Running workflow';
  }
  if (name == 'edit_workflow') {
    final workflowName = _resolveTargetWorkflowName(args, context);
    return workflowName != null ? 'Editing $workflowName' : 'Editing workflow';
  }
  if (name == 'query_logs') {
    final workflowName =
        workflow(args?['workflowId']) ?? _stringParam(args?['workflowName']);
    if (workflowName != null) return 'Querying logs for $workflowName';
  }
  if (_tableScopedToolIds.contains(name)) {
    final nested = _asRecord(args?['args']);
    final tableName =
        _stringParam(args?['tableName']) ??
        context?._resource('table', nested?['tableId'] ?? args?['tableId']);
    if (nested != null || tableName != null) {
      return getToolDisplayTitle(name, {
        ...?args,
        ...?nested,
        'tableName': ?tableName,
      });
    }
  }
  if (_workflowScopedToolIds.contains(name) &&
      _stringParam(args?['workflowName']) == null) {
    final workflowName = _resolveTargetWorkflowName(args, context);
    final blockName =
        _stringParam(args?['blockName']) ?? block(args?['blockId']);
    if (workflowName != null || blockName != null) {
      return getToolDisplayTitle(name, {
        ...?args,
        'workflowName': ?workflowName,
        'blockName': ?blockName,
      });
    }
  }
  final resourceTitle = resolveNamedCliToolDisplayTitle(name, args, context);
  if (resourceTitle != null) return resourceTitle;
  return getToolDisplayTitle(name, args);
}

/// stream-helpers.ts:317 `decodeStreamingString`.
String _decodeStreamingString(String value) => value
    .replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    )
    .replaceAll(r'\"', '"')
    .replaceAll(r'\\', r'\');

/// stream-helpers.ts:326 `matchStreamingStringArg`.
String? _matchStreamingStringArg(String streamingArgs, String key) {
  final match = RegExp(
    '"$key"\\s*:\\s*"([^"]*)"',
    multiLine: true,
  ).firstMatch(streamingArgs)?.group(1);
  return match == null || match.isEmpty ? null : _decodeStreamingString(match);
}

/// stream-helpers.ts:331 `resolveStreamingManagedResourceTitle`.
String? _streamingManagedResourceTitle(
  String name,
  String streamingArgs,
  List<String> targetKeys,
) {
  final operation = _matchStreamingStringArg(streamingArgs, 'operation');
  if (operation == null) return null;
  String? target;
  for (final key in targetKeys) {
    target = _matchStreamingStringArg(streamingArgs, key);
    if (target != null) break;
  }
  return getToolDisplayTitle(name, {
    'operation': operation,
    if (target != null) ...{
      'title': target,
      'name': target,
      'displayName': target,
      'path': target,
    },
  });
}

final RegExp _mvMultiSource = RegExp(r'"sources"\s*:\s*\[\s*"[^"]*"\s*,');
final RegExp _mvFirstSource = RegExp(
  r'"sources"\s*:\s*\[\s*"([^"]*)"',
  multiLine: true,
);

/// A title read from a call's still-streaming argument JSON
/// (stream-helpers.ts:356 `resolveStreamingToolDisplayTitle`), or `null`
/// while nothing usable has streamed.
String? resolveStreamingToolDisplayTitle(
  String name,
  String streamingArgs, [
  ToolTitleContext? context,
]) {
  String? arg(String key) => _matchStreamingStringArg(streamingArgs, key);
  switch (name) {
    case 'run_function':
      return arg('title') ?? 'Running code';
    case 'task':
      final title = arg('title');
      return title != null ? 'Delegating: $title' : null;
    case 'prepare_file_edit':
      final title = arg('title');
      final fileName = arg('fileName');
      final verb = switch (arg('operation')) {
        'append' => 'Adding',
        'patch' => 'Editing',
        _ => 'Writing',
      };
      if (title != null) return '$verb $title';
      if (fileName != null) return '$verb $fileName';
      return null;
    case 'create_empty_file':
      final target = arg('path') ?? arg('fileName');
      return target != null
          ? getToolDisplayTitle(name, {'fileName': target})
          : null;
    case 'create_workflow':
      final workflowName = arg('name');
      return workflowName != null
          ? getToolDisplayTitle(name, {'name': workflowName})
          : null;
    case 'edit_workflow':
      final workflowId = arg('workflowId');
      return workflowId != null
          ? resolveToolDisplayTitle(name, {'workflowId': workflowId}, context)
          : null;
    case 'web_search':
      final toolTitle = arg('toolTitle');
      return toolTitle != null ? 'Searching online for $toolTitle' : null;
    case 'grep':
      final toolTitle = arg('toolTitle');
      return toolTitle != null ? 'Searching for $toolTitle' : null;
    case 'glob':
      final toolTitle = arg('toolTitle');
      return toolTitle != null ? 'Finding $toolTitle' : null;
    case 'mv':
      final toolTitle = arg('toolTitle');
      if (toolTitle == null) return null;
      final multiSource = _mvMultiSource.hasMatch(streamingArgs);
      final rawFirst = _mvFirstSource.firstMatch(streamingArgs)?.group(1);
      final firstSource = rawFirst == null || rawFirst.isEmpty
          ? null
          : _decodeStreamingString(rawFirst);
      final destination = arg('destination');
      final verb = multiSource
          ? 'Moving'
          : mvDisplayVerb(firstSource, destination);
      if (verb == 'Renaming' && firstSource != null && destination != null) {
        return getToolDisplayTitle(name, {
          'sources': [firstSource],
          'destination': destination,
        });
      }
      return '$verb $toolTitle';
    case 'cp':
      final toolTitle = arg('toolTitle');
      return toolTitle != null ? 'Duplicating $toolTitle' : null;
    case 'mkdir':
      final toolTitle = arg('toolTitle');
      return toolTitle != null ? 'Creating $toolTitle' : null;
    case 'rm':
      final toolTitle = arg('toolTitle');
      return toolTitle != null ? 'Deleting $toolTitle' : null;
    case 'web_scrape':
      final url = arg('url');
      return url != null ? 'Scraping $url' : null;
    case 'web_crawl':
      final url = arg('url');
      return url != null ? 'Crawling $url' : null;
    case 'manage_custom_tool':
      return _streamingManagedResourceTitle(name, streamingArgs, const [
        'toolTitle',
        'title',
        'name',
      ]);
    case 'manage_mcp_connection':
      return _streamingManagedResourceTitle(name, streamingArgs, const [
        'serverName',
        'name',
        'title',
      ]);
    case 'manage_skill':
      return _streamingManagedResourceTitle(name, streamingArgs, const [
        'name',
        'skillName',
        'title',
      ]);
    case 'manage_credential':
      final operation = arg('operation');
      if (operation == null) return null;
      return getToolDisplayTitle(name, {
        'operation': operation,
        'previousDisplayName':
            arg('previousDisplayName') ??
            arg('oldName') ??
            arg('credentialName'),
        'displayName': arg('displayName') ?? arg('newName') ?? arg('name'),
      });
  }
  return null;
}

/// resource-display.ts:154 `CLI_RESOURCE_DOMAINS`: (domain key, type, noun).
const List<(String, String, String)> _cliResourceDomains = [
  ('workflows', 'workflow', 'workflow'),
  ('tables', 'table', 'table'),
  ('files', 'file', 'file'),
  ('knowledge', 'knowledgebase', 'knowledge base'),
  ('skills', 'skill', 'skill'),
  ('custom_tools', 'customtool', 'custom tool'),
  ('mcp_servers', 'mcpserver', 'MCP server'),
  ('workspaces', 'workspace', 'workspace'),
];

/// A CLI row's title naming the resource it targets
/// (resource-display.ts:166 `resolveNamedCliToolDisplayTitle`), e.g.
/// "Reading workflow" → "Reading Lead Router". `null` unless [context]
/// resolves a name. The React lookup of resources addressed in the chat
/// (`context.resources`) is folded into [ToolTitleContext.resourceName].
String? resolveNamedCliToolDisplayTitle(
  String name,
  Map<String, Object?>? args,
  ToolTitleContext? context,
) {
  if (!name.startsWith('cli_') || context == null) return null;
  final target = cliFirstPositional(name, args);
  (String, String, String)? domain;
  for (final candidate in _cliResourceDomains) {
    if (name.startsWith('cli_${candidate.$1}_')) {
      domain = candidate;
      break;
    }
  }
  final folder = domain != null && name.startsWith('cli_${domain.$1}_folders_');
  final type = folder
      ? (domain.$1 == 'files' ? 'filefolder' : 'folder')
      : domain?.$2;
  final workflowIds = [
    for (final value in cliFlagValues(args, '--workflow'))
      for (final part in value.split(','))
        if (part.trim().isNotEmpty) part.trim(),
  ];
  final request = _asRecord(args?['request']);
  final explicitWorkspace =
      _stringParam(request?['workspaceId']) ??
      cliFlagValue(args, '--workspace') ??
      cliFlagValue(args, '-w');
  final workspaceId = explicitWorkspace ?? context.workspaceId;
  final workspaceName =
      workspaceId != null && workspaceId != context.workspaceId
      ? context._resource('workspace', workspaceId)
      : null;
  String inWorkspace(String title) =>
      workspaceName != null ? '$title in $workspaceName' : title;
  final base = getToolDisplayTitle(name, args);

  if (name == 'cli_blocks_get' || name == 'cli_blocks_tips') {
    final blockName = target == null
        ? null
        : _nonEmpty(context.blockTypeName?.call(target));
    return blockName != null
        ? base.replaceFirst(blockDisplayName(target!), blockName)
        : null;
  }
  if (name.startsWith('cli_logs_')) {
    final names = [
      for (final id in workflowIds) context._resource('workflow', id),
    ];
    final workflow = names.isNotEmpty && names.every((n) => n != null)
        ? names.join(', ')
        : context._resource('log', target);
    final title = workflow != null ? '$base for $workflow' : base;
    return workflow != null || workspaceName != null
        ? inWorkspace(title)
        : null;
  }
  if (domain == null) return null;
  if (name == 'cli_files_read' && target != null && target.contains('/')) {
    return inWorkspace(base);
  }
  final resolvedName = type == null ? null : context._resource(type, target);
  if (resolvedName == null) {
    return workspaceName != null ? inWorkspace(base) : null;
  }
  final noun = folder ? '${domain.$3} folder' : domain.$3;
  final pattern = RegExp('\\b${RegExp.escape(noun)}\\b');
  final title = pattern.hasMatch(base)
      ? base.replaceFirst(pattern, resolvedName)
      : '$base: $resolvedName';
  return domain.$2 == 'workspace' ? title : inWorkspace(title);
}

// ---------------------------------------------------------------------------
// Row titles (tool-call-title.ts, turn-model-serialize.ts, message-content)
// ---------------------------------------------------------------------------

/// What a tool row shows when the engine supplied no `displayTitle`.
///
/// The engine's own `displayTitle` (turn_model.dart `_toolDisplayTitle`)
/// already covers the first steps of React's precedence: the model-authored
/// `activityDescription`, the integration description, and the explicit
/// `ui.title` (`context_compaction`). This function resolves the rest, in
/// the order of `toolDisplayTitle` in
/// `home/hooks/stream/turn-model-serialize.ts:58`:
///
/// 1. the integration-gateway description
///    ([resolveIntegrationToolDisplayTitle], live mid-stream);
/// 2. a CLI title naming its resource ([resolveNamedCliToolDisplayTitle]);
/// 3. the title readable from still-streaming arguments
///    ([resolveStreamingToolDisplayTitle]), only while [streamingArgs] is set;
/// 4. the context-enriched name+args title ([resolveToolDisplayTitle]),
///    which ends in [getToolDisplayTitle]: argument-aware cases, then
///    `TOOL_TITLES`, then `CLI_TOOL_TITLES`, then [humanizeToolName].
///
/// The status tense is NOT applied here: pass the result through
/// [getToolStatusDisplayTitle] (or [toolCallTitle]), as `toToolData` in
/// `message-content.tsx:232` does. Not ported: `toToolData`'s
/// `getOverrideDisplayTitle` (the VFS-aware `read` label from
/// `tools/client/store-utils.ts`, and the `manage_credential` rename title
/// that reads the tool *result*); `read` falls back to the display.ts
/// path-based title instead.
String fallbackToolTitle(
  String toolName,
  Map<String, Object?>? params, {
  ToolTitleContext? context,
  String? streamingArgs,
  String? integrationDescription,
}) {
  final integration = resolveIntegrationToolDisplayTitle(
    name: toolName,
    args: params,
    streamingArgs: streamingArgs,
    integrationDescription: integrationDescription,
  );
  if (integration != null) return integration;
  final named = resolveNamedCliToolDisplayTitle(toolName, params, context);
  if (named != null) return named;
  if (streamingArgs != null && streamingArgs.isNotEmpty) {
    final streaming = resolveStreamingToolDisplayTitle(
      toolName,
      streamingArgs,
      context,
    );
    if (streaming != null) return streaming;
  }
  return resolveToolDisplayTitle(toolName, params, context);
}

/// tool-call-title.ts:60 `getLiveFileEditTitle`: a `prepare_file_edit`
/// title read live from its streaming arguments.
String? _liveFileEditTitle(String toolName, String? streamingArgs) {
  if (toolName != 'prepare_file_edit' ||
      streamingArgs == null ||
      streamingArgs.isEmpty) {
    return null;
  }
  final title = extractStreamingStringArgument(streamingArgs, 'title');
  if (title == null || title.isEmpty) return null;
  final operation =
      extractStreamingStringArgument(streamingArgs, 'operation') ?? '';
  return '${_fileEditVerbs[operation] ?? 'Writing'} $title';
}

/// The titles of one call, shared by its row and any header naming it: the
/// non-hook core of `useToolCallTitle`
/// (`agent-group/tool-call-title.ts:88`). A running `wait` counts down from
/// [elapsedMs] (the caller owns the ticking clock), a streaming file edit
/// names its file, and a model [activityDescription] replaces the title.
///
/// [displayTitle] is the resolved, tense-neutral title (the engine's, or
/// [fallbackToolTitle] when `null`). [status] is the wire string.
/// `label` is the row's status-aware title; `activeLabel` describes the call
/// as work in progress (an open activity header).
({String label, String activeLabel}) toolCallTitle({
  required String toolName,
  required String status,
  String? displayTitle,
  String? activityDescription,
  Map<String, Object?>? params,
  String? streamingArgs,
  int elapsedMs = 0,
  ToolTitleContext? context,
}) {
  final isCountingDown = toolName == 'wait' && status == 'executing';
  final String liveTitle;
  if (isCountingDown) {
    liveTitle = getWaitCountdownTitle(params, elapsedMs);
  } else {
    liveTitle =
        _liveFileEditTitle(toolName, streamingArgs) ??
        (displayTitle != null && displayTitle.isNotEmpty
            ? displayTitle
            : fallbackToolTitle(
                toolName,
                params,
                context: context,
                streamingArgs: streamingArgs,
              ));
  }
  final description = isCountingDown ? null : activityDescription;
  return (
    label: getToolStatusDisplayTitle(
      liveTitle,
      status,
      toolName: toolName,
      activityDescription: description,
    ),
    activeLabel: getToolInProgressTitle(
      liveTitle,
      status,
      toolName: toolName,
      activityDescription: description,
    ),
  );
}
