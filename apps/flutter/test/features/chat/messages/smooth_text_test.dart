// Failure modes of the paced reveal (`use-smooth-text.ts`):
// 1. restored history (not streaming at mount) shows everything at once
// 2. a stream that starts with > 60 chars already present skips the replay
// 3. reveal releases at word/punctuation boundaries, never mid-word, unless a
//    token runs past the 24-char lookahead
// 4. the rate drains the backlog over ~400 ms, clamped to 45..2400 chars/s, so
//    a large backlog does not take seconds and a tiny one still trickles
// 5. publishing is capped at 60 Hz
// 6. after the stream ends, the remaining tail drains within 400 ms
// 7. a rewrite that shrinks the content pulls the cursor back
// 8. a user Stop (snap) reveals everything immediately
// 9. a huge frame gap (background tab) cannot bank an unbounded budget
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/chat/messages/streaming/smooth_text.dart';

const _frame = Duration(microseconds: 16667);

/// Advances [pacer] frame by frame for [total].
void run(SmoothTextPacer pacer, Duration total, {Duration step = _frame}) {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    pacer.tick(step);
    elapsed += step;
  }
}

void main() {
  test('history renders in full without pacing', () {
    final pacer = SmoothTextPacer(content: 'Already here.', streaming: false);
    expect(pacer.visible, 'Already here.');
    expect(pacer.hasBacklog, isFalse);
  });

  test('a resume past 60 chars skips the replay', () {
    final long = 'x ' * 40;
    final pacer = SmoothTextPacer(content: long, streaming: true);
    expect(pacer.visible, long);
  });

  test('a short live stream starts empty and reveals whole words', () {
    final pacer = SmoothTextPacer(content: 'Hello', streaming: true);
    expect(pacer.visible, '');
    pacer.update('Hello wonderful world of words', streaming: true);
    final seen = <String>{};
    for (var i = 0; i < 120 && pacer.hasBacklog; i++) {
      pacer.tick(_frame);
      seen.add(pacer.visible);
    }
    for (final v in seen) {
      if (v.isEmpty || v == 'Hello wonderful world of words') continue;
      expect(
        RegExp(r'[\s.,!?;:)\]]$').hasMatch(v),
        isTrue,
        reason: '"$v" ends mid-word',
      );
    }
  });

  test('a token longer than the lookahead is released whole', () {
    final url = 'https://example.com/${'a' * 60}';
    final pacer = SmoothTextPacer(content: '', streaming: true)
      ..update(url, streaming: true);
    run(pacer, const Duration(milliseconds: 1500));
    expect(pacer.visible, url);
  });

  test('a large backlog drains in about the horizon, capped at 2400 cps', () {
    final pacer = SmoothTextPacer(content: '', streaming: true)
      ..update('word ' * 100, streaming: true); // 500 chars
    run(pacer, const Duration(milliseconds: 100));
    // 400 ms horizon → 1250 cps; 100 ms ≈ 125 chars (word-snapped).
    expect(pacer.visible.length, inInclusiveRange(90, 160));
  });

  test('a tiny backlog still trickles at the 45 cps floor', () {
    final pacer = SmoothTextPacer(content: '', streaming: true)
      ..update('a b ', streaming: true);
    run(pacer, const Duration(milliseconds: 120));
    expect(pacer.visible, isNotEmpty);
  });

  test('publishes at most 60 times per second', () {
    final pacer = SmoothTextPacer(content: '', streaming: true)
      ..update('a ' * 400, streaming: true);
    var publishes = 0;
    for (var i = 0; i < 240; i++) {
      if (pacer.tick(const Duration(microseconds: 4167))) publishes++;
    }
    // 240 ticks of 4.17 ms = 1 s of a 240 Hz display.
    expect(publishes, lessThanOrEqualTo(61));
  });

  test('after the stream ends the tail drains within 400 ms', () {
    final pacer = SmoothTextPacer(content: '', streaming: true)
      ..update('one two three four five six seven', streaming: true)
      ..update('one two three four five six seven', streaming: false);
    run(pacer, const Duration(milliseconds: 420));
    expect(pacer.hasBacklog, isFalse);
  });

  test('a shrinking rewrite pulls the cursor back', () {
    final pacer = SmoothTextPacer(content: '', streaming: true)
      ..update('alpha beta gamma ', streaming: true);
    run(pacer, const Duration(milliseconds: 500));
    pacer
      ..update('alpha ', streaming: true)
      ..tick(_frame);
    expect(pacer.visible, 'alpha ');
  });

  test('snap reveals everything at once', () {
    final pacer = SmoothTextPacer(content: '', streaming: true)
      ..update('lots of text here', streaming: true)
      ..snap();
    expect(pacer.visible, 'lots of text here');
  });

  test('a long frame gap is clamped to 100 ms of budget', () {
    final pacer = SmoothTextPacer(content: '', streaming: true)
      ..update('word ' * 100, streaming: true)
      ..tick(const Duration(seconds: 5));
    expect(pacer.visible.length, lessThan(300));
  });
}
