import 'package:flutter/widgets.dart';
import 'package:sim_app/features/home/conversation/queued_messages.dart';
import 'package:sim_app/features/home/slots.dart';
import 'package:sim_design/sim_design.dart';

/// `max-w-chat`.
const double chatMaxWidth = 704;

/// `MothershipChatSkeleton` (`mothership-chat-skeleton.tsx`, layout
/// `mothership-view`).
class ChatHistorySkeleton extends StatelessWidget {
  const ChatHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'home.chat.skeleton',
    container: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        Widget bar(double fraction, double height, double radius) =>
            SimSkeleton(width: w * fraction, height: height, radius: radius);
        Widget userRow(double fraction, double height) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: bar(fraction, height, 16),
          ),
        );
        Widget lines(List<double> fractions) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: <Widget>[for (final f in fractions) bar(f, 14, 4)],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 24,
          children: <Widget>[
            userRow(0.55, 40),
            lines(const <double>[0.9, 0.75, 0.82, 0.4]),
            userRow(0.4, 32),
            lines(const <double>[0.85, 0.7, 0.6]),
          ],
        );
      },
    ),
  );
}

/// The conversation surface (`MothershipChat` with `layout='mothership-
/// view'`, `mothership-chat.tsx:858-996`): the scroll region (transcript
/// slot, or the skeleton while history loads), and the footer with the
/// queue tray and the composer (hidden while loading). The footer slides in
/// once after the first send from the hero.
class ConversationView extends StatefulWidget {
  const ConversationView({
    required this.session,
    required this.transcript,
    required this.composer,
    required this.isLoading,
    required this.onRemoveQueued,
    required this.onSendQueuedNow,
    required this.onEditQueued,
    required this.onCancelQueueEdit,
    super.key,
    this.animateFooter = false,
    this.onFooterAnimationEnd,
  });

  final HomeChatSession session;
  final Widget transcript;
  final Widget composer;
  final bool isLoading;
  final ValueChanged<String> onRemoveQueued;
  final ValueChanged<String> onSendQueuedNow;
  final ValueChanged<String> onEditQueued;
  final VoidCallback onCancelQueueEdit;

  /// `animate-slide-in-bottom` (400ms, 20px, `cubic-bezier(.16,1,.3,1)`).
  final bool animateFooter;
  final VoidCallback? onFooterAnimationEnd;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: SimMotion.of(SimMotion.slideInBottom),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animateFooter) _play();
  }

  @override
  void didUpdateWidget(ConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateFooter && !oldWidget.animateFooter) _play();
  }

  void _play() {
    if (SimMotion.disabled) {
      _slide.value = 1;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onFooterAnimationEnd?.call(),
      );
      return;
    }
    _slide
      ..duration = SimMotion.of(SimMotion.slideInBottom)
      ..forward(from: 0).whenCompleteOrCancel(() {
        if (mounted) widget.onFooterAnimationEnd?.call();
      });
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    Widget footer = Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: chatMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              QueuedMessagesTray(
                messages: session.queuedMessages,
                editingId: session.editingQueuedId,
                dispatchingId: session.dispatchingHeadId,
                onRemove: widget.onRemoveQueued,
                onSendNow: widget.onSendQueuedNow,
                onEdit: widget.onEditQueued,
                onCancelEdit: widget.onCancelQueueEdit,
              ),
              if (!widget.isLoading) widget.composer,
            ],
          ),
        ),
      ),
    );
    footer = AnimatedBuilder(
      animation: _slide,
      child: footer,
      builder: (context, child) {
        final t = SimMotion.expoOut.transform(_slide.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
    );
    return Semantics(
      identifier: 'home.chat',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Semantics(
              identifier: 'home.chat.scroll',
              container: true,
              child: widget.isLoading
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: chatMaxWidth,
                          ),
                          child: const ChatHistorySkeleton(),
                        ),
                      ),
                    )
                  : widget.transcript,
            ),
          ),
          Semantics(
            identifier: 'home.chat.footer',
            container: true,
            child: footer,
          ),
        ],
      ),
    );
  }
}
