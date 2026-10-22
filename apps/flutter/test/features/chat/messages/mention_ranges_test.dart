// Failure modes of user-bubble mention ranges (`user-message-content/utils.ts`
// computeMentionRanges) and the copy-text preparation
// (`copyable-markdown.ts`):
// 1. a mention only matches as a whole token after whitespace/start and
//    before whitespace/punctuation/end (`@Leadsx` and `a@Leads` do not match)
// 2. skills, MCP and slash commands use `/`, everything else `@`
// 3. overlapping matches keep the earlier/longer one
// 4. regex metacharacters in labels are escaped
// 5. copy text turns resource chips into portable `sim:kind/id` links and
//    drops sources, thinking and block tags
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/messages/markdown/copy_text.dart';
import 'package:sim_app/features/chat/messages/markdown/mention_ranges.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';

void main() {
  const leads = ChatMentionView(kind: ChatResourceKind.table, label: 'Leads');

  test('matches whole tokens only', () {
    final r = computeMentionRanges('Open @Leads, not @Leadsx or a@Leads.', [
      leads,
    ]);
    expect(r, hasLength(1));
    expect(r.single.start, 5);
    expect(r.single.end, 11);
  });

  test('skills use a slash prefix', () {
    const skill = ChatMentionView(
      kind: ChatResourceKind.skill,
      label: 'deploy',
    );
    final r = computeMentionRanges('run /deploy now and @deploy', [skill]);
    expect(r.single.start, 4);
  });

  test('overlaps keep the earlier, longer range', () {
    const a = ChatMentionView(kind: ChatResourceKind.file, label: 'a b');
    const b = ChatMentionView(kind: ChatResourceKind.file, label: 'a');
    final r = computeMentionRanges('@a b end', [b, a]);
    expect(r, hasLength(1));
    expect(r.single.end, 4);
  });

  test('regex metacharacters are escaped', () {
    const odd = ChatMentionView(kind: ChatResourceKind.file, label: 'c++ (v2)');
    final r = computeMentionRanges('see @c++ (v2) ok', [odd]);
    expect(r, hasLength(1));
  });

  test('copy text makes chips portable and drops hidden tags', () {
    final text = prepareCopyText(
      'Use<workspace_resource>{"type":"table","id":"t1","title":"Leads"}</workspace_resource>.'
      '<source>{"url":"https://a.dev/x","title":"A"}</source>'
      '<thinking>hidden</thinking>',
    );
    // Sources are not part of the copied text upstream; resources become
    // `serializePortableChipLink` links.
    expect(text, 'Use [Leads](sim:table/t1).');
  });
}
