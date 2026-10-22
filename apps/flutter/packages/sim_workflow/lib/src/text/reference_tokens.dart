/// The reference-token tokenizer behind the highlighted text inputs:
/// a port of `formatDisplayText` in
/// `packages/workflow-renderer/src/formatted-text.tsx` (used by
/// `short-input`, `long-input` and `code` under
/// `apps/sim/app/workspace/.../components/panel/components/editor/
/// components/sub-block/components/`) producing spans
/// instead of React nodes, plus the token finder from
/// `packages/utils/src/workflow-references.ts`.
library;

import 'package:meta/meta.dart';
import 'package:sim_workflow/src/rules/block_names.dart';

/// Port of `WorkflowTextRange`.
@immutable
class WorkflowTextRange {
  const WorkflowTextRange({required this.start, required this.end});

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is WorkflowTextRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Port of `WorkflowSearchTextHighlight`: the active search/replace match.
@immutable
class WorkflowSearchTextHighlight {
  const WorkflowSearchTextHighlight({this.range, this.rawValue});

  final WorkflowTextRange? range;
  final String? rawValue;
}

/// Port of `HighlightContext`.
///
/// `accessiblePrefixes` null means "unknown" and callers pass
/// `highlightAll: true` in that case (`short-input.tsx`); `availableEnvVars`
/// null means every env token is highlighted.
@immutable
class HighlightContext {
  const HighlightContext({
    this.accessiblePrefixes,
    this.availableEnvVars,
    this.highlightAll = false,
    this.workflowSearchHighlight,
  });

  final Set<String>? accessiblePrefixes;
  final Set<String>? availableEnvVars;
  final bool highlightAll;
  final WorkflowSearchTextHighlight? workflowSearchHighlight;

  HighlightContext _withoutSearchHighlight() => workflowSearchHighlight == null
      ? this
      : HighlightContext(
          accessiblePrefixes: accessiblePrefixes,
          availableEnvVars: availableEnvVars,
          highlightAll: highlightAll,
        );
}

/// What a span of display text is.
enum ReferenceSpanKind {
  /// Ordinary text.
  plain,

  /// A `<block.path>` reference the current block may read.
  blockReference,

  /// A `{{ENV_VAR}}` reference to a known environment variable.
  envReference,

  /// Token syntax that is not highlighted upstream: an inaccessible block
  /// prefix or an unknown env var. Rendered plain for parity.
  invalid,
}

/// One span of display text with its UTF-16 offsets into the source.
@immutable
class ReferenceSpan {
  const ReferenceSpan({
    required this.kind,
    required this.start,
    required this.end,
    required this.text,
    this.searchHighlight = false,
  });

  final ReferenceSpanKind kind;
  final int start;
  final int end;
  final String text;

  /// Inside the active search match (upstream wraps these in `<mark>`).
  final bool searchHighlight;

  @override
  bool operator ==(Object other) =>
      other is ReferenceSpan &&
      other.kind == kind &&
      other.start == start &&
      other.end == end &&
      other.text == text &&
      other.searchHighlight == searchHighlight;

  @override
  int get hashCode => Object.hash(kind, start, end, text, searchHighlight);

  @override
  String toString() => 'ReferenceSpan($kind $start-$end "$text")';
}

const Set<String> _systemPrefixes = {'loop', 'parallel', 'variable'};

/// Port of the `formatDisplayText` regex: `/<[^<>]+>|\{\{[^{}]+\}\}/g`.
final RegExp _displayTokenPattern = RegExp(r'<[^<>]+>|\{\{[^{}]+\}\}');

/// Port of `getValidWorkflowSearchRange`: the range only applies when it is
/// inside the text and still covers exactly `rawValue`.
WorkflowTextRange? getValidWorkflowSearchRange(
  String text,
  WorkflowSearchTextHighlight? highlight,
) {
  final range = highlight?.range;
  final rawValue = highlight?.rawValue;
  if (range == null || rawValue == null || rawValue.isEmpty) return null;
  if (range.start < 0 || range.end <= range.start || range.end > text.length) {
    return null;
  }
  return text.substring(range.start, range.end) == rawValue ? range : null;
}

/// Port of `formatDisplayText`: splits [text] into spans, highlighting
/// `<block.path>` references, `{{ENV}}` references and the active search
/// range. Spans are contiguous and concatenate back to [text].
List<ReferenceSpan> tokenizeDisplayText(
  String text, [
  HighlightContext? context,
]) => _tokenize(text, context, 0);

List<ReferenceSpan> _tokenize(
  String text,
  HighlightContext? context,
  int offset,
) {
  if (text.isEmpty) return const [];

  final searchRange = getValidWorkflowSearchRange(
    text,
    context?.workflowSearchHighlight,
  );
  if (searchRange != null) {
    final base = context?._withoutSearchHighlight();
    return [
      ..._tokenize(text.substring(0, searchRange.start), base, offset),
      for (final span in _tokenize(
        text.substring(searchRange.start, searchRange.end),
        base,
        offset + searchRange.start,
      ))
        ReferenceSpan(
          kind: span.kind,
          start: span.start,
          end: span.end,
          text: span.text,
          searchHighlight: true,
        ),
      ..._tokenize(
        text.substring(searchRange.end),
        base,
        offset + searchRange.end,
      ),
    ];
  }

  bool shouldHighlightReference(String reference) {
    if (!reference.startsWith('<') || !reference.endsWith('>')) return false;
    if (context?.highlightAll ?? false) return true;
    final inner = reference.substring(1, reference.length - 1);
    final prefix = inner.split('.').first;
    final normalized = normalizeWorkflowBlockName(prefix);
    if (_systemPrefixes.contains(normalized)) return true;
    return context?.accessiblePrefixes?.contains(normalized) ?? false;
  }

  bool shouldHighlightEnvVar(String name) {
    if (context?.highlightAll ?? false) return true;
    final available = context?.availableEnvVars;
    if (available == null) return true;
    return available.contains(name);
  }

  final spans = <ReferenceSpan>[];
  void pushPlain(int start, int end) {
    if (end <= start) return;
    spans.add(
      ReferenceSpan(
        kind: ReferenceSpanKind.plain,
        start: offset + start,
        end: offset + end,
        text: text.substring(start, end),
      ),
    );
  }

  var lastIndex = 0;
  for (final match in _displayTokenPattern.allMatches(text)) {
    final matchText = match.group(0)!;
    pushPlain(lastIndex, match.start);

    final ReferenceSpanKind kind;
    if (matchText.startsWith('{{')) {
      final name = matchText.substring(2, matchText.length - 2).trim();
      kind = shouldHighlightEnvVar(name)
          ? ReferenceSpanKind.envReference
          : ReferenceSpanKind.invalid;
    } else {
      final split = splitWorkflowReferenceSegment(matchText);
      if (split != null && shouldHighlightReference(split.reference)) {
        pushPlain(match.start, match.start + split.leading.length);
        spans.add(
          ReferenceSpan(
            kind: ReferenceSpanKind.blockReference,
            start: offset + match.start + split.leading.length,
            end: offset + match.end,
            text: split.reference,
          ),
        );
        lastIndex = match.end;
        continue;
      }
      kind = ReferenceSpanKind.invalid;
    }

    spans.add(
      ReferenceSpan(
        kind: kind,
        start: offset + match.start,
        end: offset + match.end,
        text: matchText,
      ),
    );
    lastIndex = match.end;
  }
  pushPlain(lastIndex, text.length);

  return spans;
}

// ---------------------------------------------------------------------------
// packages/utils/src/workflow-references.ts
// ---------------------------------------------------------------------------

const String _referenceStart = '<';
const String _referenceEnd = '>';
const String _referencePathDelimiter = '.';
final RegExp _invalidReferenceChars = RegExp('[+*/=<>!&|]');
final RegExp _leadingReferencePattern = RegExp(r'^[<>=!\s]*$');
final RegExp _envReferencePattern = RegExp(r'\{\{[^{}\r\n]+\}\}');
final RegExp _onlyComparison = RegExp(r'^\s*[<>=!]+\s*$');
final RegExp _spacedComparison = RegExp(r'\s[<>=!]+\s');
final RegExp _leadingComparison = RegExp(r'^[<>=!]+\s');
final RegExp _allDigits = RegExp(r'^\d+$');
final RegExp _spaceDigit = RegExp(r'\s\d');

/// Port of `WorkflowReferenceToken['kind']`.
enum WorkflowReferenceTokenKind { environment, workflow }

/// Port of `WorkflowReferenceToken`.
@immutable
class WorkflowReferenceToken {
  const WorkflowReferenceToken({
    required this.kind,
    required this.value,
    required this.start,
    required this.end,
  });

  final WorkflowReferenceTokenKind kind;
  final String value;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is WorkflowReferenceToken &&
      other.kind == kind &&
      other.value == value &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(kind, value, start, end);

  @override
  String toString() => 'WorkflowReferenceToken($kind $start-$end "$value")';
}

/// Port of `splitWorkflowReferenceSegment`: separates comparison characters
/// before the final `<workflow.reference>` segment.
({String leading, String reference})? splitWorkflowReferenceSegment(
  String segment,
) {
  if (!segment.startsWith(_referenceStart) ||
      !segment.endsWith(_referenceEnd)) {
    return null;
  }
  final lastOpen = segment.lastIndexOf(_referenceStart);
  if (lastOpen == -1) return null;
  final leading = lastOpen > 0 ? segment.substring(0, lastOpen) : '';
  final reference = segment.substring(lastOpen);
  if (!reference.startsWith(_referenceStart) ||
      !reference.endsWith(_referenceEnd)) {
    return null;
  }
  return (leading: leading, reference: reference);
}

/// Port of `isLikelyWorkflowReferenceSegment`: distinguishes Sim references
/// from comparison expressions and stray angle brackets.
bool isLikelyWorkflowReferenceSegment(String segment) {
  final split = splitWorkflowReferenceSegment(segment);
  if (split == null) return false;

  final leading = split.leading;
  if (leading.isNotEmpty && !_leadingReferencePattern.hasMatch(leading)) {
    return false;
  }

  final reference = split.reference;
  final inner = reference.substring(
    _referenceStart.length,
    reference.length - _referenceEnd.length,
  );
  if (inner.isEmpty || inner.startsWith(' ')) return false;
  if (_onlyComparison.hasMatch(inner) || _spacedComparison.hasMatch(inner)) {
    return false;
  }
  if (_leadingComparison.hasMatch(inner)) return false;

  final dotIndex = inner.indexOf(_referencePathDelimiter);
  if (dotIndex != -1) {
    final beforeDot = inner.substring(0, dotIndex);
    final afterDot = inner.substring(dotIndex + _referencePathDelimiter.length);
    return !afterDot.contains(' ') &&
        !_invalidReferenceChars.hasMatch(beforeDot) &&
        !_invalidReferenceChars.hasMatch(afterDot);
  }

  return !_invalidReferenceChars.hasMatch(inner) &&
      !_allDigits.hasMatch(inner) &&
      !_spaceDigit.hasMatch(inner);
}

/// Port of `findWorkflowReferenceTokens`: non-overlapping `{{ENV}}` and
/// `<workflow.reference>` tokens in source order. A candidate reference
/// resets at a line break and never overlaps an env token.
List<WorkflowReferenceToken> findWorkflowReferenceTokens(String source) {
  final tokens = <WorkflowReferenceToken>[
    for (final match in _envReferencePattern.allMatches(source))
      WorkflowReferenceToken(
        kind: WorkflowReferenceTokenKind.environment,
        value: match.group(0)!,
        start: match.start,
        end: match.end,
      ),
  ];

  var candidateStart = -1;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (character == _referenceStart && candidateStart == -1) {
      candidateStart = index;
      continue;
    }
    if (character == '\r' || character == '\n') {
      candidateStart = -1;
      continue;
    }
    if (character != _referenceEnd || candidateStart == -1) continue;

    final candidate = source.substring(candidateStart, index + 1);
    final split = splitWorkflowReferenceSegment(candidate);
    if (split != null && isLikelyWorkflowReferenceSegment(candidate)) {
      final start = candidateStart + split.leading.length;
      final end = start + split.reference.length;
      final overlaps = tokens.any(
        (token) => start < token.end && end > token.start,
      );
      if (!overlaps) {
        tokens.add(
          WorkflowReferenceToken(
            kind: WorkflowReferenceTokenKind.workflow,
            value: split.reference,
            start: start,
            end: end,
          ),
        );
      }
    }
    candidateStart = -1;
  }

  tokens.sort((left, right) => left.start.compareTo(right.start));
  return tokens;
}
