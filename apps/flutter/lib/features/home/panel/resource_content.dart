import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/panel/resource_registry.dart';
import 'package:sim_app/features/home/slots.dart';
import 'package:sim_design/sim_design.dart';

/// The panel body for the active resource (`MothershipView` content area,
/// `mothership-view.tsx:307-334`; `ResourceContent`,
/// `resource-content.tsx:315-416`) as far as Phase 1.5 ports it:
///
/// * no active resource: "Click "+" above to add a resource";
/// * `generic`: "No results yet"; `sources`: the cited sources; `folder`:
///   the embedded folder with its workflows (Phase 1 data);
/// * `workflow`, `table`, `file`, `knowledgebase`, `log`, `dashboard`,
///   `test`: a placeholder until their surfaces land (Phases 2 and 4);
/// * `filefolder`, `task`, `integration`: nothing, like upstream;
/// * `search`, `browser`, `terminal`: never reached on web.
class ResourceContentView extends StatelessWidget {
  const ResourceContentView({
    required this.workspaceId,
    required this.resource,
    required this.session,
    required this.onOpenWorkflow,
    super.key,
    this.folders,
    this.workflows,
  });

  final String workspaceId;
  final HomeResource? resource;
  final HomeChatSession session;
  final ValueChanged<String> onOpenWorkflow;
  final FoldersCubit? folders;
  final WorkflowsCubit? workflows;

  @override
  Widget build(BuildContext context) {
    final active = resource;
    final Widget body;
    if (active == null) {
      body = const _PanelEmpty();
    } else {
      body = switch (active.type) {
        HomeResourceType.generic => const _CenteredNote('No results yet'),
        HomeResourceType.sources => _SourcesContent(
          resource: active,
          session: session,
        ),
        HomeResourceType.folder => _EmbeddedFolder(
          folderId: active.id,
          folders: folders,
          workflows: workflows,
          onOpenWorkflow: onOpenWorkflow,
        ),
        HomeResourceType.workflow ||
        HomeResourceType.table ||
        HomeResourceType.file ||
        HomeResourceType.knowledgebase ||
        HomeResourceType.log ||
        HomeResourceType.dashboard ||
        HomeResourceType.test => _LaterPhase(resource: active),
        HomeResourceType.filefolder ||
        HomeResourceType.task ||
        HomeResourceType.integration ||
        HomeResourceType.search ||
        HomeResourceType.browser ||
        HomeResourceType.terminal => const SizedBox.shrink(),
      };
    }
    return Semantics(
      identifier: 'home.panel.content',
      container: true,
      child: ClipRect(child: body),
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty();

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    return Center(
      child: Semantics(
        identifier: 'home.panel.empty',
        container: true,
        child: Text(
          'Click "+" above to add a resource',
          style: sim.text.sm.copyWith(color: sim.colors.textMuted),
        ),
      ),
    );
  }
}

class _CenteredNote extends StatelessWidget {
  const _CenteredNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    return Center(
      child: Text(
        text,
        style: sim.text.small.copyWith(color: sim.colors.textMuted),
      ),
    );
  }
}

/// A resource type whose surface ships in a later phase: its title over a
/// note, in the empty-panel style.
class _LaterPhase extends StatelessWidget {
  const _LaterPhase({required this.resource});

  final HomeResource resource;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final title = resource.title.trim().isEmpty
        ? resourceConfig(resource.type).label
        : resource.title.trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: sim.text.sm.copyWith(color: c.textPrimary),
            ),
            Text(
              'Available in a later phase',
              textAlign: TextAlign.center,
              style: sim.text.sm.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// `SourcesResourceContent`.
class _SourcesContent extends StatelessWidget {
  const _SourcesContent({required this.resource, required this.session});

  final HomeResource resource;
  final HomeChatSession session;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final messageId = resource.sourcesMessageId;
    final result = messageId == null
        ? const HomeCitedSources()
        : session.citedSources(messageId, resource.sourcesRequestId);
    final sources = result.sources;
    return SimScrollFade(
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text.rich(
              TextSpan(
                text: 'Sources',
                style: sim.text.small.copyWith(color: c.textBody),
                children: <InlineSpan>[
                  if (sources.isNotEmpty)
                    TextSpan(
                      text: ' · ${sources.length}',
                      style: TextStyle(color: c.textMuted),
                    ),
                ],
              ),
            ),
          ),
          if (sources.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                result.loading
                    ? 'Loading sources'
                    : result.failed
                    ? 'Unable to load sources. Try reopening this conversation.'
                    : 'No cited sources are available for this response.',
                style: sim.text.small.copyWith(color: c.textMuted),
              ),
            )
          else
            for (final source in sources) _SourceRow(source: source),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final HomeSource source;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final host = Uri.tryParse(source.url)?.host ?? source.url;
    return SimPressable(
      builder: (context, state) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: state.hovered ? c.surfaceHover : const Color(0x00000000),
          borderRadius: BorderRadius.circular(SimRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SimOverflowText(
              label: source.title ?? source.url,
              style: sim.text.small.copyWith(color: c.textPrimary),
            ),
            Text(
              source.siteName ?? host,
              style: sim.text.caption.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// `EmbeddedFolder` (`resource-content.tsx:1027-1078`).
class _EmbeddedFolder extends StatelessWidget {
  const _EmbeddedFolder({
    required this.folderId,
    required this.folders,
    required this.workflows,
    required this.onOpenWorkflow,
  });

  final String folderId;
  final FoldersCubit? folders;
  final WorkflowsCubit? workflows;
  final ValueChanged<String> onOpenWorkflow;

  @override
  Widget build(BuildContext context) {
    final foldersCubit = folders;
    if (foldersCubit == null) return const _FolderNotFound();
    return BlocBuilder<FoldersCubit, FoldersState>(
      bloc: foldersCubit,
      builder: (context, folderState) {
        if (folderState.isLoading ||
            folderState.folders.status == LoadStatus.idle) {
          return const _LoadingSkeleton();
        }
        final folder = folderState.byId[folderId];
        if (folder == null) return const _FolderNotFound();
        final workflowsCubit = workflows;
        if (workflowsCubit == null) {
          return _FolderBody(
            folder: folder,
            workflows: const <WorkflowListItem>[],
            onOpenWorkflow: onOpenWorkflow,
          );
        }
        return BlocBuilder<WorkflowsCubit, WorkflowsState>(
          bloc: workflowsCubit,
          builder: (context, workflowState) => _FolderBody(
            folder: folder,
            workflows: <WorkflowListItem>[
              for (final w in workflowState.items)
                if (w.folderId == folderId) w,
            ],
            onOpenWorkflow: onOpenWorkflow,
          ),
        );
      },
    );
  }
}

class _FolderBody extends StatelessWidget {
  const _FolderBody({
    required this.folder,
    required this.workflows,
    required this.onOpenWorkflow,
  });

  final Folder folder;
  final List<WorkflowListItem> workflows;
  final ValueChanged<String> onOpenWorkflow;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            folder.name,
            style: sim.text.md.copyWith(color: c.textPrimary),
          ),
        ),
        if (workflows.isEmpty)
          Text(
            'No workflows in this folder',
            style: sim.text.small.copyWith(color: c.textMuted),
          )
        else
          for (final w in workflows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SimPressable(
                onPressed: () => onOpenWorkflow(w.id),
                semanticsLabel: w.name,
                builder: (context, state) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: state.hovered ? c.surface4 : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    spacing: 8,
                    children: <Widget>[
                      SimIcon(SimEmcnIcons.workflow, color: c.textIcon),
                      Expanded(
                        child: SimOverflowText(
                          label: w.name,
                          style: sim.text.small.copyWith(
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _FolderNotFound extends StatelessWidget {
  const _FolderNotFound();

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: <Widget>[
          SimIcon(SimEmcnIcons.folder, size: 32, color: c.textIcon),
          Column(
            spacing: 4,
            children: <Widget>[
              Text(
                'Folder not found',
                style: sim.text.style(20, color: c.textPrimary),
              ),
              Text(
                'This folder may have been deleted or moved',
                style: sim.text.small.copyWith(color: c.textBody),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `LOADING_SKELETON` (`resource-content.tsx:98-104`).
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth - 48;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: <Widget>[
            SimSkeleton(width: w * 0.6, height: 16),
            SimSkeleton(width: w * 0.8, height: 16),
            SimSkeleton(width: w * 0.4, height: 16),
          ],
        ),
      );
    },
  );
}
