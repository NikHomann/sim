import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/sidebar/presence/presence_avatars.dart';
import 'package:sim_app/features/workspace_shell/sidebar/rail/hover_menu.dart';
import 'package:sim_app/features/workspace_shell/sidebar/rail/rail_flyout.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/context_menu.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/inline_rename.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/sidebar_chip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_section.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_model.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_operations.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/workflow_tree.dart';
import 'package:sim_design/sim_design.dart';

/// The "Workflows" section (`sidebar.tsx:1690-1845`): the header's More and
/// New buttons, then the tree (expanded) or the rail chip with its flyout
/// (collapsed).
class WorkflowsSection extends StatefulWidget {
  const WorkflowsSection({
    required this.workspaceId,
    required this.collapsed,
    required this.services,
    required this.operations,
    required this.canEdit,
    required this.canAdmin,
    required this.permissionsLoading,
    super.key,
    this.scrollController,
    this.scrollViewportKey,
    this.presence = const <PresenceUser>[],
    this.sidebarWidth = 224,
  });

  final String workspaceId;
  final bool collapsed;
  final SidebarServices services;
  final TreeOperations operations;
  final bool canEdit;
  final bool canAdmin;
  final bool permissionsLoading;
  final ScrollController? scrollController;
  final GlobalKey? scrollViewportKey;
  final List<PresenceUser> presence;
  final double sidebarWidth;

  @override
  State<WorkflowsSection> createState() => _WorkflowsSectionState();
}

class _WorkflowsSectionState extends State<WorkflowsSection> {
  final HoverMenuController _hover = HoverMenuController();
  final GlobalKey _moreKey = GlobalKey(debugLabel: 'workflows.more');
  String? _flyoutEditingId;
  InlineRenameController? _flyoutRename;
  String? _flyoutActionsId;

  TreeOperations get _ops => widget.operations;
  SidebarServices get _services => widget.services;

  @override
  void dispose() {
    _hover.dispose();
    _flyoutRename?.dispose();
    super.dispose();
  }

  /// `disabled={!permissionsLoading && !canEdit}`.
  bool get _readOnly => !widget.permissionsLoading && !widget.canEdit;

  void _openMoreMenu() {
    final anchor = _moreKey.currentContext;
    if (anchor == null) return;
    final import = _services.onImportWorkflow;
    SimDropdownMenu.show(
      anchor,
      sideOffset: 8,
      minWidth: 160,
      semanticsIdentifier: 'sidebar.workflows.header.menu',
      entries: () => <SimMenuEntry>[
        // The import parser is Phase 2: without it the item stays visible
        // but disabled rather than a silent no-op (known-gaps.md).
        sidebarMenuItem(
          SimEmcnIcons.upload,
          'Import workflow',
          () => import?.call(),
          enabled: widget.canEdit && import != null,
        ),
        sidebarMenuItem(
          SimEmcnIcons.folderPlus,
          _ops.isCreatingFolder.value ? 'Creating folder...' : 'Create folder',
          () => unawaited(_ops.createFolder()),
          enabled: widget.canEdit && !_ops.isCreatingFolder.value,
        ),
      ],
    );
  }

  Widget _actions(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(<Listenable>[
      _ops.isCreatingFolder,
      _ops.isCreatingWorkflow,
    ]),
    builder: (context, _) {
      final creatingWorkflow = _ops.isCreatingWorkflow.value;
      final busy = _ops.isCreatingFolder.value;
      final more = SimTooltip(
        message: 'More actions',
        child: Parity(
          'shell.sidebar.workflows.more',
          child: Parity(
            'sidebar.workflows.header.more',
            child: KeyedSubtree(
              key: _moreKey,
              child: SimButton(
                variant: SimButtonVariant.quiet,
                size: SimButtonSize.icon,
                semanticsLabel: 'More actions',
                enabled: !_readOnly,
                onPressed: _openMoreMenu,
                child: busy
                    ? const SimSpinner(size: 16)
                    : const SimIcon(
                        SimEmcnIcons.moreHorizontal,
                        strokeWidth: 1.25,
                      ),
              ),
            ),
          ),
        ),
      );
      final label = creatingWorkflow ? 'Creating workflow...' : 'New workflow';
      final shortcut = _services.mac ? '⌘⇧P' : 'Ctrl+Shift+P';
      final create = SimTooltip(
        content: creatingWorkflow
            ? const Text('Creating workflow...')
            : SimTooltipShortcut(
                keys: shortcut,
                child: const Text('New workflow'),
              ),
        child: Parity(
          'shell.sidebar.workflows.new',
          child: Parity(
            'sidebar.workflows.header.new',
            child: SimButton(
              variant: SimButtonVariant.quiet,
              size: SimButtonSize.icon,
              semanticsLabel: label,
              enabled: !creatingWorkflow && !_readOnly,
              onPressed: _ops.createWorkflow,
              child: const SimIcon(
                SimEmcnIcons.plus,
                size: 16,
                strokeWidth: 1.25,
              ),
            ),
          ),
        ),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: <Widget>[more, create],
      );
    },
  );

  // Collapsed rail flyout.

  void _startFlyoutRename(WorkflowListItem workflow) {
    _flyoutRename?.dispose();
    setState(() {
      _flyoutEditingId = workflow.id;
      _flyoutRename = InlineRenameController(
        initialName: workflow.name,
        onSave: (name) => _ops.renameWorkflow(workflow.id, name),
        onSavingChanged: (_) => setState(() {}),
        onExit: () {
          if (!mounted) return;
          final done = _flyoutRename;
          setState(() {
            _flyoutEditingId = null;
            _flyoutRename = null;
          });
          _hover.setLocked(locked: false);
          WidgetsBinding.instance.addPostFrameCallback((_) => done?.dispose());
        },
      );
    });
    _hover.setLocked(locked: true);
  }

  void _openFlyoutActions(WorkflowListItem workflow, Offset position) {
    setState(() => _flyoutActionsId = workflow.id);
    _hover.setLocked(locked: true);
    final handle = SimDropdownMenu.showAt(
      context,
      position,
      modal: false,
      entries: () => <SimMenuEntry>[
        sidebarMenuItem(
          SimEmcnIcons.squareArrowUpRight,
          'Open in new tab',
          () => _services.navigator.openInNewTab(
            _ops.workflowHref(workflow.id),
          ),
          enabled: _services.navigator.canOpenInNewTab,
        ),
        sidebarMenuItem(
          SimEmcnIcons.pencil,
          'Rename',
          () => _startFlyoutRename(workflow),
          enabled: widget.canEdit,
        ),
      ],
    );
    unawaited(
      handle.closed.then((_) {
        if (!mounted) return;
        setState(() => _flyoutActionsId = null);
        if (_flyoutEditingId == null) _hover.setLocked(locked: false);
      }),
    );
  }

  SimMenuEntry _flyoutWorkflow(WorkflowListItem workflow) {
    if (workflow.id == _flyoutEditingId && _flyoutRename != null) {
      return SimMenuCustom(
        FlyoutEditRow(
          controller: _flyoutRename!,
          semanticsLabel: 'Workflow name',
        ),
      );
    }
    final active = _ops.activeWorkflowId == workflow.id;
    return SimMenuCustom(
      FlyoutRow(
        label: workflow.name,
        active: active,
        actionOpen: _flyoutActionsId == workflow.id,
        actionLabel: 'Workflow options',
        parityId: 'sidebar.rail.workflows.flyout.workflow.${workflow.id}',
        onPressed: () {
          final href = _ops.workflowHref(workflow.id);
          if (isModifierPressed) {
            _services.navigator.openInNewTab(href);
            return;
          }
          _hover.close();
          _services.navigator.go(href);
        },
        onMiddleTap: () =>
            _services.navigator.openInNewTab(_ops.workflowHref(workflow.id)),
        onSecondaryTapDown: (position) =>
            _openFlyoutActions(workflow, position),
        onAction: (rect) => _openFlyoutActions(workflow, rect.topRight),
      ),
    );
  }

  List<SimMenuEntry> _flyoutLevel(SidebarTree tree, List<TreeEntry> entries) =>
      <SimMenuEntry>[
        for (final entry in entries)
          switch (entry) {
            TreeWorkflowEntry(:final workflow) => _flyoutWorkflow(workflow),
            TreeFolderEntry(:final node) =>
              tree.hasChildren(node.id)
                  ? SimMenuSub(
                      label: node.folder.name,
                      entries: _flyoutLevel(tree, tree.childrenOf(node.id)),
                      semanticsIdentifier:
                          'sidebar.rail.workflows.flyout.folder.${node.id}',
                    )
                  : SimMenuItem(
                      label: node.folder.name,
                      enabled: false,
                      semanticsIdentifier:
                          'sidebar.rail.workflows.flyout.folder.${node.id}',
                    ),
          },
      ];

  List<SimMenuEntry> _flyoutEntries() {
    final workflows = _services.workflows.state;
    final tree = _ops.snapshot();
    final rows = tree.workflows;
    return <SimMenuEntry>[
      sidebarMenuItem(
        SimEmcnIcons.plus,
        'New workflow',
        _ops.createWorkflow,
        semanticsIdentifier: 'sidebar.rail.workflows.flyout.new',
      ),
      const SimMenuSeparator(),
      if (workflows.isLoading && rows.isEmpty)
        ...<SimMenuEntry>[]
      else if (rows.isEmpty)
        const SimMenuItem(label: 'No workflows yet', enabled: false)
      else
        ..._flyoutLevel(tree, tree.rootEntries),
    ];
  }

  Widget _collapsedBody(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Parity(
        'shell.sidebar.rail.workflows',
        child: Parity(
          'sidebar.rail.workflows.chip',
          child: RailFlyout(
            controller: _hover,
            flyoutParityId: 'sidebar.rail.workflows.flyout',
            entries: _flyoutEntries,
            trigger: (context, {required open}) => SidebarChip(
              icon: SimEmcnIcons.workflow,
              width: SimLayout.sidebarRailChip,
              active: open,
              semanticsLabel: 'Workflows',
              onPressed: () => open ? _hover.close() : _hover.open(),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _expandedBody(BuildContext context, WorkflowsState workflows) {
    final rows = workflows.items
        .where((w) => w.workspaceId == widget.workspaceId)
        .toList();
    if (workflows.isLoading && rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          _ops.isCreatingWorkflow,
          _ops.isCreatingFolder,
        ]),
        builder: (context, _) => WorkflowTree(
          workspaceId: widget.workspaceId,
          services: _services,
          operations: _ops,
          canEdit: widget.canEdit,
          canAdmin: widget.canAdmin,
          disableCreate:
              !widget.canEdit ||
              _ops.isCreatingWorkflow.value ||
              _ops.isCreatingFolder.value,
          scrollController: widget.scrollController,
          scrollViewportKey: widget.scrollViewportKey,
          presence: widget.presence,
          sidebarWidth: widget.sidebarWidth,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkflowsCubit, WorkflowsState>(
        bloc: _services.workflows,
        builder: (context, workflows) =>
            BlocBuilder<FoldersCubit, FoldersState>(
              bloc: _services.folders,
              builder: (context, _) => SidebarSection(
                title: 'Workflows',
                railCollapsed: widget.collapsed,
                topGap: SimLayout.sidebarSectionGap,
                parityId: 'shell.sidebar.workflows',
                titleParityId: 'shell.sidebar.workflows.title',
                sectionAliasId: 'sidebar.workflows.section',
                headerParityId: 'sidebar.workflows.header',
                labelParityId: 'sidebar.workflows.header.title',
                action: widget.collapsed ? null : _actions(context),
                child: Parity(
                  'shell.sidebar.workflows.list',
                  child: widget.collapsed
                      ? _collapsedBody(context)
                      : _expandedBody(context, workflows),
                ),
              ),
            ),
      );
}
