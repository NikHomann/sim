/// Ports of the canonical basic/advanced pair machinery and sub-block
/// visibility rules in `apps/sim/lib/workflows/subblocks/visibility.ts`
/// (upstream 27b53561).
library;

import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/block_config.dart';
import 'package:sim_workflow/src/model/block_data.dart';
import 'package:sim_workflow/src/model/json.dart';
import 'package:sim_workflow/src/model/sub_block_state.dart';
import 'package:sim_workflow/src/rules/environment.dart';

/// Port of `CanonicalModeOverrides`: `block.data.canonicalModes`.
typedef CanonicalModeOverrides = Map<String, CanonicalMode>;

/// Port of `CanonicalGroup`.
class CanonicalGroup {
  CanonicalGroup({required this.canonicalId, this.basicId});

  final String canonicalId;
  String? basicId;
  final List<String> advancedIds = [];

  /// `[basicId, ...advancedIds].filter(Boolean)`.
  List<String> get memberIds => [?basicId, ...advancedIds];
}

/// Port of `CanonicalIndex`.
@immutable
class CanonicalIndex {
  const CanonicalIndex({
    required this.groupsById,
    required this.canonicalIdBySubBlockId,
  });

  final Map<String, CanonicalGroup> groupsById;
  final Map<String, String> canonicalIdBySubBlockId;

  CanonicalGroup? groupForSubBlock(String subBlockId) {
    final canonicalId = canonicalIdBySubBlockId[subBlockId];
    return canonicalId == null ? null : groupsById[canonicalId];
  }
}

/// Port of `CanonicalValueSelection`.
@immutable
class CanonicalValueSelection {
  const CanonicalValueSelection({
    required this.basicValue,
    required this.advancedValue,
    this.advancedSourceId,
  });

  final Object? basicValue;
  final Object? advancedValue;
  final String? advancedSourceId;
}

/// Port of `TriggerVisibilityBlockConfig`.
@immutable
class TriggerVisibilityBlockConfig {
  const TriggerVisibilityBlockConfig({this.category, this.triggersEnabled});

  TriggerVisibilityBlockConfig.of(BlockConfig config)
    : category = config.category,
      triggersEnabled = config.triggers?.enabled;

  final BlockCategory? category;
  final bool? triggersEnabled;
}

/// Port of `parseDependsOn`'s result.
@immutable
class ParsedDependsOn {
  const ParsedDependsOn({
    required this.allFields,
    required this.anyFields,
    required this.allDependsOnFields,
  });

  final List<String> allFields;
  final List<String> anyFields;
  final List<String> allDependsOnFields;
}

/// Port of `parseDependsOn`.
ParsedDependsOn parseDependsOn(DependsOn? dependsOn) {
  if (dependsOn == null) {
    return const ParsedDependsOn(
      allFields: [],
      anyFields: [],
      allDependsOnFields: [],
    );
  }
  return ParsedDependsOn(
    allFields: dependsOn.all,
    anyFields: dependsOn.any,
    allDependsOnFields: dependsOn.allFields,
  );
}

/// Port of `normalizeDependencyValue`.
Object? normalizeDependencyValue(Object? rawValue) {
  if (rawValue == null) return null;
  if (rawValue is List) {
    if (rawValue.isEmpty) return null;
    return rawValue.map(normalizeDependencyValue).toList();
  }
  if (rawValue is Map) {
    if (rawValue.containsKey('value')) {
      return normalizeDependencyValue(rawValue['value']);
    }
    if (rawValue.containsKey('id')) return rawValue['id'];
    return rawValue;
  }
  return rawValue;
}

/// Port of `buildSubBlockValues`: a flat `subBlockId -> value` map.
Map<String, Object?> buildSubBlockValues(
  Map<String, SubBlockState> subBlocks,
) => {for (final entry in subBlocks.entries) entry.key: entry.value.value};

/// Port of `buildCanonicalIndex`.
///
/// A trigger-mode sub-block never overwrites a `basicId` already claimed by a
/// non-trigger one (blocks spread their trigger's subBlocks after their own),
/// and repeated advanced ids are deduplicated.
CanonicalIndex buildCanonicalIndex(List<SubBlockConfig> subBlocks) {
  final groupsById = <String, CanonicalGroup>{};
  final canonicalIdBySubBlockId = <String, String>{};

  for (final subBlock in subBlocks) {
    final canonicalId = subBlock.canonicalParamId;
    if (canonicalId == null) continue;
    final group = groupsById.putIfAbsent(
      canonicalId,
      () => CanonicalGroup(canonicalId: canonicalId),
    );
    if (subBlock.mode == SubBlockMode.advanced ||
        subBlock.mode == SubBlockMode.triggerAdvanced) {
      if (!group.advancedIds.contains(subBlock.id)) {
        group.advancedIds.add(subBlock.id);
      }
    } else if (group.basicId == null || subBlock.mode != SubBlockMode.trigger) {
      group.basicId = subBlock.id;
    }
    canonicalIdBySubBlockId[subBlock.id] = canonicalId;
  }

  return CanonicalIndex(
    groupsById: groupsById,
    canonicalIdBySubBlockId: canonicalIdBySubBlockId,
  );
}

/// Port of `getCanonicalSubBlocksForSurface`: on the trigger surface only the
/// trigger members define the groups; the action surface keeps the whole
/// array (and the same list instance).
List<SubBlockConfig> getCanonicalSubBlocksForSurface(
  List<SubBlockConfig> subBlocks, {
  required bool triggerSurface,
}) {
  if (!triggerSurface) return subBlocks;
  return subBlocks
      .where(shouldUseSubBlockForTriggerModeCanonicalIndex)
      .toList();
}

/// Port of `buildCanonicalIndexForSurface`.
CanonicalIndex buildCanonicalIndexForSurface(
  List<SubBlockConfig> subBlocks, {
  required bool triggerSurface,
}) => buildCanonicalIndex(
  getCanonicalSubBlocksForSurface(subBlocks, triggerSurface: triggerSurface),
);

/// Port of `isCanonicalPair`: a basic member plus at least one advanced one.
bool isCanonicalPair(CanonicalGroup? group) =>
    group != null && group.basicId != null && group.advancedIds.isNotEmpty;

/// Port of `buildDefaultCanonicalModes`: every pair defaults to `basic`.
Map<String, CanonicalMode> buildDefaultCanonicalModes(
  List<SubBlockConfig> subBlocks,
) => {
  for (final group in buildCanonicalIndex(subBlocks).groupsById.values)
    if (isCanonicalPair(group)) group.canonicalId: CanonicalMode.basic,
};

/// Port of `isNonEmptyValue`: null, blank strings and empty lists are empty;
/// everything else (including `0`, `false` and `{}`) is set.
bool isNonEmptyValue(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is List) return value.isNotEmpty;
  return true;
}

/// Port of `getCanonicalValues`: the basic value and the first non-empty
/// advanced member's value.
CanonicalValueSelection getCanonicalValues(
  CanonicalGroup group,
  Map<String, Object?> values,
) {
  final basicId = group.basicId;
  final basicValue = basicId == null ? null : values[basicId];
  Object? advancedValue;
  String? advancedSourceId;
  for (final advancedId in group.advancedIds) {
    if (advancedValue != null) break;
    final candidate = values[advancedId];
    if (isNonEmptyValue(candidate)) {
      advancedValue = candidate;
      advancedSourceId = advancedId;
    }
  }
  return CanonicalValueSelection(
    basicValue: basicValue,
    advancedValue: advancedValue,
    advancedSourceId: advancedSourceId,
  );
}

/// Port of `resolveCanonicalMode`: an applicable override wins; otherwise
/// `advanced` only when the basic member is empty and an advanced one is set
/// (or the group has no basic member).
CanonicalMode resolveCanonicalMode(
  CanonicalGroup group,
  Map<String, Object?> values, [
  CanonicalModeOverrides? overrides,
]) {
  final override = overrides?[group.canonicalId];
  if (override == CanonicalMode.advanced && group.advancedIds.isNotEmpty) {
    return CanonicalMode.advanced;
  }
  if (override == CanonicalMode.basic && group.basicId != null) {
    return CanonicalMode.basic;
  }

  final selection = getCanonicalValues(group, values);
  final hasBasic = isNonEmptyValue(selection.basicValue);
  final hasAdvanced = isNonEmptyValue(selection.advancedValue);

  if (group.basicId == null) return CanonicalMode.advanced;
  if (!hasBasic && hasAdvanced) return CanonicalMode.advanced;
  return CanonicalMode.basic;
}

/// Port of `resolveActiveCanonicalValue`: strictly the active member's value,
/// with no cross-mode fallback.
Object? resolveActiveCanonicalValue(
  CanonicalGroup group,
  Map<String, Object?> values, [
  CanonicalModeOverrides? overrides,
]) {
  final mode = resolveCanonicalMode(group, values, overrides);
  final selection = getCanonicalValues(group, values);
  return mode == CanonicalMode.advanced
      ? selection.advancedValue
      : selection.basicValue;
}

CanonicalGroup? _groupForKey(String key, CanonicalIndex index) {
  final canonicalId =
      index.groupsById[key]?.canonicalId ?? index.canonicalIdBySubBlockId[key];
  return canonicalId == null ? null : index.groupsById[canonicalId];
}

/// Port of `resolveActiveDependencyValue`: [resolveActiveCanonicalValue]
/// addressed by canonical id or member id; a plain key reads its own value.
Object? resolveActiveDependencyValue(
  String dependencyKey,
  Map<String, Object?> values,
  CanonicalIndex canonicalIndex, [
  CanonicalModeOverrides? overrides,
]) {
  final group = _groupForKey(dependencyKey, canonicalIndex);
  if (group == null) return values[dependencyKey];
  return resolveActiveCanonicalValue(group, values, overrides);
}

/// Port of `resolveDependencyValue`: deliberately permissive for `dependsOn`
/// gates — falls back across the pair, then to any non-empty member, then to
/// the raw key.
Object? resolveDependencyValue(
  String dependencyKey,
  Map<String, Object?> values,
  CanonicalIndex canonicalIndex, [
  CanonicalModeOverrides? overrides,
]) {
  final group = _groupForKey(dependencyKey, canonicalIndex);
  if (group == null) return values[dependencyKey];

  final selection = getCanonicalValues(group, values);
  final mode = resolveCanonicalMode(group, values, overrides);
  final canonicalResult = mode == CanonicalMode.advanced
      ? (selection.advancedValue ?? selection.basicValue)
      : (selection.basicValue ?? selection.advancedValue);
  if (canonicalResult != null) return canonicalResult;

  for (final entry in canonicalIndex.canonicalIdBySubBlockId.entries) {
    if (entry.value == group.canonicalId &&
        isNonEmptyValue(values[entry.key])) {
      return values[entry.key];
    }
  }

  return values[dependencyKey];
}

CanonicalModeOverrides? _extractPrefixedModes(
  CanonicalModeOverrides overrides,
  String prefix,
) {
  CanonicalModeOverrides? scoped;
  for (final entry in overrides.entries) {
    if (entry.key.startsWith(prefix)) {
      (scoped ??= {})[entry.key.substring(prefix.length)] = entry.value;
    }
  }
  return scoped;
}

/// Port of `scopeCanonicalModesForTool`: strips the `${toolIndex}:` prefix,
/// layering index-scoped entries over the legacy `${toolType}:` baseline per
/// canonical id. Null when nothing matches.
CanonicalModeOverrides? scopeCanonicalModesForTool(
  CanonicalModeOverrides? overrides,
  int? toolIndex, [
  String? legacyToolType,
]) {
  if (overrides == null) return null;
  final scoped = toolIndex == null
      ? null
      : _extractPrefixedModes(overrides, '$toolIndex:');
  final legacy = legacyToolType == null
      ? null
      : _extractPrefixedModes(overrides, '$legacyToolType:');
  if (scoped == null) return legacy;
  return legacy == null ? scoped : {...legacy, ...scoped};
}

final RegExp _indexScopedKey = RegExp(r'^(\d+):(.+)$');

/// Port of `reindexCanonicalModesByPosition`: moves each surviving tool's
/// `${index}:${canonicalId}` overrides to its new position, drops vacated
/// indices, carries legacy keys unchanged, and returns null when nothing
/// needs to change.
Map<String, CanonicalMode>? reindexCanonicalModesByPosition(
  Map<int, int> newIndexByOldIndex,
  CanonicalModeOverrides? overrides,
) {
  if (overrides == null) return null;
  var changed = false;
  final result = <String, CanonicalMode>{};
  for (final entry in overrides.entries) {
    final match = _indexScopedKey.firstMatch(entry.key);
    if (match == null) {
      result[entry.key] = entry.value;
      continue;
    }
    final oldIndex = int.parse(match.group(1)!);
    final newIndex = newIndexByOldIndex[oldIndex];
    if (newIndex == null) {
      changed = true;
      continue;
    }
    if (newIndex != oldIndex) changed = true;
    result['$newIndex:${match.group(2)}'] = entry.value;
  }
  return changed ? result : null;
}

Object? _withoutExpandedState(Object? tool) {
  if (tool is Map) {
    return {
      for (final entry in tool.entries)
        if (entry.key != 'isExpanded') entry.key: entry.value,
    };
  }
  return tool;
}

bool _isSameToolType(Object? oldTool, Object? newTool) =>
    oldTool is Map &&
    newTool is Map &&
    oldTool['type'] is String &&
    oldTool['type'] == newTool['type'];

/// Port of `reindexRewrittenToolCanonicalModes`: for a tool array rewritten
/// from serialized input. Each new tool claims an unclaimed old tool with the
/// same content, then any still unmatched claims one of the same `type`;
/// each pass tries the same position before any other.
Map<String, CanonicalMode>? reindexRewrittenToolCanonicalModes(
  List<Object?> oldTools,
  List<Object?> newTools,
  CanonicalModeOverrides? overrides,
) {
  if (overrides == null) return null;

  final oldContents = oldTools.map(_withoutExpandedState).toList();
  final newContents = newTools.map(_withoutExpandedState).toList();
  final newIndexByOldIndex = <int, int>{};
  final matchedNewIndices = <int>{};

  final matchers = <bool Function(Object?, Object?)>[
    deepEquality.equals,
    _isSameToolType,
  ];
  for (final matches in matchers) {
    bool isUnclaimedMatch(int oldIndex, int newIndex) =>
        oldIndex < oldContents.length &&
        !newIndexByOldIndex.containsKey(oldIndex) &&
        matches(oldContents[oldIndex], newContents[newIndex]);
    int findSamePosition(int newIndex) =>
        isUnclaimedMatch(newIndex, newIndex) ? newIndex : -1;
    int findAnyPosition(int newIndex) {
      for (var oldIndex = 0; oldIndex < oldContents.length; oldIndex++) {
        if (isUnclaimedMatch(oldIndex, newIndex)) return oldIndex;
      }
      return -1;
    }

    for (final findOldIndex in [findSamePosition, findAnyPosition]) {
      for (var newIndex = 0; newIndex < newContents.length; newIndex++) {
        if (matchedNewIndices.contains(newIndex)) continue;
        final oldIndex = findOldIndex(newIndex);
        if (oldIndex == -1) continue;
        newIndexByOldIndex[oldIndex] = newIndex;
        matchedNewIndices.add(newIndex);
      }
    }
  }
  return reindexCanonicalModesByPosition(newIndexByOldIndex, overrides);
}

/// Port of `isStandaloneAdvancedMode`.
bool isStandaloneAdvancedMode(SubBlockMode? mode) =>
    mode == SubBlockMode.advanced || mode == SubBlockMode.triggerAdvanced;

/// Port of `hasAdvancedValues`: any pair's advanced value or any standalone
/// advanced field holds a value.
bool hasAdvancedValues(
  List<SubBlockConfig> subBlocks,
  Map<String, Object?> values,
  CanonicalIndex canonicalIndex,
) {
  final checked = <String>{};
  for (final subBlock in subBlocks) {
    final canonicalId = canonicalIndex.canonicalIdBySubBlockId[subBlock.id];
    if (canonicalId != null) {
      final group = canonicalIndex.groupsById[canonicalId];
      if (isCanonicalPair(group) && checked.add(canonicalId)) {
        if (isNonEmptyValue(getCanonicalValues(group!, values).advancedValue)) {
          return true;
        }
      }
      continue;
    }
    if (isStandaloneAdvancedMode(subBlock.mode) &&
        isNonEmptyValue(values[subBlock.id])) {
      return true;
    }
  }
  return false;
}

/// Port of `isSubBlockVisibleForMode`.
bool isSubBlockVisibleForMode(
  SubBlockConfig subBlock,
  // ignore: avoid_positional_boolean_parameters, mirrors the upstream signature
  bool displayAdvancedOptions,
  CanonicalIndex canonicalIndex,
  Map<String, Object?> values, [
  CanonicalModeOverrides? overrides,
]) {
  final group = canonicalIndex.groupForSubBlock(subBlock.id);
  if (isCanonicalPair(group)) {
    final mode = resolveCanonicalMode(group!, values, overrides);
    if (mode == CanonicalMode.advanced) {
      return group.advancedIds.contains(subBlock.id);
    }
    return group.basicId == subBlock.id;
  }

  if (subBlock.mode == SubBlockMode.basic && displayAdvancedOptions) {
    return false;
  }
  if (isStandaloneAdvancedMode(subBlock.mode) && !displayAdvancedOptions) {
    return false;
  }
  return true;
}

/// Port of `isTriggerModeSubBlock`.
bool isTriggerModeSubBlock(SubBlockConfig subBlock) =>
    subBlock.mode == SubBlockMode.trigger ||
    subBlock.mode == SubBlockMode.triggerAdvanced;

/// Port of `isTriggerConfigSubBlock`.
bool isTriggerConfigSubBlock(SubBlockConfig subBlock) =>
    subBlock.type == 'trigger-config';

/// Port of `shouldUseSubBlockForTriggerModeCanonicalIndex`.
bool shouldUseSubBlockForTriggerModeCanonicalIndex(SubBlockConfig subBlock) =>
    isTriggerModeSubBlock(subBlock) || isTriggerConfigSubBlock(subBlock);

/// Port of `isPureTriggerBlockConfig`.
bool isPureTriggerBlockConfig(TriggerVisibilityBlockConfig? blockConfig) =>
    blockConfig != null &&
    (blockConfig.triggersEnabled ?? false) &&
    blockConfig.category == BlockCategory.triggers;

/// Port of `isSubBlockVisibleForTriggerMode`.
bool isSubBlockVisibleForTriggerMode(
  SubBlockConfig subBlock,
  // ignore: avoid_positional_boolean_parameters, mirrors the upstream signature
  bool displayTriggerMode, [
  TriggerVisibilityBlockConfig? blockConfig,
]) {
  if (isTriggerConfigSubBlock(subBlock)) {
    return displayTriggerMode || isPureTriggerBlockConfig(blockConfig);
  }
  if (isTriggerModeSubBlock(subBlock)) return displayTriggerMode;
  if (displayTriggerMode) return false;
  return true;
}

/// Port of `isToolInputOnlySubBlock`.
bool isToolInputOnlySubBlock(SubBlockConfig subBlock) =>
    subBlock.context == 'tool-input';

/// Port of `isSubBlockFeatureEnabled`: `showWhenEnvSet` gate.
bool isSubBlockFeatureEnabled(
  SubBlockConfig subBlock,
  SubBlockEnvironment environment,
) {
  final spec = subBlock.showWhenEnvSet;
  if (spec == null || spec.isEmpty) return true;
  return environment.anyEnvSet(spec);
}

/// Port of `isSubBlockHidden`: `hideWhenHosted` and `hideWhenEnvSet`.
bool isSubBlockHidden(
  SubBlockConfig subBlock,
  SubBlockEnvironment environment,
) {
  if ((subBlock.hideWhenHosted ?? false) && environment.hosted) return true;
  final spec = subBlock.hideWhenEnvSet;
  if (spec != null && spec.isNotEmpty && environment.anyEnvSet(spec)) {
    return true;
  }
  return false;
}
