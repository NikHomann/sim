import 'package:flutter/foundation.dart';
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';

@immutable
class ChatMentionRange {
  const ChatMentionRange(this.start, this.end, this.mention);

  final int start;
  final int end;
  final ChatMentionView mention;
}

/// Port of `computeMentionRanges` (`user-message-content/utils.ts`): every
/// whole-token occurrence of each mention's `@label` / `/label`, preceded by
/// start or whitespace and followed by whitespace, punctuation or end;
/// overlaps keep the earlier (then longer) range.
///
/// The integration-name matcher (bare `@Gmail` without a context) needs the
/// block registry and is not ported.
List<ChatMentionRange> computeMentionRanges(
  String text,
  List<ChatMentionView> mentions,
) {
  final ranges = <ChatMentionRange>[];
  for (final mention in mentions) {
    if (mention.label.isEmpty) continue;
    final token = mention.token;
    final pattern = RegExp(
      '(^|\\s)(${RegExp.escape(token)})(?=[\\s,;:!?)\\]]|\\.(?![\\w-])|\$)',
    );
    for (final match in pattern.allMatches(text)) {
      final start = match.start + match.group(1)!.length;
      ranges.add(ChatMentionRange(start, start + token.length, mention));
    }
  }
  ranges.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : b.end.compareTo(a.end);
  });
  final merged = <ChatMentionRange>[];
  for (final range in ranges) {
    if (range.start >= (merged.isEmpty ? 0 : merged.last.end)) {
      merged.add(range);
    }
  }
  return merged;
}
