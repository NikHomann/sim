/// Persisted → display mapping, port of `toDisplayMessage`
/// (`lib/mothership/chat/display-message.ts`, spec chat-engine §4.1).
library;

import 'package:clock/clock.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/chat_message.dart';
import 'package:sim_app/features/chat/engine/turn_model.dart';

const _stateToStatus = <String, ToolCallStatus>{
  'success': ToolCallStatus.success,
  'error': ToolCallStatus.error,
  'cancelled': ToolCallStatus.cancelled,
  'rejected': ToolCallStatus.rejected,
  'skipped': ToolCallStatus.skipped,
  'aborted': ToolCallStatus.cancelled,
  'failed': ToolCallStatus.error,
  'interrupted': ToolCallStatus.interrupted,
  'pending': ToolCallStatus.executing,
  'executing': ToolCallStatus.executing,
  'awaiting_approval': ToolCallStatus.awaitingApproval,
};

const _unsettledStates = {'pending', 'executing', 'awaiting_approval'};

/// `HIDDEN_TOOL_NAMES` (`lib/mothership/tools/client/hidden-tools.ts`).
const hiddenToolNames = {
  'update_plan',
  'load_agent_skill',
  'load_custom_tool',
  'load_mcp_tool',
  'load_integration_tool',
  'load_skill',
  'load_slide_layout',
  'search_integration_tools',
};

/// `getMothershipAttachmentPreviewUrl`: images (with `&preview=1`) and
/// videos have a preview URL.
String? mothershipAttachmentPreviewUrl({
  required String key,
  required String mediaType,
}) {
  final isImage = mediaType.startsWith('image/');
  if (!isImage && !mediaType.startsWith('video/')) return null;
  final url = '/api/files/serve/${Uri.encodeComponent(key)}?context=mothership';
  return isImage ? '$url&preview=1' : url;
}

ToolCallInfo? _toolCall(PersistedContentBlock block, {required bool stored}) {
  final tc = block.toolCall;
  if (tc == null || hiddenToolNames.contains(tc.name)) return null;
  final status = stored && _unsettledStates.contains(tc.state)
      ? ToolCallStatus.interrupted
      : (_stateToStatus[tc.state] ?? ToolCallStatus.error);
  final result = tc.result;
  return ToolCallInfo(
    id: tc.id,
    name: tc.name,
    status: status,
    displayTitle: status == ToolCallStatus.cancelled
        ? 'Stopped by user'
        : tc.displayTitle,
    activityDescription: normalizeToolActivityDescription(
      tc.activityDescription,
    ),
    params: tc.params,
    calledBy: tc.calledBy,
    result: result == null
        ? null
        : ToolCallResult(
            success: result.success,
            output: result.output,
            error: result.error,
          ),
    unsupportedOnClient: isUnsupportedClientTool(tc.name),
  );
}

ContentBlock? _block(PersistedContentBlock block, {required bool stored}) {
  ContentBlock make(
    ContentBlockType type, {
    String? content,
    String? subagent,
    String? subagentName,
    String? error,
    ToolCallInfo? toolCall,
    TaskBlockInfo? task,
  }) => ContentBlock(
    type: type,
    content: content,
    subagent: subagent,
    subagentName: subagentName,
    error: error,
    toolCall: toolCall,
    task: task,
    parentToolCallId: block.parentToolCallId,
    spanId: block.spanId,
    parentSpanId: block.parentSpanId,
    timestamp: block.timestamp,
    endedAt: block.endedAt,
  );

  switch (block.type) {
    case 'task':
      final task = block.task;
      return task == null
          ? null
          : make(ContentBlockType.task, task: TaskBlockInfo.fromJson(task));
    case 'text':
      final thinking = block.channel == 'thinking';
      if (block.lane == 'subagent') {
        return make(
          thinking
              ? ContentBlockType.subagentThinking
              : ContentBlockType.subagentText,
          content: block.content,
          subagent: block.agent,
        );
      }
      return make(
        thinking ? ContentBlockType.thinking : ContentBlockType.text,
        content: block.content,
      );
    case 'tool':
      final toolCall = _toolCall(block, stored: stored);
      return toolCall == null
          ? null
          : make(ContentBlockType.toolCall, toolCall: toolCall);
    case 'span':
      if (block.lifecycle == 'end') {
        return make(ContentBlockType.subagentEnd, error: block.error);
      }
      return make(
        ContentBlockType.subagent,
        content: block.content,
        subagentName: block.name,
        error: block.error,
      );
    case 'complete':
      if (block.status == 'cancelled') {
        return make(ContentBlockType.stopped);
      }
      return make(ContentBlockType.text, content: block.content);
    default:
      return make(ContentBlockType.text, content: block.content);
  }
}

/// `foldFileWriteBlocks`: an `apply_file_edit` row folds into the latest
/// `prepare_file_edit` row of its span, as the live reducer does.
List<ContentBlock> _foldFileWrites(List<ContentBlock> blocks) {
  final folded = <ContentBlock>[];
  final fileIndexBySpan = <String, int>{};
  for (final block in blocks) {
    final tc = block.type == ContentBlockType.toolCall ? block.toolCall : null;
    if (tc != null) {
      final span = block.spanId ?? mainSpan;
      if (tc.name == 'apply_file_edit') {
        final index = fileIndexBySpan[span];
        final parent = index == null ? null : folded[index];
        final parentCall = parent?.toolCall;
        if (index != null && parent != null && parentCall != null) {
          folded[index] = parent.copyWith(
            toolCall: ToolCallInfo(
              id: parentCall.id,
              name: parentCall.name,
              status: tc.status,
              displayTitle: parentCall.displayTitle,
              activityDescription: parentCall.activityDescription,
              integrationDescription: parentCall.integrationDescription,
              params: parentCall.params,
              calledBy: parentCall.calledBy,
              result: tc.result,
              startedAtMs: parentCall.startedAtMs,
            ),
          );
          continue;
        }
      } else if (tc.name == 'prepare_file_edit') {
        fileIndexBySpan[span] = folded.length;
      }
    }
    folded.add(block);
  }
  return folded;
}

final Expando<ChatMessage> _displayCache = Expando('display-message');

/// `toDisplayMessage`, identity-memoised per [PersistedMessage] instance.
ChatMessage toDisplayMessage(PersistedMessage message) {
  final cached = _displayCache[message];
  if (cached != null) return cached;
  final stored =
      message.role == 'assistant' &&
      !message.id.startsWith(liveAssistantPrefix);
  final blocks = message.contentBlocks;
  final files = message.fileAttachments;
  final contexts = message.contexts;
  final display = ChatMessage(
    id: message.id,
    role: message.role == 'user' ? ChatRole.user : ChatRole.assistant,
    origin: message.origin,
    content: message.content,
    requestMode: message.requestMode,
    requestId: message.requestId,
    contentBlocks: blocks == null || blocks.isEmpty
        ? null
        : _foldFileWrites([
            for (final b in blocks) ?_block(b, stored: stored),
          ]),
    attachments: files == null || files.isEmpty
        ? null
        : [
            for (final f in files)
              ChatMessageAttachment(
                id: f.id,
                filename: f.filename,
                mediaType: f.mediaType,
                size: f.size,
                previewUrl: mothershipAttachmentPreviewUrl(
                  key: f.key,
                  mediaType: f.mediaType,
                ),
              ),
          ],
    contexts: contexts == null || contexts.isEmpty ? null : contexts,
  );
  _displayCache[message] = display;
  return display;
}

/// `toRawPersistedContentBlock` (`home/hooks/message-reconcile.ts`): a live
/// block in the persisted wire shape; `null` for blocks the wire has no
/// shape for (options, a tool block without its call).
Map<String, Object?>? _rawPersistedBlock(ContentBlock block) {
  final body = switch (block.type) {
    ContentBlockType.text => <String, Object?>{
      'type': 'text',
      if (block.subagent != null) 'lane': 'subagent',
      'channel': 'assistant',
      'content': block.content ?? '',
    },
    ContentBlockType.thinking => <String, Object?>{
      'type': 'text',
      'channel': 'thinking',
      'content': block.content ?? '',
    },
    ContentBlockType.subagentThinking => <String, Object?>{
      'type': 'text',
      'lane': 'subagent',
      'channel': 'thinking',
      'content': block.content ?? '',
      'agent': ?block.subagent,
    },
    ContentBlockType.subagentText => <String, Object?>{
      'type': 'text',
      'lane': 'subagent',
      'channel': 'assistant',
      'content': block.content ?? '',
      'agent': ?block.subagent,
    },
    ContentBlockType.toolCall => switch (block.toolCall) {
      null => null,
      final tc => <String, Object?>{
        'type': 'tool',
        'phase': 'call',
        'toolCall': {
          'id': tc.id,
          'name': tc.name,
          'state': tc.status.wire,
          'activityDescription': ?tc.activityDescription,
          'params': ?tc.params,
          if (tc.result case final r?)
            'result': {
              'success': r.success,
              'output': ?r.output,
              'error': ?r.error,
            },
          'calledBy': ?tc.calledBy,
          if (tc.displayTitle case final title?) 'display': {'title': title},
        },
      },
    },
    ContentBlockType.subagent => <String, Object?>{
      'type': 'span',
      'kind': 'subagent',
      'lifecycle': 'start',
      'content': block.content ?? '',
    },
    ContentBlockType.subagentEnd => <String, Object?>{
      'type': 'span',
      'kind': 'subagent',
      'lifecycle': 'end',
    },
    ContentBlockType.stopped => <String, Object?>{
      'type': 'complete',
      'status': 'cancelled',
    },
    ContentBlockType.task => switch (block.task) {
      null => null,
      final task => <String, Object?>{
        'type': 'task',
        'task': {
          'taskId': task.taskId,
          'kind': task.kind,
          'status': task.status,
          'target': ?task.target,
          'note': ?task.note,
          'summary': ?task.summary,
        },
      },
    },
    ContentBlockType.options => null,
  };
  if (body == null) return null;
  return {
    ...body,
    'parentToolCallId': ?block.parentToolCallId,
    'name': ?block.subagentName,
    'error': ?block.error,
    'spanId': ?block.spanId,
    'parentSpanId': ?block.parentSpanId,
    'timestamp': ?block.timestamp,
    'endedAt': ?block.endedAt,
  };
}

/// `buildAssistantSnapshotMessage`: the live assistant [message] as the
/// persisted row the stream writes into the chat's detail cache. The row
/// renders as [message] itself (the display memo is seeded), so nothing the
/// wire shape cannot carry is lost while it stands in for the server copy.
PersistedMessage assistantSnapshotMessage(ChatMessage message) {
  final blocks = [
    for (final b in message.contentBlocks ?? const <ContentBlock>[])
      ?_rawPersistedBlock(b),
  ];
  final persisted = PersistedMessage(
    id: message.id,
    role: 'assistant',
    content: message.content,
    timestamp: clock.now().toUtc().toIso8601String(),
    requestMode: message.requestMode,
    requestId: message.requestId,
    contentBlocks: blocks.isEmpty
        ? null
        : [
            for (final b in blocks)
              PersistedContentBlock(type: '${b['type']}', raw: b),
          ],
  );
  _displayCache[persisted] = message;
  return persisted;
}

bool _isPersistedAssistant(PersistedMessage message, String liveAssistantId) =>
    message.role == 'assistant' &&
    message.id != liveAssistantId &&
    !message.id.startsWith(liveAssistantPrefix);

int _streamOwnerIndex(List<PersistedMessage> messages, String streamId) =>
    messages.indexWhere((m) => m.role == 'user' && m.id == streamId);

int _assistantAfterOwner(List<PersistedMessage> messages, int ownerIndex) {
  for (var i = ownerIndex + 1; i < messages.length; i++) {
    if (messages[i].role == 'user') return -1;
    if (messages[i].role == 'assistant') return i;
  }
  return -1;
}

/// `hasTerminalPersistedAssistantForStream`: the server already holds the
/// finished answer of [streamId].
bool hasTerminalPersistedAssistantForStream(
  List<PersistedMessage> messages,
  String streamId,
  String liveAssistantId,
) {
  final owner = _streamOwnerIndex(messages, streamId);
  if (owner == -1) return false;
  final assistant = _assistantAfterOwner(messages, owner);
  return assistant != -1 &&
      _isPersistedAssistant(messages[assistant], liveAssistantId);
}

/// `reconcileLiveAssistantTurn`: places [liveAssistant] after the user
/// message that owns [streamId] (replacing the live row there), unless the
/// server copy already holds that turn's persisted answer. Returns
/// [messages] itself when nothing changes.
List<PersistedMessage> reconcileLiveAssistantTurn({
  required List<PersistedMessage> messages,
  required String streamId,
  required PersistedMessage liveAssistant,
  required String? activeStreamId,
}) {
  final owner = _streamOwnerIndex(messages, streamId);
  if (owner == -1) {
    return [
      for (final m in messages)
        if (m.id != liveAssistant.id) m,
      liveAssistant,
    ];
  }
  final assistantIndex = _assistantAfterOwner(messages, owner);
  final existing = assistantIndex >= 0 ? messages[assistantIndex] : null;
  if (activeStreamId != streamId &&
      existing != null &&
      _isPersistedAssistant(existing, liveAssistant.id)) {
    final without = [
      for (final m in messages)
        if (m.id != liveAssistant.id) m,
    ];
    return without.length == messages.length ? messages : without;
  }
  final deduped = [
    for (var i = 0; i < messages.length; i++)
      if (i == assistantIndex || messages[i].id != liveAssistant.id)
        messages[i],
  ];
  final adjustedOwner = _streamOwnerIndex(deduped, streamId);
  final adjustedAssistant = adjustedOwner >= 0
      ? _assistantAfterOwner(deduped, adjustedOwner)
      : -1;
  if (adjustedAssistant >= 0) {
    return [
      for (var i = 0; i < deduped.length; i++)
        i == adjustedAssistant ? liveAssistant : deduped[i],
    ];
  }
  if (adjustedOwner >= 0) {
    return [
      ...deduped.sublist(0, adjustedOwner + 1),
      liveAssistant,
      ...deduped.sublist(adjustedOwner + 1),
    ];
  }
  return [...deduped, liveAssistant];
}
