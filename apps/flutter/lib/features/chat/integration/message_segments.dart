/// Block → segment parser of the transcript, port of `parseBlocks`
/// (`home/components/message-content/message-content.tsx:241-626`): the
/// span-tree parser (blocks with `spanId`), the legacy parser (blocks
/// without), `groupByActivity`, plus the lane helpers of
/// `agent-group/{agent-group-content,lane-activity,tool-interactions}.ts`.
///
/// The output is an intermediate tree close to React's `MessageSegment`;
/// `message_view_mapper.dart` turns it into the renderer's views.
library;

import 'package:sim_app/features/chat/engine/engine.dart';

/// `FILE_SUBAGENT_ID` / `SUBAGENT_DISPATCH_TOOLS`.
const Map<String, String> subagentDispatchTools = {
  'file': 'prepare_file_edit',
  'task': 'task',
};

/// `SUBAGENT_KEYS`.
final Set<String> subagentKeys = subagentLabels.keys.toSet();

/// `DISPATCH_TOOL_NAMES`.
final Set<String> dispatchToolNames = {
  ...subagentKeys,
  ...subagentDispatchTools.values,
};

const String _spanRoot = 'main';
const String mainAgentName = 'mothership';

/// `resolveAgentLabel`.
String resolveAgentLabel(String key, String Function(String) humanize) {
  if (key == mainAgentName) return 'Sim';
  return subagentLabels[key] ?? humanize(key);
}

/// `isToolDone`.
bool isToolDone(ToolCallStatus status) => !status.isUnsettled;

/// One lane item (`AgentGroupItem`).
sealed class LaneItem {}

class LaneText extends LaneItem {
  LaneText(this.content);
  String content;
}

class LaneTool extends LaneItem {
  LaneTool(this.tool);
  final ToolCallInfo tool;
}

class LaneNested extends LaneItem {
  LaneNested(this.group);
  final LaneGroup group;
}

/// `AgentGroupSegment` / `NestedAgentGroup`.
class LaneGroup {
  LaneGroup({
    required this.id,
    required this.agentName,
    required this.agentLabel,
  });

  String id;
  final String agentName;
  String agentLabel;
  List<LaneItem> items = [];
  bool isDelegating = false;
  bool isOpen = false;
  String? error;

  /// `activity` of `groupByActivity` (main lane only).
  ToolActivity? activity;

  bool get isMain => agentName == mainAgentName;

  LaneGroup _cloneShallow({required String id}) =>
      LaneGroup(id: id, agentName: agentName, agentLabel: agentLabel)
        ..isDelegating = isDelegating
        ..error = error;
}

/// `MessageSegment`.
sealed class Segment {}

class TextSeg extends Segment {
  TextSeg(this.id, this.content);
  final String id;
  String content;
}

class GroupSeg extends Segment {
  GroupSeg(this.group);
  final LaneGroup group;
}

class OptionsSeg extends Segment {
  OptionsSeg(this.items);
  final List<OptionItem> items;
}

class StoppedSeg extends Segment {}

class TaskSeg extends Segment {
  TaskSeg(this.task);
  final TaskBlockInfo task;
}

bool _isToolResultRead(Map<String, Object?>? params) {
  final path = params?['path'];
  return path is String && path.startsWith('internal/tool-results/');
}

bool _hidden(String name) => hiddenToolNames.contains(name);

void _appendText(LaneGroup group, String content) {
  final last = group.items.isEmpty ? null : group.items.last;
  if (last is LaneText) {
    last.content += content;
  } else {
    group.items.add(LaneText(content));
  }
}

/// `parseBlocksWithSpanTree`.
List<Segment> parseBlocksWithSpanTree(
  List<ContentBlock> blocks,
  String Function(String) humanize,
) {
  final segments = <Segment>[];
  final groupsBySpanId = <String, LaneGroup>{};
  var textRun = 0;
  var mothershipRun = 0;
  final spanAnchor = <String, String>{};
  for (final b in blocks) {
    if (b.type == ContentBlockType.subagent &&
        b.spanId != null &&
        b.parentToolCallId != null) {
      spanAnchor[b.spanId!] = b.parentToolCallId!;
    }
  }
  String spanGroupKey(String spanId) => 'agent-${spanAnchor[spanId] ?? spanId}';

  LaneGroup? tailMothership() {
    final last = segments.isEmpty ? null : segments.last;
    return last is GroupSeg && last.group.isMain ? last.group : null;
  }

  LaneGroup ensureMothership() {
    final existing = tailMothership();
    if (existing != null) return existing;
    final group = LaneGroup(
      id: 'agent-mothership-${mothershipRun++}',
      agentName: mainAgentName,
      agentLabel: resolveAgentLabel(mainAgentName, humanize),
    );
    segments.add(GroupSeg(group));
    return group;
  }

  void absorbDispatchTool(
    String toolName,
    String? parentSpanId,
    String? dispatchToolCallId,
  ) {
    final container = parentSpanId != null && parentSpanId != _spanRoot
        ? groupsBySpanId[parentSpanId]
        : tailMothership();
    if (container == null) return;
    if (dispatchToolCallId != null) {
      final idx = container.items.indexWhere(
        (it) => it is LaneTool && it.tool.id == dispatchToolCallId,
      );
      if (idx >= 0) {
        container.items.removeAt(idx);
        return;
      }
    }
    final last = container.items.isEmpty ? null : container.items.last;
    if (last is LaneTool && last.tool.name == toolName) {
      container.items.removeLast();
    }
  }

  void attachSpanGroup(LaneGroup group, String? parentSpanId) {
    if (parentSpanId != null && parentSpanId != _spanRoot) {
      final parent = groupsBySpanId[parentSpanId];
      if (parent != null) {
        parent
          ..isDelegating = false
          ..items.add(LaneNested(group));
        return;
      }
    }
    segments.add(GroupSeg(group));
  }

  LaneGroup ensureSpanGroup(String name, String spanId, String? parentSpanId) {
    final existing = groupsBySpanId[spanId];
    if (existing != null) return existing;
    final group = LaneGroup(
      id: spanGroupKey(spanId),
      agentName: name,
      agentLabel: resolveAgentLabel(name, humanize),
    );
    groupsBySpanId[spanId] = group;
    attachSpanGroup(group, parentSpanId);
    return group;
  }

  void flushMainText(String content) {
    final last = segments.isEmpty ? null : segments.last;
    if (last is TextSeg) {
      last.content += content;
    } else {
      segments.add(TextSeg('text-${textRun++}', content));
    }
  }

  for (final block in blocks) {
    switch (block.type) {
      case ContentBlockType.thinking || ContentBlockType.subagentThinking:
        continue;
      case ContentBlockType.subagentText:
        final content = block.content;
        final spanId = block.spanId;
        if (content == null || content.isEmpty || spanId == null) continue;
        var g = groupsBySpanId[spanId];
        if (g == null && block.subagent != null) {
          g = ensureSpanGroup(block.subagent!, spanId, block.parentSpanId);
        }
        if (g == null) continue;
        g.isDelegating = false;
        _appendText(g, content);
      case ContentBlockType.text:
        final content = block.content;
        if (content == null || content.isEmpty) continue;
        if (block.subagent != null && block.spanId != null) {
          final g =
              (groupsBySpanId[block.spanId!] ??
                    ensureSpanGroup(
                      block.subagent!,
                      block.spanId!,
                      block.parentSpanId,
                    ))
                ..isDelegating = false;
          _appendText(g, content);
          continue;
        }
        flushMainText(content);
      case ContentBlockType.subagent:
        final content = block.content;
        final spanId = block.spanId;
        if (content == null || content.isEmpty || spanId == null) continue;
        final dispatch = subagentDispatchTools[content];
        if (dispatch != null) {
          absorbDispatchTool(
            dispatch,
            block.parentSpanId,
            block.parentToolCallId,
          );
        }
        final g = ensureSpanGroup(content, spanId, block.parentSpanId);
        if (block.subagentName != null) g.agentLabel = block.subagentName!;
        if (block.error != null) g.error = block.error;
        if (block.endedAt != null) {
          g
            ..isOpen = false
            ..isDelegating = false;
          continue;
        }
        g
          ..isDelegating = true
          ..isOpen = true;
      case ContentBlockType.toolCall:
        final tc = block.toolCall;
        if (tc == null || _hidden(tc.name)) continue;
        if (tc.name == 'read' && _isToolResultRead(tc.params)) continue;
        if (subagentKeys.contains(tc.name)) continue;
        if (block.spanId != null) {
          var g = groupsBySpanId[block.spanId!];
          if (g == null && tc.calledBy != null) {
            g = ensureSpanGroup(
              tc.calledBy!,
              block.spanId!,
              block.parentSpanId,
            );
          }
          if (g != null) {
            g
              ..isDelegating = false
              ..items.add(LaneTool(tc));
            continue;
          }
        }
        ensureMothership().items.add(LaneTool(tc));
      case ContentBlockType.options:
        final options = block.options;
        if (options == null || options.isEmpty) continue;
        segments.add(OptionsSeg(options));
      case ContentBlockType.task:
        final task = block.task;
        if (task == null) continue;
        segments.add(TaskSeg(task));
      case ContentBlockType.subagentEnd:
        final spanId = block.spanId;
        if (spanId == null) continue;
        final g = groupsBySpanId[spanId];
        if (g != null) {
          if (block.error != null) g.error = block.error;
          g
            ..isOpen = false
            ..isDelegating = false;
        }
      case ContentBlockType.stopped:
        segments.add(StoppedSeg());
    }
  }

  List<LaneItem> pruneEmptyNested(List<LaneItem> items) => [
    for (final item in items)
      if (item is! LaneNested)
        item
      else if ((item.group.items = pruneEmptyNested(
            item.group.items,
          )).isNotEmpty ||
          item.group.isOpen ||
          item.group.isDelegating ||
          item.group.error != null)
        item,
  ];
  for (final segment in segments) {
    if (segment is GroupSeg) {
      segment.group.items = pruneEmptyNested(segment.group.items);
    }
  }
  return [
    for (final s in segments)
      if (s is! GroupSeg ||
          s.group.items.isNotEmpty ||
          s.group.error != null ||
          s.group.isDelegating ||
          s.group.isOpen)
        s,
  ];
}

/// `parseBlocksLegacy`.
List<Segment> parseBlocksLegacy(
  List<ContentBlock> blocks,
  String Function(String) humanize,
) {
  final segments = <Segment>[];
  final groupsByKey = <String, LaneGroup>{};
  String? activeGroupKey;
  var textRun = 0;
  var mothershipRun = 0;

  String groupKey(String name, String? parentToolCallId) =>
      parentToolCallId != null ? '$name:$parentToolCallId' : '$name:legacy';

  String resolveGroupKey(String name, String? parentToolCallId) {
    if (parentToolCallId != null) return groupKey(name, parentToolCallId);
    final active = activeGroupKey;
    if (active != null && groupsByKey[active]?.agentName == name) {
      return active;
    }
    for (final entry in groupsByKey.entries) {
      if (entry.value.agentName == name && entry.value.isOpen) return entry.key;
    }
    return groupKey(name, null);
  }

  ({LaneGroup group, bool created}) ensureGroup(
    String name,
    String? parentToolCallId,
  ) {
    final key = resolveGroupKey(name, parentToolCallId);
    final existing = groupsByKey[key];
    if (existing != null) return (group: existing, created: false);
    final group = LaneGroup(
      id: parentToolCallId != null
          ? 'agent-$parentToolCallId'
          : name == mainAgentName
          ? 'agent-mothership-${mothershipRun++}'
          : 'agent-$key-${segments.length}',
      agentName: name,
      agentLabel: resolveAgentLabel(name, humanize),
    );
    segments.add(GroupSeg(group));
    groupsByKey[key] = group;
    return (group: group, created: true);
  }

  LaneGroup? findGroupForSubagentChunk(String? parentToolCallId) {
    if (parentToolCallId != null) {
      for (final entry in groupsByKey.entries) {
        if (entry.key.endsWith(':$parentToolCallId')) return entry.value;
      }
      return null;
    }
    final active = activeGroupKey;
    return active == null ? null : groupsByKey[active];
  }

  void flushLanes() {
    for (final g in groupsByKey.values) {
      g
        ..isOpen = false
        ..isDelegating = false;
    }
    groupsByKey.clear();
    activeGroupKey = null;
  }

  for (final block in blocks) {
    switch (block.type) {
      case ContentBlockType.thinking || ContentBlockType.subagentThinking:
        continue;
      case ContentBlockType.subagentText:
        final content = block.content;
        if (content == null || content.isEmpty) continue;
        final g = findGroupForSubagentChunk(block.parentToolCallId);
        if (g == null) continue;
        g.isDelegating = false;
        _appendText(g, content);
      case ContentBlockType.text:
        final content = block.content;
        if (content == null || content.isEmpty) continue;
        if (block.subagent != null) {
          final g =
              groupsByKey[resolveGroupKey(
                block.subagent!,
                block.parentToolCallId,
              )];
          if (g != null) {
            g.isDelegating = false;
            _appendText(g, content);
            continue;
          }
        }
        flushLanes();
        final last = segments.isEmpty ? null : segments.last;
        if (last is TextSeg) {
          last.content += content;
        } else {
          segments.add(TextSeg('text-${textRun++}', content));
        }
      case ContentBlockType.subagent:
        final key = block.content;
        if (key == null || key.isEmpty) continue;
        var inheritedDelegation = false;
        final dispatch = subagentDispatchTools[key];
        if (dispatch != null) {
          final main = groupsByKey[groupKey(mainAgentName, null)];
          if (main != null && main.items.isNotEmpty) {
            final last = main.items.last;
            if (last is LaneTool && last.tool.name == dispatch) {
              inheritedDelegation =
                  !isToolDone(last.tool.status) &&
                  (last.tool.streamingArgs?.isNotEmpty ?? false);
              main.items.removeLast();
            }
          }
        }
        groupsByKey.remove(groupKey(mainAgentName, null));
        final g = ensureGroup(key, block.parentToolCallId).group;
        if (block.subagentName != null) g.agentLabel = block.subagentName!;
        if (inheritedDelegation) g.isDelegating = true;
        g.isOpen = true;
        activeGroupKey = resolveGroupKey(key, block.parentToolCallId);
      case ContentBlockType.toolCall:
        final tc = block.toolCall;
        if (tc == null || _hidden(tc.name)) continue;
        if (tc.name == 'read' && _isToolResultRead(tc.params)) continue;
        final isDispatch =
            subagentKeys.contains(tc.name) && tc.calledBy == null;
        if (isDispatch) {
          groupsByKey.remove(groupKey(mainAgentName, null));
          final g = ensureGroup(tc.name, tc.id).group;
          g
            ..isDelegating = tc.status == ToolCallStatus.executing
            ..isOpen = g.isDelegating;
          continue;
        }
        if (tc.calledBy != null) {
          final ensured = ensureGroup(tc.calledBy!, block.parentToolCallId);
          final g = ensured.group..isDelegating = false;
          if (ensured.created && block.parentToolCallId != null) {
            g.isOpen = true;
          }
          g.items.add(LaneTool(tc));
          activeGroupKey = resolveGroupKey(
            tc.calledBy!,
            block.parentToolCallId,
          );
        } else {
          ensureGroup(mainAgentName, null).group.items.add(LaneTool(tc));
        }
      case ContentBlockType.options:
        final options = block.options;
        if (options == null || options.isEmpty) continue;
        flushLanes();
        segments.add(OptionsSeg(options));
      case ContentBlockType.task:
        final task = block.task;
        if (task == null) continue;
        flushLanes();
        segments.add(TaskSeg(task));
      case ContentBlockType.subagentEnd:
        final parent = block.parentToolCallId;
        if (parent != null) {
          for (final entry in groupsByKey.entries) {
            if (entry.key.endsWith(':$parent')) {
              entry.value
                ..isOpen = false
                ..isDelegating = false;
            }
          }
          if (activeGroupKey?.endsWith(':$parent') ?? false) {
            activeGroupKey = null;
          }
        } else {
          for (final entry in groupsByKey.entries) {
            if (entry.key.endsWith(':legacy') &&
                entry.value.agentName != mainAgentName) {
              entry.value
                ..isOpen = false
                ..isDelegating = false;
            }
          }
          if (activeGroupKey?.endsWith(':legacy') ?? false) {
            activeGroupKey = null;
          }
        }
      case ContentBlockType.stopped:
        flushLanes();
        segments.add(StoppedSeg());
    }
  }
  return [
    for (final s in segments)
      if (s is! GroupSeg ||
          s.group.items.isNotEmpty ||
          s.group.isDelegating ||
          s.group.isOpen)
        s,
  ];
}

/// `readToolActivity` for parsed arguments (the engine already parses the
/// streamed `arguments.activity` into the call's params once valid).
ToolActivity? readToolActivity(ToolCallInfo tool) =>
    ToolActivity.tryParse(tool.params?['activity']);

/// `isAgentGroupResolved`.
bool isLaneResolved(List<LaneItem> items) {
  var hasWork = false;
  for (final item in items) {
    switch (item) {
      case LaneTool(:final tool):
        hasWork = true;
        if (!isToolDone(tool.status)) return false;
      case LaneNested(:final group):
        hasWork = true;
        if (group.isDelegating || !isLaneResolved(group.items)) return false;
      case LaneText():
        break;
    }
  }
  return hasWork;
}

/// `groupByActivity`: activities follow transcript order; unfinished
/// parallel calls share one active group.
List<Segment> groupByActivity(
  List<Segment> segments, {
  required bool streaming,
}) {
  final labels = <String, ToolActivity>{};
  final out = <Segment>[];
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];
    if (segment is! GroupSeg || !segment.group.isMain) {
      out.add(segment);
      continue;
    }
    final source = segment.group;
    final isOpen = streaming && index == segments.length - 1;
    final groups = <LaneGroup>[];
    LaneGroup? current;
    for (final item in source.items) {
      final activity = item is LaneTool ? readToolActivity(item.tool) : null;
      if (activity != null) {
        final previous = labels[activity.id];
        labels[activity.id] = ToolActivity(
          id: activity.id,
          title: activity.title ?? previous?.title,
          completedTitle: activity.completedTitle ?? previous?.completedTitle,
        );
      }
      if (current == null ||
          (activity != null && activity.id != current.activity?.id)) {
        current = source._cloneShallow(
          id: groups.isEmpty
              ? source.id
              : '${source.id}-${item is LaneTool ? item.tool.id : groups.length}',
        )..activity = activity == null ? null : labels[activity.id];
        groups.add(current);
      } else if (activity != null) {
        current.activity = labels[activity.id];
      }
      current.items.add(item);
    }
    if (current == null) {
      out.add(segment);
      continue;
    }
    current.isOpen = isOpen;
    final firstWorking = groups.indexWhere((g) => !isLaneResolved(g.items));
    if (firstWorking >= 0 && firstWorking < groups.length - 1) {
      final working = groups[firstWorking]
        ..isOpen = isOpen
        ..items = [for (final g in groups.skip(firstWorking)) ...g.items];
      out
        ..addAll(groups.take(firstWorking).map(GroupSeg.new))
        ..add(GroupSeg(working));
    } else {
      out.addAll(groups.map(GroupSeg.new));
    }
  }
  return out;
}

/// `parseBlocks`: drops the registration receipt of a durable watch, picks
/// the parser and groups the main lane by activity.
List<Segment> parseBlocks(
  List<ContentBlock> blocks, {
  required String Function(String) humanize,
  bool streaming = false,
}) {
  final watches = {
    for (final b in blocks)
      if (b.type == ContentBlockType.task && b.task != null) b.task!.taskId,
  };
  final visible = [
    for (final block in blocks)
      if (!_isWatchReceipt(block, watches)) block,
  ];
  final parsed = blocks.any((b) => b.spanId != null)
      ? parseBlocksWithSpanTree(visible, humanize)
      : parseBlocksLegacy(visible, humanize);
  return groupByActivity(parsed, streaming: streaming);
}

bool _isWatchReceipt(ContentBlock block, Set<String> watches) {
  final tool = block.toolCall;
  if (block.type != ContentBlockType.toolCall ||
      tool?.name != 'watch' ||
      tool?.status != ToolCallStatus.success) {
    return false;
  }
  final output = tool?.result?.output;
  return output is Map &&
      output['taskId'] is String &&
      watches.contains(output['taskId']);
}

/// `deriveThinkingLabel`.
String deriveThinkingLabel(List<ContentBlock> blocks) {
  final last = blocks.isEmpty ? null : blocks.last;
  return switch (last?.type) {
    ContentBlockType.subagentEnd => 'Returning',
    ContentBlockType.toolCall =>
      last?.toolCall != null && dispatchToolNames.contains(last!.toolCall!.name)
          ? 'Dispatching'
          : 'Thinking',
    _ => 'Thinking',
  };
}

// ---------------------------------------------------------------------------
// Lane liveness (`lane-activity.ts`, `agent-group-content.ts`,
// `tool-interactions.ts`).

/// `needsToolInput`.
bool needsToolInput(ToolCallInfo tool) =>
    tool.status == ToolCallStatus.awaitingApproval ||
    (tool.status == ToolCallStatus.executing &&
        tool.name == 'terminal' &&
        tool.params?['operation'] == 'handoff');

/// `collectGroupTools`.
List<ToolCallInfo> collectLaneTools(List<LaneItem> items) {
  final tools = <ToolCallInfo>[];
  void walk(List<LaneItem> list) {
    for (final item in list) {
      switch (item) {
        case LaneTool(:final tool):
          tools.add(tool);
        case LaneNested(:final group):
          walk(group.items);
        case LaneText():
          break;
      }
    }
  }

  walk(items);
  return tools;
}

/// `hasAgentGroupItemContent`.
bool laneItemHasContent(LaneItem item) => switch (item) {
  LaneTool() => true,
  LaneText(:final content) => content.trim().isNotEmpty,
  LaneNested(:final group) =>
    group.error != null || group.items.any(laneItemHasContent),
};

/// `getNewestRunningTool`.
ToolCallInfo? newestRunningTool(List<ToolCallInfo> tools) {
  ToolCallInfo? newest;
  for (final tool in tools) {
    if (!isToolDone(tool.status) &&
        (newest == null ||
            (tool.startedAtMs ?? 0) >= (newest.startedAtMs ?? 0))) {
      newest = tool;
    }
  }
  return newest;
}

/// `hasPendingInteraction` (browser takeovers are not ported).
bool hasPendingInteraction(List<LaneItem> items) => items.any(
  (item) => switch (item) {
    LaneTool(:final tool) => needsToolInput(tool),
    LaneNested(:final group) => hasPendingInteraction(group.items),
    LaneText() => false,
  },
);

/// `isLaneWorking`.
bool isLaneWorking(LaneGroup lane, {required bool streaming}) =>
    lane.error == null &&
    ((lane.isDelegating && !isLaneResolved(lane.items)) ||
        (streaming && lane.isOpen));

/// The one live indicator of a lane: a call, or the narration header.
sealed class LaneIndicator {}

class CallIndicator extends LaneIndicator {
  CallIndicator(this.tool);
  final ToolCallInfo tool;
}

class NarrationIndicator extends LaneIndicator {}

/// `getLaneLiveIndicator`.
LaneIndicator? laneLiveIndicator({
  required bool main,
  required List<List<LaneItem>> parts,
  required bool isActive,
  required bool isOpen,
}) {
  if (!isActive || parts.any(hasPendingInteraction)) return null;
  final calls = [
    for (final part in parts)
      for (final tool in collectLaneTools(part))
        if (!needsToolInput(tool)) tool,
  ];
  final running = newestRunningTool(calls);
  if (running != null) return CallIndicator(running);
  if (!isOpen) return null;
  if (!main && calls.isEmpty) {
    return parts.any((items) => items.any(laneItemHasContent))
        ? NarrationIndicator()
        : null;
  }
  ToolCallInfo? latest;
  if (main) {
    final items = parts.isEmpty ? const <LaneItem>[] : parts.last;
    // The last run of the main lane: trailing consecutive non-interaction
    // calls.
    final last = items.isEmpty ? null : items.last;
    if (last is LaneTool && !needsToolInput(last.tool)) latest = last.tool;
  } else {
    latest = calls.isEmpty ? null : calls.last;
  }
  return latest?.status == ToolCallStatus.success
      ? CallIndicator(latest!)
      : null;
}

/// `getTurnLiveIndicators`: each top-level lane's indicator by lane id.
({bool awaitingUser, Map<String, LaneIndicator> byLane}) turnLiveIndicators(
  List<LaneGroup> lanes, {
  required bool streaming,
}) {
  final byLane = <String, LaneIndicator>{};
  final awaiting = lanes.any((lane) => hasPendingInteraction(lane.items));
  if (!streaming) return (awaitingUser: awaiting, byLane: byLane);
  final mainParts = [
    for (final lane in lanes)
      if (lane.isMain) lane,
  ];
  final mainIndicator = laneLiveIndicator(
    main: true,
    parts: [for (final lane in mainParts) lane.items],
    isActive: true,
    isOpen: mainParts.isNotEmpty && mainParts.last.isOpen,
  );
  for (final lane in lanes) {
    final working = !lane.isMain && isLaneWorking(lane, streaming: streaming);
    final indicator = lane.isMain
        ? mainIndicator
        : laneLiveIndicator(
            main: false,
            parts: [lane.items],
            isActive: working,
            isOpen: working,
          );
    if (indicator != null) byLane[lane.id] = indicator;
  }
  return (awaitingUser: awaiting, byLane: byLane);
}
