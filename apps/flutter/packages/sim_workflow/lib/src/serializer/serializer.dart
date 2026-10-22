/// Port of `apps/sim/serializer/index.ts` (upstream 27b53561):
/// `Serializer.serializeWorkflow` / `deserializeWorkflow`,
/// `extractBlockParams`, `selectToolId` and `collectBlockFieldIssues`,
/// against the `BlockRegistry` and `ToolMetadataLookup` contracts.
///
/// Not ported (see the package README TODO list): the two block-state
/// migrations `migrateGreenhouseAgentInputs` and
/// `migrateMcpOperationControls`, which are injected through
/// `WorkflowSerializer.migrations` once hand-ported.
library;

import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/block_config.dart';
import 'package:sim_workflow/src/model/block_data.dart';
import 'package:sim_workflow/src/model/block_registry.dart';
import 'package:sim_workflow/src/model/block_retry.dart';
import 'package:sim_workflow/src/model/block_state.dart';
import 'package:sim_workflow/src/model/edge.dart';
import 'package:sim_workflow/src/model/sub_block_state.dart';
import 'package:sim_workflow/src/model/subflow.dart';
import 'package:sim_workflow/src/rules/canonical.dart';
import 'package:sim_workflow/src/rules/condition.dart';
import 'package:sim_workflow/src/rules/environment.dart';
import 'package:sim_workflow/src/rules/subflow_helpers.dart';
import 'package:sim_workflow/src/serializer/serialized_types.dart';

/// Port of `CUSTOM_BLOCK_TYPE_PREFIX` / `isCustomBlockType` from
/// `apps/sim/blocks/custom/build-config.ts`.
const String customBlockTypePrefix = 'custom_block_';

bool isCustomBlockType(String? type) =>
    type != null && type.startsWith(customBlockTypePrefix);

/// Port of `RESERVED_PARAMS` from `apps/sim/blocks/custom/build-config.ts`.
const Set<String> reservedCustomBlockParams = {
  'workflowId',
  'inputMapping',
  'triggerMode',
  'advancedMode',
};

/// Port of `MissingRequiredFieldsError` from `apps/sim/serializer/errors.ts`.
class MissingRequiredFieldsError implements Exception {
  MissingRequiredFieldsError(this.blockName, List<String> missingFields)
    : missingFields = List<String>.unmodifiable(missingFields);

  final String blockName;
  final List<String> missingFields;

  String get message =>
      '$blockName is missing required fields: ${missingFields.join(', ')}';

  @override
  String toString() => 'MissingRequiredFieldsError: $message';
}

/// The `Invalid block type` error upstream throws as a bare `Error`.
class UnknownBlockTypeError implements Exception {
  const UnknownBlockTypeError(this.type);

  final String? type;

  @override
  String toString() => 'UnknownBlockTypeError: Invalid block type: $type';
}

/// Port of `InactiveModeValue['kind']`.
enum InactiveModeValueKind { credential, resource, other }

/// Port of `InactiveModeValue`: a canonical pair whose active member is
/// empty while an inactive member holds a value that will be dropped.
@immutable
class InactiveModeValue {
  const InactiveModeValue({
    required this.canonicalId,
    required this.inactiveMemberId,
    required this.kind,
    this.activeMemberId,
  });

  final String canonicalId;
  final String? activeMemberId;
  final String inactiveMemberId;
  final InactiveModeValueKind kind;
}

/// Port of `BlockFieldIssues`.
@immutable
class BlockFieldIssues {
  BlockFieldIssues({
    required List<String> missingRequiredFields,
    required List<InactiveModeValue> inactiveModeValues,
  }) : missingRequiredFields = List<String>.unmodifiable(missingRequiredFields),
       inactiveModeValues = List<InactiveModeValue>.unmodifiable(
         inactiveModeValues,
       );

  static final BlockFieldIssues none = BlockFieldIssues(
    missingRequiredFields: const [],
    inactiveModeValues: const [],
  );

  final List<String> missingRequiredFields;
  final List<InactiveModeValue> inactiveModeValues;
}

/// Port of `BlockFieldIssueOptions['mode']`.
enum BlockFieldIssueMode { execution, lint }

/// Log levels the serializer reports through [SerializerLog].
enum SerializerLogLevel { info, warn, error }

/// Replacement for `createLogger('Serializer')`.
typedef SerializerLog =
    void Function(
      SerializerLogLevel level,
      String message,
      Map<String, Object?> data,
    );

/// The result of [WorkflowSerializer.deserializeWorkflow].
typedef DeserializedWorkflow = ({
  Map<String, BlockState> blocks,
  List<Edge> edges,
});

/// Port of `Serializer` plus the module-level helpers of
/// `apps/sim/serializer/index.ts`.
class WorkflowSerializer {
  WorkflowSerializer({
    required this.registry,
    this.toolMetadata = const EmptyToolMetadataLookup(),
    this.environment = SubBlockEnvironment.selfHosted,
    String Function()? idGenerator,
    SerializerLog? log,
    List<BlockState Function(BlockState block)> migrations = const [],
  }) : _idGenerator = idGenerator ?? generateUuidV4,
       _log = log ?? _noLog,
       _migrations = List.unmodifiable(migrations);

  final BlockRegistry registry;
  final ToolMetadataLookup toolMetadata;
  final SubBlockEnvironment environment;
  final String Function() _idGenerator;
  final SerializerLog _log;
  final List<BlockState Function(BlockState block)> _migrations;

  static void _noLog(
    SerializerLogLevel level,
    String message,
    Map<String, Object?> data,
  ) {}

  BlockState _migrate(BlockState block) {
    var current = block;
    for (final migration in _migrations) {
      current = migration(current);
    }
    return current;
  }

  /// Port of `shouldSerializeSubBlock`.
  bool _shouldSerializeSubBlock(
    SubBlockConfig subBlockConfig,
    Map<String, Object?> values, {
    required bool displayAdvancedOptions,
    required bool isTriggerContext,
    required bool isTriggerCategory,
    required CanonicalIndex canonicalIndex,
    CanonicalModeOverrides? canonicalModeOverrides,
  }) {
    if (isToolInputOnlySubBlock(subBlockConfig)) return false;
    if (isSubBlockHidden(subBlockConfig, environment)) return false;

    if (subBlockConfig.mode == SubBlockMode.trigger ||
        subBlockConfig.mode == SubBlockMode.triggerAdvanced) {
      if (!isTriggerContext && !isTriggerCategory) return false;
    } else if (isTriggerContext && !isTriggerCategory) {
      return false;
    }

    final canonicalId =
        canonicalIndex.canonicalIdBySubBlockId[subBlockConfig.id];
    if (canonicalId != null) {
      final group = canonicalIndex.groupsById[canonicalId];
      if (group != null && isCanonicalPair(group)) {
        final mode =
            canonicalModeOverrides?[group.canonicalId] != null ||
                !displayAdvancedOptions
            ? resolveCanonicalMode(group, values, canonicalModeOverrides)
            : CanonicalMode.advanced;
        final matchesMode = mode == CanonicalMode.advanced
            ? group.advancedIds.contains(subBlockConfig.id)
            : group.basicId == subBlockConfig.id;
        return matchesMode &&
            evaluateSubBlockCondition(subBlockConfig.condition, values);
      }
      return evaluateSubBlockCondition(subBlockConfig.condition, values);
    }

    if (subBlockConfig.mode == SubBlockMode.advanced &&
        !displayAdvancedOptions) {
      return isNonEmptyValue(values[subBlockConfig.id]);
    }
    if (subBlockConfig.mode == SubBlockMode.basic && displayAdvancedOptions) {
      return false;
    }

    return evaluateSubBlockCondition(subBlockConfig.condition, values);
  }

  /// Port of `Serializer.serializeWorkflow`.
  ///
  /// Loops and parallels are regenerated from the container blocks; the
  /// passed maps are only used when the workflow has no container block. A
  /// custom block whose definition no longer resolves is dropped with its
  /// edges rather than failing the whole workflow.
  SerializedWorkflow serializeWorkflow(
    Map<String, BlockState> blocks,
    List<Edge> edges, {
    Map<String, Loop>? loops,
    Map<String, Parallel>? parallels,
    bool validateRequired = false,
  }) {
    final canonicalLoops = generateLoopBlocks(blocks);
    final canonicalParallels = generateParallelBlocks(blocks);
    final safeLoops = canonicalLoops.isNotEmpty ? canonicalLoops : loops ?? {};
    final safeParallels = canonicalParallels.isNotEmpty
        ? canonicalParallels
        : parallels ?? {};

    final droppedBlockIds = <String>{};
    final serializedBlocks = <SerializedBlock>[];
    for (final block in blocks.values) {
      if (isCustomBlockType(block.type) &&
          registry.getBlock(block.type) == null) {
        droppedBlockIds.add(block.id);
        _log(
          SerializerLogLevel.warn,
          'Dropping unresolvable custom block from serialization',
          {'blockId': block.id, 'type': block.type},
        );
        continue;
      }
      serializedBlocks.add(
        _serializeBlock(block, validateRequired: validateRequired),
      );
    }

    return SerializedWorkflow(
      version: '1.0',
      blocks: serializedBlocks,
      connections: [
        for (final edge in edges)
          if (!droppedBlockIds.contains(edge.source) &&
              !droppedBlockIds.contains(edge.target))
            SerializedConnection(
              source: edge.source,
              target: edge.target,
              sourceHandle: _orNull(edge.sourceHandle),
              targetHandle: _orNull(edge.targetHandle),
            ),
      ],
      loops: safeLoops,
      parallels: safeParallels,
    );
  }

  static String? _orNull(String? handle) =>
      handle == null || handle.isEmpty ? null : handle;

  /// Port of `Serializer.serializeBlock`.
  SerializedBlock _serializeBlock(
    BlockState input, {
    required bool validateRequired,
  }) {
    if (input.type == SubflowTypes.loop ||
        input.type == SubflowTypes.parallel) {
      final isLoop = input.type == SubflowTypes.loop;
      return SerializedBlock(
        id: input.id,
        position: input.position,
        config: SerializedBlockConfig(
          tool: '',
          params: input.data?.toJson() ?? const {},
        ),
        inputs: const {},
        outputs: input.outputs,
        metadata: SerializedBlockMetadata(
          id: input.type,
          name: input.name,
          description: isLoop ? 'Loop container' : 'Parallel container',
          category: 'subflow',
          color: isLoop ? '#3b82f6' : '#8b5cf6',
        ),
        enabled: input.enabled,
      );
    }

    final block = _migrate(input);
    final blockConfig = registry.getBlock(block.type);
    if (blockConfig == null) throw UnknownBlockTypeError(block.type);

    final params = extractBlockParams(block);

    final isTriggerCategory = blockConfig.category == BlockCategory.triggers;
    if ((block.triggerMode ?? false) || isTriggerCategory) {
      params['triggerMode'] = true;
    }
    if (block.advancedMode ?? false) {
      params['advancedMode'] = true;
    }

    if (validateRequired) {
      final issues = collectBlockFieldIssues(block, blockConfig, params);
      if (issues.missingRequiredFields.isNotEmpty) {
        final blockName = block.name.isNotEmpty
            ? block.name
            : blockConfig.name.isNotEmpty
            ? blockConfig.name
            : 'Block';
        throw MissingRequiredFieldsError(
          blockName,
          issues.missingRequiredFields,
        );
      }
    }

    var toolId = '';
    final tools = params['tools'];
    if (block.type == 'agent' && _isTruthy(tools)) {
      try {
        final parsed = tools is List
            ? tools
            : jsonDecode(tools! as String) as List<Object?>;
        final nonCustom = parsed.where(
          (tool) => !(tool is Map && tool['type'] == 'custom-tool'),
        );
        if (nonCustom.isNotEmpty) {
          toolId = selectToolId(blockConfig, params);
        }
      } on Object catch (error) {
        _log(
          SerializerLogLevel.error,
          'Error processing tools in agent block:',
          {'error': error.toString()},
        );
        toolId = blockConfig.tools.access.first;
      }
    } else if (params['triggerMode'] != true) {
      toolId = selectToolId(blockConfig, params);
    }

    final inputs = {
      for (final entry in blockConfig.inputs.entries)
        entry.key: entry.value.type,
    };

    final retry = resolveBlockRetryConfig(block.retry);

    final privateInputIds = <String>{};
    for (final subBlock in blockConfig.subBlocks) {
      if (!(subBlock.hideFromCopilot ?? false)) continue;
      privateInputIds.add(subBlock.id);
      final canonicalId = subBlock.canonicalParamId;
      if (canonicalId != null) privateInputIds.add(canonicalId);
    }

    return SerializedBlock(
      id: block.id,
      position: block.position,
      config: SerializedBlockConfig(tool: toolId, params: params),
      inputs: inputs,
      outputs: {...block.outputs},
      metadata: SerializedBlockMetadata(
        id: block.type,
        name: block.name,
        description: blockConfig.description,
        category: blockConfig.category.id,
        color: blockConfig.bgColor,
      ),
      enabled: block.enabled,
      retry: retry,
      privateInputIds: privateInputIds.isEmpty
          ? null
          : privateInputIds.toList(),
      canonicalModes: block.data?.canonicalModes,
    );
  }

  /// Port of `Serializer.deserializeWorkflow`.
  DeserializedWorkflow deserializeWorkflow(SerializedWorkflow workflow) {
    final blocks = <String, BlockState>{};
    final edges = <Edge>[];
    final droppedBlockIds = <String>{};

    for (final serializedBlock in workflow.blocks) {
      final type = serializedBlock.metadata?.id;
      if (isCustomBlockType(type) && registry.getBlock(type!) == null) {
        droppedBlockIds.add(serializedBlock.id);
        _log(
          SerializerLogLevel.warn,
          'Dropping unresolvable custom block from deserialization',
          {'blockId': serializedBlock.id, 'type': type},
        );
        continue;
      }
      final block = _deserializeBlock(serializedBlock);
      blocks[block.id] = block;
    }

    for (final connection in workflow.connections) {
      if (droppedBlockIds.contains(connection.source) ||
          droppedBlockIds.contains(connection.target)) {
        continue;
      }
      edges.add(
        Edge(
          id: _idGenerator(),
          source: connection.source,
          target: connection.target,
          sourceHandle: connection.sourceHandle,
          targetHandle: connection.targetHandle,
        ),
      );
    }

    return (blocks: blocks, edges: edges);
  }

  /// Port of `Serializer.deserializeBlock`.
  BlockState _deserializeBlock(SerializedBlock serializedBlock) {
    final blockType = serializedBlock.metadata?.id;
    if (blockType == null || blockType.isEmpty) {
      throw UnknownBlockTypeError(blockType);
    }

    if (blockType == SubflowTypes.loop || blockType == SubflowTypes.parallel) {
      final name = serializedBlock.metadata?.name;
      return BlockState(
        id: serializedBlock.id,
        type: blockType,
        name: name != null && name.isNotEmpty
            ? name
            : blockType == SubflowTypes.loop
            ? 'Loop'
            : 'Parallel',
        position: serializedBlock.position,
        subBlocks: const {},
        outputs: serializedBlock.outputs,
        enabled: serializedBlock.enabled,
        data: BlockData.fromJson(serializedBlock.config.params),
      );
    }

    final blockConfig = registry.getBlock(blockType);
    if (blockConfig == null) throw UnknownBlockTypeError(blockType);

    final params = serializedBlock.config.params;
    final subBlocks = <String, SubBlockState>{
      for (final subBlock in blockConfig.subBlocks)
        subBlock.id: SubBlockState(
          id: subBlock.id,
          type: subBlock.type,
          value:
              _collectSubBlockValueFromParams(subBlock, params) ??
              params[subBlock.id],
        ),
    };

    if (blockType == 'agent') {
      _migrateAgentParamsToMessages(params, subBlocks, serializedBlock.id);
    }

    final name = serializedBlock.metadata?.name;
    return BlockState(
      id: serializedBlock.id,
      type: blockType,
      name: name != null && name.isNotEmpty ? name : blockConfig.name,
      position: serializedBlock.position,
      subBlocks: subBlocks,
      outputs: serializedBlock.outputs,
      enabled: true,
      triggerMode:
          params['triggerMode'] == true ||
          serializedBlock.metadata?.category == 'triggers',
      advancedMode: params['advancedMode'] == true,
      retry: serializedBlock.retry,
    );
  }

  /// Port of `migrateAgentParamsToMessages`: legacy `systemPrompt` /
  /// `userPrompt` become a `messages` array when none exists yet.
  void _migrateAgentParamsToMessages(
    Map<String, Object?> params,
    Map<String, SubBlockState> subBlocks,
    String blockId,
  ) {
    final systemPrompt = params['systemPrompt'];
    final userPrompt = params['userPrompt'];
    if (!(_isTruthy(systemPrompt) || _isTruthy(userPrompt)) ||
        _isTruthy(params['messages'])) {
      return;
    }
    _log(
      SerializerLogLevel.info,
      'Migrating agent block from legacy format to messages array',
      {
        'blockId': blockId,
        'hasSystemPrompt': _isTruthy(systemPrompt),
        'hasUserPrompt': _isTruthy(userPrompt),
      },
    );

    final messages = <Map<String, Object?>>[];
    if (_isTruthy(systemPrompt)) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    if (_isTruthy(userPrompt)) {
      var userContent = userPrompt;
      if (userContent is Map) {
        userContent = userContent.containsKey('input')
            ? userContent['input']
            : jsonEncode(userContent);
      }
      messages.add({'role': 'user', 'content': _jsString(userContent)});
    }

    subBlocks['messages'] = SubBlockState(
      id: 'messages',
      type: 'messages-input',
      value: messages,
    );
  }

  /// Port of `selectToolId`: `tools.config.tool(params)` when declared,
  /// `tools.access[0]` otherwise or when the selector throws.
  String selectToolId(BlockConfig blockConfig, Map<String, Object?> params) {
    final selector = blockConfig.tools.toolSelector;
    try {
      return selector != null
          ? selector.select(params)
          : blockConfig.tools.access.first;
    } on Object catch (error) {
      _log(
        SerializerLogLevel.warn,
        'Tool selection failed during serialization, using default:',
        {'error': error.toString()},
      );
      return blockConfig.tools.access.first;
    }
  }

  /// Port of `extractBlockParams`: the flat `params` map the runtime sees,
  /// resolved exactly as `serializeBlock` does. Containers have none;
  /// unknown block types throw.
  Map<String, Object?> extractBlockParams(BlockState input) {
    final block = _migrate(input);
    if (block.type == SubflowTypes.loop ||
        block.type == SubflowTypes.parallel) {
      return {};
    }

    final blockConfig = registry.getBlock(block.type);
    if (blockConfig == null) throw UnknownBlockTypeError(block.type);

    final params = <String, Object?>{};
    final legacyAdvancedMode = block.advancedMode ?? false;
    final canonicalModeOverrides = block.data?.canonicalModes;
    final isStarterBlock = block.type == 'starter';
    final isAgentBlock = block.type == 'agent';
    final isCustomBlock = isCustomBlockType(block.type);
    final customBlockHasDeclaredInputs =
        isCustomBlock &&
        blockConfig.subBlocks.any(
          (config) => !reservedCustomBlockParams.contains(config.id),
        );
    final isTriggerContext = block.triggerMode ?? false;
    final isTriggerCategory = blockConfig.category == BlockCategory.triggers;
    final canonicalIndex = buildCanonicalIndex(blockConfig.subBlocks);
    final allValues = buildSubBlockValues(block.subBlocks);

    bool shouldSerialize(SubBlockConfig config) => _shouldSerializeSubBlock(
      config,
      allValues,
      displayAdvancedOptions: legacyAdvancedMode,
      isTriggerContext: isTriggerContext,
      isTriggerCategory: isTriggerCategory,
      canonicalIndex: canonicalIndex,
      canonicalModeOverrides: canonicalModeOverrides,
    );

    for (final entry in block.subBlocks.entries) {
      final id = entry.key;
      final subBlock = entry.value;
      final matchingConfigs = blockConfig.subBlocks
          .where((config) => config.id == id)
          .toList();

      final value = subBlock.value;
      final hasStarterInputFormatValues =
          isStarterBlock &&
          id == 'inputFormat' &&
          value is List &&
          value.isNotEmpty;

      final isLegacyAgentField =
          isAgentBlock &&
          const ['systemPrompt', 'userPrompt', 'memories'].contains(id);

      final shouldInclude =
          matchingConfigs.isEmpty || matchingConfigs.any(shouldSerialize);

      final isCustomBlockInputField =
          isCustomBlock &&
          matchingConfigs.isEmpty &&
          !customBlockHasDeclaredInputs;

      final isCustomBlockWiring =
          isCustomBlock && (id == 'workflowId' || id == 'inputMapping');

      if (!isCustomBlockWiring &&
          ((matchingConfigs.isNotEmpty && shouldInclude) ||
              hasStarterInputFormatValues ||
              isLegacyAgentField ||
              isCustomBlockInputField)) {
        Map<String, bool>? expanded;
        for (final config in matchingConfigs) {
          expanded ??= expandSubBlockValueToParams(config, value);
        }
        if (expanded != null) {
          params.addAll(expanded);
        } else {
          params[id] = value;
        }
      }
    }

    for (final subBlockConfig in blockConfig.subBlocks) {
      final id = subBlockConfig.id;
      final provider = subBlockConfig.valueProvider;
      if (params[id] == null &&
          provider != null &&
          shouldSerialize(subBlockConfig)) {
        params[id] = provider(params);
      }
    }

    for (final group in canonicalIndex.groupsById.values) {
      final selection = getCanonicalValues(group, params);
      final hasExplicitOverride =
          canonicalModeOverrides?[group.canonicalId] != null;
      final legacyAdvancedWins =
          legacyAdvancedMode && !hasExplicitOverride && isCanonicalPair(group);
      final pairMode = legacyAdvancedWins
          ? CanonicalMode.advanced
          : resolveCanonicalMode(group, allValues, canonicalModeOverrides);
      final chosen = pairMode == CanonicalMode.advanced
          ? selection.advancedValue
          : selection.basicValue;
      final basicId = group.basicId;
      final chosenPresent =
          chosen != null ||
          (pairMode == CanonicalMode.basic &&
              basicId != null &&
              params.containsKey(basicId) &&
              params[basicId] == null);

      group.memberIds.forEach(params.remove);

      if (chosen != null) {
        params[group.canonicalId] = chosen;
      } else if (chosenPresent) {
        params[group.canonicalId] = null;
      }
    }

    return params;
  }

  /// Port of `classifyCanonicalKind`.
  InactiveModeValueKind _classifyCanonicalKind(
    BlockConfig blockConfig,
    List<String> memberIds,
  ) {
    for (final id in memberIds) {
      final type = blockConfig.subBlocks
          .where((subBlock) => subBlock.id == id)
          .firstOrNull
          ?.type;
      if (type == 'oauth-input') return InactiveModeValueKind.credential;
      if (type != null && type.endsWith('-selector')) {
        return InactiveModeValueKind.resource;
      }
    }
    return InactiveModeValueKind.other;
  }

  /// Port of `collectBlockFieldIssues`: non-throwing analysis of a block's
  /// required fields and canonical-mode value placement.
  BlockFieldIssues collectBlockFieldIssues(
    BlockState block,
    BlockConfig blockConfig,
    Map<String, Object?> params, {
    BlockFieldIssueMode mode = BlockFieldIssueMode.execution,
  }) {
    if (!block.enabled) return BlockFieldIssues.none;
    if ((block.triggerMode ?? false) ||
        blockConfig.category == BlockCategory.triggers ||
        params['triggerMode'] == true) {
      return BlockFieldIssues.none;
    }

    final missingFields = <String>[];
    final displayAdvancedOptions = block.advancedMode ?? false;
    final isTriggerContext = block.triggerMode ?? false;
    final isTriggerCategory = blockConfig.category == BlockCategory.triggers;
    final canonicalIndex = buildCanonicalIndex(blockConfig.subBlocks);
    final canonicalModeOverrides = block.data?.canonicalModes;
    final allValues = buildSubBlockValues(block.subBlocks);

    bool shouldSerialize(SubBlockConfig config) => _shouldSerializeSubBlock(
      config,
      allValues,
      displayAdvancedOptions: displayAdvancedOptions,
      isTriggerContext: isTriggerContext,
      isTriggerCategory: isTriggerCategory,
      canonicalIndex: canonicalIndex,
      canonicalModeOverrides: canonicalModeOverrides,
    );

    bool isMissing(Object? value) =>
        value == null || (value is String && value.isEmpty);

    final toolAccess = blockConfig.tools.access;
    final currentToolId = toolAccess.isNotEmpty
        ? selectToolId(blockConfig, params)
        : null;
    final currentToolParams = currentToolId == null
        ? null
        : toolMetadata.getToolParams(currentToolId);

    final checkedByToolPass = <String>{};
    if (currentToolParams != null) {
      for (final entry in currentToolParams.entries) {
        final paramId = entry.key;
        final paramConfig = entry.value;
        if (!(paramConfig.required ?? false) ||
            paramConfig.visibility != 'user-only') {
          continue;
        }
        checkedByToolPass.add(paramId);
        final matchingConfigs = blockConfig.subBlocks
            .where(
              (sb) => sb.id == paramId || sb.canonicalParamId == paramId,
            )
            .toList();

        var shouldValidateParam = true;
        if (matchingConfigs.isNotEmpty) {
          shouldValidateParam = matchingConfigs.any(
            (config) =>
                shouldSerialize(config) &&
                isSubBlockRequired(config.required, params),
          );
        }
        if (!shouldValidateParam) continue;

        if (isMissing(params[paramId])) {
          final activeConfig = matchingConfigs
              .where(shouldSerialize)
              .firstOrNull;
          missingFields.add(activeConfig?.title ?? paramId);
        }
      }
    }

    final validatedByTool = mode == BlockFieldIssueMode.lint
        ? checkedByToolPass
        : <String>{...?currentToolParams?.keys};

    for (final subBlockConfig in blockConfig.subBlocks) {
      if (validatedByTool.contains(subBlockConfig.id)) continue;
      final canonicalParamId = subBlockConfig.canonicalParamId;
      if (canonicalParamId != null &&
          validatedByTool.contains(canonicalParamId)) {
        continue;
      }
      if (!shouldSerialize(subBlockConfig)) continue;
      if (!isSubBlockRequired(subBlockConfig.required, params)) continue;

      final canonicalId =
          canonicalIndex.canonicalIdBySubBlockId[subBlockConfig.id];
      final fieldValue = canonicalId != null
          ? params[canonicalId]
          : params[subBlockConfig.id];
      if (isMissing(fieldValue)) {
        missingFields.add(subBlockConfig.title ?? subBlockConfig.id);
      }
    }

    final inactiveModeValues = <InactiveModeValue>[];
    for (final group in canonicalIndex.groupsById.values) {
      if (!isCanonicalPair(group)) continue;
      final groupMode = resolveCanonicalMode(
        group,
        allValues,
        canonicalModeOverrides,
      );
      final selection = getCanonicalValues(group, allValues);
      final activeValue = groupMode == CanonicalMode.advanced
          ? selection.advancedValue
          : selection.basicValue;
      if (isNonEmptyValue(activeValue)) continue;

      final memberIds = group.memberIds;
      final activeMemberId = groupMode == CanonicalMode.advanced
          ? group.advancedIds.first
          : group.basicId;
      final inactiveMemberId = memberIds
          .where((id) => id != activeMemberId && isNonEmptyValue(allValues[id]))
          .firstOrNull;
      if (inactiveMemberId != null) {
        inactiveModeValues.add(
          InactiveModeValue(
            canonicalId: group.canonicalId,
            activeMemberId: activeMemberId,
            inactiveMemberId: inactiveMemberId,
            kind: _classifyCanonicalKind(blockConfig, memberIds),
          ),
        );
      }
    }

    return BlockFieldIssues(
      missingRequiredFields: missingFields,
      inactiveModeValues: inactiveModeValues,
    );
  }
}

/// Port of `expandSubBlockValueToParams` from `apps/sim/tools/param-shape.ts`:
/// a `checkbox-list` projects onto one boolean param per option. An option
/// the user never touched is omitted, not sent as `false`; a declared
/// `defaultChecked` is a real choice and is sent. Null for other types.
Map<String, bool>? expandSubBlockValueToParams(
  SubBlockConfig subBlock,
  Object? value,
) {
  if (subBlock.type != 'checkbox-list') return null;
  final options = subBlock.staticOptions ?? const [];
  final selections = value is Map ? value : const <Object?, Object?>{};
  final params = <String, bool>{};
  for (final option in options) {
    if (option.id.isEmpty) continue;
    final selected = selections[option.id];
    final fallback = option.defaultChecked;
    if (selected is bool) {
      params[option.id] = selected;
    } else if (fallback != null) {
      params[option.id] = fallback;
    }
  }
  return params;
}

/// Port of `collectSubBlockValueFromParams`: the inverse of
/// [expandSubBlockValueToParams] for deserialization.
Map<String, Object?>? _collectSubBlockValueFromParams(
  SubBlockConfig subBlock,
  Map<String, Object?> params,
) {
  if (expandSubBlockValueToParams(subBlock, const {}) == null) return null;
  final value = <String, Object?>{
    for (final option in subBlock.staticOptions ?? const <SubBlockOption>[])
      if (option.id.isNotEmpty && params.containsKey(option.id))
        option.id: params[option.id],
  };
  return value.isEmpty ? null : value;
}

/// JavaScript truthiness for the `if (params.x)` guards upstream.
bool _isTruthy(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0 && !value.isNaN;
  if (value is String) return value.isNotEmpty;
  return true;
}

/// JavaScript `String(value)` for the JSON values the serializer sees.
String _jsString(Object? value) {
  if (value == null) return 'null';
  if (value is String) return value;
  if (value is Map || value is List) return jsonEncode(value);
  return value.toString();
}

final Random _random = Random.secure();

/// A UUID v4 from `Random.secure`, standing in for `generateId()` from
/// `@sim/utils/id`.
String generateUuidV4() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
