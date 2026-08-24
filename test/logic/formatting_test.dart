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

    test('selection reaching outside the span still wraps outward', () {
      final r = toggleWrap(text: 'a **b** c', selStart: 0, selEnd: 9, open: '**');
      expect(r.text, '**a **b** c**');
    });

    test('empty-pair caret still collapses the pair first', () {
      final r = toggleWrap(text: 'a****b', selStart: 3, selEnd: 3, open: '**');
      expect(r.text, 'ab');
    });
  });
}
