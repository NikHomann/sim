// Failure modes for the edge rules
// (port of packages/workflow-types/src/workflow.ts):
//  wouldCreateCycle
//   1. A self-loop is a cycle even with no edges.
//   2. A direct back edge (b→a when a→b exists) is a cycle.
//   3. A long indirect cycle (a→b→c→d, adding d→a) is detected.
//   4. A diamond (a→b, a→c, b→d, c→d) is not a cycle when adding a→d.
//   5. Visited bookkeeping: a graph with a pre-existing cycle elsewhere does
//      not loop forever and still answers correctly.
//  filterAcyclicEdges
//   6. Edges within one batch that chain into a cycle are rejected
//      incrementally (second edge of a→b, b→a is dropped).
//  filterUniqueWorkflowEdges
//   7. Self-loops are dropped.
//   8. A duplicate of an existing edge (same source/target/handles) is dropped,
//      including when the handles differ only by '' vs null vs missing.
//   9. Two duplicates in the same batch keep only the first.
//  10. Different handles between the same blocks are both kept.
//  11. Side-anchored legacy handles (`source-right`, `target-left`) equal the
//      canonical ids for duplicate detection.
//  getWorkflowEdgeScopeDropReason
//  12. Missing source or target block → 'edge references a missing block'.
//  13. Same parent (both root or both in the same loop) → null.
//  14. Container → direct child → null; child → its container → null.
//  15. Root block → block inside a loop → reason string naming both scopes.
//  16. Non-container parent (a block whose `type` is not loop/parallel) with
//      its child → still rejected.
//  normalizeWorkflowEdgeHandles / collectErrorSourceBlockIds
//  17. Returns the same list instance when nothing changes, a new list when a
//      legacy handle is healed, and `[]` for null.
//  18. Error sources are collected after healing (`error` handle only).
//  19. resolveEffectiveErrorEnabled is true when the flag is off but an error
//      edge leaves the block.
import 'package:sim_workflow/sim_workflow.dart';
import 'package:test/test.dart';

Edge _edge(
  String id,
  String source,
  String target, {
  String? sourceHandle,
  String? targetHandle,
}) => Edge(
  id: id,
  source: source,
  target: target,
  sourceHandle: sourceHandle,
  targetHandle: targetHandle,
);

BlockState _block(String id, String type, {String? parentId}) => BlockState(
  id: id,
  type: type,
  name: id,
  position: Position.zero,
  subBlocks: const {},
  outputs: const {},
  enabled: true,
  data: parentId == null ? null : BlockData(parentId: parentId),
);

void main() {
  group('wouldCreateCycle', () {
    test('1. self-loop', () {
      expect(wouldCreateCycle(const [], 'a', 'a'), isTrue);
    });

    test('2. direct back edge', () {
      expect(wouldCreateCycle([_edge('1', 'a', 'b')], 'b', 'a'), isTrue);
    });

    test('3. indirect cycle', () {
      final edges = [
        _edge('1', 'a', 'b'),
        _edge('2', 'b', 'c'),
        _edge('3', 'c', 'd'),
      ];
      expect(wouldCreateCycle(edges, 'd', 'a'), isTrue);
    });

    test('4. diamond is not a cycle', () {
      final edges = [
        _edge('1', 'a', 'b'),
        _edge('2', 'a', 'c'),
        _edge('3', 'b', 'd'),
        _edge('4', 'c', 'd'),
      ];
      expect(wouldCreateCycle(edges, 'a', 'd'), isFalse);
    });

    test('5. pre-existing unrelated cycle terminates', () {
      final edges = [
        _edge('1', 'x', 'y'),
        _edge('2', 'y', 'x'),
        _edge('3', 'a', 'b'),
      ];
      expect(wouldCreateCycle(edges, 'b', 'x'), isFalse);
      expect(wouldCreateCycle(edges, 'b', 'a'), isTrue);
    });
  });

  test('6. filterAcyclicEdges evaluates incrementally', () {
    final kept = filterAcyclicEdges(
      [_edge('1', 'a', 'b'), _edge('2', 'b', 'a'), _edge('3', 'b', 'c')],
      const [],
    );
    expect(kept.map((e) => e.id), ['1', '3']);
  });

  group('filterUniqueWorkflowEdges', () {
    test('7. self-loops are dropped', () {
      expect(
        filterUniqueWorkflowEdges([_edge('1', 'a', 'a')], const []),
        isEmpty,
      );
    });

    test(
      '8. duplicates of existing edges are dropped (handle normalisation)',
      () {
        final existing = [_edge('1', 'a', 'b', sourceHandle: '')];
        expect(
          filterUniqueWorkflowEdges(
            [_edge('2', 'a', 'b'), _edge('3', 'a', 'b', sourceHandle: '')],
            existing,
          ),
          isEmpty,
        );
      },
    );

    test('9. duplicates within the batch keep the first', () {
      final kept = filterUniqueWorkflowEdges(
        [
          _edge('1', 'a', 'b', sourceHandle: 'source'),
          _edge('2', 'a', 'b', sourceHandle: 'source'),
        ],
        const [],
      );
      expect(kept.map((e) => e.id), ['1']);
    });

    test('10. different handles are both kept', () {
      final kept = filterUniqueWorkflowEdges(
        [
          _edge('1', 'a', 'b', sourceHandle: 'source'),
          _edge('2', 'a', 'b', sourceHandle: 'error'),
        ],
        const [],
      );
      expect(kept, hasLength(2));
    });

    test('11. legacy side-anchored handles equal canonical ids', () {
      final kept = filterUniqueWorkflowEdges(
        [
          _edge(
            '2',
            'a',
            'b',
            sourceHandle: 'source-right',
            targetHandle: 'target-left',
          ),
        ],
        [_edge('1', 'a', 'b', sourceHandle: 'source', targetHandle: 'target')],
      );
      expect(kept, isEmpty);
      expect(normalizeWorkflowEdgeSourceHandle('source-top'), 'source');
      expect(normalizeWorkflowEdgeTargetHandle('target-bottom'), 'target');
      expect(normalizeWorkflowEdgeSourceHandle('condition-x'), 'condition-x');
      expect(normalizeWorkflowEdgeSourceHandle(''), isNull);
    });
  });

  group('getWorkflowEdgeScopeDropReason', () {
    final blocks = {
      'root': _block('root', 'agent'),
      'loop': _block('loop', 'loop'),
      'child': _block('child', 'agent', parentId: 'loop'),
      'child2': _block('child2', 'agent', parentId: 'loop'),
      'fake': _block('fake', 'agent'),
      'fakeChild': _block('fakeChild', 'agent', parentId: 'fake'),
    };

    test('12. missing block', () {
      expect(
        getWorkflowEdgeScopeDropReason(_edge('1', 'root', 'ghost'), blocks),
        'edge references a missing block',
      );
    });

    test('13. same parent', () {
      expect(
        getWorkflowEdgeScopeDropReason(_edge('1', 'root', 'loop'), blocks),
        isNull,
      );
      expect(
        getWorkflowEdgeScopeDropReason(_edge('1', 'child', 'child2'), blocks),
        isNull,
      );
    });

    test('14. container <-> direct child', () {
      expect(
        getWorkflowEdgeScopeDropReason(_edge('1', 'loop', 'child'), blocks),
        isNull,
      );
      expect(
        getWorkflowEdgeScopeDropReason(_edge('1', 'child', 'loop'), blocks),
        isNull,
      );
    });

    test('15. crossing scopes names both', () {
      expect(
        getWorkflowEdgeScopeDropReason(_edge('1', 'root', 'child'), blocks),
        'blocks are in different scopes (root -> loop)',
      );
    });

    test('16. non-container parent is still rejected', () {
      expect(
        getWorkflowEdgeScopeDropReason(_edge('1', 'fake', 'fakeChild'), blocks),
        'blocks are in different scopes (root -> fake)',
      );
    });
  });

  group('handle healing', () {
    test('17. identity preserved when nothing changes', () {
      final edges = [_edge('1', 'a', 'b', sourceHandle: 'source')];
      expect(identical(normalizeWorkflowEdgeHandles(edges), edges), isTrue);
      final healed = normalizeWorkflowEdgeHandles(
        [_edge('1', 'a', 'b', sourceHandle: 'source-left')],
      );
      expect(healed.single.sourceHandle, 'source');
      expect(normalizeWorkflowEdgeHandles(null), isEmpty);
    });

    test('18. error sources are collected after healing', () {
      final sources = collectErrorSourceBlockIds([
        _edge('1', 'a', 'b', sourceHandle: 'error'),
        _edge('2', 'c', 'b', sourceHandle: 'source'),
      ]);
      expect(sources, {'a'});
    });

    test('19. effective error enabled reads edges too', () {
      final block = _block('a', 'agent');
      expect(resolveEffectiveErrorEnabled(block, 'a', const {}), isFalse);
      expect(resolveEffectiveErrorEnabled(block, 'a', const {'a'}), isTrue);
    });
  });
}
