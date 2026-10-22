// Failure modes of PinnedItemsRepository and InvitationsRepository against
// a dart:io fake server (spec §4.4, §4.7, §9, §10 #31, #42-49, #63-64):
// 1. the pinned list sends `resourceType` only when given; pin posts the
//    three fields; unpin fills both path params;
// 2. `toggleWorkspacePin`: 409 on pin and 404 on unpin resolve (already in
//    the end state); 404 on pin, 409 on unpin and 500 rethrow;
// 3. accept maps the route's error kinds: `{error:'disclosure-outdated'}`
//    409, `upgrade-required` 402, `email-mismatch` 403, an unknown body with
//    404 → `invalid-invitation`, 409 → `already-in-organization`, 500 →
//    `server-error`; the typed error is still an ApiClientError;
// 4. accept echoes `disclosedWorkspaceIds` and `disclosedOutcome`; reject
//    sends `{}` without a token;
// 5. a batch send with `failed[]` on a 2xx is returned as a partial failure,
//    not thrown; trimmed emails go out;
// 6. `listWorkspace` keeps only pending rows of that workspace;
// 7. `removeMember` fills the path with the user id and the body with the
//    workspace id; `cancel` sends `?workspaceId=`.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import '../contracts/fixtures.dart';
import '../support/fake_server.dart';

void main() {
  late FakeServer server;
  late PinnedItemsRepository pins;
  late InvitationsRepository invitations;

  setUp(() async {
    server = await FakeServer.start();
    final http = SimHttpClient(baseUrl: server.url);
    pins = PinnedItemsRepository(http);
    invitations = InvitationsRepository(http);
  });

  tearDown(() => server.close());

  group('pinned items', () {
    test('list query, pin body, unpin path', () async {
      server.handler = (request, body) => switch (request.method) {
        'GET' => FakeServer.json(request, 200, {'pinnedItems': <Object>[]}),
        'POST' => FakeServer.json(request, 200, {
          'pinnedItem': {
            'id': 'p1',
            'userId': userId,
            'workspaceId': workspaceId,
            'resourceType': 'workflow',
            'resourceId': workflowId,
            'pinnedAt': '2026-10-21T10:00:00.000Z',
          },
        }),
        _ => FakeServer.json(request, 200, {'success': true}),
      };
      await pins.list(workspaceId: workspaceId);
      await pins.list(
        workspaceId: workspaceId,
        resourceType: PinnedResourceType.knowledgeBase,
      );
      final pinned = await pins.pin(
        workspaceId: workspaceId,
        resourceType: PinnedResourceType.workflow,
        resourceId: workflowId,
      );
      await pins.unpin(
        resourceType: PinnedResourceType.folder,
        resourceId: folderId,
      );
      expect(server.requests[0].query, {'workspaceId': workspaceId});
      expect(server.requests[1].query, {
        'workspaceId': workspaceId,
        'resourceType': 'knowledge_base',
      });
      expect(server.requests[2].json, {
        'workspaceId': workspaceId,
        'resourceType': 'workflow',
        'resourceId': workflowId,
      });
      expect(pinned.resourceType, PinnedResourceType.workflow);
      expect(server.requests[3].path, '/api/pinned-items/folder/$folderId');
    });

    test(
      'workspace pin toggle: 409/404 are the end state, others throw',
      () async {
        server.handler = (request, body) => FakeServer.json(request, 409, {
          'error': 'This item is already pinned',
        });
        expect(
          await pins.toggleWorkspacePin(workspaceId: workspaceId, pinned: true),
          isTrue,
        );
        expect(server.requests.single.json, {
          'workspaceId': workspaceId,
          'resourceType': 'workspace',
          'resourceId': workspaceId,
        });
        server.handler = (request, body) =>
            FakeServer.json(request, 404, {'error': 'Not pinned'});
        expect(
          await pins.toggleWorkspacePin(
            workspaceId: workspaceId,
            pinned: false,
          ),
          isTrue,
        );
        await expectLater(
          pins.toggleWorkspacePin(workspaceId: workspaceId, pinned: true),
          throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 404)),
        );
        server.handler = (request, body) =>
            FakeServer.json(request, 500, {'error': 'boom'});
        await expectLater(
          pins.toggleWorkspacePin(workspaceId: workspaceId, pinned: false),
          throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 500)),
        );
      },
    );
  });

  group('invitations', () {
    test('accept maps error kinds and statuses', () async {
      final cases = <(int, Map<String, Object?>, InvitationErrorCode)>[
        (
          409,
          {'error': 'disclosure-outdated'},
          InvitationErrorCode.disclosureOutdated,
        ),
        (
          402,
          {'error': 'upgrade-required', 'message': 'Upgrade'},
          InvitationErrorCode.upgradeRequired,
        ),
        (403, {'error': 'email-mismatch'}, InvitationErrorCode.emailMismatch),
        (
          404,
          {'error': 'Something else'},
          InvitationErrorCode.invalidInvitation,
        ),
        (409, {'error': 'Conflict'}, InvitationErrorCode.alreadyInOrganization),
        (
          500,
          {'error': 'server-error', 'message': 'db down'},
          InvitationErrorCode.serverError,
        ),
        (503, {'error': 'unavailable'}, InvitationErrorCode.serverError),
        (
          400,
          {'code': 'expired', 'message': 'Expired'},
          InvitationErrorCode.expired,
        ),
      ];
      for (final (status, body, kind) in cases) {
        server.handler = (request, _) => FakeServer.json(request, status, body);
        await expectLater(
          invitations.accept('inv-1'),
          throwsA(
            isA<InvitationError>()
                .having((e) => e.kind, 'kind', kind)
                .having((e) => e.status, 'status', status),
          ),
          reason: '$status $body',
        );
      }
      expect(InvitationErrorCode.upgradeRequired.canRetry, isTrue);
      expect(InvitationErrorCode.emailMismatch.requiresAuth, isTrue);
      expect(InvitationErrorCode.expired.canRetry, isFalse);
    });

    test('accept echoes the disclosure; reject sends {}', () async {
      server.handler = (request, body) => switch (request.uri.path) {
        '/api/invitations/inv-1/accept' => FakeServer.json(request, 200, {
          'success': true,
          'redirectPath': '/workspace/$workspaceId',
          'invitation': {
            'id': 'inv-1',
            'kind': 'workspace',
            'organizationId': null,
            'acceptedWorkspaceIds': [workspaceId],
          },
        }),
        _ => FakeServer.json(request, 200, {'success': true}),
      };
      final accepted = await invitations.accept(
        'inv-1',
        token: 't',
        disclosedWorkspaceIds: const ['w1'],
        disclosedOutcome: JoinOutcome.willJoin,
      );
      await invitations.reject('inv-1');
      expect(accepted.redirectPath, '/workspace/$workspaceId');
      expect(accepted.acceptedWorkspaceIds, [workspaceId]);
      expect(server.requests[0].json, {
        'token': 't',
        'disclosedWorkspaceIds': ['w1'],
        'disclosedOutcome': 'will-join',
      });
      expect(server.requests[1].json, <String, Object?>{});
    });

    test(
      'details 404 becomes invalid-invitation with the token query',
      () async {
        server.handler = (request, body) =>
            FakeServer.json(request, 404, {'error': 'Invitation not found'});
        await expectLater(
          invitations.details('inv-1', token: 'tok'),
          throwsA(
            isA<InvitationError>().having(
              (e) => e.kind,
              'kind',
              InvitationErrorCode.invalidInvitation,
            ),
          ),
        );
        expect(server.requests.single.query, {'token': 'tok'});
        server.handler = (request, body) =>
            FakeServer.json(request, 200, invitationDetailsJson());
        final details = await invitations.details('inv-1');
        expect(details.joinPreview?.outcome, JoinOutcome.willJoin);
        expect(
          details.invitation.grants.single.permission,
          WorkspacePermission.write,
        );
      },
    );

    test('batch send: partial failure on 2xx is returned', () async {
      server.handler = (request, body) => FakeServer.json(request, 200, {
        'success': true,
        'successful': ['ok@example.com'],
        'added': <String>[],
        'failed': [
          {'email': 'bad@example.com', 'error': 'Already a member'},
        ],
        'invitations': [
          {
            'id': 'inv-2',
            'email': 'ok@example.com',
            'workspaceIds': [workspaceId],
            'permission': 'read',
            'membershipIntent': 'internal',
          },
        ],
      });
      final result = await invitations.sendBatch(
        workspaceIds: [workspaceId],
        emails: const [' ok@example.com ', 'bad@example.com'],
        permission: WorkspacePermission.read,
        membership: InvitationMembership.member,
      );
      expect(result.isPartialFailure, isTrue);
      expect(result.failed.single.error, 'Already a member');
      expect(server.requests.single.json, {
        'workspaceIds': [workspaceId],
        'emails': ['ok@example.com', 'bad@example.com'],
        'permission': 'read',
        'membership': 'member',
      });
    });

    test('listWorkspace filters pending rows of the workspace', () async {
      server.handler = (request, body) => FakeServer.json(request, 200, {
        'invitations': [
          {
            'id': 'a',
            'workspaceId': workspaceId,
            'email': 'a@x.y',
            'permission': 'read',
            'status': 'pending',
            'createdAt': 'now',
          },
          {
            'id': 'b',
            'workspaceId': 'other',
            'email': 'b@x.y',
            'permission': 'read',
            'status': 'pending',
            'createdAt': 'now',
          },
          {
            'id': 'c',
            'workspaceId': workspaceId,
            'email': 'c@x.y',
            'permission': 'read',
            'status': 'accepted',
            'createdAt': 'now',
          },
        ],
      });
      final rows = await invitations.listWorkspace(workspaceId);
      expect(rows.map((r) => r.id), ['a']);
    });

    test('removeMember and cancel wire shapes', () async {
      server.handler = (request, body) => switch (request.method) {
        'DELETE' when request.uri.path.startsWith('/api/invitations/') =>
          FakeServer.json(request, 200, {
            'success': true,
            'invitationCancelled': true,
          }),
        _ => FakeServer.json(request, 200, {'success': true}),
      };
      await invitations.removeMember(userId: 'u1', workspaceId: workspaceId);
      final cancelled = await invitations.cancel(
        'inv-1',
        workspaceId: workspaceId,
      );
      expect(server.requests[0].path, '/api/workspaces/members/u1');
      expect(server.requests[0].json, {'workspaceId': workspaceId});
      expect(server.requests[1].query, {'workspaceId': workspaceId});
      expect(cancelled.invitationCancelled, isTrue);
    });
  });
}
