// Failure modes of the Prism-palette highlighter (`chat-content.tsx` 259-278,
// `packages/emcn/src/components/code/code.css`):
// 1. the seeded JSON line maps to the spec's token colours (punctuation,
//    property, string, boolean) in light and dark
// 2. aliases resolve (js, ts, tsx, sh, shell, py, html, xml, yml); an unknown
//    language falls back to the JavaScript grammar instead of throwing
// 3. the trailing newline is trimmed before highlighting; lines split
//    correctly across multi-line tokens (block comments)
// 4. plain text is never dropped (concatenated tokens == source)
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/messages/markdown/code_highlight.dart';

String joined(List<List<ChatCodeToken>> lines) =>
    lines.map((l) => l.map((t) => t.text).join()).join('\n');

Color? colorOf(
  List<List<ChatCodeToken>> lines,
  String text,
  Brightness brightness,
) {
  for (final line in lines) {
    for (final token in line) {
      if (token.text == text) {
        return prismTokenColor(token.type, brightness);
      }
    }
  }
  fail('no token "$text"');
}

void main() {
  const seeded = '{"workspace":"Flutter E2E workspace","seeded":true}';

  test('seeded JSON maps to the spec token colours (light)', () {
    final lines = highlightCode('$seeded\n', 'json');
    expect(lines, hasLength(1));
    expect(joined(lines), seeded);
    const l = Brightness.light;
    expect(colorOf(lines, '{', l), const Color(0xFF383838));
    expect(colorOf(lines, '"workspace"', l), const Color(0xFF0891B2));
    expect(colorOf(lines, ':', l), const Color(0xFF383838));
    expect(
      colorOf(lines, '"Flutter E2E workspace"', l),
      const Color(0xFFB45309),
    );
    expect(colorOf(lines, 'true', l), const Color(0xFF16A34A));
  });

  test('seeded JSON maps to the spec token colours (dark)', () {
    final lines = highlightCode(seeded, 'json');
    const d = Brightness.dark;
    expect(colorOf(lines, '}', d), const Color(0xFFD4D4D4));
    expect(colorOf(lines, '"seeded"', d), const Color(0xFF4FC3F7));
    expect(
      colorOf(lines, '"Flutter E2E workspace"', d),
      const Color(0xFFF39C6B),
    );
    expect(colorOf(lines, 'true', d), const Color(0xFFA5D6A7));
  });

  test('aliases resolve and keywords get the keyword colour', () {
    for (final lang in ['js', 'ts', 'tsx', 'jsx']) {
      final lines = highlightCode('const x = 1', lang);
      expect(
        colorOf(lines, 'const', Brightness.light),
        const Color(0xFF2F55FF),
        reason: lang,
      );
    }
    final py = highlightCode('def f():\n    return 1', 'py');
    expect(colorOf(py, 'def', Brightness.light), const Color(0xFF2F55FF));
    final sh = highlightCode('echo "hi"', 'sh');
    expect(joined(sh), 'echo "hi"');
    expect(
      joined(highlightCode('<a href="x">t</a>', 'html')),
      '<a href="x">t</a>',
    );
    expect(joined(highlightCode('a: 1', 'yml')), 'a: 1');
  });

  test('unknown languages fall back to JavaScript', () {
    final lines = highlightCode('return true', 'brainfuck');
    expect(colorOf(lines, 'return', Brightness.light), const Color(0xFF2F55FF));
  });

  test('multi-line tokens split per line without losing text', () {
    const source = '/* a\nb */\nlet y = "s"';
    final lines = highlightCode(source, 'javascript');
    expect(lines, hasLength(3));
    expect(joined(lines), source);
    expect(colorOf(lines, 'b */', Brightness.light), const Color(0xFF16A34A));
  });
}
