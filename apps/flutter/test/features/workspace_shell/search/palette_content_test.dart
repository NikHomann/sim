// Failure modes of what the palette lists (`search-modal.tsx`), each a test:
// 1. browse order: [Actions (page)], Sim, [hoisted page section], canvas
//    groups, then pages … integrations (Chats before Integrations); empty
//    groups render nothing;
// 2. searching flattens to one heading-less group capped at 50, ties in
//    hoisted section order;
// 3. canvas groups (blocks, triggers, tools) only on the workflow canvas;
//    tool operations only while searching there; integrations and connected
//    accounts only off the canvas; a workflow's own custom block is hidden
//    on its canvas;
// 4. permission-hidden groups stay empty even when data is present; chats
//    need chat enabled and no hideCopilot;
// 5. action sets per page context, gated by canEdit / canAdmin /
//    chatEnabled / available handlers; workflow verbs only on the canvas;
// 6. pages hidden per permission unless access requests are enabled
//    (Skills always follows hideIntegrationsTab);
// 7. an exact block / page name ranks at the page tier; a trigger's base
//    name does only when no block shares it;
// 8. the page context is derived from the path (list pages exactly, detail
//    roots as one segment, the canvas whenever a workflow is open).

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/workspace_shell/search/palette_catalog.dart';
import 'package:sim_app/features/workspace_shell/search/palette_content.dart';
import 'package:sim_app/features/workspace_shell/search/palette_models.dart';
import 'package:sim_app/features/workspace_shell/search/palette_ranking.dart';
import 'package:sim_app/features/workspace_shell/shared/permission_config.dart';

const ws = 'ws-1';

PaletteActionHandlers handlers({List<String>? invoked}) =>
    PaletteActionHandlers(
      invokeCommand: (id) => invoked?.add(id),
      copyWorkflowLink: () {},
      newChat: () {},
      navigateToSettings: (_) {},
      createWorkflow: () {},
      createFolder: () {},
      importWorkflow: () {},
    );

List<PaletteAction> actions({
  PageActionContext? context,
  bool canEdit = true,
  bool canAdmin = true,
  bool chatEnabled = true,
  PaletteActionHandlers? handlerSet,
}) => buildPaletteActions(
  pageContext: context,
  canEdit: canEdit,
  canAdmin: canAdmin,
  chatEnabled: chatEnabled,
  handlers: handlerSet ?? handlers(),
);

List<PalettePageItem> pages({
  ShellPermissionConfig permissions = const ShellPermissionConfig(),
  bool accessRequests = false,
}) => buildPalettePages(
  workspaceId: ws,
  permissions: permissions,
  accessRequestsEnabled: accessRequests,
  openHelp: () {},
  openSettings: () {},
);

PaletteBlockItem block(String name, {String? type, String? source}) =>
    PaletteBlockItem(
      id: type ?? name.toLowerCase(),
      type: type ?? name.toLowerCase(),
      name: name,
      bgColor: const Color(0xFF6F3DFA),
      searchValue: name.toLowerCase(),
      sourceWorkflowId: source,
    );

PaletteFolderedItem item(String id, {String? name, bool current = false}) =>
    PaletteFolderedItem(
      id: id,
      name: name ?? id,
      href: '/workspace/$ws/x/$id',
      isCurrent: current,
    );

const integration = PaletteIntegrationItem(
  id: 'slack',
  name: 'Slack',
  href: '/workspace/ws-1/integrations/slack',
  bgColor: Color(0xFF611F69),
);

PaletteView view({
  String query = '',
  PageActionContext? context,
  PaletteCatalog catalog = const PaletteCatalog.empty(),
  PaletteSources sources = const PaletteSources(),
  ShellPermissionConfig permissions = const ShellPermissionConfig(),
  bool chatEnabled = true,
  bool canEdit = true,
  String? currentWorkflowId,
}) => buildPaletteView(
  query: query,
  actions: actions(
    context: context,
    chatEnabled: chatEnabled,
    canEdit: canEdit,
  ),
  pages: pages(permissions: permissions),
  catalog: catalog,
  sources: sources,
  pageContext: context,
  permissions: permissions,
  chatEnabled: chatEnabled,
  currentWorkflowId: currentWorkflowId,
);

final fullSources = PaletteSources(
  workflows: [item('wf-1', name: 'Onboarding')],
  workspaces: const [
    PaletteWorkspaceItem(id: ws, name: 'Acme', href: '/workspace/ws-1/w'),
  ],
  files: [item('file-1')],
  tables: [item('table-1')],
  knowledgeBases: [item('kb-1')],
  logs: const [
    PaletteLogItem(id: 'log-1', name: 'Run', href: '/l', date: 'Oct 21'),
  ],
  connectedAccounts: const [integration],
  chats: const [PaletteTaskItem(id: 'chat-1', name: 'Hello', href: '/c')],
);

final fullCatalog = InMemoryPaletteCatalog(
  blocks: [
    block('Agent'),
    block('Gmail', type: 'gmail_block'),
  ],
  triggers: [
    block('Start', type: 'start_trigger'),
    block('Gmail'),
  ],
  tools: [block('Slack', type: 'slack')],
  toolOperations: const [
    PaletteToolOperationItem(
      id: 'slack.send',
      blockType: 'slack',
      operationId: 'send',
      name: 'Send Message',
      serviceName: 'Slack',
      bgColor: Color(0xFF611F69),
    ),
  ],
  integrations: const [integration],
);

List<String> keys(PaletteView v) => [for (final g in v.groups) g.key];

void main() {
  group('1. browse order', () {
    test('off the canvas: Sim, then the canonical sections', () {
      final v = view(sources: fullSources, catalog: fullCatalog);
      expect(v.searching, isFalse);
      expect(keys(v), [
        'sim',
        'pages',
        'workflows',
        'workspaces',
        'files',
        'tables',
        'knowledgeBases',
        'logs',
        'connectedAccounts',
        'chats',
        'integrations',
      ]);
      expect(v.groups.first.heading, 'Sim');
    });

    test('a page context puts its Actions first and hoists its section', () {
      final v = view(
        context: PageActionContext.tables,
        sources: fullSources,
      );
      expect(keys(v).take(3), ['actions', 'sim', 'tables']);
      expect(v.groups.first.heading, 'Actions');
      expect(keys(v).where((k) => k == 'tables'), hasLength(1));
    });

    test('empty groups are dropped', () {
      final v = view();
      expect(keys(v), ['sim', 'pages']);
    });
  });

  group('2. searching', () {
    test('one heading-less group, capped at 50', () {
      final many = PaletteSources(
        workflows: [for (var i = 0; i < 80; i++) item('w$i', name: 'Flow $i')],
      );
      final v = view(query: 'flow', sources: many);
      expect(v.searching, isTrue);
      expect(v.groups, hasLength(1));
      expect(v.groups.single.heading, isNull);
      expect(v.groups.single.key, 'results');
      expect(v.entries, hasLength(maxSearchResults));
    });

    test('a query that matches nothing renders no group', () {
      expect(view(query: 'zzzzqqq').groups, isEmpty);
    });

    test('ties follow the hoisted section order', () {
      final sources = PaletteSources(
        tables: [item('t', name: 'Report')],
        workflows: [item('w', name: 'Report')],
      );
      final hoisted = view(
        query: 'report',
        context: PageActionContext.tables,
        sources: sources,
      );
      expect(hoisted.entries.take(2).map((e) => e.section), [
        SearchSection.tables,
        SearchSection.workflows,
      ]);
      final plain = view(query: 'report', sources: sources);
      expect(plain.entries.take(2).map((e) => e.section), [
        SearchSection.workflows,
        SearchSection.tables,
      ]);
    });
  });

  group('3. canvas groups', () {
    test('absent off the canvas', () {
      final v = view(catalog: fullCatalog, query: 'agent');
      expect(
        v.entries.where((e) => SearchSection.canvas.contains(e.section)),
        isEmpty,
      );
    });

    test('on the canvas: blocks, triggers, tools; no integrations', () {
      final v = view(
        context: PageActionContext.workflow,
        catalog: fullCatalog,
        sources: fullSources,
      );
      expect(keys(v).take(5), [
        'actions',
        'sim',
        'blocks',
        'triggers',
        'tools',
      ]);
      expect(keys(v), isNot(contains('toolOperations')));
      expect(keys(v), isNot(contains('integrations')));
      expect(keys(v), isNot(contains('connectedAccounts')));
      final triggers = v.groups.firstWhere((g) => g.key == 'triggers');
      expect(
        triggers.entries.map((e) => (e.item as PaletteBlockItem).name),
        ['Start Trigger', 'Gmail Trigger'],
      );
    });

    test('tool operations appear only while searching on the canvas', () {
      final v = view(
        context: PageActionContext.workflow,
        catalog: fullCatalog,
        query: 'send message',
      );
      expect(
        v.entries.map((e) => e.section),
        contains(SearchSection.toolOperations),
      );
      final off = view(catalog: fullCatalog, query: 'send message');
      expect(
        off.entries.map((e) => e.section),
        isNot(contains(SearchSection.toolOperations)),
      );
    });

    test("a workflow's own custom block is hidden on its canvas", () {
      final catalog = InMemoryPaletteCatalog(
        blocks: [
          block('Mine', source: 'wf-1'),
          block('Theirs', source: 'wf-2'),
        ],
      );
      final v = view(
        context: PageActionContext.workflow,
        catalog: catalog,
        currentWorkflowId: 'wf-1',
      );
      final blocks = v.groups.firstWhere((g) => g.key == 'blocks');
      expect(blocks.entries.map((e) => e.id), ['theirs']);
    });
  });

  group('4. permission-gated groups', () {
    test('hidden tabs empty their groups even with data', () {
      final v = view(
        sources: fullSources,
        catalog: fullCatalog,
        permissions: const ShellPermissionConfig(
          hideTablesTab: true,
          hideFilesTab: true,
          hideKnowledgeBaseTab: true,
          hideIntegrationsTab: true,
        ),
      );
      for (final key in [
        'tables',
        'files',
        'knowledgeBases',
        'integrations',
        'connectedAccounts',
      ]) {
        expect(keys(v), isNot(contains(key)), reason: key);
      }
      expect(keys(v), contains('chats'));
    });

    test('chats need chat enabled and Copilot visible', () {
      expect(
        keys(view(sources: fullSources, chatEnabled: false)),
        isNot(contains('chats')),
      );
      expect(
        keys(
          view(
            sources: fullSources,
            permissions: const ShellPermissionConfig(hideCopilot: true),
          ),
        ),
        isNot(contains('chats')),
      );
    });
  });

  group('5. action sets', () {
    List<String> ids(List<PaletteAction> list, PageActionContext? context) => [
      for (final a in list)
        if (a.context == null || a.context == context) a.id,
    ];

    test('global verbs, gated', () {
      expect(ids(actions(), null), [
        'new-chat',
        'create-workflow',
        'create-folder',
        'import-workflow',
        'invite-teammates',
      ]);
      expect(ids(actions(canEdit: false, chatEnabled: false), null), [
        'invite-teammates',
      ]);
      final noHandlers = actions(
        handlerSet: PaletteActionHandlers(
          invokeCommand: (_) {},
          copyWorkflowLink: () {},
          newChat: () {},
          navigateToSettings: (_) {},
        ),
      );
      expect(ids(noHandlers, null), ['new-chat', 'invite-teammates']);
    });

    test('workflow verbs only on the canvas; deploy needs admin', () {
      const c = PageActionContext.workflow;
      expect(ids(actions(context: c), c).take(4), [
        'run-workflow',
        'deploy-workflow',
        'fit-to-view',
        'copy-workflow-url',
      ]);
      expect(
        ids(actions(context: c, canAdmin: false), c),
        isNot(contains('deploy-workflow')),
      );
      expect(ids(actions(), null), isNot(contains('run-workflow')));
      final run = actions(context: c).firstWhere((a) => a.id == 'run-workflow');
      expect(run.shortcut, '⌘↵');
      expect(run.group, ActionGroup.actions);
    });

    test('page sets per context', () {
      Map<PageActionContext, List<String>> sets({required bool canEdit}) => {
        for (final c in PageActionContext.values)
          if (c != PageActionContext.workflow)
            c: [
              for (final a in actions(context: c, canEdit: canEdit))
                if (a.context == c) a.name,
            ],
      };
      expect(sets(canEdit: true), {
        PageActionContext.tables: ['New table', 'New folder', 'Import CSV'],
        PageActionContext.tableDetail: [
          'Export CSV',
          'New column',
          'Import CSV',
        ],
        PageActionContext.files: ['New file', 'New folder', 'Upload'],
        PageActionContext.fileDetail: ['Download', 'Rename', 'Share', 'Delete'],
        PageActionContext.knowledge: ['New base', 'New folder'],
        PageActionContext.knowledgeBase: [
          'New documents',
          'New connector',
          'Rename',
          'Edit tags',
          'Delete',
        ],
        PageActionContext.logs: ['Refresh', 'Export', 'Switch to Dashboard'],
        PageActionContext.logsDashboard: [
          'Refresh',
          'Export',
          'Switch to Logs',
        ],
      });
      expect(sets(canEdit: false), {
        PageActionContext.tables: <String>[],
        PageActionContext.tableDetail: ['Export CSV'],
        PageActionContext.files: <String>[],
        PageActionContext.fileDetail: ['Download'],
        PageActionContext.knowledge: <String>[],
        PageActionContext.knowledgeBase: <String>[],
        PageActionContext.logs: ['Refresh', 'Switch to Dashboard'],
        PageActionContext.logsDashboard: ['Refresh', 'Switch to Logs'],
      });
    });

    test('page verbs invoke their registered command', () {
      final invoked = <String>[];
      final list = actions(
        context: PageActionContext.tables,
        handlerSet: handlers(invoked: invoked),
      );
      list.firstWhere((a) => a.id == 'tables-new-table').run();
      expect(invoked, ['tables-new-table']);
    });
  });

  group('6. pages', () {
    test('the full list in order', () {
      expect(
        [for (final p in pages()) p.name],
        [
          'Integrations',
          'Skills',
          'Tables',
          'Files',
          'Knowledge bases',
          'Logs',
          'Secrets',
          'Help',
          'Settings',
        ],
      );
      final logs = pages().firstWhere((p) => p.id == 'logs');
      expect(logs.shortcut, '⇧⌘L');
      expect(logs.href, '/workspace/ws-1/logs');
      expect(
        pages().firstWhere((p) => p.id == 'secrets').href,
        '/workspace/ws-1/settings/secrets',
      );
    });

    test('hidden tabs drop their page unless access requests are on', () {
      const hidden = ShellPermissionConfig(
        hideTablesTab: true,
        hideFilesTab: true,
        hideKnowledgeBaseTab: true,
        hideIntegrationsTab: true,
      );
      expect(
        [for (final p in pages(permissions: hidden)) p.id],
        [
          'logs',
          'secrets',
          'help',
          'settings',
        ],
      );
      expect(
        [
          for (final p in pages(permissions: hidden, accessRequests: true))
            p.id,
        ],
        [
          'integrations',
          'tables',
          'files',
          'knowledge-base',
          'logs',
          'secrets',
          'help',
          'settings',
        ],
      );
    });
  });

  group('7. exact-name lifts', () {
    test('an exact page name ranks at the page tier', () {
      final v = view(query: 'logs');
      expect(v.entries.first.id, 'logs');
      expect(v.entries.first.score, pageMatchTier);
    });

    test('an exact block name ranks at the page tier', () {
      final v = view(
        query: 'agent',
        context: PageActionContext.workflow,
        catalog: fullCatalog,
      );
      expect(v.entries.first.id, 'agent');
      expect(v.entries.first.score, pageMatchTier);
    });

    test('a trigger base name lifts only when no block shares it', () {
      final start = view(
        query: 'start',
        context: PageActionContext.workflow,
        catalog: fullCatalog,
      );
      expect(start.entries.first.section, SearchSection.triggers);
      expect(start.entries.first.score, pageMatchTier);

      final gmail = view(
        query: 'gmail',
        context: PageActionContext.workflow,
        catalog: fullCatalog,
      );
      expect(gmail.entries.first.section, SearchSection.blocks);
      final trigger = gmail.entries.firstWhere(
        (e) => e.section == SearchSection.triggers,
      );
      expect(trigger.score, lessThan(pageMatchTier));
    });

    test('"workflows" names Create workflow outright', () {
      final v = view(query: 'workflows', sources: fullSources);
      expect(v.entries.first.id, 'create-workflow');
      expect(v.entries.first.score, pageMatchTier);
      // Then the Workflows section, lifted by its label.
      expect(v.entries[1].section, SearchSection.workflows);
    });
  });

  group('8. page context from the path', () {
    PageActionContext? ctx(
      String path, {
      String? workflowId,
      bool dash = false,
    }) => pageContextForPath(
      pathname: path,
      workspaceId: ws,
      workflowId: workflowId,
      logsDashboard: dash,
    );

    test('list pages, detail roots, canvas', () {
      expect(ctx('/workspace/ws-1/tables'), PageActionContext.tables);
      expect(ctx('/workspace/ws-1/tables/t1'), PageActionContext.tableDetail);
      expect(ctx('/workspace/ws-1/tables/t1/rows'), isNull);
      expect(ctx('/workspace/ws-1/files'), PageActionContext.files);
      expect(ctx('/workspace/ws-1/files/f1'), PageActionContext.fileDetail);
      expect(ctx('/workspace/ws-1/knowledge'), PageActionContext.knowledge);
      expect(
        ctx('/workspace/ws-1/knowledge/k1'),
        PageActionContext.knowledgeBase,
      );
      expect(ctx('/workspace/ws-1/logs'), PageActionContext.logs);
      expect(
        ctx('/workspace/ws-1/logs', dash: true),
        PageActionContext.logsDashboard,
      );
      expect(
        ctx('/workspace/ws-1/w/wf-1', workflowId: 'wf-1'),
        PageActionContext.workflow,
      );
      expect(ctx('/workspace/ws-1/home'), isNull);
      expect(ctx(''), isNull);
    });
  });
}
