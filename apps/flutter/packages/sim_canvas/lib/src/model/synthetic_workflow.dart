import 'dart:math' as math;
import 'dart:ui';

import 'package:sim_canvas/src/model/canvas_graph.dart';

/// Hand-placed nodes with known geometry, used by the hit-test checks.
///
/// `fanSource` has two edges whose vertical mid-segments are 60 canvas units
/// apart (`centerX = (sourceX + targetX) / 2` differs by 60 because the
/// targets' x differ by 120), so the midpoint between them is empty space
/// outside both 30-wide hit bands.
abstract final class SyntheticFixture {
  static const String fanSource = 'fx-source';
  static const String fanTargetNear = 'fx-target-near';
  static const String fanTargetFar = 'fx-target-far';
  static const String fanEdgeNear = 'fx-edge-near';
  static const String fanEdgeFar = 'fx-edge-far';
  static const String negativeNode = 'n-0-0';
  static const String containerChild = 'c0-child-0';
  static const String container = 'container-0';
}

/// Deterministic synthetic workflow: a grid of 250×120 block cards starting
/// at negative canvas coordinates, right-neighbour edges plus random longer
/// ones (forward, backward and cross-row so every smooth-step branch is
/// exercised), a few loop/parallel containers with children, and the
/// hit-test fixture below the grid.
CanvasGraph generateSyntheticWorkflow({
  int nodeCount = 200,
  int extraEdges = 75,
  int containerCount = 3,
  int childrenPerContainer = 3,
  int columns = 14,
  int seed = 42,
}) {
  final random = math.Random(seed);
  final nodes = <CanvasNode>[];
  final edges = <CanvasEdge>[];
  const accents = <Color>[
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
  ];
  const kinds = <String>[
    'Agent',
    'Function',
    'API',
    'Condition',
    'Router',
    'Loop',
  ];

  const pitchX = CanvasDimensions.blockWidth + 100;
  const pitchY = CanvasDimensions.blockHeight + 80;
  const origin = Offset(-700, -400);

  final gridCount = nodeCount - containerCount * (childrenPerContainer + 1);
  final rows = (gridCount / columns).ceil();
  final gridIds = <String>[];
  for (var i = 0; i < gridCount; i++) {
    final col = i % columns;
    final row = i ~/ columns;
    final id = 'n-$row-$col';
    gridIds.add(id);
    nodes.add(
      CanvasNode(
        id: id,
        position: origin + Offset(col * pitchX, row * pitchY),
        size: const Size(
          CanvasDimensions.blockWidth,
          CanvasDimensions.blockHeight,
        ),
        title: '${kinds[i % kinds.length]} ${i + 1}',
        rows: const <String>['model: gpt-4o', 'input: <start.input>'],
        accent: accents[i % accents.length],
      ),
    );
    if (col > 0) {
      edges.add(
        CanvasEdge(
          id: 'e-$row-${col - 1}-$col',
          source: 'n-$row-${col - 1}',
          target: id,
        ),
      );
    }
  }

  // Containers to the right of the grid, each with children.
  final containerX = origin.dx + columns * pitchX + 100;
  for (var c = 0; c < containerCount; c++) {
    final containerId = 'container-$c';
    nodes.add(
      CanvasNode(
        id: containerId,
        kind: CanvasNodeKind.container,
        position: Offset(
          containerX,
          origin.dy + c * (CanvasDimensions.containerHeight + 400),
        ),
        size: const Size(
          CanvasDimensions.containerWidth + 300,
          CanvasDimensions.containerHeight + 200,
        ),
        title: c.isEven ? 'Loop ${c + 1}' : 'Parallel ${c + 1}',
        accent: const Color(0xFF64748B),
      ),
    );
    String? previous;
    for (var k = 0; k < childrenPerContainer; k++) {
      final childId = 'c$c-child-$k';
      nodes.add(
        CanvasNode(
          id: childId,
          parentId: containerId,
          position: Offset(
            CanvasDimensions.containerLeftPadding + 120 + k * 230,
            CanvasDimensions.containerHeaderHeight +
                CanvasDimensions.containerTopPadding +
                (k.isOdd ? 170 : 20),
          ),
          size: const Size(
            CanvasDimensions.blockWidth,
            CanvasDimensions.blockHeight,
          ),
          title: 'Child ${k + 1}',
          rows: const <String>['iteration: <loop.index>', 'value: <loop.item>'],
          accent: accents[(c + k) % accents.length],
        ),
      );
      if (previous != null) {
        edges.add(
          CanvasEdge(id: 'e-$childId', source: previous, target: childId),
        );
      }
      previous = childId;
    }
    // Edge from the last grid column into the container's input.
    final row = math.min(rows - 1, c * 2);
    edges.add(
      CanvasEdge(
        id: 'e-into-$containerId',
        source: 'n-$row-${columns - 1}',
        target: containerId,
      ),
    );
  }

  // Random longer edges over the grid (forward, backward, cross-row).
  var attempts = 0;
  final seen = <String>{for (final e in edges) '${e.source}>${e.target}'};
  while (edges.length <
          gridCount -
              rows +
              extraEdges +
              containerCount * childrenPerContainer &&
      attempts < extraEdges * 20) {
    attempts++;
    final a = gridIds[random.nextInt(gridIds.length)];
    final b = gridIds[random.nextInt(gridIds.length)];
    if (a == b || !seen.add('$a>$b')) continue;
    edges.add(CanvasEdge(id: 'e-x-$a-$b', source: a, target: b));
  }

  // Hit-test fixture below the grid.
  final fixtureOrigin = Offset(origin.dx, origin.dy + rows * pitchY + 200);
  nodes
    ..add(
      CanvasNode(
        id: SyntheticFixture.fanSource,
        position: fixtureOrigin,
        size: const Size(
          CanvasDimensions.blockWidth,
          CanvasDimensions.blockHeight,
        ),
        title: 'Fixture source',
        rows: const <String>['two edges', 'vertical segments 60 apart'],
      ),
    )
    ..add(
      CanvasNode(
        id: SyntheticFixture.fanTargetNear,
        position: fixtureOrigin + const Offset(400, 300),
        size: const Size(
          CanvasDimensions.blockWidth,
          CanvasDimensions.blockHeight,
        ),
        title: 'Fixture near',
        rows: const <String>['centerX = +325', ''],
      ),
    )
    ..add(
      CanvasNode(
        id: SyntheticFixture.fanTargetFar,
        position: fixtureOrigin + const Offset(520, 600),
        size: const Size(
          CanvasDimensions.blockWidth,
          CanvasDimensions.blockHeight,
        ),
        title: 'Fixture far',
        rows: const <String>['centerX = +385', ''],
      ),
    );
  edges
    ..add(
      const CanvasEdge(
        id: SyntheticFixture.fanEdgeNear,
        source: SyntheticFixture.fanSource,
        target: SyntheticFixture.fanTargetNear,
      ),
    )
    ..add(
      const CanvasEdge(
        id: SyntheticFixture.fanEdgeFar,
        source: SyntheticFixture.fanSource,
        target: SyntheticFixture.fanTargetFar,
      ),
    );

  return CanvasGraph(nodes: nodes, edges: edges);
}

/// Two blocks side by side: small enough that a `Stack` sized to its content
/// bounds is smaller than the viewport, which exposes the hit-test failure
/// of `RenderBox.hitTest` outside the box (`architecture-review-v1.md` finding 8a).
CanvasGraph generateTinyWorkflow() {
  const size = Size(CanvasDimensions.blockWidth, CanvasDimensions.blockHeight);
  return const CanvasGraph(
    nodes: <CanvasNode>[
      CanvasNode(
        id: 'tiny-a',
        position: Offset.zero,
        size: size,
        title: 'Tiny A',
      ),
      CanvasNode(
        id: 'tiny-b',
        position: Offset(350, 0),
        size: size,
        title: 'Tiny B',
      ),
    ],
    edges: <CanvasEdge>[
      CanvasEdge(id: 'tiny-ab', source: 'tiny-a', target: 'tiny-b'),
    ],
  );
}
