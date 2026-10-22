/// Query keys and stale times of the mothership chats
/// (`hooks/queries/mothership-chats.ts:110-193`, spec chat-engine §3.6).
library;

import 'package:sim_api/sim_api.dart';

abstract final class MothershipChatKeys {
  static const QueryKey all = ['mothership-chats'];
  static QueryKey lists() => [...all, 'list'];

  /// Both scopes of one workspace (`workspaceLists` = `ownerLists(ws)`).
  static QueryKey workspaceLists(String? workspaceId) => [
    ...lists(),
    workspaceId ?? '',
  ];
  static QueryKey list(String? workspaceId, [String scope = 'active']) => [
    ...workspaceLists(workspaceId),
    scope,
  ];
  static QueryKey details() => [...all, 'detail'];
  static QueryKey detail(String? chatId) => [...details(), chatId ?? ''];
  static QueryKey olderMessages(String chatId, String cursor) => [
    ...all,
    'older-messages',
    chatId,
    cursor,
  ];
}

/// `MOTHERSHIP_CHAT_LIST_STALE_TIME`.
const mothershipChatListStaleTime = Duration(seconds: 60);

/// `MOTHERSHIP_CHAT_HISTORY_STALE_TIME`.
const mothershipChatHistoryStaleTime = Duration(seconds: 30);

/// `/workspace/<id>/chat/<chatId>`, keeping only the `resource` query param
/// of the current location (`home/hooks/chat-url.ts`).
String chatUrl(String workspaceId, String chatId, {String? resource}) {
  final path = '/workspace/$workspaceId/chat/$chatId';
  return resource == null
      ? path
      : '$path?resource=${Uri.encodeQueryComponent(resource)}';
}
