import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// One catalog template (`Candidate`, `suggested-actions.tsx:44-56`).
@immutable
class SuggestionTemplate {
  const SuggestionTemplate({
    required this.id,
    required this.blockType,
    required this.label,
    required this.prompt,
    required this.modules,
    this.iconId,
    this.featured = false,
    this.popular = false,
    this.providerId,
  });

  final String id;

  /// Diversity key: at most one suggestion per block.
  final String blockType;
  final String label;
  final String prompt;

  /// `brand/<name>` icon of the template, or null for the table glyph.
  final String? iconId;
  final List<String> modules;
  final bool featured;
  final bool popular;

  /// The OAuth provider of the owning block, when it is an OAuth
  /// integration.
  final String? providerId;
}

/// One `OAUTH_PROVIDERS` service (`useOAuthConnections` lists them all).
@immutable
class OAuthServiceEntry {
  const OAuthServiceEntry({
    required this.id,
    required this.name,
    required this.providerId,
  });

  final String id;
  final String name;
  final String providerId;
}

/// A suggested-action row (`Action`, `types.ts:16-20`).
@immutable
sealed class SuggestedAction {
  const SuggestedAction({required this.id, required this.label});

  final String id;
  final String label;
}

/// Populates the composer with [prompt].
class PromptAction extends SuggestedAction {
  const PromptAction({
    required super.id,
    required super.label,
    required this.prompt,
    this.iconId,
  });

  final String prompt;
  final String? iconId;
}

/// Opens the OAuth connect modal for the integration [slug].
class IntegrationAction extends SuggestedAction {
  const IntegrationAction({
    required super.id,
    required super.label,
    required this.slug,
    this.providerId,
  });

  final String slug;
  final String? providerId;
}

/// `TABLE_STARTERS` (`suggested-actions.tsx:59-75`).
const List<SuggestionTemplate> tableStarters = <SuggestionTemplate>[
  SuggestionTemplate(
    id: 'table-starter-0',
    blockType: 'table-starter-0',
    label: 'Create a CRM with sample data',
    prompt: 'Create a CRM with sample data.',
    modules: <String>['tables'],
    popular: true,
  ),
  SuggestionTemplate(
    id: 'table-starter-1',
    blockType: 'table-starter-1',
    label: 'Build a project tracker',
    prompt: 'Build a project tracker table.',
    modules: <String>['tables'],
    popular: true,
  ),
  SuggestionTemplate(
    id: 'table-starter-2',
    blockType: 'table-starter-2',
    label: 'Create a content calendar',
    prompt: 'Create a content calendar table.',
    modules: <String>['tables'],
    popular: true,
  ),
  SuggestionTemplate(
    id: 'table-starter-3',
    blockType: 'table-starter-3',
    label: 'Build an expense tracker',
    prompt: 'Build an expense tracker table.',
    modules: <String>['tables'],
    popular: true,
  ),
  SuggestionTemplate(
    id: 'table-starter-4',
    blockType: 'table-starter-4',
    label: 'Create a bug tracker',
    prompt: 'Create a bug tracker table.',
    modules: <String>['tables'],
    popular: true,
  ),
];

/// The first featured GitHub template of the catalog
/// (`CANDIDATES.filter(github && featured)[0]`), kept here so the initial
/// rows render without loading the catalog. A test checks it against the
/// generated catalog.
const SuggestionTemplate firstFeaturedGithubTemplate = SuggestionTemplate(
  id: 'github-6',
  blockType: 'github',
  label: 'Link GitHub pull requests to Jira tickets',
  prompt:
      'Build a workflow that monitors GitHub pull requests and automatically '
      'transitions linked Jira issues when PRs are opened or merged, keeping '
      'your project board accurate without any manual updates.',
  iconId: 'brand/github-icon',
  modules: <String>['agent', 'workflows'],
  featured: true,
);

PromptAction promptActionOf(SuggestionTemplate t) =>
    PromptAction(id: t.id, label: t.label, prompt: t.prompt, iconId: t.iconId);

/// `INITIAL_ACTIONS` (`suggested-actions.tsx:214-233`): Slack, Gmail, the
/// CRM starter and the first featured GitHub template. Shown until the
/// signals say the workspace has a connection (and for good otherwise).
final List<SuggestedAction> initialSuggestedActions = <SuggestedAction>[
  const IntegrationAction(
    id: 'integrate-slack',
    label: 'Integrate with Slack',
    slug: 'slack',
  ),
  const IntegrationAction(
    id: 'integrate-gmail',
    label: 'Integrate with Gmail',
    slug: 'gmail',
  ),
  promptActionOf(tableStarters.first),
  promptActionOf(firstFeaturedGithubTemplate),
];

/// `weightedSample` (`weighted-sample.ts`): sampling without replacement,
/// each pick proportional to its (non-negative) weight.
List<T> weightedSample<T>(
  List<T> pool,
  int n,
  double Function(T item) weightOf,
  math.Random random,
) {
  final remaining = <(T, double)>[
    for (final item in pool) (item, math.max(weightOf(item), 0)),
  ];
  final out = <T>[];
  while (out.length < n && remaining.isNotEmpty) {
    final total = remaining.fold<double>(0, (sum, e) => sum + e.$2);
    if (total <= 0) break;
    var roll = random.nextDouble() * total;
    var index = -1;
    for (var i = 0; i < remaining.length; i++) {
      roll -= remaining[i].$2;
      if (roll <= 0) {
        index = i;
        break;
      }
    }
    out.add(remaining.removeAt(index == -1 ? remaining.length - 1 : index).$1);
  }
  return out;
}

/// Workspace signals of the scoring (`Signals`).
@immutable
class SuggestionSignals {
  const SuggestionSignals({
    this.connectedProviders = const <String>{},
    this.hasTables = false,
    this.hasKnowledgeBases = false,
    this.servicesLoaded = false,
  });

  final Set<String> connectedProviders;
  final bool hasTables;
  final bool hasKnowledgeBases;

  /// The OAuth services query answered (`services.length > 0`).
  final bool servicesLoaded;

  /// `personalized` (`suggested-actions.tsx:290-294`).
  bool get personalized => servicesLoaded && connectedProviders.isNotEmpty;
}

/// `scoreCandidate` (`suggested-actions.tsx:149-160`).
double scoreSuggestion(SuggestionTemplate c, SuggestionSignals s) {
  var weight = 1.0;
  if (c.featured) weight *= 3;
  if (c.popular) weight *= 1.5;
  final provider = c.providerId;
  if (provider != null) {
    weight *= s.connectedProviders.contains(provider) ? 4 : 0.4;
  }
  if (c.modules.contains('tables') && !s.hasTables) weight *= 1.5;
  if (c.modules.contains('knowledge-base') && s.hasKnowledgeBases) {
    weight *= 0.6;
  }
  return weight;
}

/// The catalog `computeActions` draws from.
@immutable
class SuggestionCatalog {
  const SuggestionCatalog({
    required this.templates,
    required this.services,
    required this.slugByLowerName,
    required this.typeBySlug,
  });

  /// Table starters first, then the integration templates (`CANDIDATES`).
  final List<SuggestionTemplate> templates;
  final List<OAuthServiceEntry> services;
  final Map<String, String> slugByLowerName;
  final Map<String, String> typeBySlug;

  /// `TEMPLATE_COUNT_BY_TYPE`.
  Map<String, int> get templateCountByType {
    final counts = <String, int>{};
    for (final c in templates) {
      if (c.providerId != null) {
        counts[c.blockType] = (counts[c.blockType] ?? 0) + 1;
      }
    }
    return counts;
  }
}

/// `computeActions` (`suggested-actions.tsx:180-206`): one (or, for a
/// workspace without connections, two) "Integrate with X" rows for
/// unconnected services weighted by template count + 1, then prompts
/// weighted by [scoreSuggestion], at most one per block, four rows total.
List<SuggestedAction> computeSuggestedActions(
  SuggestionCatalog catalog,
  SuggestionSignals signals,
  math.Random random,
) {
  final counts = catalog.templateCountByType;
  final connect = <(OAuthServiceEntry, String)>[
    for (final s in catalog.services)
      if (!signals.connectedProviders.contains(s.providerId))
        if (catalog.slugByLowerName[s.name.toLowerCase()] case final slug?)
          (s, slug),
  ];
  final connectCount = signals.connectedProviders.isEmpty ? 2 : 1;
  final integrations = <SuggestedAction>[
    for (final (service, slug) in weightedSample(
      connect,
      connectCount,
      (e) => (counts[catalog.typeBySlug[e.$2] ?? ''] ?? 0) + 1.0,
      random,
    ))
      IntegrationAction(
        id: 'integrate-${service.providerId}',
        label: 'Integrate with ${service.name}',
        slug: slug,
        providerId: service.providerId,
      ),
  ];
  final scored = <(SuggestionTemplate, double)>[
    for (final c in catalog.templates)
      if (scoreSuggestion(c, signals) case final w when w > 0) (c, w),
  ];
  final prompts = <SuggestedAction>[];
  final used = <String>{};
  while (prompts.length < 4 - integrations.length) {
    final available = <(SuggestionTemplate, double)>[
      for (final e in scored)
        if (!used.contains(e.$1.blockType)) e,
    ];
    final picks = weightedSample(available, 1, (e) => e.$2, random);
    if (picks.isEmpty) break;
    used.add(picks.first.$1.blockType);
    prompts.add(promptActionOf(picks.first.$1));
  }
  return <SuggestedAction>[...integrations, ...prompts];
}
