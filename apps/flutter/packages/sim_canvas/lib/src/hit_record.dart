import 'package:flutter/foundation.dart';

enum HitKind { node, edge, empty }

/// What a tap on the canvas resolved to, reported through
/// `GraphCanvas.onHit` (used by the spike's hit-test checks).
@immutable
class HitRecord {
  const HitRecord(this.kind, [this.id]);

  const HitRecord.node(String id) : this(HitKind.node, id);
  const HitRecord.edge(String id) : this(HitKind.edge, id);
  const HitRecord.empty() : this(HitKind.empty);

  final HitKind kind;
  final String? id;

  @override
  bool operator ==(Object other) =>
      other is HitRecord && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => id == null ? kind.name : '${kind.name}:$id';
}
