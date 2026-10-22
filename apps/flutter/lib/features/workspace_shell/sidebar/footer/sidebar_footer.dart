import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/data/data.dart';
import 'package:sim_app/features/workspace_shell/shared/backend_image.dart';
import 'package:sim_app/features/workspace_shell/sidebar/footer/slack_icon.dart';
import 'package:sim_app/features/workspace_shell/sidebar/seams.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/context_menu.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/parity.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/sidebar_chip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/sidebar_tooltip.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/user_color.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_design/sim_design.dart';

/// `DOCS_URL` (`lib/help-links.ts`).
const String docsUrl = 'https://docs.sim.ai';

/// `SLACK_COMMUNITY_URL` (`lib/help-links.ts`).
const String slackCommunityUrl =
    'https://join.slack.com/t/sim-ott9864/shared_invite/zt-43lp8tc5v-0qrrqHGBKUsvQlpoouH~TA';

/// One profile-menu link (`profileNavigationLinks`).
@immutable
class ProfileMenuLink {
  const ProfileMenuLink({
    required this.label,
    required this.icon,
    required this.href,
  });

  final String label;
  final SimIconData icon;
  final String href;
}

/// `ANONYMOUS_USER_ID` (`@sim/auth/principal`): the auth-disabled
/// principal, which gets no "Sign out".
const String anonymousUserId = '00000000-0000-0000-0000-000000000000';

/// The profile menu's links in the settings registry order
/// (`components/settings/navigation.ts:448, 474, 665`): Settings (general),
/// Subscription (only when billing settings are reachable), Teammates,
/// Recently deleted, Organization (only with an organization href). Sign
/// out follows for a signed-in, non-anonymous user.
List<ProfileMenuLink> profileMenuLinks({
  required String workspaceId,
  required bool canViewBilling,
  String? organizationHref,
}) {
  String settings(String section) =>
      '/workspace/$workspaceId/settings/$section';
  return <ProfileMenuLink>[
    ProfileMenuLink(
      label: 'Settings',
      icon: SimEmcnIcons.settings,
      href: settings('general'),
    ),
    if (canViewBilling)
      ProfileMenuLink(
        label: 'Subscription',
        icon: SimEmcnIcons.credit,
        href: settings('billing'),
      ),
    ProfileMenuLink(
      label: 'Teammates',
      icon: SimEmcnIcons.users,
      href: settings('teammates'),
    ),
    ProfileMenuLink(
      label: 'Recently deleted',
      icon: SimEmcnIcons.trash,
      href: settings('recently-deleted'),
    ),
    if (organizationHref != null)
      ProfileMenuLink(
        label: 'Organization',
        icon: SimEmcnIcons.building,
        href: organizationHref,
      ),
  ];
}

/// `SidebarFooter`: the profile chip and the Help chip. Expanded they share
/// one row (profile hugging its content on the left, help hard right);
/// collapsed they stack as 32px rail chips, help above profile. The top
/// rule shows only while the scroll region hides rows below
/// ([showDivider]).
class SidebarFooter extends StatelessWidget {
  const SidebarFooter({
    required this.workspaceId,
    required this.collapsed,
    required this.showDivider,
    required this.services,
    required this.onContactSupport,
    super.key,
  });

  final String workspaceId;
  final bool collapsed;
  final bool showDivider;
  final SidebarServices services;
  final VoidCallback onContactSupport;

  bool _canViewBilling(SessionState session) {
    final host = services.host?.state.context;
    final user = session.user;
    if (host == null || user == null) return false;
    return host.canViewBillingSettings(
      viewerId: user.id,
      shape: services.deploymentShape.state.shape,
    );
  }

  void _openProfileMenu(BuildContext anchor, SessionState session) {
    final links = profileMenuLinks(
      workspaceId: workspaceId,
      canViewBilling: _canViewBilling(session),
      organizationHref: services.organizationHref,
    );
    SimDropdownMenu.show(
      anchor,
      side: SimSide.top,
      sideOffset: 4,
      semanticsIdentifier: 'shell.sidebar.footer.profile.menu',
      entries: () => <SimMenuEntry>[
        for (final link in links)
          sidebarMenuItem(
            link.icon,
            link.label,
            () => services.navigator.go(link.href),
          ),
        if (session.user != null && session.user?.id != anonymousUserId)
          sidebarMenuItem(
            SimEmcnIcons.logOut,
            'Sign out',
            () => requestLeave(() => signOutAndRedirect(services)),
          ),
      ],
    );
  }

  void _openHelpMenu(BuildContext anchor) => SimDropdownMenu.show(
    anchor,
    side: SimSide.top,
    align: collapsed ? SimAlign.start : SimAlign.end,
    sideOffset: 4,
    semanticsIdentifier: 'shell.sidebar.footer.help.menu',
    entries: () => <SimMenuEntry>[
      sidebarMenuItem(
        SimEmcnIcons.bookOpen,
        'Docs',
        () => services.navigator.openExternal(docsUrl),
      ),
      SimMenuItem(
        label: 'Join Slack',
        leading: const SlackIcon(),
        onSelect: () => services.navigator.openExternal(slackCommunityUrl),
      ),
      sidebarMenuItem(
        SimEmcnIcons.helpCircle,
        'Contact support',
        onContactSupport,
      ),
    ],
  );

  Widget _avatar(BuildContext context, SessionState session) {
    final sim = SimTheme.of(context);
    final user = session.user;
    if (user == null) {
      return const SimSkeleton(width: 16, height: 16, radius: SimRadii.full);
    }
    final image = user.image;
    if (image != null && image.isNotEmpty) {
      return ClipOval(
        child: BackendImage(
          url: image,
          size: 16,
          fallback: const SizedBox.square(dimension: 16),
        ),
      );
    }
    final name = _name(session);
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: userColor(user.id, sim.colors),
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? '' : name[0].toUpperCase(),
        style: sim.text.style(9, height: 1, color: SimColors.white),
      ),
    );
  }

  /// `profile.name?.trim() || profile.email`.
  static String _name(SessionState session) {
    final user = session.user;
    if (user == null) return '';
    final name = user.name?.trim() ?? '';
    return name.isNotEmpty ? name : user.email;
  }

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    return BlocBuilder<SessionCubit, SessionState>(
      bloc: services.session,
      builder: (context, session) {
        final name = _name(session);
        final profile = Parity(
          'shell.sidebar.footer.profile',
          child: SidebarTooltip(
            label: name,
            enabled: collapsed,
            child: Builder(
              builder: (anchor) => SidebarChip(
                leading: _avatar(context, session),
                hug: !collapsed,
                width: collapsed ? SimLayout.sidebarRailChip : null,
                semanticsLabel: name.isEmpty ? 'Account' : name,
                content: collapsed
                    ? null
                    : session.user == null
                    ? const SimSkeleton(width: 96, height: 14, radius: 4)
                    : null,
                label: collapsed || session.user == null ? null : name,
                onPressed: () => _openProfileMenu(anchor, session),
              ),
            ),
          ),
        );
        final help = Parity(
          'shell.sidebar.footer.help',
          child: SidebarTooltip(
            label: 'Help',
            enabled: collapsed,
            child: Builder(
              builder: (anchor) => SidebarIconChip(
                icon: SimEmcnIcons.helpCircle,
                semanticsLabel: 'Help',
                onPressed: () => _openHelpMenu(anchor),
              ),
            ),
          ),
        );
        final Widget body = collapsed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: SimLayout.sidebarItemGap,
                children: <Widget>[help, profile],
              )
            : Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: profile,
                    ),
                  ),
                  help,
                ],
              );
        return Parity(
          'shell.sidebar.footer',
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: showDivider ? c.border : const Color(0x00000000),
                ),
              ),
            ),
            child: body,
          ),
        );
      },
    );
  }
}
