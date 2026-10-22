/// The deterministic model of one assistant turn, port of
/// `home/hooks/stream/turn-model.ts` (`reduceEvent`, `applyTurnTerminal`)
/// and `turn-model-serialize.ts` (`modelToContentBlocks`, `modelMainText`),
/// spec chat-engine §4.2.
///
/// Pure Dart: [reduceEvent] folds one validated envelope into a mutable
/// [TurnModel] and returns it; `seq` is the sole ordering and idempotency
/// key, so replaying events at or below [TurnModel.lastSeq] is a no-op and
/// replaying into a fresh model rebuilds the identical tree.
library;

import 'dart:convert';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/chat_message.dart';

/// The root span lane of main-agent events.
const mainSpan = 'main';

const _workspaceFileTool = 'prepare_file_edit';
const _editContentTool = 'apply_file_edit';
const _callIntegrationTool = 'call_integration_tool';
const _contextCompactionTool = 'context_compaction';

/// `CONTEXT_COMPACTION_DISPLAY_TITLE`.
const contextCompactionDisplayTitle = 'Summarizing context';

/// `NodeStatus`: `running` and `awaitingApproval` are non-terminal.
enum NodeStatus {
  running,
  awaitingApproval,
  success,
  error,
  cancelled,
  skipped,
  rejected
  ;

  bool get isTerminal => this != running && this != awaitingApproval;

  ToolCallStatus get toolStatus => switch (this) {
    running => ToolCallStatus.executing,
    awaitingApproval => ToolCallStatus.awaitingApproval,
    success => ToolCallStatus.success,
    error => ToolCallStatus.error,
    cancelled => ToolCallStatus.cancelled,
    skipped => ToolCallStatus.skipped,
    rejected => ToolCallStatus.rejected,
  };
}

/// `TurnStatus`.
enum TurnStatus { streaming, complete, error, cancelled }

sealed class LifecycleNode {
  LifecycleNode({
    required this.id,
    required this.spanId,
    required this.seq,
    this.startedAtMs,
  });

  final String id;
  final String spanId;
  final int seq;
  int? startedAtMs;
}

class ToolNode extends LifecycleNode {
  ToolNode({
    required super.id,
    required super.spanId,
    required super.seq,
    required this.name,
    super.startedAtMs,
  });

  String name;
  NodeStatus status = NodeStatus.running;
  Map<String, Object?>? args;
  String? streamingArgs;
  String? uiTitle;
  String? activityDescription;

  /// The model-authored activity labels of the call's `arguments.activity`
  /// (the first valid one wins).
  ToolActivity? activity;
  String? integrationDescription;
  bool hidden = false;
  ToolCallResult? result;

  /// The call frame named a tool this port does not execute.
  bool unsupportedOnClient = false;
}

class AgentNode extends LifecycleNode {
  AgentNode({
    required super.id,
    required super.spanId,
    required super.seq,
    required this.parentSpanId,
    required this.agentId,
    super.startedAtMs,
    this.triggerToolCallId,
    this.displayName,
  });

  String parentSpanId;
  String agentId;
  String? triggerToolCallId;
  String? displayName;
  NodeStatus status = NodeStatus.running;
  int? endSeq;
  String? error;
}

class TextNode extends LifecycleNode {
  TextNode({
    required super.id,
    required super.spanId,
    required super.seq,
    required this.channel,
    required this.text,
    super.startedAtMs,
  });

  final TextChannel channel;
  String text;
  int? endedAtMs;
}

class TaskNode extends LifecycleNode {
  TaskNode({
    required super.id,
    required super.spanId,
    required super.seq,
    required this.task,
    super.startedAtMs,
  });

  TaskBlockInfo task;
}

/// A tool result that arrived before its call.
typedef BufferedToolResult = ({
  bool success,
  Object? output,
  String? status,
  String? error,
});

/// `ToolActivity` (`lib/mothership/generated/protocol.ts`): model-authored
/// intent labels for one top-level tool activity, carried in the tool's
/// arguments.
class ToolActivity extends Equatable {
  const ToolActivity({required this.id, this.title, this.completedTitle});

  final String id;
  final String? title;
  final String? completedTitle;

  /// The zod schema's parse: `id` 1–64 chars, the titles 1–120 (all
  /// trimmed); anything else is `null`.
  static ToolActivity? tryParse(Object? value) {
    if (value is! Map) return null;
    String? field(String key, int max, {required bool required}) {
      final raw = value[key];
      if (raw == null && !required) return null;
      if (raw is! String) throw const FormatException();
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed.length > max) {
        throw const FormatException();
      }
      return trimmed;
    }

    try {
      return ToolActivity(
        id: field('id', 64, required: true)!,
        title: field('title', 120, required: false),
        completedTitle: field('completedTitle', 120, required: false),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get props => [id, title, completedTitle];
}

/// Whether a `cli_*` candidate names a known CLI command (the title catalog
/// and the service display table live with the tool display, outside the
/// engine).
typedef CliToolNameRecognizer = bool Function(String candidate);

final _streamingArgsArray = RegExp(r'"args"\s*:\s*\[([^\]]*)');
final _completeStringToken = RegExp(r'"((?:[^"\\]|\\.)*)"');

/// `refineStreamingCliToolName` (`lib/mothership/tools/display.ts`): the
/// specific `cli_*` name a streaming `sim_cli` call's argv names, once
/// enough tokens streamed; `null` when it names none [isKnown] accepts.
String? refineStreamingCliToolName(
  String streamingArgs, {
  CliToolNameRecognizer? isKnown,
}) {
  final argv = _streamingArgsArray.firstMatch(streamingArgs)?.group(1);
  if (argv == null || argv.isEmpty) return null;
  final tokens = [
    for (final m in _completeStringToken.allMatches(argv)) m.group(1) ?? '',
  ];
  if (tokens.contains('--help') || tokens.contains('-h')) return 'cli_help';
  if (isKnown == null) return null;
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
  for (var length = min(path.length, 4); length >= 1; length--) {
    final candidate = 'cli_${path.take(length).join('_').replaceAll('-', '_')}';
    if (isKnown(candidate)) return candidate;
  }
  return null;
}

/// `TurnModel`.
class TurnModel {
  TurnModel({this.isKnownCliToolName});

  /// Recognises refined CLI tool names on `args_delta`; without it only
  /// `cli_help` is refined.
  final CliToolNameRecognizer? isKnownCliToolName;

  TurnStatus status = TurnStatus.streaming;
  final Map<String, LifecycleNode> nodes = {};
  final List<String> order = [];
  final Map<String, String> agentBySpanId = {};
  final Map<String, String> openTextByKey = {};
  final Map<String, BufferedToolResult> bufferedResults = {};
  final Map<String, String> toolAlias = {};
  int lastSeq = 0;

  String resolveToolId(String id) => toolAlias[id] ?? id;

  /// Whether the model holds anything a reconnect must preserve.
  bool get isEmpty => order.isEmpty;
}

/// `resolveStreamToolOutcome` (`lib/mothership/chat/stream-tool-outcome.ts`).
NodeStatus resolveStreamToolOutcome({
  required bool success,
  Object? output,
  String? status,
}) {
  final cancelled =
      (output is Map &&
          (output['reason'] == 'user_cancelled' ||
              output['cancelledByUser'] == true)) ||
      status == 'cancelled';
  if (cancelled) return NodeStatus.cancelled;
  return switch (status) {
    'success' => NodeStatus.success,
    'error' => NodeStatus.error,
    'skipped' => NodeStatus.skipped,
    'rejected' => NodeStatus.rejected,
    'aborted' => NodeStatus.cancelled,
    'failed' => NodeStatus.error,
    _ => success ? NodeStatus.success : NodeStatus.error,
  };
}

/// `normalizeToolActivityDescription`: whitespace collapsed, ≤ 160 chars.
String? normalizeToolActivityDescription(Object? value) {
  if (value is! String) return null;
  final description = value
      .replaceAll(RegExp(r'[\s﻿]+', unicode: true), ' ')
      .trim();
  return description.isNotEmpty && description.runes.length <= 160
      ? description
      : null;
}

/// `extractStreamingStringArgument`: a completed string field out of a
/// possibly partial JSON buffer.
String? extractStreamingStringArgument(String? input, String key) {
  if (input == null || input.isEmpty) return null;
  final match = RegExp(
    '"${RegExp.escape(key)}"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"',
  ).firstMatch(input);
  final body = match?.group(1);
  if (body == null || body.isEmpty) return null;
  try {
    return jsonDecode('"$body"') as String;
  } on FormatException {
    return null;
  }
}

/// `buildMothershipErrorTag`: one encoding for live, replayed and persisted
/// assistant failures, rendered inline by the `mothership-error` tag.
String buildMothershipErrorTag(ErrorPayload payload) {
  final message = payload.text ?? 'An unexpected error occurred';
  return '<mothership-error>${jsonEncode({
    'message': message,
    if (payload.code != null && payload.code!.isNotEmpty) 'code': payload.code,
    if (payload.provider != null && payload.provider!.isNotEmpty) 'provider': payload.provider,
  })}</mothership-error>';
}

int? _tsToMs(String ts) {
  if (ts.isEmpty) return null;
  return DateTime.tryParse(ts)?.millisecondsSinceEpoch;
}

void _closeOpenText(
  TurnModel model,
  String spanId,
  TextChannel channel,
  int? atMs,
) {
  final key = '$spanId::${channel.name}';
  final nodeId = model.openTextByKey[key];
  if (nodeId == null) return;
  if (atMs != null) {
    final node = model.nodes[nodeId];
    if (node is TextNode && node.endedAtMs == null) node.endedAtMs = atMs;
  }
  model.openTextByKey.remove(key);
}

void _breakLane(TurnModel model, String spanId, int? atMs) {
  _closeOpenText(model, spanId, TextChannel.assistant, atMs);
  _closeOpenText(model, spanId, TextChannel.thinking, atMs);
}

void _appendText(
  TurnModel model,
  String spanId,
  TextChannel channel,
  String text,
  int seq,
  int? atMs,
) {
  if (text.isEmpty) return;
  final key = '$spanId::${channel.name}';
  final openId = model.openTextByKey[key];
  final open = openId == null ? null : model.nodes[openId];
  if (open is TextNode) {
    open.text += text;
    return;
  }
  _closeOpenText(
    model,
    spanId,
    channel == TextChannel.thinking
        ? TextChannel.assistant
        : TextChannel.thinking,
    atMs,
  );
  final node = TextNode(
    id: 'text:$seq',
    spanId: spanId,
    seq: seq,
    channel: channel,
    text: text,
    startedAtMs: atMs,
  );
  model.nodes[node.id] = node;
  model.order.add(node.id);
  model.openTextByKey[key] = node.id;
}

void _drainBufferedResult(TurnModel model, String fromId, ToolNode node) {
  final buffered = model.bufferedResults.remove(fromId);
  if (buffered == null) return;
  node
    ..status = resolveStreamToolOutcome(
      success: buffered.success,
      output: buffered.output,
      status: buffered.status,
    )
    ..result = ToolCallResult(
      success: buffered.success,
      output: buffered.output,
      error: buffered.error,
    )
    ..streamingArgs = null;
}

ToolNode _upsertToolNode(
  TurnModel model,
  String id,
  String spanId,
  String name,
  int seq,
  int? atMs,
) {
  final existing = model.nodes[id];
  if (existing is ToolNode) {
    final cliFamily =
        existing.name == 'sim_cli' || existing.name.startsWith('cli_');
    if (name.isNotEmpty &&
        (existing.name.isEmpty ||
            (cliFamily && name != existing.name && name != 'sim_cli'))) {
      existing.name = name;
    }
    return existing;
  }
  final node = ToolNode(
    id: id,
    spanId: spanId,
    seq: seq,
    name: name,
    startedAtMs: atMs,
  );
  model.nodes[id] = node;
  model.order.add(id);
  _breakLane(model, spanId, atMs);
  _drainBufferedResult(model, id, node);
  return node;
}

void _applyToolResult(TurnModel model, String id, ToolResultPayload payload) {
  final existing = model.nodes[id];
  if (existing is ToolNode) {
    existing
      ..status = resolveStreamToolOutcome(
        success: payload.success,
        output: payload.output,
        status: payload.status,
      )
      ..result = ToolCallResult(
        success: payload.success,
        output: payload.output,
        error: (payload.error?.isEmpty ?? true) ? null : payload.error,
      )
      ..streamingArgs = null;
    return;
  }
  model.bufferedResults[id] = (
    success: payload.success,
    output: payload.output,
    status: payload.status,
    error: (payload.error?.isEmpty ?? true) ? null : payload.error,
  );
}

void _ensureSubagentLane(
  TurnModel model,
  String spanId,
  Map<String, Object?>? scope,
  int seq,
  int? atMs,
) {
  if (spanId == mainSpan || model.agentBySpanId.containsKey(spanId)) return;
  final parentToolCallId = scope?['parentToolCallId'];
  final node = AgentNode(
    id: spanId,
    spanId: spanId,
    seq: seq,
    parentSpanId: scope?['parentSpanId'] as String? ?? mainSpan,
    agentId: scope?['agentId'] as String? ?? '',
    startedAtMs: atMs,
    triggerToolCallId: parentToolCallId is String && parentToolCallId.isNotEmpty
        ? parentToolCallId
        : null,
  );
  model.nodes[node.id] = node;
  model.order.add(node.id);
  model.agentBySpanId[spanId] = node.id;
}

ToolNode? _findWorkspaceFileNodeInSpan(TurnModel model, String spanId) {
  for (var i = model.order.length - 1; i >= 0; i--) {
    final node = model.nodes[model.order[i]];
    if (node is ToolNode &&
        node.spanId == spanId &&
        node.name == _workspaceFileTool) {
      return node;
    }
  }
  return null;
}

void _finalizeStaleWorkspaceFiles(TurnModel model, String spanId) {
  for (final id in model.order) {
    final node = model.nodes[id];
    if (node is ToolNode &&
        node.spanId == spanId &&
        node.name == _workspaceFileTool &&
        node.status == NodeStatus.running) {
      node
        ..status = NodeStatus.success
        ..streamingArgs = null;
    }
  }
}

void _rebindResolvedIntegrationCall(ToolNode node, String toolName) {
  if (node.name != _callIntegrationTool) return;
  if (toolName.isEmpty || toolName == _callIntegrationTool) return;
  final fromArgs = node.args?['description'];
  final description =
      (fromArgs is String ? fromArgs.trim() : null) ??
      extractStreamingStringArgument(
        node.streamingArgs,
        'description',
      )?.trim();
  if (description != null && description.isNotEmpty) {
    node.integrationDescription = description;
  }
  node
    ..name = toolName
    ..streamingArgs = null;
}

/// `reduceEvent`.
TurnModel reduceEvent(TurnModel model, MothershipStreamEnvelope envelope) {
  final seq = envelope.seq;
  if (seq <= model.lastSeq) return model;
  model.lastSeq = seq;
  final tsMs = _tsToMs(envelope.ts);
  final scope = envelope.scope;
  final scopeSpan = scope?['spanId'];
  final spanId = scopeSpan is String ? scopeSpan : mainSpan;
  final payload = MothershipPayload.of(envelope);

  switch (payload) {
    case TextPayload():
      _ensureSubagentLane(model, spanId, scope, seq, tsMs);
      _appendText(model, spanId, payload.channel, payload.text, seq, tsMs);
    case FilePreviewPayload():
      // Preview phases are a separate panel concern.
      break;
    case ToolCallPayload():
      final rawId = payload.toolCallId;
      if (rawId.isEmpty) break;
      final toolName = payload.toolName;
      _ensureSubagentLane(model, spanId, scope, seq, tsMs);
      if (toolName == _editContentTool) {
        final aliasedId = model.toolAlias[rawId];
        final aliased = aliasedId == null ? null : model.nodes[aliasedId];
        final parent = aliased is ToolNode
            ? aliased
            : _findWorkspaceFileNodeInSpan(model, spanId);
        if (parent != null) {
          model.toolAlias[rawId] = parent.id;
          parent
            ..status = NodeStatus.running
            ..result = null;
          _drainBufferedResult(model, rawId, parent);
          break;
        }
      }
      if (toolName == _workspaceFileTool && !model.nodes.containsKey(rawId)) {
        _finalizeStaleWorkspaceFiles(model, spanId);
      }
      final node = _upsertToolNode(
        model,
        model.resolveToolId(rawId),
        spanId,
        toolName,
        seq,
        tsMs,
      );
      _rebindResolvedIntegrationCall(node, toolName);
      node.activityDescription ??= normalizeToolActivityDescription(
        payload.activityDescription,
      );
      final callStatus = payload.status;
      if (callStatus == 'awaiting_approval' &&
          !node.status.isTerminal &&
          node.result == null) {
        node.status = NodeStatus.awaitingApproval;
      } else if (callStatus == 'executing' &&
          node.status == NodeStatus.awaitingApproval) {
        node.status = NodeStatus.running;
      }
      final arguments = payload.arguments;
      if (arguments != null) {
        node
          ..args = arguments
          ..activity ??= ToolActivity.tryParse(arguments['activity']);
      }
      final restored = payload.integrationDescription;
      if (restored != null && restored.isNotEmpty) {
        node.integrationDescription = restored;
      }
      if (payload.ui.hidden) node.hidden = true;
      if (isUnsupportedClientTool(node.name, executor: payload.executor)) {
        node.unsupportedOnClient = true;
      }
    case ToolArgsDeltaPayload():
      if (payload.toolCallId.isEmpty) break;
      _ensureSubagentLane(model, spanId, scope, seq, tsMs);
      final node = _upsertToolNode(
        model,
        model.resolveToolId(payload.toolCallId),
        spanId,
        payload.toolName,
        seq,
        tsMs,
      );
      if (payload.argumentsDelta.isNotEmpty) {
        node.streamingArgs =
            (node.streamingArgs ?? '') + payload.argumentsDelta;
        // Progressive CLI title: the placeholder upgrades to the specific
        // command once enough argv tokens streamed to name it.
        if (node.name == 'sim_cli' || node.name.startsWith('cli_')) {
          final refined = refineStreamingCliToolName(
            node.streamingArgs ?? '',
            isKnown: model.isKnownCliToolName,
          );
          if (refined != null && refined != node.name) node.name = refined;
        }
      }
    case ToolResultPayload():
      if (payload.toolCallId.isEmpty) break;
      _ensureSubagentLane(model, spanId, scope, seq, tsMs);
      _applyToolResult(model, model.resolveToolId(payload.toolCallId), payload);
    case SpanPayload():
      if (payload.kind != 'subagent') break;
      _reduceSpan(model, payload, scope, seq, tsMs);
    case RunPayload():
      _reduceRun(model, payload, scope, spanId, seq, tsMs);
    case ErrorPayload():
      final tag = buildMothershipErrorTag(payload);
      final key = '$spanId::assistant';
      final openId = model.openTextByKey[key];
      final open = openId == null ? null : model.nodes[openId];
      if (open is TextNode) {
        if (!open.text.contains(tag)) {
          final prefix = open.text.isNotEmpty && !open.text.endsWith('\n')
              ? '\n'
              : '';
          open.text += prefix + tag;
        }
      } else {
        _appendText(model, spanId, TextChannel.assistant, tag, seq, tsMs);
      }
    case CompletePayload():
      if (payload.isAsyncPause) break;
      applyTurnTerminal(model, switch (payload.status) {
        'cancelled' => TurnStatus.cancelled,
        'error' => TurnStatus.error,
        _ => TurnStatus.complete,
      });
    case SessionStartPayload() ||
        SessionChatPayload() ||
        SessionTitlePayload() ||
        SessionTracePayload() ||
        ResourceEventPayload() ||
        UnknownPayload():
      break;
  }
  return model;
}

void _reduceSpan(
  TurnModel model,
  SpanPayload payload,
  Map<String, Object?>? scope,
  int seq,
  int? tsMs,
) {
  final data = payload.data;
  String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
  final triggerToolCallId =
      str(scope?['parentToolCallId']) ??
      str(data?['tool_call_id']) ??
      str(data?['toolCallId']);
  final agentId = payload.agent ?? str(scope?['agentId']) ?? '';
  final displayName = str(data?['name']);
  final resolvedSpanId =
      str(scope?['spanId']) ??
      (triggerToolCallId != null ? 'span:$triggerToolCallId' : 'span:$seq');
  final parentSpanId = str(scope?['parentSpanId']) ?? mainSpan;

  if (payload.event == 'start') {
    _breakLane(model, parentSpanId, tsMs);
    final existingId = model.agentBySpanId[resolvedSpanId];
    final existing = existingId == null ? null : model.nodes[existingId];
    if (existing is AgentNode) {
      if (agentId.isNotEmpty && existing.agentId != agentId) {
        existing.agentId = agentId;
      }
      if (displayName != null) existing.displayName = displayName;
      if (existing.triggerToolCallId == null && triggerToolCallId != null) {
        existing.triggerToolCallId = triggerToolCallId;
      }
      if (existing.parentSpanId == mainSpan && parentSpanId != mainSpan) {
        existing.parentSpanId = parentSpanId;
      }
      if (existing.startedAtMs == null && tsMs != null) {
        existing.startedAtMs = tsMs;
      }
      return;
    }
    final node = AgentNode(
      id: resolvedSpanId,
      spanId: resolvedSpanId,
      seq: seq,
      parentSpanId: parentSpanId,
      agentId: agentId,
      startedAtMs: tsMs,
      triggerToolCallId: triggerToolCallId,
      displayName: displayName,
    );
    model.nodes[node.id] = node;
    model.order.add(node.id);
    model.agentBySpanId[resolvedSpanId] = node.id;
  } else if (payload.event == 'end') {
    if (data?['pending'] == true) return;
    _breakLane(model, resolvedSpanId, tsMs);
    final node = model.nodes[resolvedSpanId];
    final error = str(data?['error']);
    final errored = error != null;
    if (node is AgentNode && !node.status.isTerminal) {
      node
        ..status = errored ? NodeStatus.error : NodeStatus.success
        ..endSeq = seq;
      if (error != null) node.error = error;
    }
    for (final id in model.order) {
      final stale = model.nodes[id];
      if (stale is ToolNode &&
          stale.spanId == resolvedSpanId &&
          stale.status == NodeStatus.running) {
        stale
          ..status = errored ? NodeStatus.error : NodeStatus.success
          ..streamingArgs = null;
      }
    }
  }
}

void _reduceRun(
  TurnModel model,
  RunPayload payload,
  Map<String, Object?>? scope,
  String spanId,
  int seq,
  int? tsMs,
) {
  final raw = payload.raw;
  switch (payload.kind) {
    case 'task_armed' || 'task_delivered':
      final id = 'task:${raw['taskId']}';
      final node = model.nodes[id];
      final current = node is TaskNode ? node.task : null;
      final TaskBlockInfo? task;
      if (payload.kind == 'task_armed') {
        task =
            current ??
            TaskBlockInfo(
              taskId: '${raw['taskId']}',
              kind: '${raw['taskKind'] ?? ''}',
              target: raw['target'],
              note: raw['note'] is String ? raw['note']! as String : null,
              status: 'pending',
            );
      } else {
        task = current?.delivered(
          status: '${raw['status']}',
          summary: raw['summary'] is String ? raw['summary']! as String : null,
        );
      }
      if (task == null) return;
      if (node is TaskNode) {
        node.task = task;
      } else {
        model.nodes[id] = TaskNode(
          id: id,
          spanId: spanId,
          seq: seq,
          task: task,
          startedAtMs: tsMs,
        );
        model.order.add(id);
      }
    case 'compaction_start':
      _ensureSubagentLane(model, spanId, scope, seq, tsMs);
      _upsertToolNode(
        model,
        'compaction:$seq',
        spanId,
        _contextCompactionTool,
        seq,
        tsMs,
      ).uiTitle = contextCompactionDisplayTitle;
    case 'compaction_done':
      _ensureSubagentLane(model, spanId, scope, seq, tsMs);
      for (var i = model.order.length - 1; i >= 0; i--) {
        final node = model.nodes[model.order[i]];
        if (node is ToolNode &&
            node.spanId == spanId &&
            node.name == _contextCompactionTool &&
            node.status == NodeStatus.running) {
          node
            ..status = NodeStatus.success
            ..uiTitle = contextCompactionDisplayTitle;
          return;
        }
      }
      _upsertToolNode(
          model,
          'compaction:$seq',
          spanId,
          _contextCompactionTool,
          seq,
          tsMs,
        )
        ..status = NodeStatus.success
        ..uiTitle = contextCompactionDisplayTitle;
  }
}

/// `applyTurnTerminal`: sets the turn status and settles every running or
/// awaiting tool/agent node (complete → success, error → error, cancelled →
/// cancelled), closing straggler agent lanes at [TurnModel.lastSeq].
void applyTurnTerminal(TurnModel model, TurnStatus turn) {
  assert(turn != TurnStatus.streaming, 'terminal status required');
  model.status = turn;
  final nodeStatus = switch (turn) {
    TurnStatus.cancelled => NodeStatus.cancelled,
    TurnStatus.error => NodeStatus.error,
    _ => NodeStatus.success,
  };
  for (final id in model.order) {
    final node = model.nodes[id];
    if (node is ToolNode && !node.status.isTerminal) {
      node.status = nodeStatus;
    } else if (node is AgentNode && !node.status.isTerminal) {
      node
        ..status = nodeStatus
        ..endSeq ??= model.lastSeq;
    }
  }
}

/// The title a tool row shows, as far as the engine can resolve it: the
/// model-authored activity description, then the integration description,
/// then the explicit UI title (`context_compaction`). Name- and argument-
/// derived titles (`resolveToolDisplayTitle`, the tool catalog) are the
/// renderer's job.
String? _toolDisplayTitle(ToolNode node) =>
    node.activityDescription ?? node.integrationDescription ?? node.uiTitle;

/// `modelToContentBlocks`.
List<ContentBlock> modelToContentBlocks(TurnModel model) {
  final entries = <(int, int, ContentBlock)>[];
  var arrival = 0;
  void push(int seq, ContentBlock block) =>
      entries.add((seq, arrival++, block));

  for (final id in model.order) {
    final node = model.nodes[id];
    if (node == null) continue;
    final isSub = node.spanId != mainSpan;
    final owner = isSub ? model.nodes[node.spanId] : null;
    final ownerAgent = owner is AgentNode ? owner : null;
    final spanId = isSub ? node.spanId : null;
    final parentSpanId = isSub ? ownerAgent?.parentSpanId : null;

    switch (node) {
      case TextNode():
        if (node.text.isEmpty) continue;
        final timestamp = node.startedAtMs ?? node.seq;
        final thinking = node.channel == TextChannel.thinking;
        push(
          node.seq,
          ContentBlock(
            type: thinking
                ? (isSub
                      ? ContentBlockType.subagentThinking
                      : ContentBlockType.thinking)
                : ContentBlockType.text,
            content: node.text,
            subagent: isSub ? ownerAgent?.agentId : null,
            spanId: spanId,
            parentSpanId: parentSpanId,
            timestamp: timestamp,
            endedAt: node.endedAtMs,
          ),
        );
      case ToolNode():
        if (node.hidden) continue;
        final result = node.result;
        push(
          node.seq,
          ContentBlock(
            type: ContentBlockType.toolCall,
            toolCall: ToolCallInfo(
              id: node.id,
              name: node.name,
              status: node.status.toolStatus,
              displayTitle: _toolDisplayTitle(node),
              activityDescription: node.activityDescription,
              integrationDescription: node.integrationDescription,
              params: node.args,
              streamingArgs: node.streamingArgs,
              result: result,
              calledBy: isSub ? ownerAgent?.agentId : null,
              startedAtMs: node.startedAtMs,
              unsupportedOnClient: node.unsupportedOnClient,
            ),
            spanId: spanId,
            parentSpanId: parentSpanId,
            timestamp: node.startedAtMs ?? node.seq,
          ),
        );
      case TaskNode():
        push(
          node.seq,
          ContentBlock(
            type: ContentBlockType.task,
            task: node.task,
            spanId: spanId,
            parentSpanId: parentSpanId,
            timestamp: node.startedAtMs ?? node.seq,
            endedAt: node.task.status != 'pending'
                ? node.startedAtMs ?? node.seq
                : null,
          ),
        );
      case AgentNode():
        push(
          node.seq,
          ContentBlock(
            type: ContentBlockType.subagent,
            content: node.agentId,
            subagentName: node.displayName,
            spanId: node.spanId,
            parentSpanId: node.parentSpanId,
            parentToolCallId: node.triggerToolCallId,
            timestamp: node.startedAtMs ?? node.seq,
          ),
        );
        final endSeq = node.endSeq;
        if (endSeq != null) {
          push(
            endSeq,
            ContentBlock(
              type: ContentBlockType.subagentEnd,
              error: node.error,
              spanId: node.spanId,
              parentSpanId: node.parentSpanId,
              parentToolCallId: node.triggerToolCallId,
              timestamp: endSeq,
            ),
          );
        }
    }
  }
  // Stable by seq, as JS Array.prototype.sort is.
  entries.sort((a, b) {
    final bySeq = a.$1.compareTo(b.$1);
    return bySeq != 0 ? bySeq : a.$2.compareTo(b.$2);
  });
  return [for (final e in entries) e.$3];
}

/// `modelMainText`: the main lane's assistant text, in order.
String modelMainText(TurnModel model) {
  final buffer = StringBuffer();
  for (final id in model.order) {
    final node = model.nodes[id];
    if (node is TextNode &&
        node.spanId == mainSpan &&
        node.channel == TextChannel.assistant) {
      buffer.write(node.text);
    }
  }
  return buffer.toString();
}

/// `finalizeResidualToolCalls` on serialized blocks: settles unfinished tool
/// rows (and stamps open subagent lanes) at a turn terminal. Returns the new
/// blocks, or `null` when nothing was unsettled.
List<ContentBlock>? finalizeResidualToolCalls(
  List<ContentBlock> blocks,
  TurnStatus terminal, {
  required int nowMs,
}) {
  final propagated = switch (terminal) {
    TurnStatus.cancelled => ToolCallStatus.cancelled,
    TurnStatus.error => ToolCallStatus.error,
    _ => ToolCallStatus.success,
  };
  var settled = false;
  final next = <ContentBlock>[];
  for (final block in blocks) {
    if (block.type == ContentBlockType.subagent && block.endedAt == null) {
      settled = true;
      next.add(block.copyWith(endedAt: nowMs));
      continue;
    }
    final tc = block.toolCall;
    if (tc == null || !tc.status.isUnsettled) {
      next.add(block);
      continue;
    }
    settled = true;
    next.add(
      block.copyWith(
        endedAt: block.endedAt ?? nowMs,
        toolCall: tc.copyWith(
          status: propagated,
          displayTitle: propagated == ToolCallStatus.cancelled
              ? 'Stopped by user'
              : null,
        ),
      ),
    );
  }
  return settled ? next : null;
}

/// The local Stop effect on a live assistant (`markMessageStopped` +
/// the pending-messages branch of `stopGeneration`): stamp `endedAt` on open
/// blocks, cancel unsettled tools ('Stopped by user'), append `stopped`.
List<ContentBlock> markBlocksStopped(
  List<ContentBlock> blocks, {
  required int nowMs,
}) {
  final hasUnsettled = blocks.any(
    (b) => b.toolCall?.status.isUnsettled ?? false,
  );
  final hasOpen = blocks.any((b) => b.endedAt == null);
  if (!hasUnsettled && !hasOpen) return blocks;
  final stamped = [
    for (final b in blocks) b.endedAt == null ? b.copyWith(endedAt: nowMs) : b,
  ];
  final settled =
      finalizeResidualToolCalls(stamped, TurnStatus.cancelled, nowMs: nowMs) ??
      stamped;
  return [...settled, const ContentBlock(type: ContentBlockType.stopped)];
}
