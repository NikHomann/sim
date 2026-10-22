import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/activity/activity_status.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_design/sim_design.dart';

/// `ToolPermissionCard` (`tool-permission-card.tsx:156-230`): ShieldCheck,
/// the tool title (`text-sm --text-body`, tooltip with tool name + args),
/// `Allow` (primary), `Don't ask again ▾` (For this chat / For every chat)
/// and `Skip`; the first of several outstanding cards adds "N tools need
/// permission" with `Allow all` / `Skip all`. Disabled while submitting; a
/// 404 turns it into "{title} — this request is no longer active".
class ChatPermissionCard extends StatefulWidget {
  const ChatPermissionCard({
    required this.tool,
    this.outstandingIds = const <String>[],
    super.key,
  });

  final ChatToolCallView tool;

  /// Every pending permission in the message, in order; the bulk row shows
  /// on the first card when there is more than one.
  final List<String> outstandingIds;

  @override
  State<ChatPermissionCard> createState() => _ChatPermissionCardState();
}

class _ChatPermissionCardState extends State<ChatPermissionCard> {
  bool _busy = false;
  bool _expired = false;

  Future<void> _submit(
    ChatPermissionDecision decision,
    List<String> ids,
  ) async {
    final submit = ChatScope.of(context).onPermission;
    if (submit == null || _busy) return;
    setState(() => _busy = true);
    final outcome = await submit(ids, decision);
    if (!mounted) return;
    setState(() {
      _expired = outcome == ChatPermissionOutcome.expired;
      // Accepted cards stay disabled until the engine swaps the row.
      _busy = outcome == ChatPermissionOutcome.accepted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final tool = widget.tool;
    final shield = SizedBox.square(
      dimension: chatActivityIconSlot,
      child: SimIcon(SimEmcnIcons.shieldCheck, color: c.textIcon),
    );
    final sm = ChatText.inter(context, 14, lineHeight: 20, tracking: true);
    if (_expired || tool.permissionExpired) {
      return ChatParity(
        'chat.tool.permission',
        child: Row(
          spacing: chatActivityGap,
          children: <Widget>[
            shield,
            Flexible(
              child: Text(
                '${tool.title} — this request is no longer active',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sm.copyWith(color: c.textTertiary),
              ),
            ),
          ],
        ),
      );
    }
    final enabled = !_busy && ChatScope.of(context).onPermission != null;
    final title = Text(
      tool.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: sm.copyWith(color: c.textBody),
    );
    final preview = tool.argsSummary;
    final ids = widget.outstandingIds;
    final showBulk = ids.length > 1 && ids.first == tool.id;
    return ChatParity(
      'chat.tool.permission',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: <Widget>[
          Row(
            spacing: chatActivityGap,
            children: <Widget>[
              shield,
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: preview == null || preview.isEmpty
                          ? title
                          : SimTooltip(
                              content: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(tool.name),
                                    const SizedBox(height: 4),
                                    Text(
                                      preview.length > 600
                                          ? '${preview.substring(0, 600)}…'
                                          : preview,
                                      style: ChatText.mono(11),
                                    ),
                                  ],
                                ),
                              ),
                              child: title,
                            ),
                    ),
                    SimChip(
                      label: 'Allow',
                      variant: SimChipVariant.primary,
                      enabled: enabled,
                      onPressed: () => _submit(
                        ChatPermissionDecision.allow,
                        <String>[tool.id],
                      ),
                    ),
                    Builder(
                      builder: (anchor) => SimChip(
                        label: "Don't ask again",
                        variant: SimChipVariant.border,
                        rightIcon: SimEmcnIcons.chevronDown,
                        enabled: enabled,
                        onPressed: () => SimDropdownMenu.show(
                          anchor,
                          entries: () => <SimMenuEntry>[
                            SimMenuItem(
                              label: 'For this chat',
                              onSelect: () => _submit(
                                ChatPermissionDecision.allowChat,
                                <String>[tool.id],
                              ),
                            ),
                            SimMenuItem(
                              label: 'For every chat',
                              onSelect: () => _submit(
                                ChatPermissionDecision.alwaysAllow,
                                <String>[tool.id],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SimChip(
                      label: 'Skip',
                      enabled: enabled,
                      onPressed: () => _submit(
                        ChatPermissionDecision.skip,
                        <String>[tool.id],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showBulk)
            ChatActivityTextColumn(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${ids.length} tools need permission',
                      style: ChatText.inter(
                        context,
                        11,
                        lineHeight: 16.5,
                        color: c.textTertiary,
                        tracking: true,
                      ),
                    ),
                  ),
                  SimChip(
                    label: 'Allow all',
                    enabled: enabled,
                    onPressed: () => _submit(ChatPermissionDecision.allow, ids),
                  ),
                  SimChip(
                    label: 'Skip all',
                    enabled: enabled,
                    onPressed: () => _submit(ChatPermissionDecision.skip, ids),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
