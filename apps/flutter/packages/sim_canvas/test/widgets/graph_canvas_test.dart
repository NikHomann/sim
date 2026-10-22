// Failure modes of canvas hit-testing (architecture-review-v1.md finding 8):
// 1. a node at negative canvas coordinates must be clickable after panning;
// 2. a node whose screen position lies beyond the content-sized layer box
//    must be clickable (RenderBox.hitTest rejects points outside its size;
//    RenderTransform skips that check, so a content-sized Stack with the
//    origin folded into the transform passes too);
// 3. an edge must be clickable on its stroke at zoom 0.5 and 1.3 and not
//    16+ canvas units away from it;
// 4. a click on empty space must resolve to empty, not to the nearest node;
// 5. a child inside a container must win over the container.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_canvas/sim_canvas.dart';

const _size = Size(CanvasDimensions.blockWidth, CanvasDimensions.blockHeight);

CanvasGraph _graph() => const CanvasGraph(
  nodes: <CanvasNode>[
    CanvasNode(
      id: 'neg',
      position: Offset(-900, -700),
      size: _size,
      title: 'Negative',
    ),
    CanvasNode(id: 'a', position: Offset.zero, size: _size, title: 'A'),
    CanvasNode(id: 'b', position: Offset(400, 300), size: _size, title: 'B'),
    CanvasNode(
      id: 'box',
      kind: CanvasNodeKind.container,
      position: Offset(0, 600),
      size: Size(
        CanvasDimensions.containerWidth,
        CanvasDimensions.containerHeight,
      ),
      title: 'Loop',
    ),
    CanvasNode(
      id: 'child',
      parentId: 'box',
      position: Offset(100, 80),
      size: _size,
      title: 'Child',
    ),
  ],
  edges: <CanvasEdge>[CanvasEdge(id: 'ab', source: 'a', target: 'b')],
);

class _Harness {
  _Harness(this.implementation)
    : controller = GraphController(_graph()),
      viewport = CanvasViewport();

  final NodeLayerImplementation implementation;
  final GraphController controller;
  final CanvasViewport viewport;
  final List<HitRecord> hits = <HitRecord>[];

  Widget build() => Directionality(
    textDirection: TextDirection.ltr,
    child: GraphCanvas(
      controller: controller,
      viewport: viewport,
      implementation: implementation,
      onHit: hits.add,
    ),
  );

  /// Places [canvasPoint] at [screen] with [zoom], taps there, returns the hits.
  Future<List<HitRecord>> tapCanvasPoint(
    WidgetTester tester,
    Offset canvasPoint, {
    Offset screen = const Offset(400, 300),
    double zoom = 1,
  }) async {
    viewport.setTransform(
      CanvasTransform(offset: screen - canvasPoint * zoom, zoom: zoom),
    );
    await tester.pump();
    hits.clear();
    await tester.tapAt(screen);
    await tester.pump();
    return List<HitRecord>.of(hits);
  }
}

void main() {
  for (final implementation in const <NodeLayerImplementation>[
    StackNodeLayer(),
    RenderBoxNodeLayer(),
  ]) {
    group(implementation.name, () {
      testWidgets(
        'node at negative canvas coordinates is clickable after panning',
        (tester) async {
          final h = _Harness(implementation);
          await tester.pumpWidget(h.build());
          final hits = await h.tapCanvasPoint(
            tester,
            h.controller.absoluteRect('neg').center,
          );
          expect(hits, const <HitRecord>[HitRecord.node('neg')]);
        },
      );

      testWidgets(
        'edge stroke is clickable at zoom 0.5 and 1.3; 16 units off is not',
        (tester) async {
          final h = _Harness(implementation);
          await tester.pumpWidget(h.build());
          // Vertical mid-segment of a→b at centerX = (250 + 400) / 2 = 325.
          const mid = Offset(325, 200);
          expect(
            await h.tapCanvasPoint(tester, mid, zoom: 0.5),
            const <HitRecord>[HitRecord.edge('ab')],
          );
          expect(
            await h.tapCanvasPoint(tester, mid, zoom: 1.3),
            const <HitRecord>[HitRecord.edge('ab')],
          );
          expect(
            await h.tapCanvasPoint(
              tester,
              mid + const Offset(14, 0),
              zoom: 1.3,
            ),
            const <HitRecord>[HitRecord.edge('ab')],
          );
          expect(
            await h.tapCanvasPoint(
              tester,
              mid + const Offset(16, 0),
              zoom: 0.5,
            ),
            const <HitRecord>[HitRecord.empty()],
          );
        },
      );

      testWidgets('empty space between nodes resolves to empty', (
        tester,
      ) async {
        final h = _Harness(implementation);
        await tester.pumpWidget(h.build());
        expect(
          await h.tapCanvasPoint(tester, const Offset(300, 250)),
          const <HitRecord>[HitRecord.empty()],
        );
      });

      testWidgets('child inside a container wins over the container', (
        tester,
      ) async {
        final h = _Harness(implementation);
        await tester.pumpWidget(h.build());
        final child = h.controller.absoluteRect('child').center;
        expect(await h.tapCanvasPoint(tester, child), const <HitRecord>[
          HitRecord.node('child'),
        ]);
        final containerHeader =
            h.controller.absolutePosition('box') + const Offset(20, 20);
        expect(
          await h.tapCanvasPoint(tester, containerHeader),
          const <HitRecord>[HitRecord.node('box')],
        );
      });

      testWidgets('node visible beyond the content-sized layer box', (
        tester,
      ) async {
        final h = _Harness(implementation);
        await tester.pumpWidget(h.build());
        // Content spans x∈[-900, 650], y∈[-700, 900] (+100 margin) → 1750×1800:
        // the Transform's untransformed size. A tap at screen (780, 580) is
        // inside the 800×600 test window but, for the Stack implementation,
        // outside that box only when the box is smaller than the window; so
        // use a two-node graph whose box (800×320) is.
        final tiny = GraphController(generateTinyWorkflow());
        final viewport = CanvasViewport();
        final hits = <HitRecord>[];
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: GraphCanvas(
              controller: tiny,
              viewport: viewport,
              implementation: implementation,
              onHit: hits.add,
            ),
          ),
        );
        const screen = Offset(780, 580);
        final center = tiny.absoluteRect('tiny-b').center;
        viewport.setTransform(
          CanvasTransform(offset: screen - center * 1.3, zoom: 1.3),
        );
        await tester.pump();
        await tester.tapAt(screen);
        await tester.pump();
        // Both pass: RenderTransform.hitTest deliberately skips the size
        // check, and the Stack is sized to the content bounds with the
        // bounds origin folded into the transform.
        expect(hits, const <HitRecord>[HitRecord.node('tiny-b')]);
        tiny.dispose();
      });
    });
  }
}
