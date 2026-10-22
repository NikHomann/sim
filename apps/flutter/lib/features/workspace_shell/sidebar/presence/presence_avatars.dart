import 'package:flutter/widgets.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/user_color.dart';
import 'package:sim_design/sim_design.dart';

/// One collaborator in the open workflow (`usePresenceStore.presenceUsers`,
/// own socket excluded). Presence arrives with the editor's workflow room
/// (Phase 2); until then the sidebar renders an empty stack.
@immutable
class PresenceUser {
  const PresenceUser({
    required this.socketId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
  });

  final String socketId;
  final String userId;
  final String userName;
  final String? avatarUrl;
}

/// `maxVisible = clamp(4 + floor((renderedSidebarWidth − 224) / 20), 4, 12)`
/// (`avatars.tsx:13-17, 38-43`).
int presenceMaxVisible(double sidebarWidth) =>
    (4 + ((sidebarWidth - 224) / 20).floor()).clamp(4, 12);

/// `PresenceAvatars` (`presence-avatars.tsx`): 14px discs overlapping by
/// 4px, visible users reversed so the rightmost stays stable, a `+N` chip
/// for the overflow.
class PresenceAvatars extends StatelessWidget {
  const PresenceAvatars({
    required this.users,
    required this.maxVisible,
    super.key,
  });

  final List<PresenceUser> users;
  final int maxVisible;

  static const double size = 14;
  static const double overlap = 4;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final visible = users.take(maxVisible).toList().reversed.toList();
    final overflow = users.length - visible.length;
    final discs = <Widget>[
      if (overflow > 0)
        SimTooltip(
          message: '$overflow more user${overflow == 1 ? '' : 's'}',
          child: _disc(
            color: SimColors.gray[7], // bg-gray-700
            child: Text(
              '+$overflow',
              style: sim.text.style(7, height: 1, color: SimColors.white),
            ),
            border: c.border,
          ),
        ),
      for (final user in visible)
        SimTooltip(
          message: user.userName,
          child: _disc(
            color: userColor(user.userId, c),
            border: c.border,
            child: Text(
              user.userName.isEmpty ? '?' : user.userName[0].toUpperCase(),
              style: sim.text.style(
                8,
                weight: 600,
                height: 1,
                color: SimColors.white,
              ),
            ),
          ),
        ),
    ];
    final width = size + (discs.length - 1) * (size - overlap);
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: <Widget>[
          for (var i = 0; i < discs.length; i++)
            Positioned(left: i * (size - overlap), top: 0, child: discs[i]),
        ],
      ),
    );
  }

  Widget _disc({
    required Color color,
    required Color border,
    required Widget child,
  }) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: border),
    ),
    child: child,
  );
}
