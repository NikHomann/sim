import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_design/sim_design.dart';

/// One chip of a [StatusCardPage].
class StatusCardAction {
  const StatusCardAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.parityId,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final String? parityId;
}

/// The centred status composition shared by `WorkspaceAccessDenied`,
/// `OrganizationAccessDenied` (`workspace-access-denied.tsx:143-158`) and
/// the picker's `WorkspaceStatusCard` (`workspace/page.tsx:46-72`):
/// `--surface-1` page with 24px padding filling the viewport, a 448px column
/// gap-3: 40px `--surface-3` disc with an 18px `CircleAlert`, the 18px
/// `--text-primary` title and 14px `--text-muted` body (4px apart), then the
/// chips 8px apart.
class StatusCardPage extends StatelessWidget {
  const StatusCardPage({
    required this.title,
    required this.description,
    required this.actions,
    super.key,
    this.rootId,
    this.iconId,
    this.titleId,
  });

  final String title;
  final String description;
  final List<StatusCardAction> actions;
  final String? rootId;
  final String? iconId;
  final String? titleId;

  Widget _id(String? id, Widget child) => id == null
      ? child
      : Semantics(identifier: id, container: true, child: child);

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final column = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: <Widget>[
          _id(
            iconId,
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface3,
                shape: BoxShape.circle,
              ),
              child: SimIcon(SimIcons.circleAlert, size: 18, color: c.textIcon),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: <Widget>[
              _id(
                titleId,
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: sim.text.lg.copyWith(color: c.textPrimary),
                ),
              ),
              Text(
                description,
                textAlign: TextAlign.center,
                style: sim.text.sm.copyWith(color: c.textMuted),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: <Widget>[
              for (final action in actions)
                _id(
                  action.parityId,
                  SimChip(
                    label: action.label,
                    variant: action.primary
                        ? SimChipVariant.primary
                        : SimChipVariant.base,
                    onPressed: action.onPressed,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    return _id(
      rootId,
      ColoredBox(
        color: c.surface1,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: column),
        ),
      ),
    );
  }
}

/// `WorkspaceAccessDenied` (`shell.access-denied`): replaces the whole
/// shell when the host context answers 403 or the workspace is unknown.
class WorkspaceAccessDenied extends StatelessWidget {
  const WorkspaceAccessDenied({super.key});

  @override
  Widget build(BuildContext context) => StatusCardPage(
    rootId: 'shell.access-denied',
    iconId: 'shell.access-denied.icon',
    titleId: 'shell.access-denied.title',
    title: 'Workspace access denied',
    description:
        'You do not have access to this workspace. Ask a workspace '
        'administrator for access or choose another workspace.',
    actions: <StatusCardAction>[
      StatusCardAction(
        label: 'View your workspaces',
        primary: true,
        parityId: 'shell.access-denied.cta',
        onPressed: () => GoRouter.of(context).go('/workspace'),
      ),
    ],
  );
}

/// `OrganizationAccessDenied`: the same page with the organization copy.
class OrganizationAccessDenied extends StatelessWidget {
  const OrganizationAccessDenied({super.key});

  @override
  Widget build(BuildContext context) => StatusCardPage(
    rootId: 'shell.access-denied',
    iconId: 'shell.access-denied.icon',
    titleId: 'shell.access-denied.title',
    title: 'Organization access denied',
    description:
        'You are not a member of this organization. Ask an organization '
        'admin to add you, or head back to your workspaces.',
    actions: <StatusCardAction>[
      StatusCardAction(
        label: 'View your workspaces',
        primary: true,
        parityId: 'shell.access-denied.cta',
        onPressed: () => GoRouter.of(context).go('/workspace'),
      ),
    ],
  );
}
