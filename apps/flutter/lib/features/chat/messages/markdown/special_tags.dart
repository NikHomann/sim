import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';

/// One piece of parsed assistant text (`ContentSegment`).
@immutable
sealed class ChatContentPiece {
  const ChatContentPiece();
}

class ChatTextPiece extends ChatContentPiece {
  const ChatTextPiece(this.text);

  final String text;
}

class ChatSourcePiece extends ChatContentPiece {
  const ChatSourcePiece(this.source);

  final ChatSourceView source;
}

class ChatResourcePiece extends ChatContentPiece {
  const ChatResourcePiece(this.resource);

  final ChatResourceView resource;
}

/// A block tag: question, follow-ups, error or credential.
class ChatBlockPiece extends ChatContentPiece {
  const ChatBlockPiece(this.segment);

  final ChatSegment segment;
}

@immutable
class ParsedSpecialTags {
  const ParsedSpecialTags(this.pieces, {required this.hasPendingTag});

  final List<ChatContentPiece> pieces;

  /// A tag is mid-stream: its bytes render nothing and the shimmer bridges.
  final bool hasPendingTag;
}

const List<String> _tagNames = <String>[
  'thinking',
  'options',
  'usage_upgrade',
  'credential',
  'mothership-error',
  'workspace_resource',
  'question',
  'source',
];

/// Runtime names that may still be arriving as a half-received `<opener`.
const List<String> _runtimeNames = <String>[..._tagNames, 'file'];

/// Port of `parseSpecialTags` (`special-tags.tsx:1573`): finds the nearest
/// known opener, resolves its body, and returns text and tag pieces in
/// order. Simplified relative to upstream: a body that fails to parse as the
/// tag's payload is discarded when the tag closed, and an unclosed tag is
/// pending while streaming and literal text afterwards.
ParsedSpecialTags parseSpecialTags(String content, {required bool streaming}) {
  final pieces = <ChatContentPiece>[];
  var pending = false;
  var discarded = false;
  var cursor = 0;

  void pushText(String text) {
    if (text.isNotEmpty) pieces.add(ChatTextPiece(text));
  }

  while (cursor < content.length) {
    var nearest = -1;
    var name = '';
    for (final candidate in _tagNames) {
      final index = content.indexOf('<$candidate>', cursor);
      if (index != -1 && (nearest == -1 || index < nearest)) {
        nearest = index;
        name = candidate;
      }
    }
    if (nearest == -1) {
      var remaining = content.substring(cursor);
      if (streaming) {
        final partial = RegExp(
          r'<[a-z_-]*$',
          caseSensitive: false,
        ).firstMatch(remaining);
        if (partial != null) {
          final fragment = partial.group(0)!.substring(1);
          if (fragment.isNotEmpty &&
              _runtimeNames.any((t) => t.startsWith(fragment))) {
            remaining = remaining.substring(0, partial.start);
            pending = true;
          }
        }
      }
      pushText(remaining);
      break;
    }
    pushText(content.substring(cursor, nearest));
    final open = '<$name>';
    final close = '</$name>';
    final bodyStart = nearest + open.length;
    final closeAt = content.indexOf(close, bodyStart);
    if (closeAt == -1) {
      if (streaming) {
        pending = true;
        break;
      }
      pushText(content.substring(nearest));
      break;
    }
    final body = content.substring(bodyStart, closeAt);
    final piece = _resolve(name, body);
    if (piece != null) {
      pieces.add(piece);
    } else if (name != 'thinking') {
      discarded = true;
    }
    cursor = closeAt + close.length;
  }

  if (pieces.isEmpty && !pending && !discarded) {
    final hadThinkingOnly = content.contains('<thinking>');
    if (!hadThinkingOnly && content.isNotEmpty) {
      pieces.add(ChatTextPiece(content));
    }
  }
  return ParsedSpecialTags(pieces, hasPendingTag: pending);
}

/// The questions of the last complete `<question>` tag of [content]
/// (`parseLastQuestionTag`, `special-tags.tsx:737`), parsed the way the card
/// renders them; used to pair the card with the user turn that answered it.
List<ChatQuestionView>? parseLastQuestionTag(String content) {
  final last = RegExp(
    r'<question>([\s\S]*?)</question>',
  ).allMatches(content).lastOrNull;
  if (last == null) return null;
  final piece = _resolve('question', last.group(1)!);
  return piece is ChatBlockPiece && piece.segment is ChatQuestionSegment
      ? (piece.segment as ChatQuestionSegment).questions
      : null;
}

Object? _json(String body) {
  try {
    return jsonDecode(body.trim());
  } on FormatException {
    return null;
  }
}

String? _string(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

ChatContentPiece? _resolve(String name, String body) {
  switch (name) {
    case 'thinking':
      return null;
    case 'source':
      final data = _json(body);
      if (data is! Map) return null;
      final url = _string(data['url']);
      if (url == null || !RegExp('^https?://').hasMatch(url)) return null;
      return ChatSourcePiece(
        ChatSourceView(
          url: url,
          title: _string(data['title']),
          siteName: _string(data['siteName']),
          connectorType: _string(data['connectorType']),
          snippet: _string(data['snippet']),
        ),
      );
    case 'workspace_resource':
      final data = _json(body);
      if (data is! Map) return null;
      final kind = switch (data['type']) {
        'workflow' => ChatResourceKind.workflow,
        'table' => ChatResourceKind.table,
        'dashboard' => ChatResourceKind.dashboard,
        'file' => ChatResourceKind.file,
        _ => null,
      };
      if (kind == null) return null;
      return ChatResourcePiece(
        ChatResourceView(
          kind: kind,
          id: _string(data['id']),
          path: _string(data['path']),
          title: _string(data['title']),
          workspaceId: _string(data['workspaceId']),
        ),
      );
    case 'options':
      final data = _json(body);
      if (data is! Map || data.isEmpty) return null;
      final options = <ChatOptionView>[];
      for (final value in data.values) {
        if (value is! Map) return null;
        final title = _string(value['title']);
        if (title == null) return null;
        options.add(ChatOptionView(id: title, label: title));
      }
      return ChatBlockPiece(ChatFollowUpsSegment(options: options));
    case 'mothership-error':
      final data = _json(body);
      if (data is! Map) return null;
      final message = _string(data['message']);
      if (message == null) return null;
      return ChatBlockPiece(ChatErrorSegment(message: message));
    case 'question':
      final data = _json(body);
      final raw = data is List ? data : (data is Map ? <Object?>[data] : null);
      if (raw == null) return null;
      final questions = <ChatQuestionView>[];
      for (final item in raw) {
        final question = _question(item);
        if (question != null) questions.add(question);
      }
      if (questions.isEmpty) return null;
      return ChatBlockPiece(ChatQuestionSegment(questions: questions));
    case 'credential':
    case 'usage_upgrade':
      final data = _json(body);
      final raw = data is List ? data : (data is Map ? <Object?>[data] : null);
      if (raw == null) return null;
      final items = <ChatCredentialItemView>[
        for (final item in raw)
          if (item is Map)
            ChatCredentialItemView(
              label:
                  _string(item['name']) ??
                  _string(item['provider']) ??
                  _string(item['message']) ??
                  _string(item['type']) ??
                  'Continue',
            ),
      ];
      if (items.isEmpty) return null;
      return ChatBlockPiece(ChatCredentialSegment(items: items));
  }
  return null;
}

/// Catch-all options the card replaces with its own "Something else" row.
const Set<String> _selfProvidedLabels = <String>{
  'other',
  'something else',
  'other (please specify)',
  'none of the above',
  'custom',
};

ChatQuestionView? _question(Object? value) {
  if (value is! Map) return null;
  final prompt = _string(value['prompt']);
  final type = switch (value['type']) {
    'single_select' => ChatQuestionType.singleSelect,
    'multi_select' => ChatQuestionType.multiSelect,
    _ => null,
  };
  final rawOptions = value['options'];
  if (prompt == null || type == null || rawOptions is! List) return null;
  final options = <ChatOptionView>[
    for (final option in rawOptions)
      if (option is Map &&
          _string(option['label']) != null &&
          !_selfProvidedLabels.contains(
            (option['label'] as String).trim().toLowerCase(),
          ))
        ChatOptionView(
          id: _string(option['id']) ?? option['label'] as String,
          label: option['label'] as String,
        ),
  ];
  if (options.isEmpty) return null;
  return ChatQuestionView(prompt: prompt, options: options, type: type);
}

/// A render group: consecutive text and inline chips merge into one markdown
/// group; block tags become siblings (`chat-content.tsx:718-823`).
@immutable
sealed class ChatRenderGroup {
  const ChatRenderGroup();
}

class ChatInlineGroup extends ChatRenderGroup {
  const ChatInlineGroup({
    required this.markdown,
    this.sources = const <ChatSourceView>[],
    this.resources = const <ChatResourceView>[],
  });

  /// Markdown with sentinel links `#sim-source-ref-N` / `#sim-workspace-ref-N`.
  final String markdown;
  final List<ChatSourceView> sources;
  final List<ChatResourceView> resources;
}

class ChatBlockGroup extends ChatRenderGroup {
  const ChatBlockGroup(this.segment);

  final ChatSegment segment;
}

const String sourceLinkPrefix = '#sim-source-ref-';
const String workspaceLinkPrefix = '#sim-workspace-ref-';

bool _startsInlineWord(String value) =>
    RegExp('^[A-Za-z0-9_(]').hasMatch(value);
bool _endsInlineWord(String value) => RegExp(r'[A-Za-z0-9_)]$').hasMatch(value);

String _escapeLinkLabel(String label) =>
    label.replaceAllMapped(RegExp(r'[\\[\]*_`<>]'), (m) => '\\${m[0]}');

String _nextLabel(ChatContentPiece? piece) => switch (piece) {
  ChatTextPiece(:final text) => text,
  ChatResourcePiece(:final resource) => resource.title ?? resource.id ?? '',
  ChatSourcePiece(:final source) => source.label,
  _ => '',
};

String _appendReference(
  String current,
  String reference,
  ChatContentPiece? next,
) {
  var result = current;
  if (result.isNotEmpty &&
      _endsInlineWord(result) &&
      !RegExp(r'\s$').hasMatch(result)) {
    result += ' ';
  }
  result += reference;
  final following = _nextLabel(next);
  if (following.isNotEmpty &&
      _startsInlineWord(following) &&
      !RegExp(r'^\s').hasMatch(following) &&
      !RegExp(r'\s$').hasMatch(result)) {
    result += ' ';
  }
  return result;
}

/// Folds [pieces] into render groups.
List<ChatRenderGroup> buildRenderGroups(List<ChatContentPiece> pieces) {
  final groups = <ChatRenderGroup>[];
  var markdown = '';
  var sources = <ChatSourceView>[];
  var resources = <ChatResourceView>[];

  void flush() {
    if (markdown.trim().isNotEmpty) {
      groups.add(
        ChatInlineGroup(
          markdown: markdown,
          sources: sources,
          resources: resources,
        ),
      );
    }
    markdown = '';
    sources = <ChatSourceView>[];
    resources = <ChatResourceView>[];
  }

  for (var i = 0; i < pieces.length; i++) {
    final piece = pieces[i];
    final next = i + 1 < pieces.length ? pieces[i + 1] : null;
    switch (piece) {
      case ChatTextPiece(:final text):
        markdown += text;
      case ChatResourcePiece(:final resource):
        final label = resource.title ?? resource.path ?? resource.id ?? '';
        markdown = _appendReference(
          markdown,
          '[${_escapeLinkLabel(label)}](<$workspaceLinkPrefix${resources.length}>)',
          next,
        );
        resources.add(resource);
      case ChatSourcePiece(:final source):
        if (markdown.isNotEmpty && !RegExp(r'\s$').hasMatch(markdown)) {
          markdown += ' ';
        }
        markdown = _appendReference(
          markdown,
          '[${_escapeLinkLabel(source.label)}](<$sourceLinkPrefix${sources.length}>)',
          next,
        );
        sources.add(source);
      case ChatBlockPiece(:final segment):
        flush();
        groups.add(ChatBlockGroup(segment));
    }
  }
  flush();
  return groups;
}

/// Every distinct cited source of [texts], first occurrence wins
/// (`collectMessageSources`).
List<ChatSourceView> collectMessageSources(Iterable<String> texts) {
  final seen = <String>{};
  final result = <ChatSourceView>[];
  for (final text in texts) {
    for (final piece in parseSpecialTags(text, streaming: false).pieces) {
      if (piece is ChatSourcePiece && seen.add(piece.source.url)) {
        result.add(piece.source);
      }
    }
  }
  return result;
}
