// Failure modes (home-page.md States/Interactions 46-47, 53, 56;
// home/page.tsx, home/layout.tsx, chat/[chatId]/{page,layout}.tsx,
// chat-url.ts, use-chat.ts:1356-1365):
// - /home or /chat/<id> still renders the shell placeholder
// - chat disabled: /home renders instead of redirecting to /workspace/<id>
//   (which resolves to /w); /chat/<id> renders a chat instead of the 404
// - the document title is not "New chat | Sim" / "Chat | Sim"
// - the new chat's adoption pushes a history entry (on the web the engine
//   gets `routeInformationUpdated` without `replace`: the chat route's
//   async redirect makes the parse finish after Router.neglect's report,
//   so Back returns to /home) or remounts the page
//   (the turn streaming in it would be lost), drops `?resource=`, or keeps
//   other query params
// - another chat (or /home after a chat) reuses the old mount, so its
//   session leaks into the next chat
// - the routed chat is not marked read on mount, or is marked again on
//   every rebuild
// - the transform drops or reorders the shell's other routes

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_app/features/home/home_page.dart';
import 'package:sim_app/features/home/home_routes.dart';
import 'package:sim_app/features/home/models.dart';
import 'package:sim_app/features/workspace_shell/routes.dart';

import 'support/home_harness.dart';

String? _title(WidgetTester tester) {
  final titles = tester.widgetList<Title>(find.byType(Title)).toList();
  return titles.isEmpty ? null : titles.last.title;
}

void main() {
  late HomeHarness h;

  setUp(() async {
    h = HomeHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  test('withHomeRoutes replaces only home and chat, in place', () {
    List<String> paths(List<RouteBase> routes) => <String>[
      for (final r in (routes.single as ShellRoute).routes)
        if (r is GoRoute) r.path,
    ];
    final original = workspaceShellRoutes();
    final transformed = withHomeRoutes(workspaceShellRoutes());
    expect(paths(transformed), paths(original));
    final shell = transformed.single as ShellRoute;
    final home = shell.routes.whereType<GoRoute>().firstWhere(
      (r) => r.path == HomePaths.home,
    );
    final chat = shell.routes.whereType<GoRoute>().firstWhere(
      (r) => r.path == HomePaths.chat,
    );
    expect(home.pageBuilder, isNotNull);
    expect(chat.pageBuilder, isNotNull);
    expect(
      shell.routes.whereType<GoRoute>().where((r) => r.path.endsWith('/w')),
      hasLength(1),
    );
  });

  testWidgets('/home renders the Home page with its title', (tester) async {
    await h.pump(tester, homePath);
    expect(byParityId('home.page'), findsOneWidget);
    expect(byParityId('home.empty'), findsOneWidget);
    expect(byParityId('shell.placeholder'), findsNothing);
    expect(_title(tester), 'New chat | Sim');
    expect(h.sessions, hasLength(1));
    expect(h.session.request.chatId, isNull);
    expect(h.markedRead, isEmpty);
  });

  testWidgets('/chat/<id> opens that chat, titled "Chat | Sim", marked read '
      'once', (tester) async {
    await h.pump(tester, chatPath);
    expect(byParityId('home.page'), findsOneWidget);
    expect(_title(tester), 'Chat | Sim');
    expect(h.session.request.chatId, seededChatId);
    expect(h.markedRead, <String>[seededChatId]);
    h.session.setSending(sending: true);
    await settle(tester);
    expect(h.markedRead, <String>[seededChatId]);
    h.session.setSending(sending: false);
    await settle(tester);
    expect(
      h.markedRead,
      <String>[seededChatId, seededChatId],
      reason: 'a finished send marks the chat read again',
    );
  });

  testWidgets('chat disabled: /home redirects to the workspace (→ /w)', (
    tester,
  ) async {
    h
      ..chatEnabled = false
      ..stubDeployment();
    await h.pump(tester, homePath);
    expect(h.location, '/workspace/$workspaceId/w');
    expect(byParityId('home.page'), findsNothing);
  });

  testWidgets('chat disabled: /chat/<id> is the workspace 404', (tester) async {
    h
      ..chatEnabled = false
      ..stubDeployment();
    await h.pump(tester, chatPath);
    expect(byParityId('home.not-found'), findsOneWidget);
    expect(find.text('Page not found'), findsOneWidget);
    expect(h.sessions, isEmpty);
  });

  testWidgets('the new chat moves its URL in place, keeping ?resource= and '
      'the mount', (tester) async {
    await h.pump(tester, '$homePath?resource=r1&other=x');
    final first = h.session;
    final visitsBefore = h.shell.visited.length;
    first.adoptChatId('chat-new');
    await settle(tester);
    expect(h.location, '/workspace/$workspaceId/chat/chat-new?resource=r1');
    expect(h.sessions, hasLength(1), reason: 'no remount');
    expect(first.isDisposed, isFalse);
    expect(_title(tester), 'Chat | Sim');
    // `replaceState`: the old entry is gone, Back has nothing new to pop.
    expect(h.router.canPop(), isFalse);
    expect(h.shell.visited.length, greaterThan(visitsBefore));
  });

  testWidgets('the adoption rewrite reaches the engine as a replace, not a '
      'push (browser history)', (tester) async {
    final reports = <Map<Object?, Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method == 'routeInformationUpdated') {
          reports.add(call.arguments as Map<Object?, Object?>);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      ),
    );
    await h.pump(tester, homePath);
    reports.clear();
    h.session.adoptChatId('chat-new');
    await settle(tester);
    const chatUri = '/workspace/$workspaceId/chat/chat-new';
    final toChat = reports.where((r) => r['uri'] == chatUri).toList();
    expect(toChat, isNotEmpty, reason: 'the engine learns the chat URL');
    expect(
      toChat.every((r) => r['replace'] == true),
      isTrue,
      reason: 'reports: $reports',
    );
    expect(
      reports.where((r) => r['replace'] != true),
      isEmpty,
      reason: 'no push at all: $reports',
    );
  });

  testWidgets('a ?resource= rewrite on a routed chat also replaces', (
    tester,
  ) async {
    final reports = <Map<Object?, Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method == 'routeInformationUpdated') {
          reports.add(call.arguments as Map<Object?, Object?>);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      ),
    );
    await h.pump(tester, chatPath);
    reports.clear();
    tester
        .state<HomeContentState>(find.byType(HomeContent))
        .panel
        .addFromUser(
          const HomeResource(
            type: HomeResourceType.table,
            id: 'table-a',
            title: 'Table A',
          ),
        );
    await settle(tester);
    expect(h.location, contains('resource='));
    expect(reports, isNotEmpty);
    expect(
      reports.where((r) => r['replace'] != true),
      isEmpty,
      reason: 'reports: $reports',
    );
  });

  testWidgets(
    'a ?resource= rewrite on /home (async chat-enabled redirect) also '
    'replaces',
    (
      tester,
    ) async {
      final reports = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (call) async {
          if (call.method == 'routeInformationUpdated') {
            reports.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.navigation,
          null,
        ),
      );
      await h.pump(tester, homePath);
      reports.clear();
      tester
          .state<HomeContentState>(find.byType(HomeContent))
          .panel
          .addFromUser(
            const HomeResource(
              type: HomeResourceType.table,
              id: 'table-a',
              title: 'Table A',
            ),
          );
      await settle(tester);
      expect(h.location, contains('resource='));
      expect(reports, isNotEmpty);
      expect(
        reports.where((r) => r['replace'] != true),
        isEmpty,
        reason: 'reports: $reports',
      );
    },
  );

  testWidgets('another chat remounts; /home after a chat remounts', (
    tester,
  ) async {
    await h.pump(tester, chatPath);
    final first = h.session;
    h.router.go('/workspace/$workspaceId/chat/other-chat');
    await settle(tester);
    expect(h.sessions, hasLength(2));
    expect(first.isDisposed, isTrue);
    expect(h.session.request.chatId, 'other-chat');
    h.router.go(homePath);
    await settle(tester);
    expect(h.sessions, hasLength(3));
    expect(h.session.request.chatId, isNull);
  });

  test('chat URLs carry only the resource param', () {
    expect(homeChatUrl('ws', 'c'), '/workspace/ws/chat/c');
    expect(
      homeChatUrl('ws', 'c', resource: 'a b'),
      '/workspace/ws/chat/c?resource=a+b',
    );
    expect(homeUrl('ws', resource: 'r'), '/workspace/ws/home?resource=r');
    expect(homeDocumentTitle(chatRoute: false), 'New chat | Sim');
    expect(homeDocumentTitle(chatRoute: true, brand: 'Acme'), 'Chat | Acme');
  });
}
