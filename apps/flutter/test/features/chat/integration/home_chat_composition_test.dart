// The real composition of Phase 1.5: SimApp with the app's own locator
// wiring (chat integration, real Home slots, real workspace shell), only the
// repositories and the mothership client replaced; the client replays the
// engine fixtures.
//
// Failure modes:
// - the slots are not registered, so Home renders the placeholders (no
//   `chat.message.*` rows, no `chat-input.*` ids);
// - typing + Enter in the composer never reaches the engine, or reaches it
//   without the text;
// - the user row, the streamed text, the tool row or the settled actions
//   row is missing (adapter drops segments, the transcript is not fed);
// - the new chat's id is not written to the URL (`onChatResolved` lost);
// - a second message in the same chat does not stream (session state not
//   reset after the first turn);
// - Stop does not abort or the stopped row is missing;
// - the permission card's Allow does not post the decision or the turn
//   does not continue;
// - opening `/workspace/<ws>/chat/<id>` does not render the stored history;
// - a stored question card answered by the next user turn renders as the
//   live form plus a duplicate answer bubble instead of the recap, or an
//   inline `files/…` image loads the raw path instead of the chat image
//   route of its turn (`privateImageUrls`).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/app/app.dart';
import 'package:sim_app/app/locator.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/integration/chat_events_host.dart';
import 'package:sim_app/features/chat/integration/chat_integration.dart';
import 'package:sim_app/features/home/home_services.dart';
import 'package:sim_design/sim_design.dart';

import '../../../data/support/mocks.dart' show workspaceId;
import '../engine/support/fixtures.dart';
import 'support/real_app.dart';
import 'support/scripted_client.dart';

const String homePath = '/workspace/$workspaceId/home';

late ScriptedMothershipClient client;

Future<void> _configure() async {
  await configureRealLocator();
  final queries = locator<QueryClient>();
  client = ScriptedMothershipClient(queries);
  var ids = 0;
  if (locator.isRegistered<MothershipClient>()) {
    await locator.unregister<MothershipClient>();
  }
  if (locator.isRegistered<ChatIntegration>()) {
    await locator.unregister<ChatIntegration>();
  }
  locator
    ..registerSingleton<MothershipClient>(client)
    ..registerSingleton<ChatClientOverride>(const ChatClientOverride())
    ..registerSingleton<ChatIntegration>(
      ChatIntegration(
        client: client,
        queries: queries,
        storages: ChatStorages.memory(),
        browserReturns: const Stream.empty(),
        onlineEvents: const Stream.empty(),
        isOnline: () => true,
        idGenerator: () => 'u-${ids++}',
      ),
    );
  HomeServices.resetShared();
  ChatEventsCubit.resetSubscriptionHistory();
}

Finder byParity(String identifier) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == identifier,
  description: 'parity id $identifier',
);

Finder text(String value) => find.textContaining(value, findRichText: true);

String location(WidgetTester tester) => GoRouter.of(
  tester.element(find.byType(Navigator).first),
).routerDelegate.currentConfiguration.uri.path;

Future<void> settle(WidgetTester tester, {int rounds = 20}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> boot(WidgetTester tester, {String path = homePath}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final scale = SimMotion.scale;
  SimMotion.scale = 0;
  addTearDown(() => SimMotion.scale = scale);
  await tester.pumpWidget(const SimApp());
  await settle(tester);
  GoRouter.of(tester.element(find.byType(Navigator).first)).go(path);
  await settle(tester);
}

/// Types [message] into the composer and presses Enter.
Future<void> send(WidgetTester tester, String message) async {
  final editor = find.descendant(
    of: byParity('chat-input.root'),
    matching: find.byType(EditableText),
  );
  expect(editor, findsOneWidget, reason: 'the real composer is mounted');
  await tester.tap(editor);
  await tester.pump();
  await tester.enterText(editor, message);
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await settle(tester);
}

void main() {
  setUp(_configure);
  tearDown(locator.reset);

  testWidgets(
    'Home: Enter sends, the turn streams with a tool row and settles with '
    'actions, the URL becomes /chat/<id>, a second message streams too',
    (tester) async {
      client.script.addAll(['tool_call_success', 'plain_text_answer']);
      await boot(tester);
      expect(byParity('home.page'), findsOneWidget);

      await send(tester, 'Find foo please');
      expect(client.sends.single.message, 'Find foo please');
      expect(byParity('chat.message.user'), findsOneWidget);
      expect(text('Find foo please'), findsWidgets);
      expect(text('Found 3 matches.'), findsOneWidget);
      expect(byParity('chat.tool.call'), findsWidgets);
      expect(byParity('chat.message.actions'), findsOneWidget);
      expect(location(tester), '/workspace/$workspaceId/chat/chat-1');

      final firstAnswer = client.turns.single;
      expect(firstAnswer.done, isTrue);

      await send(tester, 'And now?');
      expect(client.sends, hasLength(2));
      expect(client.sends.last.chatId, 'chat-1');
      expect(byParity('chat.message.user'), findsNWidgets(2));
      final plain = loadFixtureText('plain_text_answer');
      expect(text(plain), findsOneWidget);
      expect(byParity('chat.message.actions'), findsNWidgets(2));
    },
  );

  testWidgets('Stop mid-stream aborts and shows the stopped row', (
    tester,
  ) async {
    client.script.add('stop_mid_stream');
    await boot(tester);
    await send(tester, 'Run something long');
    expect(text('Working on it.'), findsOneWidget);
    expect(client.turns.single.done, isFalse, reason: 'awaiting the stop');

    await tester.tap(byParity('chat-input.send'));
    await settle(tester);
    expect(client.calls.any((c) => c.startsWith('abort')), isTrue);
    expect(client.turns.single.sse.cancelled, isTrue);
    client.turns.single.advance();
    await settle(tester);
    expect(byParity('chat.message.stopped'), findsOneWidget);
    // The stopped row, and the cancelled tool row (React titles it the same).
    expect(text('Stopped by user'), findsNWidgets(2));
  });

  testWidgets('a permission prompt: Allow posts the decision and the turn '
      'continues', (tester) async {
    client.script.add('permission_requested_then_allowed');
    await boot(tester);
    await send(tester, 'Delete the workflow');
    expect(byParity('chat.tool.permission'), findsOneWidget);

    await tester.tap(find.text('Allow').first);
    await settle(tester);
    expect(client.calls, contains('permission t-perm=allow'));

    client.turns.single.advance();
    await settle(tester);
    expect(text('Deleted.'), findsOneWidget);
    expect(byParity('chat.tool.permission'), findsNothing);
  });

  testWidgets('opening a chat route renders the stored history', (
    tester,
  ) async {
    client.histories['chat-seeded'] = MothershipChatHistory.fromJson(const {
      'success': true,
      'chat': {
        'id': 'chat-seeded',
        'title': 'E2E conversation',
        'messages': [
          {
            'id': 'm-user',
            'role': 'user',
            'content': 'Summarise the seeded workspace for me.',
          },
          {
            'id': 'm-assistant',
            'role': 'assistant',
            'content':
                'Here is the summary.\n\n| Item | Count |\n| --- | --- |\n'
                '| Workflows | 4 |\n\n```json\n{"seeded":true}\n```\n',
          },
        ],
        'resources': <Object?>[],
      },
    });
    await boot(tester, path: '/workspace/$workspaceId/chat/chat-seeded');
    expect(text('Summarise the seeded workspace for me.'), findsOneWidget);
    expect(text('Here is the summary.'), findsOneWidget);
    expect(byParity('chat.table'), findsOneWidget);
    expect(byParity('chat.code'), findsOneWidget);
    expect(byParity('chat.message.actions'), findsOneWidget);
  });

  testWidgets('stored history: an answered question renders its recap with '
      'the answer bubble hidden; inline images load the chat image route', (
    tester,
  ) async {
    const question =
        '<question>[{"type":"single_select","prompt":"Which region?", '
        '"options":[{"id":"eu","label":"EU"},{"id":"us","label":"US"}]}]'
        '</question>';
    client.histories['chat-q'] = MothershipChatHistory.fromJson(const {
      'success': true,
      'chat': {
        'id': 'chat-q',
        'title': 'Pairing',
        'messages': [
          {'id': 'm1', 'role': 'user', 'content': 'Set it up'},
          {
            'id': 'm2',
            'role': 'assistant',
            'content': 'One question.\n$question',
            'requestId': 'req-2',
          },
          {'id': 'm3', 'role': 'user', 'content': 'Which region? — EU'},
          {
            'id': 'm4',
            'role': 'assistant',
            'content': 'Here is the chart:\n\n![chart](files/chart.png)\n',
            'requestId': 'req-4',
          },
        ],
        'resources': <Object?>[],
      },
    });
    await boot(tester, path: '/workspace/$workspaceId/chat/chat-q');
    expect(text('Which region?'), findsOneWidget);
    expect(find.text('EU'), findsOneWidget);
    expect(find.text('US'), findsNothing, reason: 'the recap, not the form');
    expect(text('Which region? — EU'), findsNothing);
    expect(byParity('chat.message.user'), findsOneWidget);
    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<NetworkImage>()
        .map((i) => i.url);
    expect(
      images,
      contains(
        '/api/mothership/chats/chat-q/images/req-4?path=files%2Fchart.png',
      ),
    );
  });
}

/// The assistant text of a fixture (its `text` envelopes joined).
String loadFixtureText(String name) {
  final buffer = StringBuffer();
  for (final envelope in loadFixture(name).envelopes) {
    final line = envelope.json;
    final payload = line['payload'];
    if (line['type'] == 'text' &&
        payload is Map &&
        payload['channel'] == 'assistant') {
      buffer.write(payload['text']);
    }
  }
  return buffer.toString();
}
