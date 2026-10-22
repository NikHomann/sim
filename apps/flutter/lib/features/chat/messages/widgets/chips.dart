import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_design/sim_design.dart';

/// `chipFilledFillTokens`: `--surface-5`, dark `--surface-4`.
Color chatChipFill(SimColors c) =>
    c.brightness == Brightness.dark ? c.surface4 : c.surface5;

/// Icon of a resource/mention kind (`ContextMentionIcon`).
SimIconData chatResourceIcon(ChatResourceKind kind) => switch (kind) {
  ChatResourceKind.workflow => SimEmcnIcons.workflow,
  ChatResourceKind.table => SimEmcnIcons.table,
  ChatResourceKind.dashboard => SimEmcnIcons.layout,
  ChatResourceKind.file => SimEmcnIcons.file,
  ChatResourceKind.knowledge => SimEmcnIcons.database,
  ChatResourceKind.folder => SimEmcnIcons.folder,
  ChatResourceKind.skill ||
  ChatResourceKind.slashCommand ||
  ChatResourceKind.mcp => SimEmcnIcons.code,
  ChatResourceKind.integration || ChatResourceKind.other => SimEmcnIcons.link,
};

/// Favicon / document mark of a source (`SourceIcon`): the injected favicon
/// builder, else the `FileText` fallback.
class ChatSourceIcon extends StatelessWidget {
  const ChatSourceIcon({required this.url, this.size = 14, super.key});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final builder = ChatScope.of(context).faviconBuilder;
    if (builder != null) {
      return SizedBox.square(dimension: size, child: builder(url, size));
    }
    return SimIcon(SimEmcnIcons.fileText, size: size);
  }
}

/// `ResourceMention`: a 20px mono `ChipTag` with a 12px kind icon and an
/// overflow-faded title; clickable when [onSelect] is set
/// (`resource-mention.tsx`, parity `chat.workspaceResource.chip` /
/// `chat.message.user.mention`).
class ChatResourceChip extends StatelessWidget {
  const ChatResourceChip({
    required this.kind,
    required this.title,
    this.onSelect,
    this.parityId = 'chat.workspaceResource.chip',
    super.key,
  });

  final ChatResourceKind kind;
  final String title;
  final VoidCallback? onSelect;
  final String parityId;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final style = ChatText.inter(
      context,
      14,
      lineHeight: 20,
      color: c.textPrimary,
      tracking: true,
    );
    Widget chip({required bool hovered}) => Container(
      height: SimLayout.chipTagHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: hovered ? c.surfaceHover : chatChipFill(c),
        borderRadius: BorderRadius.circular(SimRadii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: <Widget>[
          SimIcon(chatResourceIcon(kind), size: 12, color: c.textIcon),
          Flexible(
            child: SimOverflowText(label: title, style: style),
          ),
        ],
      ),
    );
    return ChatParity(
      parityId,
      child: onSelect == null
          ? chip(hovered: false)
          : SimPressable(
              onPressed: onSelect,
              semanticsLabel: title,
              builder: (context, state) => chip(hovered: state.hovered),
            ),
    );
  }
}

/// Inline citation (`SourceChip`): 20px round pill, max 160px, favicon +
/// caption title, `--text-body` on the chip fill, hover `--surface-hover`.
class ChatSourceChip extends StatelessWidget {
  const ChatSourceChip({required this.source, super.key});

  final ChatSourceView source;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final callbacks = ChatScope.of(context);
    final slackChannel = source.connectorType == 'slack'
        ? RegExp(r'^(#[^:\s]+): ').firstMatch(source.title ?? '')?.group(1)
        : null;
    final label = slackChannel ?? source.label;
    return ChatParity(
      'chat.source.chip',
      child: SimTooltip(
        message: source.label,
        child: SimPressable(
          isLink: true,
          semanticsLabel: label,
          onPressed: callbacks.onOpenLink == null
              ? null
              : () => callbacks.onOpenLink!(source.url),
          builder: (context, state) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Container(
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: state.hovered ? c.surfaceHover : chatChipFill(c),
                borderRadius: BorderRadius.circular(SimRadii.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: <Widget>[
                  ChatSourceIcon(url: source.url, size: 12),
                  Flexible(
                    child: SimOverflowText(
                      label: label,
                      tooltipEnabled: false,
                      style: ChatText.inter(
                        context,
                        12,
                        lineHeight: 18,
                        color: c.textBody,
                        tracking: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
