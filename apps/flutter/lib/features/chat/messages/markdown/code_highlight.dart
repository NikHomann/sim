import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/re_highlight.dart';

/// One highlighted run; [type] is a Prism token type (`property`, `string`,
/// `punctuation`, …) or null for default text.
@immutable
class ChatCodeToken {
  const ChatCodeToken(this.text, [this.type]);

  final String text;
  final String? type;

  @override
  bool operator ==(Object other) =>
      other is ChatCodeToken && other.text == text && other.type == type;

  @override
  int get hashCode => Object.hash(text, type);

  @override
  String toString() => type == null ? text : '$type($text)';
}

/// `LANG_ALIASES` (`chat-content.tsx:72-83`).
const Map<String, String> _aliases = <String, String>{
  'js': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'jsx': 'javascript',
  'sh': 'bash',
  'shell': 'bash',
  'html': 'markup',
  'xml': 'markup',
  'yml': 'yaml',
  'py': 'python',
};

/// The grammars emcn's Prism registers (markup, css, clike, javascript,
/// python, json, bash, toml; chat adds typescript). Anything else, YAML
/// included, renders through the JavaScript grammar like upstream.
final Highlight _highlight = Highlight()
  ..registerLanguages(<String, Mode>{
    'markup': langXml,
    'css': langCss,
    'clike': langJavascript,
    'javascript': langJavascript,
    'typescript': langTypescript,
    'python': langPython,
    'json': langJson,
    'bash': langBash,
    'toml': langIni,
  });

/// highlight.js scope → Prism token type.
const Map<String, String> _scopeToPrism = <String, String>{
  'comment': 'comment',
  'doctag': 'comment',
  'meta': 'prolog',
  'punctuation': 'punctuation',
  'operator': 'operator',
  'attr': 'property',
  'attribute': 'attr-name',
  'property': 'property',
  'variable': 'variable',
  'template-variable': 'variable',
  'tag': 'tag',
  'name': 'tag',
  'literal': 'boolean',
  'number': 'number',
  'variable.constant': 'constant',
  'string': 'string',
  'char.escape': 'string',
  'built_in': 'builtin',
  'addition': 'inserted',
  'deletion': 'deleted',
  'keyword': 'keyword',
  'title.function': 'function',
  'title.function.invoke': 'function',
  'function': 'function',
  'title.class': 'class-name',
  'title.class.inherited': 'class-name',
  'type': 'class-name',
  'title': 'function',
  'regexp': 'regex',
  'symbol': 'symbol',
  'selector-tag': 'tag',
  'selector-class': 'class-name',
  'section': 'keyword',
};

final RegExp _punctuation = RegExp(r'[{}\[\];(),.:]');
final RegExp _operator = RegExp(r'[=+\-*/%<>!&|^~?]');

/// Bounded LRU like upstream's `highlightCache` (512 entries).
final LinkedHashMap<String, List<List<ChatCodeToken>>> _cache =
    LinkedHashMap<String, List<List<ChatCodeToken>>>();
const int _cacheLimit = 512;

/// Test probe: receives the source of every highlighter run (cache misses).
@visibleForTesting
ValueChanged<String>? debugOnChatHighlight;

/// Test probe: entries held by the highlight LRU.
@visibleForTesting
int get debugChatHighlightCacheSize => _cache.length;

/// Test probe: empties the highlight LRU.
@visibleForTesting
void debugClearChatHighlightCache() => _cache.clear();

String _resolve(String language) {
  final lower = language.toLowerCase();
  final resolved = _aliases[lower] ?? (lower.isEmpty ? 'javascript' : lower);
  return _highlight.getLanguage(resolved) == null ? 'javascript' : resolved;
}

/// Highlights [code] (trailing whitespace trimmed, as `codeString.trimEnd()`)
/// and splits it into lines of tokens (`highlighted-lines.tsx`). A still
/// growing fence passes `cache: false` so each delta does not take an LRU
/// slot (and evict completed blocks).
List<List<ChatCodeToken>> highlightCode(
  String code,
  String language, {
  bool cache = true,
}) {
  final source = code.trimRight();
  final resolved = _resolve(language);
  final key = '$resolved\n$source';
  final cached = _cache.remove(key);
  if (cached != null) {
    _cache[key] = cached;
    return cached;
  }
  debugOnChatHighlight?.call(source);
  final renderer = _TokenRenderer(markup: resolved == 'markup');
  _highlight.highlight(code: source, language: resolved).render(renderer);
  final lines = <List<ChatCodeToken>>[<ChatCodeToken>[]];
  for (final token in renderer.tokens) {
    final parts = token.text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) lines.add(<ChatCodeToken>[]);
      if (parts[i].isNotEmpty) {
        lines.last.add(ChatCodeToken(parts[i], token.type));
      }
    }
  }
  if (!cache) return lines;
  _cache[key] = lines;
  if (_cache.length > _cacheLimit) _cache.remove(_cache.keys.first);
  return lines;
}

class _TokenRenderer implements HighlightRenderer {
  _TokenRenderer({required this.markup});

  final bool markup;
  final List<String?> _stack = <String?>[];
  final List<ChatCodeToken> tokens = <ChatCodeToken>[];

  String? get _type {
    for (var i = _stack.length - 1; i >= 0; i--) {
      final scope = _stack[i];
      if (scope == null) continue;
      // `beginKeywords` modes wrap their word in an inner `keyword` node; a
      // literal mode's word is still a Prism boolean.
      if (scope == 'keyword' && i > 0 && _stack[i - 1] == 'literal') continue;
      final mapped =
          _scopeToPrism[scope] ?? _scopeToPrism[scope.split('.').first];
      if (mapped != null) {
        // Inside a markup tag, quoted values are Prism `attr-value`.
        if (markup && mapped == 'string') return 'attr-value';
        return mapped;
      }
    }
    return null;
  }

  @override
  void addText(String text) {
    final type = _type;
    if (type != null) {
      tokens.add(ChatCodeToken(text, type));
      return;
    }
    // Prism tokenises punctuation and operators that highlight.js leaves
    // unscoped; both paint #383838 / #d4d4d4.
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isNotEmpty) tokens.add(ChatCodeToken(buffer.toString()));
      buffer.clear();
    }

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final kind = _punctuation.hasMatch(char)
          ? 'punctuation'
          : (!markup && _operator.hasMatch(char) ? 'operator' : null);
      if (kind == null) {
        buffer.write(char);
      } else {
        flush();
        tokens.add(ChatCodeToken(char, kind));
      }
    }
    flush();
  }

  @override
  void openNode(DataNode node) => _stack.add(node.scope);

  @override
  void closeNode(DataNode node) => _stack.removeLast();
}

/// Token colours of `packages/emcn/src/components/code/code.css`; null means
/// the default `--text-primary`.
Color? prismTokenColor(String? type, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (type) {
    'comment' ||
    'block-comment' ||
    'prolog' ||
    'doctype' ||
    'cdata' => dark ? const Color(0xFF6EC97D) : const Color(0xFF16A34A),
    'punctuation' ||
    'operator' ||
    'entity' ||
    'url' ||
    'symbol' => dark ? const Color(0xFFD4D4D4) : const Color(0xFF383838),
    'property' ||
    'attr-name' ||
    'variable' => dark ? const Color(0xFF4FC3F7) : const Color(0xFF0891B2),
    'tag' ||
    'boolean' ||
    'number' ||
    'constant' => dark ? const Color(0xFFA5D6A7) : const Color(0xFF16A34A),
    'string' ||
    'char' ||
    'builtin' ||
    'inserted' => dark ? const Color(0xFFF39C6B) : const Color(0xFFB45309),
    'atrule' ||
    'attr-value' ||
    'keyword' => dark ? const Color(0xFF2FA1FF) : const Color(0xFF2F55FF),
    'function' ||
    'class-name' => dark ? const Color(0xFFFBBF24) : const Color(0xFFCA8A04),
    'regex' ||
    'important' => dark ? const Color(0xFFF87171) : const Color(0xFFE11D48),
    'deleted' => dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    _ => null,
  };
}
