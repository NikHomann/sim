/// The workspace-scoped chat seam the shell mounts: the `task_status`
/// events cubit (`useMothershipChatEvents`, mounted with the sidebar in
/// React), its effect on the sidebar chat list (refetch on every owner-list
/// invalidation, running dots before the refetch lands) and, off the web,
/// stream recovery when the app window resumes (the engine's browser-return
/// signals exist only on web).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/integration/chat_integration.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/http_chats_source.dart';

/// Registered next to a test's own [MothershipClient] so the shell mounts
/// the chat seams without an HTTP client.
class ChatClientOverride {
  const ChatClientOverride();
}

/// Where the events go besides the cubit (the sidebar's chat source).
abstract interface class ChatListSink {
  void invalidate(String workspaceId);
  void setRunning(String workspaceId, Set<String> chatIds);
}

class _HttpChatsSink implements ChatListSink {
  const _HttpChatsSink(this.source);
  final HttpChatsSource source;

  @override
  void invalidate(String workspaceId) => source.invalidate(workspaceId);

  @override
  void setRunning(String workspaceId, Set<String> chatIds) =>
      source.setRunning(workspaceId, chatIds);
}

/// Mounts a [ChatEventsCubit] for [workspaceId] while the chat integration
/// is registered and Chat is enabled; renders [child] unchanged.
class ChatEventsHost extends StatefulWidget {
  const ChatEventsHost({
    required this.workspaceId,
    required this.child,
    this.integration,
    this.sink,
    this.recoverOnResume,
    super.key,
  });

  final String workspaceId;
  final Widget child;

  /// Defaults to the locator's (none: the host is inert).
  final ChatIntegration? integration;

  /// Defaults to the shared sidebar chat source.
  final ChatListSink? sink;

  /// Defaults to off the web only.
  final bool? recoverOnResume;

  @override
  State<ChatEventsHost> createState() => ChatEventsHostState();
}

class ChatEventsHostState extends State<ChatEventsHost> {
  ChatEventsCubit? _cubit;
  StreamSubscription<ChatEventsState>? _subscription;
  AppLifecycleListener? _lifecycle;
  int _generation = 0;

  @visibleForTesting
  ChatEventsCubit? get cubit => _cubit;

  /// The integration, or `null` when none is registered or it cannot be
  /// built (no backend client: VM tests of the shell).
  ChatIntegration? get _integration {
    final given = widget.integration;
    if (given != null) return given;
    if (!locator.isRegistered<ChatIntegration>() ||
        (!locator.isRegistered<SimHttpClient>() && !_clientOverridden)) {
      return null;
    }
    try {
      return locator<ChatIntegration>();
    } on Object {
      return null;
    }
  }

  /// A test registered its own [MothershipClient] (the default one needs
  /// the HTTP client).
  static bool get _clientOverridden =>
      locator.isRegistered<MothershipClient>() &&
      locator.isRegistered<ChatClientOverride>();

  ChatListSink? get _sink {
    final sink = widget.sink;
    if (sink != null) return sink;
    final source = sharedChatsSource;
    return source == null ? null : _HttpChatsSink(source);
  }

  bool get _chatEnabled =>
      !locator.isRegistered<DeploymentShapeCubit>() ||
      locator<DeploymentShapeCubit>().state.shape.chatEnabled;

  @override
  void initState() {
    super.initState();
    _mount();
    if (widget.recoverOnResume ?? !kIsWeb) {
      _lifecycle = AppLifecycleListener(
        onResume: () => _integration?.recoverActiveStreams(
          BrowserReturnReason.visible,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(ChatEventsHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) {
      _unmount();
      _mount();
    }
  }

  void _mount() {
    final integration = _integration;
    if (integration == null || !_chatEnabled) return;
    final ChatEventsCubit cubit;
    try {
      cubit = ChatEventsCubit(
        client: integration.client,
        queryClient: integration.queries,
        queueStore: integration.queue,
        workspaceId: widget.workspaceId,
      );
    } on Object catch (error) {
      debugPrint('chat events unavailable: $error');
      return;
    }
    _cubit = cubit;
    _generation = cubit.state.listGeneration;
    final workspaceId = widget.workspaceId;
    _subscription = cubit.stream.listen((state) {
      final sink = _sink;
      if (sink == null) return;
      if (state.listGeneration != _generation) {
        _generation = state.listGeneration;
        sink.invalidate(workspaceId);
      }
      sink.setRunning(workspaceId, state.runningChatIds);
    });
    cubit.start();
  }

  void _unmount() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    final cubit = _cubit;
    _cubit = null;
    if (cubit != null) unawaited(cubit.close());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _unmount();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
