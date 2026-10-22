// Failure modes of the switcher rules (`workspace-header.tsx`,
// `workspace-context-menu.tsx`, `use-workspace-management.ts`):
// 1. search filters only at >= 6 workspaces, by case-insensitive substring
//    of the trimmed query, keeping the pinned-first order;
// 2. the highlight follows the workspace id across filtering, re-seeds to
//    the first result when filtered out, and wraps with the arrows;
// 3. Enter is armed only once keyboard navigation began (typing counts,
//    pointer hover disarms);
// 4. the context menu's role policy: rename/upload/delete need admin,
//    delete needs a second workspace, leave is hidden for the owner, an
//    org admin and a signed-out viewer;
// 5. switching from a settings page keeps the section, never the detail;
//    a sectionless settings path does not navigate;
// 6. the initial ignores the word "workspace".

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/switcher/identity_tile.dart';
import 'package:sim_app/features/workspace_shell/switcher/switcher_logic.dart';

import '../search/support/shell_fixtures.dart';

void main() {
  final six = [
    for (final n in ['Acme', 'Beta', 'Gamma', 'Delta', 'acme labs', 'Zeta'])
      ws(n.toLowerCase().replaceAll(' ', '-'), name: n),
  ];

  group('1. filtering', () {
    test('below the threshold the query is ignored', () {
      final search = SwitcherSearch()..type('acme');
      expect(search.filter(six.take(5).toList()), hasLength(5));
    });

    test('at the threshold: trimmed, case-insensitive, order kept', () {
      final search = SwitcherSearch()..type('  ACME ');
      expect(search.filter(six).map((w) => w.name), ['Acme', 'acme labs']);
    });
  });

  group('2. highlight', () {
    test('seeds to the first row and follows the id', () {
      final search = SwitcherSearch()..seed(six);
      expect(search.highlightedId, 'acme');
      search
        ..move(six, 1)
        ..move(six, 1);
      expect(search.highlightedId, 'gamma');
      search.type('a');
      final filtered = search.filter(six);
      expect(search.activeIndex(filtered), 2);
    });

    test('re-seeds when the highlighted row is filtered out', () {
      final search = SwitcherSearch()
        ..highlightedId = 'zeta'
        ..type('acme');
      final filtered = search.filter(six);
      search.seed(filtered);
      expect(search.highlightedId, 'acme');
    });

    test('arrows wrap at both ends', () {
      final search = SwitcherSearch()
        ..seed(six)
        ..move(six, -1);
      expect(search.highlightedId, 'zeta');
      search.move(six, 1);
      expect(search.highlightedId, 'acme');
    });
  });

  group('3. armed Enter', () {
    test('ignored until keyboard navigation began', () {
      final search = SwitcherSearch()..seed(six);
      expect(search.enterTarget(six), isNull);
      search.move(six, 1);
      expect(search.enterTarget(six)?.id, 'beta');
    });

    test('typing arms, hover disarms but retargets', () {
      final search = SwitcherSearch()
        ..type('')
        ..seed(six);
      expect(search.enterTarget(six)?.id, 'acme');
      search.hover('delta');
      expect(search.enterTarget(six), isNull);
      search.move(six, 1);
      expect(search.enterTarget(six)?.id, 'acme-labs');
    });

    test('an empty result never switches', () {
      final search = SwitcherSearch()..type('nothing');
      expect(search.enterTarget(search.filter(six)), isNull);
    });
  });

  group('4. context menu policy', () {
    test('admin of one of several workspaces: everything', () {
      final p = WorkspaceMenuPolicy.of(
        ws('a', ownerId: 'someone-else'),
        workspaceCount: 2,
        sessionUserId: userId,
      );
      expect(
        [p.canRename, p.canUploadLogo, p.canDelete, p.showLeave],
        [
          true,
          true,
          true,
          true,
        ],
      );
    });

    test('the only workspace cannot be deleted', () {
      final p = WorkspaceMenuPolicy.of(
        ws('a'),
        workspaceCount: 1,
        sessionUserId: userId,
      );
      expect(p.canDelete, isFalse);
      expect(p.canRename, isTrue);
    });

    for (final role in [
      WorkspacePermission.write,
      WorkspacePermission.read,
      null,
    ]) {
      test('$role cannot rename, upload or delete', () {
        final p = WorkspaceMenuPolicy.of(
          ws('a', permissions: role, ownerId: 'owner'),
          workspaceCount: 3,
          sessionUserId: userId,
        );
        expect(
          [p.canRename, p.canUploadLogo, p.canDelete],
          [
            false,
            false,
            false,
          ],
        );
        expect(p.showLeave, isTrue);
      });
    }

    test('leave is hidden for the owner, an org admin, no session', () {
      expect(
        WorkspaceMenuPolicy.of(
          ws('a'),
          workspaceCount: 2,
          sessionUserId: userId,
        ).showLeave,
        isFalse,
      );
      expect(
        WorkspaceMenuPolicy.of(
          ws('a', ownerId: 'x', isOrgAdmin: true),
          workspaceCount: 2,
          sessionUserId: userId,
        ).showLeave,
        isFalse,
      );
      expect(
        WorkspaceMenuPolicy.of(
          ws('a', ownerId: 'x'),
          workspaceCount: 2,
          sessionUserId: null,
        ).showLeave,
        isFalse,
      );
    });
  });

  test('5. switch href keeps the settings section only', () {
    String? href(String path) => resolveWorkspaceSwitchHref(
      pathname: path,
      currentWorkspaceId: 'a',
      targetWorkspaceId: 'b',
    );
    expect(href('/workspace/a/w/wf'), '/workspace/b');
    expect(
      href('/workspace/a/settings/secrets/key-1'),
      '/workspace/b/settings/secrets',
    );
    expect(href('/workspace/a/settings/'), isNull);
    expect(href('/workspace/c/settings/secrets'), '/workspace/b');
  });

  test('6. workspace initial', () {
    expect(workspaceInitial('Acme Workspace'), 'A');
    expect(workspaceInitial('workspace'), 'W');
    expect(workspaceInitial('My workspace'), 'M');
    expect(workspaceInitial(' b '), 'B');
    expect(workspaceInitial(null), 'W');
    expect(workspaceInitial(''), 'W');
  });
}
