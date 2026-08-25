import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/logic/formatting.dart';

void main() {
  group('toggleWrap — wrapping', () {
    test('wraps a plain selection', () {
      final r = toggleWrap(text: 'hello world', selStart: 0, selEnd: 5, open: '**');
      expect(r.text, '**hello** world');
      expect(r.selStart, 2);
      expect(r.selEnd, 7);
    });

    test('wraps a mid-string selection', () {
      final r = toggleWrap(text: 'plain words', selStart: 6, selEnd: 11, open: '*');
      expect(r.text, 'plain *words*');
      expect(r.selStart, 7);
      expect(r.selEnd, 12);
    });

    test('inserts an empty pair at a collapsed caret', () {
      final r = toggleWrap(text: 'ab', selStart: 1, selEnd: 1, open: '**');
      expect(r.text, 'a****b');
      expect(r.selStart, 3);
      expect(r.selEnd, 3);
    });

    test('uses asymmetric markers for underline', () {
      final r = toggleWrap(text: 'go', selStart: 0, selEnd: 2, open: '<u>', close: '</u>');
      expect(r.text, '<u>go</u>');
      expect(r.selStart, 3);
      expect(r.selEnd, 5);
    });
  });

  group('toggleWrap — unwrapping', () {
    test('exact wrapped selection unwraps', () {
      final r = toggleWrap(text: '**bold**', selStart: 0, selEnd: 8, open: '**');
      expect(r.text, 'bold');
      expect(r.selStart, 0);
      expect(r.selEnd, 4);
    });

    test('wrapped selection with asymmetric markers unwraps', () {
      final r = toggleWrap(
        text: 'a <u>u</u> b',
        selStart: 2,
        selEnd: 10,
        open: '<u>',
        close: '</u>',
      );
      expect(r.text, 'a u b');
      expect(r.selStart, 2);
      expect(r.selEnd, 3);
    });

    test('collapsed caret between adjacent markers removes them', () {
      // Caret sits right after "**" and right before "**".
      final r = toggleWrap(text: 'a****b', selStart: 3, selEnd: 3, open: '**');
      expect(r.text, 'ab');
      expect(r.selStart, 1);
      expect(r.selEnd, 1);
    });
  });

  group('toggleWrap — unwrap from inside (feedback F1)', () {
    test('bare caret inside a span unwraps it', () {
      final r = toggleWrap(text: '**bold**', selStart: 4, selEnd: 4, open: '**');
      expect(r.text, 'bold');
      expect(r.selStart, 2);
    });

    test('caret at the inner start edge unwraps', () {
      final r = toggleWrap(text: '**bold**', selStart: 2, selEnd: 2, open: '**');
      expect(r.text, 'bold');
      expect(r.selStart, 0);
    });

    test('partial selection inside unwraps the whole span', () {
      // Selection covers 'ol' only.
      final r = toggleWrap(text: '**bold**', selStart: 3, selEnd: 5, open: '**');
      expect(r.text, 'bold');
      expect(r.selStart, 1);
      expect(r.selEnd, 3);
    });

    test('asymmetric underline span unwraps from a bare caret', () {
      // Caret sits after the 'g'; unwrap keeps it after that same glyph.
      final r = toggleWrap(text: '<u>go</u>', selStart: 4, selEnd: 4, open: '<u>', close: '</u>');
      expect(r.text, 'go');
      expect(r.selStart, 1);
    });

    test('smallest containing span wins when nested', () {
      final r = toggleWrap(text: '**bold and *sharp***', selStart: 12, selEnd: 12, open: '*');
      // Caret inside *sharp*: italic markers go, bold stays.
      expect(r.text, '**bold and sharp**');
    });

    test('selection reaching past both span edges unwraps the span (F20)', () {
      // Enveloping selections used to fall through to a nested re-wrap;
      // overlap-with-inner now unwraps predictably instead.
      final r = toggleWrap(text: 'a **b** c', selStart: 0, selEnd: 9, open: '**');
      expect(r.text, 'a b c');
      expect(r.selStart, 0);
      expect(r.selEnd, 5);
    });

    test('empty-pair caret still collapses the pair first', () {
      final r = toggleWrap(text: 'a****b', selStart: 3, selEnd: 3, open: '**');
      expect(r.text, 'ab');
    });
  });

  group('toggleWrap — marker-inclusive selections (feedback F11/F20)', () {
    test('bold wrap↔untoggle cycle is stable over three iterations', () {
      var text = 'word';
      var sel = (0, 4);
      for (var i = 0; i < 3; i++) {
        final wrapped = toggleWrap(text: text, selStart: sel.$1, selEnd: sel.$2, open: '**');
        expect(wrapped.text, '**word**', reason: 'iteration $i wrap');
        expect((wrapped.selStart, wrapped.selEnd), (2, 6), reason: 'iteration $i wrap sel');

        final unwrapped = toggleWrap(
          text: wrapped.text,
          selStart: wrapped.selStart,
          selEnd: wrapped.selEnd,
          open: '**',
        );
        expect(unwrapped.text, 'word', reason: 'iteration $i unwrap');
        expect((unwrapped.selStart, unwrapped.selEnd), (0, 4), reason: 'iteration $i unwrap sel');
        text = unwrapped.text;
        sel = (unwrapped.selStart, unwrapped.selEnd);
      }
    });

    test('untoggle cycle survives a selection covering the whole span', () {
      // Marker-inclusive selection (e.g. after a line-wide select-all):
      // used to fail containment and nest a second layer.
      final r = toggleWrap(text: '**word**', selStart: 0, selEnd: 8, open: '**');
      expect(r.text, 'word');
      expect((r.selStart, r.selEnd), (0, 4));
    });

    test('selection crossing the leading marker unwraps', () {
      final r = toggleWrap(text: '**bold**', selStart: 0, selEnd: 4, open: '**');
      expect(r.text, 'bold');
      expect((r.selStart, r.selEnd), (0, 2));
    });

    test('selection crossing the trailing marker unwraps without right-shrink', () {
      // The exact reported drift: selection grew over the closing marker.
      final r = toggleWrap(text: '**bold**', selStart: 4, selEnd: 8, open: '**');
      expect(r.text, 'bold');
      expect((r.selStart, r.selEnd), (2, 4));
    });

    test('italic cycle from a marker-crossing selection stays put', () {
      final first = toggleWrap(text: 'sharp', selStart: 0, selEnd: 5, open: '*');
      expect(first.text, '*sharp*');

      // Shift+Right once past the closing star, then toggle.
      final second = toggleWrap(text: first.text, selStart: 1, selEnd: 7, open: '*');
      expect(second.text, 'sharp');
      expect((second.selStart, second.selEnd), (0, 5));

      final third = toggleWrap(
        text: second.text,
        selStart: second.selStart,
        selEnd: second.selEnd,
        open: '*',
      );
      expect(third.text, '*sharp*');
    });

    test('underline selection crossing </u> unwraps with correct remap', () {
      final r = toggleWrap(text: '<u>go</u>', selStart: 0, selEnd: 6, open: '<u>', close: '</u>');
      expect(r.text, 'go');
      expect((r.selStart, r.selEnd), (0, 2));
    });

    test('enveloping selection with text on both sides maps cleanly', () {
      final r = toggleWrap(text: 'x **y**', selStart: 0, selEnd: 7, open: '**');
      expect(r.text, 'x y');
      expect((r.selStart, r.selEnd), (0, 3));
    });

    test('nested spans peel one layer per toggle', () {
      const nested = '**bold and *sharp***';
      final italicOff = toggleWrap(text: nested, selStart: 14, selEnd: 17, open: '*');
      expect(italicOff.text, '**bold and sharp**');
      expect((italicOff.selStart, italicOff.selEnd), (13, 16));

      final boldOff = toggleWrap(
        text: italicOff.text,
        selStart: italicOff.selStart,
        selEnd: italicOff.selEnd,
        open: '**',
      );
      expect(boldOff.text, 'bold and sharp');
      expect((boldOff.selStart, boldOff.selEnd), (11, 14));
    });

    test('degenerate empty-inner matches never win (adjacent markers)', () {
      // '**' pairs around 'a' must not be misread as empty italic spans when
      // hunting single-star spans; the real *b* span is the one unwrapped.
      final r = toggleWrap(text: '**a** *b*', selStart: 2, selEnd: 9, open: '*');
      expect(r.text, '**a** b');
      expect((r.selStart, r.selEnd), (2, 7));

      // Bare caret inside 'b' takes the same route.
      final caret = toggleWrap(text: '**a** *b*', selStart: 7, selEnd: 7, open: '*');
      expect(caret.text, '**a** b');
      expect((caret.selStart, caret.selEnd), (6, 6));
    });
  });

  group('wordBoundary (feedback F6)', () {
    test('selects the word under the caret', () {
      expect(wordBoundary('foo bar baz', 5), (4, 7));
      expect(wordBoundary('foo bar baz', 0), (0, 3));
      expect(wordBoundary('foo bar baz', 2), (0, 3));
    });

    test('trailing edge of a word selects backwards onto it', () {
      expect(wordBoundary('foo bar', 3), (0, 3));
      expect(wordBoundary('foo bar', 7), (4, 7));
    });

    test('whitespace runs select themselves', () {
      expect(wordBoundary('ab    cd', 4), (2, 6));
    });

    test('punctuation forms its own run when not after a word', () {
      expect(wordBoundary('(x)', 0), (0, 1));
      expect(wordBoundary(' . ', 1), (1, 2));
    });

    test('empty text and out-of-range carets are safe', () {
      expect(wordBoundary('', 0), (0, 0));
      expect(wordBoundary('abc', 99), (0, 3));
    });
  });
}
