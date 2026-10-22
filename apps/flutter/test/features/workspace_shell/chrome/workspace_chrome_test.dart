// Failure modes (workspace-chrome.md "States", global-behaviours.md
// "Session expiry", "Impersonation banner", "Access-denied pages",
// workspace-permissions-provider toasts):
// - a host-context 403 renders the shell (or navigates) instead of
//   replacing it with the access-denied page; its CTA (shell → picker →
//   granted shell) crashes on a doubly mounted shell navigator key
// - the session-expired takeover paints under the toasts or a modal
// - the connection toasts: more than one realtime toast, a realtime toast
//   while offline, the offline toast hidden on a file viewer, or a toast
//   the user closed raised again while its condition holds
// - a failed feature-flags load (404 on an older server, 403) denies access
//   instead of falling back to all flags off
// - the shell renders before the host context resolved (no loading surface)
// - the sidebar's workflow and folder lists wait for the host context
//   (a waterfall) instead of starting with it
// - a live session settling to null does not take over, does not sign out
//   and wipe, or does not land on /login; a failed sign-out has no retry
// - a failed session refetch (offline, 5xx) is mistaken for an expiry
// - the impersonation banner is missing, or "Stop impersonating" does not
//   clear (keeping recent impersonations) and go to /home
// - a socket blip under 2 s raises "Reconnecting...", a longer one does not,
//   or the toast is swept by navigation; offline toasts lack "Refresh"
// - unmounting the shell leaves the persistent toasts behind
// - Mod+B / Mod+K / Mod+L do not reach the sidebar, palette and router

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/features/workspace_shell/chrome/search_palette_controller.dart';
import 'package:sim_app/features/workspace_shell/chrome/sidebar_controller.dart';
import 'package:sim_design/sim_design.dart';

import 'support/shell_harness.dart';

const String home = '/workspace/$workspaceId/home';

/// Toast messages render as rich text (icon span + message).
Finder toastText(String text) => find.textContaining(text, findRichText: true);

void main() {
  late ShellHarness h;

  setUp(() async {
    h = ShellHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  testWidgets('host-context 403 replaces the shell without navigating', (
    tester,
  ) async {
    when(
      () =>
          h.runtime.hostContext(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => WorkspaceAccess.denied(error: apiError(403)));
    await h.pump(tester, home);
    await tester.pumpAndSettle();
    expect(byParityId('shell.access-denied'), findsOneWidget);
    expect(byParityId('shell.chrome'), findsNothing);
    expect(h.location, home);
  });

  // Regression (review finding 8): shell → picker → shell used to mount the
  // shell navigator's GlobalKey twice unless the picker waited an extra
  // frame; the picker now resolves in a router redirect (shell → shell).
  testWidgets('access denied → "Go to workspaces" → a granted workspace', (
    tester,
  ) async {
    when(
      () => h.runtime.hostContext(
        workspaceId,
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => WorkspaceAccess.denied(error: apiError(403)));
    when(
      () => h.workspacesRepo.list(
        scope: any(named: 'scope'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => workspaceList(lastActiveWorkspaceId: otherWorkspaceId),
    );
    await h.pump(tester, home);
    await tester.pumpAndSettle();
    expect(byParityId('shell.access-denied'), findsOneWidget);

    await tester.tap(byParityId('shell.access-denied.cta'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(h.location, '/workspace/$otherWorkspaceId/home');
    expect(byParityId('shell.chrome'), findsOneWidget);
    expect(byParityId('shell.access-denied'), findsNothing);
  });

  // Regression (live run 2026-10-22): a server without the feature-flags
  // endpoint answers 404; access is gated on the host context only
  // (layout.tsx), so the shell must render with every flag off.
  // The same constraint from a live shell (its nested navigator mounted):
  // a picker visit must resolve without an intermediate page.
  testWidgets('a mounted shell → /workspace → another workspace', (
    tester,
  ) async {
    when(
      () => h.workspacesRepo.list(
        scope: any(named: 'scope'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => workspaceList(lastActiveWorkspaceId: otherWorkspaceId),
    );
    await h.pump(tester, home);
    await tester.pumpAndSettle();
    expect(byParityId('shell.chrome'), findsOneWidget);

    h.router.go('/workspace');
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(h.settledLocation, '/workspace/$otherWorkspaceId/home');
    expect(byParityId('shell.chrome'), findsOneWidget);
  });

  testWidgets('feature-flags 404/403 does not deny access; flags default off', (
    tester,
  ) async {
    when(
      () =>
          h.runtime.featureFlags(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) async => FeatureFlagsDenied(apiError(404)));
    await h.pump(tester, home);
    await tester.pumpAndSettle();
    expect(byParityId('shell.access-denied'), findsNothing);
    expect(byParityId('shell.chrome'), findsOneWidget);
  });

  testWidgets('loading surface until the host context resolves', (
    tester,
  ) async {
    final completer = Completer<WorkspaceAccess>();
    when(
      () =>
          h.runtime.hostContext(any(), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer((_) => completer.future);
    await h.pump(tester, home);
    expect(byParityId('shell.loading'), findsOneWidget);
    expect(byParityId('shell.chrome'), findsNothing);
    // Regression (review finding 6): the sidebar's lists are requested
    // with the host context, not after it (the sidebar mounts behind it).
    verify(
      () => h.workflowsRepo.list(
        workspaceId: workspaceId,
        scope: any(named: 'scope'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    verify(
      () => h.foldersRepo.list(
        workspaceId: workspaceId,
        scope: any(named: 'scope'),
        resourceType: any(named: 'resourceType'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
    completer.complete(WorkspaceAccess.granted(hostContext()));
    await tester.pumpAndSettle();
    expect(byParityId('shell.loading'), findsNothing);
    expect(byParityId('shell.chrome'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  group('session expiry', () {
    testWidgets('a live session settling to null signs out, wipes, /login', (
      tester,
    ) async {
      await h.pump(tester, home);
      await tester.pumpAndSettle();
      expect(byParityId('shell.session-expired'), findsNothing);

      final gate = Completer<void>();
      h.actionsLog.signOutGate = gate;
      h.sessionCubit.setSession(null);
      await tester.pump();
      await tester.pump();
      expect(byParityId('shell.session-expired'), findsOneWidget);
      expect(
        find.text('Your session expired. Signing you out…'),
        findsOneWidget,
      );
      expect(h.actionsLog.signOuts, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(h.actionsLog.signOuts, 1);
      expect(h.actionsLog.clears, 1);
      expect(h.location, '/login');
    });

    testWidgets('a failed sign-out shows the retry state', (tester) async {
      h.actionsLog.signOutFails = true;
      await h.pump(tester, home);
      await tester.pumpAndSettle();
      h.sessionCubit.setSession(null);
      await tester.pumpAndSettle();
      expect(
        find.text('Your session expired, but signing out failed.'),
        findsOneWidget,
      );
      expect(h.actionsLog.clears, 0, reason: 'nothing wiped without sign-out');
      expect(h.location, home);

      h.actionsLog.signOutFails = false;
      await tester.tap(byParityId('shell.session-expired.retry'));
      await tester.pumpAndSettle();
      expect(h.actionsLog.signOuts, 2);
      expect(h.location, '/login');
    });

    // Regression (review finding 10): the takeover is the overlay's z-500
    // layer, above the toast stack and an open modal.
    testWidgets('the takeover covers toasts and modals', (tester) async {
      await h.pump(tester, home);
      await tester.pumpAndSettle();
      final context = tester.element(byParityId('shell.chrome'));
      h.toasts.error('Reconnecting...', duration: Duration.zero);
      unawaited(
        showSimChipModal<void>(
          context,
          semanticsLabel: 'Open modal',
          builder: (context) => const SizedBox(width: 200, height: 100),
        ),
      );
      await tester.pumpAndSettle();
      h.actionsLog.signOutGate = Completer<void>();
      h.sessionCubit.setSession(null);
      await tester.pump();
      await tester.pump();
      expect(byParityId('shell.session-expired'), findsOneWidget);
      final layers = SimOverlay.of(context).entries;
      expect(layers.last.z, SimZ.takeover);
      expect(
        find.descendant(
          of: byParityId('shell.viewport'),
          matching: byParityId('shell.session-expired'),
        ),
        findsNothing,
        reason: 'not painted inside the routed page under the toast stack',
      );
      h.actionsLog.signOutGate!.complete();
      await tester.pumpAndSettle();
      expect(h.location, '/login');
    });

    testWidgets('a failed refetch is not an expiry', (tester) async {
      await h.pump(tester, home);
      await tester.pumpAndSettle();
      when(
        () => h.auth.getSession(
          disableCookieCache: any(named: 'disableCookieCache'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(const ApiNetworkError('offline'));
      h.now = h.now.add(const Duration(minutes: 6));
      await h.sessionCubit.onFocus();
      await tester.pumpAndSettle();
      expect(h.sessionCubit.state.hasError, isTrue);
      expect(byParityId('shell.session-expired'), findsNothing);
      expect(h.actionsLog.signOuts, 0);
    });
  });

  testWidgets('impersonation banner stops, clears and goes home', (
    tester,
  ) async {
    when(
      () => h.auth.getSession(
        disableCookieCache: any(named: 'disableCookieCache'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => session(impersonatedBy: 'admin-1'));
    await h.pump(tester, home);
    await tester.pump(const Duration(milliseconds: 10));
    expect(byParityId('shell.banner.impersonation'), findsOneWidget);
    expect(find.textContaining('Impersonating this user'), findsOneWidget);

    await tester.tap(byParityId('shell.banner.impersonation.action'));
    await tester.pump();
    await tester.pump();
    expect(h.actionsLog.stops, 1);
    expect(h.actionsLog.preservedImpersonations, isTrue);
    expect(h.requested, contains('/home'));
    h.sessionCubit.reset();
  });

  group('connection toasts', () {
    testWidgets('Reconnecting... only after 2 s and survives navigation', (
      tester,
    ) async {
      await h.pump(tester, home);
      await tester.pumpAndSettle();
      h.permissionsCubit.setSocketState(isReconnecting: true);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(toastText('Reconnecting...'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(toastText('Reconnecting...'), findsOneWidget);
      final toast = h.toasts.toasts.single;
      expect(toast.persistAcrossRoutes, isTrue);
      expect(toast.duration, Duration.zero);

      h.router.go('/workspace/$workspaceId/logs');
      await tester.pumpAndSettle();
      h.toasts.sweepRoute();
      await tester.pump();
      expect(toastText('Reconnecting...'), findsOneWidget);

      h.permissionsCubit.setSocketState(isReconnecting: false);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      expect(h.toasts.toasts, isEmpty);
    });

    testWidgets('offline toast carries the description and Refresh', (
      tester,
    ) async {
      await h.pump(tester, home);
      await tester.pumpAndSettle();
      h.permissionsCubit.setOperationError(hasError: true);
      await tester.pumpAndSettle();
      expect(toastText('Connection unavailable'), findsOneWidget);
      expect(
        find.text('Recent changes may not have been saved. Refresh to resync.'),
        findsOneWidget,
      );
      expect(find.text('Refresh'), findsOneWidget);
      expect(h.permissionsCubit.state.userPermissions.canEdit, isFalse);

      h.router.go('/login');
      await tester.pumpAndSettle();
      expect(h.toasts.toasts, isEmpty, reason: 'dismissed with the shell');
    });

    List<String> shown() => [for (final t in h.toasts.toasts) t.message];

    // Regression (review finding 4): one realtime slot, Reconnecting over
    // Joining, and no realtime status while offline.
    testWidgets('one realtime slot; offline hides it', (tester) async {
      await h.pump(tester, home);
      await tester.pumpAndSettle();
      h.permissionsCubit.setSocketState(
        isReconnecting: true,
        isRetryingWorkflowJoin: true,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(shown(), ['Reconnecting...']);

      h.permissionsCubit.setOperationError(hasError: true);
      await tester.pump();
      expect(shown(), ['Connection unavailable']);
    });

    testWidgets('on a file viewer the offline toast still shows', (
      tester,
    ) async {
      await h.pump(tester, home);
      await tester.pumpAndSettle();
      h.permissionsCubit
        ..setRoute(isFileViewer: true)
        ..setSocketState(isRetryingWorkflowJoin: true)
        ..setOperationError(hasError: true);
      await tester.pump();
      expect(shown(), ['Connection unavailable']);
    });

    testWidgets('a dismissed toast stays dismissed while another appears', (
      tester,
    ) async {
      await h.pump(tester, home);
      await tester.pumpAndSettle();
      h.permissionsCubit.setSocketState(isRetryingWorkflowJoin: true);
      await tester.pump();
      expect(shown(), ['Joining workflow...']);
      h.toasts.dismiss(h.toasts.toasts.single.id);
      await tester.pump();

      h.permissionsCubit.setSocketState(
        blockedJoinWorkflowId: 'wf-1',
      );
      h.permissionsCubit.setRoute(workflowId: 'wf-1');
      await tester.pump();
      expect(
        shown(),
        ['Unable to connect to workflow'],
        reason: 'the closed "Joining workflow..." is not raised again',
      );

      h.permissionsCubit.setSocketState(isRetryingWorkflowJoin: false);
      await tester.pump();
      h.permissionsCubit.setSocketState(isRetryingWorkflowJoin: true);
      await tester.pump();
      expect(
        shown(),
        ['Unable to connect to workflow', 'Joining workflow...'],
        reason: 'once its condition cleared, the slot raises it again',
      );
    });
  });

  testWidgets('Mod+B, Mod+K and Mod+L reach sidebar, palette and router', (
    tester,
  ) async {
    await h.pump(tester, home);
    await tester.pumpAndSettle();
    final sidebar = locator<SidebarController>();
    final palette = locator<SearchPaletteController>();

    Future<bool> chord(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final handled = await tester.sendKeyDownEvent(key);
      await tester.sendKeyUpEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      return handled;
    }

    expect(await chord(LogicalKeyboardKey.keyB), isTrue);
    expect(sidebar.isCollapsed, isTrue);
    expect(
      tester.getSize(byParityId('shell.sidebar.shell')).width,
      SidebarWidth.collapsed,
    );
    expect(await chord(LogicalKeyboardKey.keyK), isTrue);
    expect(palette.isOpen, isTrue);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      focused?.findAncestorStateOfType<EditableTextState>(),
      isNotNull,
      reason: "the palette's input has focus",
    );
    expect(await chord(LogicalKeyboardKey.keyK), isTrue);
    expect(palette.isOpen, isFalse, reason: 'Mod+K toggles from the input');
    expect(await chord(LogicalKeyboardKey.keyL), isTrue);
    expect(h.location, '/workspace/$workspaceId/logs');
  });
}
