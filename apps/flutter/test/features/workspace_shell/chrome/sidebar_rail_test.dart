// Failure modes (workspace-chrome.md "Rail widths", "Resize handle",
// "Collapse and persistence"):
// - a width below 224 or above max(224, min(400, 0.3·vw)) survives (400 at
//   1440, 384 at 1280; 400 below 768); a non-finite width is not reset
// - the stored width or collapse flag is not read back by a new controller
//   (the React app and a reload would disagree)
// - resizing while collapsed changes the stored width
// - the collapsed rail is not exactly 48px
// - a drag persists on every move instead of once on release, or the rail
//   does not follow the pointer during the drag
// - a drag past the ceiling widens the rail beyond it
// - pointer cancel leaves the drag uncommitted
// - the collapsed handle does not expand on click / Enter / Space
// - `/upgrade` keeps the rail visible or the pane border
// - the content paints over the 1px pane border
// - sign-out rewrites `sidebar-state` instead of leaving it absent

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/workspace_shell/chrome/sidebar_controller.dart';
import 'package:sim_app/features/workspace_shell/chrome/sidebar_frame.dart';
import 'package:sim_design/sim_design.dart';

import 'support/shell_harness.dart' show byParityId;

class CountingStorage extends MemorySharedWebState {
  int widthWrites = 0;
  int collapseWrites = 0;

  @override
  void writeSidebarWidth(int width) {
    widthWrites++;
    super.writeSidebarWidth(width);
  }

  @override
  void writeSidebarCollapsed({required bool collapsed}) {
    collapseWrites++;
    super.writeSidebarCollapsed(collapsed: collapsed);
  }
}

void main() {
  group('clampSidebarWidth', () {
    test('ceiling follows the viewport and never drops below 224', () {
      expect(getMaxSidebarWidth(1440), 400);
      expect(getMaxSidebarWidth(1280), 384);
      expect(getMaxSidebarWidth(700), 224);
      expect(clampSidebarWidth(100, viewportWidth: 1440), 224);
      expect(clampSidebarWidth(390, viewportWidth: 1280), 384);
      expect(clampSidebarWidth(500, viewportWidth: 600), 400);
      expect(clampSidebarWidth(double.nan, viewportWidth: 1440), 224);
      expect(clampSidebarWidth(double.infinity, viewportWidth: 1440), 224);
    });
  });

  group('SidebarController', () {
    test('width and collapse round-trip through the shared storage', () {
      final storage = CountingStorage();
      SidebarController(storage: storage)
        ..setSidebarWidth(300, viewportWidth: 1440)
        ..toggleCollapsed();
      final reloaded = SidebarController(storage: storage);
      expect(reloaded.storedWidth, 300);
      expect(reloaded.isCollapsed, isTrue);
      expect(reloaded.renderedWidth(1440), SidebarWidth.collapsed);
      reloaded.toggleCollapsed();
      expect(SidebarController(storage: storage).isCollapsed, isFalse);
    });

    test('a stored width is re-clamped for a narrower window', () {
      final storage = CountingStorage()..writeSidebarWidth(400);
      final controller = SidebarController(storage: storage);
      expect(controller.renderedWidth(1440), 400);
      expect(controller.renderedWidth(1280), 384);
      expect(controller.storedWidth, 400, reason: 'not persisted by a resize');
    });

    test('resizing is ignored while collapsed', () {
      final storage = CountingStorage();
      final controller = SidebarController(storage: storage)
        ..setCollapsed(collapsed: true)
        ..setSidebarWidth(320, viewportWidth: 1440);
      expect(controller.storedWidth, SidebarWidth.defaultWidth);
      expect(storage.widthWrites, 0);
    });

    // Regression (review finding 22): React's clearUserData leaves
    // `sidebar-state` absent; rewriting the default resurrected the key.
    test('reset removes the width key but keeps the collapse cookie', () {
      final storage = CountingStorage();
      final controller = SidebarController(storage: storage)
        ..setSidebarWidth(320, viewportWidth: 1440)
        ..setCollapsed(collapsed: true)
        ..reset();
      expect(controller.storedWidth, SidebarWidth.defaultWidth);
      expect(storage.readSidebarWidth(), isNull);
      expect(storage.readSidebarCollapsed(), isTrue);
    });
  });

  group('SidebarFrame', () {
    late CountingStorage storage;
    late SidebarController controller;

    setUp(() {
      storage = CountingStorage();
      controller = SidebarController(storage: storage);
    });

    Future<void> pumpFrame(
      WidgetTester tester, {
      double width = 1440,
      bool fullscreen = false,
    }) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: simLightTheme(),
          home: SidebarFrame(
            controller: controller,
            fullscreen: fullscreen,
            sidebar: const SizedBox.expand(key: Key('rail')),
            content: const SizedBox.expand(key: Key('content')),
          ),
        ),
      );
    }

    double railWidth(WidgetTester tester) =>
        tester.getSize(byParityId('shell.sidebar.shell')).width;

    testWidgets('drag follows the pointer and persists once on release', (
      tester,
    ) async {
      await pumpFrame(tester);
      expect(railWidth(tester), 224);
      final handle = tester.getCenter(
        byParityId('shell.sidebar.resize-handle'),
      );
      expect(handle.dx, 224, reason: 'strip centred on the rail edge');

      final gesture = await tester.startGesture(handle);
      await gesture.moveTo(const Offset(300, 450));
      await tester.pump();
      expect(railWidth(tester), 300);
      await gesture.moveTo(const Offset(350, 450));
      await tester.pump();
      expect(railWidth(tester), 350);
      expect(storage.widthWrites, 0, reason: 'nothing persisted mid-drag');

      await gesture.moveTo(const Offset(900, 450));
      await tester.pump();
      expect(railWidth(tester), 400, reason: 'max at 1440 is 400');

      await gesture.up();
      await tester.pump();
      expect(storage.widthWrites, 1);
      expect(storage.readSidebarWidth(), 400);
      expect(railWidth(tester), 400);
      final pane = tester.getRect(byParityId('shell.content.pane'));
      expect(pane.left, 400);
    });

    testWidgets('a cancelled drag still commits the last width', (
      tester,
    ) async {
      await pumpFrame(tester, width: 1280);
      final gesture = await tester.startGesture(
        tester.getCenter(byParityId('shell.sidebar.resize-handle')),
      );
      await gesture.moveTo(const Offset(100, 450));
      await tester.pump();
      expect(railWidth(tester), 224, reason: 'never below 224');
      await gesture.moveTo(const Offset(260, 450));
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      expect(storage.readSidebarWidth(), 260);
      expect(storage.widthWrites, 1);
    });

    testWidgets('collapsed: 48px rail; click and Enter expand, drag does not', (
      tester,
    ) async {
      controller.setCollapsed(collapsed: true);
      await pumpFrame(tester);
      expect(railWidth(tester), 48);

      final handle = byParityId('shell.sidebar.resize-handle');
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveTo(const Offset(320, 450));
      await tester.pump();
      expect(railWidth(tester), 48);
      await gesture.up();
      await tester.pump();
      expect(controller.isCollapsed, isTrue, reason: 'a drag is not a click');

      await tester.tap(handle);
      await tester.pump();
      expect(controller.isCollapsed, isFalse, reason: 'a click expands');
      expect(railWidth(tester), 224);

      controller.setCollapsed(collapsed: true);
      await tester.pump();
      final focus = Focus.of(
        tester.element(
          find.descendant(of: handle, matching: find.byType(MouseRegion)).first,
        ),
      )..requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.isCollapsed, isFalse);
      controller.setCollapsed(collapsed: true);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(controller.isCollapsed, isFalse);
    });

    testWidgets('fullscreen: no rail, no handle, no pane border', (
      tester,
    ) async {
      await pumpFrame(tester, fullscreen: true);
      expect(railWidth(tester), 0);
      expect(byParityId('shell.sidebar.resize-handle'), findsNothing);
      final pane = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: byParityId('shell.content.pane'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((pane.decoration as BoxDecoration).border, isNull);
    });

    // Regression (review finding 11): `border-l` in a border-box; the
    // content starts after the 1px divider so it cannot paint over it.
    testWidgets('content starts 1px right of the rail (the border)', (
      tester,
    ) async {
      await pumpFrame(tester);
      expect(
        tester.getTopLeft(find.byKey(const Key('content'))).dx,
        railWidth(tester) + 1,
      );
    });

    testWidgets('toggling snaps in one frame', (tester) async {
      await pumpFrame(tester);
      controller.toggleCollapsed();
      await tester.pump();
      expect(railWidth(tester), 48);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
