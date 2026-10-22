/// Phase 1.5 stand-ins for the three Home slots (`slots.dart`) until the
/// chat engine, the message renderer and the composer are plugged in. They
/// keep the geometry of the real pieces (the composer box is 104px tall in
/// the hero and 80px in the footer, `chat-input.md`) so the page layout,
/// its goldens and its parity ids are already right.
library;

import 'package:flutter/material.dart' show InputDecoration, TextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/slots.dart';
import 'package:sim_design/sim_design.dart';

/// One message of the placeholder transcript.
@immutable
class PlaceholderMessage {
  const PlaceholderMessage({required this.role, required this.content});

  /// `user` or `assistant`.
  final String role;
  final String content;
}

/// A local, backend-less [HomeChatSession]: sends append the user message,
/// nothing streams, nothing persists. Its mutators let tests and previews
/// drive every state Home renders.
class PlaceholderChatSession extends ChangeNotifier implements HomeChatSession {
  PlaceholderChatSession(this.request) : _chatId = request.chatId;

  /// [HomeChatSessionFactory] of the placeholder.
  static HomeChatSession create(HomeSessionRequest request) =>
      PlaceholderChatSession(request);

  final HomeSessionRequest request;
  String? _chatId;
  bool _historyPending = false;
  bool _sending = false;
  final List<PlaceholderMessage> messages = <PlaceholderMessage>[];
  List<HomeResource> _resources = const <HomeResource>[];
  List<HomeQueuedMessage> _queue = const <HomeQueuedMessage>[];
  String? _editingQueuedId;
  String? _dispatchingHeadId;
  bool _disposed = false;

  /// Every message passed to [sendMessage], with its request mode.
  final List<(HomeOutgoingMessage, HomeRequestMode?)> sent =
      <(HomeOutgoingMessage, HomeRequestMode?)>[];
  int stops = 0;

  bool get isDisposed => _disposed;

  @override
  String? get chatId => _chatId;

  @override
  bool get isHistoryPending => _historyPending;

  @override
  bool get isSending => _sending;

  @override
  bool get isReconnecting => false;

  @override
  int get messageCount => messages.length;

  @override
  List<HomeResource> get resources => _resources;

  @override
  List<HomeQueuedMessage> get queuedMessages => _queue;

  @override
  String? get editingQueuedId => _editingQueuedId;

  @override
  String? get dispatchingHeadId => _dispatchingHeadId;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void sendMessage(
    HomeOutgoingMessage message, {
    HomeRequestMode? requestMode,
  }) {
    sent.add((message, requestMode));
    messages.add(PlaceholderMessage(role: 'user', content: message.text));
    _changed();
  }

  @override
  Future<void> stopGeneration() async {
    stops++;
    setSending(sending: false);
  }

  @override
  void addResource(HomeResource resource) {
    if (_resources.any((r) => r.selectionId == resource.selectionId)) return;
    _resources = <HomeResource>[..._resources, resource];
    _changed();
  }

  @override
  void removeResource(HomeResource resource) {
    _resources = <HomeResource>[
      for (final r in _resources)
        if (!(r.type == resource.type && r.id == resource.id)) r,
    ];
    _changed();
  }

  @override
  void reorderResources(List<HomeResource> ordered) {
    _resources = List<HomeResource>.unmodifiable(ordered);
    _changed();
  }

  @override
  void removeQueuedMessage(String id) {
    _queue = <HomeQueuedMessage>[
      for (final m in _queue)
        if (m.id != id) m,
    ];
    if (_editingQueuedId == id) _editingQueuedId = null;
    _changed();
  }

  @override
  Future<void> sendQueuedNow(String id) async {
    final message = _queue.where((m) => m.id == id).firstOrNull;
    if (message == null) return;
    removeQueuedMessage(id);
    sendMessage(HomeOutgoingMessage(text: message.content));
  }

  @override
  HomeQueuedMessage? editQueuedMessage(String id) {
    final message = _queue.where((m) => m.id == id).firstOrNull;
    if (message == null ||
        message.admissionUnknown ||
        id == _dispatchingHeadId) {
      return null;
    }
    _editingQueuedId = id;
    _changed();
    return message;
  }

  @override
  void cancelQueueEdit() {
    _editingQueuedId = null;
    _changed();
  }

  /// Sources the placeholder reports for every message.
  HomeCitedSources sources = const HomeCitedSources();

  @override
  HomeCitedSources citedSources(String messageId, String? requestId) => sources;

  // Test and preview drivers.

  /// The engine adopted [id] for this new chat.
  void adoptChatId(String id) {
    _chatId = id;
    request.callbacks.onChatResolved(id);
    _changed();
  }

  void setHistoryPending({required bool pending}) {
    _historyPending = pending;
    _changed();
  }

  void setSending({required bool sending}) {
    _sending = sending;
    _changed();
  }

  void setMessages(List<PlaceholderMessage> next) {
    messages
      ..clear()
      ..addAll(next);
    _changed();
  }

  void setResources(List<HomeResource> next) {
    _resources = List<HomeResource>.unmodifiable(next);
    _changed();
  }

  void setQueue(
    List<HomeQueuedMessage> next, {
    String? editingId,
    String? dispatchingId,
  }) {
    _queue = List<HomeQueuedMessage>.unmodifiable(next);
    _editingQueuedId = editingId;
    _dispatchingHeadId = dispatchingId;
    _changed();
  }

  /// A stream `resource` event for [resource] (added when missing).
  void emitResourceEvent(HomeResource resource, {bool activate = true}) {
    if (!_resources.any((r) => r.selectionId == resource.selectionId)) {
      _resources = <HomeResource>[..._resources, resource];
      _changed();
    }
    request.callbacks.onResourceEvent(
      resource.selectionId,
      activate: activate,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The placeholder transcript: the user and assistant texts in the 704px
/// column, without markdown or tool rows.
Widget buildPlaceholderTranscript(
  BuildContext context,
  HomeTranscriptProps props,
) => _PlaceholderTranscript(props: props);

class _PlaceholderTranscript extends StatelessWidget {
  const _PlaceholderTranscript({required this.props});

  final HomeTranscriptProps props;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final session = props.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final messages = session is PlaceholderChatSession
            ? session.messages
            : <PlaceholderMessage>[
                for (var i = 0; i < session.messageCount; i++)
                  const PlaceholderMessage(role: 'assistant', content: '…'),
              ];
        return ListView.builder(
          padding: props.padding,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final user = message.role == 'user';
            final text = Text(
              message.content,
              style: sim.text.inter(14, color: c.textPrimary),
            );
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: props.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Align(
                    alignment: user
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: user
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: c.surface5,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: text,
                          )
                        : text,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// The placeholder composer: the `chat-input.root` box (border, 16px
/// radius, white / `--surface-4`, ambient shadow in the hero) with a plain
/// text field and a send button, 104px tall in the hero and 80px in the
/// footer like the real `UserInput`.
Widget buildPlaceholderComposer(
  BuildContext context,
  HomeComposerProps props,
) => PlaceholderComposer(props: props);

class PlaceholderComposer extends StatefulWidget {
  const PlaceholderComposer({required this.props, super.key});

  final HomeComposerProps props;

  @override
  State<PlaceholderComposer> createState() => _PlaceholderComposerState();
}

class _PlaceholderComposerState extends State<PlaceholderComposer>
    implements HomeComposerHandle {
  late final TextEditingController _text = TextEditingController(
    text: widget.props.initialPrompt,
  );
  final FocusNode _focus = FocusNode(debugLabel: 'PlaceholderComposer');

  @override
  void initState() {
    super.initState();
    widget.props.controller.attach(this);
  }

  @override
  void didUpdateWidget(PlaceholderComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.props.controller, widget.props.controller)) {
      oldWidget.props.controller.detach(this);
      widget.props.controller.attach(this);
    }
  }

  @override
  void dispose() {
    widget.props.controller.detach(this);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void populatePrompt(String prompt) {
    _text.value = TextEditingValue(
      text: prompt,
      selection: TextSelection.collapsed(offset: prompt.length),
    );
    _focus.requestFocus();
  }

  @override
  void loadQueuedMessage(HomeQueuedMessage message) =>
      populatePrompt(message.content);

  void _submit() {
    final text = _text.text;
    widget.props.onSubmit(HomeOutgoingMessage(text: text));
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final hero = widget.props.variant == HomeComposerVariant.hero;
    return Semantics(
      identifier: 'chat-input.root',
      container: true,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 704),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: sim.isDark ? c.surface4 : SimColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: hero ? sim.shadows.ambient : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: hero ? 56 : 32),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    const SingleActivator(LogicalKeyboardKey.enter): _submit,
                  },
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    maxLines: null,
                    style: sim.text.inter(14, color: c.textPrimary),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Ask Sim anything',
                      hintStyle: sim.text.inter(14, color: c.textMuted),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 30,
              child: Row(
                children: <Widget>[
                  if (widget.props.requestMode != null)
                    Text(
                      widget.props.requestMode == HomeRequestMode.plan
                          ? 'Plan'
                          : 'Agent',
                      style: sim.text.small.copyWith(color: c.textSecondary),
                    ),
                  const Spacer(),
                  SimButton(
                    variant: SimButtonVariant.ghost,
                    size: SimButtonSize.sm,
                    width: 28,
                    height: 28,
                    padding: EdgeInsets.zero,
                    semanticsLabel: widget.props.isSending
                        ? 'Stop generating'
                        : 'Send message',
                    onPressed: widget.props.isSending
                        ? widget.props.onStop
                        : _submit,
                    child: SimIcon(
                      widget.props.isSending
                          ? SimEmcnIcons.stopFilled
                          : SimEmcnIcons.arrowUp,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
