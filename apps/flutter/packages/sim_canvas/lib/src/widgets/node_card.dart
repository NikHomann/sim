import 'package:flutter/widgets.dart';
import 'package:sim_canvas/src/model/canvas_graph.dart';

/// Visual approximation of upstream `block-view.tsx` (250 px wide card,
/// 40 px header with a coloured icon square, rows of `text-sm`) and
/// `subflow/node-view.tsx` (container with header and inset Start card).
/// Plain Flutter, no design tokens: the spike measures geometry and
/// rendering cost, not fidelity.
class NodeCard extends StatelessWidget {
  const NodeCard({required this.node, this.selected = false, super.key});

  final CanvasNode node;
  final bool selected;

  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _text = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _handle = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final body = node.isContainer
        ? _ContainerBody(node: node)
        : _BlockBody(node: node);
    final handleY = node.handleOffset(HandleIds.target).dy;
    return SizedBox(
      width: node.size.width,
      height: node.size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: node.isContainer ? const Color(0xFFF8FAFC) : _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? node.accent : _border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: body,
            ),
          ),
          _Handle(x: -5, y: handleY - 5),
          _Handle(x: node.size.width - 5, y: handleY - 5),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.x, required this.y});

  final double x;
  final double y;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: y,
      child: const SizedBox(
        width: 10,
        height: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: NodeCard._handle,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: NodeCard._surface, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CanvasDimensions.headerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 20,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: node.accent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Text(
                    node.title.isEmpty ? '?' : node.title.substring(0, 1),
                    style: const TextStyle(
                      color: NodeCard._surface,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NodeCard._text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockBody extends StatelessWidget {
  const _BlockBody({required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(node: node),
        Padding(
          padding: const EdgeInsets.all(CanvasDimensions.contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < node.rows.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: CanvasDimensions.contentGap),
                SizedBox(
                  height: CanvasDimensions.rowHeight,
                  child: Text(
                    node.rows[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NodeCard._textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ContainerBody extends StatelessWidget {
  const _ContainerBody({required this.node});

  final CanvasNode node;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(left: 0, right: 0, top: 0, child: _Header(node: node)),
        Positioned(
          left: CanvasDimensions.containerLeftPadding,
          top:
              CanvasDimensions.containerHeaderHeight +
              CanvasDimensions.subflowStartTopOffset,
          child: SizedBox(
            width: CanvasDimensions.subflowStartWidth,
            height: CanvasDimensions.subflowStartHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: NodeCard._surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NodeCard._border),
              ),
              child: const Center(
                child: Text(
                  'Start',
                  style: TextStyle(
                    color: NodeCard._textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
