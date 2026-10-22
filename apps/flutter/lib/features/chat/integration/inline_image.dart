/// Inline chat images, port of `lib/mothership/chat/inline-image-reference.ts`
/// and the `privateImageUrls` rehype pass (`chat-content.tsx:539-557`): an
/// `<img>` whose source is a first-party file reference loads the chat's
/// private image snapshot route; any other source is left alone.
library;

final RegExp _controlCharacters = RegExp('[\u0000-\u001f\u007f]');
final RegExp _workspaceFileId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// `isInlineFileReference`: first-party file namespaces, not arbitrary URLs
/// or host filesystem paths.
bool isInlineFileReference(String reference) {
  if (reference.isEmpty ||
      reference.length > 2048 ||
      _controlCharacters.hasMatch(reference)) {
    return false;
  }
  try {
    Uri.encodeFull(reference);
  } on Object {
    return false;
  }
  return reference.startsWith('files/') ||
      reference.startsWith('uploads/') ||
      reference.startsWith('/tmp/') ||
      reference.startsWith('/home/user/') ||
      (reference.startsWith('wf_') && _workspaceFileId.hasMatch(reference)) ||
      _uuid.hasMatch(reference);
}

/// `normalizeInlineFileReference`: CommonMark's URI encoding without
/// decoding a literal percent sign twice (`encodeURI`, then `%25XX` →
/// `%XX`), so a raw and an already-encoded reference normalize alike.
String normalizeInlineFileReference(String reference) =>
    Uri.encodeFull(reference).replaceAllMapped(
      RegExp('%25([0-9a-f]{2})', caseSensitive: false),
      (m) => '%${m[1]!.toUpperCase()}',
    );

/// `inlineChatImageUrl`: the private snapshot the turn [requestId] published.
String inlineChatImageUrl(String chatId, String requestId, String reference) =>
    '/api/mothership/chats/${Uri.encodeComponent(chatId)}/images/'
    '${Uri.encodeComponent(requestId)}'
    '?path=${Uri.encodeComponent(normalizeInlineFileReference(reference))}';

/// `privateImageUrls` for one image source: an inline reference resolves to
/// the chat image route, or is dropped (`''` upstream, null here: the image
/// hides) while the chat or the turn's request id is unknown; any other
/// source is returned unchanged.
String? resolveChatImageUrl(
  String src, {
  required String? chatId,
  required String? requestId,
}) {
  if (!isInlineFileReference(src)) return src;
  if (chatId == null ||
      chatId.isEmpty ||
      requestId == null ||
      requestId.isEmpty) {
    return null;
  }
  return inlineChatImageUrl(chatId, requestId, src);
}
