import 'package:flutter/foundation.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';

/// `SKILL_CHIP_TRIGGER`: the EM SPACE stored in place of a skill/MCP chip's
/// `/` so the centred icon fits its slot like `@` does. Restored to `/` on
/// submit and copy.
const String skillChipTrigger = ' ';

/// `restoreSkillTriggerText`.
String restoreSkillTriggerText(String text) =>
    text.replaceAll(skillChipTrigger, '/');

/// The stored trigger glyph of a kind (`cp/utils.ts:29-41`).
String contextTrigger(ChatContextKind kind) => switch (kind) {
  ChatContextKind.skill || ChatContextKind.mcp => skillChipTrigger,
  ChatContextKind.slashCommand => '/',
  _ => '@',
};

/// The inline token of [context], `null` for `current_workflow` and empty
/// labels (`extractContextTokens`).
String? contextToken(ChatContext context) {
  if (context.kind == ChatContextKind.currentWorkflow) return null;
  if (context.label.isEmpty) return null;
  return '${contextTrigger(context.kind)}${context.label}';
}

/// `extractContextTokens`.
List<String> extractContextTokens(Iterable<ChatContext> contexts) => [
  for (final context in contexts) ?contextToken(context),
];

/// `stripMentionTrigger`.
String stripMentionTrigger(String token) {
  if (token.isEmpty) return token;
  final first = token[0];
  return first == '@' || first == '/' || first == skillChipTrigger
      ? token.substring(1)
      : token;
}

/// A highlighted token occurrence `[start, end)` (no glue spaces).
@immutable
class TokenRange {
  const TokenRange(this.start, this.end, this.token);

  final int start;
  final int end;
  final String token;

  @override
  String toString() => 'TokenRange($start, $end, $token)';
}

/// `computeMentionHighlightRanges`: every occurrence of any token, longest
/// alternative first so a label that prefixes another never splits it.
List<TokenRange> computeMentionHighlightRanges(
  String text,
  List<String> tokens,
) {
  if (tokens.isEmpty || text.isEmpty) return const [];
  final unique = tokens.toSet().toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final pattern = RegExp(unique.map(RegExp.escape).join('|'));
  return [
    for (final match in pattern.allMatches(text))
      if (match.end > match.start)
        TokenRange(match.start, match.end, match.group(0)!),
  ];
}

/// `filterContextsPresentInMessage`: the contexts whose exact token still
/// occurs in [message]; the same list instance when none was dropped.
List<ChatContext> filterContextsPresentInMessage(
  List<ChatContext> contexts,
  String message,
) {
  if (contexts.isEmpty) return contexts;
  if (message.isEmpty) return const [];
  final tokens = [for (final c in contexts) contextToken(c) ?? ''];
  final present = computeMentionHighlightRanges(
    message,
    tokens.where((t) => t.isNotEmpty).toList(),
  ).map((r) => r.token).toSet();
  final filtered = [
    for (var i = 0; i < contexts.length; i++)
      if (present.contains(tokens[i])) contexts[i],
  ];
  return filtered.length == contexts.length ? contexts : filtered;
}

/// `filterOutContext`.
List<ChatContext> filterOutContext(
  List<ChatContext> contexts,
  ChatContext remove,
) => [
  for (final c in contexts)
    if (c.kind != remove.kind || !areContextsEqual(c, remove)) c,
];

/// `isContextAlreadySelected`: label collision first, then id equality.
bool isContextAlreadySelected(
  ChatContext context,
  List<ChatContext> selected,
) => selected.any((c) {
  if (c.label.isNotEmpty &&
      context.label.isNotEmpty &&
      c.label == context.label) {
    return true;
  }
  if (c.kind != context.kind) return false;
  return areContextsEqual(c, context);
});

/// `uniqueContextLabel`: `label`, else the first free `label (n)`, n >= 2.
String uniqueContextLabel(String label, List<ChatContext> selected) {
  final taken = {for (final c in selected) c.label};
  if (!taken.contains(label)) return label;
  for (var n = 2; ; n++) {
    final candidate = '$label ($n)';
    if (!taken.contains(candidate)) return candidate;
  }
}

/// `prepareContextForInsert`: `null` when the exact context is attached,
/// else the context with a collision-free label.
ChatContext? prepareContextForInsert(
  ChatContext context,
  List<ChatContext> selected,
) {
  final duplicate = selected.any(
    (c) => c.kind == context.kind && areContextsEqual(c, context),
  );
  if (duplicate) return null;
  return context.copyWith(label: uniqueContextLabel(context.label, selected));
}

/// A chip's atomic span `[start, end)` including its glue spaces
/// (`useMentionTokens.mentionRanges`).
@immutable
class ChipRange {
  const ChipRange(this.start, this.end, this.label);

  final int start;
  final int end;
  final String label;

  ({int start, int end}) get bounds => (start: start, end: end);

  @override
  bool operator ==(Object other) =>
      other is ChipRange &&
      other.start == start &&
      other.end == end &&
      other.label == label;

  @override
  int get hashCode => Object.hash(start, end, label);

  @override
  String toString() => 'ChipRange($start, $end, $label)';
}

/// `mentionRanges`: `@label ` at the start, every ` @label `, and a
/// trailing `@label` at the end (with its leading space), sorted by start.
List<ChipRange> computeChipRanges(String message, List<ChatContext> contexts) {
  final ranges = <ChipRange>[];
  if (message.isEmpty || contexts.isEmpty) return ranges;
  final labels = <String>{
    for (final c in contexts)
      if (c.label.isNotEmpty) c.label,
  };
  for (final label in labels) {
    final matching = contexts.firstWhere((c) => c.label == label);
    final prefix = contextTrigger(matching.kind);
    final atStart = '$prefix$label ';
    if (message.startsWith(atStart)) {
      ranges.add(ChipRange(0, atStart.length, label));
    }
    final token = ' $prefix$label ';
    var from = 0;
    while (from <= message.length) {
      final idx = message.indexOf(token, from);
      if (idx == -1) break;
      ranges.add(ChipRange(idx, idx + token.length, label));
      from = idx + token.length;
    }
    final atEnd = '$prefix$label';
    if (message.endsWith(atEnd)) {
      final idx = message.lastIndexOf(atEnd);
      final hasLeadingSpace = idx > 0 && message[idx - 1] == ' ';
      ranges.add(
        ChipRange(hasLeadingSpace ? idx - 1 : idx, message.length, label),
      );
    }
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  return ranges;
}

/// The chip strictly containing [pos] (`findRangeContaining`).
ChipRange? findRangeContaining(List<ChipRange> ranges, int pos) {
  for (final r in ranges) {
    if (pos > r.start && pos < r.end) return r;
  }
  return null;
}

/// `deleteRange`: removes the chip span; when the removal leaves a space on
/// both sides the following run of spaces goes too (one edit).
({String text, int caret}) deleteChipRange(String text, ChipRange range) {
  final before = text.substring(0, range.start);
  final after = text.substring(range.end);
  var deleteEnd = range.end;
  if (before.endsWith(' ') && after.startsWith(' ')) {
    deleteEnd += after.length - after.replaceFirst(RegExp('^ +'), '').length;
  }
  return (
    text: text.substring(0, range.start) + text.substring(deleteEnd),
    caret: range.start,
  );
}

/// An open `@`/`/` query: the trigger at [start], the caret at [end].
@immutable
class TriggerQuery {
  const TriggerQuery(this.query, this.start, this.end);

  final String query;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is TriggerQuery &&
      other.query == query &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(query, start, end);

  @override
  String toString() => 'TriggerQuery("$query", $start, $end)';
}

final RegExp _whitespace = RegExp(r'\s');

bool _isCompletedToken(
  String text,
  int triggerIndex,
  int pos,
  String trigger,
  Iterable<String> labels,
) {
  for (final label in labels) {
    if (triggerIndex == 0 && text.startsWith('$trigger$label ')) return true;
    final token = ' $trigger$label ';
    var from = 0;
    while (from <= text.length) {
      final idx = text.indexOf(token, from);
      if (idx == -1) break;
      if (triggerIndex == idx + 1) return true;
      if (pos > idx && pos < idx + token.length) return true;
      from = idx + token.length;
    }
  }
  return false;
}

TriggerQuery? _activeQuery(
  String text,
  int pos,
  String trigger,
  Iterable<String> labels,
) {
  final clamped = pos.clamp(0, text.length);
  final before = text.substring(0, clamped);
  final index = before.lastIndexOf(trigger);
  if (index == -1) return null;
  if (index > 0 && !_whitespace.hasMatch(before[index - 1])) return null;
  if (_isCompletedToken(text, index, clamped, trigger, labels)) return null;
  final segment = before.substring(index + 1);
  if (segment.isNotEmpty && _whitespace.hasMatch(segment[0])) return null;
  return TriggerQuery(segment, index, clamped);
}

/// `getActiveMentionQueryAtPosition`.
TriggerQuery? activeMentionQuery(
  String text,
  int pos,
  List<ChatContext> contexts,
) => _activeQuery(text, pos, '@', [
  for (final c in contexts)
    if (c.kind != ChatContextKind.slashCommand && c.label.isNotEmpty) c.label,
]);

/// `getActiveSlashQueryAtPosition`.
TriggerQuery? activeSlashQuery(
  String text,
  int pos,
  List<ChatContext> contexts,
) => _activeQuery(text, pos, '/', [
  for (final c in contexts)
    if (c.kind == ChatContextKind.slashCommand && c.label.isNotEmpty) c.label,
]);

/// A selection in text offsets.
typedef SelRange = ({int start, int end});

/// `snapSelectionToChips` (`home/components/user-input/chip-selection.ts`).
SelRange snapSelectionToChips(
  SelRange sel,
  SelRange prev,
  SelRange? startChip,
  SelRange? endChip,
) {
  final start = sel.start;
  final end = sel.end;
  if (start == end) {
    if (startChip == null) return sel;
    final nearest = start - startChip.start < startChip.end - start
        ? startChip.start
        : startChip.end;
    return (start: nearest, end: nearest);
  }
  final singleEdgeMoved = (start != prev.start) != (end != prev.end);
  var newStart = startChip == null
      ? start
      : (singleEdgeMoved && start > prev.start
            ? startChip.end
            : startChip.start);
  final newEnd = endChip == null
      ? end
      : (singleEdgeMoved && end < prev.end ? endChip.start : endChip.end);
  if (newStart > newEnd) newStart = newEnd;
  return (start: newStart, end: newEnd);
}
