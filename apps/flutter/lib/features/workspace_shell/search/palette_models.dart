/// Result types of the search palette (`search-modal/utils.ts` and
/// `stores/modals/search/types.ts`).
library;

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:sim_design/sim_design.dart';

/// `SEARCH_SECTIONS` in canonical order, with `SECTION_LABELS`.
enum SearchSection {
  actions('Sim'),
  blocks('Blocks'),
  triggers('Triggers'),
  tools('Tools'),
  toolOperations('Tool operations'),
  pages('Pages'),
  workflows('Workflows'),
  workspaces('Workspaces'),
  files('Files'),
  tables('Tables'),
  knowledgeBases('Knowledge Bases'),
  logs('Logs'),
  connectedAccounts('Connected Integrations'),
  chats('Chats'),
  integrations('Integrations')
  ;

  const SearchSection(this.label);

  final String label;

  /// `CANVAS_SECTIONS`.
  static const List<SearchSection> canvas = [
    blocks,
    triggers,
    tools,
    toolOperations,
  ];
}

/// `PageActionContext`: pages that contribute palette actions while active.
enum PageActionContext {
  workflow,
  tables,
  tableDetail,
  files,
  fileDetail,
  knowledge,
  knowledgeBase,
  logs,
  logsDashboard
  ;

  /// `PAGE_CONTEXT_HOISTED_SECTION`.
  SearchSection? get hoistedSection => switch (this) {
    workflow => null,
    tables || tableDetail => SearchSection.tables,
    files || fileDetail => SearchSection.files,
    knowledge || knowledgeBase => SearchSection.knowledgeBases,
    logs || logsDashboard => SearchSection.logs,
  };
}

/// `searchModalPageContext` (`sidebar.tsx:1091-1108`): the page whose
/// registered commands are invocable. List pages match exactly, detail roots
/// as a single path segment.
PageActionContext? pageContextForPath({
  required String? pathname,
  required String workspaceId,
  String? workflowId,
  bool logsDashboard = false,
}) {
  if (pathname == null || pathname.isEmpty) return null;
  if (workflowId != null && workflowId.isNotEmpty) {
    return PageActionContext.workflow;
  }
  final base = '/workspace/$workspaceId';
  bool detail(String prefix) {
    if (!pathname.startsWith(prefix)) return false;
    final rest = pathname.substring(prefix.length);
    return rest.isNotEmpty && !rest.contains('/');
  }

  if (pathname == '$base/tables') return PageActionContext.tables;
  if (detail('$base/tables/')) return PageActionContext.tableDetail;
  if (pathname == '$base/files') return PageActionContext.files;
  if (detail('$base/files/')) return PageActionContext.fileDetail;
  if (pathname == '$base/knowledge') return PageActionContext.knowledge;
  if (detail('$base/knowledge/')) return PageActionContext.knowledgeBase;
  if (pathname == '$base/logs') {
    return logsDashboard
        ? PageActionContext.logsDashboard
        : PageActionContext.logs;
  }
  return null;
}

/// `ActionGroupLabel`.
enum ActionGroup { sim, actions }

/// `ActionItem`: a verb the palette can run directly.
@immutable
class PaletteAction {
  const PaletteAction({
    required this.id,
    required this.name,
    required this.icon,
    required this.run,
    this.context,
    this.keywords,
    this.exactQueries = const [],
    this.shortcut,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String? keywords;

  /// cmdk `disabled`: listed at half opacity, skipped by the arrows and
  /// inert on click.
  final bool enabled;

  /// Lowercase queries that name this action outright.
  final List<String> exactQueries;
  final SimIconData icon;
  final String? shortcut;

  /// `null` is the `'global'` context.
  final PageActionContext? context;
  final VoidCallback run;

  /// `getActionGroupLabel`.
  ActionGroup get group =>
      context == null ? ActionGroup.sim : ActionGroup.actions;
}

/// `SearchBlockItem` (blocks, triggers, tools).
@immutable
class PaletteBlockItem {
  const PaletteBlockItem({
    required this.id,
    required this.type,
    required this.name,
    required this.bgColor,
    this.searchValue = '',
    this.sourceWorkflowId,
    this.triggerCapable = false,
    this.baseName,
  });

  final String id;
  final String type;
  final String name;
  final Color bgColor;
  final String searchValue;

  /// Custom blocks bound to a workflow are hidden on that workflow's canvas.
  final String? sourceWorkflowId;

  /// `hasTriggerCapability(config)` (triggers only).
  final bool triggerCapable;

  /// The trigger's undecorated name, kept rankable after the " Trigger"
  /// display suffix.
  final String? baseName;

  PaletteBlockItem asTriggerRow() => PaletteBlockItem(
    id: id,
    type: type,
    name: name.endsWith('Trigger') ? name : '$name Trigger',
    bgColor: bgColor,
    searchValue: searchValue,
    sourceWorkflowId: sourceWorkflowId,
    triggerCapable: triggerCapable,
    baseName: name,
  );
}

/// `SearchToolOperationItem`.
@immutable
class PaletteToolOperationItem {
  const PaletteToolOperationItem({
    required this.id,
    required this.blockType,
    required this.operationId,
    required this.name,
    required this.serviceName,
    required this.bgColor,
    this.searchValue = '',
  });

  final String id;
  final String blockType;
  final String operationId;
  final String name;
  final String serviceName;
  final Color bgColor;
  final String searchValue;
}

/// `IntegrationSearchItem` (integrations and connected accounts).
@immutable
class PaletteIntegrationItem {
  const PaletteIntegrationItem({
    required this.id,
    required this.name,
    required this.href,
    required this.bgColor,
  });

  final String id;
  final String name;
  final String href;
  final Color bgColor;
}

/// `TaskItem` (chats) — [date] is the formatted trailing metadata.
@immutable
class PaletteTaskItem {
  const PaletteTaskItem({
    required this.id,
    required this.name,
    required this.href,
    this.date,
  });

  final String id;
  final String name;
  final String href;
  final String? date;
}

/// `FolderedItem` / `WorkflowItem` / `FileItem`.
@immutable
class PaletteFolderedItem {
  const PaletteFolderedItem({
    required this.id,
    required this.name,
    required this.href,
    this.folderPath,
    this.isCurrent = false,
  });

  final String id;
  final String name;
  final String href;

  /// Owning folder names, root first; `null` at the root.
  final List<String>? folderPath;
  final bool isCurrent;
}

/// `LogItem`.
@immutable
class PaletteLogItem {
  const PaletteLogItem({
    required this.id,
    required this.name,
    required this.href,
    required this.date,
  });

  final String id;
  final String name;
  final String href;
  final String date;
}

/// `WorkspaceItem`.
@immutable
class PaletteWorkspaceItem {
  const PaletteWorkspaceItem({
    required this.id,
    required this.name,
    required this.href,
    this.isCurrent = false,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String href;
  final bool isCurrent;
  final String? logoUrl;
}

/// `PageItem`.
@immutable
class PalettePageItem {
  const PalettePageItem({
    required this.id,
    required this.name,
    required this.icon,
    this.href,
    this.onSelect,
    this.shortcut,
  });

  final String id;
  final String name;
  final SimIconData icon;
  final String? href;
  final VoidCallback? onSelect;
  final String? shortcut;
}

/// `SearchEntry`: one ranked row of a section.
@immutable
class PaletteEntry {
  const PaletteEntry(this.section, this.item, this.score);

  final SearchSection section;
  final Object item;
  final double score;

  String get id => switch (item) {
    final PaletteAction i => i.id,
    final PaletteBlockItem i => i.id,
    final PaletteToolOperationItem i => i.id,
    final PaletteIntegrationItem i => i.id,
    final PaletteTaskItem i => i.id,
    final PaletteFolderedItem i => i.id,
    final PaletteLogItem i => i.id,
    final PaletteWorkspaceItem i => i.id,
    final PalettePageItem i => i.id,
    _ => '',
  };

  /// Selectable (cmdk skips a `disabled` item).
  bool get enabled => switch (item) {
    final PaletteAction a => a.enabled,
    _ => true,
  };

  /// `search.palette.row.<section>.<id>`.
  String get parityId => 'search.palette.row.${section.name}.$id';

  @override
  String toString() => 'PaletteEntry(${section.name}.$id, $score)';
}

/// One rendered group: a headed browse section, or the heading-less flat
/// search results ([heading] `null`).
@immutable
class PaletteGroup {
  const PaletteGroup({
    required this.key,
    required this.entries,
    this.heading,
  });

  /// Parity key (`actions`, `sim`, a section name, or `results`).
  final String key;
  final String? heading;
  final List<PaletteEntry> entries;
}

/// `add-block-from-toolbar` detail: a Blocks/Triggers/Tools/Tool-operations
/// selection. The canvas listener arrives in Phase 2.
@immutable
class AddBlockRequest {
  const AddBlockRequest({
    required this.type,
    this.enableTriggerMode = false,
    this.presetOperation,
  });

  final String type;
  final bool enableTriggerMode;
  final String? presetOperation;

  @override
  bool operator ==(Object other) =>
      other is AddBlockRequest &&
      other.type == type &&
      other.enableTriggerMode == enableTriggerMode &&
      other.presetOperation == presetOperation;

  @override
  int get hashCode => Object.hash(type, enableTriggerMode, presetOperation);

  @override
  String toString() =>
      'AddBlockRequest($type, trigger: $enableTriggerMode, op: $presetOperation)';
}
