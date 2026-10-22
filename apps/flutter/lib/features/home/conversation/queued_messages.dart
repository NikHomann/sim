import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_design/sim_design.dart';

/// `NARROW_WIDTH_PX`: below it the attachment pill shows only the count.
const double queueNarrowWidth = 320;

/// The edit button's tooltip (`queued-messages.tsx:75-82`).
String queueEditLabel({
  required bool dispatching,
  required bool admissionUnknown,
}) => dispatching
    ? 'Sending now'
    : admissionUnknown
    ? 'May already be sent; editing could send a second message'
    : 'Edit queued message';

/// `QueuedMessages` (`queued-messages.tsx`): the tray tucked 12px under the
/// composer, inset 14px, listing the queued follow-ups with Edit / Send
/// now / Remove (or Cancel edit for the row being edited). Renders nothing
/// for an empty queue.
class QueuedMessagesTray extends StatefulWidget {
  const QueuedMessagesTray({
    required this.messages,
    required this.onRemove,
    required this.onSendNow,
    required this.onEdit,
    required this.onCancelEdit,
    super.key,
    this.editingId,
    this.dispatchingId,
  });

  final List<HomeQueuedMessage> messages;
  final String? editingId;
  final String? dispatchingId;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onSendNow;
  final ValueChanged<String> onEdit;
  final VoidCallback onCancelEdit;

  @override
  State<QueuedMessagesTray> createState() => _QueuedMessagesTrayState();
}

class _QueuedMessagesTrayState extends State<QueuedMessagesTray> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) return const SizedBox.shrink();
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return NegativeBottomMargin(
      margin: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Semantics(
          identifier: 'home.queue',
          container: true,
          child: Container(
            padding: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: c.surface3,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(color: c.border),
                left: BorderSide(color: c.border),
                right: BorderSide(color: c.border),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < queueNarrowWidth;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      identifier: 'home.queue.header',
                      container: true,
                      child: SimPressable(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        semanticsLabel: '${widget.messages.length} Queued',
                        selected: _expanded,
                        builder: (context, state) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          color: state.hovered
                              ? c.surfaceHover
                              : const Color(0x00000000),
                          child: Row(
                            spacing: 6,
                            children: <Widget>[
                              SimIcon(
                                _expanded
                                    ? SimEmcnIcons.chevronDown
                                    : SimEmcnIcons.chevronRight,
                                color: c.textIcon,
                              ),
                              Text(
                                '${widget.messages.length} Queued',
                                style: sim.text.small.copyWith(
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_expanded)
                      for (var i = 0; i < widget.messages.length; i++)
                        _QueueRow(
                          message: widget.messages[i],
                          first: i == 0,
                          narrow: narrow,
                          editing: widget.messages[i].id == widget.editingId,
                          dispatching:
                              widget.messages[i].id == widget.dispatchingId,
                          onRemove: widget.onRemove,
                          onSendNow: widget.onSendNow,
                          onEdit: widget.onEdit,
                          onCancelEdit: widget.onCancelEdit,
                        ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueRow extends StatefulWidget {
  const _QueueRow({
    required this.message,
    required this.first,
    required this.narrow,
    required this.editing,
    required this.dispatching,
    required this.onRemove,
    required this.onSendNow,
    required this.onEdit,
    required this.onCancelEdit,
  });

  final HomeQueuedMessage message;
  final bool first;
  final bool narrow;
  final bool editing;
  final bool dispatching;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onSendNow;
  final ValueChanged<String> onEdit;
  final VoidCallback onCancelEdit;

  @override
  State<_QueueRow> createState() => _QueueRowState();
}

class _QueueRowState extends State<_QueueRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final message = widget.message;
    final editBlocked = widget.dispatching || message.admissionUnknown;
    final ringColor = widget.editing
        ? c.textSecondary.withValues(alpha: 0.6)
        : c.textTertiary.withValues(alpha: 0.4);
    final files = message.attachments;
    Widget row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.only(left: 14, right: 8, top: 6, bottom: 6),
        color: widget.editing
            ? c.surfaceActive
            : _hovered
            ? c.surfaceHover
            : const Color(0x00000000),
        child: Row(
          spacing: 8,
          children: <Widget>[
            SizedBox.square(
              dimension: 16,
              child: Center(
                child: CustomPaint(
                  size: const Size.square(10),
                  painter: _RingPainter(
                    color: ringColor,
                    dashed: widget.editing,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                message.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sim.text.inter(14, color: c.textPrimary),
              ),
            ),
            if (files.isNotEmpty)
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.narrow ? 80 : 200,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface5,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: <Widget>[
                        SimIcon(
                          SimEmcnIcons.paperclip,
                          size: 12,
                          color: c.textIcon,
                        ),
                        if (widget.narrow)
                          Text(
                            '${files.length}',
                            style: sim.text.small.copyWith(
                              color: c.textSecondary,
                            ),
                          )
                        else ...<Widget>[
                          Flexible(
                            child: Text(
                              files.first.filename,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: sim.text.small.copyWith(
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          if (files.length > 1)
                            Text(
                              '+${files.length - 1}',
                              style: sim.text.small.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: widget.editing
                  ? <Widget>[
                      _QueueAction(
                        icon: SimEmcnIcons.x,
                        label: 'Cancel edit',
                        onPressed: widget.onCancelEdit,
                      ),
                    ]
                  : <Widget>[
                      _QueueAction(
                        icon: SimEmcnIcons.pencil,
                        label: queueEditLabel(
                          dispatching: widget.dispatching,
                          admissionUnknown: message.admissionUnknown,
                        ),
                        parityId: widget.first ? 'home.queue.row.edit' : null,
                        ariaDisabled: editBlocked,
                        onPressed: () {
                          if (!editBlocked) widget.onEdit(message.id);
                        },
                      ),
                      _QueueAction(
                        icon: SimEmcnIcons.arrowUp,
                        label: 'Send now',
                        parityId: widget.first ? 'home.queue.row.send' : null,
                        enabled: !widget.dispatching,
                        onPressed: () => widget.onSendNow(message.id),
                      ),
                      _QueueAction(
                        icon: SimEmcnIcons.trash,
                        label: 'Remove from queue',
                        parityId: widget.first ? 'home.queue.row.remove' : null,
                        onPressed: () => widget.onRemove(message.id),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
    if (widget.first) {
      row = Semantics(
        identifier: 'home.queue.row',
        container: true,
        child: row,
      );
    }
    return row;
  }
}

/// `-mb-3`: lays [child] out normally but reports [margin] less height, so
/// the next sibling (the composer) overlaps its bottom edge.
class NegativeBottomMargin extends SingleChildRenderObjectWidget {
  const NegativeBottomMargin({
    required this.margin,
    required super.child,
    super.key,
  });

  final double margin;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderNegativeBottomMargin(margin);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderNegativeBottomMargin renderObject,
  ) => renderObject.margin = margin;
}

class RenderNegativeBottomMargin extends RenderProxyBox {
  RenderNegativeBottomMargin(this._margin);

  double _margin;
  double get margin => _margin;
  set margin(double value) {
    if (value == _margin) return;
    _margin = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints.copyWith(minHeight: 0), parentUsesSize: true);
    size = constraints.constrain(
      Size(
        child.size.width,
        (child.size.height - _margin).clamp(0, double.infinity),
      ),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final hit = child.hitTest(result, position: position);
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }
}

/// A 23px queue action with its top tooltip. [ariaDisabled] keeps hover
/// and focus (so the tooltip explains why) but ignores presses.
class _QueueAction extends StatelessWidget {
  const _QueueAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.parityId,
    this.enabled = true,
    this.ariaDisabled = false,
  });

  final SimIconData icon;
  final String label;
  final VoidCallback onPressed;
  final String? parityId;
  final bool enabled;
  final bool ariaDisabled;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final dimmed = !enabled || ariaDisabled;
    Widget action = SimTooltip(
      message: label,
      preferAbove: true,
      offset: 4,
      child: SimPressable(
        onPressed: enabled ? onPressed : null,
        enabled: enabled,
        semanticsLabel: label,
        builder: (context, state) {
          final hovered = state.hovered && !dimmed;
          return Opacity(
            opacity: dimmed ? 0.4 : 1,
            child: Container(
              width: 23,
              height: 23,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hovered ? c.surfaceActive : const Color(0x00000000),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SimIcon(
                icon,
                size: 13,
                color: hovered ? c.textPrimary : c.textIcon,
              ),
            ),
          );
        },
      ),
    );
    if (parityId != null) {
      action = Semantics(identifier: parityId, container: true, child: action);
    }
    return action;
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    final ring = rect.deflate(0.75);
    if (!dashed) {
      canvas.drawOval(ring, paint);
      return;
    }
    const segments = 8;
    const sweep = 3.14159265 * 2 / segments;
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(ring, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}
