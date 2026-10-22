// Failure modes of WorkspacesRepository against a dart:io fake server
// (spec §4.3, §10 #27-29, #34, #36-37, #40):
// 1. `list()` sends `?scope=active`; `listDefault()` sends no scope at all;
// 2. a 401 on the list stays an ApiClientError (the picker's stale-session
//    signal), as does a 404 on permissions (the context's error string);
// 3. `update` trims the name, sends `logoUrl: null` only with `clearLogo`,
//    and omits every untouched field; `delete` sends the empty `{}` body;
// 4. `create` on a capability refusal surfaces the 403 with its body; a 409
//    membership race is a 409;
// 5. `updatePermissions` serialises `{updates:[{userId, permissions}]}` and
//    a validation failure keeps `details[]`;
// 6. `recordVisit` is a POST with no body and a `{success:true}` response;
//    `{success:false}` is a contract failure.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import '../contracts/fixtures.dart';
import '../support/fake_server.dart';

void main() {
  late FakeServer server;
  late WorkspacesRepository repo;

  setUp(() async {
    server = await FakeServer.start();
    repo = WorkspacesRepository(SimHttpClient(baseUrl: server.url));
  });

  tearDown(() => server.close());

  test('list sends scope=active; listDefault sends no scope', () async {
    server.handler = (request, body) =>
        FakeServer.json(request, 200, liveWorkspaceListJson());
    await repo.list();
    await repo.listDefault();
    expect(server.requests[0].query, {'scope': 'active'});
    expect(server.requests[1].query, isEmpty);
    expect(server.requests[1].path, '/api/workspaces');
  });

  test('401 on the list and 404 on permissions stay ApiClientError', () async {
    server.handler = (request, body) =>
        FakeServer.json(request, 401, {'error': 'Unauthorized'});
    await expectLater(
      repo.list(),
      throwsA(
        isA<ApiClientError>().having((e) => e.isUnauthorized, '401', true),
      ),
    );
    server.handler = (request, body) =>
        FakeServer.json(request, 404, {'error': 'Workspace not found'});
    await expectLater(
      repo.permissions('ws'),
      throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 404)),
    );
  });

  test('update body: trimmed name, logoUrl null only with clearLogo', () async {
    server.handler = (request, body) =>
        FakeServer.json(request, 200, {'workspace': liveWorkspaceJson()});
    await repo.update(workspaceId, name: '  Renamed ');
    await repo.update(workspaceId, clearLogo: true);
    await repo.update(workspaceId, logoUrl: '/uploads/logo.png');
    expect(server.requests[0].method, 'PATCH');
    expect(server.requests[0].path, '/api/workspaces/$workspaceId');
    expect(server.requests[0].json, {'name': 'Renamed'});
    expect(server.requests[1].json, {'logoUrl': null});
    expect(server.requests[2].json, {'logoUrl': '/uploads/logo.png'});
  });

  test('delete sends the empty body and reads success', () async {
    server.handler = (request, body) =>
        FakeServer.json(request, 200, {'success': true});
    await repo.delete(workspaceId);
    expect(server.requests.single.method, 'DELETE');
    expect(server.requests.single.json, <String, Object?>{});
    expect(server.requests.single.headers['content-type'], 'application/json');
  });

  test(
    'create: 403 capability refusal and 409 race keep their bodies',
    () async {
      server.handler = (request, body) => FakeServer.json(request, 403, {
        'error': 'Workspace creation is not allowed',
        'details': {'code': 'PERMISSION_GROUP_CAPABILITY_BLOCKED'},
      });
      await expectLater(
        repo.create(name: ' New '),
        throwsA(
          isA<ApiClientError>()
              .having((e) => e.status, 'status', 403)
              .having(
                (e) => e.message,
                'message',
                'Workspace creation is not allowed',
              )
              .having(
                (e) => (e.body! as Map)['details'],
                'details',
                {'code': 'PERMISSION_GROUP_CAPABILITY_BLOCKED'},
              ),
        ),
      );
      expect(server.requests.single.json, {'name': 'New'});
      server.handler = (request, body) =>
          FakeServer.json(request, 409, {'error': 'Conflict'});
      await expectLater(
        repo.create(name: 'New'),
        throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 409)),
      );
    },
  );

  test('updatePermissions body and validation details', () async {
    server.handler = (request, body) =>
        FakeServer.json(request, 200, {'message': 'ok'});
    final message = await repo.updatePermissions(
      workspaceId,
      updates: const [
        PermissionUpdate(userId: 'u1', permissions: WorkspacePermission.write),
      ],
    );
    expect(message, 'ok');
    expect(server.requests.single.json, {
      'updates': [
        {'userId': 'u1', 'permissions': 'write'},
      ],
    });
    server.handler = (request, body) => FakeServer.json(request, 400, {
      'error': 'Invalid request',
      'details': [
        {
          'path': ['updates', 0, 'permissions'],
          'message': 'Invalid enum value',
        },
      ],
    });
    await expectLater(
      repo.updatePermissions(
        workspaceId,
        updates: const [
          PermissionUpdate(userId: 'u1', permissions: WorkspacePermission.read),
        ],
      ),
      throwsA(
        isA<ApiClientError>().having(
          (e) => e.findIssue(['permissions'])?.message,
          'first issue',
          'Invalid enum value',
        ),
      ),
    );
  });

  test(
    'recordVisit posts without a body; success:false is a failure',
    () async {
      server.handler = (request, body) =>
          FakeServer.json(request, 200, {'success': true});
      await repo.recordVisit(workspaceId);
      expect(server.requests.single.method, 'POST');
      expect(server.requests.single.path, '/api/workspaces/$workspaceId/visit');
      expect(server.requests.single.body, isEmpty);
      server.handler = (request, body) =>
          FakeServer.json(request, 200, {'success': false});
      await expectLater(
        repo.recordVisit(workspaceId),
        throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 200)),
      );
    },
  );
}
