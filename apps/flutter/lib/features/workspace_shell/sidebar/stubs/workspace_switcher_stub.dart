import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/sidebar/seams.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/switcher/identity_tile.dart';
import 'package:sim_design/sim_design.dart';

/// Stand-in for `WorkspaceSwitcherChip` where the app locator is not
/// configured (widget tests and goldens; see `../seams.dart`): the
/// switcher's resting chip without its dropdown — tile + name + chevron
/// expanded, the 32px expand chip collapsed (`workspace-header.tsx:449-520`).
class WorkspaceSwitcherChipStub extends StatelessWidget {
  const WorkspaceSwitcherChipStub({
    required this.workspaceId,
    required this.collapsed,
    super.key,
  });

  final String workspaceId;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final services = resolveSidebarServices(context);
    return BlocBuilder<WorkspacesCubit, WorkspacesState>(
      bloc: services.workspaces,
      builder: (context, state) {
        Workspace? current;
        for (final w in state.workspaces) {
          if (w.id == workspaceId) current = w;
        }
        final tile = IdentityTile(
          name: current?.name,
          logoUrl: current?.logoUrl,
        );
        if (collapsed) {
          return Parity(
            'shell.sidebar.header.workspace',
            child: SizedBox(
              width: SimLayout.sidebarRailChip,
              child: SimChip(
                fullWidth: true,
                semanticsLabel: 'Expand sidebar',
                leftAdornment: SizedBox.square(dimension: 16, child: tile),
                onPressed: sidebarToggle(context, services),
              ),
            ),
          );
        }
        return Parity(
          'shell.sidebar.header.workspace',
          child: SimChip(
            label: current?.name ?? '',
            leftAdornment: tile,
            rightAdornment: const SizedBox.square(
              dimension: 16,
              child: Center(child: SimIcon(SimEmcnIcons.chevronDown)),
            ),
            onPressed: () {},
          ),
        );
      },
    );
  }
}
