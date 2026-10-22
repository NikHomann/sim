/// Port of `sanitizeChatDisplayContent` (`chat-sanitize.ts`): outside fenced
/// blocks, inline-code backticks wrapped around a complete chip tag are
/// removed (the model sometimes code-formats a `<workspace_resource>`), and
/// hidden internal references are stripped everywhere. Fenced content is
/// kept verbatim.
///
/// Simplified relative to upstream: only a single-backtick span whose whole
/// content is chip tags (plus whitespace) is unwrapped; upstream also
/// unwraps spans that merely touch a chip.
String sanitizeChatDisplayContent(String content) {
  final parts = StringBuffer();
  var cursor = 0;
  int? fenceStart;
  var fence = '';
  final fenceLine = RegExp(
    r'^ {0,3}(`{3,}|~{3,})([^\n]*)(?:\n|$)',
    multiLine: true,
  );
  for (final line in fenceLine.allMatches(content)) {
    final delimiter = line.group(1)!;
    final info = line.group(2)!;
    if (fenceStart == null) {
      if (delimiter[0] == '`' && info.contains('`')) continue;
      fenceStart = line.start;
      fence = delimiter;
    } else if (delimiter[0] == fence[0] &&
        delimiter.length >= fence.length &&
        RegExp(r'^[\t \r]*$').hasMatch(info)) {
      parts
        ..write(_unwrapChips(content.substring(cursor, fenceStart)))
        ..write(content.substring(fenceStart, line.end));
      cursor = line.end;
      fenceStart = null;
    }
  }
  if (fenceStart == null) {
    parts.write(_unwrapChips(content.substring(cursor)));
  } else {
    parts
      ..write(_unwrapChips(content.substring(cursor, fenceStart)))
      ..write(content.substring(fenceStart));
  }
  return parts.toString().replaceAll(_hiddenReference, '');
}

final RegExp _hiddenReference = RegExp(
  r'`[^`\n]*(?:internal/tool-results/|internal/blocktips/|components/integrations/[^`\n]*README)[^`\n]*`',
);

const String _chipTag =
    r'<(?<tag>workspace_resource|source)>\s*\{(?:"(?:\\.|[^"\\\r\n])*"|[^"`<\\])*?\}\s*</\k<tag>>';

final RegExp _wrappedChips = RegExp('`((?:\\s*$_chipTag)+\\s*)`');

String _unwrapChips(String text) =>
    text.replaceAllMapped(_wrappedChips, (m) => m.group(1)!);
