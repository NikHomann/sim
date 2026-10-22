import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/block_config.dart';

/// Port of the lookup surface of `apps/sim/blocks/registry.ts`
/// (`getBlock`, `getAllBlocks`). The generated registry and the custom-block
/// overlay both implement this.
abstract interface class BlockRegistry {
  BlockConfig? getBlock(String type);

  Iterable<BlockConfig> get all;
}

/// An in-memory [BlockRegistry]; later entries with the same type win so an
/// overlay (custom blocks) can be layered over the generated registry.
class MapBlockRegistry implements BlockRegistry {
  MapBlockRegistry(Iterable<BlockConfig> blocks)
    : _byType = {for (final block in blocks) block.type: block};

  final Map<String, BlockConfig> _byType;

  @override
  BlockConfig? getBlock(String type) => _byType[type];

  @override
  Iterable<BlockConfig> get all => _byType.values;
}

/// Port of one entry of `ToolConfig['params']` from `apps/sim/tools/types.ts`
/// as the serializer reads it (`getToolParams` in `apps/sim/tools/metadata.ts`).
@immutable
class ToolParamConfig {
  const ToolParamConfig({
    required this.type,
    this.required,
    this.visibility,
    this.description,
  });

  final String type;
  final bool? required;

  /// `'user-or-llm' | 'user-only' | 'llm-only' | 'hidden'`.
  final String? visibility;
  final String? description;
}

/// Port of `getToolParams(toolId)` from `apps/sim/tools/metadata.ts`.
// ignore: one_member_abstracts, lookup contract implemented by the generated registry
abstract interface class ToolMetadataLookup {
  /// Declared params for a built-in tool, or null when unknown.
  Map<String, ToolParamConfig>? getToolParams(String toolId);
}

/// A [ToolMetadataLookup] that knows no tools, for callers that only need
/// the sub-block-level required-field pass.
class EmptyToolMetadataLookup implements ToolMetadataLookup {
  const EmptyToolMetadataLookup();

  @override
  Map<String, ToolParamConfig>? getToolParams(String toolId) => null;
}
