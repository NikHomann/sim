import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/json.dart';

/// Port of `Position` from `packages/workflow-types/src/workflow.ts`.
@immutable
class Position {
  const Position({required this.x, required this.y});

  factory Position.fromJson(Map<String, Object?> json, [String path = '']) {
    final reader = JsonReader(json, path);
    return Position(x: reader.number('x'), y: reader.number('y'));
  }

  static const zero = Position(x: 0, y: 0);

  final double x;
  final double y;

  Position copyWith({double? x, double? y}) =>
      Position(x: x ?? this.x, y: y ?? this.y);

  Position translate(double dx, double dy) => Position(x: x + dx, y: y + dy);

  Map<String, Object?> toJson() => {'x': jsonNumber(x), 'y': jsonNumber(y)};

  @override
  bool operator ==(Object other) =>
      other is Position && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Position($x, $y)';
}

/// Port of `DragStartPosition` from `packages/workflow-types/src/workflow.ts`.
@immutable
class DragStartPosition {
  const DragStartPosition({
    required this.id,
    required this.x,
    required this.y,
    this.parentId,
  });

  factory DragStartPosition.fromJson(
    Map<String, Object?> json, [
    String path = '',
  ]) {
    final reader = JsonReader(json, path);
    return DragStartPosition(
      id: reader.string('id'),
      x: reader.number('x'),
      y: reader.number('y'),
      parentId: reader.optionalString('parentId'),
    );
  }

  final String id;
  final double x;
  final double y;

  /// Upstream allows `string | null | undefined`; both nullish forms are
  /// written back as an explicit `null` because the store always sets the key.
  final String? parentId;

  Map<String, Object?> toJson() => {
    'id': id,
    'x': jsonNumber(x),
    'y': jsonNumber(y),
    'parentId': parentId,
  };

  @override
  bool operator ==(Object other) =>
      other is DragStartPosition &&
      other.id == id &&
      other.x == x &&
      other.y == y &&
      other.parentId == parentId;

  @override
  int get hashCode => Object.hash(id, x, y, parentId);
}
