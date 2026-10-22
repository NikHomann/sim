import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:sim_canvas/src/geometry/edge_hit_tester.dart';
import 'package:sim_canvas/src/geometry/smooth_step.dart';

/// Upstream `BLOCK_DIMENSIONS` / `CONTAINER_DIMENSIONS` / `HANDLE_POSITIONS`
/// (`packages/workflow-renderer/src/dimensions.ts`), the subset the spike uses.
abstract final class CanvasDimensions {
  static const double blockWidth = 250;
  static const double headerHeight = 40;
  static const double contentPadding = 16;
  static const double rowHeight = 20;
  static const double contentGap = 8;

  /// Header + padding + two rows + gap + padding.
  static const double blockHeight =
      headerHeight +
      contentPadding +
      rowHeight +
      contentGap +
      rowHeight +
      contentPadding;

  static const double containerWidth = 500;
  static const double containerHeight = 300;
  static const double containerHeaderHeight = 40;
  static const double containerLeftPadding = 24;
  static const double containerTopPadding = 24;
  static const double subflowStartTopOffset = 12;
  static const double subflowStartHeight = 34;
  static const double subflowStartWidth = 58;

  /// Y of every port on a loop/parallel container (`SUBFLOW_CONNECTION_Y`).
  static const double subflowConnectionY =
      containerHeaderHeight + subflowStartTopOffset + subflowStartHeight / 2;

  /// Upstream `WorkflowEdgeView`: `borderRadius: 8`, `offset: isHorizontal ? 30 : 20`.
  static const double edgeBorderRadius = 8;
  static const double edgeHorizontalOffset = 30;
  static const double edgeVerticalOffset = 20;
  static const double edgeHitWidth = 30;
}

enum CanvasNodeKind { block, container }

/// Canonical handle ids (`WORKFLOW_SOURCE_HANDLE_ID` / `WORKFLOW_TARGET_HANDLE_ID`).
abstract final class HandleIds {
  static const String source = 'source';
  static const String target = 'target';
}

@immutable
class CanvasNode {
  const CanvasNode({
    required this.id,
    required this.position,
    required this.size,
    this.kind = CanvasNodeKind.block,
    this.parentId,
    this.title = '',
    this.rows = const <String>[],
    this.accent = const Color(0xFF6366F1),
  });

  final String id;
  final CanvasNodeKind kind;

  /// Position relative to the parent container, or absolute when [parentId]
  /// is null (React Flow `parentId` + `extent: 'parent'` convention).
  final Offset position;
  final Size size;
  final String? parentId;
  final String title;
  final List<String> rows;
  final Color accent;

  bool get isContainer => kind == CanvasNodeKind.container;

  /// Local (node-relative) position of a handle.
  Offset handleOffset(String handleId) {
    final y = isContainer
        ? CanvasDimensions.subflowConnectionY
        : size.height / 2;
    return switch (handleId) {
      HandleIds.target => Offset(0, y),
      _ => Offset(size.width, y),
    };
  }

  HandlePosition handlePosition(String handleId) =>
      handleId == HandleIds.target ? HandlePosition.left : HandlePosition.right;
}

@immutable
class CanvasEdge {
  const CanvasEdge({
    required this.id,
    required this.source,
    required this.target,
    this.sourceHandle = HandleIds.source,
    this.targetHandle = HandleIds.target,
  });

  final String id;
  final String source;
  final String target;
  final String sourceHandle;
  final String targetHandle;
}

@immutable
class CanvasGraph {
  const CanvasGraph({required this.nodes, required this.edges});

  /// Paint order; containers precede their children.
  final List<CanvasNode> nodes;
  final List<CanvasEdge> edges;
}

/// Cached geometry of one edge, valid for a pair of endpoint position versions.
class EdgeGeometry {
  EdgeGeometry({
    required this.path,
    required this.sourceVersion,
    required this.targetVersion,
  });

  final SmoothStepPath path;
  final int sourceVersion;
  final int targetVersion;
}

/// Mutable view state of a [CanvasGraph] for the layers.
///
/// Positions are *absolute* canvas coordinates held in one `ValueNotifier`
/// per node, so dragging one node rebuilds only that node's position widget
/// (the React `useSubBlockValue`/per-node selector discipline). Moving a
/// container moves its descendants with it. Edge paths and hit samples are
/// cached per edge and recomputed lazily when an endpoint's version changes.
class GraphController {
  GraphController(
    this.graph, {
    double edgeHitWidth = CanvasDimensions.edgeHitWidth,
  }) : hitTester = EdgeHitTester(hitWidth: edgeHitWidth) {
    for (final node in graph.nodes) {
      _nodes[node.id] = node;
      _versions[node.id] = 0;
      final parent = node.parentId == null
          ? Offset.zero
          : absolutePosition(node.parentId!);
      _positions[node.id] = ValueNotifier<Offset>(parent + node.position);
      _children.putIfAbsent(node.parentId, () => <String>[]).add(node.id);
    }
    for (final edge in graph.edges) {
      _edges[edge.id] = edge;
      _edgesByNode.putIfAbsent(edge.source, () => <CanvasEdge>[]).add(edge);
      _edgesByNode.putIfAbsent(edge.target, () => <CanvasEdge>[]).add(edge);
    }
  }

  final CanvasGraph graph;
  final EdgeHitTester hitTester;

  final Map<String, CanvasNode> _nodes = <String, CanvasNode>{};
  final Map<String, CanvasEdge> _edges = <String, CanvasEdge>{};
  final Map<String, ValueNotifier<Offset>> _positions =
      <String, ValueNotifier<Offset>>{};
  final Map<String, int> _versions = <String, int>{};
  final Map<String?, List<String>> _children = <String?, List<String>>{};
  final Map<String, List<CanvasEdge>> _edgesByNode =
      <String, List<CanvasEdge>>{};
  final Map<String, EdgeGeometry> _geometry = <String, EdgeGeometry>{};

  /// Fires after any node moved (edge layer repaint, bounds recompute).
  final GeometryNotifier geometryChanged = GeometryNotifier();

  Iterable<CanvasNode> get nodes => graph.nodes;
  Iterable<CanvasEdge> get edges => graph.edges;
  int get nodeCount => _nodes.length;
  int get edgeCount => _edges.length;

  CanvasNode node(String id) => _nodes[id]!;
  CanvasEdge edge(String id) => _edges[id]!;
  CanvasNode? nodeOrNull(String id) => _nodes[id];

  ValueListenable<Offset> positionListenable(String id) => _positions[id]!;

  Offset absolutePosition(String id) => _positions[id]!.value;

  Rect absoluteRect(String id) => absolutePosition(id) & node(id).size;

  /// Absolute canvas position of [handleId] on node [id].
  Offset handlePosition(String id, String handleId) =>
      absolutePosition(id) + node(id).handleOffset(handleId);

  List<CanvasEdge> edgesOf(String nodeId) =>
      _edgesByNode[nodeId] ?? const <CanvasEdge>[];

  /// Moves a node (and its descendants) by [delta] canvas units.
  void moveNodeBy(String id, Offset delta) {
    if (delta == Offset.zero) return;
    _shift(id, delta);
    geometryChanged.notify();
  }

  /// Sets the absolute position of a node, moving its descendants with it.
  void setAbsolutePosition(String id, Offset absolute) {
    moveNodeBy(id, absolute - absolutePosition(id));
  }

  void _shift(String id, Offset delta) {
    final notifier = _positions[id]!;
    notifier.value = notifier.value + delta;
    _versions[id] = _versions[id]! + 1;
    for (final child in _children[id] ?? const <String>[]) {
      _shift(child, delta);
    }
  }

  /// Cached smooth-step geometry for [edge]; recomputed when either endpoint
  /// moved since the last call. Also refreshes the hit-test samples.
  EdgeGeometry geometryOf(CanvasEdge edge) {
    final sv = _versions[edge.source]!;
    final tv = _versions[edge.target]!;
    final cached = _geometry[edge.id];
    if (cached != null &&
        cached.sourceVersion == sv &&
        cached.targetVersion == tv) {
      return cached;
    }
    final sourceNode = node(edge.source);
    final targetNode = node(edge.target);
    final sourcePosition = sourceNode.handlePosition(edge.sourceHandle);
    final targetPosition = targetNode.handlePosition(edge.targetHandle);
    final path = smoothStepPath(
      source: handlePosition(edge.source, edge.sourceHandle),
      target: handlePosition(edge.target, edge.targetHandle),
      sourcePosition: sourcePosition,
      targetPosition: targetPosition,
      borderRadius: CanvasDimensions.edgeBorderRadius,
      offset: sourcePosition.isHorizontal
          ? CanvasDimensions.edgeHorizontalOffset
          : CanvasDimensions.edgeVerticalOffset,
    );
    final geometry = EdgeGeometry(
      path: path,
      sourceVersion: sv,
      targetVersion: tv,
    );
    _geometry[edge.id] = geometry;
    hitTester.update(edge.id, path.path);
    return geometry;
  }

  /// Ensures every edge's geometry and hit samples are current.
  void refreshGeometry() {
    graph.edges.forEach(geometryOf);
  }

  /// The topmost edge under [canvasPoint] (hit width in canvas units), or null.
  String? edgeAt(Offset canvasPoint) {
    refreshGeometry();
    return hitTester.edgeAt(canvasPoint);
  }

  /// Union of all node rects and edge path bounds, in canvas units.
  Rect contentBounds() {
    Rect? bounds;
    for (final node in graph.nodes) {
      final rect = absoluteRect(node.id);
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    for (final edge in graph.edges) {
      final rect = geometryOf(edge).path.path.getBounds();
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    return bounds ?? Rect.zero;
  }

  void dispose() {
    _positions.forEach((_, notifier) => notifier.dispose());
    geometryChanged.dispose();
  }
}

/// A `Listenable` the controller fires after node moves; the edge painter
/// uses it as its `repaint` listenable.
class GeometryNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
