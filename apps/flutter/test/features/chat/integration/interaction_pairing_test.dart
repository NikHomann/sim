// Failure modes of the question/credential pairing
// (`mothership-chat.tsx:615-665` `interactionPairing`):
// 1. an answered `<question>` card stays an active form and the user's
//    "Prompt — Answer" message renders as a duplicate bubble;
// 2. a user message that does not match the batch's answer format (a
//    dismissed card followed by unrelated typing) is paired anyway;
// 3. a submitted `<credential>` card stays a live form and its
//    "Credential setup submitted — {…}" turn renders as a bubble;
// 4. a credential card the user talked past stays a live form instead of
//    collapsing to the all-"Skipped" recap;
// 5. the pairing only exists in the mapper: the real transcript still shows
//    the hidden bubble or the active card.

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/integration/interaction_pairing.dart';
import 'package:sim_app/features/chat/integration/message_view_mapper.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_transcript.dart';

import '../messages/support/chat_harness.dart';

const List<Map<String, Object>> _questions = [
  {
    'type': 'single_select',
    'prompt': 'Which region?',
    'options': [
      {'id': 'eu', 'label': 'EU'},
      {'id': 'us', 'label': 'US'},
    ],
  },
  {
    'type': 'single_select',
    'prompt': 'Which size?',
    'options': [
      {'id': 's', 'label': 'Small'},
      {'id': 'l', 'label': 'Large'},
    ],
  },
];

ChatMessage _assistant(String id, String content) => ChatMessage(
  id: id,
  role: ChatRole.assistant,
  content: content,
  requestId: 'req-$id',
);

ChatMessage _user(String id, String content) =>
    ChatMessage(id: id, role: ChatRole.user, content: content);

final String _questionTurn =
    'Two quick questions.\n<question>${jsonEncode(_questions)}</question>';

const _credentials = [
  {'type': 'link', 'provider': 'slack', 'value': 'https://sim.ai/oauth/slack'},
  {'type': 'secret_input', 'name': 'OPENAI_API_KEY'},
];

final String _credentialTurn =
    'Connect these first.\n<credential>${jsonEncode(_credentials)}</credential>';

List<ChatMessageView> _map(List<ChatMessage> messages) =>
    mapChatMessages(messages, const ChatViewContext(chatId: 'c1'));

void main() {
  test('1. an answered question pairs: recap answers, user bubble hidden', () {
    final views = _map([
      _user('u1', 'Set it up'),
      _assistant('a1', _questionTurn),
      _user('u2', 'Which region? — EU\nWhich size? — Large'),
      _assistant('a2', 'Done.'),
    ]);
    final card = views[1] as ChatAssistantMessageView;
    expect(card.questionAnswers, ['EU', 'Large']);
    expect((views[2] as ChatUserMessageView).hidden, isTrue);
    expect((views[0] as ChatUserMessageView).hidden, isFalse);
    expect((views[3] as ChatAssistantMessageView).questionAnswers, isNull);
  });

  test('2. a non-matching user message is not paired', () {
    final views = _map([
      _assistant('a1', _questionTurn),
      _user('u2', 'Actually, never mind'),
    ]);
    expect((views[0] as ChatAssistantMessageView).questionAnswers, isNull);
    expect((views[1] as ChatUserMessageView).hidden, isFalse);
    // One line per question, in order: a single matching line is not enough.
    final partial = pairInteractions([
      _assistant('a1', _questionTurn),
      _user('u2', 'Which region? — EU'),
    ]);
    expect(partial.answersByIndex, isEmpty);
    expect(partial.hiddenUserIndexes, isEmpty);
  });

  test('3. a submitted credential card recaps its rows and hides the turn', () {
    final submission =
        'Credential setup submitted — ${jsonEncode({
          'integrations': [
            {'name': 'slack', 'status': 'connected'},
          ],
          'secrets': [
            {'name': 'OPENAI_API_KEY', 'status': 'skipped'},
          ],
        })}';
    final views = _map([
      _assistant('a1', _credentialTurn),
      _user('u2', submission),
    ]);
    final card = views[0] as ChatAssistantMessageView;
    expect(
      card.credentialRecap?.map((r) => '${r.label}=${r.status}').toList(),
      ['slack=Connected', 'OPENAI_API_KEY=Skipped'],
    );
    expect((views[1] as ChatUserMessageView).hidden, isTrue);

    // The legacy "Credential setup complete — …" form pairs as all done.
    final legacy = pairInteractions([
      _assistant('a1', _credentialTurn),
      _user(
        'u2',
        'Credential setup complete — integrations: slack; '
            'secrets: OPENAI_API_KEY',
      ),
    ]);
    expect(
      legacy.credentialRecapByIndex[0]?.map((r) => r.status).toList(),
      ['Connected', 'Added'],
    );
    expect(legacy.hiddenUserIndexes, {1});
  });

  test('4. a credential card the user talked past recaps as skipped', () {
    final views = _map([
      _assistant('a1', _credentialTurn),
      _user('u2', 'Skip that, just draft the workflow'),
      _assistant('a2', 'Drafted.'),
    ]);
    final card = views[0] as ChatAssistantMessageView;
    expect(card.credentialRecap?.map((r) => r.status).toList(), [
      'Skipped',
      'Skipped',
    ]);
    expect((views[1] as ChatUserMessageView).hidden, isFalse);
    // The newest turn is not superseded: its card stays live.
    final live = _map([_user('u1', 'go'), _assistant('a1', _credentialTurn)]);
    expect((live[1] as ChatAssistantMessageView).credentialRecap, isNull);
  });

  testWidgets('5. the real transcript renders the recaps and hides the '
      'paired bubbles', (tester) async {
    final views = _map([
      _user('u1', 'Set it up'),
      _assistant('a1', _questionTurn),
      _user('u2', 'Which region? — EU\nWhich size? — Large'),
      _assistant('a2', _credentialTurn),
      _user('u3', 'Skip that'),
      _assistant('a3', 'Ok.'),
    ]);
    await pumpChat(
      tester,
      ChatTranscript(messages: views, chatId: 'c1'),
      size: const Size(1200, 2400),
    );
    await tester.pump(const Duration(seconds: 2));
    // Question recap: prompts with their answers, no active option rows.
    expect(find.text('Which region?'), findsOneWidget);
    expect(find.text('EU'), findsOneWidget);
    expect(find.text('Large'), findsOneWidget);
    expect(find.text('Small'), findsNothing);
    // The paired answer bubble is hidden.
    expect(
      find.textContaining('Which size? — Large', findRichText: true),
      findsNothing,
    );
    // Credential recap rows read "Skipped"; the unpaired bubble stays.
    expect(find.text('slack'), findsOneWidget);
    expect(find.text('Skipped'), findsNWidgets(2));
    expect(find.textContaining('Skip that', findRichText: true), findsWidgets);
  });
}
