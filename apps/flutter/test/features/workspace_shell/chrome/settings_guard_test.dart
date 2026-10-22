// Failure modes (global-behaviours.md "Settings dirty guard",
// settings-navigation-guard.tsx):
// - a clean surface still asks, or a dirty one navigates without asking
// - "Keep editing" / Escape navigates anyway or forgets the dirty state
// - "Discard changes" does not discard the dirty drafts before leaving
// - a blocked surface lets the leave through (or opens the dialog)
// - a history traversal (`discardOnConfirm: false`) discards on confirm
// - the dialog stays open after the editor turned clean
// - a link to the current location is guarded

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_dirty_store.dart';
import 'package:sim_app/features/workspace_shell/chrome/settings_navigation_guard.dart';

import 'support/shell_harness.dart';

const String settings = '/workspace/$workspaceId/settings/general';
const String logs = '/workspace/$workspaceId/logs';

void main() {
  late ShellHarness h;
  late SettingsDirtyStore store;
  late int discards;

  setUp(() async {
    h = ShellHarness();
    await h.setUp();
    store = locator<SettingsDirtyStore>();
    discards = 0;
  });

  tearDown(() => h.tearDown());

  void markDirty({bool blocked = false}) => store.setGuard(
    'general',
    SettingsGuard(
      isDirty: true,
      navigationBlocked: blocked,
      onDiscard: () => discards++,
    ),
  );

  bool go(WidgetTester tester, String location) => guardedGo(
    tester.element(find.text('Settings: general')),
    location,
    store: store,
  );

  testWidgets('clean: navigates at once without a dialog', (tester) async {
    await h.pump(tester, settings);
    await tester.pumpAndSettle();
    expect(go(tester, logs), isTrue);
    await tester.pumpAndSettle();
    expect(h.location, logs);
    expect(byParityId('shell.dirty-guard.modal'), findsNothing);
  });

  testWidgets('dirty: Keep editing and Escape stay, Discard leaves', (
    tester,
  ) async {
    await h.pump(tester, settings);
    await tester.pumpAndSettle();
    markDirty();

    expect(go(tester, logs), isFalse);
    await tester.pumpAndSettle();
    expect(byParityId('shell.dirty-guard.modal'), findsOneWidget);
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(byParityId('shell.dirty-guard.modal'), findsNothing);
    expect(h.location, settings);
    expect(store.isDirty, isTrue);
    expect(store.hasPendingLeave, isFalse);

    go(tester, logs);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(byParityId('shell.dirty-guard.modal'), findsNothing);
    expect(h.location, settings);

    go(tester, logs);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(discards, 1);
    expect(h.location, logs);
    expect(byParityId('shell.dirty-guard.modal'), findsNothing);
  });

  testWidgets('blocked: refuses without a dialog', (tester) async {
    await h.pump(tester, settings);
    await tester.pumpAndSettle();
    markDirty(blocked: true);
    expect(go(tester, logs), isFalse);
    await tester.pumpAndSettle();
    expect(byParityId('shell.dirty-guard.modal'), findsNothing);
    expect(h.location, settings);
  });

  testWidgets('the dialog closes once the editor turns clean', (tester) async {
    await h.pump(tester, settings);
    await tester.pumpAndSettle();
    markDirty();
    go(tester, logs);
    await tester.pumpAndSettle();
    expect(byParityId('shell.dirty-guard.modal'), findsOneWidget);
    store.removeGuard('general');
    await tester.pumpAndSettle();
    expect(byParityId('shell.dirty-guard.modal'), findsNothing);
    expect(h.location, settings);
  });

  testWidgets('same location is not guarded', (tester) async {
    await h.pump(tester, settings);
    await tester.pumpAndSettle();
    markDirty();
    expect(go(tester, settings), isFalse);
    await tester.pumpAndSettle();
    expect(byParityId('shell.dirty-guard.modal'), findsNothing);
  });

  test('history traversals do not discard on confirm', () {
    final s = SettingsDirtyStore()
      ..setGuard(
        'g',
        SettingsGuard(isDirty: true, onDiscard: () => discards++),
      );
    var left = 0;
    expect(s.requestLeave(() => left++, discardOnConfirm: false), isFalse);
    s.confirmLeave();
    expect(left, 1);
    expect(discards, 0);
  });

  testWidgets('the registered navigator is used; goUnguarded skips the guard', (
    tester,
  ) async {
    await h.pump(tester, settings);
    await tester.pumpAndSettle();
    final navigator = ShellNavigator(router: h.router, dirty: store);
    locator.registerSingleton<ShellNavigator>(navigator);
    expect(
      ShellNavigator.of(tester.element(find.text('Settings: general'))),
      same(navigator),
    );
    markDirty();
    navigator.goUnguarded(logs);
    await tester.pumpAndSettle();
    expect(h.settledLocation, logs);
    expect(byParityId('shell.dirty-guard.modal'), findsNothing);
  });
}
