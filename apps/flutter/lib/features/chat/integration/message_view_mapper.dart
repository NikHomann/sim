/// Engine display messages → renderer views: the part of `MessageContent`,
/// `AgentGroupView`, `ToolActivityGroup` and `useToolCallTitle` that decides
/// what each row says (titles and tense, lane header labels, liveness) and
/// the gating of `MothershipChat` (`canFork`, feedback, thinking label).
library;

import 'dart:convert';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:clock/clock.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/integration/interaction_pairing.dart';
import 'package:sim_app/features/chat/integration/locale_time.dart';
import 'package:sim_app/features/chat/integration/message_segments.dart';
import 'package:sim_app/features/chat/integration/tool_activity.dart';
import 'package:sim_app/features/chat/integration/tool_display.dart'
    show ToolTitleContext, humanizeToolName, toolCallTitle;
import 'package:sim_app/features/chat/integration/tool_icons.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';

/// What the mapper needs besides the messages.
class ChatViewContext {
  const ChatViewContext({
    this.chatId,
    this.isSending = false,
    this.canForkChat = true,
    this.titleContext,
    this.nowMs,
    this.expiredPermissionIds = const {},
    this.locale,
  });

  final String? chatId;

  /// The turn is streaming: the last assistant message is live.
  final bool isSending;

  /// The viewer owns the chat (fork gating).
  final bool canForkChat;
  final ToolTitleContext? titleContext;

  /// Clock of the wait countdown.
  final int Function()? nowMs;

  /// Permission prompts whose decision POST answered 404.
  final Set<String> expiredPermissionIds;

  /// Locale of the timer times; defaults to the platform locale.
  final Locale? locale;
}

/// `MAX_SUMMARY_ACTIONS` (`tool-activity-group.tsx:26`).
const maxSummaryActions = 3;

/// Suffix of a client-executed tool row this app does not run.
const unsupportedToolSuffix = 'not supported in this app';

/// Maps a transcript.
List<ChatMessageView> mapChatMessages(
  List<ChatMessage> messages,
  ChatViewContext context,
) {
  final views = <ChatMessageView>[];
  final pairing = pairInteractions(messages);
  String? lastUserText;
  for (var i = 0; i < messages.length; i++) {
    final message = messages[i];
    if (message.isUser) {
      lastUserText = message.content;
      views.add(
        mapUserMessage(
          message,
          hidden: pairing.hiddenUserIndexes.contains(i),
        ),
      );
      continue;
    }
    final isLast = i == messages.length - 1;
    views.add(
      mapAssistantMessage(
        message,
        context,
        isStreaming: context.isSending && isLast,
        userQuery: lastUserText,
        questionAnswers: pairing.answersByIndex[i],
        credentialRecap: pairing.credentialRecapByIndex[i],
      ),
    );
  }
  return views;
}

ChatResourceKind _mentionKind(String? kind) => switch (kind) {
  'workflow' ||
  'current_workflow' ||
  'workflow_block' => ChatResourceKind.workflow,
  'knowledge' => ChatResourceKind.knowledge,
  'table' || 'table_selection' => ChatResourceKind.table,
  'file' || 'file_selection' => ChatResourceKind.file,
  'dashboard' => ChatResourceKind.dashboard,
  'folder' || 'filefolder' => ChatResourceKind.folder,
  'integration' => ChatResourceKind.integration,
  'skill' => ChatResourceKind.skill,
  'mcp' => ChatResourceKind.mcp,
  'slash_command' => ChatResourceKind.slashCommand,
  _ => ChatResourceKind.other,
};

ChatUserMessageView mapUserMessage(
  ChatMessage message, {
  bool hidden = false,
}) => ChatUserMessageView(
  id: message.id,
  text: message.content,
  hidden: hidden,
  isTaskNotification: message.origin == 'task',
  mentions: [
    for (final c in message.contexts ?? const <Map<String, Object?>>[])
      if (c['label'] is String)
        ChatMentionView(
          kind: _mentionKind(c['kind'] as String?),
          label: c['label']! as String,
        ),
  ],
  attachments: [
    for (final a in message.attachments ?? const <ChatMessageAttachment>[])
      ChatAttachmentView(
        id: a.id,
        filename: a.filename,
        mediaType: a.mediaType,
        previewUrl: a.previewUrl,
      ),
  ],
);

ChatAssistantMessageView mapAssistantMessage(
  ChatMessage message,
  ChatViewContext context, {
  required bool isStreaming,
  String? userQuery,
  List<String>? questionAnswers,
  List<ChatCredentialRecapItem>? credentialRecap,
}) {
  final blocks = message.contentBlocks ?? const <ContentBlock>[];
  var parsed = blocks.isEmpty
      ? <Segment>[]
      : parseBlocks(blocks, humanize: humanizeToolName, streaming: isStreaming);
  if (parsed.isEmpty && message.content.trim().isNotEmpty) {
    parsed = [TextSeg('text-fallback', message.content)];
  }
  final lanes = [
    for (final s in parsed)
      if (s is GroupSeg) s.group,
  ];
  final indicators = turnLiveIndicators(lanes, streaming: isStreaming);
  final mapper = _LaneMapper(context, streaming: isStreaming);
  final segments = <ChatSegment>[];
  for (var i = 0; i < parsed.length; i++) {
    final s = parsed[i];
    switch (s) {
      case TextSeg(:final id, :final content):
        segments.add(
          ChatTextSegment(
            id: id,
            content: content,
            streaming: isStreaming && i == parsed.length - 1,
          ),
        );
      case GroupSeg(:final group):
        final indicator = indicators.byLane[group.id];
        segments.add(
          ChatAgentGroupSegment(
            group: mapper.group(group, indicator: indicator),
          ),
        );
      case OptionsSeg(:final items):
        segments.add(
          ChatOptionsSegment(
            options: [
              for (final o in items) ChatOptionView(id: o.id, label: o.label),
            ],
          ),
        );
      case StoppedSeg():
        segments.add(const ChatStoppedSegment());
      case TaskSeg(:final task):
        segments.add(_watchSegment(task, context.locale));
    }
  }
  final chatId = context.chatId;
  return ChatAssistantMessageView(
    id: message.id,
    segments: segments,
    isStreaming: isStreaming,
    thinkingLabel: deriveThinkingLabel(blocks),
    canFeedback: chatId != null && userQuery != null,
    canFork: context.canForkChat && chatId != null && !message.isLive,
    requestId: message.requestId,
    userQuery: userQuery,
    questionAnswers: questionAnswers,
    credentialRecap: credentialRecap,
  );
}

/// `watchLabel` (`watch-activity.tsx:11-38`; workflow names are not
/// resolved).
ChatWatchSegment _watchSegment(TaskBlockInfo task, Locale? locale) {
  final status = task.status;
  final pending = status == 'pending';
  String label;
  if (task.kind == 'workflow_run') {
    const target = 'workflow run';
    label = switch (status) {
      'completed' => 'Completed $target',
      'failed' => 'Failed $target',
      'stopped' => 'Stopped watching $target',
      'expired' => 'Watch expired for $target',
      _ => 'Waiting for $target',
    };
  } else {
    final firesAt = task.target is Map
        ? (task.target! as Map)['firesAt']
        : null;
    final at = firesAt is String ? DateTime.tryParse(firesAt)?.toLocal() : null;
    final time = at == null
        ? null
        : formatLocaleTime(at, locale ?? PlatformDispatcher.instance.locale);
    if (pending) {
      label = time != null ? 'Waiting until $time' : 'Waiting for timer';
    } else {
      final base = switch (status) {
        'completed' => 'Timer finished',
        'failed' => 'Timer failed',
        'stopped' => 'Timer stopped',
        _ => 'Timer expired',
      };
      label = time != null ? '$base · $time' : base;
    }
  }
  final tooltip = [
    ?task.summary,
    ?task.note,
  ].where((s) => s.isNotEmpty).join('\n');
  return ChatWatchSegment(
    label: label,
    pending: pending,
    tooltip: tooltip.isEmpty ? null : tooltip,
  );
}

ChatToolState _state(ToolCallStatus status) => switch (status) {
  ToolCallStatus.executing => ChatToolState.executing,
  ToolCallStatus.awaitingApproval => ChatToolState.awaitingApproval,
  ToolCallStatus.success => ChatToolState.success,
  ToolCallStatus.error => ChatToolState.error,
  ToolCallStatus.cancelled => ChatToolState.cancelled,
  ToolCallStatus.skipped => ChatToolState.skipped,
  ToolCallStatus.rejected => ChatToolState.rejected,
  ToolCallStatus.interrupted => ChatToolState.interrupted,
};

bool _isFailed(ToolCallInfo tool) =>
    tool.status == ToolCallStatus.error ||
    tool.status == ToolCallStatus.rejected;

class _LaneMapper {
  _LaneMapper(this.context, {required this.streaming});

  final ChatViewContext context;
  final bool streaming;

  ({String label, String activeLabel}) titles(
    ToolCallInfo tool, {
    int? elapsedMs,
  }) {
    final started = tool.startedAtMs;
    final now = context.nowMs?.call() ?? clock.now().millisecondsSinceEpoch;
    return toolCallTitle(
      toolName: tool.name,
      status: tool.status.wire,
      displayTitle: tool.displayTitle,
      activityDescription: tool.activityDescription,
      params: tool.params,
      streamingArgs: tool.streamingArgs,
      elapsedMs:
          elapsedMs ??
          (started == null ? 0 : (now - started).clamp(0, 1 << 31)),
      context: context.titleContext,
    );
  }

  /// `isCountingDown` of `useToolCallTitle`: a running `wait`.
  static bool _countsDown(ToolCallInfo tool) =>
      tool.name == 'wait' &&
      tool.status == ToolCallStatus.executing &&
      !tool.unsupportedOnClient;

  /// The 250 ms countdown of a running `wait` (`tool-call-title.ts:91-108`).
  ChatCountdown? _countdown(
    ToolCallInfo tool, {
    String Function(String activeLabel)? header,
  }) {
    if (!_countsDown(tool)) return null;
    String active(int elapsed) =>
        titles(tool, elapsedMs: elapsed < 0 ? 0 : elapsed).activeLabel;
    return ChatCountdown(
      startedAtMs: tool.startedAtMs,
      title: (elapsed) =>
          titles(tool, elapsedMs: elapsed < 0 ? 0 : elapsed).label,
      activeTitle: header == null
          ? active
          : (elapsed) => header(active(elapsed)),
    );
  }

  ChatToolCallView tool(ToolCallInfo tool) {
    final t = titles(tool);
    var state = _state(tool.status);
    var title = t.label;
    String? activeTitle = t.activeLabel;
    if (tool.unsupportedOnClient && !isToolDone(tool.status)) {
      // The server keeps the call open until its own deadline; this client
      // never runs it (chat-engine spec ambiguity 6).
      state = ChatToolState.error;
      title = '${t.label} · $unsupportedToolSuffix';
      activeTitle = null;
    }
    final params = tool.params;
    String? args;
    if (params != null && params.isNotEmpty) {
      try {
        args = jsonEncode(params);
      } on Object {
        args = null;
      }
      if (args != null && args.length > 600) {
        args = '${args.substring(0, 600)}…';
      }
    }
    return ChatToolCallView(
      id: tool.id,
      name: tool.name,
      state: state,
      title: title,
      activeTitle: activeTitle,
      icon: toolIconFor(tool.name),
      argsSummary: args,
      permissionExpired: context.expiredPermissionIds.contains(tool.id),
      countdown: _countdown(tool),
      activityPhrase: resolveToolActivity(
        ToolActivitySubject(
          toolName: tool.name,
          params: tool.params,
          title: t.label,
        ),
      ),
    );
  }

  ChatAgentGroupView group(
    LaneGroup lane, {
    required LaneIndicator? indicator,
  }) {
    final liveCall = indicator is CallIndicator ? indicator.tool : null;
    if (lane.isMain) {
      final tools = collectLaneTools(lane.items);
      return ChatAgentGroupView(
        id: lane.id,
        agentName: lane.agentName,
        label: lane.agentLabel,
        isMain: true,
        isLive:
            lane.error == null &&
            liveCall != null &&
            tools.any((t) => t.id == liveCall.id),
        error: lane.error,
        completedTitle: lane.activity?.completedTitle,
        expandedLabel: lane.activity?.title,
        items: _items(lane, liveCall: null, indicator: null),
      );
    }
    final tools = collectLaneTools(lane.items);
    final statusTool = _activityStatusTool(tools);
    final headerTool = statusTool == null
        ? null
        : _activityHeaderTool(tools, statusTool);
    final headerTitles = headerTool == null ? null : titles(headerTool);
    final activity =
        lane.activity ??
        tools.reversed
            .map(readToolActivity)
            .where((a) => a?.title != null || a?.completedTitle != null)
            .firstOrNull;
    final isWorking = isLaneWorking(lane, streaming: streaming);
    final isLaneLive =
        lane.error == null &&
        (indicator is NarrationIndicator ||
            (liveCall != null && tools.any((t) => t.id == liveCall.id)));
    final inProgress =
        isLaneLive ||
        (isWorking && statusTool != null && !isToolDone(statusTool.status));
    ChatCountdown? labelCountdown;
    final String label;
    if (lane.error != null) {
      label = lane.agentLabel;
    } else if (inProgress) {
      label = headerTool != null && headerTitles != null
          ? _inProgressLabel(
              headerTitles.activeLabel,
              headerTool,
              tools,
              activity?.title,
            )
          : 'Thinking';
      if (headerTool != null) {
        labelCountdown = _countdown(
          headerTool,
          header: (active) =>
              _inProgressLabel(active, headerTool, tools, activity?.title),
        );
      }
    } else if (tools.isNotEmpty) {
      label = _completedLabel(tools, activity);
    } else {
      label = lane.agentLabel;
    }
    return ChatAgentGroupView(
      id: lane.id,
      agentName: lane.agentLabel,
      label: label,
      isLive: isLaneLive,
      error: lane.error,
      icon: agentIconFor(lane.agentName),
      completedTitle: activity?.completedTitle,
      expandedLabel: hasPendingInteraction(lane.items) ? null : activity?.title,
      labelCountdown: labelCountdown,
      items: _items(lane, liveCall: liveCall, indicator: indicator),
    );
  }

  List<ChatAgentItem> _items(
    LaneGroup lane, {
    required ToolCallInfo? liveCall,
    required LaneIndicator? indicator,
  }) {
    final items = <ChatAgentItem>[];
    for (var i = 0; i < lane.items.length; i++) {
      final item = lane.items[i];
      switch (item) {
        case LaneText(:final content):
          items.add(
            ChatAgentTextItem(
              content: content,
              streaming: streaming && i == lane.items.length - 1,
            ),
          );
        case LaneTool(tool: final t):
          items.add(ChatAgentToolItem(tool: tool(t)));
        case LaneNested(:final group):
          final nestedWorking = isLaneWorking(group, streaming: streaming);
          final passes =
              liveCall != null &&
              nestedWorking &&
              collectLaneTools(group.items).any((t) => t.id == liveCall.id);
          items.add(
            ChatAgentNestedItem(
              group: this.group(
                group,
                indicator: passes ? indicator : null,
              ),
            ),
          );
      }
    }
    return items;
  }

  /// `isAwaitingTitle` (`tool-activity-group.tsx:97-111`).
  bool _isAwaitingTitle(ToolCallInfo tool) {
    if (tool.status != ToolCallStatus.executing ||
        (tool.activityDescription?.isNotEmpty ?? false)) {
      return false;
    }
    final params = tool.params ?? const <String, Object?>{};
    if (tool.name == 'call_integration_tool') {
      final description = params['description'];
      return !(description is String && description.trim().isNotEmpty);
    }
    return (tool.name == 'sim_cli' ||
            tool.name == 'run_code' ||
            tool.name == 'search_workspace') &&
        params.keys.every((k) => k == 'activity');
  }

  /// `getActivityStatusTool`.
  ToolCallInfo? _activityStatusTool(List<ToolCallInfo> tools) =>
      newestRunningTool(tools) ??
      tools.where((t) => !_isFailed(t)).lastOrNull ??
      tools.lastOrNull;

  /// `getActivityHeaderTool`.
  ToolCallInfo _activityHeaderTool(
    List<ToolCallInfo> tools,
    ToolCallInfo statusTool,
  ) {
    if (!_isAwaitingTitle(statusTool)) return statusTool;
    final index = tools.indexWhere((t) => t.id == statusTool.id);
    final earlier = tools
        .take(index < 0 ? 0 : index)
        .where(
          (t) => !_isAwaitingTitle(t) && !needsToolInput(t) && !_isFailed(t),
        )
        .toList();
    return _activityStatusTool(earlier) ?? statusTool;
  }

  List<String> _interruptions(List<ToolCallInfo> tools) {
    var stopped = 0;
    var skipped = 0;
    for (final t in tools) {
      if (t.status == ToolCallStatus.cancelled ||
          t.status == ToolCallStatus.interrupted) {
        stopped++;
      } else if (t.status == ToolCallStatus.skipped) {
        skipped++;
      }
    }
    return [
      if (stopped > 0) '$stopped stopped',
      if (skipped > 0) '$skipped skipped',
    ];
  }

  /// `getInProgressActivityLabel`.
  String _inProgressLabel(
    String activeLabel,
    ToolCallInfo headerTool,
    List<ToolCallInfo> tools,
    String? activityTitle,
  ) {
    final label =
        (_isAwaitingTitle(headerTool) ? activityTitle : null) ?? activeLabel;
    return headerTool.status == ToolCallStatus.executing ||
            headerTool.status == ToolCallStatus.success
        ? [label, ..._interruptions(tools)].join(' · ')
        : label;
  }

  /// `getCompletedActivityLabel` (`tool-activity-group.tsx:193-200`) with
  /// `getToolActivitySummary` (`tool-activity-group.tsx:71-82`).
  String _completedLabel(List<ToolCallInfo> tools, ToolActivity? activity) {
    final completed = activity?.completedTitle;
    if (completed != null &&
        tools.every((t) => t.status == ToolCallStatus.success)) {
      return completed;
    }
    if (tools.length == 1) return titles(tools.single).label;
    final succeeded = tools
        .where((t) => t.status == ToolCallStatus.success)
        .toList();
    final List<String> parts;
    if (succeeded.length == 1) {
      parts = [titles(succeeded.single).label];
    } else {
      parts = toolActivitySummaryActions([
        for (final t in succeeded)
          ToolActivitySubject(
            toolName: t.name,
            params: t.params,
            title: titles(t).label,
          ),
      ], maxSummaryActions);
    }
    final summary = parts.isEmpty || parts.first.isEmpty
        ? '${tools.length} tool ${tools.length == 1 ? 'call' : 'calls'}'
        : [
            parts.first[0].toUpperCase() + parts.first.substring(1),
            ...parts.skip(1),
          ].join(', ');
    return [summary, ..._interruptions(tools)].join(' · ');
  }
}
