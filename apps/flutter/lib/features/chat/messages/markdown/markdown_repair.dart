/// Streaming repair pass: closes what a half-received message left open so
/// it parses like the finished one will (Streamdown's `remend`, applied by
/// `ChatContent` while a message streams).
///
/// Only the trailing block can be incomplete, so emphasis, code spans,
/// links and table delimiter rows are repaired in the text after the last
/// blank line (and after the last closed fence). Underscore emphasis is left
/// alone: `_` is intraword in identifiers far more often than it is emphasis.
String repairStreamingMarkdown(String text) {
  if (text.isEmpty) return text;
  final fence = _openFence(text);
  if (fence != null) {
    return '$text${text.endsWith('\n') ? '' : '\n'}$fence';
  }
  final tailStart = _tailStart(text);
  final head = text.substring(0, tailStart);
  var tail = text.substring(tailStart);
  tail = _repairTableDelimiter(tail);
  tail = _repairLink(tail);
  tail = _repairEmphasis(tail);
  return '$head$tail';
}

final RegExp _fenceLine = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');

/// The closing run for a fence still open at the end of [text], else null.
String? _openFence(String text) {
  String? open;
  for (final line in text.split('\n')) {
    final match = _fenceLine.firstMatch(line);
    if (match == null) continue;
    final run = match.group(1)!;
    final info = match.group(2)!;
    if (open == null) {
      if (run[0] == '`' && info.contains('`')) continue;
      open = run;
    } else if (run[0] == open[0] &&
        run.length >= open.length &&
        info.trim().isEmpty) {
      open = null;
    }
  }
  return open;
}

/// Offset where the trailing block begins: after the last blank line or the
/// last closing fence, whichever is later.
int _tailStart(String text) {
  var start = 0;
  final blank = RegExp(r'\n[ \t]*\n');
  for (final match in blank.allMatches(text)) {
    start = match.end;
  }
  var offset = 0;
  String? open;
  for (final line in text.split('\n')) {
    final match = _fenceLine.firstMatch(line);
    final lineEnd = offset + line.length + 1;
    if (match != null) {
      final run = match.group(1)!;
      if (open == null) {
        if (!(run[0] == '`' && match.group(2)!.contains('`'))) open = run;
      } else if (run[0] == open[0] &&
          run.length >= open.length &&
          match.group(2)!.trim().isEmpty) {
        open = null;
        if (lineEnd > start) start = lineEnd;
      }
    }
    offset = lineEnd;
  }
  return start > text.length ? text.length : start;
}

List<String> _cells(String row) {
  var trimmed = row.trim();
  if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
  if (trimmed.endsWith('|')) trimmed = trimmed.substring(0, trimmed.length - 1);
  return trimmed.split('|');
}

final RegExp _delimiterChars = RegExp(r'^[\s|:\-]*$');

/// A delimiter row still arriving under a header row is completed to the
/// header's column count (GFM needs a full delimiter row to see a table).
String _repairTableDelimiter(String tail) {
  final lines = tail.split('\n');
  if (lines.length < 2) return tail;
  final last = lines.last;
  final header = lines[lines.length - 2];
  if (!last.contains('-') || !_delimiterChars.hasMatch(last)) return tail;
  if (!header.contains('|')) return tail;
  final columns = _cells(header).length;
  final cells = _cells(last);
  final headerClosed = header.trimRight().endsWith('|');
  final complete =
      cells.length == columns &&
      cells.every((c) => RegExp(r'^\s*:?-+:?\s*$').hasMatch(c)) &&
      (!headerClosed || last.trimRight().endsWith('|'));
  if (complete) return tail;
  final aligned = <String>[
    for (var i = 0; i < columns; i++)
      i < cells.length && cells[i].trim().startsWith(':')
          ? (cells[i].trim().endsWith(':') && cells[i].trim().length > 1
                ? ':---:'
                : ':---')
          : '---',
  ];
  lines[lines.length - 1] = '| ${aligned.join(' | ')} |';
  return lines.join('\n');
}

final RegExp _partialLink = RegExp(r'(!?)\[([^\]\n]*)\]\([^)\s]*$');
final RegExp _partialLabel = RegExp(r'(!?)\[([^\]\n]*)$');

/// `[label](http…` → `label`; `[label` → `label`; a partial image vanishes.
String _repairLink(String tail) {
  final link = _partialLink.firstMatch(tail);
  if (link != null) {
    final label = link.group(1)!.isEmpty ? link.group(2)! : '';
    return tail.replaceRange(link.start, link.end, label);
  }
  final label = _partialLabel.firstMatch(tail);
  if (label != null) {
    final before = label.start > 0 ? tail[label.start - 1] : '';
    if (before == r'\') return tail;
    final text = label.group(2)!;
    // `- [ ]` / `- [x]` task markers are complete on their own.
    if (RegExp(r'^[ xX]$').hasMatch(text)) return tail;
    final keep = label.group(1)!.isEmpty ? text : '';
    return tail.replaceRange(label.start, label.end, keep);
  }
  return tail;
}

class _Opener {
  _Opener(this.position, this.marker);

  final int position;
  final String marker;
}

bool _isWordChar(String c) => RegExp('[A-Za-z0-9]').hasMatch(c);
bool _isSpace(String c) => c.trim().isEmpty;

/// Closes unbalanced `**`, `*`, `~~` and backtick code spans in [tail], in
/// reverse opening order; a marker with nothing after it is dropped.
String _repairEmphasis(String tail) {
  _Opener? strong;
  _Opener? em;
  _Opener? strike;
  _Opener? code;
  var i = 0;
  final n = tail.length;
  while (i < n) {
    final c = tail[i];
    if (c == r'\' && i + 1 < n) {
      i += 2;
      continue;
    }
    if (c == '`') {
      var j = i;
      while (j < n && tail[j] == '`') {
        j++;
      }
      final run = tail.substring(i, j);
      if (code == null) {
        code = _Opener(i, run);
      } else if (code.marker == run) {
        code = null;
      }
      i = j;
      continue;
    }
    if (code != null) {
      i++;
      continue;
    }
    if (c == '~' && i + 1 < n && tail[i + 1] == '~') {
      strike = strike == null ? _Opener(i, '~~') : null;
      i += 2;
      continue;
    }
    if (c == '*') {
      var j = i;
      while (j < n && tail[j] == '*') {
        j++;
      }
      var count = j - i;
      final prev = i > 0 ? tail[i - 1] : '\n';
      final next = j < n ? tail[j] : '';
      final lineStart =
          i == 0 || tail.substring(0, i).split('\n').last.trim().isEmpty;
      if (count == 1 && lineStart && next == ' ') {
        i = j;
        continue;
      }
      if (_isWordChar(prev) && _isWordChar(next)) {
        i = j;
        continue;
      }
      if (_isSpace(prev) && next.isNotEmpty && _isSpace(next)) {
        i = j;
        continue;
      }
      var pos = i;
      if (count >= 2) {
        strong = strong == null ? _Opener(pos, '**') : null;
        count -= 2;
        pos += 2;
      }
      if (count == 1) {
        em = em == null ? _Opener(pos, '*') : null;
      }
      i = j;
      continue;
    }
    i++;
  }

  final open = <_Opener>[?strong, ?em, ?strike, ?code]
    ..sort((a, b) => b.position.compareTo(a.position));
  if (open.isEmpty) return tail;
  var result = tail;
  final closers = StringBuffer();
  for (final opener in open) {
    final after = result.substring(
      (opener.position + opener.marker.length).clamp(0, result.length),
    );
    if (after.trim().isEmpty && closers.isEmpty) {
      result = result.substring(0, opener.position);
      continue;
    }
    closers.write(opener.marker);
  }
  return '$result$closers';
}
