/// The palette's ranking, ported from
/// `apps/sim/app/workspace/[workspaceId]/w/components/sidebar/components/search-modal/utils.ts`
/// (`fuzzyMatch`, the score tiers, `scoreSectionItems`, `scoreActions`,
/// `getGlobalSearchResults`) and `apps/sim/lib/search/tokens.ts`
/// (`toSearchToken`).
///
/// Every sort here is stable (`mergeSort`), as `Array.prototype.sort` is:
/// equal scores keep section order, then in-section order.
library;

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:sim_app/features/workspace_shell/search/palette_models.dart';

/// Rank offset that lifts every name match above any secondary-text match.
const double nameMatchTier = 1000000;

/// Rank offset that lifts a whole section when the query IS its label.
const double sectionMatchTier = 2000000;

/// Rank offset for a page row (or exact block / trigger / `exactQueries`
/// action) whose name IS the query.
const double pageMatchTier = 3000000;

/// Added to word-start action matches (`ACTION_MATCH_BIAS`).
const double actionMatchBias = 500000;

/// Max rows per section while searching (`MAX_RESULTS_PER_GROUP`).
const int maxResultsPerGroup = 50;

/// Max rows in the flat search list (`MAX_SEARCH_RESULTS`).
const int maxSearchResults = 50;

/// Characters that begin a new word (`SEPARATORS`).
const Set<String> _separators = {' ', '-', '_', '/', '.', ':', '(', ')'};

/// `toSearchToken`: collapses a phrase into one kebab-case token.
String toSearchToken(String value) =>
    value.trim().split(RegExp(r'\s+')).join('-');

/// Result of matching a query against one candidate string.
class FuzzyResult {
  const FuzzyResult({
    required this.matched,
    required this.score,
    this.positions = const <int>[],
  });

  static const FuzzyResult noMatch = FuzzyResult(matched: false, score: 0);

  final bool matched;
  final double score;

  /// Matched indices into the candidate, ascending.
  final List<int> positions;
}

bool _isCamelBoundary(String text, int index) {
  if (index == 0) return false;
  final prev = text[index - 1];
  final curr = text[index];
  return prev == prev.toLowerCase() &&
      curr != curr.toLowerCase() &&
      curr == curr.toUpperCase();
}

bool _isHardBoundary(String lowerText, int index) =>
    index == 0 || _separators.contains(lowerText[index - 1]);

FuzzyResult _tokenFallback(String lowerText, String lowerQuery) {
  final tokens = lowerQuery
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.length <= 1 || !tokens.every(lowerText.contains)) {
    return FuzzyResult.noMatch;
  }
  final positions = <int>{};
  for (final token in tokens) {
    final start = lowerText.indexOf(token);
    for (var k = 0; k < token.length; k++) {
      positions.add(start + k);
    }
  }
  return FuzzyResult(
    matched: true,
    score: 10 - lowerText.length * 0.1,
    positions: positions.toList()..sort(),
  );
}

/// `fuzzyMatch`: substring hits first (boundary bonuses, exact/prefix/other
/// bonuses, position and length penalties), then a scattered subsequence that
/// must start at a hard boundary, then the multi-word token fallback.
/// [scatter] `false` skips the scattered mode (secondary text).
FuzzyResult fuzzyMatch(String text, String query, {bool scatter = true}) {
  if (query.isEmpty) return const FuzzyResult(matched: true, score: 1);
  if (text.isEmpty) return FuzzyResult.noMatch;

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();

  final substringIndex = lowerText.indexOf(lowerQuery);
  if (substringIndex != -1) {
    final length = lowerQuery.length;
    var score = 1.0;
    if (substringIndex == 0) {
      score += 10;
    } else if (_separators.contains(lowerText[substringIndex - 1])) {
      score += 8;
    } else if (_isCamelBoundary(text, substringIndex)) {
      score += 6;
    }
    score += (length - 1) * 6;

    if (lowerText == lowerQuery) {
      score += 120;
    } else if (substringIndex == 0) {
      score += 50;
    } else {
      score += 25;
    }

    score -= substringIndex * 0.5;
    score -= (length - 1) * 0.15;
    score -= lowerText.length * 0.1;
    return FuzzyResult(
      matched: true,
      score: score,
      positions: [for (var k = 0; k < length; k++) substringIndex + k],
    );
  }

  if (!scatter) return _tokenFallback(lowerText, lowerQuery);

  final positions = <int>[];
  var queryIndex = 0;
  var score = 0.0;
  var prevMatch = -2;
  for (var i = 0; i < lowerText.length && queryIndex < lowerQuery.length; i++) {
    if (lowerText[i] != lowerQuery[queryIndex]) continue;
    var charScore = 1.0;
    if (i == 0) {
      charScore += 10;
    } else if (_separators.contains(lowerText[i - 1])) {
      charScore += 8;
    } else if (_isCamelBoundary(text, i)) {
      charScore += 6;
    }
    if (prevMatch == i - 1) charScore += 5;
    score += charScore;
    positions.add(i);
    prevMatch = i;
    queryIndex++;
  }

  if (queryIndex == lowerQuery.length &&
      _isHardBoundary(lowerText, positions.first)) {
    score -= positions.first * 0.5;
    score -= (positions.last - positions.first) * 0.15;
    score -= lowerText.length * 0.1;
    return FuzzyResult(matched: true, score: score, positions: positions);
  }

  return _tokenFallback(lowerText, lowerQuery);
}

final Map<String, List<String>> _secondaryWords = <String, List<String>>{};

/// `matchSecondaryText`: whole-string match without scatter, else the best
/// per-word match (scatter allowed within one word).
FuzzyResult _matchSecondaryText(String extra, String query) {
  final whole = fuzzyMatch(extra, query, scatter: false);
  var best = whole.matched ? whole : FuzzyResult.noMatch;
  if (_secondaryWords.length > 4096) _secondaryWords.clear();
  final words = _secondaryWords.putIfAbsent(
    extra,
    () => extra.split(RegExp(r'\s+')),
  );
  for (final word in words) {
    final byWord = fuzzyMatch(word, query);
    if (byWord.matched && (!best.matched || byWord.score > best.score)) {
      best = byWord;
    }
  }
  return best;
}

/// `scoreItem`: a name match lifted by [nameMatchTier], else the secondary
/// text match.
FuzzyResult _scoreItem(String name, String search, String? Function()? extra) {
  final byName = fuzzyMatch(name, search);
  if (byName.matched) {
    return FuzzyResult(
      matched: true,
      score: byName.score + nameMatchTier,
      positions: byName.positions,
    );
  }
  final text = extra?.call();
  if (text == null || text.isEmpty) return FuzzyResult.noMatch;
  final byExtra = _matchSecondaryText(text, search);
  return byExtra.matched ? byExtra : FuzzyResult.noMatch;
}

/// One ranked item.
class Scored<T> {
  const Scored(this.item, this.score);

  final T item;
  final double score;
}

void _sortDescending<T>(List<Scored<T>> list) =>
    mergeSort<Scored<T>>(list, compare: (a, b) => b.score.compareTo(a.score));

/// `scoreAndSort`: matched items with their scores, best first.
List<Scored<T>> scoreAndSort<T>(
  List<T> items,
  String Function(T item) toValue,
  String search, {
  String? Function(T item)? toExtra,
}) {
  final query = search.trim();
  final scored = <Scored<T>>[];
  for (final item in items) {
    final result = _scoreItem(
      toValue(item),
      query,
      toExtra == null ? null : () => toExtra(item),
    );
    if (result.matched) scored.add(Scored(item, result.score));
  }
  _sortDescending(scored);
  return scored;
}

/// `scoreItemsForSection`: ranked matches, then — when the query matches the
/// section label — the remaining rows in natural order just below the
/// lowest match; a query equal to the label lifts every row into
/// [sectionMatchTier] minus its index.
List<Scored<T>> _scoreItemsForSection<T>(
  String sectionLabel,
  List<T> items,
  String Function(T item) toValue,
  String search, {
  String? Function(T item)? toExtra,
  int? maxResults,
}) {
  final max = maxResults ?? 1000000000;
  final ranked = scoreAndSort(items, toValue, search, toExtra: toExtra);
  final query = search.trim();
  final sectionMatch = fuzzyMatch(sectionLabel, query);
  final isExactLabelMatch =
      sectionMatch.matched && query.toLowerCase() == sectionLabel.toLowerCase();

  List<Scored<T>> results;
  if (!sectionMatch.matched || ranked.length >= max) {
    results = ranked.take(max).toList();
  } else {
    final matched = Set<T>.identity()..addAll(ranked.map((s) => s.item));
    final fallbackScore = ranked.isEmpty
        ? sectionMatch.score
        : math.min(sectionMatch.score, ranked.last.score - 1);
    results = [...ranked];
    for (final item in items) {
      if (!matched.contains(item)) results.add(Scored(item, fallbackScore));
      if (results.length >= max) break;
    }
  }

  if (isExactLabelMatch) {
    return [
      for (var i = 0; i < results.length; i++)
        Scored(results[i].item, sectionMatchTier - i),
    ];
  }
  return results;
}

/// `scoreSectionItems`: [_scoreItemsForSection] under the section's label;
/// tool operations never match on their label.
List<Scored<T>> scoreSectionItems<T>(
  SearchSection section,
  List<T> items,
  String Function(T item) toValue,
  String search, {
  String? Function(T item)? toExtra,
  int? maxResults,
}) {
  if (section == SearchSection.toolOperations) {
    final ranked = scoreAndSort(items, toValue, search, toExtra: toExtra);
    return maxResults == null ? ranked : ranked.take(maxResults).toList();
  }
  return _scoreItemsForSection(
    section.label,
    items,
    toValue,
    search,
    toExtra: toExtra,
    maxResults: maxResults,
  );
}

bool _isWordStartMatch(String text, List<int> positions) {
  if (positions.isEmpty) return true;
  return _isHardBoundary(text.toLowerCase(), positions.first) ||
      _isCamelBoundary(text, positions.first);
}

/// `scoreActions`: actions ranked under their group label with
/// `kebab(name) + keywords` as secondary text; an `exactQueries` hit ranks at
/// [pageMatchTier]; word-start matches gain [actionMatchBias], a mid-word
/// name hit below the section tier does not.
List<Scored<PaletteAction>> scoreActions(
  List<PaletteAction> actions,
  String search, {
  int? maxResults,
  String groupLabel = 'Sim',
}) {
  final query = search.trim().toLowerCase();
  return _scoreItemsForSection<PaletteAction>(
    groupLabel,
    actions,
    (action) => action.name,
    search,
    toExtra: (action) =>
        '${toSearchToken(action.name)} ${action.keywords ?? ''}',
    maxResults: maxResults,
  ).map((scored) {
    final item = scored.item;
    if (item.exactQueries.contains(query)) {
      return Scored(item, pageMatchTier);
    }
    final byName = fuzzyMatch(item.name, query);
    final midWord =
        scored.score < sectionMatchTier &&
        byName.matched &&
        !_isWordStartMatch(item.name, byName.positions);
    return Scored(
      item,
      midWord ? scored.score : scored.score + actionMatchBias,
    );
  }).toList();
}

/// `getGlobalSearchResults`: every section's entries concatenated in
/// [sections] order, stable-sorted by score descending.
List<PaletteEntry> globalSearchResults(
  Map<SearchSection, List<PaletteEntry>> entriesBySection,
  List<SearchSection> sections,
) {
  final flat = [
    for (final section in sections) ...?entriesBySection[section],
  ];
  mergeSort<PaletteEntry>(flat, compare: (a, b) => b.score.compareTo(a.score));
  return flat;
}

/// `filterAndSort`: the input unchanged for an empty query, else the
/// matches best first.
List<T> filterAndSort<T>(
  List<T> items,
  String Function(T item) toValue,
  String search, {
  String? Function(T item)? toExtra,
}) {
  if (search.trim().isEmpty) return items;
  return [
    for (final s in scoreAndSort(items, toValue, search, toExtra: toExtra))
      s.item,
  ];
}

/// `filterAndCap`: [filterAndSort] capped at [maxResultsPerGroup] while
/// searching; the browse state is never capped.
List<T> filterAndCap<T>(
  List<T> items,
  String Function(T item) toValue,
  String search, {
  String? Function(T item)? toExtra,
}) {
  final results = filterAndSort(items, toValue, search, toExtra: toExtra);
  return search.trim().isEmpty
      ? results
      : results.take(maxResultsPerGroup).toList();
}
