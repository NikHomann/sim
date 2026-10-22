import 'package:equatable/equatable.dart';
import 'package:sim_app/features/chat/engine/chat_message.dart';
import 'package:sim_app/features/chat/engine/stores/queue_store.dart';

/// Loading state of the chat transcript (`useChat`'s history read).
enum ChatHistoryStatus { none, loading, ready, error }

/// "Failed to load chat history. Refresh to try again." (`U:5427-5428`).
const chatHistoryErrorMessage =
    'Failed to load chat history. Refresh to try again.';

/// `RECONNECT_TAIL_ERROR`.
const reconnectTailError =
    'Live reconnect failed before the stream finished. The latest response may be incomplete.';

/// What one chat surface shows (spec chat-engine §4.5): the transcript with
/// the live turn spliced in, the transport flags, the hook's `error` and the
/// queue of this surface.
class ChatSessionState extends Equatable {
  const ChatSessionState({
    required this.workspaceId,
    this.chatId,
    this.title,
    this.historyStatus = ChatHistoryStatus.none,
    this.messages = const [],
    this.isSending = false,
    this.isReconnecting = false,
    this.error,
    this.queue = const [],
    this.editingQueuedId,
    this.dispatchingHeadId,
    this.streamId,
    this.olderCursor,
  });

  final String workspaceId;

  /// The resolved chat; `null` on a new-chat surface before admission.
  final String? chatId;
  final String? title;
  final ChatHistoryStatus historyStatus;

  /// Persisted messages (or the pending pair before a chat id) with the
  /// optimistic user message and the live assistant appended.
  final List<ChatMessage> messages;

  /// Drives the Stop button.
  final bool isSending;

  /// Drives the reconnect indicator.
  final bool isReconnecting;

  /// The hook's `error`. React's workspace Home does not render it (spec
  /// §3.10, ambiguity 3); the organization home toasts it.
  final String? error;
  final List<QueuedMessage> queue;
  final String? editingQueuedId;
  final String? dispatchingHeadId;

  /// The stream being read (`streamIdRef`).
  final String? streamId;
  final String? olderCursor;

  ChatSessionState copyWith({
    String? chatId,
    String? title,
    ChatHistoryStatus? historyStatus,
    List<ChatMessage>? messages,
    bool? isSending,
    bool? isReconnecting,
    String? error,
    bool clearError = false,
    List<QueuedMessage>? queue,
    String? editingQueuedId,
    bool clearEditing = false,
    String? dispatchingHeadId,
    bool clearDispatching = false,
    String? streamId,
    bool clearStreamId = false,
    String? olderCursor,
  }) => ChatSessionState(
    workspaceId: workspaceId,
    chatId: chatId ?? this.chatId,
    title: title ?? this.title,
    historyStatus: historyStatus ?? this.historyStatus,
    messages: messages ?? this.messages,
    isSending: isSending ?? this.isSending,
    isReconnecting: isReconnecting ?? this.isReconnecting,
    error: clearError ? null : (error ?? this.error),
    queue: queue ?? this.queue,
    editingQueuedId: clearEditing
        ? null
        : (editingQueuedId ?? this.editingQueuedId),
    dispatchingHeadId: clearDispatching
        ? null
        : (dispatchingHeadId ?? this.dispatchingHeadId),
    streamId: clearStreamId ? null : (streamId ?? this.streamId),
    olderCursor: olderCursor ?? this.olderCursor,
  );

  @override
  List<Object?> get props => [
    workspaceId,
    chatId,
    title,
    historyStatus,
    messages,
    isSending,
    isReconnecting,
    error,
    queue,
    editingQueuedId,
    dispatchingHeadId,
    streamId,
    olderCursor,
  ];
}
