// Failure modes of the Chats section (sidebar.tsx:1529-1651,
// collapsed-sidebar-menu.tsx, stores/folders/store.ts), each a test below:
// 1. chat selection lives apart from the tree's: selecting a chat leaves
//    the workflow selection in place, selecting a workflow leaves chats
//    highlighted; Shift ranges from the anchor [finding 16];
// 2. right-click on a row inside a multi-selection acts on the whole
//    selection ("Delete 3 items" deletes all three) [finding 30];
// 3. Rename from the row menu edits inline and saves through the source;
// 4. "See more" adds five rows, "See less" returns to five;
// 5. Rename from the collapsed rail flyout locks the flyout open with no
//    input (no edit row is rendered), so it never closes [finding 15];
// 6. a rail flyout open during a collapse / expand round trip leaves its
//    controller "open": the chip stays active and hover never reopens the
//    flyout [finding 17];
// 7. the scroll region starting or stopping to overflow remounts the
//    section (SimScrollFade swaps its subtree), so "See more" resets
//    [finding 6].

import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/workspace_shell/sidebar/chats/chat_models.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar.dart';
import 'package:sim_app/features/workspace_shell/sidebar/sidebar_environment.dart';

import 'support/harness.dart';

class FakeChats extends SidebarChatsSource {
  FakeChats(int count)
    : list = ValueNotifier<List<SidebarChat>?>(<SidebarChat>[
        for (var i = 1; i <= count; i++)
          SidebarChat(id: 'c$i', name: 'Chat $i'),
      ]);

  final ValueNotifier<List<SidebarChat>?> list;
  final List<String> renamed = <String>[];
  final List<List<String>> deleted = <List<String>>[];

  @override
  ValueListenable<List<SidebarChat>?> chats(String workspaceId) => list;

  @override
  Future<void> rename(String chatId, String title) async =>
      renamed.add('$chatId:$title');

  @override
  Future<void> setPinned(String chatId, {required bool pinned}) async {}

  @override
  Future<void> markRead(String chatId) async {}

  @override
  Future<void> markUnread(String chatId) async {}

  @override
  Future<void> delete(List<String> chatIds) async => deleted.add(chatIds);
}

void main() {
  late SidebarHarness h;
  late FakeChats chats;

  setUp(() {
    h = SidebarHarness();
    chats = FakeChats(7);
    h.chats = chats;
  });
  tearDown(() => h.dispose());

  Finder chatRow(String name) => find.ancestor(
    of: find.text(name),
    matching: find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == name,
    ),
  );

  bool selected(WidgetTester tester, String name) =>
      tester.widget<Semantics>(chatRow(name).first).properties.selected ??
      false;

  Future<void> shiftTap(WidgetTester tester, Finder target) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(target);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  testWidgets('1. chat and tree selection clear each other', (tester) async {
    await pumpSidebar(tester, h);
    expect(h.tree.state.selectedWorkflows, <String>{'w-empty'});
    await tester.tap(find.text('Chat 1'));
    await tester.pump();
    expect(h.tree.state.selectedWorkflows, isEmpty);
    await shiftTap(tester, find.text('Chat 3'));
    expect(h.tree.state.selectedChats, <String>{'c1', 'c2', 'c3'});
    expect(selected(tester, 'Chat 2'), isTrue);

    await tester.tap(find.text('Benchmark 200 blocks'));
    await tester.pump();
    expect(h.tree.state.selectedChats, isEmpty);
    expect(selected(tester, 'Chat 2'), isFalse);
  });

  testWidgets('2. a menu on a multi-selection deletes all of it', (
    tester,
  ) async {
    await pumpSidebar(tester, h);
    await tester.tap(find.text('Chat 1'));
    await tester.pump();
    await shiftTap(tester, find.text('Chat 3'));
    await tester.tap(find.text('Chat 2'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(byParity('shell.sidebar.chats.menu'), findsOneWidget);
    expect(find.text('Open in new tab'), findsNothing);
    await tester.tap(find.text('Delete 3 items'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(chats.deleted, <List<String>>[
      <String>['c1', 'c2', 'c3'],
    ]);
  });

  testWidgets('3. rename from the row menu saves through the source', (
    tester,
  ) async {
    await pumpSidebar(tester, h);
    await tester.tap(find.text('Chat 4'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Roadmap');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(chats.renamed, <String>['c4:Roadmap']);
  });

  testWidgets('4. See more adds five rows, See less returns to five', (
    tester,
  ) async {
    await pumpSidebar(tester, h);
    expect(find.text('Chat 6'), findsNothing);
    await tester.tap(find.text('See more'));
    await tester.pump();
    expect(find.text('Chat 7'), findsOneWidget);
    await tester.tap(find.text('See less'));
    await tester.pump();
    expect(find.text('Chat 6'), findsNothing);
  });

  group('collapsed rail', () {
    late SidebarServices services;

    Future<void> pumpRail(WidgetTester tester, {required bool collapsed}) =>
        tester.pumpWidget(
          sidebarApp(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: collapsed ? 48 : 224,
                height: 900,
                child: SidebarEnvironment(
                  services: services,
                  child: WorkspaceSidebar(
                    workspaceId: workspaceId,
                    collapsed: collapsed,
                  ),
                ),
              ),
            ),
          ),
        );

    Future<TestGesture> hoverChats(WidgetTester tester) async {
      final chip = tester.getRect(byParity('shell.sidebar.rail.chats'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(600, 600));
      await mouse.moveTo(chip.center);
      await tester.pump();
      return mouse;
    }

    setUp(() async {
      services = h.services();
    });

    testWidgets('5. rail Rename shows an input, saves and unlocks', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(h.load);
      await pumpRail(tester, collapsed: true);
      await tester.pump();
      final mouse = await hoverChats(tester);
      expect(byParity('shell.sidebar.rail.flyout'), findsOneWidget);
      await tester.tap(find.text('Chat 2'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(byParity('shell.sidebar.rail.flyout'), findsOneWidget);
      final input = find.byType(EditableText);
      expect(input, findsOneWidget);
      await tester.enterText(input, 'Plans');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chats.renamed, <String>['c2:Plans']);
      await mouse.moveTo(const Offset(600, 600));
      await tester.pump(const Duration(milliseconds: 200));
      expect(byParity('shell.sidebar.rail.flyout'), findsNothing);
      await mouse.removePointer();
    });

    testWidgets('6. a collapse / expand round trip keeps the flyout working', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(h.load);
      await pumpRail(tester, collapsed: true);
      await tester.pump();
      final mouse = await hoverChats(tester);
      expect(byParity('shell.sidebar.rail.flyout'), findsOneWidget);
      await mouse.moveTo(const Offset(600, 600));
      await pumpRail(tester, collapsed: false);
      await tester.pump();
      await pumpRail(tester, collapsed: true);
      await tester.pump();
      expect(byParity('shell.sidebar.rail.flyout'), findsNothing);
      final chip = tester.getSemantics(
        find.descendant(
          of: byParity('shell.sidebar.rail.chats'),
          matching: find.bySemanticsLabel('Chats'),
        ),
      );
      expect(chip.flagsCollection.isSelected, isNot(Tristate.isTrue));
      await mouse.moveTo(
        tester.getCenter(byParity('shell.sidebar.rail.chats')),
      );
      await tester.pump();
      expect(byParity('shell.sidebar.rail.flyout'), findsOneWidget);
      await mouse.removePointer();
    });
  });

  testWidgets('7. an overflow flip keeps the section state', (tester) async {
    chats = FakeChats(15);
    h.chats = chats;
    await pumpSidebar(tester, h, height: 820);
    final scrollable = find.descendant(
      of: byParity('shell.sidebar.scroll'),
      matching: find.byType(Scrollable),
    );
    ScrollPosition position() =>
        tester.state<ScrollableState>(scrollable.first).position;
    expect(position().maxScrollExtent, 0, reason: 'fits before See more');
    await tester.tap(find.text('See more'));
    await tester.pump();
    await tester.pump();
    expect(position().maxScrollExtent, greaterThan(0));
    expect(find.text('Chat 10'), findsOneWidget);
  });
}
