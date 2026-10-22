// Failure modes of the Phase 1 contract decoders (spec §2.1, §11.4, §11.9):
// 1. unknown fields on any object are ignored (live rows carry `projectId`,
//    `status`, `billedAccountUserId` the schema does not list);
// 2. a required field that is missing or mistyped fails with the dotted
//    path of the field, never a bare TypeError;
// 3. an enum value outside the zod union fails like `z.enum`;
// 4. the host context tolerates absent `features` / `deployment` (rolling
//    compatibility) and `WorkflowListItem` defaults `forkSyncExcluded`;
// 5. `normalizeWorkspace` defaults the three invite fields;
// 6. `WorkspaceFeatureFlags.flag(name)` is `false` for an unknown name;
// 7. structural equality: two decodes of the same shape are `==`, a single
//    changed leaf is not (what `seedDeploymentShape` relies on);
// 8. passthrough rows keep their extra fields (`PendingWorkspaceInvitation`);
// 9. user settings default every omitted field like the zod schema and
//    `withSetting` replaces exactly one key;
// 10. OpenRouter model lists are de-duplicated, other providers are not;
// 11. `BlockVisibility` decodes into sets.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import 'fixtures.dart';

void main() {
  group('unknown fields and required fields', () {
    test('live-shaped rows with extra fields decode', () {
      final list = WorkspaceList.fromJson(liveWorkspaceListJson());
      expect(list.workspaces.single.id, workspaceId);
      expect(list.creationPolicy?.canCreate, isTrue);
      expect(list.lastActiveWorkspaceId, workspaceId);
      final folder = Folder.fromJson(liveFolderJson());
      expect(folder.parentId, isNull);
    });

    test('a missing required field names its path', () {
      final json = liveWorkspaceListJson();
      (json['workspaces']! as List)[0] = Map<String, Object?>.of(
        (json['workspaces']! as List)[0] as Map<String, Object?>,
      )..remove('ownerId');
      expect(
        () => WorkspaceList.fromJson(json),
        throwsA(
          isA<ContractDecodeError>().having((e) => e.path, 'path', 'ownerId'),
        ),
      );
    });

    test('a mistyped field fails, not a TypeError', () {
      final json = liveHostContextJson()..['hostOrganizationId'] = 42;
      expect(
        () => WorkspaceHostContext.fromJson(json),
        throwsA(isA<ContractDecodeError>()),
      );
    });

    test('an enum value outside the union fails', () {
      final json = liveWorkspaceListJson();
      ((json['workspaces']! as List)[0] as Map)['workspaceMode'] = 'shared';
      expect(
        () => WorkspaceList.fromJson(json),
        throwsA(
          isA<ContractDecodeError>().having(
            (e) => e.path,
            'path',
            'workspaceMode',
          ),
        ),
      );
    });
  });

  group('rolling-compatibility defaults', () {
    test('host context without features/deployment decodes with defaults', () {
      final json = liveHostContextJson()
        ..remove('features')
        ..remove('deployment');
      final context = WorkspaceHostContext.fromJson(json);
      expect(context.deployment, isNull);
      expect(context.features.credentialGroups, isFalse);
      expect(context.viewer.permission, WorkspacePermission.admin);
    });

    test('workflow list item defaults forkSyncExcluded and isDeployed', () {
      final item = WorkflowListItem.fromJson(
        liveWorkflowJson()
          ..remove('forkSyncExcluded')
          ..remove('isDeployed'),
      );
      expect(item.forkSyncExcluded, isFalse);
      expect(item.isDeployed, isNull);
    });

    test('invite fields default like normalizeWorkspace', () {
      final row =
          ((liveWorkspaceListJson()['workspaces']! as List)[0] as Map)
              .cast<String, Object?>()
            ..remove('inviteMembersEnabled')
            ..remove('inviteDisabledReason')
            ..remove('inviteUpgradeRequired');
      final workspace = Workspace.fromJson(row);
      expect(workspace.inviteMembersEnabled, isFalse);
      expect(workspace.inviteDisabledReason, isNull);
      expect(workspace.inviteUpgradeRequired, isFalse);
    });

    test('an unknown flag name reads false', () {
      final flags = WorkspaceFeatureFlags.fromJson(featureFlagsJson());
      expect(flags.flag('dashboards'), isTrue);
      expect(flags.flag('mothership-memory-spaces'), isFalse);
      expect(flags.flag('no-such-flag'), isFalse);
    });
  });

  group('structural equality', () {
    test('same shape is equal, one changed leaf is not', () {
      final a = DeploymentShape.fromJson(
        liveHostContextJson()['deployment']! as Map<String, Object?>,
      );
      final b = DeploymentShape.fromJson(
        liveHostContextJson()['deployment']! as Map<String, Object?>,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      final changed =
          liveHostContextJson()['deployment']! as Map<String, Object?>;
      (changed['features']! as Map)['inbox'] = false;
      expect(a, isNot(equals(DeploymentShape.fromJson(changed))));
    });

    test('defaults are the nothing-configured shape', () {
      const shape = DeploymentShape();
      expect(shape.chatEnabled, isTrue);
      expect(shape.hosted, isFalse);
      expect(shape.features.sso, isFalse);
    });
  });

  test('passthrough invitation rows keep extra fields', () {
    final row = PendingWorkspaceInvitation.fromJson(const {
      'id': 'inv1',
      'workspaceId': workspaceId,
      'email': 'a@b.c',
      'permission': 'write',
      'status': 'pending',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'inviterName': 'Ann',
    });
    expect(row.extra, {'inviterName': 'Ann'});
    expect(row.toJson()['inviterName'], 'Ann');
    expect(row.isPending, isTrue);
    expect(row.isExternal, isFalse);
  });

  group('user settings', () {
    test('omitted fields take the schema defaults', () {
      final settings = UserSettings.fromJson(const {
        'mothershipEnvironment': 'default',
        'copilotAutoAllowedTools': <String>[],
        'timezone': null,
      });
      expect(settings.theme, ThemeSetting.system);
      expect(settings.autoConnect, isTrue);
      expect(settings.snapToGridSize, 0);
      expect(settings.showActionBar, isTrue);
      expect(settings.lastActiveWorkspaceId, isNull);
    });

    test('withSetting replaces exactly one key', () {
      final settings = UserSettings.fromJson(
        liveSettingsJson()['data']! as Map<String, Object?>,
      );
      final next = settings.withSetting('theme', 'dark');
      expect(next.theme, ThemeSetting.dark);
      expect(next.autoConnect, settings.autoConnect);
      expect(
        settings.withSetting('timezone', 'Europe/Berlin').timezone,
        'Europe/Berlin',
      );
      expect(settings.withSetting('timezone', null).timezone, isNull);
    });
  });

  test('OpenRouter lists are de-duplicated on request', () {
    final models = ProviderModels.fromJson(const {
      'models': ['a', 'b', 'a'],
    });
    expect(models.models, ['a', 'b', 'a']);
    expect(models.deduplicated().models, ['a', 'b']);
  });

  test('block visibility decodes into sets', () {
    final visibility = BlockVisibility.fromJson(const {
      'revealed': ['x', 'x'],
      'disabled': ['y'],
      'previewTagged': <String>[],
    });
    expect(visibility.revealed, {'x'});
    expect(visibility.disabled, {'y'});
    expect(visibility, const BlockVisibility(revealed: {'x'}, disabled: {'y'}));
  });
}
