import 'package:sim_app/features/chat/input/model/chat_context.dart';
import 'package:sim_app/features/chat/input/model/chat_tokens.dart';
import 'package:sim_app/features/chat/input/model/composer_resources.dart';

/// Characters that complete a word (`WORD_BOUNDARY_REGEX`).
final RegExp _wordBoundary = RegExp(
  r'^[\s.,;:!?(){}\[\]"'
  "'"
  r'`/\\<>\n]$',
);
final RegExp _space = RegExp(r'\s');

/// The single inserted character of a one-char keystroke, and where.
({int index, String char})? _insertedChar(String previous, String next) {
  if (next.length != previous.length + 1) return null;
  var i = 0;
  while (i < previous.length && previous[i] == next[i]) {
    i++;
  }
  return (index: i, char: next[i]);
}

/// A keystroke conversion: the rewritten text and the context it registers.
typedef AutoMentionHit = ({String text, ChatContext context});

/// Port of `use-integration-auto-mention.ts` + `getIntegrationMatcher`:
/// explicit `@`-prefixed integration names (any casing) canonicalise to
/// `@Name` and register an `integration` context; bare names never chip.
class IntegrationMatcher {
  IntegrationMatcher(List<ComposerIntegration> integrations) {
    final names = <String>[];
    for (final integration in integrations) {
      final name = integration.name.trim();
      if (name.length < 2) continue;
      final key = name.toLowerCase();
      if (_byName.containsKey(key)) continue;
      _byName[key] = integration;
      names.add(name);
    }
    names.sort((a, b) => b.length.compareTo(a.length));
    _regex = names.isEmpty
        ? null
        : RegExp(
            '(?<![A-Za-z0-9_])(${names.map(RegExp.escape).join('|')})'
            '(?![A-Za-z0-9_])',
            caseSensitive: false,
          );
  }

  final Map<String, ComposerIntegration> _byName = {};
  RegExp? _regex;

  bool get isEmpty => _regex == null;

  static bool _isMentionPrefixAt(String text, int atIndex) {
    if (atIndex < 0 || atIndex >= text.length || text[atIndex] != '@') {
      return false;
    }
    return atIndex == 0 || _space.hasMatch(text[atIndex - 1]);
  }

  ChatContext _contextOf(ComposerIntegration info) =>
      ChatContext.integration(info.blockType, info.name);

  /// `convertText`: bulk rewrite for paste, restore and programmatic text.
  ({String text, List<ChatContext> contexts}) convertText(String text) {
    final regex = _regex;
    if (regex == null || text.isEmpty) {
      return (text: text, contexts: const []);
    }
    final contexts = <ChatContext>[];
    final seen = <String>{};
    final out = StringBuffer();
    var lastEnd = 0;
    var mutated = false;
    for (final match in regex.allMatches(text)) {
      final info = _byName[match[0]!.toLowerCase()];
      if (info == null) continue;
      if (!_isMentionPrefixAt(text, match.start - 1)) continue;
      if (seen.add(info.name)) contexts.add(_contextOf(info));
      if (match[0] == info.name) continue;
      out
        ..write(text.substring(lastEnd, match.start))
        ..write(info.name);
      lastEnd = match.end;
      mutated = true;
    }
    if (!mutated) return (text: text, contexts: contexts);
    out.write(text.substring(lastEnd));
    return (text: out.toString(), contexts: contexts);
  }

  /// `processChange`: a boundary character just typed after `@name`.
  AutoMentionHit? processKeystroke(String previous, String next, int caret) {
    final regex = _regex;
    if (regex == null) return null;
    final inserted = _insertedChar(previous, next);
    if (inserted == null || !_wordBoundary.hasMatch(inserted.char)) {
      return null;
    }
    final before = next.substring(0, inserted.index);
    RegExpMatch? completed;
    for (final match in regex.allMatches(before)) {
      if (match.end == before.length) completed = match;
    }
    if (completed == null) return null;
    final info = _byName[completed[0]!.toLowerCase()];
    if (info == null) return null;
    if (!_isMentionPrefixAt(next, completed.start - 1)) return null;
    final text = completed[0] == info.name
        ? next
        : next.replaceRange(completed.start, completed.end, info.name);
    return (text: text, context: _contextOf(info));
  }

  /// `mentionifyIntegrations`: bare names become `@Name` (curated prompts).
  String mentionify(String text) {
    final regex = _regex;
    if (regex == null || text.isEmpty) return text;
    return text.replaceAllMapped(regex, (match) {
      final offset = match.start;
      return offset > 0 && text[offset - 1] == '@' ? match[0]! : '@${match[0]}';
    });
  }
}

/// Port of `use-skill-auto-mention.ts`: a completed `/name` (or a pasted
/// sentinel token) for a known skill or MCP server registers the context
/// and swaps a typed `/` for [skillChipTrigger].
class SlashMatcher {
  SlashMatcher({
    required List<ComposerSkill> skills,
    required List<ComposerMcpServer> mcpServers,
    String? ownerWorkspaceId,
    bool organizationScoped = false,
  }) {
    final counts = <String, int>{};
    for (final skill in skills) {
      final key = skill.name.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (final skill in skills) {
      final key = skill.name.toLowerCase();
      if (organizationScoped && counts[key] != 1) continue;
      final owner = skill.builtin
          ? null
          : organizationScoped
          ? skill.workspaceId
          : ownerWorkspaceId;
      _byName[key] = ChatContext.skill(
        skill.id,
        skill.name,
        workspaceId: owner,
      );
    }
    for (final server in mcpServers) {
      _byName.putIfAbsent(
        server.name.toLowerCase(),
        () => ChatContext.mcp(
          server.id,
          server.name,
          managedConnectorId: server.managedConnectorId,
        ),
      );
    }
    final names = _byName.values.map((c) => c.label).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    _regex = names.isEmpty
        ? null
        : RegExp(
            '(?:/|$skillChipTrigger)(${names.map(RegExp.escape).join('|')})'
            '(?![A-Za-z0-9_-])',
            caseSensitive: false,
          );
  }

  final Map<String, ChatContext> _byName = {};
  RegExp? _regex;

  static bool _isTriggerPrefixAt(String text, int index) {
    final ch = text[index];
    if (ch != '/' && ch != skillChipTrigger) return false;
    return index == 0 || _space.hasMatch(text[index - 1]);
  }

  static String _key(ChatContext c) => c.kind == ChatContextKind.skill
      ? 'skill:${c.workspaceId ?? ''}:${c.field('skillId')}'
      : 'mcp:${c.field('serverId')}';

  /// `applyToText`.
  ({String text, List<ChatContext> contexts}) convertText(String text) {
    final regex = _regex;
    if (regex == null || text.isEmpty) {
      return (text: text, contexts: const []);
    }
    final additions = <ChatContext>[];
    final seen = <String>{};
    final slashIndices = <int>[];
    for (final match in regex.allMatches(text)) {
      if (!_isTriggerPrefixAt(text, match.start)) continue;
      final context = _byName[match[1]!.toLowerCase()];
      if (context == null) continue;
      if (text[match.start] == '/') slashIndices.add(match.start);
      if (seen.add(_key(context))) additions.add(context);
    }
    var result = text;
    for (final index in slashIndices.reversed) {
      result = result.replaceRange(index, index + 1, skillChipTrigger);
    }
    return (text: result, contexts: additions);
  }

  /// `processChange`.
  AutoMentionHit? processKeystroke(String previous, String next, int caret) {
    final regex = _regex;
    if (regex == null) return null;
    final inserted = _insertedChar(previous, next);
    if (inserted == null || !_wordBoundary.hasMatch(inserted.char)) {
      return null;
    }
    final before = next.substring(0, inserted.index);
    RegExpMatch? completed;
    for (final match in regex.allMatches(before)) {
      if (match.end == before.length) completed = match;
    }
    if (completed == null) return null;
    if (!_isTriggerPrefixAt(next, completed.start)) return null;
    final context = _byName[completed[1]!.toLowerCase()];
    if (context == null) return null;
    final text = next[completed.start] == '/'
        ? next.replaceRange(
            completed.start,
            completed.start + 1,
            skillChipTrigger,
          )
        : next;
    return (text: text, context: context);
  }

  /// Merges [additions] into [current] by skill/server identity
  /// (`mergeContexts`), filling a missing owner on an existing skill.
  static List<ChatContext> merge(
    List<ChatContext> current,
    List<ChatContext> additions,
  ) {
    if (additions.isEmpty) return current;
    final owned = {
      for (final a in additions)
        if (a.kind == ChatContextKind.skill && a.workspaceId != null)
          a.field('skillId'): a.workspaceId!,
    };
    var changed = false;
    final normalized = [
      for (final c in current)
        if (c.kind == ChatContextKind.skill &&
            c.workspaceId == null &&
            owned.containsKey(c.field('skillId')))
          () {
            changed = true;
            return c.withWorkspace(owned[c.field('skillId')]!);
          }()
        else
          c,
    ];
    final existing = {
      for (final c in normalized)
        if (c.kind == ChatContextKind.skill || c.kind == ChatContextKind.mcp)
          _key(c),
    };
    final fresh = [
      for (final a in additions)
        if (!existing.contains(_key(a))) a,
    ];
    if (fresh.isEmpty) return changed ? normalized : current;
    return [...normalized, ...fresh];
  }
}

/// `mergeContexts` of the integration matcher: by label among integrations.
List<ChatContext> mergeIntegrationContexts(
  List<ChatContext> current,
  List<ChatContext> additions,
) {
  if (additions.isEmpty) return current;
  final existing = {
    for (final c in current)
      if (c.kind == ChatContextKind.integration) c.label,
  };
  final fresh = [
    for (final a in additions)
      if (!existing.contains(a.label)) a,
  ];
  return fresh.isEmpty ? current : [...current, ...fresh];
}
