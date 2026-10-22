import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';
import 'package:sim_app/features/chat/messages/widgets/chat_scope.dart';
import 'package:sim_design/sim_design.dart';

/// The seeded "E2E conversation" (`tools/seed/lib/src/fixtures.dart` `_chat`).
const String seededUserText = 'Summarise the seeded workspace for me.';
const String seededAssistantText =
    'Flutter E2E workspace\n\n| Resource | Count |\n| --- | --- |\n| Workflows | 3 |\n| Tables | 1 (50 rows) |\n| Knowledge bases | 1 (2 documents) |\n\n```json\n{"workspace":"Flutter E2E workspace","seeded":true}\n```';

const List<ChatMessageView> seededConversation = <ChatMessageView>[
  ChatUserMessageView(id: 'msg-1', text: seededUserText),
  ChatAssistantMessageView(
    id: 'msg-2',
    segments: <ChatSegment>[
      ChatTextSegment(id: 'text-fallback', content: seededAssistantText),
    ],
    canFeedback: true,
    canFork: true,
    requestId: 'req-1',
    userQuery: seededUserText,
  ),
];

/// Records every callback the transcript fires.
class RecordedCallbacks {
  final List<String> options = <String>[];
  final List<String> dismissed = <String>[];
  final List<(List<String>, ChatPermissionDecision)> permissions =
      <(List<String>, ChatPermissionDecision)>[];
  final List<(String, bool, String)> feedback = <(String, bool, String)>[];
  final List<String> forks = <String>[];
  final List<String> links = <String>[];
  final List<ChatResourceView> resources = <ChatResourceView>[];
  final List<String> copied = <String>[];
  final List<String> viewAll = <String>[];
  ChatPermissionOutcome permissionOutcome = ChatPermissionOutcome.accepted;

  ChatMessageCallbacks get callbacks => ChatMessageCallbacks(
    onOptionSelect: options.add,
    onQuestionDismiss: dismissed.add,
    onPermission: (ids, decision) async {
      permissions.add((ids, decision));
      return permissionOutcome;
    },
    onFeedback: (id, {required positive, required text}) =>
        feedback.add((id, positive, text)),
    onFork: (id) async => forks.add(id),
    onOpenLink: links.add,
    onResourceSelect: resources.add,
    onViewAllSources: viewAll.add,
    copyToClipboard: (text) async => copied.add(text),
  );
}

/// Material app + overlay host + theme, the way the app mounts pages.
Widget chatApp(
  Widget child, {
  bool dark = false,
  ChatMessageCallbacks? callbacks,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: simLightTheme(),
  darkTheme: simDarkTheme(),
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  builder: (context, c) => SimOverlayHost(child: c ?? const SizedBox()),
  home: Builder(
    builder: (context) => ColoredBox(
      color: SimTheme.of(context).colors.bg,
      child: ChatTextDefaults(
        child: callbacks == null
            ? child
            : ChatScope(callbacks: callbacks, child: child),
      ),
    ),
  ),
);

Future<void> pumpChat(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(800, 900),
  bool dark = false,
  ChatMessageCallbacks? callbacks,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(chatApp(child, dark: dark, callbacks: callbacks));
  await tester.pump();
}

/// Finds the [Semantics] widget carrying a parity id.
Finder byParityId(String identifier) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == identifier,
  description: 'parity id $identifier',
);
