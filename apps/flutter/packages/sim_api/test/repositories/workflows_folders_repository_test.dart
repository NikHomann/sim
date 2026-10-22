// Failure modes of WorkflowsRepository and FoldersRepository against a
// dart:io fake server (spec §4.5, §4.6, §10 #50-62):
// 1. the workflow list sends `?workspaceId&scope=active` and reads `data`;
// 2. create sends the client id, `deduplicate`, and `folderId: null` only
//    when the caller moves the row to the root; the response's
//    `subBlockValues` and `startBlockId` are decoded;
// 3. `WorkflowUpdate` omits every untouched field and sends `folderId: null`
//    only with `clearFolder`; reorder sends `{workspaceId, updates}` with
//    `folderId` per update only when it moves;
// 4. a 403 on a read-only workspace stays an ApiClientError;
// 5. the folder list sends `scope` and `resourceType`; delete and update
//    send `?resourceType=`; restore sends `{workspaceId, resourceType}`;
// 6. duplicate sends `parentId` (also `null`) only when asked;
// 7. `nextFolderName` is one past the highest "Folder N" among root
//    folders, ignoring nested and non-matching names; `generateName`
//    requests `?workspaceId` alone.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import '../contracts/fixtures.dart';
import '../support/fake_server.dart';

void main() {
  late FakeServer server;
  late WorkflowsRepository workflows;
  late FoldersRepository folders;

  setUp(() async {
    server = await FakeServer.start();
    final http = SimHttpClient(baseUrl: server.url);
    workflows = WorkflowsRepository(http);
    folders = FoldersRepository(http);
  });

  tearDown(() => server.close());

  group('workflows', () {
    test('list query and data envelope', () async {
      server.handler = (request, body) => FakeServer.json(request, 200, {
        'data': [liveWorkflowJson()],
      });
      final rows = await workflows.list(workspaceId: workspaceId);
      expect(rows.single.id, workflowId);
      expect(server.requests.single.query, {
        'workspaceId': workspaceId,
        'scope': 'active',
      });
    });

    test('create body and response decoding', () async {
      server.handler = (request, body) => FakeServer.json(request, 200, {
        'id': 'wf-new',
        'name': 'bolt-ivy',
        'description': '',
        'workspaceId': workspaceId,
        'folderId': null,
        'sortOrder': -1,
        'createdAt': '2026-10-21T10:00:00.000Z',
        'updatedAt': '2026-10-21T10:00:00.000Z',
        'startBlockId': 'start-1',
        'subBlockValues': {
          'start-1': {'input': 'x'},
        },
      });
      final created = await workflows.create(
        id: 'wf-new',
        name: 'bolt-ivy',
        workspaceId: workspaceId,
        sendFolder: true,
        sortOrder: -1,
        deduplicate: true,
      );
      expect(created.startBlockId, 'start-1');
      expect(created.subBlockValues['start-1'], {'input': 'x'});
      expect(created.toListItem().sortOrder, -1);
      expect(server.requests.single.json, {
        'id': 'wf-new',
        'name': 'bolt-ivy',
        'workspaceId': workspaceId,
        'folderId': null,
        'sortOrder': -1,
        'deduplicate': true,
      });
    });

    test('update and reorder bodies carry only the touched fields', () async {
      server.handler = (request, body) => switch (request.uri.path) {
        '/api/workflows/reorder' => FakeServer.json(request, 200, {
          'success': true,
          'updated': 2,
        }),
        _ => FakeServer.json(request, 200, {'workflow': liveWorkflowJson()}),
      };
      await workflows.update(
        workflowId,
        update: const WorkflowUpdate(name: 'A'),
      );
      await workflows.update(
        workflowId,
        update: const WorkflowUpdate(clearFolder: true),
      );
      await workflows.update(
        workflowId,
        update: const WorkflowUpdate(folderId: 'f1', sortOrder: 3),
      );
      final result = await workflows.reorder(
        workspaceId: workspaceId,
        updates: const [
          WorkflowReorderUpdate(id: 'a', sortOrder: 0),
          WorkflowReorderUpdate(id: 'b', sortOrder: 1, clearFolder: true),
        ],
      );
      expect(result.updated, 2);
      expect(server.requests[0].method, 'PUT');
      expect(server.requests[0].json, {'name': 'A'});
      expect(server.requests[1].json, {'folderId': null});
      expect(server.requests[2].json, {'folderId': 'f1', 'sortOrder': 3});
      expect(server.requests[3].json, {
        'workspaceId': workspaceId,
        'updates': [
          {'id': 'a', 'sortOrder': 0},
          {'id': 'b', 'sortOrder': 1, 'folderId': null},
        ],
      });
    });

    test('a 403 on a read-only workspace stays an ApiClientError', () async {
      server.handler = (request, body) =>
          FakeServer.json(request, 403, {'error': 'Insufficient permissions'});
      await expectLater(
        workflows.delete(workflowId),
        throwsA(
          isA<ApiClientError>().having((e) => e.isForbidden, '403', true),
        ),
      );
    });
  });

  group('folders', () {
    test('list, update, delete and restore wire shapes', () async {
      server.handler = (request, body) => switch (request.method) {
        'DELETE' => FakeServer.json(request, 200, {
          'success': true,
          'deletedItems': {'folders': 1, 'workflows': 2},
        }),
        _ when request.uri.path.endsWith('/restore') => FakeServer.json(
          request,
          200,
          {'success': true},
        ),
        'GET' => FakeServer.json(request, 200, {
          'folders': [liveFolderJson()],
        }),
        _ => FakeServer.json(request, 200, {'folder': liveFolderJson()}),
      };
      await folders.list(workspaceId: workspaceId);
      await folders.update(
        folderId,
        update: const FolderUpdate(clearParent: true),
      );
      final deleted = await folders.delete(folderId);
      final restored = await folders.restore(
        folderId,
        workspaceId: workspaceId,
      );
      expect(server.requests[0].query, {
        'workspaceId': workspaceId,
        'scope': 'active',
        'resourceType': 'workflow',
      });
      expect(server.requests[1].query, {'resourceType': 'workflow'});
      expect(server.requests[1].json, {'parentId': null});
      expect(server.requests[2].query, {'resourceType': 'workflow'});
      expect(deleted.counts?.workflows, 2);
      expect(server.requests[3].json, {
        'workspaceId': workspaceId,
        'resourceType': 'workflow',
      });
      expect(restored.counts, isNull);
    });

    test('duplicate sends parentId only when asked', () async {
      server.handler = (request, body) =>
          FakeServer.json(request, 200, {'folder': liveFolderJson()});
      await folders.duplicate(folderId, name: 'Copy', newId: 'f-new');
      await folders.duplicate(folderId, name: 'Copy', sendParent: true);
      await folders.duplicate(folderId, name: 'Copy', parentId: 'p1');
      expect(server.requests[0].json, {'name': 'Copy', 'newId': 'f-new'});
      expect(server.requests[1].json, {'name': 'Copy', 'parentId': null});
      expect(server.requests[2].json, {'name': 'Copy', 'parentId': 'p1'});
    });

    test('nextFolderName and generateName', () async {
      expect(FoldersRepository.nextFolderName(const []), 'Folder 1');
      expect(
        FoldersRepository.nextFolderName([
          Folder.fromJson(liveFolderJson(name: 'Folder 4')),
          Folder.fromJson(liveFolderJson(name: 'Folder 9', parentId: 'x')),
          Folder.fromJson(liveFolderJson(name: 'Folder')),
          Folder.fromJson(liveFolderJson(name: 'Folder 2')),
        ]),
        'Folder 5',
      );
      server.handler = (request, body) => FakeServer.json(request, 200, {
        'folders': [liveFolderJson(name: 'Folder 1')],
      });
      expect(await folders.generateName(workspaceId), 'Folder 2');
      expect(server.requests.single.query, {'workspaceId': workspaceId});
    });
  });
}
