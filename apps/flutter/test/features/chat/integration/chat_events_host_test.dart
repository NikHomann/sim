// Failure modes of the shell's chat seam:
// 1. no events cubit is mounted with the workspace, so the sidebar list is
//    never refetched on chat-status events;
// 2. the running ids never reach the sidebar (no running dot until a
//    refetch lands);
// 3. switching workspaces keeps the old workspace's cubit;
// 4. off the web, resuming the app does not recover the live streams.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/integration/chat_events_host.dart';
import 'package:sim_app/features/chat/integration/chat_integration.dart';

import '../engine/support/fake_client.dart';

class _EventsClient extends FakeMothershipClient {
  @override
  RotatingEventSource chatEvents({required String workspaceId}) =>
      RotatingEventSource(
        open: ({required cancelToken, lastEventId}) async => ApiStreamResponse(
          status: 200,
          headers: const {},
          bytes: StreamController<Uint8List>().stream,
        ),
      );
}

class _Sink implements ChatListSink {
  final List<String> invalidated = [];
  final List<Set<String>> running = [];

  @override
  void invalidate(String workspaceId) => invalidated.add(workspaceId);

  @override
  void setRunning(String workspaceId, Set<String> chatIds) =>
      running.add(chatIds);
}

void main() {
  late ChatIntegration integration;
  late _Sink sink;

  setUp(() {
    integration = ChatIntegration(
      client: _EventsClient(),
      queries: QueryClient(),
      storages: ChatStorages.memory(),
      browserReturns: const Stream.empty(),
      onlineEvents: const Stream.empty(),
      isOnline: () => true,
    );
    sink = _Sink();
    ChatEventsCubit.resetSubscriptionHistory();
  });

  Widget host(String workspaceId) => ChatEventsHost(
    workspaceId: workspaceId,
    integration: integration,
    sink: sink,
    recoverOnResume: true,
    child: const SizedBox(),
  );

  testWidgets('1-3. events refetch the list, carry running ids and follow '
      'the workspace', (tester) async {
    await tester.pumpWidget(host('ws'));
    final state = tester.state<ChatEventsHostState>(
      find.byType(ChatEventsHost),
    );
    final cubit = state.cubit!;
    expect(cubit.workspaceId, 'ws');

    cubit.handleTaskStatus({'type': 'started', 'chatId': 'c1'});
    await tester.pump();
    expect(sink.invalidated, ['ws']);
    expect(sink.running.last, {'c1'});

    cubit.handleTaskStatus({'type': 'completed', 'chatId': 'c1'});
    await tester.pump();
    expect(sink.invalidated, ['ws', 'ws']);
    expect(sink.running.last, isEmpty);

    await tester.pumpWidget(host('ws2'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(state.cubit!.workspaceId, 'ws2');
    expect(cubit.isClosed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('4. resume recovers every mounted session', (tester) async {
    final session = _RecordingSession(integration);
    integration.attachSession(session);
    await tester.pumpWidget(host('ws'));
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(session.recovered, [BrowserReturnReason.visible]);
    integration.detachSession(session);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(session.close);
  });
}

class _RecordingSession extends ChatSessionCubit {
  _RecordingSession(ChatIntegration integration)
    : super(
        client: integration.client,
        queryClient: integration.queries,
        queueStore: integration.queue,
        effortStore: integration.effort,
        planEffortStore: integration.planEffort,
        workspaceId: 'ws',
        browserReturns: const Stream.empty(),
        onlineEvents: const Stream.empty(),
        isOnline: () => true,
      );

  final List<BrowserReturnReason> recovered = [];

  @override
  Future<void> recoverActiveStream(BrowserReturnReason reason) async =>
      recovered.add(reason);
}
