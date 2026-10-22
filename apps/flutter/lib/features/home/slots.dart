/// The three slots the Home surface renders its chat through, and how a
/// build plugs implementations into them.
///
/// Home (`home-page.md`) owns the page: routing, the access boundary, the
/// hero, the conversation frame (scroll region, footer, queue tray,
/// skeleton) and the resource panel. Three neighbours are built
/// separately and plug in here:
///
/// * the **session** ([HomeChatSession], built by a
///   [HomeChatSessionFactory]): the chat engine's state for one mount
///   (`useChat`, `chat-engine.md`): messages, streaming flags, resources,
///   the queue, and the commands Home issues;
/// * the **transcript** ([HomeTranscriptBuilder]): the message rows inside
///   Home's `home.chat.scroll` region (`chat-messages.md`);
/// * the **composer** ([HomeComposerBuilder]): `UserInput` in its hero and
///   conversation variants (`chat-input.md`, outer box `chat-input.root`).
///
/// Every type crossing a slot is a Home model (`models.dart`), so the
/// engine, the renderer and the composer keep their own models and map at
/// the seam. [HomeSlots.placeholder] is what runs until the integration
/// step registers the real implementations (in the locator, or for a
/// subtree with [HomeSlotsScope]).
library;

import 'package:flutter/widgets.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/placeholder_slots.dart';

/// Callbacks a session reports to Home. Home builds them before the
/// session, so a session may call them from its constructor on.
@immutable
class HomeSessionCallbacks {
  const HomeSessionCallbacks({
    required this.onChatResolved,
    required this.onResourceEvent,
    required this.activeResourceId,
  });

  /// The engine adopted the id of the chat this mount created
  /// (`adoptResolvedChatId`, `chat-engine.md` 4.12). Home rewrites the URL
  /// in place to `/workspace/<ws>/chat/<id>` keeping `?resource=` (the
  /// `history.replaceState` of `chat-url.ts`) without remounting.
  final void Function(String chatId) onChatResolved;

  /// A stream `resource` event touched `resourceSelectionId`
  /// (`onResourceEvent`, `use-resource-panel.ts:96-128`); `activate` is the
  /// engine's `shouldActivateResourceEvent` verdict. Home decides whether
  /// that reveals the panel, activates the tab or marks activity.
  final void Function(String resourceSelectionId, {required bool activate})
  onResourceEvent;

  /// The selection `?resource=` holds (`activeResourceState`), which the
  /// engine sends as `activeResourceId` with each message.
  final String? Function() activeResourceId;
}

/// What Home passes when it opens a session.
@immutable
class HomeSessionRequest {
  const HomeSessionRequest({
    required this.workspaceId,
    required this.chatId,
    required this.callbacks,
  });

  final String workspaceId;

  /// The routed chat (`/chat/<id>`), or null on `/home` (a new chat).
  final String? chatId;
  final HomeSessionCallbacks callbacks;
}

/// The chat-engine state of one Home mount (`useChat`). Notifies its
/// listeners on every change Home renders. Home disposes it when the
/// mount ends (route change to another chat, or leaving Home).
abstract class HomeChatSession implements Listenable {
  /// The resolved chat id: the routed one, or the id the engine adopted
  /// after the first send; null for a new chat before that.
  String? get chatId;

  /// `isChatHistoryPending`: the routed chat's history has not loaded.
  bool get isHistoryPending;

  /// `isSending`: a turn is streaming (drives Stop and the queue).
  bool get isSending;

  /// `isReconnecting`.
  bool get isReconnecting;

  /// How many display messages the chat has (`messages.length`). Home only
  /// needs the count (hero vs conversation); the transcript slot reads the
  /// messages from the session itself.
  int get messageCount;

  /// The chat's resource tabs in strip order (`chat.resources`).
  List<HomeResource> get resources;

  /// The queued follow-ups (`messageQueue`), head first.
  List<HomeQueuedMessage> get queuedMessages;

  /// The queued message loaded into the composer for editing.
  String? get editingQueuedId;

  /// The queued message being dispatched right now.
  String? get dispatchingHeadId;

  /// `sendMessage(text, files, contexts)`; [requestMode] is set only for a
  /// new chat (`home.tsx:153`).
  void sendMessage(HomeOutgoingMessage message, {HomeRequestMode? requestMode});

  /// `stopGeneration`.
  Future<void> stopGeneration();

  /// `addResource` (optimistic; persisted with `POST
  /// /api/mothership/chat/resources` once the chat exists).
  void addResource(HomeResource resource);

  /// `removeResource` (`DELETE /api/mothership/chat/resources`).
  void removeResource(HomeResource resource);

  /// `reorderResources` (`PATCH /api/mothership/chat/resources`).
  void reorderResources(List<HomeResource> ordered);

  /// `removeFromQueue`.
  void removeQueuedMessage(String id);

  /// `sendNow`.
  Future<void> sendQueuedNow(String id);

  /// `editQueuedMessage`: marks [id] as being edited and returns the
  /// message to load into the composer, or null when editing is refused
  /// (dispatching, admission unknown).
  HomeQueuedMessage? editQueuedMessage(String id);

  /// `cancelQueueEdit`.
  void cancelQueueEdit();

  /// The cited sources of one assistant message, read from the chat history
  /// the session already holds (`SourcesResourceContent`: never a new
  /// provider search). Called on every rebuild of the `sources` tab.
  HomeCitedSources citedSources(String messageId, String? requestId);

  /// Ends the session (detaches a stream without cancelling it).
  void dispose();
}

/// One cited source (`SourceTagData`, reduced to what the panel lists).
@immutable
class HomeSource {
  const HomeSource({required this.url, this.title, this.siteName});

  final String url;
  final String? title;
  final String? siteName;
}

/// What the `sources` tab shows (`sources-resource-content.tsx:20-58`).
@immutable
class HomeCitedSources {
  const HomeCitedSources({
    this.sources = const <HomeSource>[],
    this.loading = false,
    this.failed = false,
  });

  final List<HomeSource> sources;

  /// History pending, or the message is in a page not loaded yet.
  final bool loading;

  /// History failed, or the older page holding the message failed.
  final bool failed;
}

typedef HomeChatSessionFactory =
    HomeChatSession Function(HomeSessionRequest request);

/// Geometry Home gives the transcript (`LAYOUT_STYLES['mothership-view']`,
/// `mothership-chat.tsx:150-162`): the scroll padding and the 704px sizer.
@immutable
class HomeTranscriptProps {
  const HomeTranscriptProps({
    required this.session,
    required this.workspaceId,
    required this.onViewSources,
    required this.onResourceRef,
    required this.onContextAdd,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 8),
    this.maxWidth = 704,
  });

  final HomeChatSession session;
  final String workspaceId;

  /// "View sources" on an assistant message: opens the `sources` tab
  /// (`home.tsx:473-481`).
  final void Function(String messageId, String? requestId) onViewSources;

  /// A resource chip inside an assistant message was clicked
  /// (`handleWorkspaceResourceSelect`, `home.tsx:368-401`): Home resolves
  /// it (a file by id, path or unique name, refetching the file list once)
  /// and opens its tab, or toasts why it cannot.
  final void Function(HomeResourceRef ref) onResourceRef;

  /// A chip added from a message (option rows insert contexts too).
  final void Function(HomeChatContext context) onContextAdd;

  /// `px-6 pt-4 pb-2` of the scroll container.
  final EdgeInsets padding;

  /// `max-w-chat` of the centred sizer.
  final double maxWidth;
}

/// Builds the transcript: a scrollable filling `home.chat.scroll` (Home
/// gives it the full region and the [HomeTranscriptProps] geometry; the
/// transcript owns scrolling, virtualisation and the 12px scroll fades).
typedef HomeTranscriptBuilder =
    Widget Function(BuildContext context, HomeTranscriptProps props);

/// The two composer layouts (`isInitialView`).
enum HomeComposerVariant { hero, conversation }

/// What Home asks of a mounted composer.
abstract class HomeComposerHandle {
  /// `populatePrompt`: mentionify bare integration names, set the text,
  /// focus with the caret at the end; never sends (`user-input.tsx:377-385`).
  void populatePrompt(String prompt);

  /// `loadQueuedMessage`: put a queued message into the editor for editing.
  void loadQueuedMessage(HomeQueuedMessage message);
}

/// Routes Home's commands to whichever composer is mounted.
class HomeComposerController {
  HomeComposerHandle? _handle;

  /// The composer registers itself when it mounts.
  // ignore: use_setters_to_change_properties, the handle is attach/detach.
  void attach(HomeComposerHandle handle) => _handle = handle;

  /// The composer unregisters when it unmounts.
  void detach(HomeComposerHandle handle) {
    if (identical(_handle, handle)) _handle = null;
  }

  bool get isAttached => _handle != null;

  void populatePrompt(String prompt) => _handle?.populatePrompt(prompt);

  void loadQueuedMessage(HomeQueuedMessage message) =>
      _handle?.loadQueuedMessage(message);
}

/// Everything a composer gets from Home.
@immutable
class HomeComposerProps {
  const HomeComposerProps({
    required this.variant,
    required this.controller,
    required this.workspaceId,
    required this.draftScopeKey,
    required this.isSending,
    required this.onSubmit,
    required this.onStop,
    required this.onContextAdd,
    this.initialPrompt = '',
    this.requestMode,
    this.onRequestModeChanged,
    this.onContextRemove,
    this.onSendQueuedHead,
    this.onEditQueuedTail,
  });

  final HomeComposerVariant variant;
  final HomeComposerController controller;
  final String workspaceId;

  /// `${workspaceId}:${chatId ?? 'new'}` (`home.tsx:405`).
  final String draftScopeKey;

  /// The landing-page prompt the hero starts with (`initialPrompt`).
  final String initialPrompt;
  final bool isSending;
  final void Function(HomeOutgoingMessage message) onSubmit;
  final VoidCallback onStop;

  /// The mode selector's value; null hides the selector (it only shows on
  /// `/home`, the hero of a new chat).
  final HomeRequestMode? requestMode;
  final ValueChanged<HomeRequestMode>? onRequestModeChanged;

  /// A chip was added (`onContextAdd`): Home opens its resource tab.
  final void Function(HomeChatContext context) onContextAdd;

  /// A chip was removed (hero only, `home.tsx:342-355`).
  final void Function(HomeChatContext removed, List<HomeChatContext> remaining)?
  onContextRemove;

  /// Conversation variant: send the queue head now (`onSendQueuedHead`).
  final VoidCallback? onSendQueuedHead;

  /// Conversation variant: ArrowUp in an empty editor edits the queue tail.
  final VoidCallback? onEditQueuedTail;
}

/// Builds the composer; its outer box carries the `chat-input.root` id.
typedef HomeComposerBuilder =
    Widget Function(BuildContext context, HomeComposerProps props);

/// The three slot implementations Home renders with.
@immutable
class HomeSlots {
  const HomeSlots({
    required this.session,
    required this.transcript,
    required this.composer,
  });

  /// The Phase 1.5 stand-ins (`placeholder_slots.dart`): a local session
  /// without a backend, a plain transcript and a plain composer.
  factory HomeSlots.placeholder() => const HomeSlots(
    session: PlaceholderChatSession.create,
    transcript: buildPlaceholderTranscript,
    composer: buildPlaceholderComposer,
  );

  final HomeChatSessionFactory session;
  final HomeTranscriptBuilder transcript;
  final HomeComposerBuilder composer;

  /// The slots for [context]: the nearest [HomeSlotsScope], else the
  /// locator's [HomeSlots], else the placeholders.
  // ignore: prefer_constructors_over_static_methods, a lookup, not a build.
  static HomeSlots of(BuildContext context) =>
      HomeSlotsScope.maybeOf(context) ??
      (locator.isRegistered<HomeSlots>()
          ? locator<HomeSlots>()
          : HomeSlots.placeholder());
}

/// Overrides the slots for a subtree (tests, previews).
class HomeSlotsScope extends InheritedWidget {
  const HomeSlotsScope({required this.slots, required super.child, super.key});

  final HomeSlots slots;

  static HomeSlots? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeSlotsScope>()?.slots;

  @override
  bool updateShouldNotify(HomeSlotsScope oldWidget) => slots != oldWidget.slots;
}
