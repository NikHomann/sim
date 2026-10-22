/// The Home session slot over the chat engine: one [ChatSessionCubit] per
/// Home mount (`useChat`), plus the resource strip state React keeps in the
/// hook (`resources`, hydrated from the chat detail and updated by the
/// stream's `resource` events and the panel's add/remove/reorder).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/input/model/chat_context.dart';
import 'package:sim_app/features/chat/input/model/composer_models.dart';
import 'package:sim_app/features/chat/integration/chat_integration.dart';
import 'package:sim_app/features/chat/integration/tool_display.dart'
    show isKnownCliToolName;
import 'package:sim_app/features/chat/messages/markdown/special_tags.dart'
    show collectMessageSources;
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/slots.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/http_chats_source.dart';

/// `HomeChatContext` of an engine context map (`resolveResourceFromContext`
/// reads these ids).
HomeChatContext homeContextOf(Map<String, Object?> context) {
  String? str(String key) {
    final value = context[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  return HomeChatContext(
    kind: str('kind') ?? '',
    label: str('label') ?? '',
    resourceId:
        str('workflowId') ??
        str('knowledgeId') ??
        str('tableId') ??
        str('fileId') ??
        str('dashboardId'),
    resourceName: str('fileName') ?? str('tableName'),
  );
}

/// A resource map of the chat detail or a stream event → [HomeResource];
/// `null` for a type the panel does not know.
HomeResource? homeResourceOf(Map<String, Object?> json) {
  final type = HomeResourceType.fromWire(json['type'] as String?);
  final id = json['id'];
  if (type == null || id is! String || id.isEmpty) return null;
  final title = json['title'];
  final workspaceId = json['workspaceId'];
  final executionId = json['executionId'];
  final sources = json['sources'];
  return HomeResource(
    type: type,
    id: id,
    title: title is String ? title : '',
    workspaceId: workspaceId is String ? workspaceId : null,
    executionId: executionId is String ? executionId : null,
    sourcesMessageId: sources is Map && sources['messageId'] is String
        ? sources['messageId'] as String
        : null,
    sourcesRequestId: sources is Map && sources['requestId'] is String
        ? sources['requestId'] as String
        : null,
  );
}

Map<String, Object?> _resourceJson(HomeResource r) => {
  'type': r.type.wire,
  'id': r.id,
  'title': r.title,
  'workspaceId': ?r.workspaceId,
  'executionId': ?r.executionId,
  if (r.sourcesMessageId != null)
    'sources': {
      'messageId': r.sourcesMessageId,
      'requestId': ?r.sourcesRequestId,
    },
};

/// The engine's send payload of a Home message: the composer's own
/// submission when the composer slot attached it, else the Home fields.
SendPayload sendPayloadOf(
  HomeOutgoingMessage message, {
  HomeRequestMode? requestMode,
}) {
  final submission = message.payload;
  final mode = requestMode?.name;
  if (submission is ComposerSubmission) {
    return SendPayload(
      content: message.text,
      fileAttachments: submission.fileAttachments.isEmpty
          ? null
          : [
              for (final f in submission.fileAttachments)
                FileAttachmentForApi.fromJson(f.toJson()),
            ],
      contexts: submission.contexts.isEmpty
          ? null
          : [for (final c in submission.contexts) c.toJson()],
      requestMode: mode,
    );
  }
  return SendPayload(
    content: message.text,
    contexts: message.contexts.isEmpty
        ? null
        : [
            for (final c in message.contexts)
              {
                'kind': c.kind,
                'label': c.label,
                if (c.resourceId != null)
                  switch (c.kind) {
                    'knowledge' => 'knowledgeId',
                    'table' || 'table_selection' => 'tableId',
                    'file' || 'file_selection' => 'fileId',
                    'dashboard' => 'dashboardId',
                    _ => 'workflowId',
                  }: c.resourceId,
              },
          ],
    requestMode: mode,
  );
}

/// The composer's view of a queued engine message (`loadQueuedMessage`).
ComposerQueuedMessage composerQueuedMessageOf(QueuedMessage message) =>
    ComposerQueuedMessage(
      content: message.content,
      contexts: [
        for (final c in message.contexts ?? const <Map<String, Object?>>[])
          ?ChatContext.fromJson(c),
      ],
      fileAttachments: [
        for (final f
            in message.fileAttachments ?? const <FileAttachmentForApi>[])
          ?ComposerFileAttachment.fromJson(f.toJson()),
      ],
    );

/// [HomeChatSession] over a [ChatSessionCubit].
class CubitHomeChatSession extends ChangeNotifier implements HomeChatSession {
  CubitHomeChatSession(this.request, this.integration) {
    final callbacks = request.callbacks;
    cubit = ChatSessionCubit(
      client: integration.client,
      queryClient: integration.queries,
      queueStore: integration.queue,
      effortStore: integration.effort,
      planEffortStore: integration.planEffort,
      handoffs: integration.handoffs,
      workspaceId: request.workspaceId,
      chatId: request.chatId,
      // Home marks the chat read itself (`HomeServices.markRead`).
      markChatRead: false,
      isKnownCliToolName: isKnownCliToolName,
      idGenerator: integration.idGenerator,
      isOnline: integration.isOnline,
      browserReturns: integration.browserReturns,
      onlineEvents: integration.onlineEvents,
      resourceAttachments: _resourceAttachments,
      callbacks: ChatSessionCallbacks(
        onChatResolved: (chatId, _) {
          _flushPendingResources(chatId);
          sharedChatsSource?.invalidate(request.workspaceId);
          callbacks.onChatResolved(chatId);
        },
        onTitleUpdate: () => sharedChatsSource?.invalidate(request.workspaceId),
      ),
    );
    integration.attachSession(cubit);
    _state = cubit.stream.listen(_onState);
    _events = cubit.resourceEvents.listen(_onResourceEvent);
    _onState(cubit.state);
  }

  /// [HomeChatSessionFactory] of the real session.
  static HomeChatSessionFactory factory(
    ChatIntegration Function() integration,
  ) =>
      (request) => CubitHomeChatSession(request, integration());

  final HomeSessionRequest request;
  final ChatIntegration integration;
  late final ChatSessionCubit cubit;
  late final StreamSubscription<ChatSessionState> _state;
  late final StreamSubscription<ChatResourceEvent> _events;
  bool _disposed = false;

  List<HomeResource> _resources = const [];

  /// Resources added before the chat existed (persisted once it does).
  final List<HomeResource> _pendingResources = [];
  String? _hydratedFrom;
  List<Map<String, Object?>>? _hydratedRaw;

  ChatSessionState get state => cubit.state;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  MothershipChatHistory? _history() {
    final chatId = cubit.state.chatId;
    if (chatId == null) return null;
    return integration.queries.getQueryData<MothershipChatHistory>(
      MothershipChatKeys.detail(chatId),
    );
  }

  void _onState(ChatSessionState state) {
    _hydrateResources();
    _changed();
  }

  /// `hydrateChatResources`: the chat detail's stored resources replace the
  /// strip whenever the stored list changes; ephemeral panels stay.
  void _hydrateResources() {
    final history = _history();
    if (history == null) return;
    if (_hydratedFrom == history.id &&
        identical(_hydratedRaw, history.resources)) {
      return;
    }
    _hydratedFrom = history.id;
    _hydratedRaw = history.resources;
    final stored = [
      for (final raw in history.resources) ?homeResourceOf(raw),
    ];
    final ephemeral = [
      for (final r in _resources)
        if (r.isEphemeral && !stored.any((s) => s.key == r.key)) r,
    ];
    final pending = [
      for (final r in _pendingResources)
        if (!stored.any((s) => s.key == r.key)) r,
    ];
    _resources = List.unmodifiable([...stored, ...pending, ...ephemeral]);
  }

  /// `handleResourceEvent`: `upsert` adds or retitles the tab and reports it
  /// to Home; `remove` drops it. Read-only upserts, search, settings and
  /// view-only ops are not ported (no panel content for them yet).
  void _onResourceEvent(ChatResourceEvent event) {
    final payload = event.payload;
    if (payload is! ResourceEventPayload) return;
    final resource = homeResourceOf(payload.resource);
    if (resource == null) return;
    switch (payload.op) {
      case 'upsert':
        if (payload.readOnly) return;
        final index = _resources.indexWhere((r) => r.key == resource.key);
        _resources = List.unmodifiable([
          if (index < 0) ...[
            ..._resources,
            resource,
          ] else
            for (final r in _resources)
              r.key == resource.key && resource.title.isNotEmpty
                  ? r.copyWith(title: resource.title)
                  : r,
        ]);
        _changed();
        request.callbacks.onResourceEvent(
          resource.selectionId,
          activate: !event.replay && !payload.replay,
        );
      case 'remove':
        _resources = List.unmodifiable([
          for (final r in _resources)
            if (r.key != resource.key) r,
        ]);
        _changed();
    }
  }

  /// `buildResourceAttachments`: open resources with the active flag.
  List<Map<String, Object?>> _resourceAttachments() {
    final active = request.callbacks.activeResourceId();
    return [
      for (final r in _resources)
        if (r.type != HomeResourceType.terminal &&
            r.type != HomeResourceType.sources &&
            r.type != HomeResourceType.browser)
          {..._resourceJson(r), 'active': r.selectionId == active},
    ];
  }

  void _flushPendingResources(String chatId) {
    final pending = List<HomeResource>.of(_pendingResources);
    _pendingResources.clear();
    for (final r in pending) {
      unawaited(
        integration.api
            .addResource(chatId, _resourceJson(r))
            .catchError((_) {}),
      );
    }
  }

  @override
  String? get chatId => cubit.state.chatId;

  @override
  bool get isHistoryPending =>
      cubit.state.chatId != null &&
      (cubit.state.historyStatus == ChatHistoryStatus.loading ||
          cubit.state.historyStatus == ChatHistoryStatus.none);

  @override
  bool get isSending => cubit.state.isSending;

  @override
  bool get isReconnecting => cubit.state.isReconnecting;

  @override
  int get messageCount => cubit.state.messages.length;

  @override
  List<HomeResource> get resources => _resources;

  @override
  List<HomeQueuedMessage> get queuedMessages => [
    for (final m in cubit.state.queue)
      HomeQueuedMessage(
        id: m.id,
        content: m.content,
        attachments: [
          for (final f in m.fileAttachments ?? const <FileAttachmentForApi>[])
            HomeAttachment(filename: f.filename, id: f.id),
        ],
        contexts: [
          for (final c in m.contexts ?? const <Map<String, Object?>>[])
            homeContextOf(c),
        ],
        admissionUnknown: m.admissionUnknown ?? false,
        payload: m,
      ),
  ];

  @override
  String? get editingQueuedId => cubit.state.editingQueuedId;

  @override
  String? get dispatchingHeadId => cubit.state.dispatchingHeadId;

  @override
  void sendMessage(
    HomeOutgoingMessage message, {
    HomeRequestMode? requestMode,
  }) {
    if (requestMode != null) cubit.requestMode = requestMode.name;
    unawaited(
      cubit.sendMessage(sendPayloadOf(message, requestMode: requestMode)),
    );
  }

  @override
  Future<void> stopGeneration() => cubit.stop();

  @override
  void addResource(HomeResource resource) {
    if (_resources.any((r) => r.key == resource.key)) return;
    _resources = List.unmodifiable([..._resources, resource]);
    _changed();
    if (resource.isEphemeral) return;
    final chatId = this.chatId;
    if (chatId == null) {
      _pendingResources.add(resource);
      return;
    }
    _writeDetailResources(chatId, _resources);
    unawaited(
      integration.api
          .addResource(chatId, _resourceJson(resource))
          .catchError((_) {}),
    );
  }

  @override
  void removeResource(HomeResource resource) {
    final address = resource.key;
    _resources = List.unmodifiable([
      for (final r in _resources)
        if (!(r.type == resource.type && r.id == resource.id)) r,
    ]);
    _pendingResources.removeWhere((r) => r.key == address);
    _changed();
    final chatId = this.chatId;
    if (resource.isEphemeral || chatId == null) return;
    _writeDetailResources(chatId, _resources);
    unawaited(
      integration.api
          .removeResource(chatId, {
            'resourceType': resource.type.wire,
            'resourceId': resource.id,
            'workspaceId': ?resource.workspaceId,
          })
          .catchError((_) {}),
    );
  }

  @override
  void reorderResources(List<HomeResource> ordered) {
    _resources = List.unmodifiable(ordered);
    _changed();
    final chatId = this.chatId;
    if (chatId == null) return;
    final persisted = [
      for (final r in ordered)
        if (!r.isEphemeral) r,
    ];
    _writeDetailResources(chatId, persisted);
    unawaited(
      integration.api
          .reorderResources(chatId, [
            for (final r in persisted) _resourceJson(r),
          ])
          .catchError((_) {}),
    );
  }

  /// Mirrors a strip change into the cached chat detail so a later
  /// hydration does not restore the old list (`applyResourceEffect`).
  void _writeDetailResources(String chatId, List<HomeResource> resources) {
    final key = MothershipChatKeys.detail(chatId);
    final current = integration.queries.getQueryData<MothershipChatHistory>(
      key,
    );
    if (current == null) return;
    final raw = [
      for (final r in resources)
        if (!r.isEphemeral) _resourceJson(r),
    ];
    final next = current.copyWith(resources: raw);
    _hydratedRaw = raw;
    integration.queries.setQueryData<MothershipChatHistory>(key, next);
  }

  @override
  void removeQueuedMessage(String id) => cubit.removeFromQueue(id);

  @override
  Future<void> sendQueuedNow(String id) => cubit.sendNow(id);

  @override
  HomeQueuedMessage? editQueuedMessage(String id) {
    final message = cubit.editQueuedMessage(id);
    if (message == null) return null;
    return queuedMessages.where((m) => m.id == id).firstOrNull ??
        HomeQueuedMessage(id: id, content: message.content, payload: message);
  }

  @override
  void cancelQueueEdit() => cubit.cancelQueueEdit();

  @override
  HomeCitedSources citedSources(String messageId, String? requestId) {
    final state = cubit.state;
    if (state.historyStatus == ChatHistoryStatus.error) {
      return const HomeCitedSources(failed: true);
    }
    final message = state.messages
        .where(
          (m) =>
              m.id == messageId ||
              (requestId != null && m.requestId == requestId),
        )
        .firstOrNull;
    if (message == null) {
      return HomeCitedSources(
        loading: state.historyStatus != ChatHistoryStatus.ready,
      );
    }
    final texts = [
      for (final b in message.contentBlocks ?? const <ContentBlock>[])
        if (b.type == ContentBlockType.text && b.content != null) b.content!,
    ];
    final sources = collectMessageSources(
      texts.isEmpty ? [message.content] : texts,
    );
    return HomeCitedSources(
      sources: [
        for (final s in sources)
          HomeSource(url: s.url, title: s.title, siteName: s.siteName),
      ],
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    integration.detachSession(cubit);
    unawaited(_state.cancel());
    unawaited(_events.cancel());
    unawaited(cubit.close());
    super.dispose();
  }
}
