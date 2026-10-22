// Failure modes (home-page.md "Panel width rules", use-mothership-resize.ts,
// stores/chat-panel/store.ts, use-resource-panel.ts):
// - maxPanelWidth uses the viewport share alone and lets the chat column
//   drop below min(480, half) (735 at 1440, 575 at 1280 when right)
// - a narrow container (< 560) clamps to a min above the max, so the drag
//   range inverts
// - the drag clamp lets the panel go under 280 or over the max, or ignores
//   the grab offset (the panel jumps by the grab distance on first move)
// - ArrowLeft narrows instead of widening; Home/End jump to the wrong bound;
//   a step past a bound overshoots
// - a modifier or IME composition still steps the width
// - the store keeps widths under 280, more than 200 keys, or drops the
//   most recent key instead of the oldest; a corrupt or foreign envelope
//   crashes hydration; the envelope shape differs from zustand's
//   `{"state":{"widths":{}},"version":0}` React reads
// - the panel auto-opens on a compact (<768px) layout, or stays shut
//   after leaving it
// - widths leak across users or chats; no user still persists
// - a pending scope is not migrated on chat creation, or a late write to
//   the pending scope lands on the stale key
// - the default (no preference) is not 50% of the row; a stored width is
//   not re-clamped to the current max
// - auto-open happens after the user collapsed, or does not happen for the
//   first resource; auto-close misses an emptied list; a chat switch keeps
//   the old ownership or activity
// - a resource event while the user owns the selection steals it, or a
//   user-collapsed panel is revealed by the agent

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/home/panel/panel_geometry.dart';
import 'package:sim_app/features/home/panel/panel_width_store.dart';
import 'package:sim_app/features/home/panel/resource_panel_controller.dart';
import 'package:sim_app/features/home/platform/local_storage.dart';

HomeResource res(String id, [HomeResourceType type = HomeResourceType.table]) =>
    HomeResource(type: type, id: id, title: id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('width rules', () {
    test('maxPanelWidth keeps the chat column floor', () {
      expect(maxPanelWidth(1440, 1215), 735);
      expect(maxPanelWidth(1280, 1055), 575);
      // Viewport share wins when it is tighter.
      expect(maxPanelWidth(600, 1215), 480);
      // Narrow container: both columns yield to half.
      expect(maxPanelWidth(500, 400), 200);
    });

    test('drag clamps with the grab offset', () {
      const g = PanelDragGeometry(
        panelRight: 1440,
        grabOffset: 4,
        maxWidth: 735,
      );
      // Grabbed at the edge (x = 1440 - 607 + 4): no jump.
      expect(panelWidthAt(1440 - 607 + 4, g), 607);
      expect(panelWidthAt(0, g), 735);
      expect(panelWidthAt(1430, g), 280);
      const narrow = PanelDragGeometry(
        panelRight: 400,
        grabOffset: 0,
        maxWidth: 200,
      );
      expect(panelWidthAt(399, narrow), 200);
    });

    test('keyboard steps 32px, Left widens, Home/End jump to bounds', () {
      expect(keyboardPanelWidth(SeparatorKey.left, 600, 735), 632);
      expect(keyboardPanelWidth(SeparatorKey.right, 600, 735), 568);
      expect(keyboardPanelWidth(SeparatorKey.left, 720, 735), 735);
      expect(keyboardPanelWidth(SeparatorKey.right, 300, 735), 280);
      expect(keyboardPanelWidth(SeparatorKey.min, 600, 735), 280);
      expect(keyboardPanelWidth(SeparatorKey.max, 600, 735), 735);
      expect(keyboardPanelWidth(SeparatorKey.min, 150, 200), 200);
    });

    test('readSeparatorKey ignores modifiers and composition', () {
      const left = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowLeft,
        logicalKey: LogicalKeyboardKey.arrowLeft,
        timeStamp: Duration.zero,
      );
      expect(readSeparatorKey(left), SeparatorKey.left);
      expect(readSeparatorKey(left, composing: true), isNull);
      const a = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      );
      expect(readSeparatorKey(a), isNull);
    });

    test('rendered width: 50% default, stored width re-clamped', () {
      double w(double? preferred, double viewport, double row) =>
          resolvePanelWidth(
            collapsed: false,
            preferred: preferred,
            viewportWidth: viewport,
            containerWidth: row,
          );
      expect(w(null, 1440, 1215), 607.5);
      expect(w(700, 1440, 1215), 700);
      expect(w(700, 1280, 1055), 575);
      expect(
        resolvePanelWidth(
          collapsed: true,
          preferred: 700,
          viewportWidth: 1440,
          containerWidth: 1215,
        ),
        0,
      );
    });
  });

  group('ChatPanelWidthStore', () {
    test('persists the zustand envelope per user and chat', () {
      final storage = MemoryHomeLocalStorage();
      ChatPanelWidthStore(storage: storage).setWidth('u1', 'c1', 500);
      expect(
        storage.read('chat-panel-widths'),
        '{"state":{"widths":{"u1:c1":500}},"version":0}',
      );
      final reloaded = ChatPanelWidthStore(storage: storage);
      expect(reloaded.preferred('u1', 'c1'), 500);
      expect(reloaded.preferred('u2', 'c1'), isNull);
      expect(reloaded.preferred('u1', 'c2'), isNull);
      expect(reloaded.preferred(null, 'c1'), isNull);
    });

    test('drops widths under 280 and junk, survives corrupt storage', () {
      final storage = MemoryHomeLocalStorage(<String, String>{
        'chat-panel-widths':
            '{"state":{"widths":{"u:a":279,"u:b":"x","u:c":300,"":400}},"version":0}',
      });
      final store = ChatPanelWidthStore(storage: storage);
      expect(store.widths, <String, double>{'u:c': 300});
      store.setWidth('u', 'd', 100);
      expect(store.preferred('u', 'd'), isNull);
      final corrupt = ChatPanelWidthStore(
        storage: MemoryHomeLocalStorage(<String, String>{
          'chat-panel-widths': '{not json',
        }),
      );
      expect(corrupt.widths, isEmpty);
      corrupt.setWidth('u', 'a', 300);
      expect(corrupt.preferred('u', 'a'), 300);
    });

    test('keeps the 200 most recently adjusted chats', () {
      final store = ChatPanelWidthStore(storage: MemoryHomeLocalStorage());
      for (var i = 0; i < 205; i++) {
        store.setWidth('u', 'c$i', 300);
      }
      // Re-adjusting an old key moves it to the end.
      store.setWidth('u', 'c10', 400);
      expect(store.widths.length, 200);
      expect(store.preferred('u', 'c0'), isNull);
      expect(store.preferred('u', 'c4'), isNull);
      expect(store.preferred('u', 'c5'), 300);
      expect(store.preferred('u', 'c10'), 400);
      expect(store.preferred('u', 'c204'), 300);
    });

    test('a pending scope migrates to the created chat', () {
      final store = ChatPanelWidthStore(storage: MemoryHomeLocalStorage())
        ..setWidth('u', 'pending:x', 420)
        ..migrate('pending:x', 'chat-1');
      expect(store.preferred('u', 'chat-1'), 420);
      expect(store.widths.containsKey('u:pending:x'), isFalse);
      // A drag finishing after adoption lands on the chat.
      store.setWidth('u', 'pending:x', 460);
      expect(store.preferred('u', 'chat-1'), 460);
      expect(store.preferred('u', 'pending:x'), 460);
    });

    test('reset forgets everything', () {
      final storage = MemoryHomeLocalStorage();
      final store = ChatPanelWidthStore(storage: storage)
        ..setWidth('u', 'c', 300)
        ..reset();
      expect(store.widths, isEmpty);
      expect(storage.read('chat-panel-widths'), isNull);
    });
  });

  group('ResourcePanelController', () {
    test('collapsed by default; auto-opens without transition on the first '
        'resources, auto-closes when they empty', () async {
      final c = ResourcePanelController()
        ..sync(chatId: 'c1', resources: const <HomeResource>[]);
      expect(c.isCollapsed, isTrue);
      c.sync(chatId: 'c1', resources: <HomeResource>[res('a')]);
      expect(c.isCollapsed, isFalse);
      expect(c.skipTransition, isTrue);
      c.sync(chatId: 'c1', resources: const <HomeResource>[]);
      expect(c.isCollapsed, isTrue);
    });

    test('no auto-open on a compact layout; leaving it re-runs the rule', () {
      final c = ResourcePanelController()
        ..sync(
          chatId: 'c1',
          resources: <HomeResource>[res('a')],
          compactLayout: true,
        );
      expect(c.isCollapsed, isTrue);
      c.sync(chatId: 'c1', resources: <HomeResource>[res('a')]);
      expect(c.isCollapsed, isFalse);
    });

    test('a user collapse is not undone by new resources until the next '
        'chat', () {
      final c = ResourcePanelController()
        ..sync(chatId: 'c1', resources: <HomeResource>[res('a')])
        ..collapse()
        ..sync(chatId: 'c1', resources: <HomeResource>[res('a'), res('b')]);
      expect(c.isCollapsed, isTrue);
      c.sync(chatId: 'c2', resources: <HomeResource>[res('x')]);
      expect(c.isCollapsed, isFalse, reason: 'ownership resets per chat');
    });

    test('no resolved chat collapses and resets', () {
      final c = ResourcePanelController()
        ..sync(chatId: 'c1', resources: <HomeResource>[res('a')])
        ..handleResourceEvent('a', activate: false)
        ..sync(chatId: null, resources: const <HomeResource>[]);
      expect(c.isCollapsed, isTrue);
      expect(c.activityIds, isEmpty);
    });

    test('adopting a chat id keeps ownership and activity', () {
      final c = ResourcePanelController()
        ..sync(chatId: null, resources: const <HomeResource>[])
        ..addFromUser(res('a'))
        ..sync(chatId: null, resources: <HomeResource>[res('a')])
        ..collapse()
        ..sync(chatId: 'new', resources: <HomeResource>[res('a'), res('b')]);
      expect(c.isCollapsed, isTrue);
      expect(c.collapseOwnedByUser, isTrue);
    });

    test('effective selection falls back to the last resource', () {
      final c = ResourcePanelController(initialSelection: 'missing')
        ..sync(chatId: 'c', resources: <HomeResource>[res('a'), res('b')]);
      expect(c.activeResourceId, 'b');
      c.select('a');
      expect(c.activeResourceId, 'a');
      expect(resolveEffectiveResourceId(const <HomeResource>[], 'a'), isNull);
    });

    test('resource events respect the user selection and collapse', () {
      final urls = <String?>[];
      final c = ResourcePanelController(onSelectionChanged: urls.add)
        ..sync(chatId: 'c', resources: <HomeResource>[res('a'), res('b')])
        ..select('a')
        // The user owns the selection: another resource only gets a mark.
        ..handleResourceEvent('b', activate: true);
      expect(c.activeResourceId, 'a');
      expect(c.activityIds, <String>{'b'});
      // A new agent turn releases the selection.
      c
        ..prepareForAgentTurn()
        ..handleResourceEvent('b', activate: true);
      expect(c.activeResourceId, 'b');
      expect(c.activityIds, isEmpty);
      expect(urls, <String?>['a', 'b']);
      // A user-collapsed panel is never revealed by the agent.
      c
        ..collapse()
        ..prepareForAgentTurn()
        ..handleResourceEvent('a', activate: true);
      expect(c.isCollapsed, isTrue);
      expect(c.activityIds, <String>{'a'});
      // Expanding clears the active tab's mark.
      c
        ..select('a')
        ..expand();
      expect(c.activityIds, isEmpty);
    });

    test('a collapsed panel the user does not own is revealed', () {
      final c = ResourcePanelController()
        ..sync(chatId: 'c', resources: <HomeResource>[res('a')])
        // Auto-opened; then an auto-close, then an event.
        ..sync(chatId: 'c', resources: const <HomeResource>[]);
      expect(c.isCollapsed, isTrue);
      c.handleResourceEvent('z', activate: true);
      expect(c.isCollapsed, isFalse);
    });

    test('activity of removed resources is pruned', () {
      final c = ResourcePanelController()
        ..sync(chatId: 'c', resources: <HomeResource>[res('a'), res('b')])
        ..select('a')
        ..handleResourceEvent('b', activate: false);
      expect(c.activityCount, 1);
      c.sync(chatId: 'c', resources: <HomeResource>[res('a')]);
      expect(c.activityCount, 0);
    });
  });

  group('HomeResource.selectionId', () {
    test('UUIDs and unscoped ids stay bare; workspace aliases carry the '
        'scope; ephemeral types stay bare', () {
      const uuid = '44098e20-360c-53b2-adb0-efed21a7919c';
      expect(
        const HomeResource(
          type: HomeResourceType.workflow,
          id: uuid,
          title: 'w',
          workspaceId: 'ws',
        ).selectionId,
        uuid,
      );
      expect(
        const HomeResource(
          type: HomeResourceType.integration,
          id: 'slack',
          title: 'Slack',
          workspaceId: 'ws',
        ).selectionId,
        '["ws","integration","slack"]',
      );
      expect(
        const HomeResource(
          type: HomeResourceType.generic,
          id: 'results',
          title: 'r',
          workspaceId: 'ws',
        ).selectionId,
        'results',
      );
      expect(res('plain').selectionId, 'plain');
    });
  });
}
