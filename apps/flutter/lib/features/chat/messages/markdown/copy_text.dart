import 'package:sim_app/features/chat/messages/markdown/chat_sanitize.dart';
import 'package:sim_app/features/chat/messages/markdown/special_tags.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';

/// Port of `toCopyableMarkdown` (`copyable-markdown.ts`): the copied text of
/// an assistant message keeps its prose, turns workspace-resource chips into
/// portable `[label](sim:kind/id)` links (`serializePortableChipLink`), and
/// drops sources, thinking and block tags.
///
/// File chips resolve by id only; upstream additionally resolves a path
/// against the workspace file list.
String prepareCopyText(String raw) {
  final pieces = parseSpecialTags(
    sanitizeChatDisplayContent(raw),
    streaming: false,
  ).pieces;
  var markdown = '';
  for (var i = 0; i < pieces.length; i++) {
    final piece = pieces[i];
    if (piece is ChatTextPiece) {
      markdown += piece.text;
    } else if (piece is ChatResourcePiece) {
      final next = i + 1 < pieces.length ? pieces[i + 1] : null;
      final reference = _portable(piece.resource);
      final following = switch (next) {
        ChatTextPiece(:final text) => text,
        ChatResourcePiece(:final resource) =>
          resource.title ?? resource.id ?? '',
        _ => '',
      };
      final leading = RegExp(r'[A-Za-z0-9_)]$').hasMatch(markdown) ? ' ' : '';
      final trailing =
          RegExp('^[A-Za-z0-9_(]').hasMatch(following) &&
              !RegExp(r'\s$').hasMatch(reference)
          ? ' '
          : '';
      markdown = '$markdown$leading$reference$trailing';
    }
  }
  return markdown.trim();
}

String _portable(ChatResourceView resource) {
  final label =
      resource.title ??
      (resource.kind == ChatResourceKind.file
          ? resource.path ?? resource.id ?? ''
          : resource.id ?? '');
  final id = resource.id;
  if (id == null) return label;
  final escaped = label.replaceAllMapped(
    RegExp(r'[\\[\]]'),
    (m) => '\\${m[0]}',
  );
  final owner = resource.workspaceId == null
      ? ''
      : '?workspace=${Uri.encodeComponent(resource.workspaceId!)}';
  return '[$escaped](sim:${resource.kind.name}/$id$owner)';
}

/// `getOrchestratorMessageText`: the message's own text segments joined
/// (agent-lane narration is excluded), ready to copy.
String messageCopyText(ChatAssistantMessageView message) {
  if (message.copyText != null) return message.copyText!;
  final raw = message.segments
      .whereType<ChatTextSegment>()
      .map((s) => s.content)
      .join('\n\n');
  return prepareCopyText(raw);
}
