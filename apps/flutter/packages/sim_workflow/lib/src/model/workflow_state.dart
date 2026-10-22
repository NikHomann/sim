import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/block_state.dart';
import 'package:sim_workflow/src/model/edge.dart';
import 'package:sim_workflow/src/model/json.dart';
import 'package:sim_workflow/src/model/position.dart';
import 'package:sim_workflow/src/model/subflow.dart';
import 'package:sim_workflow/src/model/variable.dart';

/// Port of `WorkflowState['metadata']` from
/// `packages/workflow-types/src/workflow.ts`.
@immutable
class WorkflowMetadata {
  WorkflowMetadata({
    this.name,
    this.description,
    this.exportedAt,
    Map<String, Object?> extra = const {},
  }) : extra = freezeMap(extra);

  factory WorkflowMetadata.fromJson(
    Map<String, Object?> json, [
    String path = '',
  ]) {
    final reader = JsonReader(json, path);
    return WorkflowMetadata(
      name: reader.optionalString('name'),
      description: reader.optionalString('description'),
      exportedAt: reader.optionalString('exportedAt'),
      extra: reader.extra(const {'name', 'description', 'exportedAt'}),
    );
  }

  final String? name;
  final String? description;
  final String? exportedAt;
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{...extra};
    putIfNotNull(json, 'name', name);
    putIfNotNull(json, 'description', description);
    putIfNotNull(json, 'exportedAt', exportedAt);
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is WorkflowMetadata &&
      deepEquality.equals(other.toJson(), toJson());

  @override
  int get hashCode => deepEquality.hash(toJson());
}

/// Port of `WorkflowState` from `packages/workflow-types/src/workflow.ts`.
///
/// Missing `blocks`/`edges`/`loops`/`parallels` decode to empty collections
/// (upstream readers guard with `|| {}`); `variables` stays null when absent
/// because the store distinguishes "never loaded" from "none".
@immutable
class WorkflowState {
  WorkflowState({
    Map<String, BlockState> blocks = const {},
    List<Edge> edges = const [],
    Map<String, Loop> loops = const {},
    Map<String, Parallel> parallels = const {},
    Map<String, Variable>? variables,
    this.currentWorkflowId,
    this.lastSaved,
    this.lastUpdate,
    this.metadata,
    this.dragStartPosition,
    Map<String, Object?> extra = const {},
  }) : blocks = Map<String, BlockState>.unmodifiable(blocks),
       edges = List<Edge>.unmodifiable(edges),
       loops = Map<String, Loop>.unmodifiable(loops),
       parallels = Map<String, Parallel>.unmodifiable(parallels),
       variables = variables == null
           ? null
           : Map<String, Variable>.unmodifiable(variables),
       extra = freezeMap(extra);

  factory WorkflowState.fromJson(Map<String, Object?> json) {
    final reader = JsonReader(json);
    final blocksJson = reader.optionalObject('blocks') ?? const {};
    final loopsJson = reader.optionalObject('loops') ?? const {};
    final parallelsJson = reader.optionalObject('parallels') ?? const {};
    final variablesJson = reader.optionalObject('variables');
    final edgesJson = reader.optionalList('edges') ?? const [];
    final metadataJson = reader.optionalChild('metadata');
    final dragJson = reader.optionalChild('dragStartPosition');
    return WorkflowState(
      currentWorkflowId: reader.optionalString('currentWorkflowId'),
      blocks: {
        for (final entry in blocksJson.entries)
          entry.key: BlockState.fromJson(
            JsonReader(blocksJson, 'blocks').object(entry.key),
            'blocks.${entry.key}',
          ),
      },
      edges: [
        for (var i = 0; i < edgesJson.length; i++)
          Edge.fromJson(
            JsonReader({'$i': edgesJson[i]}, 'edges').object('$i'),
            'edges[$i]',
          ),
      ],
      loops: {
        for (final entry in loopsJson.entries)
          entry.key: Loop.fromJson(
            JsonReader(loopsJson, 'loops').object(entry.key),
            'loops.${entry.key}',
          ),
      },
      parallels: {
        for (final entry in parallelsJson.entries)
          entry.key: Parallel.fromJson(
            JsonReader(parallelsJson, 'parallels').object(entry.key),
            'parallels.${entry.key}',
          ),
      },
      variables: variablesJson == null
          ? null
          : {
              for (final entry in variablesJson.entries)
                entry.key: Variable.fromJson(
                  JsonReader(variablesJson, 'variables').object(entry.key),
                  'variables.${entry.key}',
                ),
            },
      lastSaved: reader.optionalInt('lastSaved'),
      lastUpdate: reader.optionalInt('lastUpdate'),
      metadata: metadataJson == null
          ? null
          : WorkflowMetadata.fromJson(metadataJson.map, metadataJson.path),
      dragStartPosition: dragJson == null
          ? null
          : DragStartPosition.fromJson(dragJson.map, dragJson.path),
      extra: reader.extra(_knownKeys),
    );
  }

  static const _knownKeys = {
    'currentWorkflowId',
    'blocks',
    'edges',
    'lastSaved',
    'loops',
    'parallels',
    'lastUpdate',
    'metadata',
    'variables',
    'dragStartPosition',
  };

  final String? currentWorkflowId;
  final Map<String, BlockState> blocks;
  final List<Edge> edges;
  final Map<String, Loop> loops;
  final Map<String, Parallel> parallels;
  final Map<String, Variable>? variables;
  final int? lastSaved;
  final int? lastUpdate;
  final WorkflowMetadata? metadata;
  final DragStartPosition? dragStartPosition;
  final Map<String, Object?> extra;

  WorkflowState copyWith({
    Object? currentWorkflowId = _unset,
    Map<String, BlockState>? blocks,
    List<Edge>? edges,
    Map<String, Loop>? loops,
    Map<String, Parallel>? parallels,
    Object? variables = _unset,
    Object? lastSaved = _unset,
    Object? lastUpdate = _unset,
    Object? metadata = _unset,
    Object? dragStartPosition = _unset,
    Map<String, Object?>? extra,
  }) => WorkflowState(
    currentWorkflowId: _pick(currentWorkflowId, this.currentWorkflowId),
    blocks: blocks ?? this.blocks,
    edges: edges ?? this.edges,
    loops: loops ?? this.loops,
    parallels: parallels ?? this.parallels,
    variables: _pick(variables, this.variables),
    lastSaved: _pick(lastSaved, this.lastSaved),
    lastUpdate: _pick(lastUpdate, this.lastUpdate),
    metadata: _pick(metadata, this.metadata),
    dragStartPosition: _pick(dragStartPosition, this.dragStartPosition),
    extra: extra ?? this.extra,
  );

  Map<String, Object?> toJson() {
    final json = <String, Object?>{...extra};
    putIfNotNull(json, 'currentWorkflowId', currentWorkflowId);
    json['blocks'] = {
      for (final entry in blocks.entries) entry.key: entry.value.toJson(),
    };
    json['edges'] = [for (final edge in edges) edge.toJson()];
    putIfNotNull(json, 'lastSaved', lastSaved);
    json['loops'] = {
      for (final entry in loops.entries) entry.key: entry.value.toJson(),
    };
    json['parallels'] = {
      for (final entry in parallels.entries) entry.key: entry.value.toJson(),
    };
    putIfNotNull(json, 'lastUpdate', lastUpdate);
    putIfNotNull(json, 'metadata', metadata?.toJson());
    putIfNotNull(
      json,
      'variables',
      variables == null
          ? null
          : {
              for (final entry in variables!.entries)
                entry.key: entry.value.toJson(),
            },
    );
    putIfNotNull(json, 'dragStartPosition', dragStartPosition?.toJson());
    return json;
  }

  @override
  bool operator ==(Object other) =>
      other is WorkflowState &&
      other.currentWorkflowId == currentWorkflowId &&
      deepEquality.equals(other.blocks, blocks) &&
      deepEquality.equals(other.edges, edges) &&
      deepEquality.equals(other.loops, loops) &&
      deepEquality.equals(other.parallels, parallels) &&
      deepEquality.equals(other.variables, variables) &&
      other.lastSaved == lastSaved &&
      other.lastUpdate == lastUpdate &&
      other.metadata == metadata &&
      other.dragStartPosition == dragStartPosition &&
      deepEquality.equals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    currentWorkflowId,
    deepEquality.hash(blocks),
    deepEquality.hash(edges),
    deepEquality.hash(loops),
    deepEquality.hash(parallels),
    deepEquality.hash(variables),
    lastSaved,
    lastUpdate,
    metadata,
    dragStartPosition,
    deepEquality.hash(extra),
  );
}

const _unset = Object();

T _pick<T>(Object? candidate, T current) =>
    identical(candidate, _unset) ? current : candidate as T;
