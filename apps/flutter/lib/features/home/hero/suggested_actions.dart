import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/home/hero/brand_marks.dart';
import 'package:sim_app/features/home/hero/suggestion_catalog.g.dart'
    deferred as catalog;
import 'package:sim_app/features/home/hero/suggestion_types.dart';
import 'package:sim_app/features/home/home_http.dart';
import 'package:sim_app/features/home/panel/resource_inventory.dart';
import 'package:sim_design/sim_design.dart';

/// Loads the generated catalog (a deferred library: ~0.9 MB of prompts
/// stays out of the initial web bundle until a personalised set is drawn).
Future<SuggestionCatalog> loadSuggestionCatalog() async {
  await catalog.loadLibrary();
  // Deferred constants cannot be used in constant expressions.
  final templates = List<SuggestionTemplate>.of(tableStarters)
    ..addAll(catalog.suggestionTemplates);
  final services = catalog.oauthServiceCatalog;
  final slugs = catalog.integrationSlugByLowerName;
  final types = catalog.integrationTypeBySlug;
  return SuggestionCatalog(
    templates: templates,
    services: services,
    slugByLowerName: slugs,
    typeBySlug: types,
  );
}

/// The suggested-actions signals of a workspace: `GET /api/credentials`,
/// `GET /api/auth/oauth/connections`, `GET /api/table` and `GET
/// /api/knowledge`, fired on mount (`suggested-actions.tsx:245-253`).
// ignore: one_member_abstracts, the seam tests implement.
abstract class SuggestionSignalsSource {
  ValueListenable<SuggestionSignals> load(String workspaceId);
}

/// [SuggestionSignalsSource] over [HomeHttp]; every failure reads as "no
/// signal" (the initial rows stay).
class HttpSuggestionSignalsSource implements SuggestionSignalsSource {
  HttpSuggestionSignalsSource({required this.http, required this.queries});

  final HomeHttp? http;
  final QueryClient queries;

  static const Duration _stale = Duration(seconds: 30);

  @override
  ValueListenable<SuggestionSignals> load(String workspaceId) {
    final result = ValueNotifier<SuggestionSignals>(const SuggestionSignals());
    final client = http;
    if (client == null) return result;
    var connected = <String>{};
    var servicesLoaded = false;
    var hasTables = false;
    var hasKnowledgeBases = false;
    void publish() => result.value = SuggestionSignals(
      connectedProviders: connected,
      hasTables: hasTables,
      hasKnowledgeBases: hasKnowledgeBases,
      servicesLoaded: servicesLoaded,
    );
    Future<T> fetch<T>(
      QueryKey key,
      String path,
      Map<String, Object?>? query,
      T Function(Object? json) decode,
    ) => queries.fetchQuery<T>(
      key,
      (_) async => decode(await client.get(path, query: query)),
      staleTime: _stale,
    );
    unawaited(
      fetch<Set<String>>(
        <Object?>['credentials', 'list', workspaceId],
        '/api/credentials',
        <String, Object?>{'workspaceId': workspaceId},
        (json) => <String>{
          for (final c in jsonList(json, 'credentials'))
            if ((c['type'] == 'oauth' || c['type'] == 'service_account') &&
                c['providerId'] is String &&
                (c['providerId']! as String).isNotEmpty)
              c['providerId']! as String,
        },
      ).then((value) {
        connected = value;
        publish();
      }, onError: (Object _) {}),
    );
    // The service catalog is static; the connections request only decides
    // when it counts as loaded (a failure still resolves the catalog).
    unawaited(
      fetch<bool>(
        const <Object?>['oauthConnections', 'connections'],
        '/api/auth/oauth/connections',
        null,
        (_) => true,
      ).then(
        (_) {
          servicesLoaded = true;
          publish();
        },
        onError: (Object _) {
          servicesLoaded = true;
          publish();
        },
      ),
    );
    unawaited(
      fetchTableList(client, queries, workspaceId).then((rows) {
        hasTables = rows.isNotEmpty;
        publish();
      }, onError: (Object _) {}),
    );
    unawaited(
      fetchKnowledgeBaseList(client, queries, workspaceId).then((rows) {
        hasKnowledgeBases = rows.isNotEmpty;
        publish();
      }, onError: (Object _) {}),
    );
    return result;
  }
}

/// `HomeSection` (`components/home/home-section.tsx`): the collapsible
/// "Suggested actions" shell. The chevron shows on section hover or toggle
/// focus; the body animates only after the first toggle.
class HomeSection extends StatefulWidget {
  const HomeSection({
    required this.title,
    required this.expanded,
    required this.animationsEnabled,
    required this.onToggle,
    required this.children,
    super.key,
  });

  final String title;
  final bool expanded;
  final bool animationsEnabled;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  State<HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends State<HomeSection> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    // `animate-none` until the first toggle; motion off never animates.
    final duration = widget.animationsEnabled
        ? SimMotion.of(SimMotion.collapsible)
        : Duration.zero;
    final Widget body = widget.expanded
        ? Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          )
        : const SizedBox(width: double.infinity);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Semantics(
          identifier: 'home.suggested',
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SimPressable(
                onPressed: widget.onToggle,
                semanticsLabel: widget.title,
                selected: widget.expanded,
                builder: (context, state) => Semantics(
                  identifier: 'home.suggested.toggle',
                  container: true,
                  expanded: widget.expanded,
                  child: Row(
                    spacing: 8,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: sim.text.caption.copyWith(color: c.textMuted),
                      ),
                      AnimatedOpacity(
                        duration: SimMotion.of(SimMotion.sidebarChevron),
                        opacity: _hovered || state.focused ? 1 : 0,
                        child: AnimatedRotation(
                          duration: SimMotion.of(SimMotion.sidebarChevron),
                          turns: widget.expanded ? 0 : -0.25,
                          child: SimIcon(
                            SimEmcnIcons.chevronDown,
                            color: c.textIcon,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (duration == Duration.zero)
                body
              else
                ClipRect(
                  child: AnimatedSize(
                    duration: duration,
                    curve: SimMotion.standard,
                    alignment: Alignment.topCenter,
                    child: body,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `SuggestedActions` (`suggested-actions.tsx:236-376`): four rows,
/// expanded by default. Without a connection (or before the signals
/// answer) the fixed initial set; with one, a personalised draw that
/// changes on every mount. Prompt rows populate the composer; integration
/// rows ask for the OAuth connect modal.
class SuggestedActions extends StatefulWidget {
  const SuggestedActions({
    required this.workspaceId,
    required this.signals,
    required this.onSelectPrompt,
    required this.onSelectIntegration,
    super.key,
    this.random,
    this.loadCatalog = loadSuggestionCatalog,
  });

  final String workspaceId;
  final SuggestionSignalsSource signals;
  final ValueChanged<String> onSelectPrompt;
  final ValueChanged<IntegrationAction> onSelectIntegration;

  /// The draw's randomness (tests seed it).
  final math.Random? random;
  final Future<SuggestionCatalog> Function() loadCatalog;

  @override
  State<SuggestedActions> createState() => SuggestedActionsState();
}

class SuggestedActionsState extends State<SuggestedActions> {
  late ValueListenable<SuggestionSignals> _signals;
  late final math.Random _random = widget.random ?? math.Random();
  List<SuggestedAction> _actions = initialSuggestedActions;
  bool _expanded = true;
  bool _animationsEnabled = false;
  SuggestionSignals? _drawnFor;

  List<SuggestedAction> get actions => _actions;

  @override
  void initState() {
    super.initState();
    _signals = widget.signals.load(widget.workspaceId)..addListener(_onSignals);
    _onSignals();
  }

  @override
  void didUpdateWidget(SuggestedActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.signals != widget.signals) {
      _signals.removeListener(_onSignals);
      _signals = widget.signals.load(widget.workspaceId)
        ..addListener(_onSignals);
      _onSignals();
    }
  }

  @override
  void dispose() {
    _signals.removeListener(_onSignals);
    super.dispose();
  }

  bool _sameSignals(SuggestionSignals a, SuggestionSignals b) =>
      setEquals(a.connectedProviders, b.connectedProviders) &&
      a.hasTables == b.hasTables &&
      a.hasKnowledgeBases == b.hasKnowledgeBases &&
      a.servicesLoaded == b.servicesLoaded;

  void _onSignals() {
    final signals = _signals.value;
    if (!signals.personalized) {
      if (!identical(_actions, initialSuggestedActions)) {
        setState(() => _actions = initialSuggestedActions);
      }
      return;
    }
    final drawn = _drawnFor;
    if (drawn != null && _sameSignals(drawn, signals)) return;
    _drawnFor = signals;
    unawaited(
      widget.loadCatalog().then((catalog) {
        if (!mounted || !identical(_drawnFor, signals)) return;
        setState(
          () => _actions = computeSuggestedActions(catalog, signals, _random),
        );
      }),
    );
  }

  void _toggle() => setState(() {
    _animationsEnabled = true;
    _expanded = !_expanded;
  });

  @override
  Widget build(BuildContext context) => HomeSection(
    title: 'Suggested actions',
    expanded: _expanded,
    animationsEnabled: _animationsEnabled,
    onToggle: _toggle,
    children: <Widget>[
      for (var i = 0; i < _actions.length; i++)
        _SuggestionRow(
          action: _actions[i],
          first: i == 0,
          onPressed: () {
            final action = _actions[i];
            switch (action) {
              case PromptAction(:final prompt):
                widget.onSelectPrompt(prompt);
              case IntegrationAction():
                widget.onSelectIntegration(action);
            }
          },
        ),
    ],
  );
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.action,
    required this.first,
    required this.onPressed,
  });

  final SuggestedAction action;
  final bool first;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final icon = switch (action) {
      PromptAction(:final iconId) => SuggestionIcon(iconId: iconId),
      IntegrationAction(:final slug, :final label) => SuggestionIcon(
        slug: slug,
        label: label,
      ),
    };
    Widget row = SimPressable(
      onPressed: onPressed,
      semanticsLabel: action.label,
      builder: (context, state) => AnimatedContainer(
        duration: SimMotion.of(SimMotion.colors),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: state.hovered ? c.surface5 : const Color(0x00000000),
          border: first ? null : Border(top: BorderSide(color: c.border)),
        ),
        child: Row(
          spacing: 8,
          children: <Widget>[
            icon,
            Expanded(
              child: SimOverflowText(
                label: action.label,
                // Tailwind `text-sm` carries its own 20px line height, so
                // the row is 8 + 20 + 8 = 36px (+1px border after the first).
                style: sim.text.sm.copyWith(color: c.textBody, height: 20 / 14),
              ),
            ),
            SimIcon(SimEmcnIcons.arrowRight, size: 16, color: c.textIcon),
          ],
        ),
      ),
    );
    if (first) {
      row = Semantics(
        identifier: 'home.suggested.row',
        container: true,
        child: row,
      );
    }
    return row;
  }
}
