// Failure modes of the chat stores (spec chat-engine §5, §4.11, §4.13,
// §4.14; parity rows 60, 63, 65-74, 76-79):
// 1. the queue reads and writes `sessionStorage['mothership-queue']` in the
//    zustand envelope v0 written by React, and survives a corrupt value;
// 2. legacy queue fields (`retryRequired`, `heldUntilOnline`, `sendRetries`
//    + `notBefore`, `queuedSendHandoff.userMessageId`) are migrated and the
//    admission guard marks a reused id as possibly sent;
// 3. an `admissionUnknown` entry cannot be edited; an edit strips the
//    resume id, hold and retry;
// 4. a `pending::` queue migrates to its chat behind what was there, and a
//    write captured before the move lands in the chat (`liveQueuePosition`);
// 5. a deleted chat's queue cannot be recreated until restored;
// 6. requeue policy per reason (offline hold, busy/unreachable retry with
//    1–30 s backoff, stop-failed/failed hold for the user);
// 7. drafts: `localStorage['mothership-drafts:v1']` envelope v1, empty
//    payload deletes the key, v0 legacy copilot keys dropped, 200 ms
//    debounce, flush on dispose, clear on submit;
// 8. effort: `mothership-effort`/`mothership-plan-effort` `{modelSelection}`
//    v0, invalid → default, Opus 5 → 5.5 without fast mode; per-chat picks
//    are memory only and a newer pick survives a failed save of an older;
// 9. model resolution without the selector (max → xhigh, plan → Opus);
// 10. tool permission: bulk row only on the first outstanding card when
//     more than one waits; 404 → expired, other failure re-enables;
// 11. handoffs: queued-send handoff 5 min TTL, claim 30 s TTL, the
//     `sim_mothership_handoff` record is consumed once, 60 s max age, and
//     another workspace's record is left alone.

import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/engine.dart';

class _MockClient extends Mock implements MothershipClient {}

void main() {
  group('queue store', () {
    late MemoryChatStorage session;

    setUp(() => session = MemoryChatStorage());

    test('writes the React envelope and reads it back', () {
      final store = MothershipQueueStore(session)
        ..enqueue('chat-1', const QueuedMessage(id: 'q1', content: 'hi'));
      final raw = jsonDecode(session.values['mothership-queue']!) as Map;
      expect(raw, {
        'state': {
          'queues': {
            'chat-1': [
              {'id': 'q1', 'content': 'hi'},
            ],
          },
        },
        'version': 0,
      });
      expect(store.queue('chat-1').single.id, 'q1');
      expect(
        MothershipQueueStore(session).queue('chat-1').single.content,
        'hi',
      );
    });

    test('corrupt storage starts empty', () {
      session.values['mothership-queue'] = '{not json';
      expect(MothershipQueueStore(session).queues, isEmpty);
    });

    test('legacy fields are migrated and the admission guard applied', () {
      session.values['mothership-queue'] = jsonEncode({
        'state': {
          'queues': {
            'c': [
              {
                'id': 'a',
                'content': 'x',
                'retryRequired': true,
                'heldUntilOnline': true,
              },
              {'id': 'b', 'content': 'y', 'sendRetries': 2, 'notBefore': 99},
              {
                'id': 'c',
                'content': 'z',
                'queuedSendHandoff': {
                  'id': 'c',
                  'supersededStreamId': 's',
                  'userMessageId': 'u-old',
                },
              },
              {'id': 'bad'},
            ],
          },
        },
        'version': 0,
      });
      final q = MothershipQueueStore(session).queue('c');
      expect(q.map((m) => m.id), ['a', 'b', 'c']);
      expect(q[0].hold, QueueHold.online);
      expect(q[1].retry, const SendRetry(attempt: 2, notBefore: 99));
      expect(q[2].resumeUserMessageId, 'u-old');
      expect(q[2].admissionUnknown, isTrue);
      expect(q[2].queuedSendHandoff?.supersededStreamId, 's');
    });

    test('edits are refused for possibly-sent entries and strip resume', () {
      final store = MothershipQueueStore(session)
        ..enqueue(
          'c',
          const QueuedMessage(id: 'a', content: 'x', resumeUserMessageId: 'u'),
        )
        ..enqueue(
          'c',
          const QueuedMessage(
            id: 'b',
            content: 'y',
            hold: QueueHold.user,
            admissionUnknown: false,
            resumeUserMessageId: 'u2',
          ),
        )
        ..replaceAt('c', 'a', const SendPayload(content: 'edited'))
        ..replaceAt('c', 'b', const SendPayload(content: 'edited'));
      expect(store.queue('c')[0].content, 'x');
      final b = store.queue('c')[1];
      expect(b.content, 'edited');
      expect(b.hold, isNull);
      expect(b.resumeUserMessageId, isNull);
    });

    test('pending queue migrates behind the chat queue', () {
      final store = MothershipQueueStore(session)
        ..enqueue('chat', const QueuedMessage(id: 'old', content: '1'))
        ..enqueue(
          'pending::x',
          const QueuedMessage(id: 'new', content: '2', heldSurface: 'ws:home'),
        )
        ..migrate('pending::x', 'chat');
      expect(store.queue('chat').map((m) => m.id), ['old', 'new']);
      expect(store.queue('chat').last.heldSurface, isNull);
      final position = store.liveQueuePosition('pending::x', const []);
      expect(position.chatKey, 'chat');
      expect(position.index, 1);
    });

    test('a deleted chat is not recreated until restored', () {
      final store = MothershipQueueStore(session)
        ..enqueue('c', const QueuedMessage(id: 'a', content: 'x'))
        ..clearChat('c')
        ..enqueue('c', const QueuedMessage(id: 'b', content: 'y'));
      expect(store.queue('c'), isEmpty);
      store
        ..reopenRestoredChat('c')
        ..enqueue('c', const QueuedMessage(id: 'b', content: 'y'));
      expect(store.queue('c').single.id, 'b');
    });

    test('online release and surface adoption', () {
      final store = MothershipQueueStore(session)
        ..enqueue(
          'pending::dead',
          const QueuedMessage(id: 'h', content: 'x', hold: QueueHold.online),
        )
        ..holdForSurface('pending::dead', 'ws:home')
        ..adoptHeldSends('pending::live', 'ws:home');
      expect(store.queue('pending::live').single.id, 'h');
      store.releaseHeldUntilOnline();
      expect(store.queue('pending::live').single.hold, isNull);
    });
  });

  group('requeue policy', () {
    const entry = QueuedMessage(id: 'a', content: 'x', hold: QueueHold.user);
    final random = Random(1);

    test('per reason', () {
      expect(
        requeued(
          entry,
          RequeueReason.offline,
          previousAttempts: 0,
          nowMs: 0,
        ).hold,
        QueueHold.online,
      );
      final busy = requeued(
        entry,
        RequeueReason.busy,
        previousAttempts: 2,
        nowMs: 1000,
        random: random,
      );
      expect(busy.hold, isNull);
      expect(busy.retry?.attempt, 3);
      // attempt 3: 4 s ± 20 %.
      expect(busy.retry!.notBefore, inInclusiveRange(1000 + 3200, 1000 + 4800));
      expect(
        requeued(
          entry,
          RequeueReason.stopFailed,
          previousAttempts: 0,
          nowMs: 0,
        ).hold,
        QueueHold.user,
      );
      final withdrawn = requeued(
        entry,
        RequeueReason.withdrawn,
        previousAttempts: 0,
        nowMs: 0,
      );
      expect(withdrawn.hold, isNull);
      expect(withdrawn.retry, isNull);
    });

    test('backoff caps at 30 s', () {
      final ms = backoffWithJitterMs(
        20,
        base: const Duration(seconds: 1),
        max: const Duration(seconds: 30),
        random: Random(2),
      );
      expect(ms, inInclusiveRange(24000, 36000));
    });

    test('resend verdict', () {
      const possiblySent = QueuedMessage(
        id: 'q',
        content: 'x',
        resumeUserMessageId: 'u1',
        admissionUnknown: true,
      );
      const history = MothershipChatHistory(
        id: 'c',
        messages: [PersistedMessage(id: 'u1', role: 'user', content: 'x')],
      );
      expect(resendVerdict(possiblySent, history), ResendVerdict.drop);
      expect(resendVerdict(possiblySent, null), ResendVerdict.wait);
      expect(
        resendVerdict(
          possiblySent,
          const MothershipChatHistory(id: 'c', messages: []),
        ),
        ResendVerdict.send,
      );
      expect(
        resendVerdict(const QueuedMessage(id: 'q', content: 'x'), null),
        ResendVerdict.send,
      );
    });
  });

  group('drafts', () {
    test('envelope v1, empty deletes, legacy dropped', () {
      final local = MemoryChatStorage()
        ..values['mothership-drafts:v1'] = jsonEncode({
          'state': {
            'drafts': {
              'ws:workflow-copilot:wf': {'text': 'legacy'},
              'ws:new': {'text': 'keep'},
            },
          },
          'version': 0,
        });
      final store = MothershipDraftsStore(local);
      expect(store.drafts.keys, ['ws:new']);
      expect(
        (jsonDecode(local.values['mothership-drafts:v1']!) as Map)['version'],
        1,
      );
      store.setDraft(homeDraftKey('ws', 'c1'), const DraftPayload(text: 'a'));
      expect(
        (jsonDecode(local.values['mothership-drafts:v1']!) as Map)['state'],
        {
          'drafts': {
            'ws:new': {'text': 'keep'},
            'ws:c1': {'text': 'a'},
          },
        },
      );
      store.setDraft('ws:c1', const DraftPayload(text: ''));
      expect(store.draft('ws:c1'), isNull);
    });

    test('autosave debounces 200 ms, flushes on dispose, clears on submit', () {
      fakeAsync((async) {
        final store = MothershipDraftsStore(MemoryChatStorage());
        final saver = DraftAutosaver(store, 'ws:new')
          ..save(const DraftPayload(text: 'h'))
          ..save(const DraftPayload(text: 'he'));
        async.elapse(const Duration(milliseconds: 199));
        expect(store.draft('ws:new'), isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(store.draft('ws:new')?.text, 'he');
        saver
          ..save(const DraftPayload(text: 'hel'))
          ..dispose();
        expect(store.draft('ws:new')?.text, 'hel');
        DraftAutosaver(store, 'ws:new').clear();
        expect(store.draft('ws:new'), isNull);
      });
    });
  });

  group('effort', () {
    test('persisted model selection, invalid → default', () {
      final local = MemoryChatStorage()
        ..values['mothership-effort'] = jsonEncode({
          'state': {
            'modelSelection': {'model': 'claude-opus-5', 'fastMode': true},
          },
          'version': 0,
        })
        ..values['mothership-plan-effort'] =
            '{"state":{"modelSelection":{"model":"nope"}}}';
      final build = MothershipEffortStore(local, plan: false);
      expect(
        build.modelSelection,
        const ModelSelection(model: 'claude-opus-5-5'),
      );
      final plan = MothershipEffortStore(local, plan: true);
      expect(plan.modelSelection.model, 'claude-opus-5-5');
      build.setModel('gpt-6-sol');
      expect(jsonDecode(local.values['mothership-effort']!), {
        'state': {
          'modelSelection': {'model': 'gpt-6-sol', 'fastMode': false},
        },
        'version': 0,
      });
    });

    test('a failed save drops only its own pick', () {
      final store = MothershipEffortStore(MemoryChatStorage(), plan: false);
      final first = store.setChatEffort('c', 'low');
      store.setChatEffort('c', 'max');
      expect(store.dropChatEffort('c', first), isFalse);
      expect(store.chatEffort('c'), 'max');
      store
        ..setNewChatEffort('xhigh')
        ..adoptNewChatEffort('n', 'xhigh');
      expect(store.newChatEffort, isNull);
      expect(store.chatEffort('n'), 'xhigh');
    });

    test('resolution without the selector', () {
      expect(
        resolveMothershipModelSettings(effort: 'max', advanced: false),
        (effort: 'xhigh', modelSelection: null),
      );
      expect(
        resolveMothershipModelSettings(advanced: false, plan: true),
        (
          effort: 'medium',
          modelSelection: const ModelSelection(model: 'claude-opus-5-5'),
        ),
      );
      expect(
        resolveMothershipModelSettings(effort: 'none', advanced: true).effort,
        'low',
      );
    });
  });

  group('tool permission', () {
    test('bulk row on the first outstanding card only', () {
      final store = ToolPermissionStore()..register('a');
      expect(store.showsBulkActions('a'), isFalse);
      store.register('b');
      expect(store.showsBulkActions('a'), isTrue);
      expect(store.showsBulkActions('b'), isFalse);
      store.markSubmitted(['a']);
      expect(store.showsBulkActions('b'), isFalse);
    });

    test('404 expires, other errors re-enable', () async {
      final client = _MockClient();
      final store = ToolPermissionStore()..register('t');
      when(() => client.decideToolPermissions(any())).thenThrow(
        ApiClientError.fromResponse(status: 404, body: {}),
      );
      expect(
        await store.decide(client, ['t'], ToolPermissionDecision.allow),
        ToolPermissionOutcome.expired,
      );
      expect(store.isSubmitted('t'), isTrue);
      when(() => client.decideToolPermissions(any())).thenThrow(
        ApiClientError.fromResponse(status: 500, body: {}),
      );
      store.clearSubmitted(['t']);
      expect(
        await store.decide(client, ['t'], ToolPermissionDecision.skip),
        ToolPermissionOutcome.failed,
      );
      expect(store.isSubmitted('t'), isFalse);
      var settingsInvalidated = false;
      when(
        () => client.decideToolPermissions(any()),
      ).thenAnswer((_) async => []);
      expect(
        await store.decide(
          client,
          ['t'],
          ToolPermissionDecision.alwaysAllow,
          onAlwaysAllow: () => settingsInvalidated = true,
        ),
        ToolPermissionOutcome.recorded,
      );
      expect(settingsInvalidated, isTrue);
    });
  });

  group('handoffs', () {
    test('queued-send handoff TTL and claim TTL', () {
      var now = 1000000;
      final session = MemoryChatStorage();
      final store =
          SendHandoffStore(
            session: session,
            local: MemoryChatStorage(),
            nowMs: () => now,
            idGenerator: () => 'owner',
          )..writeQueued(
            QueuedSendHandoffState(
              seed: const QueuedSendHandoffSeed(
                id: 'h',
                chatId: 'c',
                supersededStreamId: 's',
              ),
              workspaceId: 'ws',
              userMessageId: 'u',
              payload: const SendPayload(content: 'hi', requestMode: 'agent'),
              requestedAt: now,
            ),
          );
      expect(
        jsonDecode(session.values[queuedSendHandoffKey]!),
        {
          'id': 'h',
          'chatId': 'c',
          'workspaceId': 'ws',
          'supersededStreamId': 's',
          'userMessageId': 'u',
          'message': 'hi',
          'requestMode': 'agent',
          'requestedAt': 1000000,
        },
      );
      expect(store.readQueued()?.payload.content, 'hi');
      expect(store.writeClaim('h'), 'owner');
      expect(store.readClaim(), 'h');
      now += 30001;
      expect(store.readClaim(), isNull);
      now += 5 * 60 * 1000;
      expect(store.readQueued(), isNull);
      expect(session.values.containsKey(queuedSendHandoffKey), isFalse);
    });

    test('mothership handoff is consumed once and owner-scoped', () {
      var now = 5000;
      final local = MemoryChatStorage();
      final store = SendHandoffStore(
        session: MemoryChatStorage(),
        local: local,
        nowMs: () => now,
      );
      expect(
        store.storeHandoff(
          const MothershipHandoff(message: 'retry', resumeUserMessageId: 'u'),
          workspaceId: 'ws',
        ),
        isTrue,
      );
      expect(store.consumeHandoff(workspaceId: 'other'), isNull);
      final consumed = store.consumeHandoff(workspaceId: 'ws');
      expect(consumed?.message, 'retry');
      expect(consumed?.resumeUserMessageId, 'u');
      expect(store.consumeHandoff(workspaceId: 'ws'), isNull);
      store.storeHandoff(
        const MothershipHandoff(message: 'x'),
        workspaceId: 'ws',
      );
      now += 60001;
      expect(store.consumeHandoff(workspaceId: 'ws'), isNull);
      expect(local.values.containsKey(mothershipHandoffKey), isFalse);
    });
  });
}
