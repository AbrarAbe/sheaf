import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/logic/line_edit.dart';

void main() {
  group('indentBlock', () {
    test('indents a single-line collapsed caret at end of line', () {
      final r = indentBlock(text: 'hello', selStart: 5, selEnd: 5);
      expect(r.text, '  hello');
      expect(r.selStart, 7);
      expect(r.selEnd, 7);
    });

    test('indents a single-line caret mid-line', () {
      final r = indentBlock(text: 'hello', selStart: 3, selEnd: 3);
      expect(r.text, '  hello');
      expect(r.selStart, 5);
      expect(r.selEnd, 5);
    });

    test('indents every line in a multi-line selection', () {
      // 'first\nsecond\nthird' (18 chars) — selEnd=18 is past end, on
      // line 2. All 3 lines indent by 2. selEnd shifts by 6 (sum of
      // deltas for lines 0..2).
      final r = indentBlock(text: 'first\nsecond\nthird', selStart: 0, selEnd: 18);
      expect(r.text, '  first\n  second\n  third');
      expect(r.selStart, 2);
      expect(r.selEnd, 24);
    });

    test('indents only the touched line, leaving others alone', () {
      // 'a\nbb\nccc' — offsets 2..3 both land on line 1 ('bb'). Lines 0
      // and 2 are outside the selection's line range and stay unchanged.
      final r = indentBlock(text: 'a\nbb\nccc', selStart: 2, selEnd: 3);
      expect(r.text, 'a\n  bb\nccc');
      expect(r.selStart, 4);
      expect(r.selEnd, 5);
    });

    test('indents a caret at a line boundary (end of line)', () {
      // Caret at offset 1 (the newline at end of 'a') belongs to line 0.
      final r = indentBlock(text: 'a\nb', selStart: 1, selEnd: 1);
      expect(r.text, '  a\nb');
      expect(r.selStart, 3);
      expect(r.selEnd, 3);
    });

    test('indents a caret at the very start of text', () {
      final r = indentBlock(text: 'hello', selStart: 0, selEnd: 0);
      expect(r.text, '  hello');
      expect(r.selStart, 2);
      expect(r.selEnd, 2);
    });

    test('indents already-indented lines by two more spaces', () {
      // '  nested\n  still' (16 chars) — both lines indent by 2 more.
      final r = indentBlock(text: '  nested\n  still', selStart: 0, selEnd: 16);
      expect(r.text, '    nested\n    still');
      expect(r.selStart, 2);
      expect(r.selEnd, 20);
    });

    test('empty text is a no-op', () {
      final r = indentBlock(text: '', selStart: 0, selEnd: 0);
      expect(r.text, '');
      expect(r.selStart, 0);
      expect(r.selEnd, 0);
    });

    test('trailing newline with caret on the empty last line', () {
      // 'abc\n' — lines 0='abc', 1=''. Caret at offset 4 is on line 1.
      // Only that empty line gets indented; line 0 stays put.
      final r = indentBlock(text: 'abc\n', selStart: 4, selEnd: 4);
      expect(r.text, 'abc\n  ');
      expect(r.selStart, 6);
      expect(r.selEnd, 6);
    });

    test('selection with selStart > selEnd is normalized', () {
      // Same result as indentBlock(selStart:0, selEnd:5).
      final r = indentBlock(text: 'hello\nworld', selStart: 5, selEnd: 0);
      expect(r.text, '  hello\nworld');
      expect(r.selStart, 2);
      expect(r.selEnd, 7);
    });
  });

  group('outdentBlock', () {
    test('removes two leading spaces', () {
      final r = outdentBlock(text: '  hello', selStart: 0, selEnd: 7);
      expect(r.text, 'hello');
      expect(r.selStart, 0);
      expect(r.selEnd, 5);
    });

    test('removes one leading space (only one to remove)', () {
      final r = outdentBlock(text: ' hello', selStart: 0, selEnd: 6);
      expect(r.text, 'hello');
      expect(r.selStart, 0);
      expect(r.selEnd, 5);
    });

    test('no-op on lines with no leading space', () {
      final r = outdentBlock(text: 'hello', selStart: 0, selEnd: 5);
      expect(r.text, 'hello');
      expect(r.selStart, 0);
      expect(r.selEnd, 5);
    });

    test('outdents every touched line in a multi-line selection', () {
      // '  first\n  second\n  third' (24) → 'first\nsecond\nthird' (18).
      final r = outdentBlock(text: '  first\n  second\n  third', selStart: 0, selEnd: 24);
      expect(r.text, 'first\nsecond\nthird');
      expect(r.selStart, 0);
      expect(r.selEnd, 18);
    });

    test('leaves untouched lines alone', () {
      final r = outdentBlock(text: 'a\n  bb\nccc', selStart: 4, selEnd: 6);
      expect(r.text, 'a\nbb\nccc');
      expect(r.selStart, 2);
      expect(r.selEnd, 4);
    });

    test('mixed indentation: some lines no-op, some remove', () {
      // '  a\nb\n  c' (9) → 'a\nb\nc' (5). Deltas = [-2, 0, -2].
      final r = outdentBlock(text: '  a\nb\n  c', selStart: 0, selEnd: 9);
      expect(r.text, 'a\nb\nc');
      expect(r.selStart, 0);
      expect(r.selEnd, 5);
    });

    test('caret at end of an indented line', () {
      final r = outdentBlock(text: '  hi', selStart: 4, selEnd: 4);
      expect(r.text, 'hi');
      expect(r.selStart, 2);
      expect(r.selEnd, 2);
    });

    test('caret at start of an indented line moves back after removal', () {
      final r = outdentBlock(text: '  hi', selStart: 0, selEnd: 0);
      expect(r.text, 'hi');
      expect(r.selStart, 0);
      expect(r.selEnd, 0);
    });

    test('trailing newline with caret on empty last line — no-op', () {
      // 'a\n' — lines 0='a', 1=''. Caret at 2 is on empty line 1.
      final r = outdentBlock(text: 'a\n', selStart: 2, selEnd: 2);
      expect(r.text, 'a\n');
      expect(r.selStart, 2);
      expect(r.selEnd, 2);
    });

    test('empty text is a no-op', () {
      final r = outdentBlock(text: '', selStart: 0, selEnd: 0);
      expect(r.text, '');
      expect(r.selStart, 0);
      expect(r.selEnd, 0);
    });

    test('never removes a tab character (only spaces)', () {
      final r = outdentBlock(text: '\thi', selStart: 0, selEnd: 3);
      expect(r.text, '\thi');
      expect(r.selStart, 0);
      expect(r.selEnd, 3);
    });
  });

  group('selection preservation', () {
    test('indent then outdent on a multi-line block round-trips selection', () {
      // Caret at offset 8 is on line 1 of 'first\nsecond\nthird' — only
      // line 1 indents. Outindent of the result maps the caret back.
      const text = 'first\nsecond\nthird';
      final after = indentBlock(text: text, selStart: 8, selEnd: 8);
      expect(after.text, 'first\n  second\nthird');
      expect(after.selStart, 10);
      expect(after.selEnd, 10);
      final round = outdentBlock(
        text: after.text,
        selStart: after.selStart,
        selEnd: after.selEnd,
      );
      expect(round.text, text);
      expect(round.selStart, 8);
      expect(round.selEnd, 8);
    });

    test('round-trip on an empty-text edge case', () {
      const text = '';
      final after = indentBlock(text: text, selStart: 0, selEnd: 0);
      final back = outdentBlock(text: after.text, selStart: 0, selEnd: 0);
      expect(back.text, text);
      expect(back.selStart, 0);
      expect(back.selEnd, 0);
    });
  });
}
