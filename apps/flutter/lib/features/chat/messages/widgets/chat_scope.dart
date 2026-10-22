import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_design/sim_design.dart';

/// Tags [child] with its spec parity id (`Semantics(container: true,
/// identifier:)`), which the parity capture reads from the
/// `flt-semantics-identifier` DOM.
class ChatParity extends StatelessWidget {
  const ChatParity(this.id, {required this.child, super.key});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Semantics(container: true, identifier: id, child: child);
}

/// Every action that leaves the transcript. All optional: a missing callback
/// hides or disables the control the way upstream gates it.
@immutable
class ChatMessageCallbacks {
  const ChatMessageCallbacks({
    this.onOptionSelect,
    this.onQuestionDismiss,
    this.onPermission,
    this.onFeedback,
    this.onFork,
    this.onViewAllSources,
    this.onOpenLink,
    this.onResourceSelect,
    this.resolveImageUrl,
    this.resolveMessageImageUrl,
    this.faviconBuilder,
    this.copyToClipboard,
  });

  /// Option chip, follow-up row or question answer → next user message.
  /// Only wired for the last message (`onOptionSelect` undefined otherwise).
  final ValueChanged<String>? onOptionSelect;
  final ValueChanged<String>? onQuestionDismiss;

  /// `POST /api/copilot/tool-permission`; resolves to the outcome so the card
  /// can expire (404) or re-enable (other errors).
  final Future<ChatPermissionOutcome> Function(
    List<String> toolCallIds,
    ChatPermissionDecision decision,
  )?
  onPermission;

  /// `POST /api/copilot/feedback` (only called with non-empty text).
  final void Function(
    String messageId, {
    required bool positive,
    required String text,
  })?
  onFeedback;

  /// `POST /api/mothership/chats/{chatId}/fork` + navigation; the future
  /// completes when the fork settled (pending state ends).
  final Future<void> Function(String messageId)? onFork;
  final ValueChanged<String>? onViewAllSources;

  /// Opens an http(s)/mailto/relative link (new tab on web).
  final ValueChanged<String>? onOpenLink;
  final ValueChanged<ChatResourceView>? onResourceSelect;

  /// Maps an inline chat file image reference to the authenticated route
  /// (`privateImageUrls`); returning null hides the image.
  final String? Function(String src)? resolveImageUrl;

  /// Per-message form of [resolveImageUrl]: the assistant row binds its own
  /// `requestId` (`imageRequestId`), so each turn's images resolve against
  /// that turn's published snapshot. Takes precedence when set.
  final String? Function(String src, String? requestId)? resolveMessageImageUrl;

  /// Favicon for external links and citation chips; defaults to the globe.
  final Widget Function(String url, double size)? faviconBuilder;

  /// Clipboard writer; defaults to [Clipboard.setData].
  final Future<void> Function(String text)? copyToClipboard;

  ChatMessageCallbacks copyWith({
    ValueChanged<String>? onQuestionDismiss,
    String? Function(String src)? resolveImageUrl,
  }) => ChatMessageCallbacks(
    onOptionSelect: onOptionSelect,
    onQuestionDismiss: onQuestionDismiss ?? this.onQuestionDismiss,
    onPermission: onPermission,
    onFeedback: onFeedback,
    onFork: onFork,
    onViewAllSources: onViewAllSources,
    onOpenLink: onOpenLink,
    onResourceSelect: onResourceSelect,
    resolveImageUrl: resolveImageUrl ?? this.resolveImageUrl,
    resolveMessageImageUrl: resolveMessageImageUrl,
    faviconBuilder: faviconBuilder,
    copyToClipboard: copyToClipboard,
  );

  /// Hides option/question interactivity (older messages).
  ChatMessageCallbacks withoutOptionSelect() => ChatMessageCallbacks(
    onQuestionDismiss: onQuestionDismiss,
    onPermission: onPermission,
    onFeedback: onFeedback,
    onFork: onFork,
    onViewAllSources: onViewAllSources,
    onOpenLink: onOpenLink,
    onResourceSelect: onResourceSelect,
    resolveImageUrl: resolveImageUrl,
    resolveMessageImageUrl: resolveMessageImageUrl,
    faviconBuilder: faviconBuilder,
    copyToClipboard: copyToClipboard,
  );

  List<Object?> get _fields => <Object?>[
    onOptionSelect,
    onQuestionDismiss,
    onPermission,
    onFeedback,
    onFork,
    onViewAllSources,
    onOpenLink,
    onResourceSelect,
    resolveImageUrl,
    resolveMessageImageUrl,
    faviconBuilder,
    copyToClipboard,
  ];

  /// Field-wise equality, so a rebuilt but unchanged bundle (e.g. each
  /// build's [withoutOptionSelect]) does not notify the [ChatScope].
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChatMessageCallbacks) return false;
    final a = _fields;
    final b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);

  Future<void> copy(String text) async {
    final writer = copyToClipboard;
    if (writer != null) return writer(text);
    await Clipboard.setData(ClipboardData(text: text));
  }
}

/// Provides [ChatMessageCallbacks] to the transcript widgets.
class ChatScope extends InheritedWidget {
  const ChatScope({required this.callbacks, required super.child, super.key});

  final ChatMessageCallbacks callbacks;

  static ChatMessageCallbacks of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatScope>()?.callbacks ??
      const ChatMessageCallbacks();

  @override
  bool updateShouldNotify(ChatScope oldWidget) =>
      callbacks != oldWidget.callbacks;
}

/// Bundled monospace face for chat code (`apps/flutter/pubspec.yaml`):
/// JetBrains Mono Regular, whose 0.6 em advance matches Liberation Mono /
/// Courier New (the Linux-container rendering of `font-mono`); Windows
/// Chromium renders Consolas (0.55 em), so mono glyph runs are ~9 % wider
/// than a Windows React capture (known gap).
const String chatMonoFamily = 'JetBrains Mono';

/// Text styles of the chat surface. Prose, user text and code reset the
/// workspace tracking to 0; activity rows, chips and actions keep 0.02em.
abstract final class ChatText {
  static TextStyle inter(
    BuildContext context,
    double size, {
    double? lineHeight,
    int weight = SimTextStyles.regular,
    Color? color,
    bool tracking = false,
  }) {
    final sim = SimTheme.of(context);
    final style = sim.text.inter(
      size,
      weight: weight,
      height: (lineHeight ?? size * 1.5) / size,
      color: color,
    );
    return tracking ? style : style.copyWith(letterSpacing: 0);
  }

  static TextStyle mono(
    double size, {
    double? lineHeight,
    Color? color,
  }) => TextStyle(
    fontFamily: chatMonoFamily,
    fontFamilyFallback: SimFonts.monoFallback,
    fontSize: size,
    height: lineHeight == null ? null : lineHeight / size,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    fontWeight: FontWeight.w400,
    // JetBrains Mono draws `++`, `=>`, `!=` as ligatures; Consolas and the
    // Liberation/Courier faces React renders with have none.
    fontFeatures: const [
      FontFeature.disable('calt'),
      FontFeature.disable('liga'),
    ],
    color: color,
  );
}

/// `Expandable` (Radix Collapsible, 300 ms `cubic-bezier(.4,0,.2,1)`);
/// with motion off the body snaps (a zero-duration [AnimatedSize] trips a
/// relayout assertion).
class ChatExpandable extends StatelessWidget {
  const ChatExpandable({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: SimMotion.disabled
        ? child
        : AnimatedSize(
            duration: SimMotion.of(SimMotion.collapsible),
            curve: SimMotion.standard,
            alignment: Alignment.topCenter,
            child: child,
          ),
  );
}

/// The transcript's default text: Inter 15/25 `--text-primary`, no
/// decoration (outside a Material the framework default is the debug
/// underline style).
class ChatTextDefaults extends StatelessWidget {
  const ChatTextDefaults({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: ChatText.inter(
      context,
      15,
      lineHeight: 25,
      color: SimTheme.of(context).colors.textPrimary,
    ).copyWith(decoration: TextDecoration.none),
    child: child,
  );
}

/// Copy feedback: flips to `true` for [reset], then back
/// (`useCopyToClipboard`).
class ChatCopyState extends ValueNotifier<bool> {
  ChatCopyState(this.reset) : super(false);

  final Duration reset;
  Timer? _timer;

  void copied() {
    value = true;
    _timer?.cancel();
    _timer = Timer(reset, () => value = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
