// Failure modes of the nav lists and the rail hover menu
// (sidebar.tsx:754-865, sidebar-nav-chip.tsx:393-398, use-hover-menu.ts):
// 1. flags: Dashboard / Changelog / Tests appear only with their flags;
// 2. chat off → home becomes the "New workflow" action, hidden for a
//    read-only member once permissions resolved (but shown while loading);
// 3. a permission group hides a tab, or keeps it with a Lock when access
//    requests are available;
// 4. active matching stops at segment boundaries; Integrations is also
//    active on /skills;
// 5. hover menu: opens on enter, closes 150 ms after leaving every region,
//    re-entering cancels, a lock holds it open and unlocking outside
//    closes it.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/workspace_shell/shared/permission_config.dart';
import 'package:sim_app/features/workspace_shell/sidebar/nav/nav_items.dart';
import 'package:sim_app/features/workspace_shell/sidebar/rail/hover_menu.dart';

NavGating gating({
  bool chat = true,
  bool canEdit = true,
  bool loading = false,
  bool dashboards = false,
  bool changelog = false,
  bool tests = false,
  ShellPermissionConfig config = const ShellPermissionConfig(),
  bool accessRequests = false,
}) => NavGating(
  workspaceId: 'ws',
  chatEnabled: chat,
  canEdit: canEdit,
  permissionsLoading: loading,
  dashboardsEnabled: dashboards,
  changelogEnabled: changelog,
  testsEnabled: tests,
  permissionConfig: config,
  accessRequestsEnabled: accessRequests,
);

void main() {
  group('nav gating', () {
    test('flags add Dashboard, Changelog and Tests', () {
      expect(topNavItems(gating()).map((i) => i.id), <String>[
        'home',
        'integrations',
      ]);
      expect(
        topNavItems(gating(dashboards: true, changelog: true)).map((i) => i.id),
        <String>['home', 'dashboards', 'changelog', 'integrations'],
      );
      expect(workspaceNavItems(gating()).map((i) => i.id), <String>[
        'tables',
        'files',
        'knowledge-base',
        'logs',
      ]);
      expect(
        workspaceNavItems(gating(tests: true)).map((i) => i.id),
        contains('tests'),
      );
    });

    test('chat off turns home into the New workflow action', () {
      final home = topNavItems(gating(chat: false)).first;
      expect(home.label, 'New workflow');
      expect(home.href, isNull);
      expect(home.isAction, isTrue);
      expect(
        topNavItems(gating(chat: false, canEdit: false)).first.id,
        'integrations',
      );
      expect(
        topNavItems(
          gating(chat: false, canEdit: false, loading: true),
        ).first.id,
        'home',
      );
      final chatHome = topNavItems(gating()).first;
      expect(chatHome.label, 'New chat');
      expect(chatHome.href, '/workspace/ws/home');
    });

    test('permission groups hide or lock tabs', () {
      const config = ShellPermissionConfig(
        hideFilesTab: true,
        hideCopilot: true,
        hideTablesTab: true,
      );
      expect(
        workspaceNavItems(gating(config: config)).map((i) => i.id),
        <String>['knowledge-base', 'logs'],
      );
      final locked = workspaceNavItems(
        gating(config: config, accessRequests: true, tests: true),
      );
      expect(locked.map((i) => i.id), <String>[
        'tables',
        'files',
        'knowledge-base',
        'tests',
        'logs',
      ]);
      expect(locked.where((i) => i.restricted).map((i) => i.id), <String>[
        'tables',
        'files',
        'tests',
      ]);
      expect(topNavItems(gating(config: config)).first.id, 'integrations');
      expect(
        topNavItems(
          gating(config: config, accessRequests: true),
        ).first.restricted,
        isTrue,
      );
    });

    test('active matching stops at segment boundaries', () {
      final items = {for (final i in topNavItems(gating())) i.id: i};
      final integrations = items['integrations']!;
      expect(
        isNavItemActive(integrations, '/workspace/ws/integrations'),
        isTrue,
      );
      expect(
        isNavItemActive(integrations, '/workspace/ws/integrations/x'),
        isTrue,
      );
      expect(
        isNavItemActive(integrations, '/workspace/ws/integrations-x'),
        isFalse,
      );
      expect(isNavItemActive(integrations, '/workspace/ws/skills/a'), isTrue);
      expect(isNavItemActive(items['home']!, null), isFalse);
    });
  });

  group('hover menu', () {
    test('closes 150 ms after leaving; re-entering cancels', () {
      fakeAsync((async) {
        final hover = HoverMenuController()..open();
        expect(hover.isOpen, isTrue);
        hover.setPointerInside(inside: false);
        async.elapse(const Duration(milliseconds: 149));
        hover.setPointerInside(inside: true);
        async.elapse(const Duration(milliseconds: 200));
        expect(hover.isOpen, isTrue);
        hover.setPointerInside(inside: false);
        async.elapse(hoverMenuCloseDelay);
        expect(hover.isOpen, isFalse);
        hover.dispose();
      });
    });

    test('a lock holds it open; unlocking outside closes it', () {
      fakeAsync((async) {
        final hover = HoverMenuController()
          ..open()
          ..setLocked(locked: true)
          ..setPointerInside(inside: false);
        async.elapse(const Duration(seconds: 1));
        expect(hover.isOpen, isTrue);
        hover.close();
        expect(hover.isOpen, isTrue);
        hover.setLocked(locked: false);
        expect(hover.isOpen, isFalse);
        hover.dispose();
      });
    });
  });
}
