import 'package:flutter/foundation.dart';

/// The 23 chat context kinds (`ChatContext` in `stores/panel/types.ts`,
/// registry `home/components/chat-context-kind-registry`).
enum ChatContextKind {
  browserTab('browser_tab'),
  terminalTab('terminal_tab'),
  workflow('workflow'),
  currentWorkflow('current_workflow'),
  workflowBlock('workflow_block'),
  blocks('blocks'),
  knowledge('knowledge'),
  table('table'),
  tableSelection('table_selection'),
  dashboard('dashboard'),
  file('file'),
  fileSelection('file_selection'),
  folder('folder'),
  filefolder('filefolder'),
  project('project'),
  workspace('workspace'),
  pastChat('past_chat'),
  logs('logs'),
  docs('docs'),
  slashCommand('slash_command'),
  integration('integration'),
  skill('skill'),
  mcp('mcp')
  ;

  const ChatContextKind(this.wire);

  /// The `kind` string on the wire.
  final String wire;

  static ChatContextKind? fromWire(String? wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }

  /// `WORKSPACE_OWNED_CONTEXT_KINDS` (`lib/mothership/chat/context-ownership.ts`).
  bool get isWorkspaceOwned => switch (this) {
    pastChat ||
    workflow ||
    workflowBlock ||
    logs ||
    knowledge ||
    table ||
    tableSelection ||
    file ||
    fileSelection ||
    dashboard ||
    folder ||
    filefolder ||
    skill => true,
    _ => false,
  };

  /// The registry label (tooltips, accessible names).
  String get label => switch (this) {
    browserTab => 'Browser tab',
    terminalTab => 'Terminal',
    workflow => 'Workflow',
    currentWorkflow => 'Current workflow',
    workflowBlock => 'Block',
    blocks => 'Blocks',
    knowledge => 'Knowledge base',
    table => 'Table',
    tableSelection => 'Table selection',
    dashboard => 'Dashboard',
    file => 'File',
    fileSelection => 'File selection',
    folder => 'Folder',
    filefolder => 'File folder',
    project => 'Project',
    workspace => 'Workspace',
    pastChat => 'Past chat',
    logs => 'Logs',
    docs => 'Docs',
    slashCommand => 'Command',
    integration => 'Integration',
    skill => 'Skill',
    mcp => 'MCP server',
  };
}

/// One chat context (a chip's structured payload). [fields] carries the
/// kind-specific ids exactly as they travel on the wire (`workflowId`,
/// `tableId`, `rowIds`, `workspaceId`, ...); [toJson] produces the
/// `ChatContext` object the chat engine sends.
@immutable
class ChatContext {
  const ChatContext({
    required this.kind,
    required this.label,
    this.fields = const <String, Object?>{},
  });

  factory ChatContext.workflow(String id, String label) => ChatContext(
    kind: ChatContextKind.workflow,
    label: label,
    fields: {'workflowId': id},
  );

  factory ChatContext.skill(String id, String label, {String? workspaceId}) =>
      ChatContext(
        kind: ChatContextKind.skill,
        label: label,
        fields: {'skillId': id, 'workspaceId': ?workspaceId},
      );

  factory ChatContext.mcp(
    String serverId,
    String label, {
    String? managedConnectorId,
  }) => ChatContext(
    kind: ChatContextKind.mcp,
    label: label,
    fields: {
      'serverId': serverId,
      'managedConnectorId': ?managedConnectorId,
    },
  );

  factory ChatContext.integration(String blockType, String label) =>
      ChatContext(
        kind: ChatContextKind.integration,
        label: label,
        fields: {'blockType': blockType},
      );

  /// Parses a wire context; `null` for an unknown kind or a missing label.
  static ChatContext? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = ChatContextKind.fromWire(json['kind'] as String?);
    final label = json['label'];
    if (kind == null || label is! String) return null;
    return ChatContext(
      kind: kind,
      label: label,
      fields: <String, Object?>{
        for (final entry in json.entries)
          if (entry.key != 'kind' && entry.key != 'label')
            '${entry.key}': entry.value,
      },
    );
  }

  final ChatContextKind kind;
  final String label;
  final Map<String, Object?> fields;

  /// A string field, `null` when absent or not a string.
  String? field(String name) {
    final value = fields[name];
    return value is String ? value : null;
  }

  String? get workspaceId => field('workspaceId');

  ChatContext copyWith({String? label, Map<String, Object?>? fields}) =>
      ChatContext(
        kind: kind,
        label: label ?? this.label,
        fields: fields ?? this.fields,
      );

  ChatContext withWorkspace(String workspaceId) =>
      copyWith(fields: {...fields, 'workspaceId': workspaceId});

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.wire,
    'label': label,
    ...fields,
  };

  @override
  bool operator ==(Object other) =>
      other is ChatContext &&
      other.kind == kind &&
      other.label == label &&
      mapEquals(other.fields, fields);

  @override
  int get hashCode => Object.hash(
    kind,
    label,
    Object.hashAllUnordered(
      fields.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => 'ChatContext(${kind.wire}, $label, $fields)';
}

bool _sameIds(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is! List || b is! List || a.length != b.length) return false;
  final inA = a.toSet();
  return b.every(inA.contains);
}

/// `areContextsEqual` (`copilot/.../user-input/utils.ts`): identity of two
/// contexts of the same kind by their id fields, owner included.
bool areContextsEqual(ChatContext c, ChatContext other) {
  if (c.workspaceId != other.workspaceId) return false;
  if (c.kind != other.kind) return false;
  bool same(String field) => c.field(field) == other.field(field);
  return switch (c.kind) {
    ChatContextKind.pastChat => same('chatId'),
    ChatContextKind.workflow ||
    ChatContextKind.currentWorkflow => same('workflowId'),
    ChatContextKind.blocks => () {
      final mine = (c.fields['blockIds'] as List?) ?? const <Object?>[];
      final theirs = (other.fields['blockIds'] as List?) ?? const <Object?>[];
      return mine.any(theirs.contains);
    }(),
    ChatContextKind.workflowBlock => same('workflowId') && same('blockId'),
    ChatContextKind.knowledge => same('knowledgeId'),
    ChatContextKind.table => same('tableId'),
    ChatContextKind.file => same('fileId'),
    ChatContextKind.folder => same('folderId'),
    ChatContextKind.filefolder => same('fileFolderId'),
    ChatContextKind.workspace => true,
    ChatContextKind.fileSelection =>
      same('fileId') &&
          same('text') &&
          c.fields['startLine'] == other.fields['startLine'] &&
          c.fields['endLine'] == other.fields['endLine'],
    ChatContextKind.tableSelection =>
      same('tableId') &&
          _sameIds(c.fields['rowIds'], other.fields['rowIds']) &&
          _sameIds(c.fields['columnIds'], other.fields['columnIds']),
    ChatContextKind.logs => same('executionId'),
    ChatContextKind.integration => same('blockType'),
    ChatContextKind.docs => true,
    ChatContextKind.slashCommand => same('command'),
    ChatContextKind.skill => same('skillId'),
    ChatContextKind.mcp => same('serverId'),
    // No `dashboard` arm upstream: it falls to `default: false`.
    ChatContextKind.dashboard ||
    ChatContextKind.browserTab ||
    ChatContextKind.terminalTab ||
    ChatContextKind.project => false,
  };
}
