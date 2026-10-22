import 'dart:async';

import 'package:clock/clock.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/chat/messages/activity/shimmer.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_design/sim_design.dart';

/// Icon column shared by every activity row (`ACTIVITY_ICON_SLOT_CLASS`).
const double chatActivityIconSlot = 14;

/// `gap-2` between the icon column and the text column.
const double chatActivityGap = 8;

/// Activity row (`components/ui/activity-status.tsx`): a 14px icon slot in
/// `--text-icon`, 8px gap, then the Inter 15/20 `--text-tertiary` label
/// (overflow-faded; `--text-body` when [hovered]); [active] paints the label
/// with the shimmer resting in `--text-tertiary`.
class ChatActivityStatus extends StatelessWidget {
  const ChatActivityStatus({
    required this.label,
    this.active = false,
    this.icon,
    this.hovered = false,
    super.key,
  });

  final String label;
  final bool active;
  final Widget? icon;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final style = ChatText.inter(
      context,
      15,
      lineHeight: 20,
      color: hovered ? c.textBody : c.textTertiary,
      tracking: true,
    );
    return ChatParity(
      'chat.activity.status',
      child: Semantics(
        liveRegion: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: chatActivityGap,
          children: <Widget>[
            if (icon != null)
              ExcludeSemantics(
                child: SizedBox.square(
                  dimension: chatActivityIconSlot,
                  child: IconTheme.merge(
                    data: IconThemeData(color: c.textIcon, size: 14),
                    child: Center(child: icon),
                  ),
                ),
              ),
            Flexible(
              child: SimOverflowText(
                label: label,
                style: style,
                child: active
                    ? ChatShimmer(
                        restColor: c.textTertiary,
                        child: Text(
                          label,
                          style: style,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `ActivityTextColumn`: reserves the icon column so nested content lines up
/// with every row's label (22px per level).
class ChatActivityTextColumn extends StatelessWidget {
  const ChatActivityTextColumn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      left: chatActivityIconSlot + chatActivityGap,
    ),
    child: child,
  );
}

/// `ActivityStream` + `ActivityDisclosure` + `ActivityViewport`: a header
/// row (paced to one label change per second while live and collapsed), an
/// optional chevron (rotated −90° and hidden while collapsed, shown on
/// hover/focus, 150 ms), and an expandable body (300 ms) holding a 110px
/// auto-following viewport with 16px scroll fades (unbounded for pending
/// interactions).
class ChatActivityDisclosure extends StatefulWidget {
  const ChatActivityDisclosure({
    required this.label,
    required this.body,
    this.icon,
    this.active = false,
    this.collapsible = true,
    this.expanded = false,
    this.onToggle,
    this.expandedLabel,
    this.streaming = false,
    this.unbounded = false,
    super.key,
  });

  final String label;
  final Widget? icon;
  final bool active;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggle;
  final String? expandedLabel;
  final bool streaming;
  final bool unbounded;
  final Widget body;

  /// `ACTIVITY_UPDATE_INTERVAL_MS`.
  static const Duration labelInterval = Duration(milliseconds: 1000);

  @override
  State<ChatActivityDisclosure> createState() => _ChatActivityDisclosureState();
}

class _ChatActivityDisclosureState extends State<ChatActivityDisclosure> {
  late String _shownLabel = widget.label;
  DateTime _shownAt = clock.now();
  Timer? _timer;

  bool get _isExpanded => widget.collapsible && widget.expanded;

  @override
  void didUpdateWidget(ChatActivityDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.label == _shownLabel) return;
    final paced = widget.active && !_isExpanded && !SimMotion.disabled;
    if (!paced || oldWidget.active != widget.active) {
      _show(widget.label);
      return;
    }
    final remaining =
        ChatActivityDisclosure.labelInterval - clock.now().difference(_shownAt);
    _timer?.cancel();
    if (remaining <= Duration.zero) {
      _show(widget.label);
    } else {
      _timer = Timer(remaining, () {
        if (mounted) setState(() => _show(widget.label));
      });
    }
  }

  void _show(String label) {
    _timer?.cancel();
    _shownLabel = label;
    _shownAt = clock.now();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final label = _isExpanded
        ? (widget.expandedLabel ?? _shownLabel)
        : _shownLabel;
    Widget header({required bool hovered, required bool focused}) => ChatParity(
      'chat.activity.header',
      child: Row(
        spacing: chatActivityGap,
        children: <Widget>[
          Flexible(
            child: ChatActivityStatus(
              label: label,
              active: widget.active,
              icon: widget.icon,
              hovered: hovered && widget.collapsible,
            ),
          ),
          if (widget.collapsible)
            ChatParity(
              'chat.activity.chevron',
              child: AnimatedOpacity(
                duration: SimMotion.of(SimMotion.sidebarChevron),
                opacity: _isExpanded || hovered || focused ? 1 : 0,
                child: AnimatedRotation(
                  duration: SimMotion.of(SimMotion.sidebarChevron),
                  turns: _isExpanded ? 0 : -0.25,
                  child: SimIcon(SimEmcnIcons.chevronDown, color: c.textIcon),
                ),
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.collapsible)
          Semantics(
            expanded: _isExpanded,
            child: SimPressable(
              onPressed: widget.onToggle,
              semanticsLabel: label,
              builder: (context, state) =>
                  header(hovered: state.hovered, focused: state.focused),
            ),
          )
        else
          header(hovered: false, focused: false),
        if (widget.collapsible)
          ChatExpandable(
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ChatActivityViewport(
                      streaming: widget.streaming,
                      unbounded: widget.unbounded,
                      child: widget.body,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
      ],
    );
  }
}

/// `ActivityViewport`: `pr-2`, max 110px with hidden scrollbar and 16px
/// edge fades; follows new content while [streaming] until the user scrolls
/// up, re-sticking within 8px of the bottom on a downward scroll.
class ChatActivityViewport extends StatefulWidget {
  const ChatActivityViewport({
    required this.child,
    this.streaming = false,
    this.unbounded = false,
    super.key,
  });

  final Widget child;
  final bool streaming;
  final bool unbounded;

  static const double maxHeight = 110;

  @override
  State<ChatActivityViewport> createState() => _ChatActivityViewportState();
}

class _ChatActivityViewportState extends State<ChatActivityViewport> {
  final ScrollController _controller = ScrollController();
  bool _stick = true;
  double _previous = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _follow() {
    if (!widget.streaming || !_stick || !_controller.hasClients) return;
    final position = _controller.position;
    final gap = position.maxScrollExtent - position.pixels;
    if (gap < 1) return;
    if (SimMotion.disabled) {
      _controller.jumpTo(position.maxScrollExtent);
    } else {
      unawaited(
        _controller.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: SimMotion.easeOut,
        ),
      );
    }
  }

  bool _onNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.forward) {
      _stick = false;
    }
    if (notification is ScrollUpdateNotification) {
      final m = notification.metrics;
      if (m.maxScrollExtent - m.pixels < 8 && m.pixels > _previous) {
        _stick = true;
      }
      _previous = m.pixels;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: widget.child,
    );
    if (widget.unbounded) {
      return ChatParity('chat.activity.viewport', child: content);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _follow();
    });
    return ChatParity(
      'chat.activity.viewport',
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: ChatActivityViewport.maxHeight,
        ),
        child: SimScrollFade(
          band: 16,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onNotification,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                controller: _controller,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
