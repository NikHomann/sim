// Failure modes for the reference-token tokenizer
// (ports of packages/workflow-renderer/src/formatted-text.tsx and
// packages/utils/src/workflow-references.ts):
//  tokenizeDisplayText
//   1. Empty text yields no spans; text without tokens is one plain span.
//   2. `<a.b>` with highlightAll is a blockReference with exact offsets and
//      the surrounding text is plain; spans concatenate back to the input.
//   3. `{{ENV}}` is an envReference; an env var missing from
//      `availableEnvVars` is `invalid`; without `availableEnvVars` every env
//      token is highlighted; the lookup trims the inner name while the span
//      keeps braces and whitespace.
//   4. Incomplete and nested delimiters: `<a.b` is plain, `<a<b>` yields only
//      `<b>`, `{{a{{b}}` yields only `{{b}}`, `{{}}` and `<>` are plain.
//   5. Accessible prefixes are compared after normalisation
//      (`<Agent 1.content>` matches `agent1`); `loop`/`parallel`/`variable`
//      are always highlighted; an inaccessible prefix is `invalid`.
//   6. A backslash does not escape a token (upstream has no escape syntax).
//   7. Search highlight: a valid range marks the spans inside it and splits a
//      token at its boundaries; a range whose rawValue does not match, is out
//      of bounds, or is empty is ignored.
//   8. Adjacent tokens `<a.b><c.d>{{E}}` are contiguous with no gaps.
//   9. A newline inside `<a\n.b>` still tokenizes in display text (the
//      renderer regex allows it) but not in findWorkflowReferenceTokens.
//  10. Offsets are UTF-16 code units (an astral-plane emoji counts as two).
//  11. 100k unterminated braces tokenize in well under a second.
//  findWorkflowReferenceTokens / isLikelyWorkflowReferenceSegment
//  12. Comparison expressions (`x < 3 && y > 2`, `<= 5 >`) are not references;
//      a purely numeric `<5>` is not; `<start.input>` and `<loop.index>` are.
//  13. Leading comparison characters are stripped (`<<a.b>` → `<a.b>` at
//      offset 1) and env tokens win over an overlapping workflow candidate.
//  14. Tokens are returned sorted by start regardless of kind order.
import 'package:sim_workflow/sim_workflow.dart';
import 'package:test/test.dart';

String _join(List<ReferenceSpan> spans) => spans.map((s) => s.text).join();

void main() {
  group('tokenizeDisplayText', () {
    test('1. empty and token-less text', () {
      expect(tokenizeDisplayText(''), isEmpty);
      final spans = tokenizeDisplayText('hello world');
      expect(spans, hasLength(1));
      expect(spans.single.kind, ReferenceSpanKind.plain);
      expect(spans.single.start, 0);
      expect(spans.single.end, 11);
    });

    test('2. block reference with offsets', () {
      const text = 'Hi <a.b>!';
      final spans = tokenizeDisplayText(
        text,
        const HighlightContext(highlightAll: true),
      );
      expect(spans.map((s) => s.kind), [
        ReferenceSpanKind.plain,
        ReferenceSpanKind.blockReference,
        ReferenceSpanKind.plain,
      ]);
      expect(spans[1].start, 3);
      expect(spans[1].end, 8);
      expect(spans[1].text, '<a.b>');
      expect(_join(spans), text);
    });

    test('3. env references', () {
      final known = tokenizeDisplayText(
        'k={{ API_KEY }}',
        const HighlightContext(availableEnvVars: {'API_KEY'}),
      );
      expect(known.last.kind, ReferenceSpanKind.envReference);
      expect(known.last.text, '{{ API_KEY }}');
      expect(known.last.start, 2);
      final unknown = tokenizeDisplayText(
        '{{NOPE}}',
        const HighlightContext(availableEnvVars: {'API_KEY'}),
      );
      expect(unknown.single.kind, ReferenceSpanKind.invalid);
      expect(
        tokenizeDisplayText('{{ANY}}').single.kind,
        ReferenceSpanKind.envReference,
      );
    });

    test('4. incomplete and nested delimiters', () {
      const ctx = HighlightContext(highlightAll: true);
      expect(
        tokenizeDisplayText('<a.b', ctx).single.kind,
        ReferenceSpanKind.plain,
      );
      final nested = tokenizeDisplayText('<a<b>', ctx);
      expect(
        nested.map((s) => (s.kind, s.text)),
        [
          (ReferenceSpanKind.plain, '<a'),
          (ReferenceSpanKind.blockReference, '<b>'),
        ],
      );
      final braces = tokenizeDisplayText('{{a{{b}}', ctx);
      expect(
        braces.map((s) => (s.kind, s.text)),
        [
          (ReferenceSpanKind.plain, '{{a'),
          (ReferenceSpanKind.envReference, '{{b}}'),
        ],
      );
      expect(
        tokenizeDisplayText('{{}} <>', ctx).single.kind,
        ReferenceSpanKind.plain,
      );
    });

    test('5. accessible prefixes and system prefixes', () {
      const ctx = HighlightContext(accessiblePrefixes: {'agent1'});
      expect(
        tokenizeDisplayText('<Agent 1.content>', ctx).single.kind,
        ReferenceSpanKind.blockReference,
      );
      expect(
        tokenizeDisplayText('<loop.index>', ctx).single.kind,
        ReferenceSpanKind.blockReference,
      );
      expect(
        tokenizeDisplayText('<Variable.x>', ctx).single.kind,
        ReferenceSpanKind.blockReference,
      );
      expect(
        tokenizeDisplayText('<other.x>', ctx).single.kind,
        ReferenceSpanKind.invalid,
      );
      expect(
        tokenizeDisplayText('<other.x>', const HighlightContext()).single.kind,
        ReferenceSpanKind.invalid,
      );
    });

    test('6. backslash does not escape', () {
      final spans = tokenizeDisplayText(
        r'\<a.b>',
        const HighlightContext(highlightAll: true),
      );
      expect(spans.map((s) => s.kind), [
        ReferenceSpanKind.plain,
        ReferenceSpanKind.blockReference,
      ]);
    });

    test('7. search highlight range', () {
      const text = 'x <a.b> y';
      final marked = tokenizeDisplayText(
        text,
        const HighlightContext(
          highlightAll: true,
          workflowSearchHighlight: WorkflowSearchTextHighlight(
            range: WorkflowTextRange(start: 2, end: 7),
            rawValue: '<a.b>',
          ),
        ),
      );
      expect(marked.map((s) => s.searchHighlight), [false, true, false]);
      expect(marked[1].kind, ReferenceSpanKind.blockReference);
      expect(_join(marked), text);

      final split = tokenizeDisplayText(
        text,
        const HighlightContext(
          highlightAll: true,
          workflowSearchHighlight: WorkflowSearchTextHighlight(
            range: WorkflowTextRange(start: 2, end: 4),
            rawValue: '<a',
          ),
        ),
      );
      expect(split.every((s) => s.kind == ReferenceSpanKind.plain), isTrue);
      expect(split.map((s) => s.text), ['x ', '<a', '.b> y']);
      expect(split.map((s) => s.start), [0, 2, 4]);

      for (final bad in [
        const WorkflowSearchTextHighlight(
          range: WorkflowTextRange(start: 2, end: 7),
          rawValue: 'wrong',
        ),
        const WorkflowSearchTextHighlight(
          range: WorkflowTextRange(start: 2, end: 99),
          rawValue: '<a.b>',
        ),
        const WorkflowSearchTextHighlight(
          range: WorkflowTextRange(start: 3, end: 3),
          rawValue: '',
        ),
        const WorkflowSearchTextHighlight(rawValue: '<a.b>'),
      ]) {
        expect(getValidWorkflowSearchRange(text, bad), isNull);
        final spans = tokenizeDisplayText(
          text,
          HighlightContext(highlightAll: true, workflowSearchHighlight: bad),
        );
        expect(spans.any((s) => s.searchHighlight), isFalse);
      }
    });

    test('8. adjacent tokens are contiguous', () {
      const text = '<a.b><c.d>{{E}}';
      final spans = tokenizeDisplayText(
        text,
        const HighlightContext(highlightAll: true),
      );
      expect(spans, hasLength(3));
      for (var i = 1; i < spans.length; i++) {
        expect(spans[i].start, spans[i - 1].end);
      }
      expect(_join(spans), text);
    });

    test('9. newline inside a reference', () {
      final spans = tokenizeDisplayText(
        '<a\n.b>',
        const HighlightContext(highlightAll: true),
      );
      expect(spans.single.kind, ReferenceSpanKind.blockReference);
      expect(findWorkflowReferenceTokens('<a\n.b>'), isEmpty);
    });

    test('10. offsets are UTF-16 code units', () {
      final spans = tokenizeDisplayText(
        '😀<a.b>',
        const HighlightContext(highlightAll: true),
      );
      expect(spans[1].start, 2);
      expect(spans[1].end, 7);
    });

    test('11. pathological input is linear', () {
      final watch = Stopwatch()..start();
      tokenizeDisplayText('{' * 100000);
      findWorkflowReferenceTokens('<' * 100000);
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('findWorkflowReferenceTokens', () {
    test('12. comparison expressions are not references', () {
      expect(findWorkflowReferenceTokens('x < 3 && y > 2'), isEmpty);
      expect(findWorkflowReferenceTokens('<= 5 >'), isEmpty);
      expect(findWorkflowReferenceTokens('<5>'), isEmpty);
      expect(isLikelyWorkflowReferenceSegment('< a.b>'), isFalse);
      expect(isLikelyWorkflowReferenceSegment('<a.b c>'), isFalse);
      expect(isLikelyWorkflowReferenceSegment('<a+b>'), isFalse);
      final found = findWorkflowReferenceTokens('<start.input> <loop.index>');
      expect(found.map((t) => t.value), ['<start.input>', '<loop.index>']);
      expect(found.map((t) => t.kind), [
        WorkflowReferenceTokenKind.workflow,
        WorkflowReferenceTokenKind.workflow,
      ]);
      expect(found.first.start, 0);
      expect(found.first.end, 13);
    });

    test('13. leading comparison characters and env precedence', () {
      final stripped = findWorkflowReferenceTokens('<<a.b>');
      expect(stripped.single.value, '<a.b>');
      expect(stripped.single.start, 1);
      expect(splitWorkflowReferenceSegment('<<a.b>'), (
        leading: '<',
        reference: '<a.b>',
      ));
      expect(splitWorkflowReferenceSegment('a.b>'), isNull);
      final overlapping = findWorkflowReferenceTokens('<{{E}}.x>');
      expect(overlapping.map((t) => t.kind), [
        WorkflowReferenceTokenKind.environment,
      ]);
    });

    test('14. tokens are sorted by start', () {
      final tokens = findWorkflowReferenceTokens('<a.b> {{E}} <c.d>');
      expect(tokens.map((t) => t.start), [0, 6, 12]);
      expect(tokens[1].kind, WorkflowReferenceTokenKind.environment);
      expect(tokens[1].end, 11);
    });
  });
}
