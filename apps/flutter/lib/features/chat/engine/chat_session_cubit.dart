/// The chat state machine of one chat surface, port of `useChat`
/// (`app/workspace/[workspaceId]/home/hooks/use-chat.ts`, spec chat-engine
/// §4): optimistic send, chat creation and route change, the stream loop
/// with the React-strict envelope validation and cursor dedupe, finalize,
/// reconnect with retries and backoff, browser-return recovery, Stop,
/// switching chats mid-stream, the per-chat queue and its drain, and the
/// 45 s idle timeout.
///
/// Out of scope here (spec ambiguity 6, 11): client-executed tools are
/// flagged `unsupportedOnClient` and left running for the server to time
/// out; resource and file-preview events are forwarded on
/// [ChatSessionCubit.resourceEvents] for the resources panel.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/chat_message.dart';
import 'package:sim_app/features/chat/engine/chat_query_keys.dart';
import 'package:sim_app/features/chat/engine/chat_session_state.dart';
import 'package:sim_app/features/chat/engine/display_message.dart';
import 'package:sim_app/features/chat/engine/platform/browser_signals.dart';
import 'package:sim_app/features/chat/engine/stores/effort_store.dart';
import 'package:sim_app/features/chat/engine/stores/handoff_store.dart';
import 'package:sim_app/features/chat/engine/stores/queue_store.dart';
import 'package:sim_app/features/chat/engine/stores/send_queue_policy.dart';
import 'package:sim_app/features/chat/engine/turn_model.dart';

/// Timing constants of `use-chat.ts:335-354`.
abstract final class ChatTimings {
  static const idleTimeout = Duration(seconds: 45);
  static const maxReconnectAttempts = 10;
  static const reconnectBaseDelay = Duration(seconds: 1);
  static const reconnectMaxDelay = Duration(seconds: 30);
  static const reconnectExhaustedRecheck = Duration(seconds: 30);
  static const chatIdResolveTimeout = Duration(seconds: 10);
  static const historyRecoveryTimeout = Duration(seconds: 10);
  static const persistedTurnRefetchBase = Duration(milliseconds: 250);
  static const persistedTurnRefetchMax = Duration(seconds: 5);
  static const persistedTurnWait = Duration(seconds: 120);
  static const stopRequestTimeout = Duration(seconds: 15);
  static const textFlushInterval = Duration(milliseconds: 50);
  static const emptyBatchPause = Duration(seconds: 1);
}

/// Callbacks the surface wires (route change, title, end of turn, ...).
class ChatSessionCallbacks {
  const ChatSessionCallbacks({
    this.onChatResolved,
    this.onTitleUpdate,
    this.onStreamEnd,
    this.onToolResult,
    this.onRequestStarted,
  });

  /// A new chat got its id: replace the location with the url
  /// (`history.replaceState`, no router navigation).
  final void Function(String chatId, String url)? onChatResolved;
  final void Function()? onTitleUpdate;
  final void Function(String chatId, List<ChatMessage> messages)? onStreamEnd;
  final void Function(ToolResultPayload result)? onToolResult;
  final void Function(String requestId, String userMessageId)? onRequestStarted;
}

/// A `resource` or file-preview envelope for the resources panel.
class ChatResourceEvent {
  const ChatResourceEvent({required this.payload, required this.replay});
  final MothershipPayload payload;

  /// Replayed after a reconnect: React skips tab promotion and preview
  /// cleanup for these.
  final bool replay;
}

/// How a send ended when it did not go out.
class SendWithdrawal {
  const SendWithdrawal({
    required this.userMessageId,
    required this.reason,
    required this.admissionUnknown,
  });
  final String userMessageId;
  final WithdrawalReason reason;
  final bool admissionUnknown;
}

/// Stop modes (`StopGenerationOptions.mode`).
enum StopMode { normal, queuedHandoff }

class _Aborted implements Exception {
  const _Aborted(this.reason);
  final Object? reason;
}

class _Abort {
  final MothershipCancelToken token = MothershipCancelToken();
  String? reason;

  /// Sleeps woken by [abort]; each removes itself when it ends on its own.
  final Set<void Function()> waiters = {};
  bool get aborted => token.isCancelled;

  void abort(String why) {
    if (aborted) return;
    reason = why;
    token.cancel(why);
    final woken = waiters.toList();
    waiters.clear();
    for (final wake in woken) {
      wake();
    }
  }
}

class _Reader {
  StreamSubscription<SseFrame>? subscription;
  final Completer<void> done = Completer<void>();

  void cancel() {
    unawaited(subscription?.cancel());
    if (!done.isCompleted) done.complete();
  }
}

class _Loop {
  _Loop({required this.gen, this.targetChatId, this.deferFlushes = false});

  /// The stream generation that owns this loop: once it moved on, the loop
  /// writes nothing (no flush, no terminal marking).
  final int gen;
  final String? targetChatId;
  final bool deferFlushes;
  bool sawComplete = false;
  bool sawStreamError = false;
  String? completionStatus;
}

class _Turn {
  _Turn({
    required this.userMessageId,
    required this.assistantMessageId,
    required this.pendingChatKey,
  });
  final String userMessageId;
  final String assistantMessageId;
  final String pendingChatKey;
}

class _Admission {
  _Admission({
    required this.userMessageId,
    required this.chatKey,
    required this.abort,
    required this.payload,
  });
  final String userMessageId;
  final String chatKey;
  final _Abort abort;
  final SendPayload payload;
  final Completer<String?> settled = Completer<String?>();

  void settle(String? chatId) {
    if (!settled.isCompleted) settled.complete(chatId);
  }
}

/// One chat surface. Create one per mounted Home/chat route (React mounts
/// `Home key={chatId}`); [close] runs the unmount cleanup.
class ChatSessionCubit extends Cubit<ChatSessionState> {
  ChatSessionCubit({
    required MothershipClient client,
    required QueryClient queryClient,
    required MothershipQueueStore queueStore,
    required MothershipEffortStore effortStore,
    required MothershipEffortStore planEffortStore,
    required String workspaceId,
    String? chatId,
    SendHandoffStore? handoffs,
    this.requestMode = 'agent',
    this.modelSelectorEnabled = false,
    this.workflowId,
    this.surface = 'home',
    this.markChatRead = true,
    this.callbacks = const ChatSessionCallbacks(),
    String Function()? idGenerator,
    bool Function()? isOnline,
    String Function()? timeZone,
    Stream<BrowserReturnReason>? browserReturns,
    Stream<void>? onlineEvents,
    Random? random,
    this.resourceAttachments,
    this.isKnownCliToolName,
  }) : _client = client,
       _queries = queryClient,
       _queue = queueStore,
       _effort = effortStore,
       _planEffort = planEffortStore,
       _handoffs = handoffs,
       _newId = idGenerator ?? _uuid,
       _isOnline = isOnline ?? deviceIsOnline,
       _timeZone = timeZone ?? deviceTimeZone,
       _random = random ?? Random(),
       super(ChatSessionState(workspaceId: workspaceId, chatId: chatId)) {
    _pendingChatKey = '$pendingChatKeyPrefix${_newId()}';
    _queue.addListener(_onQueueChanged);
    _returnsSub = (browserReturns ?? browserReturnSignals()).listen(
      (reason) => unawaited(recoverActiveStream(reason)),
    );
    _onlineSub = (onlineEvents ?? onlineSignals()).listen(
      (_) => _queue.releaseHeldUntilOnline(),
    );
    if (!_chatId.isNullOrEmpty) {
      _observeHistory(chatId!);
    } else {
      _queue.adoptHeldSends(_chatKey, _heldSurface);
    }
    if (_isOnline()) _queue.releaseHeldUntilOnline();
    _onQueueChanged();
  }

  static String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  final MothershipClient _client;
  final QueryClient _queries;
  final MothershipQueueStore _queue;
  final MothershipEffortStore _effort;
  final MothershipEffortStore _planEffort;
  final SendHandoffStore? _handoffs;
  final String Function() _newId;
  final bool Function() _isOnline;
  final String Function() _timeZone;
  final Random _random;
  final SseDecoder _decoder = SseDecoder();

  /// `agent`, `assistant` or `plan` for new turns.
  String requestMode;
  final bool modelSelectorEnabled;
  final String? workflowId;

  /// The surface name of held chatless sends (`<scope>:<workflowId|'home'>`).
  final String surface;

  /// Marks the chat read when it resolves and when a send ends
  /// (`home.tsx:193-200`).
  final bool markChatRead;
  final ChatSessionCallbacks callbacks;

  /// `buildResourceAttachments` of the resources panel (open resources with
  /// the active flag); `null` or empty sends none.
  final List<Map<String, Object?>> Function()? resourceAttachments;

  /// Recognises the specific `cli_*` names a streaming `sim_cli` call
  /// refines to (the tool display's title catalog); see
  /// [refineStreamingCliToolName].
  final CliToolNameRecognizer? isKnownCliToolName;

  TurnModel _newModel() => TurnModel(isKnownCliToolName: isKnownCliToolName);

  /// Sends the unmount put back at the head of a dying chatless queue, so the
  /// withdrawal that follows does not hand them off a second time.
  final Set<String> _withdrawnHeldAtUnmount = {};

  // Stream identity and cursors.
  int _gen = 0;
  _Abort? _abort;
  _Reader? _reader;
  String? _streamId;
  String _lastCursor = '0';
  String? _logResyncedStreamId;
  String? _traceparent;
  String? _requestId;
  late TurnModel _model = _newModel();
  _Turn? _turn;
  String? _liveAssistantId;
  String? _locallyTerminalStreamId;
  _Admission? _pendingAdmission;
  Future<void>? _pendingStop;
  StopMode? _pendingStopMode;
  bool _sending = false;
  bool _reconnecting = false;

  // Live overlay on top of the transcript.
  ChatMessage? _liveUser;
  ChatMessage? _liveAssistant;
  String? _overlayStreamId;
  PersistedMessage? _pendingUserPersisted;

  // History.
  late String _pendingChatKey;
  Query<MothershipChatHistory>? _historyQuery;
  StreamSubscription<QueryState<MothershipChatHistory>>? _historySub;
  MothershipChatHistory? _history;
  String? _appliedHydrationKey;

  // Pacing and timers.
  Timer? _flushTimer;
  DateTime? _lastFlushAt;
  Timer? _exhaustedRecheck;
  Timer? _retryWakeup;
  ({String streamId, _Abort abort})? _persistedWait;
  ({String subject, _Abort abort, Future<void> future})? _recovery;

  // Queue dispatch.
  final List<int> _dispatchActions = [];
  Future<void>? _dispatchTask;
  int _dispatchEpoch = 0;
  final Set<String> _dispatchIds = {};
  final Set<String> _removedDuringDispatch = {};
  String? _dispatchingHeadId;

  StreamSubscription<BrowserReturnReason>? _returnsSub;
  StreamSubscription<void>? _onlineSub;
  final _resourceEvents = StreamController<ChatResourceEvent>.broadcast();

  /// Resource and file-preview events of the live stream.
  Stream<ChatResourceEvent> get resourceEvents => _resourceEvents.stream;

  String? get _chatId => state.chatId;
  String get _chatKey => _chatId ?? _pendingChatKey;
  String get _heldSurface => '${state.workspaceId}:${workflowId ?? surface}';
  int get _nowMs => clock.now().millisecondsSinceEpoch;

  /// The current queue key (`chatKeyRef`).
  @visibleForTesting
  String get chatKey => _chatKey;

  /// Pending sleeps on the current abort (bounded: one per running wait).
  @visibleForTesting
  int get debugAbortWaiters => _abort?.waiters.length ?? 0;

  /// `hasPendingChatAdmission`: a POST of this chat key has not answered.
  /// One of a chat the surface switched away from does not hold this one.
  bool get _hasPendingAdmission => _pendingAdmission?.chatKey == _chatKey;

  // ---------------------------------------------------------------------------
  // State emission.

  void _emitState(ChatSessionState next) {
    if (!isClosed) emit(next);
  }

  void _emitMessages() {
    final overlay = [?_liveUser, ?_liveAssistant];
    final overlayIds = {for (final m in overlay) m.id};
    final history = _history;
    final base = _chatId != null && history != null
        ? [
            for (final m in history.messages)
              if (!overlayIds.contains(m.id)) toDisplayMessage(m),
          ]
        : const <ChatMessage>[];
    _emitState(state.copyWith(messages: [...base, ...overlay]));
  }

  void _setError(String? message) => _emitState(
    message == null
        ? state.copyWith(clearError: true)
        : state.copyWith(error: message),
  );

  void _setTransportIdle() {
    final wasSending = _sending;
    _sending = false;
    _reconnecting = false;
    _emitState(state.copyWith(isSending: false, isReconnecting: false));
    if (wasSending) _markRead();
    _scheduleDrain();
  }

  void _setTransportStreaming() {
    _sending = true;
    _reconnecting = false;
    _emitState(state.copyWith(isSending: true, isReconnecting: false));
  }

  void _setTransportReconnecting() {
    _sending = true;
    _reconnecting = true;
    _emitState(state.copyWith(isSending: true, isReconnecting: true));
  }

  void _setReconnecting({required bool value}) {
    _reconnecting = value;
    _emitState(state.copyWith(isReconnecting: value));
  }

  void _markRead() {
    final chatId = _chatId;
    if (!markChatRead || chatId == null) return;
    unawaited(_client.markRead(chatId).catchError((_) {}));
  }

  // ---------------------------------------------------------------------------
  // History.

  void _observeHistory(String chatId) {
    unawaited(_historySub?.cancel());
    _historyQuery?.dispose();
    final key = MothershipChatKeys.detail(chatId);
    final query = _queries.query<MothershipChatHistory>(
      key,
      (token) => _fetchHistory(chatId, token),
      staleTime: mothershipChatHistoryStaleTime,
    );
    _historyQuery = query;
    _historySub = query.states.listen((next) {
      if (next.status == QueryStatus.idle &&
          next.data == null &&
          !next.isFetching) {
        // The entry was removed (`removeQueries`, e.g. the chat was deleted
        // elsewhere): observe a fresh one, whose fetch decides (a 404 shows
        // the history error, as React's refetch does).
        _history = null;
        _appliedHydrationKey = null;
        _emitMessages();
        scheduleMicrotask(() {
          if (!isClosed && identical(_historyQuery, query)) {
            _observeHistory(chatId);
          }
        });
        return;
      }
      _onHistoryState(next);
    });
    _onHistoryState(query.state);
    unawaited(query.fetch().then((_) {}, onError: (_) {}));
  }

  Future<MothershipChatHistory> _fetchHistory(
    String chatId,
    MothershipCancelToken token, {
    Duration? timeout,
  }) async {
    final deleteSeen = _queue.cleared[chatId];
    final history = await _client.chatHistory(
      chatId,
      cached: _queries.getQueryData<MothershipChatHistory>(
        MothershipChatKeys.detail(chatId),
      ),
      cancelToken: token,
      timeout: timeout,
    );
    if (deleteSeen != null) _queue.liftDelete(chatId, deleteSeen);
    return history;
  }

  void _onHistoryState(QueryState<MothershipChatHistory> query) {
    if (isClosed) return;
    final data = query.data;
    final status = data != null
        ? ChatHistoryStatus.ready
        : switch (query.status) {
            QueryStatus.error => ChatHistoryStatus.error,
            QueryStatus.loading => ChatHistoryStatus.loading,
            _ => ChatHistoryStatus.loading,
          };
    if (status == ChatHistoryStatus.error && data == null) {
      _emitState(
        state.copyWith(
          historyStatus: status,
          error: chatHistoryErrorMessage,
        ),
      );
      return;
    }
    if (data == null) {
      _emitState(state.copyWith(historyStatus: status));
      return;
    }
    _history = data;
    _emitState(
      state.copyWith(
        historyStatus: status,
        title: data.title,
        olderCursor: data.olderCursor,
      ),
    );
    _maybeDropSettledOverlay(data);
    _emitMessages();
    _hydrate(data);
    _discardAcceptedQueuedSends(data);
    _scheduleDrain();
  }

  /// The finished turn's overlay goes once the server copy no longer lists
  /// its stream as running (the detail refetch replaces it, as in React).
  void _maybeDropSettledOverlay(MothershipChatHistory history) {
    final overlayStream = _overlayStreamId;
    if (_turn != null || overlayStream == null) return;
    if (history.activeStreamId == overlayStream) return;
    if (_locallyTerminalStreamId != overlayStream &&
        history.messages.every((m) => m.id != _liveUser?.id)) {
      return;
    }
    _liveUser = null;
    _liveAssistant = null;
    _overlayStreamId = null;
  }

  /// Load-time reconnect (`U:2063-2302`): a chat whose server copy lists a
  /// running stream the surface is not already reading is tailed from 0.
  void _hydrate(MothershipChatHistory history) {
    final key =
        '${history.id}|${history.activeStreamId}|${history.streamSnapshotStatus}|'
        '${history.messages.length}|${history.messages.lastOrNull?.id}';
    if (_appliedHydrationKey == key) return;
    _appliedHydrationKey = key;
    final activeStreamId = history.activeStreamId;
    if (activeStreamId == null && _locallyTerminalStreamId != null) {
      _locallyTerminalStreamId = null;
    }
    final reconnect =
        activeStreamId != null &&
        !_sending &&
        !_hasPendingAdmission &&
        activeStreamId != _locallyTerminalStreamId &&
        !isTerminalStreamStatus(history.streamSnapshotStatus);
    if (!reconnect) return;
    final gen = ++_gen;
    _abort?.abort('superseded:hydration');
    _abort = _Abort();
    _reader?.cancel();
    _streamId = activeStreamId;
    _liveAssistantId = liveAssistantMessageId(activeStreamId);
    _overlayStreamId = activeStreamId;
    _setTransportReconnecting();
    _model = _newModel();
    _lastCursor = '0';
    unawaited(() async {
      final ok = await _retryReconnect(
        streamId: activeStreamId,
        gen: gen,
        targetChatId: history.id,
      );
      if (_gen != gen) return;
      if (!ok) {
        _finalize(error: true, targetChatId: history.id, streamTerminal: false);
      } else if (_sending && !_reconnecting) {
        _setTransportIdle();
      }
    }());
  }

  void _upsertHistory(
    String chatId,
    MothershipChatHistory Function(MothershipChatHistory current) update,
  ) {
    final key = MothershipChatKeys.detail(chatId);
    final current =
        _queries.getQueryData<MothershipChatHistory>(key) ??
        MothershipChatHistory(id: chatId, messages: const []);
    _queries.setQueryData<MothershipChatHistory>(key, update(current));
  }

  void _invalidateChat({bool includeDetail = true, String? targetChatId}) {
    final chatId = targetChatId ?? _chatId;
    if (includeDetail && chatId != null) {
      unawaited(_queries.invalidateQueries(MothershipChatKeys.detail(chatId)));
    }
    unawaited(
      _queries.invalidateQueries(MothershipChatKeys.list(state.workspaceId)),
    );
  }

  /// `adoptResolvedChatId`: the surface now shows [chatId].
  void _adoptChat(
    String chatId, {
    bool replaceRoute = true,
    bool invalidateList = false,
  }) {
    if (_chatId == chatId) return;
    final previousKey = _chatKey;
    _emitState(state.copyWith(chatId: chatId));
    _queue.migrate(previousKey, chatId);
    _effort.setNewChatEffort(null);
    if (replaceRoute && workflowId == null) {
      callbacks.onChatResolved?.call(
        chatId,
        chatUrl(state.workspaceId, chatId),
      );
    }
    if (invalidateList) _invalidateChat(includeDetail: false);
    _observeHistory(chatId);
    _markRead();
  }

  // ---------------------------------------------------------------------------
  // Live overlay and flushes.

  void _resetStreamingBuffers() {
    _model = _newModel();
    _liveAssistant = null;
    _requestId = null;
  }

  /// The live assistant rebuilt from the model (no emission).
  bool _rebuildLiveAssistant() {
    final id = _liveAssistantId;
    if (id == null) return false;
    _liveAssistant = ChatMessage(
      id: id,
      role: ChatRole.assistant,
      requestMode: requestMode,
      content: modelMainText(_model),
      contentBlocks: modelToContentBlocks(_model),
      requestId: _requestId,
    );
    return true;
  }

  /// The stream loop's `flush` (`stream-context.ts`): the model snapshot
  /// becomes the live message and is written into the chat's detail cache
  /// (`reconcileLiveAssistantTurn`), so the turn's answer outlives the
  /// overlay (a queued follow-up's optimistic pair replaces the overlay
  /// before the server copy is refetched). A stale [loop] writes nothing.
  void _flush(_Loop loop) {
    if (_isStale(loop.gen)) return;
    _flushTimer?.cancel();
    _flushTimer = null;
    _lastFlushAt = clock.now();
    if (!_rebuildLiveAssistant()) return;
    _writeLiveAssistant(targetChatId: loop.targetChatId, touchStream: true);
    _emitMessages();
  }

  /// Writes the live assistant into the detail cache of [targetChatId] (or
  /// the shown chat). [touchStream] also marks the stream active there, as
  /// a running turn's flush does; terminal writes (stop, error finalize)
  /// leave it.
  void _writeLiveAssistant({String? targetChatId, bool touchStream = false}) {
    final chatId = targetChatId ?? _chatId;
    final live = _liveAssistant;
    if (chatId == null || live == null) return;
    final snapshot = assistantSnapshotMessage(live);
    final streamId = _streamId;
    _upsertHistory(chatId, (current) {
      final sid = streamId ?? current.activeStreamId ?? live.id;
      final terminalExists =
          current.activeStreamId != sid &&
          hasTerminalPersistedAssistantForStream(
            current.messages,
            sid,
            live.id,
          );
      final messages = reconcileLiveAssistantTurn(
        messages: current.messages,
        streamId: sid,
        liveAssistant: snapshot,
        activeStreamId: current.activeStreamId,
      );
      if (identical(messages, current.messages)) return current;
      return current.copyWith(
        messages: messages,
        activeStreamId: !touchStream || terminalExists
            ? current.activeStreamId
            : (streamId ?? current.activeStreamId),
      );
    });
  }

  /// Paced text flush: at most one per [ChatTimings.textFlushInterval].
  void _flushText(_Loop loop) {
    if (loop.deferFlushes || _isStale(loop.gen) || _flushTimer != null) {
      return;
    }
    final last = _lastFlushAt;
    final elapsed = last == null
        ? ChatTimings.textFlushInterval
        : clock.now().difference(last);
    final wait = ChatTimings.textFlushInterval - elapsed;
    if (wait <= Duration.zero) {
      _flush(loop);
      return;
    }
    late final Timer timer;
    timer = Timer(wait, () {
      if (identical(_flushTimer, timer)) _flushTimer = null;
      _flush(loop);
    });
    _flushTimer = timer;
  }

  void _flushNow(_Loop loop) {
    if (loop.deferFlushes) return;
    _flush(loop);
  }

  // ---------------------------------------------------------------------------
  // The stream loop (`processSSEStream`).

  bool _isStale(int gen) => _gen != gen;

  Future<({bool sawStreamError, bool sawComplete})> _processBytes(
    Stream<List<int>> bytes,
    int gen, {
    String? targetChatId,
  }) async {
    final loop = _Loop(gen: gen, targetChatId: targetChatId);
    if (_isStale(gen)) return (sawStreamError: false, sawComplete: false);
    final reader = _Reader();
    _reader = reader;
    Object? failure;
    StackTrace? failureStack;
    reader.subscription = _decoder
        .frames(withSseIdleTimeout(bytes, ChatTimings.idleTimeout))
        .listen(
          (frame) {
            if (reader.done.isCompleted) return;
            if (loop.sawComplete) return;
            if (_isStale(gen)) {
              reader.cancel();
              return;
            }
            if (frame.isDone) return;
            try {
              Object? json;
              try {
                json = jsonDecode(frame.data);
              } on FormatException catch (error) {
                throw MothershipStreamSchemaError.forFailure(
                  [error.message],
                  context: 'Live SSE event.',
                  failure:
                      'Received invalid JSON while parsing a stream event.',
                );
              }
              final envelope = MothershipStreamEnvelope.fromJson(
                json,
                strict: true,
                context: 'Live SSE event.',
              );
              _handleEnvelope(envelope, loop, targetChatId: targetChatId);
            } on Object catch (error, stack) {
              failure = error;
              failureStack = stack;
              reader.cancel();
              return;
            }
            if (loop.sawComplete) reader.cancel();
          },
          onError: (Object error, StackTrace stack) {
            failure ??= error;
            failureStack ??= stack;
            reader.cancel();
          },
          onDone: reader.cancel,
        );
    await reader.done.future;
    if (identical(_reader, reader)) _reader = null;
    _finishLoop(loop);
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    return _verdict(loop);
  }

  /// Replays validated batch events (`buildReplayStream` + `processSSEStream`
  /// with `deferFlushes`).
  ({bool sawStreamError, bool sawComplete}) _processBatch(
    List<StreamBatchEvent> events,
    int gen, {
    String? targetChatId,
  }) {
    final loop = _Loop(
      gen: gen,
      targetChatId: targetChatId,
      deferFlushes: true,
    );
    for (final event in events) {
      if (_isStale(gen) || loop.sawComplete) break;
      _handleEnvelope(event.envelope, loop, targetChatId: targetChatId);
    }
    _finishLoop(loop);
    _flush(loop);
    return _verdict(loop);
  }

  /// A loop the user moved on from (stop, chat switch, a newer stream)
  /// leaves the model and the transcript alone.
  void _finishLoop(_Loop loop) {
    if (_isStale(loop.gen)) return;
    if (loop.sawStreamError && !loop.sawComplete) {
      applyTurnTerminal(_model, TurnStatus.error);
      _flushNow(loop);
    }
    if (_flushTimer != null) _flush(loop);
  }

  /// `complete{complete}` outranks earlier error frames; `complete{error}` is
  /// an error even without one (`U:2499-2507`).
  ({bool sawStreamError, bool sawComplete}) _verdict(_Loop loop) => (
    sawStreamError:
        loop.completionStatus != 'complete' &&
        (loop.sawStreamError || loop.completionStatus == 'error'),
    sawComplete: loop.sawComplete,
  );

  void _handleEnvelope(
    MothershipStreamEnvelope envelope,
    _Loop loop, {
    String? targetChatId,
  }) {
    final traceRequestId = envelope.trace?['requestId'];
    if (traceRequestId is String && traceRequestId != _requestId) {
      _requestId = traceRequestId;
      _flushNow(loop);
    }
    _streamId = envelope.stream.streamId;
    final cursor = envelope.stream.cursor ?? '${envelope.seq}';
    if (_isProcessedCursor(cursor, _lastCursor)) return;
    _lastCursor = cursor;
    reduceEvent(_model, envelope);
    final payload = MothershipPayload.of(envelope);
    switch (payload) {
      case SessionChatPayload(:final chatId):
        if (_chatId == null) {
          _seedNewChat(chatId);
        } else {
          _invalidateChat(includeDetail: false);
        }
      case SessionTitlePayload():
        _invalidateChat(includeDetail: false);
        callbacks.onTitleUpdate?.call();
      case TextPayload() || ToolArgsDeltaPayload():
        _flushText(loop);
      case ToolResultPayload():
        if (!payload.replay) callbacks.onToolResult?.call(payload);
        _flushNow(loop);
      case FilePreviewPayload():
        _resourceEvents.add(ChatResourceEvent(payload: payload, replay: false));
      case ResourceEventPayload():
        _resourceEvents.add(
          ChatResourceEvent(payload: payload, replay: payload.replay),
        );
        _flushNow(loop);
      case ErrorPayload():
        loop.sawStreamError = true;
        _setError(payload.text ?? 'An error occurred');
        _flushNow(loop);
      case CompletePayload():
        loop
          ..sawComplete = true
          ..completionStatus = payload.status;
        _flushNow(loop);
      case ToolCallPayload() || SpanPayload() || RunPayload():
        _flushNow(loop);
      case SessionStartPayload() || SessionTracePayload() || UnknownPayload():
        break;
    }
  }

  static bool _isProcessedCursor(String eventCursor, String current) {
    final event = num.tryParse(eventCursor);
    final now = num.tryParse(current);
    return event != null && now != null && event <= now;
  }

  /// `session chat` on a chatless surface: adopt the chat and seed its
  /// detail with the optimistic pair (`handle-session-event.ts:9-73`).
  void _seedNewChat(String chatId) {
    final user = _pendingUserPersisted;
    final assistantId = _liveAssistantId;
    _queries.setQueryData<MothershipChatHistory>(
      MothershipChatKeys.detail(chatId),
      MothershipChatHistory(
        id: chatId,
        messages: [
          ?user,
          if (assistantId != null)
            PersistedMessage(id: assistantId, role: 'assistant', content: ''),
        ],
        activeStreamId: _streamId,
      ),
    );
    _adoptChat(chatId, invalidateList: true);
  }

  // ---------------------------------------------------------------------------
  // Reconnect.

  ({String after, bool preserve}) _selectReplay(String afterCursor) {
    final after = num.tryParse(afterCursor);
    if (after != null && after > 0 && !_model.isEmpty) {
      return (after: afterCursor, preserve: true);
    }
    _model = _newModel();
    _lastCursor = '0';
    return (after: '0', preserve: false);
  }

  bool _staleReconnect(int gen) => _gen != gen || (_abort?.aborted ?? true);

  Future<StreamBatch> _fetchBatch(
    String streamId,
    String after, {
    _Abort? abort,
  }) => _client.batch(
    streamId,
    after,
    fromLog: _logResyncedStreamId == streamId,
    traceparent: _traceparent,
    cancelToken: abort?.token,
  );

  /// `attachToExistingStream`.
  Future<({bool error, bool aborted})> _attach({
    required String streamId,
    required int gen,
    required StreamBatch initialBatch,
    required String afterCursor,
    String? targetChatId,
  }) async {
    if (_staleReconnect(gen)) return (error: false, aborted: true);
    var latest = _selectReplay(afterCursor).after;
    var seed = initialBatch.events;
    var status = initialBatch.status;
    _setTransportReconnecting();
    _setError(null);
    try {
      while (_gen == gen) {
        if (seed.isNotEmpty) {
          final result = _processBatch(seed, gen, targetChatId: targetChatId);
          if (_staleReconnect(gen)) return (error: false, aborted: true);
          latest = '${seed.last.eventId}';
          _lastCursor = latest;
          seed = const [];
          if (result.sawStreamError) return (error: true, aborted: false);
        }
        if (isTerminalStreamStatus(status)) {
          if (status == 'error') _setError(reconnectTailError);
          return (error: status == 'error', aborted: false);
        }
        final abort = _abort;
        if (abort == null || abort.aborted) {
          return (error: false, aborted: true);
        }
        final MothershipTailStream tail;
        try {
          tail = await _client.tail(
            streamId,
            latest,
            fromLog: _logResyncedStreamId == streamId,
            traceparent: _traceparent,
            cancelToken: abort.token,
          );
        } on ApiClientError {
          throw StateError(reconnectTailError);
        }
        if (_staleReconnect(gen)) return (error: false, aborted: true);
        if (tail.logResynced) {
          _logResyncedStreamId = streamId;
          latest = _selectReplay('0').after;
        }
        _setTransportStreaming();
        final live = await _processBytes(
          tail.bytes,
          gen,
          targetChatId: targetChatId,
        );
        if (live.sawStreamError) return (error: true, aborted: false);
        if (live.sawComplete) return (error: false, aborted: false);
        if (_staleReconnect(gen)) return (error: false, aborted: true);
        _setTransportReconnecting();
        latest = _lastCursor.isEmpty ? latest : _lastCursor;
        final batch = await _fetchBatch(streamId, latest, abort: abort);
        if (_staleReconnect(gen)) return (error: false, aborted: true);
        seed = batch.events;
        status = batch.status;
        if (batch.events.isEmpty && !batch.isTerminal) {
          if (abort.aborted || _gen != gen) {
            return (error: false, aborted: true);
          }
          await _sleep(ChatTimings.emptyBatchPause, abort);
        }
      }
      return (error: false, aborted: true);
    } on _Aborted {
      return (error: false, aborted: true);
    } on ApiCancelledError {
      return (error: false, aborted: true);
    } finally {
      if (_gen == gen) {
        if (_sending) {
          _setReconnecting(value: false);
        } else {
          _setTransportIdle();
        }
      }
    }
  }

  /// `resumeOrFinalize`.
  Future<void> _resumeOrFinalize({
    required String streamId,
    required int gen,
    required String afterCursor,
    _Abort? abort,
    String? targetChatId,
    bool Function()? shouldContinue,
  }) async {
    bool cont() => shouldContinue?.call() ?? true;
    if (_gen != gen || (abort?.aborted ?? false) || !cont()) return;
    final replay = _selectReplay(afterCursor);
    final batch = await _fetchBatch(streamId, replay.after, abort: abort);
    if (_gen != gen || !cont()) return;
    if (batch.isTerminal) {
      if (batch.events.isNotEmpty) {
        _processBatch(batch.events, gen, targetChatId: targetChatId);
      }
      if (_gen != gen || !cont()) return;
      _finalize(error: batch.status == 'error', targetChatId: targetChatId);
      return;
    }
    final result = await _attach(
      streamId: streamId,
      gen: gen,
      initialBatch: batch,
      afterCursor: replay.after,
      targetChatId: targetChatId,
    );
    if (_gen == gen && !result.aborted && cont()) {
      _finalize(error: result.error, targetChatId: targetChatId);
    } else if (_gen == gen && result.aborted && !_sending && cont()) {
      _setTransportIdle();
    }
  }

  /// `retryReconnect`: up to 10 attempts at `min(1 s·2^(n-1), 30 s)`, the
  /// budget reset whenever an attempt advanced the cursor. Returns `false`
  /// on a schema error or exhaustion (the caller finalizes with an error).
  Future<bool> _retryReconnect({
    required String streamId,
    required int gen,
    String? targetChatId,
    bool Function()? shouldContinue,
  }) async {
    bool stale() =>
        _gen != gen ||
        (_abort?.aborted ?? false) ||
        !(shouldContinue?.call() ?? true);
    void settleTransport() {
      if (!_sending) {
        _setTransportIdle();
      } else {
        _setReconnecting(value: false);
      }
    }

    var attempt = 0;
    while (attempt <= ChatTimings.maxReconnectAttempts) {
      if (stale()) return true;
      final cursorBefore = _lastCursor;
      if (attempt > 0) {
        final delay = Duration(
          milliseconds: min(
            ChatTimings.reconnectBaseDelay.inMilliseconds *
                pow(2, attempt - 1).toInt(),
            ChatTimings.reconnectMaxDelay.inMilliseconds,
          ),
        );
        if (stale()) return true;
        _setTransportReconnecting();
        try {
          await _sleep(delay, _abort);
        } on _Aborted {
          // Woken by an abort: the staleness check below decides.
        }
        if (stale()) {
          settleTransport();
          return true;
        }
      }
      try {
        await _resumeOrFinalize(
          streamId: streamId,
          gen: gen,
          afterCursor: _lastCursor.isEmpty ? '0' : _lastCursor,
          abort: _abort,
          targetChatId: targetChatId,
          shouldContinue: shouldContinue,
        );
        if (_gen != gen || (_abort?.aborted ?? false)) {
          settleTransport();
          return true;
        }
        if (!_sending) {
          _setTransportIdle();
          return true;
        }
      } on _Aborted {
        settleTransport();
        return true;
      } on ApiCancelledError {
        settleTransport();
        return true;
      } on MothershipStreamGoneError {
        if (_gen == gen) _finalize(targetChatId: targetChatId);
        return true;
      } on MothershipStreamSchemaError catch (error) {
        if (_gen == gen) _setError(error.message);
        return false;
      } on Object catch (error) {
        developer.log(
          'Reconnect attempt ${attempt + 1} failed',
          name: 'sim_app.chat',
          error: error,
        );
      }
      attempt = _lastCursor != cursorBefore ? 1 : attempt + 1;
    }
    if (_gen == gen) {
      _setReconnecting(value: false);
      _setError(reconnectTailError);
      _exhaustedRecheck?.cancel();
      _exhaustedRecheck = Timer(ChatTimings.reconnectExhaustedRecheck, () {
        _exhaustedRecheck = null;
        unawaited(recoverActiveStream(BrowserReturnReason.exhaustedRecheck));
      });
    }
    return false;
  }

  Future<void> _sleep(Duration duration, _Abort? abort) {
    if (abort != null && abort.aborted) {
      return Future.error(_Aborted(abort.reason));
    }
    final completer = Completer<void>();
    late final Timer timer;
    void wake() {
      timer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(_Aborted(abort?.reason));
      }
    }

    timer = Timer(duration, () {
      abort?.waiters.remove(wake);
      if (!completer.isCompleted) completer.complete();
    });
    abort?.waiters.add(wake);
    return completer.future;
  }

  /// `resolveChatIdForStream`: batches from 0 until a chat id appears,
  /// 10 s deadline, 250 ms → 2 s backoff.
  Future<String?> _resolveChatIdForStream(
    String streamId, {
    bool preferExisting = true,
  }) async {
    if (preferExisting && _chatId != null) return _chatId;
    final deadline = clock.now().add(ChatTimings.chatIdResolveTimeout);
    var delay = const Duration(milliseconds: 250);
    while (clock.now().isBefore(deadline)) {
      try {
        final batch = await _fetchBatch(streamId, '0');
        final chatId = batch.resolvedChatId;
        if (chatId != null) return chatId;
      } on Object {
        // Retried until the deadline.
      }
      final remaining = deadline.difference(clock.now());
      if (remaining <= Duration.zero) break;
      await _sleep(delay < remaining ? delay : remaining, null);
      delay = Duration(milliseconds: min(delay.inMilliseconds * 2, 2000));
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Browser-return recovery (`recoverActiveStreamFromRedis`).

  /// Re-attaches to the chat's running stream after the tab returns
  /// (visible, pageshow, online), a reconnect exhaustion recheck or a busy
  /// refusal. A newer call supersedes one in flight.
  Future<void> recoverActiveStream(BrowserReturnReason reason) async {
    final chatId = _chatId;
    if (chatId == null || isClosed) return;
    final previous = _recovery;
    if (previous != null) {
      previous.abort.abort('superseded_by_return');
      _recovery = null;
    }
    final recoveryAbort = _Abort();
    final observedGen = _gen;
    bool sameSubject() =>
        _chatId == chatId && !recoveryAbort.aborted && !isClosed;

    Future<void> run() async {
      final cachedStream = _history?.activeStreamId;
      final fallbackStreamId =
          _streamId ?? _turn?.userMessageId ?? cachedStream;
      String? loadedStream;
      var loaded = false;
      try {
        final history = await _fetchHistory(
          chatId,
          recoveryAbort.token,
          timeout: ChatTimings.historyRecoveryTimeout,
        );
        if (recoveryAbort.aborted) return;
        _queries.setQueryData<MothershipChatHistory>(
          MothershipChatKeys.detail(chatId),
          history,
        );
        loaded = true;
        loadedStream = history.activeStreamId;
      } on Object {
        loadedStream = cachedStream;
      }
      final admission = _pendingAdmission;
      final admitted =
          admission == null ||
          (loaded &&
              (_history?.messages.any((m) => m.id == admission.userMessageId) ??
                  false));
      if (!admitted) return;
      final locallyRunning = _sending
          ? (_streamId ?? _turn?.userMessageId)
          : null;
      final streamId = loaded
          ? (loadedStream ?? locallyRunning)
          : fallbackStreamId;
      if (!sameSubject() ||
          _gen != observedGen ||
          _pendingStop != null ||
          streamId == null ||
          _locallyTerminalStreamId == streamId) {
        return;
      }
      final gen = ++_gen;
      final previousStream = _streamId ?? _turn?.userMessageId;
      final afterCursor = previousStream == streamId
          ? (_lastCursor.isEmpty ? '0' : _lastCursor)
          : '0';
      _setTransportReconnecting();
      _streamId = streamId;
      _abort?.abort('superseded_recovery');
      _reader?.cancel();
      _reader = null;
      _abort = recoveryAbort;
      _liveAssistantId ??= liveAssistantMessageId(streamId);
      if (previousStream != streamId) {
        _liveAssistantId = liveAssistantMessageId(streamId);
      }
      _overlayStreamId = streamId;
      try {
        await _resumeOrFinalize(
          streamId: streamId,
          gen: gen,
          afterCursor: afterCursor,
          abort: recoveryAbort,
          targetChatId: chatId,
          shouldContinue: sameSubject,
        );
      } on _Aborted {
        return;
      } on ApiCancelledError {
        return;
      } on Object {
        final ok = await _retryReconnect(
          streamId: streamId,
          gen: gen,
          targetChatId: chatId,
          shouldContinue: sameSubject,
        );
        if (!ok && _gen == gen && sameSubject()) {
          _finalize(error: true, targetChatId: chatId, streamTerminal: false);
        }
      }
    }

    final future = run();
    final entry = (subject: chatId, abort: recoveryAbort, future: future);
    _recovery = entry;
    try {
      await future;
    } finally {
      if (identical(_recovery, entry)) _recovery = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Finalize.

  /// `finalize` (`U:3468-3548`).
  void _finalize({
    bool error = false,
    String? targetChatId,
    bool streamTerminal = true,
  }) {
    if (error) {
      final blocks = _liveAssistant?.contentBlocks;
      if (blocks != null) {
        final settled = finalizeResidualToolCalls(
          blocks,
          TurnStatus.error,
          nowMs: _nowMs,
        );
        if (settled != null) {
          _liveAssistant = _liveAssistant!.copyWith(contentBlocks: settled);
          _writeLiveAssistant(targetChatId: targetChatId);
        }
      }
    }
    final followUp = !error && _queue.queue(_chatKey).isNotEmpty;
    final completedChat = targetChatId ?? _chatId;
    final terminalStream = streamTerminal
        ? (_streamId ?? _turn?.userMessageId)
        : null;
    if (streamTerminal) _locallyTerminalStreamId = terminalStream;
    _turn = null;
    _pendingUserPersisted = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _abort = null;
    _setTransportIdle();
    _emitMessages();
    _invalidateChat(includeDetail: !followUp, targetChatId: targetChatId);
    if (terminalStream != null && completedChat != null) {
      unawaited(_awaitPersistedTurn(completedChat, terminalStream));
    }
    _notifyTurnEnded(error: error);
  }

  bool _notifyTurnEnded({required bool error, bool skipQueueDispatch = false}) {
    final followUp = !error && _queue.queue(_chatKey).isNotEmpty;
    if (!error) {
      final chatId = _chatId;
      if (chatId != null) callbacks.onStreamEnd?.call(chatId, state.messages);
    }
    if (!error && !skipQueueDispatch && followUp) _enqueueDispatch();
    return followUp;
  }

  /// `awaitPersistedTurn`: until the server copy no longer lists [streamId]
  /// (≤ 120 s, 250 ms–5 s backoff, `stream-status` between refetches).
  Future<void> _awaitPersistedTurn(String chatId, String streamId) async {
    if (_persistedWait?.streamId == streamId) return;
    _persistedWait?.abort.abort('superseded:persisted_turn_wait');
    final wait = (streamId: streamId, abort: _Abort());
    _persistedWait = wait;
    final deadline = clock.now().add(ChatTimings.persistedTurnWait);
    bool waiting() =>
        !wait.abort.aborted &&
        !isClosed &&
        _locallyTerminalStreamId == streamId &&
        _chatId == chatId;
    try {
      for (var attempt = 0; clock.now().isBefore(deadline); attempt++) {
        if (attempt > 0) {
          await _sleep(
            Duration(
              milliseconds: backoffWithJitterMs(
                attempt,
                base: ChatTimings.persistedTurnRefetchBase,
                max: ChatTimings.persistedTurnRefetchMax,
                random: _random,
              ),
            ),
            wait.abort,
          );
          if (!waiting()) return;
          String? active;
          try {
            active = await _client.streamStatus(
              chatId,
              cancelToken: wait.abort.token,
            );
          } on Object {
            active = null;
          }
          if (active == streamId) continue;
        }
        if (!waiting()) return;
        MothershipChatHistory? history;
        try {
          history = await _queries.fetchQuery<MothershipChatHistory>(
            MothershipChatKeys.detail(chatId),
            (token) => _fetchHistory(chatId, token),
            force: true,
          );
        } on Object {
          history = null;
        }
        if (history != null && history.activeStreamId != streamId) return;
      }
    } on _Aborted {
      return;
    } finally {
      if (identical(_persistedWait, wait)) _persistedWait = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Send.

  /// `sendMessage`: queues when a turn is running, a stop is pending or
  /// anything is queued ahead; otherwise sends now. A withdrawn send goes
  /// back to the queue under the same id with the requeue policy.
  Future<void> sendMessage(
    SendPayload payload, {
    String? resumeUserMessageId,
  }) async {
    if (isClosed) return;
    if (payload.content.trim().isEmpty &&
        (payload.fileAttachments?.isEmpty ?? true)) {
      return;
    }
    final key = _chatKey;
    final editingId = _queue.editing[key];
    if (editingId != null) {
      final existing = _queue.queue(key).where((m) => m.id == editingId);
      if (existing.isNotEmpty) {
        _queue
          ..replaceAt(
            key,
            editingId,
            SendPayload(
              content: payload.content,
              fileAttachments: payload.fileAttachments,
              contexts: payload.contexts,
              requestMode: payload.requestMode ?? existing.first.requestMode,
              assistantSearch:
                  payload.assistantSearch ?? existing.first.assistantSearch,
              assistantSearchLevel:
                  payload.assistantSearchLevel ??
                  existing.first.assistantSearchLevel,
            ),
          )
          ..setEditing(key, null);
        if (!_sending && _pendingStop == null) _enqueueDispatch();
        return;
      }
      _queue.setEditing(key, null);
    }
    final request = SendPayload(
      content: payload.content,
      fileAttachments: payload.fileAttachments,
      contexts: payload.contexts,
      requestMode: payload.requestMode ?? requestMode,
      assistantSearch: payload.assistantSearch,
      assistantSearchLevel: payload.assistantSearchLevel,
    );
    final queuedAhead = _queue.queue(key).length;
    if (shouldQueueOutgoingMessage(
      sending: _sending || _hasPendingAdmission,
      stopPending: _pendingStop != null,
      queuedAhead: queuedAhead,
    )) {
      _queue.enqueue(key, _createQueuedMessage(request, resumeUserMessageId));
      if (_pendingStop != null || (queuedAhead > 0 && !_sending)) {
        _enqueueDispatch();
      }
      return;
    }
    final result = await _startSend(
      request,
      resumeUserMessageId: resumeUserMessageId,
    );
    if (result is! SendWithdrawal) return;
    final position = _queue.liveQueuePosition(key, const []);
    final chatless = position.chatKey.startsWith(pendingChatKeyPrefix);
    if (result.reason == WithdrawalReason.withdrawn && chatless) {
      if (_withdrawnHeldAtUnmount.remove(result.userMessageId)) return;
      _handOffWithdrawnSend(request, result.userMessageId);
      return;
    }
    _queue.insertAt(
      position.chatKey,
      position.index,
      requeued(
        _createQueuedMessage(request, result.userMessageId),
        requeueReasonOf(result.reason),
        previousAttempts: 0,
        nowMs: _nowMs,
        chatlessSurface: chatless ? _heldSurface : null,
        random: _random,
      ).copyWith(admissionUnknown: result.admissionUnknown),
    );
  }

  void _handOffWithdrawnSend(SendPayload payload, String userMessageId) {
    _handoffs?.storeHandoff(
      MothershipHandoff(
        message: payload.content,
        contexts: payload.contexts ?? const [],
        fileAttachments: payload.fileAttachments,
        resumeUserMessageId: userMessageId,
        requestMode: payload.requestMode,
        assistantSearch: payload.assistantSearch,
        assistantSearchLevel: payload.assistantSearchLevel,
      ),
      workspaceId: state.workspaceId,
    );
  }

  QueuedMessage _createQueuedMessage(
    SendPayload payload,
    String? resumeUserMessageId,
  ) {
    final id = _newId();
    final handoffChatId = _chatId;
    final superseded =
        _streamId ??
        _turn?.userMessageId ??
        _locallyTerminalStreamId ??
        _history?.activeStreamId;
    return QueuedMessage(
      id: id,
      content: payload.content,
      fileAttachments: payload.fileAttachments,
      contexts: payload.contexts,
      requestMode: payload.requestMode,
      assistantSearch: payload.assistantSearch,
      assistantSearchLevel: payload.assistantSearchLevel,
      resumeUserMessageId: resumeUserMessageId,
      queuedSendHandoff: superseded != null || handoffChatId != null
          ? QueuedSendHandoffSeed(
              id: id,
              chatId: handoffChatId,
              supersededStreamId: superseded,
            )
          : null,
    );
  }

  PersistedMessage _persistedUser(
    String id,
    SendPayload payload,
    String mode,
  ) => PersistedMessage(
    id: id,
    role: 'user',
    requestMode: mode,
    content: payload.content,
    timestamp: clock.now().toUtc().toIso8601String(),
    fileAttachments: payload.fileAttachments?.isEmpty ?? true
        ? null
        : payload.fileAttachments,
    contexts: payload.contexts?.isEmpty ?? true ? null : payload.contexts,
  );

  MothershipEffortStore _effortStoreFor(String mode) =>
      mode == 'plan' ? _planEffort : _effort;

  /// `startSendMessage` (`U:3550-4320`). Returns `true` when the optimistic
  /// pair was applied (the transcript consumed it), `false` when nothing
  /// was sent, or a [SendWithdrawal].
  Future<Object> _startSend(
    SendPayload payload, {
    String? resumeUserMessageId,
    bool? admissionUnknownHint,
    QueuedSendHandoffSeed? queuedSendHandoff,
    Future<void>? pendingStop,
    void Function()? onOptimisticSendApplied,
  }) async {
    if (isClosed) return false;
    final mode = payload.requestMode ?? requestMode;
    final stop = pendingStop ?? _pendingStop;
    var handoff = queuedSendHandoff;
    final pendingStopStreamId = stop != null
        ? (_locallyTerminalStreamId ??
              handoff?.supersededStreamId ??
              _streamId ??
              _turn?.userMessageId)
        : null;
    if (stop != null && handoff != null) {
      handoff = handoff.copyWith(
        supersededStreamId: pendingStopStreamId,
        stopRequired: true,
      );
    }
    var reachedServer = false;
    var failedAtNetwork = false;
    var consumed = false;

    _setError(null);
    _setTransportStreaming();

    final userMessageId = resumeUserMessageId ?? _newId();
    var admissionUnknown =
        resumeUserMessageId != null && (admissionUnknownHint ?? true);
    final assistantId = liveAssistantMessageId(userMessageId);
    var requestChatId = handoff?.chatId ?? _chatId;

    final effortStore = _effort;
    final effortChoice = mode == 'assistant'
        ? null
        : requestChatId != null
        ? (effortStore.chatEffort(requestChatId) ??
              _queries
                  .getQueryData<MothershipChatHistory>(
                    MothershipChatKeys.detail(requestChatId),
                  )
                  ?.effort)
        : effortStore.newChatEffort;

    void adoptNewChatEffort(String chatId, {required bool admittedThisSend}) {
      if (mode == 'assistant') return;
      final latest = effortStore.newChatEffort ?? effortChoice;
      if (latest == null) return;
      effortStore.adoptNewChatEffort(chatId, latest);
      if (!admittedThisSend || latest != effortChoice) {
        unawaited(_client.setChatEffort(chatId, latest).catchError((_) {}));
      }
    }

    void writeHandoff(String? chatId) {
      final seed = handoff;
      final store = _handoffs;
      if (seed == null || store == null) return;
      if (chatId == null && seed.supersededStreamId == null) return;
      store.writeQueued(
        QueuedSendHandoffState(
          seed: seed.copyWith(chatId: chatId),
          workspaceId: state.workspaceId,
          userMessageId: userMessageId,
          payload: payload,
          requestedAt: _nowMs,
          admissionUnknown: admissionUnknown,
        ),
      );
    }

    if (handoff != null) writeHandoff(handoff.chatId);

    final persistedUser = _persistedUser(userMessageId, payload, mode);
    _pendingUserPersisted = persistedUser;
    final optimisticUser = ChatMessage(
      id: userMessageId,
      role: ChatRole.user,
      requestMode: mode,
      content: payload.content,
      attachments: [
        for (final f
            in payload.fileAttachments ?? const <FileAttachmentForApi>[])
          ChatMessageAttachment(
            id: f.id,
            filename: f.filename,
            mediaType: f.mediaType,
            size: f.size,
            previewUrl: mothershipAttachmentPreviewUrl(
              key: f.key,
              mediaType: f.mediaType,
            ),
          ),
      ],
      contexts: payload.contexts?.isEmpty ?? true ? null : payload.contexts,
    );
    final optimisticAssistant = ChatMessage(
      id: assistantId,
      role: ChatRole.assistant,
      requestMode: mode,
      content: '',
      contentBlocks: const [],
    );

    void applyOptimistic() {
      final chatId = requestChatId;
      if (chatId != null) {
        _queries.cancelQueries(MothershipChatKeys.detail(chatId));
        _upsertHistory(
          chatId,
          (current) => current.copyWith(
            resources: [
              for (final r in current.resources)
                if (r['id'] != 'streaming-file') r,
            ],
            messages: [
              for (final m in current.messages)
                if (m.id != userMessageId && m.id != assistantId) m,
              persistedUser,
              PersistedMessage(id: assistantId, role: 'assistant', content: ''),
            ],
            activeStreamId: userMessageId,
          ),
        );
      }
      _liveUser = optimisticUser;
      _liveAssistant = optimisticAssistant;
      _overlayStreamId = userMessageId;
      _emitMessages();
    }

    void rollback() {
      final chatId = requestChatId;
      if (chatId != null) {
        _upsertHistory(
          chatId,
          (current) => MothershipChatHistory(
            id: current.id,
            title: current.title,
            mode: current.mode,
            messages: [
              for (final m in current.messages)
                if (m.id != userMessageId && m.id != assistantId) m,
            ],
            activeStreamId: current.activeStreamId == userMessageId
                ? null
                : current.activeStreamId,
            resources: current.resources,
            effort: current.effort,
            olderCursor: current.olderCursor,
            windowStartCursor: current.windowStartCursor,
          ),
        );
      }
      if (_liveUser?.id == userMessageId) {
        _liveUser = null;
        _liveAssistant = null;
        _overlayStreamId = null;
      }
      _emitMessages();
    }

    int? gen;
    _Admission? admission;
    void beginSend() {
      gen = ++_gen;
      _locallyTerminalStreamId = null;
      _streamId = userMessageId;
      _lastCursor = '0';
      _logResyncedStreamId = null;
      _resetStreamingBuffers();
      // A send that waited for a stop already shows its optimistic pair.
      if (_liveUser?.id == userMessageId) _liveAssistant = optimisticAssistant;
      _liveAssistantId = assistantId;
      _turn = _Turn(
        userMessageId: userMessageId,
        assistantMessageId: assistantId,
        pendingChatKey: _pendingChatKey,
      );
      final abort = _Abort();
      _abort = abort;
      admission = _Admission(
        userMessageId: userMessageId,
        chatKey: _chatKey,
        abort: abort,
        payload: payload,
      );
      _pendingAdmission = admission;
      _emitState(state.copyWith(streamId: userMessageId));
    }

    if (stop == null && !(handoff?.stopRequired ?? false)) beginSend();
    applyOptimistic();
    onOptimisticSendApplied?.call();
    consumed = true;

    String? streamTargetChatId;
    try {
      if (stop != null || (handoff?.stopRequired ?? false)) {
        try {
          if (stop != null) {
            await stop;
          } else {
            final predecessor = handoff?.supersededStreamId;
            if (predecessor == null) {
              throw StateError(
                'The previous response could not be identified.',
              );
            }
            final stopped = await _client.abort(
              streamId: predecessor,
              workspaceId: state.workspaceId,
              chatId: requestChatId,
            );
            if (!stopped.settled) {
              throw StateError('Previous response is still shutting down.');
            }
          }
          if (handoff != null) {
            handoff = handoff.copyWith(stopRequired: false);
            writeHandoff(requestChatId);
          }
          if (requestChatId == null) {
            requestChatId =
                handoff?.chatId ?? (handoff == null ? _chatId : null);
            if (requestChatId == null && pendingStopStreamId != null) {
              final resolved = await _resolveChatIdForStream(
                pendingStopStreamId,
                preferExisting: false,
              );
              if (resolved != null) {
                if (_chatId == null || _chatId == resolved) {
                  _adoptChat(resolved);
                }
                requestChatId = resolved;
              }
            }
            if (requestChatId != null) writeHandoff(requestChatId);
          }
          if ((handoff != null || pendingStopStreamId != null) &&
              requestChatId == null) {
            throw StateError(
              'Cannot send queued message until the active chat is known.',
            );
          }
          if (handoff != null &&
              requestChatId != null &&
              _chatId != null &&
              _chatId != requestChatId) {
            throw StateError(
              'Queued message was restored because the selected chat changed.',
            );
          }
          applyOptimistic();
        } on Object catch (error) {
          if (handoff != null) _handoffs?.clearClaim(handoff.id);
          rollback();
          if (_reader == null && _abort == null) {
            _turn = null;
            _setTransportIdle();
          }
          _setError(
            error is StateError
                ? error.message
                : 'Failed to stop the previous response',
          );
          return SendWithdrawal(
            userMessageId: userMessageId,
            reason: WithdrawalReason.stopFailed,
            admissionUnknown: admissionUnknown,
          );
        }
      }

      streamTargetChatId = requestChatId;
      if (admission == null) beginSend();
      final admitted = admission!;
      final sendGen = gen!;
      final abort = admitted.abort;

      final modelSettings = mode == 'assistant'
          ? null
          : resolveMothershipModelSettings(
              modelSelection: _effortStoreFor(mode).modelSelection,
              advanced: modelSelectorEnabled,
              plan: mode == 'plan',
            );
      admissionUnknown = true;
      writeHandoff(requestChatId);
      final MothershipSendStream response;
      try {
        response = await _client.send(
          MothershipSendRequest(
            message: payload.content,
            workspaceId: state.workspaceId,
            userMessageId: userMessageId,
            chatId: requestChatId,
            fileAttachments: payload.fileAttachments ?? const [],
            resourceAttachments: mode == 'assistant'
                ? null
                : _nonEmpty(resourceAttachments?.call()),
            contexts: payload.contexts ?? const [],
            mode: payload.requestMode,
            assistantSearch: payload.assistantSearch,
            assistantSearchLevel: payload.assistantSearchLevel,
            workflowId: workflowId,
            userTimezone: _timeZone(),
            modelSelection: modelSettings?.modelSelection?.toJson(),
            effort: effortChoice,
          ),
          cancelToken: abort.token,
        );
      } on MothershipSendRejected catch (rejected) {
        reachedServer = true;
        admitted.settle(null);
        if (identical(_pendingAdmission, admitted)) _pendingAdmission = null;
        return await _onRejected(
          rejected,
          gen: sendGen,
          abort: abort,
          userMessageId: userMessageId,
          assistantId: assistantId,
          requestChatId: requestChatId,
          handoff: handoff,
          pendingStopStreamId: pendingStopStreamId,
          admissionUnknown: admissionUnknown,
          rollback: rollback,
          consumed: consumed,
          onAdoptChat: (chatId) {
            adoptNewChatEffort(chatId, admittedThisSend: false);
            streamTargetChatId = chatId;
          },
          streamTargetChatId: () => streamTargetChatId,
        );
      } on ApiNetworkError {
        failedAtNetwork = true;
        rethrow;
      }
      reachedServer = true;
      final admittedChatId = response.chatId ?? requestChatId;
      admitted.settle(admittedChatId);
      if (identical(_pendingAdmission, admitted)) _pendingAdmission = null;
      if (_gen != sendGen) {
        unawaited(response.bytes.listen(null).cancel());
        return consumed;
      }
      if (requestChatId == null && admittedChatId != null) {
        adoptNewChatEffort(admittedChatId, admittedThisSend: true);
        requestChatId = admittedChatId;
        streamTargetChatId = admittedChatId;
        _pendingUserPersisted = persistedUser;
        _seedNewChat(admittedChatId);
      }
      final traceparent = response.traceparent;
      if (traceparent != null) {
        _traceparent = traceparent;
        final traceId = response.traceId;
        if (traceId != null) {
          callbacks.onRequestStarted?.call(traceId, userMessageId);
        }
      }
      if (handoff != null) _handoffs?.clearQueued(handoff.id);

      final result = await _processBytes(
        response.bytes,
        sendGen,
        targetChatId: streamTargetChatId,
      );
      if (_gen == sendGen) {
        if (result.sawStreamError) {
          _finalize(error: true, targetChatId: streamTargetChatId);
          return consumed;
        }
        if (result.sawComplete) {
          _finalize(targetChatId: streamTargetChatId);
          return consumed;
        }
        await _resumeOrFinalize(
          streamId: _streamId ?? userMessageId,
          gen: sendGen,
          afterCursor: _lastCursor.isEmpty ? '0' : _lastCursor,
          abort: abort,
          targetChatId: streamTargetChatId,
        );
        if (_gen == sendGen && _sending) {
          _finalize(targetChatId: streamTargetChatId);
        }
      }
      return consumed;
    } on Object catch (error) {
      final sendAbort = admission?.abort;
      final aborted =
          error is ApiCancelledError ||
          error is _Aborted ||
          (sendAbort?.aborted ?? false);
      if (aborted) {
        if (sendAbort?.reason == 'unmount:client_cleanup' && !reachedServer) {
          rollback();
          return SendWithdrawal(
            userMessageId: userMessageId,
            reason: WithdrawalReason.withdrawn,
            admissionUnknown: admissionUnknown,
          );
        }
        return consumed;
      }
      if (error is MothershipStreamSchemaError) {
        _setError(error.message);
        if (gen != null && _gen == gen) {
          _finalize(error: true, targetChatId: streamTargetChatId);
        }
        return consumed;
      }
      if (!reachedServer) {
        rollback();
        if (gen != null && _gen == gen) {
          _gen++;
          admission?.abort.abort('send_unreachable:no_response');
          _abort = null;
          _turn = null;
          _setTransportIdle();
        }
        final retryLater = failedAtNetwork && _isOnline();
        _setError(
          failedAtNetwork
              ? 'Message not sent: Sim could not be reached. ${retryLater ? 'Retrying.' : 'It will send when you are back online.'}'
              : _messageOf(error, 'Failed to send message'),
        );
        return SendWithdrawal(
          userMessageId: userMessageId,
          reason: retryLater
              ? WithdrawalReason.unreachable
              : WithdrawalReason.offline,
          admissionUnknown: admissionUnknown,
        );
      }
      final activeStream = _streamId;
      if (activeStream != null && gen != null && _gen == gen) {
        final ok = await _retryReconnect(
          streamId: activeStream,
          gen: gen!,
          targetChatId: streamTargetChatId,
        );
        if (ok) return consumed;
      }
      _setError(_messageOf(error, 'Failed to send message'));
      if (gen != null && _gen == gen) {
        _finalize(
          error: true,
          streamTerminal: false,
          targetChatId: streamTargetChatId,
        );
      }
      return consumed;
    } finally {
      admission?.settle(null);
      if (identical(_pendingAdmission, admission)) _pendingAdmission = null;
    }
  }

  static List<Map<String, Object?>>? _nonEmpty(
    List<Map<String, Object?>>? list,
  ) => list == null || list.isEmpty ? null : list;

  static String _messageOf(Object error, String fallback) => switch (error) {
    StateError(:final message) => message,
    ApiClientError(:final message) => message,
    ApiNetworkError(:final message) => message,
    SseIdleTimeoutError() => error.toString(),
    _ => fallback,
  };

  /// The 409 and other non-2xx branches of `startSendMessage`
  /// (`U:4025-4155`).
  Future<Object> _onRejected(
    MothershipSendRejected rejected, {
    required int gen,
    required _Abort abort,
    required String userMessageId,
    required String assistantId,
    required String? requestChatId,
    required QueuedSendHandoffSeed? handoff,
    required String? pendingStopStreamId,
    required bool admissionUnknown,
    required void Function() rollback,
    required bool consumed,
    required void Function(String chatId) onAdoptChat,
    required String? Function() streamTargetChatId,
  }) async {
    // The user moved on (stop, another chat) while the POST was out: only a
    // conflict still matters, it re-queues the message in its own chat.
    if (_gen != gen && !rejected.isConflict) return consumed;
    if (!rejected.isConflict) {
      _setError(rejected.displayMessage);
      _finalize(error: true, targetChatId: streamTargetChatId());
      return consumed;
    }
    final conflict = rejected.activeStreamId;
    final viewOnSend = _gen == gen;
    final superseded = handoff?.supersededStreamId ?? pendingStopStreamId;
    void release(String reason) {
      rollback();
      if (_gen == gen) {
        _gen++;
        abort.abort(reason);
        _abort = null;
        _turn = null;
        _setTransportIdle();
      }
    }

    if (superseded != null &&
        conflict == superseded &&
        conflict != userMessageId) {
      release('queued_handoff:superseded_conflict');
      if (viewOnSend) {
        _setError(
          'Previous response is still shutting down; queued message was restored.',
        );
      }
      return SendWithdrawal(
        userMessageId: userMessageId,
        reason: WithdrawalReason.stopFailed,
        admissionUnknown: false,
      );
    }
    if (conflict != userMessageId) {
      release('send_conflict:chat_busy');
      if (requestChatId != null && conflict != null) {
        _upsertHistory(
          requestChatId,
          (current) => current.copyWith(activeStreamId: conflict),
        );
      }
      if (viewOnSend) {
        unawaited(recoverActiveStream(BrowserReturnReason.busyRefusal));
      } else if (requestChatId != null) {
        unawaited(
          _queries.invalidateQueries(
            MothershipChatKeys.detail(requestChatId),
            refetchActive: false,
          ),
        );
      }
      return SendWithdrawal(
        userMessageId: userMessageId,
        reason: WithdrawalReason.busy,
        admissionUnknown: false,
      );
    }
    // A duplicate: the earlier attempt's stream must exist.
    bool exists;
    try {
      await _fetchBatch(userMessageId, '0', abort: abort);
      exists = true;
    } on Object catch (error) {
      exists = error is! MothershipStreamGoneError && abort.aborted;
    }
    if (!exists) {
      release('send_conflict:chat_busy');
      return SendWithdrawal(
        userMessageId: userMessageId,
        reason: WithdrawalReason.busy,
        admissionUnknown: admissionUnknown,
      );
    }
    if (_gen != gen) return consumed;
    final conflictChat = rejected.chatId;
    if (conflictChat != null && streamTargetChatId() == null) {
      onAdoptChat(conflictChat);
      _adoptChat(conflictChat, invalidateList: true);
    }
    _streamId = userMessageId;
    final ok = await _retryReconnect(
      streamId: userMessageId,
      gen: gen,
      targetChatId: streamTargetChatId(),
    );
    if (!ok && _gen == gen) {
      _finalize(error: true, targetChatId: streamTargetChatId());
    }
    return consumed;
  }

  // ---------------------------------------------------------------------------
  // Stop (`stopGeneration`, `U:4642-4937`).

  /// Stops the running turn: local effects at once (reader cancelled, abort,
  /// idle, the live message marked stopped), then within 15 s the abort POST
  /// (retried once when not settled), the stop-persist POST when it was
  /// sending, and the invalidations. Re-entrant: a second call joins the
  /// pending stop.
  Future<void> stop({StopMode mode = StopMode.normal}) {
    final pending = _pendingStop;
    if (pending != null) {
      if (mode == StopMode.queuedHandoff &&
          _pendingStopMode != StopMode.queuedHandoff) {
        return Future.error(
          StateError(
            'Previous response is already stopping; queued message was restored.',
          ),
        );
      }
      return pending;
    }
    final completer = Completer<void>();
    final operation = completer.future..ignore();
    _pendingStop = operation;
    _pendingStopMode = mode;
    unawaited(
      _runStop(mode)
          .then(
            (_) => completer.complete(),
            onError: (Object error, StackTrace stack) {
              completer.completeError(error, stack);
            },
          )
          .whenComplete(() {
            if (identical(_pendingStop, operation)) {
              _pendingStop = null;
              _pendingStopMode = null;
            }
            _scheduleDrain();
          }),
    );
    return operation;
  }

  Future<void> _runStop(StopMode mode) async {
    final admission = _hasPendingAdmission ? _pendingAdmission : null;
    final wasSending = _sending || admission != null;
    var activeChatId = _chatId;
    final sid =
        _streamId ??
        _turn?.userMessageId ??
        admission?.userMessageId ??
        _history?.activeStreamId;
    if (mode == StopMode.queuedHandoff && activeChatId == null && sid == null) {
      const message =
          'Cannot send queued message until the active chat is known.';
      _setError(message);
      throw StateError(message);
    }
    final requestId = _requestId;
    final traceparent = _traceparent;
    final now = _nowMs;
    _locallyTerminalStreamId = sid;
    final stoppedGen = ++_gen;
    _turn = null;
    _reader?.cancel();
    _reader = null;
    final controller = _abort;
    if (!identical(controller, admission?.abort)) {
      controller?.abort('user_stop:client_stopGeneration');
    }
    _abort = null;
    // Text a paced flush still held belongs to the stopped answer.
    if (_flushTimer != null) _rebuildLiveAssistant();
    _flushTimer?.cancel();
    _flushTimer = null;
    _setTransportIdle();
    final blocks = _liveAssistant?.contentBlocks;
    if (_liveAssistant != null && blocks != null) {
      _liveAssistant = _liveAssistant!.copyWith(
        contentBlocks: markBlocksStopped(blocks, nowMs: now),
      );
      _writeLiveAssistant();
    }
    _emitMessages();

    var abortSucceeded = false;
    Future<void> barrier() async {
      var stopSucceeded = false;
      try {
        var resolvedChatId = activeChatId;
        var settled = false;
        Future<bool> postAbort(String? chatId) async {
          if (sid == null) return true;
          final result = await _client.abort(
            streamId: sid,
            workspaceId: state.workspaceId,
            chatId: chatId,
            traceparent: traceparent,
          );
          abortSucceeded = true;
          return result.settled;
        }

        Object? abortFailure;
        final abortFuture = sid == null
            ? Future<void>.value()
            : postAbort(resolvedChatId).then(
                (value) => settled = value,
                onError: (Object error) => abortFailure = error,
              );
        Object? stopFailure;
        try {
          if (admission != null && admission.userMessageId == sid) {
            final admittedChat = await admission.settled.future;
            resolvedChatId ??= admittedChat;
            admission.abort.abort('user_stop:client_stopGeneration');
          }
          if (resolvedChatId == null && sid != null) {
            resolvedChatId = await _resolveChatIdForStream(
              sid,
              preferExisting: false,
            );
            if (resolvedChatId == null && mode == StopMode.queuedHandoff) {
              throw StateError(
                'Cannot send queued message until the active chat is known.',
              );
            }
          }
          if (resolvedChatId != null) {
            activeChatId = resolvedChatId;
            if (_gen == stoppedGen &&
                (_chatId == null || _chatId == resolvedChatId)) {
              _adoptChat(resolvedChatId);
            }
          }
          if (wasSending && resolvedChatId != null && sid != null) {
            await _client.persistStop(
              chatId: resolvedChatId,
              streamId: sid,
              requestId: requestId,
              traceparent: traceparent,
            );
          }
        } on Object catch (error) {
          stopFailure = error;
        }
        await abortFuture;
        if (sid != null && !settled) {
          try {
            final retried = await postAbort(resolvedChatId);
            settled = retried;
            abortFailure = retried
                ? null
                : StateError('Previous response is still shutting down.');
          } on Object catch (error) {
            abortFailure = error;
          }
        }
        if (stopFailure != null || abortFailure != null) {
          final failure = stopFailure ?? abortFailure!;
          Error.throwWithStackTrace(failure, StackTrace.current);
        }
        stopSucceeded = true;
        if (_gen == stoppedGen) {
          _notifyTurnEnded(
            error: false,
            skipQueueDispatch: mode == StopMode.queuedHandoff,
          );
        }
      } finally {
        _invalidateChat(
          includeDetail: mode != StopMode.queuedHandoff || !stopSucceeded,
          targetChatId: activeChatId,
        );
      }
    }

    try {
      await barrier().timeout(ChatTimings.stopRequestTimeout);
    } on Object catch (error) {
      if (sid != null && !abortSucceeded && _locallyTerminalStreamId == sid) {
        _locallyTerminalStreamId = null;
      }
      if (activeChatId != null) _invalidateChat();
      if (_gen == stoppedGen) {
        _setError(
          error is StateError
              ? error.message
              : error is TimeoutException
              ? 'Failed to stop the previous response'
              : _messageOf(error, 'Failed to stop the previous response'),
        );
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Chat switching.

  /// Shows [chatId] on this surface (`U:1843-1931`): a running stream is
  /// detached (generation bumped, reader cancelled, idle) without a server
  /// cancel, and the abandoned chat's detail is invalidated.
  void selectChat(String? chatId) {
    if (chatId == _chatId) return;
    final abandoned = _chatId;
    if (_sending || _reader != null) {
      _gen++;
      _reader?.cancel();
      _reader = null;
      _turn = null;
      _abort = null;
      _setTransportIdle();
      if (abandoned != null) _invalidateChat(targetChatId: abandoned);
    }
    // `cancelActiveStreamRecovery` + `clearActiveTurn`: nothing of the old
    // chat's stream (a paced flush, the live ids, the cursor) carries over.
    _recovery?.abort.abort('chat_switch');
    _recovery = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _turn = null;
    _pendingUserPersisted = null;
    _streamId = null;
    _traceparent = null;
    _lastCursor = '0';
    _locallyTerminalStreamId = null;
    _liveAssistantId = null;
    _resetStreamingBuffers();
    _liveUser = null;
    _liveAssistant = null;
    _overlayStreamId = null;
    _history = null;
    _appliedHydrationKey = null;
    unawaited(_historySub?.cancel());
    _historySub = null;
    _historyQuery?.dispose();
    _historyQuery = null;
    if (chatId == null) {
      _pendingChatKey = '$pendingChatKeyPrefix${_newId()}';
      _emitState(
        ChatSessionState(workspaceId: state.workspaceId),
      );
      _onQueueChanged();
      return;
    }
    _emitState(
      ChatSessionState(workspaceId: state.workspaceId, chatId: chatId),
    );
    _observeHistory(chatId);
    _onQueueChanged();
  }

  // ---------------------------------------------------------------------------
  // Queue.

  void _onQueueChanged() {
    if (isClosed) return;
    final key = _chatKey;
    _emitState(
      state.copyWith(
        queue: _queue.queue(key),
        editingQueuedId: _queue.editing[key],
        clearEditing: _queue.editing[key] == null,
      ),
    );
    _scheduleDrain();
  }

  void _discardAcceptedQueuedSends(MothershipChatHistory history) {
    if (history.id != _chatKey) return;
    final accepted = acceptedMessageIds(history);
    for (final queued in _queue.queue(history.id)) {
      if (_dispatchIds.contains(queued.id)) continue;
      final requestId = queued.resumeUserMessageId;
      if (requestId == null || !accepted.contains(requestId)) continue;
      _discard(history.id, queued.id);
    }
  }

  void _discard(String chatKey, String id) {
    _queue.remove(chatKey, id);
    _handoffs
      ?..clearQueued(id)
      ..clearClaim(id);
  }

  /// The auto-drain effect (`U:5353-5380`).
  void _scheduleDrain() {
    if (isClosed) return;
    final queue = _queue.queue(_chatKey);
    if (queue.isEmpty || queue.first.hold != null) return;
    final notBefore = queue.first.retry?.notBefore;
    if (notBefore != null && notBefore > _nowMs) {
      _retryWakeup?.cancel();
      _retryWakeup = Timer(
        Duration(milliseconds: notBefore - _nowMs),
        _scheduleDrain,
      );
      return;
    }
    if (_sending || _pendingStop != null) return;
    if (_dispatchTask != null) return;
    if (_chatId != null && _history == null) return;
    if (_history?.activeStreamId != null && _chatId != null) return;
    _enqueueDispatch();
  }

  void _enqueueDispatch() {
    _dispatchActions.add(_dispatchEpoch);
    unawaited(_runDispatchLoop());
  }

  Future<void> _runDispatchLoop() {
    final running = _dispatchTask;
    if (running != null) return running;
    final task = () async {
      while (_dispatchActions.isNotEmpty && !isClosed) {
        final epoch = _dispatchActions.removeAt(0);
        if (epoch != _dispatchEpoch) continue;
        if (_hasPendingAdmission) continue;
        final key = _chatKey;
        final queue = _queue.queue(key);
        if (queue.isEmpty) continue;
        final message = queue.first;
        if (message.hold != null) continue;
        final retry = message.retry;
        if (retry != null && retry.notBefore > _nowMs) continue;
        if (_queue.editing[key] == message.id) continue;
        final verdict = await _checkResend(key, message);
        if (verdict != ResendVerdict.send) {
          _applyResendVerdict(key, message, verdict);
          continue;
        }
        await _dispatchQueued(message, epoch: epoch);
      }
    }();
    _dispatchTask = task;
    return task.whenComplete(() {
      if (identical(_dispatchTask, task)) _dispatchTask = null;
      if (_dispatchActions.isNotEmpty && !isClosed) {
        unawaited(_runDispatchLoop());
      }
    });
  }

  Future<ResendVerdict> _checkResend(
    String chatKey,
    QueuedMessage message,
  ) async {
    if (!needsResendCheck(message) ||
        chatKey.startsWith(pendingChatKeyPrefix)) {
      return ResendVerdict.send;
    }
    MothershipChatHistory? history;
    try {
      history = await _client.chatHistory(chatKey);
    } on Object {
      history = null;
    }
    return resendVerdict(message, history);
  }

  void _applyResendVerdict(
    String chatKey,
    QueuedMessage message,
    ResendVerdict verdict,
  ) {
    if (_dispatchIds.contains(message.id)) return;
    if (verdict == ResendVerdict.drop) {
      _discard(chatKey, message.id);
      return;
    }
    _queue.deferRetry(
      chatKey,
      message.id,
      sendRetry(
        (message.retry?.attempt ?? 0) + 1,
        nowMs: _nowMs,
        random: _random,
      ),
    );
  }

  /// `dispatchQueuedMessage`.
  Future<void> _dispatchQueued(
    QueuedMessage message, {
    required int epoch,
    Future<void>? pendingStop,
    QueuedSendHandoffSeed? handoff,
  }) async {
    if (_dispatchIds.contains(message.id)) return;
    _dispatchIds.add(message.id);
    final dispatchKey = _chatKey;
    final atStart = _queue.queue(dispatchKey);
    final startIndex = atStart.indexWhere((m) => m.id == message.id);
    if (startIndex == -1) {
      _dispatchIds.remove(message.id);
      return;
    }
    var aheadIds = [for (final m in atStart.take(startIndex)) m.id];
    _dispatchingHeadId = message.id;
    _emitState(state.copyWith(dispatchingHeadId: message.id));
    var removed = false;
    var dispatched = message;
    void removeFromQueue() {
      if (removed || epoch != _dispatchEpoch) return;
      removed = true;
      _queue.remove(_queue.liveQueueKey(dispatchKey), message.id);
    }

    void restore(QueuedSendHandoffSeed? seed, SendWithdrawal? withdrawn) {
      final position = _queue.liveQueuePosition(dispatchKey, aheadIds);
      final chatless = position.chatKey.startsWith(pendingChatKeyPrefix);
      final saved = _handoffs?.readQueued();
      final restoredRequestId =
          withdrawn?.userMessageId ??
          (saved?.id == message.id ? saved?.userMessageId : null);
      final retained = saved?.id == message.id ? saved?.seed : seed;
      _handoffs?.clearClaim(message.id);
      if (!removed) return;
      final epochMoved = epoch != _dispatchEpoch;
      if (epochMoved &&
          (withdrawn == null ||
              (withdrawn.reason == WithdrawalReason.stopFailed && isClosed))) {
        return;
      }
      if (_removedDuringDispatch.remove(message.id)) {
        _handoffs?.clearQueued(message.id);
        return;
      }
      if (withdrawn?.reason == WithdrawalReason.withdrawn && chatless) {
        _handoffs?.clearQueued(message.id);
        _handOffWithdrawnSend(dispatched, withdrawn!.userMessageId);
        return;
      }
      _handoffs?.clearQueued(message.id);
      var entry = requeued(
        dispatched,
        withdrawn == null
            ? RequeueReason.failed
            : requeueReasonOf(withdrawn.reason),
        previousAttempts: dispatched.retry?.attempt ?? 0,
        nowMs: _nowMs,
        chatlessSurface: chatless ? _heldSurface : null,
        random: _random,
      );
      if (retained != null) entry = entry.copyWith(queuedSendHandoff: retained);
      if (restoredRequestId != null) {
        entry = entry.copyWith(resumeUserMessageId: restoredRequestId);
      }
      if (withdrawn != null) {
        entry = entry.copyWith(admissionUnknown: withdrawn.admissionUnknown);
      }
      _queue.insertAt(position.chatKey, position.index, entry);
    }

    var activeHandoff = handoff ?? message.queuedSendHandoff;
    try {
      final atSend = _queue.queue(dispatchKey);
      final index = atSend.indexWhere((m) => m.id == message.id);
      if (index == -1) return;
      aheadIds = [for (final m in atSend.take(index)) m.id];
      final live = atSend[index];
      dispatched = live;
      activeHandoff = handoff ?? live.queuedSendHandoff;
      final result = await _startSend(
        live,
        resumeUserMessageId: live.resumeUserMessageId,
        admissionUnknownHint: live.admissionUnknown,
        queuedSendHandoff: activeHandoff,
        pendingStop: pendingStop,
        onOptimisticSendApplied: removeFromQueue,
      );
      if (result != true) {
        restore(activeHandoff, result is SendWithdrawal ? result : null);
      }
    } on Object {
      restore(activeHandoff, null);
    } finally {
      if (_dispatchingHeadId == message.id) {
        _dispatchingHeadId = null;
        _emitState(state.copyWith(clearDispatching: true));
      }
      _dispatchIds.remove(message.id);
      _removedDuringDispatch.remove(message.id);
    }
  }

  /// Removes a queued message (a dispatch in flight will not restore it).
  void removeFromQueue(String id) {
    if (_dispatchIds.contains(id)) _removedDuringDispatch.add(id);
    _discard(_chatKey, id);
  }

  /// Puts the message in the composer for editing; refused for one the
  /// server may already hold (`admissionUnknown`) or mid-dispatch.
  QueuedMessage? editQueuedMessage(String id) {
    if (_dispatchIds.contains(id)) return null;
    final message = _queue.queue(_chatKey).where((m) => m.id == id).firstOrNull;
    if (message == null || (message.admissionUnknown ?? false)) return null;
    _handoffs
      ?..clearQueued(id)
      ..clearClaim(id);
    _queue.setEditing(_chatKey, id);
    return message;
  }

  void cancelQueueEdit() {
    _queue.setEditing(_chatKey, null);
    if (!_sending && _pendingStop == null) _enqueueDispatch();
  }

  /// "Send now": drops the head when history shows it accepted, else stops
  /// the running turn (`queued-handoff`) and dispatches it.
  Future<void> sendNow([String? id]) async {
    final key = _chatKey;
    final queue = _queue.queue(key);
    final message = id == null
        ? queue.firstOrNull
        : queue.where((m) => m.id == id).firstOrNull;
    if (message == null || _queue.editing[key] == message.id) return;
    if (_dispatchIds.contains(message.id)) return;
    if (await _checkResend(key, message) == ResendVerdict.drop) {
      _applyResendVerdict(key, message, ResendVerdict.drop);
      return;
    }
    if (_chatKey != key ||
        isClosed ||
        _dispatchIds.contains(message.id) ||
        _queue.editing[key] == message.id ||
        !_queue.queue(key).any((m) => m.id == message.id)) {
      return;
    }
    final admissionPending = _hasPendingAdmission;
    _dispatchActions.clear();
    final handoff =
        message.queuedSendHandoff ??
        (_sending || _pendingStop != null || admissionPending
            ? QueuedSendHandoffSeed(
                id: message.id,
                chatId: _chatId,
                supersededStreamId:
                    _streamId ??
                    _turn?.userMessageId ??
                    (admissionPending
                        ? _pendingAdmission?.userMessageId
                        : null) ??
                    _history?.activeStreamId,
              )
            : null);
    final pendingStop = _sending || admissionPending
        ? stop(mode: StopMode.queuedHandoff)
        : _pendingStop;
    await _dispatchQueued(
      message,
      epoch: _dispatchEpoch,
      pendingStop: pendingStop,
      handoff: handoff,
    );
  }

  // ---------------------------------------------------------------------------
  // Tool permission.

  /// Records a permission decision for [toolCallIds] (one card or the bulk
  /// row); see `ToolPermissionStore.decide` for the card-side state.
  Future<List<ToolPermissionResult>> decideToolPermission(
    List<String> toolCallIds,
    ToolPermissionDecision decision,
  ) => _client.decideToolPermissions({
    for (final id in toolCallIds) id: decision,
  });

  // ---------------------------------------------------------------------------
  // Unmount.

  @override
  Future<void> close() async {
    final deadKey = _chatKey;
    if (deadKey.startsWith(pendingChatKeyPrefix)) {
      final withdrawing = _pendingAdmission;
      if (withdrawing != null &&
          withdrawing.chatKey == deadKey &&
          identical(_abort, withdrawing.abort) &&
          _queue.queue(deadKey).isNotEmpty) {
        final send = withdrawing.payload;
        _queue.insertAt(
          deadKey,
          0,
          QueuedMessage(
            id: _newId(),
            content: send.content,
            fileAttachments: send.fileAttachments,
            contexts: send.contexts,
            requestMode: send.requestMode,
            assistantSearch: send.assistantSearch,
            assistantSearchLevel: send.assistantSearchLevel,
            resumeUserMessageId: withdrawing.userMessageId,
            admissionUnknown: true,
          ),
        );
        _withdrawnHeldAtUnmount.add(withdrawing.userMessageId);
      }
      _queue.holdForSurface(deadKey, _heldSurface);
    }
    _recovery?.abort.abort('unmount');
    _dispatchActions.clear();
    _dispatchEpoch++;
    _gen++;
    _reader?.cancel();
    _abort?.abort('unmount:client_cleanup');
    _abort = null;
    _persistedWait?.abort.abort('unmount:persisted_turn_wait');
    _turn = null;
    _sending = false;
    _queue
      ..setEditing(deadKey, null)
      ..removeListener(_onQueueChanged);
    _flushTimer?.cancel();
    _exhaustedRecheck?.cancel();
    _retryWakeup?.cancel();
    await _returnsSub?.cancel();
    await _onlineSub?.cancel();
    await _historySub?.cancel();
    _historyQuery?.dispose();
    await _resourceEvents.close();
    return super.close();
  }
}

extension on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}
