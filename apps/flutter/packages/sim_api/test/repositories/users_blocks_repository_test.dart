// Failure modes of UsersRepository, SettingsRepository, BlocksRepository,
// OrganizationsRepository, HelpRepository and RecentlyDeletedRepository
// against a dart:io fake server (spec §3.4, §4.2, §4.8, §4.9, §4.11, §4.13):
// 1. `updateSetting` patches exactly one key, `null` included (timezone
//    clear); `updateProfile` sends `image: null` only with `clearImage`;
// 2. the settings read decodes the live body; 500 `{error}` stays an
//    ApiClientError;
// 3. provider models: `?workspaceId` goes out only for the four providers
//    whose route accepts it; OpenRouter lists are de-duplicated; a 500 is
//    an ApiClientError the loader logs;
// 4. surface-context 403 is `OrganizationAccess.denied`, 401 throws, a
//    granted surface decodes `hasOrganizationHome`;
// 5. the help form is multipart with the text fields and one `image_<n>`
//    part per screenshot; 401 and 413 arrive as ApiClientError;
// 6. recently-deleted paging sends the defaults, `cursor`/`limit` when
//    given, and reads `nextCursor`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import '../contracts/fixtures.dart';
import '../support/fake_server.dart';

void main() {
  late FakeServer server;
  late SimHttpClient http;

  setUp(() async {
    server = await FakeServer.start();
    http = SimHttpClient(baseUrl: server.url);
  });

  tearDown(() => server.close());

  group('users', () {
    test('updateSetting patches one key, null included', () async {
      final users = UsersRepository(http);
      server.handler = (request, body) =>
          FakeServer.json(request, 200, {'success': true});
      await users.updateSetting('theme', 'dark');
      await users.updateSetting('timezone', null);
      expect(server.requests[0].method, 'PATCH');
      expect(server.requests[0].path, '/api/users/me/settings');
      expect(server.requests[0].json, {'theme': 'dark'});
      expect(server.requests[1].json, {'timezone': null});
    });

    test('updateProfile sends image:null only with clearImage', () async {
      final users = UsersRepository(http);
      server.handler = (request, body) => FakeServer.json(request, 200, {
        'success': true,
        ...liveProfileJson(),
      });
      final profile = await users.updateProfile(name: 'New');
      await users.updateProfile(clearImage: true);
      expect(profile.email, 'flutter-e2e@example.com');
      expect(server.requests[0].json, {'name': 'New'});
      expect(server.requests[1].json, {'image': null});
    });

    test('settings read decodes; 500 stays an error', () async {
      final users = UsersRepository(http);
      server.handler = (request, body) =>
          FakeServer.json(request, 200, liveSettingsJson());
      final settings = await users.settings();
      expect(settings.theme, ThemeSetting.system);
      expect(settings.copilotAutoAllowedTools, isEmpty);
      server.handler = (request, body) =>
          FakeServer.json(request, 500, {'error': 'Failed to load settings'});
      await expectLater(
        users.settings(),
        throwsA(
          isA<ApiClientError>().having(
            (e) => e.message,
            'message',
            'Failed to load settings',
          ),
        ),
      );
    });

    test('allowed-* reads', () async {
      final settings = SettingsRepository(http);
      server.handler = (request, body) => switch (request.uri.path) {
        '/api/settings/allowed-providers' => FakeServer.json(request, 200, {
          'blacklistedProviders': ['x'],
        }),
        _ => FakeServer.json(request, 200, {
          'allowedIntegrations': null,
          'integrationAvailability': [
            {'type': 'slack', 'state': 'ready', 'oauthAvailable': true},
          ],
          'oauthServiceAvailability': <Object>[],
        }),
      };
      final integrations = await settings.allowedIntegrations();
      final providers = await settings.allowedProviders();
      expect(integrations.allowedIntegrations, isNull);
      expect(integrations.integrationAvailability.single.state, 'ready');
      expect(providers.blacklistedProviders, ['x']);
    });
  });

  group('blocks', () {
    test(
      'provider models: workspace query only where the route takes it',
      () async {
        final blocks = BlocksRepository(http);
        server.handler = (request, body) => FakeServer.json(request, 200, {
          'models': ['m1', 'm1', 'm2'],
        });
        for (final provider in ProviderName.values) {
          await blocks.providerModels(provider, workspaceId: workspaceId);
        }
        final withWorkspace = <String>[];
        for (final request in server.requests) {
          if (request.query.containsKey('workspaceId')) {
            withWorkspace.add(request.path);
          }
        }
        expect(withWorkspace, [
          '/api/providers/ollama-cloud/models',
          '/api/providers/fireworks/models',
          '/api/providers/together/models',
          '/api/providers/baseten/models',
        ]);
        final openrouter = await blocks.providerModels(ProviderName.openrouter);
        final base = await blocks.providerModels(ProviderName.base);
        expect(openrouter.models, ['m1', 'm2']);
        expect(base.models, ['m1', 'm1', 'm2']);
        server.handler = (request, body) =>
            FakeServer.json(request, 500, {'error': 'upstream down'});
        await expectLater(
          blocks.providerModels(ProviderName.vllm),
          throwsA(isA<ApiClientError>()),
        );
      },
    );

    test('custom blocks and visibility queries', () async {
      final blocks = BlocksRepository(http);
      server.handler = (request, body) => switch (request.uri.path) {
        '/api/custom-blocks' => FakeServer.json(request, 200, {
          'enabled': false,
          'customBlocks': <Object>[],
        }),
        _ => FakeServer.json(request, 403, {'error': 'Access denied'}),
      };
      final custom = await blocks.customBlocks(workspaceId);
      expect(custom.enabled, isFalse);
      expect(server.requests.single.query, {'workspaceId': workspaceId});
      await expectLater(
        blocks.visibility(workspaceId),
        throwsA(
          isA<ApiClientError>().having((e) => e.isForbidden, '403', true),
        ),
      );
    });
  });

  group('organizations', () {
    test(
      'surface-context 403 is denied, 401 throws, granted decodes',
      () async {
        final organizations = OrganizationsRepository(http);
        server.handler = (request, body) =>
            FakeServer.json(request, 403, {'error': 'Forbidden'});
        final denied = await organizations.surfaceContext('org-1');
        expect(denied.isDenied, isTrue);
        expect(
          server.requests.single.path,
          '/api/organizations/org-1/surface-context',
        );
        server.handler = (request, body) =>
            FakeServer.json(request, 401, {'error': 'Unauthorized'});
        await expectLater(
          organizations.surfaceContext('org-1'),
          throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 401)),
        );
        server.handler = (request, body) =>
            FakeServer.json(request, 200, surfaceContextJson());
        final granted = await organizations.surfaceContext('org-1');
        final surface = granted.surfaceOrNull!;
        expect(surface.context.hasOrganizationHome, isTrue);
        expect(surface.flags.mothershipMemorySpaces, isTrue);
        expect(surface.benchmarkEnabled, isTrue);
        expect(surface.context.settingsFeatures.selfHosted['sso'], isFalse);
      },
    );

    test('creator organizations list', () async {
      final organizations = OrganizationsRepository(http);
      server.handler = (request, body) => FakeServer.json(request, 200, {
        'organizations': <Object>[],
        'isMemberOfAnyOrg': false,
      });
      final list = await organizations.list();
      expect(list.isMemberOfAnyOrg, isFalse);
    });
  });

  group('help', () {
    test('multipart fields and image parts; 401 and 413 are errors', () async {
      final help = HelpRepository(http);
      server.handler = (request, body) =>
          FakeServer.json(request, 200, {'success': true});
      await help.submit(
        const HelpRequest(
          subject: 'Bug',
          message: 'It broke',
          type: HelpRequestType.bug,
          userAgent: 'flutter',
          workspaceId: workspaceId,
          images: [
            HelpImage(
              filename: 'a.png',
              bytes: [1, 2, 3],
              contentType: 'image/png',
            ),
          ],
        ),
      );
      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/help');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(request.body, contains('name="subject"'));
      expect(request.body, contains('name="type"\r\n\r\nbug'));
      expect(request.body, contains('name="workspaceId"'));
      expect(request.body, isNot(contains('name="workflowId"')));
      expect(request.body, contains('name="image_0"; filename="a.png"'));
      expect(request.body, contains('content-type: image/png'));
      server.handler = (r, body) =>
          FakeServer.json(r, 401, {'error': 'Authentication required'});
      await expectLater(
        help.submit(
          const HelpRequest(
            subject: 's',
            message: 'm',
            type: HelpRequestType.other,
            userAgent: 'ua',
          ),
        ),
        throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 401)),
      );
      server.handler = (r, body) async {
        r.response.statusCode = HttpStatus.requestEntityTooLarge;
        await r.response.close();
      };
      await expectLater(
        help.submit(
          const HelpRequest(
            subject: 's',
            message: 'm',
            type: HelpRequestType.other,
            userAgent: 'ua',
          ),
        ),
        throwsA(
          isA<ApiClientError>().having((e) => e.isPayloadTooLarge, '413', true),
        ),
      );
    });
  });

  group('recently deleted', () {
    test('paging query and nextCursor', () async {
      final recentlyDeleted = RecentlyDeletedRepository(http);
      server.handler = (request, body) => FakeServer.json(request, 200, {
        'items': [
          {
            'id': workflowId,
            'name': 'Old',
            'type': 'workflow',
            'deletedAt': '2026-10-21T10:00:00.000Z',
            'parentId': null,
          },
        ],
        'nextCursor': 'abc',
      });
      final page = await recentlyDeleted.list(workspaceId);
      final next = await recentlyDeleted.list(
        workspaceId,
        type: RecentlyDeletedFilter.workflow,
        search: 'old',
        limit: 10,
        cursor: page.nextCursor,
      );
      expect(page.hasMore, isTrue);
      expect(next.items.single.type, RecentlyDeletedType.workflow);
      expect(
        server.requests[0].path,
        '/api/workspaces/$workspaceId/recently-deleted',
      );
      expect(server.requests[0].query, {
        'type': 'all',
        'sortBy': 'deleted',
        'sortOrder': 'desc',
      });
      expect(server.requests[1].query, {
        'type': 'workflow',
        'search': 'old',
        'sortBy': 'deleted',
        'sortOrder': 'desc',
        'limit': '10',
        'cursor': 'abc',
      });
    });
  });
}
