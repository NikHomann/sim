import 'dart:convert';

import 'package:sim_app/features/chat/input/model/chat_context.dart';
import 'package:sim_app/features/chat/input/model/chat_tokens.dart';

/// Port of `home/components/user-input/components/chip-clipboard-codec.ts`:
/// portable `[label](sim:kind/id)` links for chips on copy, parsed back into
/// chips on paste.

/// `PORTABLE_KIND_TO_ID_FIELD`.
const Map<ChatContextKind, String> portableKindIdField = {
  ChatContextKind.table: 'tableId',
  ChatContextKind.file: 'fileId',
  ChatContextKind.dashboard: 'dashboardId',
  ChatContextKind.folder: 'folderId',
  ChatContextKind.filefolder: 'fileFolderId',
  ChatContextKind.workspace: 'workspaceId',
  ChatContextKind.knowledge: 'knowledgeId',
  ChatContextKind.pastChat: 'chatId',
  ChatContextKind.workflow: 'workflowId',
  ChatContextKind.logs: 'executionId',
  ChatContextKind.skill: 'skillId',
  ChatContextKind.mcp: 'serverId',
  ChatContextKind.integration: 'blockType',
  ChatContextKind.slashCommand: 'command',
};

const String _ownerParam = '?workspace=';

final RegExp _chipLinkPattern = RegExp(
  r'\[((?:\\.|[^\]\\])+)\]\(sim:([a-z_]+)\/([^)\s]+)\)',
);

/// `serializePortableChipLink`.
String serializePortableChipLink(
  ChatContextKind kind,
  String id,
  String label, {
  String? workspaceId,
}) {
  final escaped = label.replaceAllMapped(
    RegExp(r'[\\\[\]]'),
    (m) => '\\${m[0]}',
  );
  final owner = workspaceId == null || workspaceId.isEmpty
      ? ''
      : '$_ownerParam${Uri.encodeComponent(workspaceId)}';
  return '[$escaped](sim:${kind.wire}/$id$owner)';
}

String? _serializeChipContext(ChatContext context) {
  final field = portableKindIdField[context.kind];
  if (field == null) return null;
  final id = context.field(field);
  if (id == null || id.isEmpty) return null;
  return serializePortableChipLink(
    context.kind,
    id,
    context.label,
    workspaceId: context.kind.isWorkspaceOwned ? context.workspaceId : null,
  );
}

/// `chipDisplayToken`: the per-kind token re-created on paste.
String chipDisplayToken(ChatContext context) =>
    contextToken(context) ?? '@${context.label}';

ChatContext? _contextForToken(String token, List<ChatContext> contexts) {
  final label = stripMentionTrigger(token);
  for (final c in contexts) {
    if (c.label == label) return c;
  }
  return null;
}

/// `serializeSelectionForClipboard`: every portable chip becomes a link;
/// everything else has skill sentinels restored to `/`. Byte-identical to
/// the input when there is nothing to convert.
String serializeSelectionForClipboard(
  String selectedText,
  List<ChatContext> contexts,
) {
  final ranges = computeMentionHighlightRanges(
    selectedText,
    extractContextTokens(contexts),
  );
  if (ranges.isEmpty) return restoreSkillTriggerText(selectedText);
  final out = StringBuffer();
  var last = 0;
  for (final range in ranges) {
    if (range.start > last) {
      out.write(
        restoreSkillTriggerText(selectedText.substring(last, range.start)),
      );
    }
    final matched = _contextForToken(range.token, contexts);
    final serialized = matched == null ? null : _serializeChipContext(matched);
    out.write(serialized ?? restoreSkillTriggerText(range.token));
    last = range.end;
  }
  if (last < selectedText.length) {
    out.write(restoreSkillTriggerText(selectedText.substring(last)));
  }
  return out.toString();
}

/// `selectionContextsInText`: `file_selection` / `table_selection` chips in
/// the text (those travel through the custom clipboard MIME instead).
List<ChatContext> selectionContextsInText(
  String selectedText,
  List<ChatContext> contexts,
) {
  final found = <ChatContext>[];
  for (final range in computeMentionHighlightRanges(
    selectedText,
    extractContextTokens(contexts),
  )) {
    final matched = _contextForToken(range.token, contexts);
    if (matched != null &&
        (matched.kind == ChatContextKind.fileSelection ||
            matched.kind == ChatContextKind.tableSelection)) {
      found.add(matched);
    }
  }
  return found;
}

/// A parsed portable link with its source span.
class ParsedChipLink {
  const ParsedChipLink({
    required this.kind,
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    this.workspaceId,
  });

  final ChatContextKind kind;
  final String id;
  final String label;
  final String? workspaceId;
  final int start;
  final int end;
}

/// `parseChipLinks`: links of portable kinds in source order.
List<ParsedChipLink> parseChipLinks(String text) {
  final links = <ParsedChipLink>[];
  for (final match in _chipLinkPattern.allMatches(text)) {
    final kind = ChatContextKind.fromWire(match.group(2));
    if (kind == null || !portableKindIdField.containsKey(kind)) continue;
    final address = match.group(3)!;
    final ownerAt = address.lastIndexOf(_ownerParam);
    String? owner;
    if (ownerAt != -1) {
      try {
        owner = Uri.decodeComponent(
          address.substring(ownerAt + _ownerParam.length),
        );
      } on FormatException {
        continue;
      }
    }
    links.add(
      ParsedChipLink(
        kind: kind,
        id: ownerAt == -1 ? address : address.substring(0, ownerAt),
        label: match
            .group(1)!
            .replaceAllMapped(
              RegExp(r'\\([\\\[\]])'),
              (m) => m[1]!,
            ),
        workspaceId: owner == null || owner.isEmpty ? null : owner,
        start: match.start,
        end: match.end,
      ),
    );
  }
  return links;
}

/// `chipLinkToContext`.
ChatContext chipLinkToContext(ParsedChipLink link) {
  final context = ChatContext(
    kind: link.kind,
    label: link.label,
    fields: {portableKindIdField[link.kind]!: link.id},
  );
  final owner = link.workspaceId;
  return owner != null && link.kind.isWorkspaceOwned
      ? context.withWorkspace(owner)
      : context;
}

/// The paste-back rewrite of `handlePaste` (`use-prompt-editor.ts:1199-1228`):
/// each link becomes its kind-correct token; a run of plain spaces between
/// two chips collapses to one; a separator is appended only when the next
/// source character is not whitespace. `null` when [pasted] has no link.
({String text, List<ChatContext> contexts})? rewritePastedChipLinks(
  String pasted,
) {
  final links = parseChipLinks(pasted);
  if (links.isEmpty) return null;
  final contexts = <ChatContext>[];
  final out = StringBuffer();
  var cursor = 0;
  for (var i = 0; i < links.length; i++) {
    final link = links[i];
    var between = pasted.substring(cursor, link.start);
    if (i > 0 && RegExp(r'^ +$').hasMatch(between)) between = ' ';
    out.write(between);
    final ctx = chipLinkToContext(link);
    contexts.add(ctx);
    final next = link.end < pasted.length ? pasted[link.end] : '';
    final token = chipDisplayToken(ctx);
    out.write(RegExp(r'\S').hasMatch(next) ? '$token ' : token);
    cursor = link.end;
  }
  out.write(pasted.substring(cursor));
  return (text: out.toString(), contexts: contexts);
}

const int _selectionClipboardVersion = 1;

/// `attachSelectionContextToClipboard`: the `text/x-sim-selection` payload.
String encodeSelectionClipboard(ChatContext context, String workspaceId) =>
    jsonEncode(<String, Object?>{
      'version': _selectionClipboardVersion,
      'sourceWorkspaceId': workspaceId,
      'context': context.toJson(),
    });

/// `readSelectionContextFromClipboard`: a selection chip copied in the same
/// workspace with its resolving fields, else `null` (plain-text paste).
ChatContext? decodeSelectionClipboard(String? raw, String workspaceId) {
  if (raw == null || raw.isEmpty) return null;
  Object? envelope;
  try {
    envelope = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (envelope is! Map ||
      envelope['version'] != _selectionClipboardVersion ||
      envelope['sourceWorkspaceId'] != workspaceId) {
    return null;
  }
  final context = ChatContext.fromJson(envelope['context']);
  if (context == null) return null;
  final f = context.fields;
  if (context.kind == ChatContextKind.fileSelection &&
      f['text'] is String &&
      f['fileName'] is String &&
      (context.field('fileId')?.isNotEmpty ?? false)) {
    return context;
  }
  final rows = f['rowIds'];
  if (context.kind == ChatContextKind.tableSelection &&
      (context.field('tableId')?.isNotEmpty ?? false) &&
      f['tableName'] is String &&
      rows is List &&
      rows.isNotEmpty) {
    return context;
  }
  return null;
}
