import 'package:sim_app/features/auth/shared/auth_api.dart';

/// A pending invitation with one `write` grant per name.
InviteDetails invitation({
  String kind = 'workspace',
  String email = 'ada@example.com',
  String intent = 'internal',
  List<String?> names = const ['Design'],
  String? org,
}) => InviteDetails(
  id: 'inv-1',
  kind: kind,
  email: email,
  organizationName: org,
  membershipIntent: intent,
  role: 'member',
  grants: [
    for (final (i, name) in names.indexed)
      InviteGrant(
        workspaceId: 'ws-$i',
        workspaceName: name,
        workspaceLogoUrl: null,
        permission: 'write',
      ),
  ],
);

/// A `will-join` preview moving one personal workspace.
const InviteJoinPreview preview = InviteJoinPreview(
  outcome: 'will-join',
  organizationName: 'Acme',
  workspacesToMove: ['Personal'],
  workspaceIdsToMove: ['ws-p'],
);
