// Failure modes of inline chat images (`chat-content.tsx:539-557`
// `privateImageUrls`, `lib/mothership/chat/inline-image-reference.ts`):
// 1. a first-party file reference (`files/…`, `uploads/…`, `/tmp/…`,
//    `/home/user/…`, `wf_…`, a UUID) renders nothing because no resolver is
//    wired, or loads the raw reference instead of the chat image route;
// 2. the `path` query is double-encoded for an already CommonMark-encoded
//    reference (`a%20b` must stay `a%20b`, not `a%2520b`), or not encoded;
// 3. arbitrary URLs/paths are rewritten (must stay untouched), or a
//    reference without chat id / request id leaks the raw path instead of
//    being dropped;
// 4. the route is resolved per transcript instead of per message: each
//    assistant message must use its own `requestId`.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/integration/inline_image.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_transcript.dart';

import '../messages/support/chat_harness.dart';

void main() {
  test('1-2. inline references map to the chat image route', () {
    expect(
      inlineChatImageUrl('c 1', 'req-1', 'files/a b.png'),
      '/api/mothership/chats/c%201/images/req-1?path=files%2Fa%2520b.png',
    );
    expect(
      inlineChatImageUrl('c1', 'req-1', 'files/a%20b.png'),
      '/api/mothership/chats/c1/images/req-1?path=files%2Fa%2520b.png',
    );
    for (final ref in [
      'files/x.png',
      'uploads/y.jpg',
      '/tmp/z.png',
      '/home/user/out.png',
      'wf_abc-123',
      '3f2504e0-4f89-41d3-9a0c-0305e82c3301',
    ]) {
      expect(isInlineFileReference(ref), isTrue, reason: ref);
    }
    for (final ref in [
      'https://example.com/a.png',
      '/etc/passwd',
      'images/a.png',
      'wf_a/b',
      '',
      'files/\u0007x',
    ]) {
      expect(isInlineFileReference(ref), isFalse, reason: ref);
    }
  });

  test('3. other sources untouched; missing ids drop the image', () {
    expect(
      resolveChatImageUrl('images/a.png', chatId: 'c', requestId: 'r'),
      'images/a.png',
    );
    expect(
      resolveChatImageUrl('files/a.png', chatId: null, requestId: 'r'),
      isNull,
    );
    expect(
      resolveChatImageUrl('files/a.png', chatId: 'c', requestId: null),
      isNull,
    );
  });

  testWidgets('4. each message resolves with its own request id', (
    tester,
  ) async {
    const views = <ChatMessageView>[
      ChatAssistantMessageView(
        id: 'a1',
        requestId: 'req-1',
        segments: [ChatTextSegment(id: 't', content: '![one](files/one.png)')],
      ),
      ChatAssistantMessageView(
        id: 'a2',
        requestId: 'req-2',
        segments: [ChatTextSegment(id: 't', content: '![two](files/two.png)')],
      ),
    ];
    await pumpChat(
      tester,
      ChatTranscript(
        messages: views,
        chatId: 'c1',
        callbacks: ChatMessageCallbacks(
          resolveMessageImageUrl: (src, requestId) =>
              resolveChatImageUrl(src, chatId: 'c1', requestId: requestId),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final urls = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<NetworkImage>()
        .map((i) => i.url)
        .toList();
    expect(urls, [
      '/api/mothership/chats/c1/images/req-1?path=files%2Fone.png',
      '/api/mothership/chats/c1/images/req-2?path=files%2Ftwo.png',
    ]);
  });
}
