/// What the palette lists for a query: the action and page sets
/// (`search-modal.tsx:263-669`), the per-section ranking
/// (`entriesBySection`, 1062-1201), and the browse / search layouts
/// (1203-1275). Pure: the widget renders whatever this returns.
library;

import 'package:flutter/foundation.dart';
import 'package:sim_app/features/workspace_shell/search/palette_catalog.dart';
import 'package:sim_app/features/workspace_shell/search/palette_models.dart';
import 'package:sim_app/features/workspace_shell/search/palette_ranking.dart';
import 'package:sim_app/features/workspace_shell/shared/permission_config.dart';
import 'package:sim_design/sim_design.dart';

/// Callbacks the action verbs run.
@immutable
class PaletteActionHandlers {
  const PaletteActionHandlers({
    required this.invokeCommand,
    required this.copyWorkflowLink,
    required this.newChat,
    required this.navigateToSettings,
    this.createWorkflow,
    this.createFolder,
    this.importWorkflow,
  });

  /// `useInvokeGlobalCommand()(id)`: runs a page-registered command.
  final void Function(String commandId) invokeCommand;
  final VoidCallback copyWorkflowLink;
  final VoidCallback newChat;

  /// `navigateToSettings({ section })`; `null` opens the default section.
  final void Function(String? section) navigateToSettings;
  final VoidCallback? createWorkflow;
  final VoidCallback? createFolder;
  final VoidCallback? importWorkflow;
}

/// The action list of `search-modal.tsx:344-669`, before context filtering.
List<PaletteAction> buildPaletteActions({
  required PageActionContext? pageContext,
  required bool canEdit,
  required bool canAdmin,
  required bool chatEnabled,
  required PaletteActionHandlers handlers,
}) {
  VoidCallback invoke(String id) =>
      () => handlers.invokeCommand(id);
  const workflow = PageActionContext.workflow;
  final list = <PaletteAction>[
    PaletteAction(
      id: 'run-workflow',
      name: 'Run workflow',
      keywords: 'execute start play test',
      icon: SimEmcnIcons.play,
      shortcut: '⌘↵',
      context: workflow,
      run: invoke('run-workflow'),
    ),
    if (canAdmin)
      PaletteAction(
        id: 'deploy-workflow',
        name: 'Deploy workflow',
        keywords: 'ship release publish api',
        exactQueries: const ['deploy'],
        icon: SimEmcnIcons.rocket,
        context: workflow,
        run: invoke('deploy-workflow'),
      ),
    PaletteAction(
      id: 'fit-to-view',
      name: 'Fit workflow to view',
      keywords: 'zoom center recenter canvas reset',
      icon: SimEmcnIcons.selectAll,
      shortcut: '⇧⌘F',
      context: workflow,
      run: invoke('fit-to-view'),
    ),
    PaletteAction(
      id: 'copy-workflow-url',
      name: 'Copy workflow link',
      keywords: 'url share clipboard',
      exactQueries: const ['copy'],
      icon: SimEmcnIcons.duplicate,
      context: workflow,
      run: handlers.copyWorkflowLink,
    ),
    if (chatEnabled)
      PaletteAction(
        id: 'new-chat',
        name: 'New chat',
        keywords: 'chat chats message ask sim assistant home',
        exactQueries: const ['chats'],
        icon: SimEmcnIcons.home,
        run: handlers.newChat,
      ),
    if (canEdit && handlers.createWorkflow != null)
      PaletteAction(
        id: 'create-workflow',
        name: 'Create workflow',
        keywords: 'new add build workflows',
        exactQueries: const ['workflows'],
        icon: SimEmcnIcons.plus,
        run: handlers.createWorkflow!,
      ),
    if (canEdit && handlers.createFolder != null)
      PaletteAction(
        id: 'create-folder',
        name: 'Create folder',
        keywords: 'new add group',
        icon: SimEmcnIcons.folderPlus,
        run: handlers.createFolder!,
      ),
    // The sidebar that mounts the palette always hands React an import
    // flow; while the port has none (the parser is Phase 2) the row stays
    // listed but disabled, like the sidebar's own menu item.
    if (canEdit &&
        (handlers.importWorkflow != null || handlers.createFolder != null))
      PaletteAction(
        id: 'import-workflow',
        name: 'Import workflow',
        keywords: 'upload add',
        icon: SimEmcnIcons.upload,
        enabled: handlers.importWorkflow != null,
        run: handlers.importWorkflow ?? () {},
      ),
    PaletteAction(
      id: 'invite-teammates',
      name: 'Invite teammates',
      keywords: 'members people add user organization',
      icon: SimEmcnIcons.send,
      run: () => handlers.navigateToSettings('teammates'),
    ),
  ];

  PaletteAction page(
    String id,
    String name,
    String keywords,
    SimIconData icon,
    PageActionContext context,
  ) => PaletteAction(
    id: id,
    name: name,
    keywords: keywords,
    icon: icon,
    context: context,
    run: invoke(id),
  );

  switch (pageContext) {
    case PageActionContext.tables when canEdit:
      const c = PageActionContext.tables;
      list.addAll([
        page(
          'tables-new-table',
          'New table',
          'create add',
          SimEmcnIcons.plus,
          c,
        ),
        page(
          'tables-new-folder',
          'New folder',
          'create add group',
          SimEmcnIcons.folderPlus,
          c,
        ),
        page(
          'tables-import-csv',
          'Import CSV',
          'upload tsv spreadsheet',
          SimEmcnIcons.upload,
          c,
        ),
      ]);
    case PageActionContext.tableDetail:
      const c = PageActionContext.tableDetail;
      list.add(
        page(
          'table-export-csv',
          'Export CSV',
          'download spreadsheet',
          SimEmcnIcons.download,
          c,
        ),
      );
      if (canEdit) {
        list.addAll([
          page(
            'table-new-column',
            'New column',
            'create add field',
            SimEmcnIcons.columns3,
            c,
          ),
          page(
            'table-import-csv',
            'Import CSV',
            'upload tsv spreadsheet',
            SimEmcnIcons.upload,
            c,
          ),
        ]);
      }
    case PageActionContext.files when canEdit:
      const c = PageActionContext.files;
      list.addAll([
        page(
          'files-new-file',
          'New file',
          'create add document markdown',
          SimEmcnIcons.file,
          c,
        ),
        page(
          'files-new-folder',
          'New folder',
          'create add group',
          SimEmcnIcons.folderPlus,
          c,
        ),
        page(
          'files-upload',
          'Upload',
          'add import file',
          SimEmcnIcons.upload,
          c,
        ),
      ]);
    case PageActionContext.fileDetail:
      const c = PageActionContext.fileDetail;
      list.add(
        page(
          'file-download',
          'Download',
          'save export',
          SimEmcnIcons.download,
          c,
        ),
      );
      if (canEdit) {
        list.addAll([
          page('file-rename', 'Rename', 'edit name', SimEmcnIcons.pencil, c),
          page('file-share', 'Share', 'link send', SimEmcnIcons.send, c),
          page('file-delete', 'Delete', 'remove trash', SimEmcnIcons.trash, c),
        ]);
      }
    case PageActionContext.knowledge when canEdit:
      const c = PageActionContext.knowledge;
      list.addAll([
        page(
          'knowledge-new-base',
          'New base',
          'create add knowledge kb',
          SimEmcnIcons.plus,
          c,
        ),
        page(
          'knowledge-new-folder',
          'New folder',
          'create add group',
          SimEmcnIcons.folderPlus,
          c,
        ),
      ]);
    case PageActionContext.knowledgeBase when canEdit:
      const c = PageActionContext.knowledgeBase;
      list.addAll([
        page(
          'knowledge-base-new-documents',
          'New documents',
          'add upload document',
          SimEmcnIcons.plus,
          c,
        ),
        page(
          'knowledge-base-new-connector',
          'New connector',
          'add sync source connect',
          SimEmcnIcons.integration,
          c,
        ),
        page(
          'knowledge-base-rename',
          'Rename',
          'edit name',
          SimEmcnIcons.pencil,
          c,
        ),
        page(
          'knowledge-base-tags',
          'Edit tags',
          'label metadata',
          SimEmcnIcons.tagIcon,
          c,
        ),
        page(
          'knowledge-base-delete',
          'Delete',
          'remove trash',
          SimEmcnIcons.trash,
          c,
        ),
      ]);
    case PageActionContext.logs || PageActionContext.logsDashboard:
      final c = pageContext!;
      list.add(
        page(
          'logs-refresh',
          'Refresh',
          'reload update',
          SimEmcnIcons.refreshCw,
          c,
        ),
      );
      if (canEdit) {
        list.add(
          page(
            'logs-export',
            'Export',
            'download csv',
            SimEmcnIcons.download,
            c,
          ),
        );
      }
      list.add(
        c == PageActionContext.logs
            ? page(
                'logs-show-dashboard',
                'Switch to Dashboard',
                'charts stats overview',
                SimEmcnIcons.library,
                c,
              )
            : page(
                'logs-show-logs',
                'Switch to Logs',
                'list executions runs',
                SimEmcnIcons.library,
                c,
              ),
      );
    case _:
      break;
  }
  return list;
}

/// The page list of `search-modal.tsx:263-337`; a hidden tab's page stays
/// listed when access requests are enabled (except Skills).
List<PalettePageItem> buildPalettePages({
  required String workspaceId,
  required ShellPermissionConfig permissions,
  required VoidCallback openHelp,
  required VoidCallback openSettings,
  bool accessRequestsEnabled = false,
}) {
  final base = '/workspace/$workspaceId';
  return [
    if (!(permissions.hideIntegrationsTab && !accessRequestsEnabled))
      PalettePageItem(
        id: 'integrations',
        name: 'Integrations',
        icon: SimEmcnIcons.integration,
        href: '$base/integrations',
      ),
    if (!permissions.hideIntegrationsTab)
      PalettePageItem(
        id: 'skills',
        name: 'Skills',
        icon: SimEmcnIcons.hammer,
        href: '$base/skills',
      ),
    if (!(permissions.hideTablesTab && !accessRequestsEnabled))
      PalettePageItem(
        id: 'tables',
        name: 'Tables',
        icon: SimEmcnIcons.table,
        href: '$base/tables',
      ),
    if (!(permissions.hideFilesTab && !accessRequestsEnabled))
      PalettePageItem(
        id: 'files',
        name: 'Files',
        icon: SimEmcnIcons.file,
        href: '$base/files',
      ),
    if (!(permissions.hideKnowledgeBaseTab && !accessRequestsEnabled))
      PalettePageItem(
        id: 'knowledge-base',
        name: 'Knowledge bases',
        icon: SimEmcnIcons.database,
        href: '$base/knowledge',
      ),
    PalettePageItem(
      id: 'logs',
      name: 'Logs',
      icon: SimEmcnIcons.library,
      href: '$base/logs',
      shortcut: '⇧⌘L',
    ),
    PalettePageItem(
      id: 'secrets',
      name: 'Secrets',
      icon: SimEmcnIcons.key,
      href: '$base/settings/secrets',
    ),
    PalettePageItem(
      id: 'help',
      name: 'Help',
      icon: SimEmcnIcons.helpCircle,
      onSelect: openHelp,
    ),
    PalettePageItem(
      id: 'settings',
      name: 'Settings',
      icon: SimEmcnIcons.settings,
      onSelect: openSettings,
    ),
  ];
}

/// The entity lists the shell feeds the palette. Groups whose data source
/// is not ported yet (files, tables, knowledge bases, logs, connected
/// accounts, chats: Phase 4) stay empty and therefore do not render.
@immutable
class PaletteSources {
  const PaletteSources({
    this.workflows = const [],
    this.workspaces = const [],
    this.files = const [],
    this.tables = const [],
    this.knowledgeBases = const [],
    this.logs = const [],
    this.connectedAccounts = const [],
    this.chats = const [],
  });

  final List<PaletteFolderedItem> workflows;
  final List<PaletteWorkspaceItem> workspaces;
  final List<PaletteFolderedItem> files;
  final List<PaletteFolderedItem> tables;
  final List<PaletteFolderedItem> knowledgeBases;
  final List<PaletteLogItem> logs;
  final List<PaletteIntegrationItem> connectedAccounts;
  final List<PaletteTaskItem> chats;
}

/// The groups to render for one query.
@immutable
class PaletteView {
  const PaletteView({required this.searching, required this.groups});

  /// A non-empty trimmed query: one flat, heading-less group.
  final bool searching;

  /// Non-empty groups in render order.
  final List<PaletteGroup> groups;

  List<PaletteEntry> get entries => [for (final g in groups) ...g.entries];
}

String? _folderTokens(PaletteFolderedItem item) =>
    item.folderPath?.map(toSearchToken).join(' ');

/// `entriesBySection` + `searchResults` / `sectionGroups`.
PaletteView buildPaletteView({
  required String query,
  required List<PaletteAction> actions,
  required List<PalettePageItem> pages,
  required PaletteCatalog catalog,
  required PaletteSources sources,
  required PageActionContext? pageContext,
  required ShellPermissionConfig permissions,
  required bool chatEnabled,
  String? currentWorkflowId,
}) {
  final trimmed = query.trim();
  final searching = trimmed.isNotEmpty;
  final lowerQuery = trimmed.toLowerCase();
  final onCanvas = pageContext == PageActionContext.workflow;

  List<Scored<T>> rank<T>(
    SearchSection section,
    List<T> items,
    String Function(T) toValue, {
    String? Function(T)? toExtra,
  }) => searching
      ? scoreSectionItems(
          section,
          items,
          toValue,
          query,
          toExtra: toExtra,
          maxResults: maxResultsPerGroup,
        )
      : [for (final item in items) Scored(item, 0)];

  List<PaletteEntry> entries<T>(
    SearchSection section,
    List<Scored<T>> scored, [
    double Function(T item, double score)? adjust,
  ]) => [
    for (final s in scored)
      PaletteEntry(
        section,
        s.item as Object,
        adjust == null ? s.score : adjust(s.item, s.score),
      ),
  ];

  final available = actions
      .where((a) => a.context == null || a.context == pageContext)
      .toList();
  final pageActions = pageContext == null
      ? const <PaletteAction>[]
      : available.where((a) => a.group == ActionGroup.actions).toList();
  final simActions = available
      .where((a) => a.group == ActionGroup.sim)
      .toList();
  List<Scored<PaletteAction>> rankActions(
    List<PaletteAction> items,
    String label,
  ) => searching
      ? scoreActions(
          items,
          query,
          maxResults: maxResultsPerGroup,
          groupLabel: label,
        )
      : [for (final a in items) Scored(a, 0)];

  bool notOwnCustomBlock(PaletteBlockItem b) =>
      b.sourceWorkflowId == null || b.sourceWorkflowId != currentWorkflowId;
  final blocks = onCanvas
      ? catalog.blocks.where(notOwnCustomBlock).toList()
      : const <PaletteBlockItem>[];
  final tools = onCanvas
      ? catalog.tools.where(notOwnCustomBlock).toList()
      : const <PaletteBlockItem>[];
  final triggers = onCanvas
      ? [for (final t in catalog.triggers) t.asTriggerRow()]
      : const <PaletteBlockItem>[];
  final blockNames = {
    for (final b in [...blocks, ...tools]) b.name.toLowerCase(),
  };

  final hideIntegrations = permissions.hideIntegrationsTab;
  final bySection = <SearchSection, List<PaletteEntry>>{
    SearchSection.actions: [
      if (pageContext != null)
        ...entries(SearchSection.actions, rankActions(pageActions, 'Actions')),
      ...entries(SearchSection.actions, rankActions(simActions, 'Sim')),
    ],
    SearchSection.blocks: entries(
      SearchSection.blocks,
      rank(
        SearchSection.blocks,
        blocks,
        (b) => b.name,
        toExtra: (b) => b.searchValue,
      ),
      (b, score) => b.name.toLowerCase() == lowerQuery ? pageMatchTier : score,
    ),
    SearchSection.triggers: entries(
      SearchSection.triggers,
      rank(
        SearchSection.triggers,
        triggers,
        (t) => t.name,
        toExtra: (t) => '${toSearchToken(t.name)} ${t.id}',
      ),
      (t, score) {
        final base = (t.baseName ?? t.name).toLowerCase();
        return base == lowerQuery && !blockNames.contains(base)
            ? pageMatchTier
            : score;
      },
    ),
    SearchSection.tools: entries(
      SearchSection.tools,
      rank(
        SearchSection.tools,
        tools,
        (t) => t.name,
        toExtra: (t) => t.searchValue,
      ),
    ),
    SearchSection.toolOperations: entries(
      SearchSection.toolOperations,
      rank(
        SearchSection.toolOperations,
        onCanvas && searching
            ? catalog.toolOperations
            : const <PaletteToolOperationItem>[],
        (o) => o.name,
        toExtra: (o) => o.searchValue,
      ),
    ),
    SearchSection.pages: entries(
      SearchSection.pages,
      rank(SearchSection.pages, pages, (p) => p.name),
      (p, score) => p.name.toLowerCase() == lowerQuery ? pageMatchTier : score,
    ),
    SearchSection.workflows: entries(
      SearchSection.workflows,
      rank(
        SearchSection.workflows,
        sources.workflows,
        (w) => w.name,
        toExtra: _folderTokens,
      ),
    ),
    SearchSection.workspaces: entries(
      SearchSection.workspaces,
      rank(SearchSection.workspaces, sources.workspaces, (w) => w.name),
    ),
    SearchSection.files: entries(
      SearchSection.files,
      rank(
        SearchSection.files,
        permissions.hideFilesTab
            ? const <PaletteFolderedItem>[]
            : sources.files,
        (f) => f.name,
        toExtra: _folderTokens,
      ),
    ),
    SearchSection.tables: entries(
      SearchSection.tables,
      rank(
        SearchSection.tables,
        permissions.hideTablesTab
            ? const <PaletteFolderedItem>[]
            : sources.tables,
        (t) => t.name,
        toExtra: _folderTokens,
      ),
    ),
    SearchSection.knowledgeBases: entries(
      SearchSection.knowledgeBases,
      rank(
        SearchSection.knowledgeBases,
        permissions.hideKnowledgeBaseTab
            ? const <PaletteFolderedItem>[]
            : sources.knowledgeBases,
        (k) => k.name,
        toExtra: _folderTokens,
      ),
    ),
    SearchSection.logs: entries(
      SearchSection.logs,
      rank(SearchSection.logs, sources.logs, (l) => l.name),
    ),
    SearchSection.connectedAccounts: entries(
      SearchSection.connectedAccounts,
      rank(
        SearchSection.connectedAccounts,
        onCanvas || hideIntegrations
            ? const <PaletteIntegrationItem>[]
            : sources.connectedAccounts,
        (c) => c.name,
      ),
    ),
    SearchSection.chats: entries(
      SearchSection.chats,
      rank(
        SearchSection.chats,
        permissions.hideCopilot || !chatEnabled
            ? const <PaletteTaskItem>[]
            : sources.chats,
        (c) => c.name,
      ),
    ),
    SearchSection.integrations: entries(
      SearchSection.integrations,
      rank(
        SearchSection.integrations,
        onCanvas || hideIntegrations
            ? const <PaletteIntegrationItem>[]
            : catalog.integrations,
        (i) => i.name,
      ),
    ),
  };

  final hoisted = pageContext?.hoistedSection;
  final ordered = hoisted == null
      ? SearchSection.values
      : [
          SearchSection.actions,
          hoisted,
          ...SearchSection.values.where(
            (s) => s != SearchSection.actions && s != hoisted,
          ),
        ];

  if (searching) {
    final results = globalSearchResults(
      bySection,
      ordered,
    ).take(maxSearchResults).toList();
    return PaletteView(
      searching: true,
      groups: [
        if (results.isNotEmpty) PaletteGroup(key: 'results', entries: results),
      ],
    );
  }

  List<PaletteEntry> actionsIn(ActionGroup group) => [
    for (final e in bySection[SearchSection.actions]!)
      if ((e.item as PaletteAction).group == group) e,
  ];
  PaletteGroup section(SearchSection s) =>
      PaletteGroup(key: s.name, heading: s.label, entries: bySection[s]!);

  final groups = <PaletteGroup>[
    if (pageContext != null)
      PaletteGroup(
        key: 'actions',
        heading: 'Actions',
        entries: actionsIn(ActionGroup.actions),
      ),
    PaletteGroup(
      key: 'sim',
      heading: 'Sim',
      entries: actionsIn(ActionGroup.sim),
    ),
    if (hoisted != null) section(hoisted),
    ...SearchSection.canvas.map(section),
    ...SearchSection.values
        .where(
          (s) =>
              s != SearchSection.actions &&
              s != hoisted &&
              !SearchSection.canvas.contains(s),
        )
        .map(section),
  ];
  return PaletteView(
    searching: false,
    groups: [
      for (final g in groups)
        if (g.entries.isNotEmpty) g,
    ],
  );
}
