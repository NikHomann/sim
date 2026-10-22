/// Inline special tags inside assistant text (spec chat-engine §4.1, data
/// contract of `message-content/components/special-tags/special-tags.tsx`):
/// `thinking, options, usage_upgrade, credential, mothership-error,
/// workspace_resource, question, source` and the runtime `file` tag.
///
/// The engine only splits text into plain and tag segments and decodes the
/// payloads it owns (`<mothership-error>` JSON, `<options>` items); how each
/// tag looks is the renderer's concern.
library;

import 'dart:convert';

import 'package:equatable/equatable.dart';

/// The tag names the React parser recognises.
const specialTagNames = [
  'thinking',
  'options',
  'usage_upgrade',
  'credential',
  'mothership-error',
  'workspace_resource',
  'question',
  'source',
  'file',
];

sealed class TextSegment extends Equatable {
  const TextSegment();
}

class PlainTextSegment extends TextSegment {
  const PlainTextSegment(this.text);
  final String text;

  @override
  List<Object?> get props => [text];
}

/// A `<name attrs>body</name>` tag. [complete] is false while the closing
/// tag has not streamed in yet (the renderer shows a pending state).
class SpecialTagSegment extends TextSegment {
  const SpecialTagSegment({
    required this.name,
    required this.body,
    this.attributes = const {},
    this.complete = true,
  });

  final String name;
  final String body;
  final Map<String, String> attributes;
  final bool complete;

  /// The decoded JSON body, or `null` when it is not JSON.
  Object? get json {
    try {
      return jsonDecode(body.trim());
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get props => [name, body, attributes, complete];
}

final _open = RegExp(
  '<(${specialTagNames.map(RegExp.escape).join('|')})((?:\\s+[\\w-]+="[^"]*")*)\\s*(/?)>',
);
final _attr = RegExp(r'([\w-]+)="([^"]*)"');

/// Splits [text] into plain and special-tag segments. Tags do not nest
/// (React parses them flat); an unclosed tag at the end is an incomplete
/// segment holding the rest of the text.
List<TextSegment> parseSpecialTags(String text) {
  final segments = <TextSegment>[];
  var index = 0;
  while (index < text.length) {
    final match = _open.firstMatch(text.substring(index));
    if (match == null) {
      segments.add(PlainTextSegment(text.substring(index)));
      break;
    }
    final start = index + match.start;
    if (start > index) {
      segments.add(PlainTextSegment(text.substring(index, start)));
    }
    final name = match.group(1)!;
    final attributes = {
      for (final a in _attr.allMatches(match.group(2) ?? ''))
        a.group(1)!: a.group(2)!,
    };
    final bodyStart = index + match.end;
    if (match.group(3) == '/') {
      segments.add(
        SpecialTagSegment(name: name, body: '', attributes: attributes),
      );
      index = bodyStart;
      continue;
    }
    final close = text.indexOf('</$name>', bodyStart);
    if (close == -1) {
      segments.add(
        SpecialTagSegment(
          name: name,
          body: text.substring(bodyStart),
          attributes: attributes,
          complete: false,
        ),
      );
      break;
    }
    segments.add(
      SpecialTagSegment(
        name: name,
        body: text.substring(bodyStart, close),
        attributes: attributes,
      ),
    );
    index = close + name.length + 3;
  }
  return segments;
}

/// The `<mothership-error>` payload `{message, code?, provider?}`.
typedef MothershipErrorTag = ({String message, String? code, String? provider});

/// Decodes a `mothership-error` segment.
MothershipErrorTag? decodeMothershipErrorTag(SpecialTagSegment segment) {
  if (segment.name != 'mothership-error') return null;
  final json = segment.json;
  if (json is! Map || json['message'] is! String) return null;
  return (
    message: json['message']! as String,
    code: json['code'] is String ? json['code']! as String : null,
    provider: json['provider'] is String ? json['provider']! as String : null,
  );
}

/// One `<options>` entry: `OptionsItemData {title, description}`.
typedef OptionsTagItem = ({String key, String title, String description});

/// Decodes an `<options>` body, `OptionsTagData = Record<string,
/// {title, description}>` (an array is read by index). Entries of another
/// shape are dropped. Selecting one submits its key as the next user
/// message (`mothership-chat.tsx:770-772`), only on the last row.
List<OptionsTagItem> decodeOptionsTag(SpecialTagSegment segment) {
  final json = segment.json;
  final entries = json is Map
      ? json.entries.map((e) => MapEntry('${e.key}', e.value))
      : json is List
      ? json.asMap().entries.map((e) => MapEntry('${e.key}', e.value))
      : const <MapEntry<String, Object?>>[];
  return [
    for (final entry in entries)
      if (entry.value case {
        'title': final String title,
        'description': final String description,
      })
        (key: entry.key, title: title, description: description),
  ];
}
