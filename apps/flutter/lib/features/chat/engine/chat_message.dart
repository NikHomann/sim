/// The display model of a chat transcript, port of `home/types.ts`
/// (`ChatMessage`, `ContentBlock`, `ToolCallInfo`, spec chat-engine §4.1).
///
/// This is the data contract the renderer (`lib/features/chat/messages`)
/// reads: it parses `contentBlocks` into segments (text, agent groups, tool
/// rows, options, stopped, task pills) and text into inline special tags
/// (see `special_tags.dart`).
library;

import 'package:equatable/equatable.dart';

/// `ToolCallStatus`.
enum ToolCallStatus {
  executing,

  /// Held for the user's Allow / Don't ask again / Skip decision.
  awaitingApproval('awaiting_approval'),
  success,
  error,
  cancelled,
  skipped,
  rejected,
  interrupted
  ;

  const ToolCallStatus([this._wire]);
  final String? _wire;

  String get wire => _wire ?? name;

  static ToolCallStatus? parse(String? raw) =>
      values.where((s) => s.wire == raw).firstOrNull;

  /// Running or waiting for a decision: not settled.
  bool get isUnsettled => this == executing || this == awaitingApproval;
}

/// `ContentBlockType`.
enum ContentBlockType {
  text,
  thinking,
  toolCall('tool_call'),
  subagent,
  subagentEnd('subagent_end'),
  subagentText('subagent_text'),
  subagentThinking('subagent_thinking'),
  options,
  stopped,
  task
  ;

  const ContentBlockType([this._wire]);
  final String? _wire;

  String get wire => _wire ?? name;
}

/// `{success, output?, error?}` of a settled tool.
class ToolCallResult extends Equatable {
  const ToolCallResult({required this.success, this.output, this.error});

  final bool success;
  final Object? output;
  final String? error;

  @override
  List<Object?> get props => [success, output, error];
}

/// `ToolCallInfo`, plus [unsupportedOnClient] (Dart only): a tool React runs
/// in the browser or the desktop bridge (`run_workflow`, browser, terminal,
/// computer, local filesystem) that this port does not execute in Phase 1.5
/// (spec ambiguity 6). The server keeps the call open until its own deadline;
/// the renderer shows the row as unsupported.
class ToolCallInfo extends Equatable {
  const ToolCallInfo({
    required this.id,
    required this.name,
    required this.status,
    this.displayTitle,
    this.activityDescription,
    this.integrationDescription,
    this.params,
    this.calledBy,
    this.result,
    this.streamingArgs,
    this.startedAtMs,
    this.unsupportedOnClient = false,
  });

  final String id;
  final String name;
  final ToolCallStatus status;
  final String? displayTitle;
  final String? activityDescription;
  final String? integrationDescription;
  final Map<String, Object?>? params;
  final String? calledBy;
  final ToolCallResult? result;
  final String? streamingArgs;
  final int? startedAtMs;
  final bool unsupportedOnClient;

  ToolCallInfo copyWith({
    ToolCallStatus? status,
    String? displayTitle,
    ToolCallResult? result,
  }) => ToolCallInfo(
    id: id,
    name: name,
    status: status ?? this.status,
    displayTitle: displayTitle ?? this.displayTitle,
    activityDescription: activityDescription,
    integrationDescription: integrationDescription,
    params: params,
    calledBy: calledBy,
    result: result ?? this.result,
    streamingArgs: streamingArgs,
    startedAtMs: startedAtMs,
    unsupportedOnClient: unsupportedOnClient,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    status,
    displayTitle,
    activityDescription,
    integrationDescription,
    params,
    calledBy,
    result,
    streamingArgs,
    startedAtMs,
    unsupportedOnClient,
  ];
}

/// `OptionItem`.
class OptionItem extends Equatable {
  const OptionItem({required this.id, required this.label});
  final String id;
  final String label;

  @override
  List<Object?> get props => [id, label];
}

/// `TaskBlockInfo` (`lib/mothership/request/types.ts`): a background task
/// the turn armed (`run task_armed`) and its delivery.
class TaskBlockInfo extends Equatable {
  const TaskBlockInfo({
    required this.taskId,
    required this.kind,
    required this.status,
    this.target,
    this.note,
    this.summary,
  });

  factory TaskBlockInfo.fromJson(Map<String, Object?> json) => TaskBlockInfo(
    taskId: '${json['taskId']}',
    kind: '${json['kind'] ?? json['taskKind'] ?? ''}',
    status: '${json['status'] ?? 'pending'}',
    target: json['target'],
    note: json['note'] is String ? json['note']! as String : null,
    summary: json['summary'] is String ? json['summary']! as String : null,
  );

  final String taskId;

  /// `timer` or `workflow_run`.
  final String kind;

  /// `pending`, `completed`, `failed`, `stopped`, `expired`.
  final String status;
  final Object? target;
  final String? note;
  final String? summary;

  TaskBlockInfo delivered({required String status, String? summary}) =>
      TaskBlockInfo(
        taskId: taskId,
        kind: kind,
        status: status,
        target: target,
        note: note,
        summary: summary,
      );

  @override
  List<Object?> get props => [taskId, kind, status, target, note, summary];
}

/// `ContentBlock`.
class ContentBlock extends Equatable {
  const ContentBlock({
    required this.type,
    this.content,
    this.task,
    this.subagent,
    this.subagentName,
    this.toolCall,
    this.options,
    this.timestamp,
    this.endedAt,
    this.error,
    this.parentToolCallId,
    this.spanId,
    this.parentSpanId,
  });

  final ContentBlockType type;
  final String? content;
  final TaskBlockInfo? task;
  final String? subagent;
  final String? subagentName;
  final ToolCallInfo? toolCall;
  final List<OptionItem>? options;
  final int? timestamp;
  final int? endedAt;
  final String? error;
  final String? parentToolCallId;
  final String? spanId;
  final String? parentSpanId;

  ContentBlock copyWith({
    ToolCallInfo? toolCall,
    int? endedAt,
    String? content,
  }) => ContentBlock(
    type: type,
    content: content ?? this.content,
    task: task,
    subagent: subagent,
    subagentName: subagentName,
    toolCall: toolCall ?? this.toolCall,
    options: options,
    timestamp: timestamp,
    endedAt: endedAt ?? this.endedAt,
    error: error,
    parentToolCallId: parentToolCallId,
    spanId: spanId,
    parentSpanId: parentSpanId,
  );

  @override
  List<Object?> get props => [
    type,
    content,
    task,
    subagent,
    subagentName,
    toolCall,
    options,
    timestamp,
    endedAt,
    error,
    parentToolCallId,
    spanId,
    parentSpanId,
  ];
}

/// `ChatMessageAttachment`.
class ChatMessageAttachment extends Equatable {
  const ChatMessageAttachment({
    required this.id,
    required this.filename,
    required this.mediaType,
    required this.size,
    this.previewUrl,
  });

  final String id;
  final String filename;
  final String mediaType;
  final int size;
  final String? previewUrl;

  @override
  List<Object?> get props => [id, filename, mediaType, size, previewUrl];
}

/// `ChatMessage`. [contexts] keep the persisted context maps (`kind`,
/// `label`, ids) as they are; the renderer reads `kind`/`label`.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.requestMode,
    this.origin,
    this.contentBlocks,
    this.attachments,
    this.contexts,
    this.requestId,
  });

  final String id;
  final ChatRole role;
  final String content;

  /// `agent`, `assistant` or `plan`.
  final String? requestMode;

  /// `task`: a background-task notification opened the turn.
  final String? origin;
  final List<ContentBlock>? contentBlocks;
  final List<ChatMessageAttachment>? attachments;
  final List<Map<String, Object?>>? contexts;
  final String? requestId;

  bool get isUser => role == ChatRole.user;

  /// Ids of live assistant turns never reach the server (fork must wait for
  /// the persisted id).
  bool get isLive => id.startsWith(liveAssistantPrefix);

  ChatMessage copyWith({
    String? content,
    List<ContentBlock>? contentBlocks,
    String? requestId,
  }) => ChatMessage(
    id: id,
    role: role,
    content: content ?? this.content,
    requestMode: requestMode,
    origin: origin,
    contentBlocks: contentBlocks ?? this.contentBlocks,
    attachments: attachments,
    contexts: contexts,
    requestId: requestId ?? this.requestId,
  );

  @override
  List<Object?> get props => [
    id,
    role,
    content,
    requestMode,
    origin,
    contentBlocks,
    attachments,
    contexts,
    requestId,
  ];
}

enum ChatRole { user, assistant }

const liveAssistantPrefix = 'live-assistant:';

/// `getLiveAssistantMessageId`.
String liveAssistantMessageId(String streamId) =>
    '$liveAssistantPrefix$streamId';

/// `SUBAGENT_LABELS`: display fallbacks of agent ids.
const subagentLabels = <String, String>{
  'workflow': 'Workflow Agent',
  'debug': 'Debug Agent',
  'deploy': 'Deploy Agent',
  'auth': 'Auth Agent',
  'research': 'Research Agent',
  'knowledge': 'Knowledge Agent',
  'table': 'Table Agent',
  'custom_tool': 'Custom Tool Agent',
  'scout': 'Scout Agent',
  'search': 'Search Agent',
  'platform': 'Platform Agent',
  'superagent': 'Superagent',
  'run': 'Run Agent',
  'agent': 'Extensions Agent',
  'extensions': 'Extensions Agent',
  'task': 'Subagent',
  'job': 'Job Agent',
  'file': 'File Agent',
  'media': 'Media Agent',
  'browser': 'Browser Agent',
};

/// Tools React executes in the browser or desktop bridge
/// (`lib/mothership/tools/client-executed-tools.ts`); not executed here.
/// (`lib/mothership/tools/{client-executed-tools,desktop-tools}.ts`,
/// `@sim/browser-protocol`, `@sim/terminal-protocol`).
const clientExecutedToolNames = {
  'run_workflow',
  'run_workflow_until_block',
  'run_block',
  'run_from_block',
  'computer',
  'terminal',
  'import_local_files',
  'read_local_file',
};

/// Whether a call frame names a tool this port does not run (spec
/// ambiguity 6): the client-executed workflow tools, the desktop tools
/// (`browser_*`, `terminal`, `computer`, local files), or any frame the
/// server marks `executor: client`. VFS reads of a granted local folder
/// (`isUserLocalVfsToolCall`) need the desktop app and never reach the web.
bool isUnsupportedClientTool(String name, {String? executor}) =>
    executor == 'client' ||
    clientExecutedToolNames.contains(name) ||
    name.startsWith('browser_');
