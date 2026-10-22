/// Wire shapes of `apps/sim/lib/api/contracts/{custom-blocks,block-visibility,
/// providers}.ts` that the workspace loaders read
/// (`generated/contracts/{custom-blocks,block-visibility,providers}.schema.json`).
library;

import 'package:sim_api/src/contracts/json.dart';

/// One `inputFields[]` entry of a custom block.
class CustomBlockInputField extends ContractValue {
  const CustomBlockInputField({
    required this.name,
    required this.type,
    this.id,
    this.description,
    this.placeholder,
    this.required,
  });

  factory CustomBlockInputField.fromJson(JsonObject json) =>
      CustomBlockInputField(
        id: json.stringOrNull('id'),
        name: json.string('name'),
        type: json.string('type'),
        description: json.stringOrNull('description'),
        placeholder: json.stringOrNull('placeholder'),
        required: json.boolOrNull('required'),
      );

  final String? id;
  final String name;
  final String type;
  final String? description;
  final String? placeholder;
  final bool? required;

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    description,
    placeholder,
    required,
  ];

  @override
  JsonObject toJson() => {
    'id': ?id,
    'name': name,
    'type': type,
    'description': ?description,
    'placeholder': ?placeholder,
    'required': ?required,
  };
}

/// `exposedOutputSchema` (`lib/workflows/custom-blocks/settings-input.ts`).
class ExposedOutput extends ContractValue {
  const ExposedOutput({
    required this.blockId,
    required this.path,
    required this.name,
  });

  factory ExposedOutput.fromJson(JsonObject json) => ExposedOutput(
    blockId: json.string('blockId'),
    path: json.string('path'),
    name: json.string('name'),
  );

  final String blockId;
  final String path;
  final String name;

  @override
  List<Object?> get props => [blockId, path, name];

  @override
  JsonObject toJson() => {'blockId': blockId, 'path': path, 'name': name};
}

/// `customBlockSchema` (`custom-blocks.ts:36-57`).
class CustomBlock extends ContractValue {
  const CustomBlock({
    required this.id,
    required this.organizationId,
    required this.workflowId,
    required this.workflowName,
    required this.workspaceId,
    required this.workspaceName,
    required this.type,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.enabled,
    required this.traceChildRuns,
    required this.inputFields,
    required this.exposedOutputs,
  });

  factory CustomBlock.fromJson(JsonObject json) => CustomBlock(
    id: json.string('id'),
    organizationId: json.string('organizationId'),
    workflowId: json.string('workflowId'),
    workflowName: json.string('workflowName'),
    workspaceId: json.stringOrNull('workspaceId'),
    workspaceName: json.stringOrNull('workspaceName'),
    type: json.string('type'),
    name: json.string('name'),
    description: json.string('description'),
    iconUrl: json.stringOrNull('iconUrl'),
    enabled: json.boolean('enabled'),
    traceChildRuns: json.boolean('traceChildRuns'),
    inputFields: json
        .objectList('inputFields')
        .map(CustomBlockInputField.fromJson)
        .toList(),
    exposedOutputs: json
        .objectList('exposedOutputs')
        .map(ExposedOutput.fromJson)
        .toList(),
  );

  final String id;
  final String organizationId;
  final String workflowId;
  final String workflowName;
  final String? workspaceId;
  final String? workspaceName;
  final String type;
  final String name;
  final String description;
  final String? iconUrl;
  final bool enabled;
  final bool traceChildRuns;
  final List<CustomBlockInputField> inputFields;
  final List<ExposedOutput> exposedOutputs;

  @override
  List<Object?> get props => [
    id,
    organizationId,
    workflowId,
    workflowName,
    workspaceId,
    workspaceName,
    type,
    name,
    description,
    iconUrl,
    enabled,
    traceChildRuns,
    inputFields,
    exposedOutputs,
  ];

  @override
  JsonObject toJson() => {
    'id': id,
    'organizationId': organizationId,
    'workflowId': workflowId,
    'workflowName': workflowName,
    'workspaceId': workspaceId,
    'workspaceName': workspaceName,
    'type': type,
    'name': name,
    'description': description,
    'iconUrl': iconUrl,
    'enabled': enabled,
    'traceChildRuns': traceChildRuns,
    'inputFields': inputFields.map((f) => f.toJson()).toList(),
    'exposedOutputs': exposedOutputs.map((o) => o.toJson()).toList(),
  };
}

/// `GET /api/custom-blocks?workspaceId` → `{enabled, customBlocks}`.
class CustomBlocksResponse extends ContractValue {
  const CustomBlocksResponse({
    required this.enabled,
    required this.customBlocks,
  });

  factory CustomBlocksResponse.fromJson(JsonObject json) =>
      CustomBlocksResponse(
        enabled: json.boolean('enabled'),
        customBlocks: json
            .objectList('customBlocks')
            .map(CustomBlock.fromJson)
            .toList(),
      );

  final bool enabled;
  final List<CustomBlock> customBlocks;

  @override
  List<Object?> get props => [enabled, customBlocks];

  @override
  JsonObject toJson() => {
    'enabled': enabled,
    'customBlocks': customBlocks.map((b) => b.toJson()).toList(),
  };
}

/// `GET /api/blocks/visibility?workspaceId` → `{revealed, disabled,
/// previewTagged}` (`block-visibility.ts`).
class BlockVisibility extends ContractValue {
  const BlockVisibility({
    this.revealed = const {},
    this.disabled = const {},
    this.previewTagged = const {},
  });

  factory BlockVisibility.fromJson(JsonObject json) => BlockVisibility(
    revealed: json.stringList('revealed').toSet(),
    disabled: json.stringList('disabled').toSet(),
    previewTagged: json.stringList('previewTagged').toSet(),
  );

  final Set<String> revealed;
  final Set<String> disabled;
  final Set<String> previewTagged;

  @override
  List<Object?> get props => [revealed, disabled, previewTagged];

  @override
  JsonObject toJson() => {
    'revealed': revealed.toList(),
    'disabled': disabled.toList(),
    'previewTagged': previewTagged.toList(),
  };
}

/// The nine providers `ProviderModelsLoader` queries
/// (`provider-models-loader.tsx:447-538`). [takesWorkspace] marks the four
/// routes that accept `?workspaceId`.
enum ProviderName implements WireNamed {
  base('base', takesWorkspace: false),
  ollama('ollama', takesWorkspace: false),
  ollamaCloud('ollama-cloud', takesWorkspace: true),
  vllm('vllm', takesWorkspace: false),
  litellm('litellm', takesWorkspace: false),
  openrouter('openrouter', takesWorkspace: false),
  fireworks('fireworks', takesWorkspace: true),
  together('together', takesWorkspace: true),
  baseten('baseten', takesWorkspace: true)
  ;

  const ProviderName(this.wireName, {required this.takesWorkspace});

  @override
  final String wireName;
  final bool takesWorkspace;

  /// `GET /api/providers/<name>/models`.
  String get path => '/api/providers/$wireName/models';
}

/// `pricing` of a model info entry.
class ModelPricing extends ContractValue {
  const ModelPricing({required this.input, required this.output});

  factory ModelPricing.fromJson(JsonObject json) =>
      ModelPricing(input: json.number('input'), output: json.number('output'));

  final num input;
  final num output;

  @override
  List<Object?> get props => [input, output];

  @override
  JsonObject toJson() => {'input': input, 'output': output};
}

/// One `modelInfo` entry of a provider models response.
class ProviderModelInfo extends ContractValue {
  const ProviderModelInfo({
    required this.id,
    this.contextLength,
    this.supportsStructuredOutputs,
    this.supportsTools,
    this.pricing,
  });

  factory ProviderModelInfo.fromJson(JsonObject json) => ProviderModelInfo(
    id: json.string('id'),
    contextLength: json.numOrNull('contextLength'),
    supportsStructuredOutputs: json.boolOrNull('supportsStructuredOutputs'),
    supportsTools: json.boolOrNull('supportsTools'),
    pricing: switch (json.objectOrNull('pricing')) {
      final pricing? => ModelPricing.fromJson(pricing),
      null => null,
    },
  );

  final String id;
  final num? contextLength;
  final bool? supportsStructuredOutputs;
  final bool? supportsTools;
  final ModelPricing? pricing;

  @override
  List<Object?> get props => [
    id,
    contextLength,
    supportsStructuredOutputs,
    supportsTools,
    pricing,
  ];

  @override
  JsonObject toJson() => {
    'id': id,
    'contextLength': ?contextLength,
    'supportsStructuredOutputs': ?supportsStructuredOutputs,
    'supportsTools': ?supportsTools,
    'pricing': ?pricing?.toJson(),
  };
}

/// `GET /api/providers/<name>/models` → `{models, modelInfo?}`
/// (`providers.ts`). OpenRouter lists are de-duplicated client-side
/// (`providers.ts:50`), which [ProviderModels.deduplicated] does.
class ProviderModels extends ContractValue {
  const ProviderModels({required this.models, this.modelInfo = const {}});

  factory ProviderModels.fromJson(JsonObject json) => ProviderModels(
    models: json.stringList('models'),
    modelInfo: switch (json.objectOrNull('modelInfo')) {
      final info? => {
        for (final entry in info.entries)
          entry.key: ProviderModelInfo.fromJson(
            asJsonObject(entry.value, path: 'modelInfo.${entry.key}'),
          ),
      },
      null => const {},
    },
  );

  final List<String> models;
  final Map<String, ProviderModelInfo> modelInfo;

  ProviderModels deduplicated() {
    final seen = <String>{};
    return ProviderModels(
      models: [
        for (final model in models)
          if (seen.add(model)) model,
      ],
      modelInfo: modelInfo,
    );
  }

  @override
  List<Object?> get props => [models, modelInfo];

  @override
  JsonObject toJson() => {
    'models': models,
    if (modelInfo.isNotEmpty)
      'modelInfo': modelInfo.map((k, v) => MapEntry(k, v.toJson())),
  };
}
