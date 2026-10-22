/// The sidebar's seams to the other workspace-shell implementers, in one
/// place so each can be switched with a single edit:
///
/// - the workspace switcher chip is the switcher implementer's
///   [WorkspaceSwitcherChip], wired to the shell modals (invite, pending
///   invitations) and the logo upload; a locator without [InvitationsCubit]
///   is a misconfiguration (asserted), except in sidebar widget tests that
///   opt into the resting-chip stub.
/// - the search palette opens through the chrome's
///   [SearchPaletteController] in the locator.
/// - settings navigation goes through the chrome's [SettingsDirtyStore]
///   (`requestLeave`), sign-out through [SessionActions].
/// - the collapse toggle is the chrome's [SidebarChromeScope.onToggle]
///   (or [SidebarServices.onToggleCollapsed] when one is provided).
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/chrome/search_palette_controller.dart';
import 'package:sim_app/features/workspace_shell/chrome/session_actions.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_dirty_store.dart';
import 'package:sim_app/features/workspace_shell/chrome/sidebar_frame.dart';
import 'package:sim_app/features/workspace_shell/modals/invite_modal.dart';
import 'package:sim_app/features/workspace_shell/modals/logo_upload.dart';
import 'package:sim_app/features/workspace_shell/modals/pending_invitations_modal.dart';
import 'package:sim_app/features/workspace_shell/shared/permission_config.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/sidebar/stubs/workspace_switcher_stub.dart';
import 'package:sim_app/features/workspace_shell/switcher/workspace_switcher.dart';

/// The header's switcher slot (`min-w-0 flex-1` wrapper content).
class WorkspaceSwitcherSlot extends StatelessWidget {
  const WorkspaceSwitcherSlot({
    required this.workspaceId,
    required this.collapsed,
    super.key,
  });

  final String workspaceId;
  final bool collapsed;

  /// Sidebar widget tests mount the sidebar without the switcher's cubits
  /// and opt into the resting-chip stub; anything else asserts.
  @visibleForTesting
  static bool debugAllowStub = false;

  @override
  Widget build(BuildContext context) {
    if (!locator.isRegistered<InvitationsCubit>()) {
      assert(
        debugAllowStub,
        'WorkspaceSwitcherSlot needs InvitationsCubit in the locator '
        '(configureLocator); without it the switcher would be a dead stub.',
      );
      return WorkspaceSwitcherChipStub(
        workspaceId: workspaceId,
        collapsed: collapsed,
      );
    }
    final services = resolveSidebarServices(context);
    return ValueListenableBuilder<ShellPermissionConfig>(
      valueListenable: services.permissionConfigs.of(workspaceId),
      builder: (context, config, _) => WorkspaceSwitcherChip(
        workspaceId: workspaceId,
        collapsed: collapsed,
        organizationHref: services.organizationHref,
        navigator: services.navigator,
        onExpandSidebar: sidebarToggle(context, services),
        invitationsDisabledByConfig: config.disableInvitations,
        onInviteTeammates: () => openInviteTeammates(context, workspaceId),
        onViewInvitations: () => unawaited(
          showPendingInvitationsModal(
            context,
            onNavigate: services.navigator.go,
          ),
        ),
        onUploadLogo: (id) => unawaited(uploadWorkspaceLogo(services, id)),
      ),
    );
  }
}

/// "Invite teammates" (`workspace-header.tsx:849-857`): the invite modal
/// for the active workspace, `canInvite = userPermissions.canAdmin`.
void openInviteTeammates(BuildContext context, String workspaceId) {
  final workspaces = locator<WorkspacesCubit>().state;
  final canInvite =
      locator.isRegistered<PermissionsCubit>() &&
      locator<PermissionsCubit>().state.userPermissions.canAdmin;
  unawaited(
    showInviteModal(
      context,
      config: InviteModalConfig.forWorkspace(
        workspaces.byId(workspaceId),
        workspaceId: workspaceId,
        canInvite: canInvite,
      ),
    ),
  );
}

/// "Upload logo" (`useWorkspaceLogoUpload`, `workspace-header.tsx:404-407`):
/// the hidden image picker, then the signed upload and the logo PATCH.
/// Failures are logged, like upstream (no toast).
Future<void> uploadWorkspaceLogo(
  SidebarServices services,
  String workspaceId,
) async {
  final files = await services.browser.pickFiles(
    accept: logoImageTypes.join(','),
  );
  if (files.isEmpty) return;
  final file = files.first;
  final uploader = WorkspaceLogoUploader(
    uploads: UploadSessionClient(locator<SimHttpClient>()),
    workspaces: services.workspaces,
    onError: (message) => developer.log(message, name: 'sim_app.switcher.logo'),
  );
  await uploader.upload(
    workspaceId: workspaceId,
    name: file.name,
    contentType: file.mimeType,
    bytes: file.bytes,
  );
}

/// `useSearchModalStore.open()`.
void openSearchPalette() {
  if (locator.isRegistered<SearchPaletteController>()) {
    locator<SearchPaletteController>().open();
  }
}

/// `useSettingsDirtyStore.getState().requestLeave(leave)`: runs [leave] now
/// when no settings editor is dirty.
void requestLeave(VoidCallback leave) {
  if (locator.isRegistered<SettingsDirtyStore>()) {
    locator<SettingsDirtyStore>().requestLeave(leave);
  } else {
    leave();
  }
}

/// `signOutAndRedirect(router.push)` (`lib/auth/sign-out.ts:8-21`).
Future<void> signOutAndRedirect(SidebarServices services) async {
  const target = '/login?fromLogout=true';
  final custom = services.onSignOut;
  if (custom != null) {
    await custom();
    return;
  }
  if (!locator.isRegistered<SessionActions>()) {
    services.navigator.go(target);
    return;
  }
  final reset = await locator<SessionActions>().signOut();
  final reload = reset ? null : services.navigator.absoluteUrl(target);
  if (reload == null) {
    services.navigator.go(target);
  } else {
    services.browser.assign(reload);
  }
}

/// `onToggle` of the sidebar chrome context (Collapse chip, collapsed
/// expand chip).
VoidCallback? sidebarToggle(BuildContext context, SidebarServices services) =>
    services.onToggleCollapsed ?? SidebarChromeScope.maybeOf(context)?.onToggle;
