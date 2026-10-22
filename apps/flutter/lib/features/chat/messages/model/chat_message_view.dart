import 'package:flutter/foundation.dart';
import 'package:sim_design/sim_design.dart';

/// Immutable render model of one transcript row (`docs/port/specs/chat-messages.md`).
///
/// The chat engine owns the stream and the transcript; an adapter maps its
/// state onto these views. Nothing here knows about the network: titles,
/// tenses and gating flags arrive pre-computed, and every user action leaves
/// through `ChatMessageCallbacks`.
@immutable
sealed class ChatMessageView {
  const ChatMessageView({required this.id});

  /// Stable row key (survives the live → persisted id swap when the adapter
  /// keeps it stable).
  final String id;
}

/// A user turn: the bubble, its mentions and attachments
/// (`UserMessageRow`, `mothership-chat.tsx:213-235`).
@immutable
class ChatUserMessageView extends ChatMessageView {
  const ChatUserMessageView({
    required super.id,
    required this.text,
    this.mentions = const <ChatMentionView>[],
    this.attachments = const <ChatAttachmentView>[],
    this.isTaskNotification = false,
    this.hidden = false,
  });

  final String text;

  /// The `contexts` the composer attached; each renders as an inline chip
  /// where `@label` (or `/label` for skills, MCP and slash commands) occurs.
  final List<ChatMentionView> mentions;
  final List<ChatAttachmentView> attachments;

  /// `msg.origin === 'task'`: a centred "Background task" pill, not a bubble.
  final bool isTaskNotification;

  /// The question card it answered renders the recap instead
  /// (`interactionPairing.hiddenUserByIndex`).
  final bool hidden;
}

/// An assistant turn: an ordered segment stack plus the tail slot.
@immutable
class ChatAssistantMessageView extends ChatMessageView {
  const ChatAssistantMessageView({
    required super.id,
    required this.segments,
    this.isStreaming = false,
    this.thinkingLabel = 'Thinking',
    this.canFeedback = false,
    this.canFork = false,
    this.requestId,
    this.userQuery,
    this.questionAnswers,
    this.credentialRecap,
    this.copyText,
  });

  /// Rendered top to bottom. A block-less persisted message is one
  /// [ChatTextSegment] holding `content` (`message-content.tsx:1019-1027`).
  final List<ChatSegment> segments;

  /// The network stream for this message is still open.
  final bool isStreaming;

  /// `deriveThinkingLabel`: Thinking, Dispatching or Returning.
  final String thinkingLabel;

  /// `chatId && userQuery` (like / dislike).
  final bool canFeedback;

  /// Owner + chatId + a persisted (non-live) message id.
  final bool canFork;

  /// Copied by the dislike modal's "Copy ID".
  final String? requestId;

  /// The preceding user message (feedback payload).
  final String? userQuery;

  /// Transcript-derived answers for a trailing question card (renders the
  /// recap; `null` while unanswered).
  final List<String>? questionAnswers;

  /// Transcript-derived recap of a trailing credential card: submitted
  /// (`credentialSubmission`) or talked past (`credentialAbandoned`); `null`
  /// while the card is still live.
  final List<ChatCredentialRecapItem>? credentialRecap;

  /// Overrides the copied text; defaults to the text segments joined
  /// (`getOrchestratorMessageText`) with chips made portable.
  final String? copyText;

  /// The last stop segment the engine appended (user Stop).
  bool get isStopped =>
      segments.isNotEmpty && segments.last is ChatStoppedSegment;
}

/// One message segment (`MessageSegment` + the special-tag blocks).
@immutable
sealed class ChatSegment {
  const ChatSegment();
}

/// Raw assistant text: markdown that may still carry special tags
/// (`<options>`, `<question>`, `<source>`, `<workspace_resource>`,
/// `<mothership-error>`, `<credential>`, `<thinking>`); the renderer parses
/// them the way `ChatContent` does.
@immutable
class ChatTextSegment extends ChatSegment {
  const ChatTextSegment({
    required this.id,
    required this.content,
    this.streaming = false,
  });

  final String id;
  final String content;

  /// This is the trailing text segment of a live message: pace and fade it.
  final bool streaming;
}

/// A lane of agent activity (`AgentGroupSegment`).
@immutable
class ChatAgentGroupSegment extends ChatSegment {
  const ChatAgentGroupSegment({required this.group});

  final ChatAgentGroupView group;
}

/// A lone tool call outside any lane (rendered as one activity row).
@immutable
class ChatToolCallSegment extends ChatSegment {
  const ChatToolCallSegment({required this.tool});

  final ChatToolCallView tool;
}

/// The `options` content block: round border chips (`options.tsx`).
@immutable
class ChatOptionsSegment extends ChatSegment {
  const ChatOptionsSegment({required this.options});

  final List<ChatOptionView> options;
}

/// A `task` (watch) block row (`watch-activity.tsx`).
@immutable
class ChatWatchSegment extends ChatSegment {
  const ChatWatchSegment({
    required this.label,
    this.pending = false,
    this.tooltip,
  });

  /// Already resolved ("Waiting for workflow run: Daily report").
  final String label;
  final bool pending;
  final String? tooltip;
}

/// User Stop: "Stopped by user" takes the tail slot.
@immutable
class ChatStoppedSegment extends ChatSegment {
  const ChatStoppedSegment();
}

/// `<question>`: one or more single/multi-select questions.
@immutable
class ChatQuestionSegment extends ChatSegment {
  const ChatQuestionSegment({required this.questions});

  final List<ChatQuestionView> questions;
}

/// `<options>` tag: "Suggested follow-ups".
@immutable
class ChatFollowUpsSegment extends ChatSegment {
  const ChatFollowUpsSegment({required this.options});

  final List<ChatOptionView> options;
}

/// `<mothership-error>`: italic 13/20 `--text-secondary`.
@immutable
class ChatErrorSegment extends ChatSegment {
  const ChatErrorSegment({required this.message});

  final String message;
}

/// `<credential>` / `<usage_upgrade>`: interaction-card chrome only (the
/// OAuth flows behind them are Phase 4).
@immutable
class ChatCredentialSegment extends ChatSegment {
  const ChatCredentialSegment({required this.items});

  final List<ChatCredentialItemView> items;
}

/// One recap row of a settled credential card (`InteractionCardRecap`):
/// the integration or secret and its outcome (Connected, Added, Skipped).
@immutable
class ChatCredentialRecapItem {
  const ChatCredentialRecapItem({required this.label, required this.status});

  final String label;
  final String status;
}

@immutable
class ChatCredentialItemView {
  const ChatCredentialItemView({required this.label, this.done = false});

  final String label;
  final bool done;
}

@immutable
class ChatOptionView {
  const ChatOptionView({required this.id, required this.label});

  /// Submitted as the next user message.
  final String id;
  final String label;
}

enum ChatQuestionType { singleSelect, multiSelect }

@immutable
class ChatQuestionView {
  const ChatQuestionView({
    required this.prompt,
    required this.options,
    this.type = ChatQuestionType.singleSelect,
  });

  final ChatQuestionType type;
  final String prompt;
  final List<ChatOptionView> options;
}

/// Tool status (`ToolCallStatus`).
enum ChatToolState {
  executing,
  awaitingApproval,
  success,
  error,
  rejected,
  cancelled,
  skipped,
  interrupted
  ;

  /// `isToolDone`.
  bool get isDone => this != executing && this != awaitingApproval;
}

/// One tool call row (`ToolCallItem`).
@immutable
class ChatToolCallView {
  const ChatToolCallView({
    required this.id,
    required this.name,
    required this.state,
    required this.title,
    this.activeTitle,
    this.icon,
    this.argsSummary,
    this.resultSummary,
    this.permissionExpired = false,
    this.activityPhrase,
    this.countdown,
  });

  final String id;

  /// Tool id (`toolName`); shown in the permission tooltip.
  final String name;
  final ChatToolState state;

  /// Status-tense title (`getToolStatusDisplayTitle`).
  final String title;

  /// In-progress label for a live run header; defaults to [title].
  final String? activeTitle;

  /// Brand or `TOOL_ICONS` icon; null → Wrench.
  final SimIconData? icon;

  /// Arguments preview for the permission tooltip (≤600 chars).
  final String? argsSummary;
  final String? resultSummary;

  /// The permission request 404'd: "{title} — this request is no longer active".
  final bool permissionExpired;

  /// The call's action phrase for a completed run's summary
  /// (`resolveToolActivity`); null → the call's own title.
  final ChatActivityPhrase? activityPhrase;

  /// A running `wait`: [title] / [activeTitle] re-read the clock every
  /// 250 ms in the row that shows them (`useToolCallTitle`).
  final ChatCountdown? countdown;
}

/// A title that counts down (`useElapsedMs`, `tool-call-title.ts:16-50`):
/// resolved from the milliseconds elapsed since [startedAtMs] (or since the
/// row mounted when the call has no start).
@immutable
class ChatCountdown {
  const ChatCountdown({
    required this.startedAtMs,
    required this.title,
    required this.activeTitle,
  });

  final int? startedAtMs;

  /// The row's status-aware title at an elapsed time.
  final String Function(int elapsedMs) title;

  /// The in-progress header label at an elapsed time.
  final String Function(int elapsedMs) activeTitle;
}

/// One completed-activity phrase (`ActivityPhrase`, `activity.ts:59-66`): a
/// plain past-tense phrase ("clicked elements") or a verb on a shared object
/// ("read" + "pages"), so adjacent phrases can share the object.
@immutable
class ChatActivityPhrase {
  const ChatActivityPhrase(String this.text) : verb = null, object = null;

  const ChatActivityPhrase.shared({
    required String this.verb,
    required String this.object,
  }) : text = null;

  final String? text;
  final String? verb;
  final String? object;

  bool get isShared => text == null;

  /// `activityLabel`.
  String get label => text ?? '$verb $object';

  @override
  bool operator ==(Object other) =>
      other is ChatActivityPhrase &&
      other.text == text &&
      other.verb == verb &&
      other.object == object;

  @override
  int get hashCode => Object.hash(text, verb, object);
}

/// `toPhraseCase` (`activity.ts:594-596`): sentence-case a title for use
/// mid-summary without lowercasing a leading acronym.
String chatPhraseCase(String title) => RegExp('^[A-Z][a-z]').hasMatch(title)
    ? title[0].toLowerCase() + title.substring(1)
    : title;

/// `getToolActivitySummaryActions` (`activity.ts:670-690`): up to [limit]
/// distinct phrases in first-occurrence order; adjacent chosen phrases on the
/// same object share it ("listed, read tables"), compacted after the cap.
List<String> chatActivitySummaryActions(
  Iterable<ChatActivityPhrase> phrases,
  int limit,
) {
  final unique = <String, ChatActivityPhrase>{};
  for (final phrase in phrases) {
    unique.putIfAbsent(phrase.label, () => phrase);
    if (unique.length == limit) break;
  }
  final visible = unique.values.toList();
  return [
    for (var i = 0; i < visible.length; i++)
      visible[i].isShared &&
              i + 1 < visible.length &&
              visible[i + 1].isShared &&
              visible[i + 1].object == visible[i].object
          ? visible[i].verb!
          : visible[i].label,
  ];
}

/// Items inside an agent lane.
@immutable
sealed class ChatAgentItem {
  const ChatAgentItem();
}

@immutable
class ChatAgentTextItem extends ChatAgentItem {
  const ChatAgentTextItem({required this.content, this.streaming = false});

  /// Narration (inline markdown only).
  final String content;
  final bool streaming;
}

@immutable
class ChatAgentToolItem extends ChatAgentItem {
  const ChatAgentToolItem({required this.tool});

  final ChatToolCallView tool;
}

@immutable
class ChatAgentNestedItem extends ChatAgentItem {
  const ChatAgentNestedItem({required this.group});

  final ChatAgentGroupView group;
}

/// An agent lane (`AgentGroupView`). The main lane (`isMain`) renders only its
/// tool runs; a subagent lane renders a disclosure header.
@immutable
class ChatAgentGroupView {
  const ChatAgentGroupView({
    required this.id,
    required this.agentName,
    required this.label,
    required this.items,
    this.isMain = false,
    this.isLive = false,
    this.error,
    this.icon,
    this.completedTitle,
    this.expandedLabel,
    this.labelCountdown,
  });

  final String id;
  final String agentName;

  /// Header text (`headerText`): in-progress label, "Thinking", the
  /// completed label, or the agent label on error.
  final String label;
  final List<ChatAgentItem> items;
  final bool isMain;

  /// Holds the turn's live indicator: the header (or the live run header)
  /// shimmers.
  final bool isLive;
  final String? error;

  /// Agent icon; null → Blimp (or the 14px loader while live).
  final SimIconData? icon;

  /// The activity's model-provided completed title for a main-lane run.
  final String? completedTitle;

  /// Label shown in the header while expanded (`activityDescriptor.title`).
  final String? expandedLabel;

  /// The header names a running `wait`: [label] counts down
  /// (`ChatCountdown.activeTitle`).
  final ChatCountdown? labelCountdown;

  bool get hasPendingPermission => items.any(
    (item) => switch (item) {
      ChatAgentToolItem(:final tool) =>
        tool.state == ChatToolState.awaitingApproval,
      ChatAgentNestedItem(:final group) => group.hasPendingPermission,
      ChatAgentTextItem() => false,
    },
  );

  bool get hasContent =>
      error != null ||
      items.any(
        (item) => switch (item) {
          ChatAgentTextItem(:final content) => content.trim().isNotEmpty,
          ChatAgentToolItem() => true,
          ChatAgentNestedItem(:final group) => group.hasContent,
        },
      );
}

/// A `<source>` citation (`SourceTagData`).
@immutable
class ChatSourceView {
  const ChatSourceView({
    required this.url,
    this.title,
    this.siteName,
    this.connectorType,
    this.snippet,
  });

  final String url;
  final String? title;
  final String? siteName;
  final String? connectorType;
  final String? snippet;

  /// `linkSiteName`: the site name, else the host without `www.`.
  String get siteLabel {
    final name = siteName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final host = Uri.tryParse(url)?.host ?? '';
    return (host.isEmpty ? url : host).replaceFirst(RegExp(r'^www\.'), '');
  }

  /// `sourceLabel`: the title, else the site.
  String get label {
    final t = title?.trim();
    return t != null && t.isNotEmpty ? t : siteLabel;
  }

  @override
  bool operator ==(Object other) =>
      other is ChatSourceView &&
      other.url == url &&
      other.title == title &&
      other.siteName == siteName &&
      other.connectorType == connectorType &&
      other.snippet == snippet;

  @override
  int get hashCode => Object.hash(url, title, siteName, connectorType, snippet);
}

enum ChatResourceKind {
  workflow,
  table,
  dashboard,
  file,
  knowledge,
  folder,
  integration,
  skill,
  mcp,
  slashCommand,
  other,
}

/// A `<workspace_resource>` chip / composer mention target.
@immutable
class ChatResourceView {
  const ChatResourceView({
    required this.kind,
    this.id,
    this.path,
    this.title,
    this.workspaceId,
  });

  final ChatResourceKind kind;
  final String? id;
  final String? path;
  final String? title;
  final String? workspaceId;

  /// `fallbackWorkspaceResourceTitle`.
  String get displayTitle {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return switch (kind) {
      ChatResourceKind.workflow => 'Workflow',
      ChatResourceKind.table => 'Table',
      ChatResourceKind.dashboard => 'Dashboard',
      ChatResourceKind.file => path ?? 'File',
      _ => id ?? '',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ChatResourceView &&
      other.kind == kind &&
      other.id == id &&
      other.path == path &&
      other.title == title &&
      other.workspaceId == workspaceId;

  @override
  int get hashCode => Object.hash(kind, id, path, title, workspaceId);
}

/// A composer context attached to a user message.
@immutable
class ChatMentionView {
  const ChatMentionView({required this.kind, required this.label});

  final ChatResourceKind kind;
  final String label;

  /// Skills, MCP servers and slash commands are written `/label`.
  String get token =>
      '${kind == ChatResourceKind.skill || kind == ChatResourceKind.mcp || kind == ChatResourceKind.slashCommand ? '/' : '@'}$label';
}

@immutable
class ChatAttachmentView {
  const ChatAttachmentView({
    required this.id,
    required this.filename,
    required this.mediaType,
    this.previewUrl,
  });

  final String id;
  final String filename;
  final String mediaType;

  /// Image/video thumbnails need a preview; files render as a pill.
  final String? previewUrl;

  bool get isVideo => mediaType.startsWith('video/');
}

/// Tool permission decisions (`tool-permission-card.tsx`).
enum ChatPermissionDecision {
  allow('allow'),
  allowChat('allow_chat'),
  alwaysAllow('always_allow'),
  skip('skip')
  ;

  const ChatPermissionDecision(this.wire);

  final String wire;
}

/// Result of a permission submission: a 404 expires the card.
enum ChatPermissionOutcome { accepted, expired, failed }
