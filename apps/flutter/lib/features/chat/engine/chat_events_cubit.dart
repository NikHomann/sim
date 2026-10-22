/// The workspace chat-status SSE, port of `hooks/use-mothership-chat-events.ts`
/// (spec chat-engine §3.9).
///
/// One cubit per workspace, mounted with the sidebar while Chat is enabled
/// and not hidden by the permission config. It keeps
/// `/api/mothership/events?workspaceId=` open through [RotatingEventSource]
/// and turns every `task_status` frame into the React cache effects:
/// - every event invalidates the workspace chat lists;
/// - `deleted`: the chat's detail is removed and its queue cleared and
///   blocked;
/// - `created` (also a restore): the queue block is lifted;
/// - `renamed`: the detail is marked stale without a refetch;
/// - `started`/`completed`: the detail is invalidated unless the cached
///   live stream makes that wrong (`shouldSkipDetailInvalidationForStreamEvent`);
///   a `completed` of the cached live stream only marks it stale.
/// A reconnect, or the first open after an earlier subscription of the same
/// workspace in this process, re-syncs the lists.
///
/// Sidebar seam (not wired here; the sidebar is another agent's): the
/// sidebar's `HttpChatsSource` should refetch its list on every
/// [ChatEventsState.listGeneration] change (that is the owner-list
/// invalidation React performs) and may read [ChatEventsState.runningChatIds]
/// for the running dot before the refetch lands. Unread dots stay derived
/// from the list rows (`mapChat`), as in React.
library;

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/chat_message.dart';
import 'package:sim_app/features/chat/engine/chat_query_keys.dart';
import 'package:sim_app/features/chat/engine/stores/queue_store.dart';

class ChatEventsState extends Equatable {
  const ChatEventsState({
    this.connected = false,
    this.listGeneration = 0,
    this.runningChatIds = const {},
    this.lastEvent,
  });

  /// A connection is open.
  final bool connected;

  /// Bumped on every owner-list invalidation.
  final int listGeneration;

  /// Chats whose last status event was `started`.
  final Set<String> runningChatIds;
  final TaskStatusEvent? lastEvent;

  ChatEventsState copyWith({
    bool? connected,
    int? listGeneration,
    Set<String>? runningChatIds,
    TaskStatusEvent? lastEvent,
  }) => ChatEventsState(
    connected: connected ?? this.connected,
    listGeneration: listGeneration ?? this.listGeneration,
    runningChatIds: runningChatIds ?? this.runningChatIds,
    lastEvent: lastEvent ?? this.lastEvent,
  );

  @override
  List<Object?> get props => [
    connected,
    listGeneration,
    runningChatIds,
    lastEvent,
  ];
}

class ChatEventsCubit extends Cubit<ChatEventsState> {
  ChatEventsCubit({
    required MothershipClient client,
    required QueryClient queryClient,
    required MothershipQueueStore queueStore,
    required this.workspaceId,
    this.chatEnabled = true,
    RotatingEventSource? source,
  }) : _queries = queryClient,
       _queue = queueStore,
       _source = source ?? client.chatEvents(workspaceId: workspaceId),
       super(const ChatEventsState());

  /// Owner scopes this process subscribed to (`everSubscribed`).
  static final Set<String> _everSubscribed = {};

  /// Forgets the subscriptions (tests, sign-out).
  static void resetSubscriptionHistory() => _everSubscribed.clear();

  final String workspaceId;

  /// `chatEnabled && !permissionConfig.hideCopilot`.
  final bool chatEnabled;
  final QueryClient _queries;
  final MothershipQueueStore _queue;
  final RotatingEventSource _source;
  final _events = StreamController<TaskStatusEvent>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _started = false;

  /// Parsed `task_status` events, after their cache effects ran.
  Stream<TaskStatusEvent> get events => _events.stream;

  /// Opens the connection (no-op when Chat is disabled or already open).
  void start() {
    if (_started || !chatEnabled || isClosed) return;
    _started = true;
    final ownerParam = 'workspaceId=$workspaceId';
    final isResubscribe = !_everSubscribed.add(ownerParam);
    _subscriptions
      ..add(
        _source.opens.listen((reason) {
          if (isClosed) return;
          emit(state.copyWith(connected: true));
          if (reason == EventSourceOpenReason.reconnect ||
              (reason == EventSourceOpenReason.initial && isResubscribe)) {
            _invalidateLists();
          }
        }),
      )
      ..add(
        _source.events.listen((event) {
          if (event.name == 'task_status') handleTaskStatus(event.json);
        }),
      )
      ..add(
        _source.errors.listen((_) {
          if (!isClosed) emit(state.copyWith(connected: false));
        }),
      );
    _source.start();
  }

  void _invalidateLists() {
    unawaited(
      _queries.invalidateQueries(
        MothershipChatKeys.workspaceLists(workspaceId),
      ),
    );
    if (!isClosed) {
      emit(state.copyWith(listGeneration: state.listGeneration + 1));
    }
  }

  /// `handleMothershipChatStatusEvent`.
  void handleTaskStatus(Object? data) {
    final event = TaskStatusEvent.parse(data);
    if (event == null || isClosed) return;
    _invalidateLists();
    final chatId = event.chatId;
    if (chatId == null) {
      _events.add(event);
      return;
    }
    final running = {...state.runningChatIds};
    switch (event.type) {
      case TaskStatusType.started:
        running.add(chatId);
      case TaskStatusType.completed || TaskStatusType.deleted:
        running.remove(chatId);
      case _:
        break;
    }
    emit(state.copyWith(runningChatIds: running, lastEvent: event));
    final detail = MothershipChatKeys.detail(chatId);
    switch (event.type) {
      case TaskStatusType.deleted:
        _queries.removeQueries(detail);
        _queue.clearChat(chatId);
      case TaskStatusType.created:
        _queue.reopenRestoredChat(chatId);
      case TaskStatusType.renamed:
        unawaited(_queries.invalidateQueries(detail, refetchActive: false));
      case TaskStatusType.started || TaskStatusType.completed:
        final current = _queries.getQueryData<MothershipChatHistory>(detail);
        if (!shouldSkipDetailInvalidation(current, event)) {
          final completesCachedLive =
              event.type == TaskStatusType.completed &&
              current?.activeStreamId == event.streamId &&
              _isLocalOptimisticActiveStream(current);
          unawaited(
            _queries.invalidateQueries(
              detail,
              refetchActive: !completesCachedLive,
            ),
          );
        }
      case TaskStatusType.updated || null:
        break;
    }
    _events.add(event);
  }

  static bool _isLocalOptimisticActiveStream(MothershipChatHistory? current) {
    final active = current?.activeStreamId;
    if (active == null) return false;
    final liveId = liveAssistantMessageId(active);
    return current!.messages.any((m) => m.id == liveId);
  }

  static bool _hasNewerKnownActiveStream(
    MothershipChatHistory? current,
    String streamId,
  ) {
    final active = current?.activeStreamId;
    if (active == null || active == streamId) return false;
    final activeIndex = current!.messages.indexWhere((m) => m.id == active);
    final eventIndex = current.messages.indexWhere((m) => m.id == streamId);
    if (activeIndex == -1 || eventIndex == -1) return false;
    return activeIndex > eventIndex;
  }

  /// `shouldSkipDetailInvalidationForStreamEvent` (`:70-84`).
  static bool shouldSkipDetailInvalidation(
    MothershipChatHistory? current,
    TaskStatusEvent event,
  ) {
    final active = current?.activeStreamId;
    if (active == null) return false;
    final streamId = event.streamId;
    if (streamId == null) return _isLocalOptimisticActiveStream(current);
    if (event.type == TaskStatusType.started && active == streamId) return true;
    if (active == streamId) return false;
    if (_hasNewerKnownActiveStream(current, streamId)) return true;
    return event.type == TaskStatusType.completed &&
        _isLocalOptimisticActiveStream(current) &&
        !current!.messages.any((m) => m.id == streamId);
  }

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _source.close();
    await _events.close();
    return super.close();
  }
}
