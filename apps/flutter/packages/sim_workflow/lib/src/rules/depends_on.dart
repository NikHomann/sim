/// Ports of `apps/sim/lib/workflows/subblocks/dependencies.ts`.
library;

import 'package:meta/meta.dart';
import 'package:sim_workflow/src/model/block_config.dart';
import 'package:sim_workflow/src/rules/canonical.dart';

/// Port of `DependentSubBlock`.
@immutable
class DependentSubBlock {
  const DependentSubBlock({required this.subBlockId, required this.reason});

  final String subBlockId;
  final String reason;
}

/// Port of `getDependsOnFields`: flattens both declaration forms.
List<String> getDependsOnFields(DependsOn? dependsOn) =>
    dependsOn?.allFields ?? const [];

/// Port of `getSubBlocksDependingOnChange`: direct dependants, treating a
/// canonical group's id and members as one field.
List<SubBlockConfig> getSubBlocksDependingOnChange(
  List<SubBlockConfig> allSubBlocks,
  String changedSubBlockId,
) {
  final canonicalIndex = buildCanonicalIndex(allSubBlocks);
  final canonicalId = canonicalIndex.canonicalIdBySubBlockId[changedSubBlockId];
  final group = canonicalId == null
      ? null
      : canonicalIndex.groupsById[canonicalId];
  final changedFields = <String>{
    changedSubBlockId,
    ?canonicalId,
    if (group?.basicId != null) group!.basicId!,
    ...?group?.advancedIds,
  };

  return allSubBlocks
      .where(
        (subBlock) =>
            getDependsOnFields(subBlock.dependsOn).any(changedFields.contains),
      )
      .toList();
}

/// Port of `getTransitiveSubBlockDependents`: every transitive dependant of
/// the changed sub-blocks, each reported once with the field it followed.
List<DependentSubBlock> getTransitiveSubBlockDependents(
  List<SubBlockConfig> allSubBlocks,
  Iterable<String> changedSubBlockIds,
) {
  final dependents = <DependentSubBlock>[];
  final visited = <String>{...changedSubBlockIds};
  final queue = [...visited];

  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    for (final subBlock in getSubBlocksDependingOnChange(
      allSubBlocks,
      current,
    )) {
      if (subBlock.id.isEmpty || !visited.add(subBlock.id)) continue;
      dependents.add(
        DependentSubBlock(
          subBlockId: subBlock.id,
          reason: '${subBlock.id} depends on $current',
        ),
      );
      queue.add(subBlock.id);
    }
  }

  return dependents;
}
