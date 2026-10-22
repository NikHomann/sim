/// Plain-data mirrors of `BlockConfig` and `SubBlockConfig` from
/// `apps/sim/blocks/types.ts` (upstream 27b53561).
///
/// Function-valued upstream fields are represented as strategy objects so a
/// generated registry can fill the static parts and hand-ported closures the
/// rest:
/// - `tools.config.tool(params)` → [ToolSelector] (decision table or callback)
/// - `tools.config.params(params)` → execution-side; only its name is kept
/// - `options` function → [DynamicOptions]
/// - `condition` / `required` functions → [DynamicCondition]
/// - `value(params)` → [ValueProvider]
/// - `icon` React component → an asset id string
library;

import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/condition.dart';
import 'package:sim_workflow/src/model/json.dart';
import 'package:sim_workflow/src/model/output_field.dart';
import 'package:sim_workflow/src/model/sub_block_type.dart';

/// Port of `BlockCategory`.
enum BlockCategory {
  blocks('blocks'),
  tools('tools'),
  triggers('triggers')
  ;

  const BlockCategory(this.id);

  final String id;

  static BlockCategory? fromId(String? id) {
    for (final category in values) {
      if (category.id == id) return category;
    }
    return null;
  }
}

/// Port of `SubBlockConfig['mode']`. Absent means `'both'`.
enum SubBlockMode {
  basic('basic'),
  advanced('advanced'),
  both('both'),
  trigger('trigger'),
  triggerAdvanced('trigger-advanced')
  ;

  const SubBlockMode(this.id);

  final String id;

  static SubBlockMode? fromId(String? id) {
    for (final mode in values) {
      if (mode.id == id) return mode;
    }
    return null;
  }
}

/// Port of `AuthMode`.
enum AuthMode {
  oauth('oauth'),
  apiKey('api_key'),
  botToken('bot_token')
  ;

  const AuthMode(this.id);

  final String id;
}

/// Port of `SubBlockConfig['paramVisibility']`.
enum ParamVisibility {
  userOrLlm('user-or-llm'),
  userOnly('user-only'),
  llmOnly('llm-only'),
  hidden('hidden')
  ;

  const ParamVisibility(this.id);

  final String id;

  static ParamVisibility? fromId(String? id) {
    for (final visibility in values) {
      if (visibility.id == id) return visibility;
    }
    return null;
  }
}

/// One entry of `SubBlockConfig.options`.
@immutable
class SubBlockOption {
  const SubBlockOption({
    required this.id,
    required this.label,
    this.iconId,
    this.group,
    this.hidden,
    this.reactiveCondition,
    this.defaultChecked,
    this.description,
  });

  final String id;
  final String label;
  final String? iconId;
  final String? group;
  final bool? hidden;
  final ReactiveCondition? reactiveCondition;
  final bool? defaultChecked;
  final String? description;

  @override
  bool operator ==(Object other) =>
      other is SubBlockOption &&
      other.id == id &&
      other.label == label &&
      other.iconId == iconId &&
      other.group == group &&
      other.hidden == hidden &&
      other.reactiveCondition == reactiveCondition &&
      other.defaultChecked == defaultChecked &&
      other.description == description;

  @override
  int get hashCode => Object.hash(
    id,
    label,
    iconId,
    group,
    hidden,
    reactiveCondition,
    defaultChecked,
    description,
  );
}

/// Port of `SubBlockConfig.options`: static list or derived from values.
@immutable
sealed class OptionsSpec {
  const OptionsSpec();

  List<SubBlockOption> resolve(Map<String, Object?> values);
}

class StaticOptions extends OptionsSpec {
  StaticOptions(List<SubBlockOption> options)
    : options = List<SubBlockOption>.unmodifiable(options);

  final List<SubBlockOption> options;

  @override
  List<SubBlockOption> resolve(Map<String, Object?> values) => options;
}

class DynamicOptions extends OptionsSpec {
  const DynamicOptions(this.builder, {this.name});

  final List<SubBlockOption> Function(Map<String, Object?> values) builder;
  final String? name;

  @override
  List<SubBlockOption> resolve(Map<String, Object?> values) => builder(values);
}

/// Port of `SubBlockConfig.reactiveCondition`.
@immutable
class ReactiveCondition {
  ReactiveCondition({
    required List<String> watchFields,
    required this.requiredType,
  }) : watchFields = List<String>.unmodifiable(watchFields);

  final List<String> watchFields;

  /// `'oauth' | 'service_account'`.
  final String requiredType;

  @override
  bool operator ==(Object other) =>
      other is ReactiveCondition &&
      deepEquality.equals(other.watchFields, watchFields) &&
      other.requiredType == requiredType;

  @override
  int get hashCode => Object.hash(deepEquality.hash(watchFields), requiredType);
}

/// Port of `SubBlockConfig.wandConfig`.
@immutable
class WandConfig {
  const WandConfig({
    required this.enabled,
    required this.prompt,
    this.generationType,
    this.placeholder,
    this.maintainHistory,
  });

  final bool enabled;
  final String prompt;
  final String? generationType;
  final String? placeholder;
  final bool? maintainHistory;
}

/// Port of `SubBlockConfig.dependsOn`: `string[] | { all?, any? }`.
///
/// The bare-array form means "all of these" (`parseDependsOn`).
@immutable
class DependsOn {
  DependsOn({List<String> all = const [], List<String> any = const []})
    : all = List<String>.unmodifiable(all),
      any = List<String>.unmodifiable(any);

  /// The `['credential']` array form.
  factory DependsOn.fields(List<String> fields) => DependsOn(all: fields);

  final List<String> all;
  final List<String> any;

  /// Port of `getDependsOnFields` / `parseDependsOn().allDependsOnFields`.
  List<String> get allFields => [...all, ...any];

  @override
  bool operator ==(Object other) =>
      other is DependsOn &&
      deepEquality.equals(other.all, all) &&
      deepEquality.equals(other.any, any);

  @override
  int get hashCode =>
      Object.hash(deepEquality.hash(all), deepEquality.hash(any));
}

/// Port of `SubBlockConfig.folderScope`.
@immutable
class FolderScope {
  const FolderScope({required this.fieldId, this.recursiveFieldId});

  final String fieldId;
  final String? recursiveFieldId;
}

/// Port of `SubBlockConfig.credentialLabels`.
@immutable
class CredentialLabels {
  const CredentialLabels({
    this.oauthGroup,
    this.oauthConnect,
    this.serviceAccountGroup,
    this.serviceAccountConnect,
  });

  final String? oauthGroup;
  final String? oauthConnect;
  final String? serviceAccountGroup;
  final String? serviceAccountConnect;
}

/// Port of `SubBlockConfig.providerWebhookUrl`.
@immutable
class ProviderWebhookUrl {
  const ProviderWebhookUrl({
    required this.providerPath,
    required this.routingKeySubBlockId,
  });

  final String providerPath;
  final String routingKeySubBlockId;
}

/// Port of `SubBlockConfig.value`: `(params) => string`.
typedef ValueProvider = String Function(Map<String, Object?> params);

/// Port of `SubBlockConfig` from `apps/sim/blocks/types.ts`.
///
/// [type] is the raw sub-block type id (see [SubBlockType.fromId]); trigger
/// definitions spread a `trigger-config` entry that is not one of the 48.
@immutable
class SubBlockConfig {
  SubBlockConfig({
    required this.id,
    required this.type,
    this.title,
    this.canvasNoun,
    this.mode,
    this.canonicalParamId,
    this.searchTextFormat,
    this.resourceType,
    this.folderScope,
    this.paramVisibility,
    this.emptyIsValid,
    this.clearOnMissingOption,
    this.createAction,
    this.context,
    this.required = SubBlockRequired.never,
    Object? defaultValue,
    this.options,
    this.min,
    this.max,
    List<String>? columns,
    this.placeholder,
    this.password,
    this.readOnly,
    this.showCopyButton,
    this.connectionDroppable,
    this.hidden,
    this.hideFromPreview,
    this.hideFromCopilot,
    this.hideDividerBefore,
    this.showWhenEnvSet,
    this.hideWhenHosted,
    this.hideWhenEnvSet,
    this.description,
    this.tooltip,
    this.modalId,
    this.valueProvider,
    this.grouped,
    this.scrollable,
    this.maxHeight,
    this.selectAllOption,
    this.condition,
    this.reactiveCondition,
    this.language,
    this.generationType,
    this.collapsible,
    this.defaultCollapsed,
    this.serviceId,
    List<String>? requiredScopes,
    this.credentialKind,
    this.credentialLabels,
    this.allowServiceAccounts,
    this.selectorKey,
    this.selectorExcludeSelf,
    this.selectorAllowSearch,
    this.mimeType,
    this.acceptedTypes,
    this.multiple,
    this.maxSize,
    this.requiresCloudStorage,
    this.step,
    this.integer,
    this.rows,
    this.multiSelect,
    this.preserveLabelCase,
    this.searchable,
    this.commandSearchable,
    this.wandConfig,
    this.dependsOn,
    this.useWebhookUrl,
    this.providerWebhookUrl,
    List<String>? unsupportedToolTypes,
  }) : defaultValue = freezeJson(defaultValue),
       columns = columns == null ? null : List<String>.unmodifiable(columns),
       requiredScopes = requiredScopes == null
           ? null
           : List<String>.unmodifiable(requiredScopes),
       unsupportedToolTypes = unsupportedToolTypes == null
           ? null
           : List<String>.unmodifiable(unsupportedToolTypes);

  final String id;
  final String type;
  final String? title;
  final String? canvasNoun;
  final SubBlockMode? mode;
  final String? canonicalParamId;
  final String? searchTextFormat;
  final String? resourceType;
  final FolderScope? folderScope;
  final ParamVisibility? paramVisibility;
  final bool? emptyIsValid;
  final bool? clearOnMissingOption;
  final String? createAction;

  /// `'tool-input'` when the field only applies inside an agent tool entry.
  final String? context;
  final SubBlockRequired required;
  final Object? defaultValue;
  final OptionsSpec? options;
  final double? min;
  final double? max;
  final List<String>? columns;
  final String? placeholder;
  final bool? password;
  final bool? readOnly;
  final bool? showCopyButton;
  final bool? connectionDroppable;
  final bool? hidden;
  final bool? hideFromPreview;
  final bool? hideFromCopilot;
  final bool? hideDividerBefore;
  final String? showWhenEnvSet;
  final bool? hideWhenHosted;
  final String? hideWhenEnvSet;
  final String? description;
  final String? tooltip;
  final String? modalId;
  final ValueProvider? valueProvider;
  final bool? grouped;
  final bool? scrollable;
  final double? maxHeight;
  final bool? selectAllOption;
  final ConditionSpec? condition;
  final ReactiveCondition? reactiveCondition;
  final String? language;
  final String? generationType;
  final bool? collapsible;
  final bool? defaultCollapsed;
  final String? serviceId;
  final List<String>? requiredScopes;
  final String? credentialKind;
  final CredentialLabels? credentialLabels;
  final bool? allowServiceAccounts;
  final String? selectorKey;
  final bool? selectorExcludeSelf;
  final bool? selectorAllowSearch;
  final String? mimeType;
  final String? acceptedTypes;
  final bool? multiple;
  final double? maxSize;
  final bool? requiresCloudStorage;
  final double? step;
  final bool? integer;
  final int? rows;
  final bool? multiSelect;
  final bool? preserveLabelCase;
  final bool? searchable;
  final bool? commandSearchable;
  final WandConfig? wandConfig;
  final DependsOn? dependsOn;
  final bool? useWebhookUrl;
  final ProviderWebhookUrl? providerWebhookUrl;
  final List<String>? unsupportedToolTypes;

  SubBlockType? get subBlockType => SubBlockType.fromId(type);

  /// Static options when declared as a list; null for dynamic or absent.
  List<SubBlockOption>? get staticOptions => switch (options) {
    StaticOptions(:final options) => options,
    _ => null,
  };
}

/// Port of `ParamConfig` (the `inputs` entries of a block).
@immutable
class ParamConfig {
  ParamConfig({
    required this.type,
    this.description,
    Map<String, Object?>? schema,
  }) : schema = schema == null ? null : freezeMap(schema);

  /// `'string' | 'number' | 'boolean' | 'json' | 'array' | 'file'`.
  final String type;
  final String? description;
  final Map<String, Object?>? schema;
}

/// Port of `tools.config.tool(params)`: picks the tool id to run for the
/// current params. Throwing is allowed and mirrors the upstream closures that
/// `throw new Error('Invalid operation')` in their `default` branch; the
/// serializer catches it and falls back to `tools.access[0]`.
// ignore: one_member_abstracts, strategy contract implemented by generated tables
abstract interface class ToolSelector {
  String select(Map<String, Object?> params);
}

/// A pure switch on one param (the common upstream shape, emitted by the
/// extraction as a decision table).
@immutable
class DecisionTableToolSelector implements ToolSelector {
  DecisionTableToolSelector({
    required this.paramKey,
    required Map<String, String> cases,
    this.fallback,
  }) : cases = Map<String, String>.unmodifiable(cases);

  final String paramKey;
  final Map<String, String> cases;

  /// The `default` branch; null means the upstream switch throws.
  final String? fallback;

  @override
  String select(Map<String, Object?> params) {
    final value = params[paramKey];
    final key = value == null ? null : _stringKey(value);
    final hit = key == null ? null : cases[key];
    if (hit != null) return hit;
    final fallback = this.fallback;
    if (fallback != null) return fallback;
    throw StateError('Invalid $paramKey: $value');
  }

  static String _stringKey(Object value) =>
      value is num ? jsonNumber(value.toDouble()).toString() : value.toString();
}

/// A hand-ported `tools.config.tool` closure.
class CallbackToolSelector implements ToolSelector {
  const CallbackToolSelector(this.callback, {this.name});

  final String Function(Map<String, Object?> params) callback;
  final String? name;

  @override
  String select(Map<String, Object?> params) => callback(params);
}

/// Port of `BlockConfig.tools`.
@immutable
class ToolsConfig {
  ToolsConfig({
    required List<String> access,
    this.toolSelector,
    this.paramsTransformName,
  }) : access = List<String>.unmodifiable(access);

  final List<String> access;

  /// `tools.config.tool`; null means "always `access[0]`".
  final ToolSelector? toolSelector;

  /// Upstream identifier of `tools.config.params`, which runs at execution
  /// time on the server and is not ported.
  final String? paramsTransformName;
}

/// Port of `BlockConfig.triggers`.
@immutable
class TriggersConfig {
  TriggersConfig({required this.enabled, required List<String> available})
    : available = List<String>.unmodifiable(available);

  final bool enabled;
  final List<String> available;
}

/// Port of `BlockConfig.sunset`.
@immutable
class SunsetConfig {
  const SunsetConfig({required this.status, this.replacedBy});

  /// `'legacy' | 'deprecated'`.
  final String status;
  final String? replacedBy;
}

/// Port of `CanvasSentenceClause`.
@immutable
sealed class CanvasSentenceClause {
  const CanvasSentenceClause();
}

class LiteralClause extends CanvasSentenceClause {
  const LiteralClause(this.text);

  final String text;
}

class FieldClause extends CanvasSentenceClause {
  FieldClause({
    required List<String> fields,
    this.text,
    this.after,
    this.core = false,
  }) : fields = List<String>.unmodifiable(fields);

  final String? text;
  final List<String> fields;
  final String? after;
  final bool core;
}

/// Port of `BlockConfig.canvasPresentation.sentences` and `triggerSentences`.
@immutable
class CanvasSentences {
  CanvasSentences({
    List<CanvasSentenceClause>? defaultSentence,
    Map<String, List<CanvasSentenceClause>>? byKey,
  }) : defaultSentence = defaultSentence == null
           ? null
           : List<CanvasSentenceClause>.unmodifiable(defaultSentence),
       byKey = byKey == null
           ? null
           : Map<String, List<CanvasSentenceClause>>.unmodifiable(byKey);

  final List<CanvasSentenceClause>? defaultSentence;

  /// `byOperation` for action sentences, `byTrigger` for trigger sentences.
  final Map<String, List<CanvasSentenceClause>>? byKey;
}

/// Port of `BlockConfig.canvasPresentation`.
@immutable
class CanvasPresentation {
  const CanvasPresentation({
    required this.defaultTitle,
    this.typeLabel,
    this.operationSubBlockId,
    this.operationRowTitle,
    this.sentences,
    this.triggerSentences,
  });

  final String defaultTitle;
  final String? typeLabel;
  final String? operationSubBlockId;
  final String? operationRowTitle;
  final CanvasSentences? sentences;
  final CanvasSentences? triggerSentences;
}

/// Port of `BlockConfig` from `apps/sim/blocks/types.ts`.
@immutable
class BlockConfig {
  BlockConfig({
    required this.type,
    required this.name,
    required this.description,
    required this.category,
    required this.bgColor,
    required List<SubBlockConfig> subBlocks,
    required this.tools,
    Map<String, ParamConfig> inputs = const {},
    Map<String, OutputFieldDefinition> outputs = const {},
    this.iconId,
    this.integrationType,
    this.longDescription,
    this.bestPractices,
    this.docsLink,
    this.iconColor,
    this.canvasPresentation,
    this.triggerAllowed,
    this.authMode,
    this.singleInstance,
    this.hideFromToolbar,
    this.sourceWorkflowId,
    this.sourceWorkspaceName,
    this.preview,
    this.sunset,
    this.triggers,
  }) : subBlocks = List<SubBlockConfig>.unmodifiable(subBlocks),
       inputs = Map<String, ParamConfig>.unmodifiable(inputs),
       outputs = Map<String, OutputFieldDefinition>.unmodifiable(outputs);

  final String type;
  final String name;
  final String description;
  final BlockCategory category;
  final String? integrationType;
  final String? longDescription;
  final String? bestPractices;
  final String? docsLink;
  final String bgColor;
  final String? iconColor;

  /// Asset id of the extracted icon (`generated/icons/...`).
  final String? iconId;
  final CanvasPresentation? canvasPresentation;
  final List<SubBlockConfig> subBlocks;
  final bool? triggerAllowed;
  final AuthMode? authMode;
  final bool? singleInstance;
  final ToolsConfig tools;
  final Map<String, ParamConfig> inputs;
  final Map<String, OutputFieldDefinition> outputs;
  final bool? hideFromToolbar;
  final String? sourceWorkflowId;
  final String? sourceWorkspaceName;
  final bool? preview;
  final SunsetConfig? sunset;
  final TriggersConfig? triggers;
}

/// Port of `SELECTOR_TYPES_HYDRATION_REQUIRED` from `apps/sim/blocks/types.ts`.
const List<SubBlockType> selectorTypesHydrationRequired = [
  SubBlockType.oauthInput,
  SubBlockType.channelSelector,
  SubBlockType.userSelector,
  SubBlockType.fileSelector,
  SubBlockType.sheetSelector,
  SubBlockType.folderSelector,
  SubBlockType.projectSelector,
  SubBlockType.knowledgeBaseSelector,
  SubBlockType.workflowSelector,
  SubBlockType.documentSelector,
  SubBlockType.variablesInput,
  SubBlockType.mcpServerSelector,
  SubBlockType.mcpToolSelector,
  SubBlockType.tableSelector,
];
