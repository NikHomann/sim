/// The real Home slots: the engine session ([CubitHomeChatSession]), the
/// renderer's [ChatTranscript] fed by the view mapper, and the
/// [ChatComposer] wired to the engine's stores.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/input/chat_composer.dart';
import 'package:sim_app/features/chat/integration/chat_integration.dart';
import 'package:sim_app/features/chat/integration/home_chat_session.dart';
import 'package:sim_app/features/chat/integration/inline_image.dart';
import 'package:sim_app/features/chat/integration/message_view_mapper.dart';
import 'package:sim_app/features/chat/integration/tool_display.dart'
    show ToolTitleContext;
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_transcript.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/placeholder_slots.dart';
import 'package:sim_app/features/home/slots.dart';
import 'package:sim_design/sim_design.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Home slots over [integration] (resolved lazily, once per session).
HomeSlots integratedHomeSlots(ChatIntegration Function() integration) =>
    HomeSlots(
      session: CubitHomeChatSession.factory(integration),
      transcript: (context, props) => IntegratedHomeTranscript(props: props),
      composer: (context, props) =>
          IntegratedHomeComposer(props: props, integration: integration()),
    );

SimToasts _toasts() => locator.isRegistered<SimToasts>()
    ? locator<SimToasts>()
    : SimToasts.instance;

ToolPermissionDecision _decision(ChatPermissionDecision d) => switch (d) {
  ChatPermissionDecision.allow => ToolPermissionDecision.allow,
  ChatPermissionDecision.allowChat => ToolPermissionDecision.allowChat,
  ChatPermissionDecision.alwaysAllow => ToolPermissionDecision.alwaysAllow,
  ChatPermissionDecision.skip => ToolPermissionDecision.skip,
};

HomeResourceType? _resourceType(ChatResourceKind kind) => switch (kind) {
  ChatResourceKind.workflow => HomeResourceType.workflow,
  ChatResourceKind.table => HomeResourceType.table,
  ChatResourceKind.dashboard => HomeResourceType.dashboard,
  ChatResourceKind.file => HomeResourceType.file,
  ChatResourceKind.knowledge => HomeResourceType.knowledgebase,
  ChatResourceKind.folder => HomeResourceType.folder,
  ChatResourceKind.integration => HomeResourceType.integration,
  _ => null,
};

/// The transcript slot.
class IntegratedHomeTranscript extends StatefulWidget {
  const IntegratedHomeTranscript({required this.props, super.key});

  final HomeTranscriptProps props;

  @override
  State<IntegratedHomeTranscript> createState() =>
      _IntegratedHomeTranscriptState();
}

class _IntegratedHomeTranscriptState extends State<IntegratedHomeTranscript> {
  final ChatTranscriptController _controller = ChatTranscriptController();
  final Set<String> _expired = {};
  String? _lastUserId;
  ChatMessageCallbacks? _callbacks;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CubitHomeChatSession? get _session {
    final session = widget.props.session;
    return session is CubitHomeChatSession ? session : null;
  }

  Future<ChatPermissionOutcome> _permission(
    List<String> ids,
    ChatPermissionDecision decision,
  ) async {
    final session = _session;
    if (session == null) return ChatPermissionOutcome.failed;
    try {
      await session.cubit.decideToolPermission(ids, _decision(decision));
      return ChatPermissionOutcome.accepted;
    } on ApiClientError catch (error) {
      if (error.status == 404) {
        if (mounted) setState(() => _expired.addAll(ids));
        return ChatPermissionOutcome.expired;
      }
    } on Object {
      // Falls through to the toast.
    }
    _toasts().error(toolPermissionErrorToast);
    return ChatPermissionOutcome.failed;
  }

  void _feedback(
    String messageId, {
    required bool positive,
    required String text,
  }) {
    final session = _session;
    if (session == null) return;
    final messages = session.state.messages;
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    final userQuery = messages
        .take(index)
        .lastWhere((m) => m.isUser, orElse: () => messages[index])
        .content;
    unawaited(
      session.integration.api
          .feedback({
            'chatId': session.chatId,
            'userQuery': userQuery,
            'agentResponse': messages[index].content,
            'isPositiveFeedback': positive,
            'feedback': text,
          })
          .catchError((_) {}),
    );
  }

  Future<void> _fork(String messageId) async {
    final session = _session;
    final chatId = session?.chatId;
    if (session == null || chatId == null) return;
    try {
      final result = await session.integration.client.forkChat(
        chatId,
        upToMessageId: messageId,
      );
      if (result.failedFileCopies.isNotEmpty) {
        _toasts().warning('Some files could not be copied to the new chat');
      }
      if (!mounted) return;
      GoRouter.maybeOf(
        context,
      )?.go('/workspace/${widget.props.workspaceId}/chat/${result.id}');
    } on ApiClientError catch (error) {
      _toasts().error(
        error.status == 409 || error.status == 413
            ? error.message
            : 'Failed to fork chat',
      );
    } on Object {
      _toasts().error('Failed to fork chat');
    }
  }

  void _openLink(String href) {
    if (href.startsWith('/workspace/')) {
      GoRouter.maybeOf(context)?.go(href);
      return;
    }
    final session = _session;
    final http = session?.integration.http;
    final url = href.startsWith('/') && http != null
        ? http.resolveUrl(href)
        : href;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    unawaited(
      launchUrl(
        uri,
        webOnlyWindowName: href.startsWith('mailto:') ? '_self' : '_blank',
      ).catchError((_) => false),
    );
  }

  void _resource(ChatResourceView view) {
    final type = _resourceType(view.kind);
    if (type == null) return;
    widget.props.onResourceRef(
      HomeResourceRef(
        type: type,
        title: view.displayTitle,
        id: view.id,
        path: view.path,
      ),
    );
  }

  void _viewSources(String messageId) {
    final message = _session?.state.messages
        .where((m) => m.id == messageId)
        .firstOrNull;
    widget.props.onViewSources(messageId, message?.requestId);
  }

  void _option(String id) =>
      _session?.sendMessage(HomeOutgoingMessage(text: id));

  /// Workflow names for `run_workflow`-style titles
  /// (`resolveWorkflowNameForDisplay` reads the workflow registry).
  ToolTitleContext get _titleContext {
    final workflows = locator.isRegistered<WorkflowsCubit>()
        ? locator<WorkflowsCubit>()
        : null;
    return ToolTitleContext(
      workspaceId: widget.props.workspaceId,
      workflowName: workflows == null
          ? null
          : (id) => workflows.state.byId[id]?.name,
    );
  }

  ChatMessageCallbacks get _callbacksValue =>
      _callbacks ??= ChatMessageCallbacks(
        onOptionSelect: _option,
        onPermission: _permission,
        onFeedback: _feedback,
        onFork: _fork,
        onViewAllSources: _viewSources,
        onOpenLink: _openLink,
        onResourceSelect: _resource,
        resolveMessageImageUrl: _imageUrl,
      );

  /// `privateImageUrls`: inline file references load the turn's private
  /// snapshot (`/api/mothership/chats/{chatId}/images/{requestId}`).
  String? _imageUrl(String src, String? requestId) => resolveChatImageUrl(
    src,
    chatId: _session?.state.chatId,
    requestId: requestId,
  );

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return buildPlaceholderTranscript(context, widget.props);
    }
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final state = session.state;
        final messages = state.messages;
        final lastUser = messages.lastWhere(
          (m) => m.isUser,
          orElse: () =>
              const ChatMessage(id: '', role: ChatRole.user, content: ''),
        );
        if (lastUser.id.isNotEmpty && lastUser.id != _lastUserId) {
          final first = _lastUserId == null;
          _lastUserId = lastUser.id;
          if (!first) _controller.jumpToBottom();
        }
        final views = mapChatMessages(
          messages,
          ChatViewContext(
            chatId: state.chatId,
            isSending: state.isSending,
            expiredPermissionIds: Set.unmodifiable(_expired),
            titleContext: _titleContext,
          ),
        );
        return ChatTranscript(
          messages: views,
          chatId: state.chatId,
          isLoading: session.isHistoryPending,
          isStreaming: state.isSending,
          callbacks: _callbacksValue,
          controller: _controller,
        );
      },
    );
  }
}

ComposerMode _mode(HomeRequestMode? mode) =>
    mode == HomeRequestMode.plan ? ComposerMode.plan : ComposerMode.agent;

HomeChatContext _homeContext(ChatContext c) => homeContextOf(c.toJson());

/// The composer slot.
class IntegratedHomeComposer extends StatefulWidget {
  const IntegratedHomeComposer({
    required this.props,
    required this.integration,
    super.key,
  });

  final HomeComposerProps props;
  final ChatIntegration integration;

  @override
  State<IntegratedHomeComposer> createState() => _IntegratedHomeComposerState();
}

class _IntegratedHomeComposerState extends State<IntegratedHomeComposer>
    implements HomeComposerHandle {
  final ChatComposerController _composer = ChatComposerController();
  late final ComposerDraftStore _drafts = ComposerDraftStore(
    widget.integration.drafts,
  );
  ComposerContextSource? _contextSource;
  ComposerUploader? _uploader;
  String? _uploaderWorkspace;

  HomeComposerProps get props => widget.props;

  /// The chat of `draftScopeKey` (`<ws>:<chatId|new>`).
  String? get _chatId {
    final key = props.draftScopeKey;
    final prefix = '${props.workspaceId}:';
    final rest = key.startsWith(prefix) ? key.substring(prefix.length) : key;
    return rest == 'new' || rest.isEmpty ? null : rest;
  }

  @override
  void initState() {
    super.initState();
    props.controller.attach(this);
    widget.integration.effort.addListener(_onEffort);
    final http = widget.integration.http;
    if (http != null) _contextSource = HttpComposerContextSource(http);
  }

  @override
  void didUpdateWidget(IntegratedHomeComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.props.controller, props.controller)) {
      oldWidget.props.controller.detach(this);
      props.controller.attach(this);
    }
    if (!identical(oldWidget.integration.effort, widget.integration.effort)) {
      oldWidget.integration.effort.removeListener(_onEffort);
      widget.integration.effort.addListener(_onEffort);
    }
  }

  @override
  void dispose() {
    props.controller.detach(this);
    widget.integration.effort.removeListener(_onEffort);
    _composer.dispose();
    super.dispose();
  }

  void _onEffort() {
    if (mounted) setState(() {});
  }

  ComposerUploader? get _upload {
    final http = widget.integration.http;
    if (http == null) return null;
    if (_uploaderWorkspace != props.workspaceId) {
      _uploaderWorkspace = props.workspaceId;
      _uploader = HttpComposerUploader(
        UploadSessionClient(http),
        workspaceId: props.workspaceId,
      );
    }
    return _uploader;
  }

  @override
  void populatePrompt(String prompt) => _composer.populatePrompt(prompt);

  @override
  void loadQueuedMessage(HomeQueuedMessage message) {
    final queued = message.payload;
    _composer.loadQueuedMessage(
      queued is QueuedMessage
          ? composerQueuedMessageOf(queued)
          : ComposerQueuedMessage(content: message.content),
    );
  }

  /// The effort the chat runs at: the engine's pick, else the stored chat
  /// effort; the new-chat pick on a new chat.
  ComposerEffort? get _effort {
    final store = widget.integration.effort;
    final chatId = _chatId;
    if (chatId == null) return ComposerEffort.fromWire(store.newChatEffort);
    final stored = widget.integration.queries
        .getQueryData<MothershipChatHistory>(MothershipChatKeys.detail(chatId))
        ?.effort;
    return ComposerEffort.fromWire(store.chatEffort(chatId) ?? stored);
  }

  /// One effort path: the engine's store records every pick; an existing
  /// chat's pick is persisted with `PUT …/effort` and dropped again when
  /// that fails (the composer rolls back and toasts).
  Future<void> _setEffort(ComposerEffort effort) async {
    final integration = widget.integration;
    final store = integration.effort;
    final chatId = _chatId;
    if (chatId == null) {
      store.setNewChatEffort(effort.wire);
      return;
    }
    final pick = store.setChatEffort(chatId, effort.wire);
    try {
      await integration.client.setChatEffort(chatId, effort.wire);
    } on Object {
      store.dropChatEffort(chatId, pick);
      rethrow;
    }
  }

  ComposerModelSelection? get _modelSelection {
    final store = props.requestMode == HomeRequestMode.plan
        ? widget.integration.planEffort
        : widget.integration.effort;
    final selection = store.modelSelection;
    final model = ComposerModel.fromWire(selection.model);
    return model == null
        ? null
        : ComposerModelSelection(model: model, fastMode: selection.fastMode);
  }

  void _setModelSelection(ComposerModelSelection selection) {
    (props.requestMode == HomeRequestMode.plan
          ? widget.integration.planEffort
          : widget.integration.effort)
      ..setModel(selection.model.wire)
      ..setFastMode(fastMode: selection.fastMode);
  }

  void _submit(ComposerSubmission submission) {
    props.onSubmit(
      HomeOutgoingMessage(
        text: submission.text,
        attachments: [
          for (final f in submission.fileAttachments)
            HomeAttachment(filename: f.filename, id: f.id),
        ],
        contexts: [for (final c in submission.contexts) _homeContext(c)],
        payload: submission,
      ),
    );
  }

  bool _flag(String name) =>
      locator.isRegistered<FeatureFlagsCubit>() &&
      locator<FeatureFlagsCubit>().state.flag(name);

  @override
  Widget build(BuildContext context) {
    final hero = props.variant == HomeComposerVariant.hero;
    final http = widget.integration.http;
    final remove = props.onContextRemove;
    final onModeChanged = props.onRequestModeChanged;
    return ChatComposer(
      workspaceId: props.workspaceId,
      chatId: _chatId,
      variant: hero ? ComposerVariant.hero : ComposerVariant.conversation,
      controller: _composer,
      isStreaming: props.isSending,
      onSubmit: _submit,
      onStop: props.onStop,
      onSendQueuedHead: props.onSendQueuedHead,
      onEditQueuedTail: props.onEditQueuedTail,
      contextSource: _contextSource,
      uploader: _upload,
      draftStore: _drafts,
      mode: _mode(props.requestMode),
      onModeChange: props.requestMode == null || onModeChanged == null
          ? null
          : (mode) => onModeChanged(
              mode == ComposerMode.plan
                  ? HomeRequestMode.plan
                  : HomeRequestMode.agent,
            ),
      planModeEnabled: _flag('mothership-plan-mode'),
      modelSelectorEnabled: _flag('mothership-model-selector'),
      effort: _effort,
      onEffortChange: _setEffort,
      modelSelection: _modelSelection,
      onModelSelectionChange: _setModelSelection,
      onContextAdd: (c) => props.onContextAdd(_homeContext(c)),
      onContextRemove: remove == null
          ? null
          : (c, remaining) => remove(
              _homeContext(c),
              [for (final r in remaining) _homeContext(r)],
            ),
      toasts: _toasts(),
      resolveUrl: http?.resolveUrl,
      defaultValue: props.initialPrompt,
    );
  }
}
