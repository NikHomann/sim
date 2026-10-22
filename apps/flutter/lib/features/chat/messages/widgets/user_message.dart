import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/markdown/mention_ranges.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_app/features/chat/messages/widgets/chips.dart';
import 'package:sim_design/sim_design.dart';

/// Row geometry of the `mothership-view` layout (`mothership-chat.tsx:149-162`).
abstract final class ChatRowMetrics {
  static const double userTop = 12;
  static const double rowGap = 24;
  static const double attachmentGap = 6;
  static const double bubbleRadius = 16;
  static const EdgeInsets bubblePadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 8,
  );

  /// `max-w-[85%] md:max-w-[70%]`.
  static double bubbleMaxFraction({required bool desktop}) =>
      desktop ? 0.7 : 0.85;
}

/// `UserMessageRow`: right-aligned attachments and bubble, 12px top and
/// 24px bottom padding (parity `chat.message.user`).
class ChatUserMessage extends StatelessWidget {
  const ChatUserMessage({
    required this.message,
    this.desktop = true,
    super.key,
  });

  final ChatUserMessageView message;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    if (message.hidden) return const SizedBox.shrink();
    if (message.isTaskNotification) {
      return ChatTaskNotification(content: message.text);
    }
    final c = SimTheme.of(context).colors;
    final fraction = ChatRowMetrics.bubbleMaxFraction(desktop: desktop);
    return ChatParity(
      'chat.message.user',
      child: Padding(
        padding: const EdgeInsets.only(
          top: ChatRowMetrics.userTop,
          bottom: ChatRowMetrics.rowGap,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth * fraction;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: ChatRowMetrics.attachmentGap,
              children: <Widget>[
                if (message.attachments.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ChatAttachments(attachments: message.attachments),
                  ),
                ChatParity(
                  'chat.message.user.bubble',
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Container(
                      padding: ChatRowMetrics.bubblePadding,
                      decoration: BoxDecoration(
                        color: c.surface5,
                        borderRadius: BorderRadius.circular(
                          ChatRowMetrics.bubbleRadius,
                        ),
                      ),
                      child: ChatUserText(
                        text: message.text,
                        mentions: message.mentions,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// `UserMessageContent`: Inter 15/23 `--text-primary`, tracking 0,
/// pre-wrap; mentions become inline mono chips.
class ChatUserText extends StatelessWidget {
  const ChatUserText({required this.text, this.mentions = const [], super.key});

  final String text;
  final List<ChatMentionView> mentions;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final style = ChatText.inter(
      context,
      15,
      lineHeight: 23,
      color: c.textPrimary,
    );
    final ranges = computeMentionRanges(text, mentions);
    final InlineSpan span;
    if (ranges.isEmpty) {
      span = TextSpan(text: text.trim(), style: style);
    } else {
      final children = <InlineSpan>[];
      var last = 0;
      for (final range in ranges) {
        if (range.start > last) {
          children.add(TextSpan(text: text.substring(last, range.start)));
        }
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ChatResourceChip(
              kind: range.mention.kind,
              title: range.mention.label,
              parityId: 'chat.message.user.mention',
            ),
          ),
        );
        last = range.end;
      }
      if (last < text.length) {
        children.add(TextSpan(text: text.substring(last)));
      }
      span = TextSpan(style: style, children: children);
    }
    return ChatParity('chat.message.user.text', child: Text.rich(span));
  }
}

/// `ChatMessageAttachments`: 56px r8 thumbnails (video placeholder with an
/// 18px icon) and ≤140px mono file pills, wrapping with a 6px gap, right
/// aligned.
class ChatAttachments extends StatelessWidget {
  const ChatAttachments({required this.attachments, super.key});

  final List<ChatAttachmentView> attachments;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return ChatParity(
      'chat.message.user.attachments',
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final a in attachments)
            if (a.previewUrl == null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: ChatResourceChip(
                  kind: ChatResourceKind.file,
                  title: a.filename,
                  parityId: 'chat.message.user.attachment',
                ),
              )
            else if (a.isVideo)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.surface5,
                  borderRadius: BorderRadius.circular(SimRadii.lg),
                ),
                alignment: Alignment.center,
                child: SimIcon(
                  SimEmcnIcons.videoIcon,
                  size: 18,
                  color: c.textIcon,
                ),
              )
            else
              SimPressable(
                semanticsLabel: 'Preview ${a.filename}',
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierColor: const Color(0xCC000000),
                  builder: (context) => GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: InteractiveViewer(
                      child: Center(child: Image.network(a.previewUrl!)),
                    ),
                  ),
                ),
                builder: (context, state) => ClipRRect(
                  borderRadius: BorderRadius.circular(SimRadii.lg),
                  child: SizedBox.square(
                    dimension: 56,
                    child: Image.network(
                      a.previewUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          ColoredBox(color: c.surface5),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// `TaskNotificationRow`: centred `Background task` pill (12px,
/// `--text-secondary`, `--border`, rounded-full), 24px bottom padding.
class ChatTaskNotification extends StatelessWidget {
  const ChatTaskNotification({required this.content, super.key});

  final String content;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final lines = content.split('\n').where((l) => l.isNotEmpty).toList();
    final outcome = lines.firstWhere(
      (l) => l.startsWith('Task '),
      orElse: () => lines.isEmpty ? '' : lines.last,
    );
    final text = outcome.replaceFirst(RegExp('^Task [0-9a-f-]+ '), '');
    final style = ChatText.inter(
      context,
      12,
      lineHeight: 18,
      color: c.textSecondary,
      tracking: true,
    );
    return ChatParity(
      'chat.message.taskNotification',
      child: Padding(
        padding: const EdgeInsets.only(bottom: ChatRowMetrics.rowGap),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.85,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.bg,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(SimRadii.full),
                ),
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: <InlineSpan>[
                      TextSpan(
                        text: 'Background task',
                        style: SimTextStyles.weight(
                          style,
                          SimTextStyles.medium,
                        ).copyWith(color: c.textPrimary),
                      ),
                      const WidgetSpan(child: SizedBox(width: 6)),
                      TextSpan(text: text),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `MothershipChatSkeleton` (`chat.skeleton`): bubbles and text lines in
/// `--surface-active` with the pulse (off with motion off).
class ChatSkeleton extends StatelessWidget {
  const ChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget lines(List<double> fractions) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: <Widget>[
        for (final f in fractions)
          FractionallySizedBox(
            widthFactor: f,
            child: const SimSkeleton(height: 14, radius: SimRadii.sm),
          ),
      ],
    );
    Widget bubble(double fraction, double height) => Padding(
      padding: const EdgeInsets.only(top: ChatRowMetrics.userTop),
      child: Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: fraction,
          child: SimSkeleton(
            height: height,
            radius: ChatRowMetrics.bubbleRadius,
          ),
        ),
      ),
    );
    return ChatParity(
      'chat.skeleton',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: <Widget>[
          bubble(0.55, 40),
          lines(const <double>[0.9, 0.75, 0.82, 0.4]),
          bubble(0.4, 32),
          lines(const <double>[0.85, 0.7, 0.6]),
        ],
      ),
    );
  }
}
