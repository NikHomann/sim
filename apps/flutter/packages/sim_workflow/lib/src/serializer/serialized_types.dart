/// Ports of `apps/sim/serializer/types.ts` (upstream 27b53561): the shape
/// `serializeWorkflow` produces and the executor consumes.
library;

import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/block_data.dart';
import 'package:sim_workflow/src/model/block_retry.dart';
import 'package:sim_workflow/src/model/json.dart';
import 'package:sim_workflow/src/model/position.dart';
import 'package:sim_workflow/src/model/subflow.dart';

/// Port of `SerializedConnection`.
@immutable
class SerializedConnection {
  const SerializedConnection({
    required this.source,
    required this.target,
    this.sourceHandle,
    this.targetHandle,
    this.condition,
  });

  factory SerializedConnection.fromJson(
    Map<String, Object?> json, [
    String path = '',
  ]) {
    final reader = JsonReader(json, path);
    return SerializedConnection(
      source: reader.string('source'),
      target: reader.string('target'),
      sourceHandle: reader.optionalString('sourceHandle'),
      targetHandle: reader.optionalString('targetHandle'),
      condition: reader.optionalObject('condition'),
    );
  }

  final String source;
  final String target;
  final String? sourceHandle;
  final String? targetHandle;

  /// `{ type: 'if' | 'else' | 'else if', expression? }`, kept raw.
  final Map<String, Object?>? condition;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{'source': source, 'target': target};
    putIfNotNull(json, 'sourceHandle', sourceHandle);
    putIfNotNull(json, 'targetHandle', targetHandle);
    putIfNotNull(json, 'condition', condition);
    return json;
  }
}

/// Port of `SerializedBlock['config']`.
@immutable
class SerializedBlockConfig {
  const SerializedBlockConfig({required this.tool, required this.params});

  final String tool;
  final Map<String, Object?> params;

  Map<String, Object?> toJson() => {'tool': tool, 'params': params};
}

/// Port of `SerializedBlock['metadata']`.
@immutable
class SerializedBlockMetadata {
  const SerializedBlockMetadata({
    required this.id,
    this.name,
    this.description,
    this.category,
    this.icon,
    this.color,
  });

  factory SerializedBlockMetadata.fromJson(
    Map<String, Object?> json, [
    String path = '',
  ]) {
    final reader = JsonReader(json, path);
    return SerializedBlockMetadata(
      id: reader.string('id'),
      name: reader.optionalString('name'),
      description: reader.optionalString('description'),
      category: reader.optionalString('category'),
      icon: reader.optionalString('icon'),
      color: reader.optionalString('color'),
    );
  }

  /// The block type.
  final String id;
  final String? name;
  final String? description;
  final String? category;
  final String? icon;
  final String? color;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{'id': id};
    putIfNotNull(json, 'name', name);
    putIfNotNull(json, 'description', description);
    putIfNotNull(json, 'category', category);
    putIfNotNull(json, 'icon', icon);
    putIfNotNull(json, 'color', color);
    return json;
  }
}

/// Port of `SerializedBlock`.
@immutable
class SerializedBlock {
  SerializedBlock({
    required this.id,
    required this.position,
    required this.config,
    required Map<String, String> inputs,
    required Map<String, Object?> outputs,
    required this.enabled,
    this.metadata,
    Map<String, CanonicalMode>? canonicalModes,
    List<String>? privateInputIds,
    this.retry,
  }) : inputs = Map<String, String>.unmodifiable(inputs),
       outputs = freezeMap(outputs),
       canonicalModes = canonicalModes == null
           ? null
           : Map<String, CanonicalMode>.unmodifiable(canonicalModes),
       privateInputIds = privateInputIds == null
           ? null
           : List<String>.unmodifiable(privateInputIds);

  factory SerializedBlock.fromJson(
    Map<String, Object?> json, [
    String path = '',
  ]) {
    final reader = JsonReader(json, path);
    final config = reader.child('config');
    final metadata = reader.optionalChild('metadata');
    final retry = reader.optionalChild('retry');
    final modes = reader.optionalObject('canonicalModes');
    final inputs = reader.optionalObject('inputs') ?? const {};
    return SerializedBlock(
      id: reader.string('id'),
      position: Position.fromJson(reader.object('position'), '$path.position'),
      config: SerializedBlockConfig(
        tool: config.string('tool'),
        params: config.optionalObject('params') ?? const {},
      ),
      inputs: {
        for (final entry in inputs.entries)
          entry.key: entry.value is String
              ? entry.value! as String
              : throw FormatException(
                  'Expected string at $path.inputs.${entry.key}',
                ),
      },
      outputs: reader.optionalObject('outputs') ?? const {},
      metadata: metadata == null
          ? null
          : SerializedBlockMetadata.fromJson(metadata.map, metadata.path),
      enabled: reader.optionalBool('enabled') ?? true,
      canonicalModes: modes == null
          ? null
          : {
              for (final entry in modes.entries)
                if (CanonicalMode.fromId(entry.value as String?) != null)
                  entry.key: CanonicalMode.fromId(entry.value! as String)!,
            },
      privateInputIds: reader.has('privateInputIds')
          ? reader.stringList('privateInputIds')
          : null,
      retry: retry == null
          ? null
          : BlockRetryConfig.fromJson(retry.map, retry.path),
    );
  }

  final String id;
  final Position position;
  final SerializedBlockConfig config;

  /// `inputs[key] = ParamConfig.type`.
  final Map<String, String> inputs;
  final Map<String, Object?> outputs;
  final SerializedBlockMetadata? metadata;
  final bool enabled;
  final Map<String, CanonicalMode>? canonicalModes;
  final List<String>? privateInputIds;
  final BlockRetryConfig? retry;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'id': id,
      'position': position.toJson(),
      'config': config.toJson(),
      'inputs': inputs,
      'outputs': outputs,
    };
    putIfNotNull(json, 'metadata', metadata?.toJson());
    json['enabled'] = enabled;
    putIfNotNull(json, 'retry', retry?.toJson());
    putIfNotNull(json, 'privateInputIds', privateInputIds);
    putIfNotNull(
      json,
      'canonicalModes',
      canonicalModes == null
          ? null
          : {
              for (final entry in canonicalModes!.entries)
                entry.key: entry.value.id,
            },
    );
    return json;
  }
}

/// Port of `SerializedWorkflow`. `loops` and `parallels` carry the full
/// [Loop] / [Parallel] records, as `serializeWorkflow` passes them through.
@immutable
class SerializedWorkflow {
  SerializedWorkflow({
    required this.version,
    required List<SerializedBlock> blocks,
    required List<SerializedConnection> connections,
    required Map<String, Loop> loops,
    Map<String, Parallel>? parallels,
  }) : blocks = List<SerializedBlock>.unmodifiable(blocks),
       connections = List<SerializedConnection>.unmodifiable(connections),
       loops = Map<String, Loop>.unmodifiable(loops),
       parallels = parallels == null
           ? null
           : Map<String, Parallel>.unmodifiable(parallels);

  factory SerializedWorkflow.fromJson(Map<String, Object?> json) {
    final reader = JsonReader(json);
    final blocks = reader.optionalList('blocks') ?? const [];
    final connections = reader.optionalList('connections') ?? const [];
    final loops = reader.optionalObject('loops') ?? const {};
    final parallels = reader.optionalObject('parallels');
    return SerializedWorkflow(
      version: reader.string('version'),
      blocks: [
        for (var i = 0; i < blocks.length; i++)
          SerializedBlock.fromJson(
            JsonReader({'$i': blocks[i]}, 'blocks').object('$i'),
            'blocks[$i]',
          ),
      ],
      connections: [
        for (var i = 0; i < connections.length; i++)
          SerializedConnection.fromJson(
            JsonReader({'$i': connections[i]}, 'connections').object('$i'),
            'connections[$i]',
          ),
      ],
      loops: {
        for (final entry in loops.entries)
          entry.key: Loop.fromJson(
            JsonReader(loops, 'loops').object(entry.key),
            'loops.${entry.key}',
          ),
      },
      parallels: parallels == null
          ? null
          : {
              for (final entry in parallels.entries)
                entry.key: Parallel.fromJson(
                  JsonReader(parallels, 'parallels').object(entry.key),
                  'parallels.${entry.key}',
                ),
            },
    );
  }

  final String version;
  final List<SerializedBlock> blocks;
  final List<SerializedConnection> connections;
  final Map<String, Loop> loops;
  final Map<String, Parallel>? parallels;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'version': version,
      'blocks': [for (final block in blocks) block.toJson()],
      'connections': [for (final c in connections) c.toJson()],
      'loops': {
        for (final entry in loops.entries) entry.key: entry.value.toJson(),
      },
    };
    putIfNotNull(
      json,
      'parallels',
      parallels == null
          ? null
          : {
              for (final entry in parallels!.entries)
                entry.key: entry.value.toJson(),
            },
    );
    return json;
  }
}
