import 'package:flutter/foundation.dart';

/// One sidebar chat row, mapped like `mothership-chats.ts:301-315`:
/// `name = title ?? 'New chat'`, `isActive = activeStreamId != null`,
/// `isUnread = activeStreamId == null && (lastSeenAt == null || updatedAt >
/// lastSeenAt)`.
@immutable
class SidebarChat {
  const SidebarChat({
    required this.id,
    required this.name,
    this.isActive = false,
    this.isUnread = false,
    this.isPinned = false,
  });

  final String id;
  final String name;
  final bool isActive;
  final bool isUnread;
  final bool isPinned;
}

/// The chat list behind the "Chats" section and its actions
/// (`useMothershipChats` + the chat mutations). No chats cubit exists in the
/// Phase 1 data layer, so the default source is empty; the Phase 4 chat
/// layer implements this.
abstract class SidebarChatsSource {
  const SidebarChatsSource();

  /// `null` while the first load is pending.
  ValueListenable<List<SidebarChat>?> chats(String workspaceId);

  Future<void> rename(String chatId, String title);
  Future<void> setPinned(String chatId, {required bool pinned});
  Future<void> markRead(String chatId);
  Future<void> markUnread(String chatId);
  Future<void> delete(List<String> chatIds);
}

/// No chats data in Phase 1: an empty, loaded list.
class EmptyChatsSource extends SidebarChatsSource {
  const EmptyChatsSource();

  static final ValueNotifier<List<SidebarChat>?> _empty =
      ValueNotifier<List<SidebarChat>?>(const <SidebarChat>[]);

  @override
  ValueListenable<List<SidebarChat>?> chats(String workspaceId) => _empty;

  @override
  Future<void> rename(String chatId, String title) async {}

  @override
  Future<void> setPinned(String chatId, {required bool pinned}) async {}

  @override
  Future<void> markRead(String chatId) async {}

  @override
  Future<void> markUnread(String chatId) async {}

  @override
  Future<void> delete(List<String> chatIds) async {}
}
