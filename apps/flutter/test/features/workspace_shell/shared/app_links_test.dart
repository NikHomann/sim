// Failure modes of the shared link base (finding 1 of the Phase 1 sidebar
// review) and the navigator built on it:
// 1. on web a route resolved against `Uri.base` (`location.href` under the
//    path URL strategy) nests under the current route
//    (`/app/workspace/ws/w/workspace/ws/w/x`); it must resolve against the
//    document base (`/app/`), whatever the current route is;
// 2. on Windows `Uri.base` is the working directory, so new tabs and copied
//    links become `file:///…`; the link must be the configured Sim origin's
//    page for the route (the React app);
// 3. without any base nothing opens (no `file:` URL), and the new-tab items
//    say so (disabled);
// 4. the sidebar navigator opens and copies the same absolute URL from a
//    nested current route;
// 5. in-app navigation goes through the settings dirty guard and ignores
//    the current location.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_dirty_store.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_navigation_guard.dart';
import 'package:sim_app/features/workspace_shell/shared/app_links.dart';
import 'package:sim_app/features/workspace_shell/sidebar/shared/platform/sidebar_browser.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';
import 'package:sim_app/features/workspace_shell/sidebar/tree/tree_menus.dart';

class _RecordingBrowser extends SidebarBrowser {
  _RecordingBrowser(this.opened);

  final List<String> opened;

  @override
  void openNewTab(String url) => opened.add(url);
}

void main() {
  const nested = '/workspace/ws/w/wf-current';
  const target = '/workspace/ws/w/wf-target';

  group('AppLinks', () {
    test('1. web: the document base, never the current route', () {
      final links = AppLinks.resolve(pageBase: 'http://localhost:3001/app/');
      expect(links.resolve(target), 'http://localhost:3001/app$target');
      expect(
        links.resolve(target.substring(1)),
        'http://localhost:3001/app$target',
      );
      // A base URI with a document name keeps its directory only.
      expect(
        AppLinks.resolve(
          pageBase: 'https://sim.example.com/app/index.html?x=1',
        ).resolve(target),
        'https://sim.example.com/app$target',
      );
    });

    test('2. desktop: the configured origin (the React page)', () {
      final links = AppLinks.resolve(
        backendOrigin: Uri.parse('https://sim.example.com:8443/ignored/path'),
      );
      expect(links.available, isTrue);
      expect(links.resolve(target), 'https://sim.example.com:8443$target');
      expect(
        links.resolve('/login?fromLogout=true'),
        endsWith('?fromLogout=true'),
      );
    });

    test('3. no base: no link and new-tab items disabled', () {
      const links = AppLinks(null);
      expect(links.available, isFalse);
      expect(links.resolve(target), isNull);
      final open = workflowMenuSpecs(
        const RowMenuGates(
          workflowCount: 1,
          folderCount: 0,
          canEdit: true,
          canAdmin: true,
          effectiveLocked: false,
          inheritedLocked: false,
          canDeleteSelection: true,
          canOpenInNewTab: false,
        ),
      ).firstWhere((s) => s.id == 'open-new-tab');
      expect(open.enabled, isFalse);
    });
  });

  group('RouterSidebarNavigator', () {
    late GoRouter router;
    late List<String> opened;
    late SettingsDirtyStore dirty;

    setUp(() {
      opened = <String>[];
      dirty = SettingsDirtyStore();
      router = GoRouter(
        initialLocation: nested,
        routes: <RouteBase>[
          GoRoute(
            path: '/workspace/:ws/w/:wf',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      );
    });

    tearDown(() {
      router.dispose();
      dirty.dispose();
    });

    RouterSidebarNavigator navigator(AppLinks links) => RouterSidebarNavigator(
      router,
      shell: ShellNavigator(router: router, dirty: dirty),
      browser: _RecordingBrowser(opened),
      links: links,
    );

    testWidgets('4. opens and copies the absolute URL from a nested route', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final nav = navigator(
        AppLinks.resolve(pageBase: 'http://localhost:3001/app/'),
      );
      expect(nav.location, nested);
      nav.openInNewTab(target);
      expect(opened, <String>['http://localhost:3001/app$target']);
      expect(nav.absoluteUrl(target), 'http://localhost:3001/app$target');

      final desktop = navigator(const AppLinks(null));
      expect(desktop.canOpenInNewTab, isFalse);
      desktop.openInNewTab(target);
      expect(opened, hasLength(1), reason: 'nothing opens without a base');
    });

    testWidgets('5. go asks the dirty guard; the current route is a no-op', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final nav = navigator(const AppLinks(null));
      dirty.setGuard('form', const SettingsGuard(isDirty: true));
      nav.go(target);
      await tester.pump();
      expect(dirty.hasPendingLeave, isTrue);
      expect(nav.location, nested);
      dirty.confirmLeave();
      await tester.pumpAndSettle();
      expect(nav.location, target);

      dirty.removeGuard('form');
      nav.go(target);
      await tester.pump();
      expect(dirty.hasPendingLeave, isFalse);
      expect(nav.location, target);
    });
  });
}
