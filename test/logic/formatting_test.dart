import 'package:flutter/widgets.dart';
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

    test('collapsed caret on a word wraps the word (feedback F10)', () {
      // A bare caret resting on a word formats the whole word rather than
      // splicing an empty pair into it (also why Ctrl+U looked dead).
      final r = toggleWrap(text: 'ab', selStart: 1, selEnd: 1, open: '**');
      expect(r.text, '**ab**');
      // Collapsed: caret parks back on its original character (1 -> 3).
      expect(r.caret, 3);
      expect(r.selStart, 2);
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
      // Collapsed: caret parks back on its original character (4 -> 2).
      expect(r.caret, 2);
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
      expect(r.caret, 1);
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
      // Collapsed caret parks back on the same glyph (index 7 -> 6 after the
      // leading star is removed) rather than shifting with the word range.
      expect(caret.caret, 6);
    });
  });

  group('toggleWrap — caret touching markers (feedback F25)', () {
    test('caret before the opener unwraps instead of splicing', () {
      final r = toggleWrap(text: '*word*', selStart: 0, selEnd: 0, open: '*');
      expect(r.text, 'word');
      expect((r.selStart, r.selEnd), (0, 0));
    });

    test('caret after the closer unwraps', () {
      final r = toggleWrap(text: '<u>go</u>', selStart: 9, selEnd: 9, open: '<u>', close: '</u>');
      expect(r.text, 'go');
    });

    test('caret in whitespace still inserts an empty pair', () {
      // A collapsed caret that is NOT on a word keeps the old empty-pair
      // behaviour so bold/italic can be started in blank space (feedback F10
      // only wraps when the caret rests on a word).
      final r = toggleWrap(text: '  ', selStart: 1, selEnd: 1, open: '**');
      expect(r.text, ' **** ');
      expect(r.selStart, 3);
    });
  });

  group('toggleWrap — editor-cycle regression (feedback F28)', () {
    // Mirrors _EditorState._applyFormat so the test exercises the exact code
    // path the key handler drives: a collapsed caret expands to the word
    // (F10), selection persists between presses, and a second identical press
    // must TOGGLE OFF rather than re-wrap into the opposite style.
    TextEditingValue applyFormat(TextEditingValue value, FormatKind kind) {
      final sel = value.selection;
      if (!sel.isValid) return value;
      final r = toggleWrap(
        text: value.text,
        selStart: sel.start,
        selEnd: sel.end,
        open: kind.open,
        close: kind.close,
      );
      // Mirror of _EditorState._applyFormat: a bare caret parks back on its
      // original character (collapsed); a real selection keeps the formatted
      // range highlighted so a second press toggles it off.
      final next = sel.isCollapsed
          ? TextSelection.collapsed(offset: r.caret)
          : TextSelection(baseOffset: r.selStart, extentOffset: r.selEnd);
      return TextEditingValue(text: r.text, selection: next);
    }

    test('italic toggles off on a second press (no bold side-effect)', () {
      var v = const TextEditingValue(
        text: 'word',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
      );
      // Press 1: wraps to italic.
      v = applyFormat(v, FormatKind.italic);
      expect(v.text, '*word*');
      expect(v.selection, const TextSelection(baseOffset: 1, extentOffset: 5));
      // Press 2: the same italic intent must UNWRAP back to plain.
      v = applyFormat(v, FormatKind.italic);
      expect(v.text, 'word');
      expect((v.selection.start, v.selection.end), (0, 4));
      // Press 3: wraps again — a real toggle, not a one-way loop.
      v = applyFormat(v, FormatKind.italic);
      expect(v.text, '*word*');
    });

    test('bold toggles off on a second press (no italic side-effect)', () {
      var v = const TextEditingValue(
        text: 'word',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
      );
      v = applyFormat(v, FormatKind.bold);
      expect(v.text, '**word**');
      expect(v.selection, const TextSelection(baseOffset: 2, extentOffset: 6));
      v = applyFormat(v, FormatKind.bold);
      expect(v.text, 'word', reason: 'second bold press must unwrap, not nest');
      expect((v.selection.start, v.selection.end), (0, 4));
    });

    test('italic from a bare caret expands the word then toggles off', () {
      // Caret parked at the end of the word (collapsed), as after typing.
      var v = const TextEditingValue(text: 'word', selection: TextSelection.collapsed(offset: 4));
      v = applyFormat(v, FormatKind.italic);
      expect(v.text, '*word*');
      // Collapsed caret parks back on its original character (offset 4 -> 5 once
      // the single '*' is inserted before the word), not a trailing selection.
      expect(v.selection.isCollapsed, isTrue);
      expect(v.selection.baseOffset, 5);
      // A second press unwraps cleanly: the caret is collapsed (so the
      // word-boundary branch is skipped) and sits inside the span it unwraps.
      v = applyFormat(v, FormatKind.italic);
      expect(v.text, 'word');
    });
  });

  group('toggleWrap — caret park position (italic drift fix)', () {
    test('wrap parks caret after the close marker', () {
      final r = toggleWrap(text: 'word', selStart: 0, selEnd: 4, open: '*');
      expect(r.text, '*word*');
      expect(r.caret, 6, reason: 'caret sits after the closing star on wrap');
    });

    test('bold wrap parks caret after **', () {
      final r = toggleWrap(text: 'word', selStart: 0, selEnd: 4, open: '**');
      expect(r.text, '**word**');
      expect(r.caret, 8);
    });

    test('asymmetric underline wrap parks caret past </u>', () {
      final r = toggleWrap(text: 'go', selStart: 0, selEnd: 2, open: '<u>', close: '</u>');
      expect(r.text, '<u>go</u>');
      expect(r.caret, 9);
    });

    test('unwrap parks caret at the end of the now-plain word', () {
      final r = toggleWrap(text: '**word**', selStart: 0, selEnd: 8, open: '**');
      expect(r.text, 'word');
      expect(r.caret, 4);
    });

    test('editor-applied wrap keeps the caret on the same character (F30)', () {
      // Mirrors _EditorState._applyFormat: a collapsed caret after a wrap must
      // land on the same character it started on (offset 4 -> 5 once the '*'
      // is inserted before the word), so a keypress edits the word in place
      // instead of appending after the close marker.
      final v = const TextEditingValue(text: 'word', selection: TextSelection.collapsed(offset: 4));
      final r = toggleWrap(
        text: v.text,
        selStart: v.selection.start,
        selEnd: v.selection.end,
        open: '*',
        close: '*',
      );
      final applied = TextEditingValue(
        text: r.text,
        selection: TextSelection.collapsed(offset: r.caret),
      );
      expect(
        applied.selection.baseOffset,
        5,
        reason: 'caret stays on the last char, not past the close marker',
      );
      final typed = applied.text.replaceRange(
        applied.selection.baseOffset,
        applied.selection.extentOffset,
        'x',
      );
      expect(typed, '*wordx*', reason: 'typing extends the word inside the markers');
    });
  });

  group('toggleWrap — caret/selection preservation (feedback F30)', () {
    // Mirror of _EditorState._applyFormat exactly.
    TextEditingValue applyFormat(TextEditingValue value, FormatKind kind) {
      final sel = value.selection;
      if (!sel.isValid) return value;
      final r = toggleWrap(
        text: value.text,
        selStart: sel.start,
        selEnd: sel.end,
        open: kind.open,
        close: kind.close,
      );
      final next = sel.isCollapsed
          ? TextSelection.collapsed(offset: r.caret)
          : TextSelection(baseOffset: r.selStart, extentOffset: r.selEnd);
      return TextEditingValue(text: r.text, selection: next);
    }

    test('collapsed caret parks inside the span and editing extends the word', () {
      final v = const TextEditingValue(text: 'word', selection: TextSelection.collapsed(offset: 4));
      final out = applyFormat(v, FormatKind.bold);
      expect(out.text, '**word**');
      expect(out.selection.isCollapsed, isTrue);
      expect(out.selection.baseOffset, 6); // origCaret 4 + 2 '**'
      final typed = out.text.replaceRange(out.selection.baseOffset, out.selection.baseOffset, 'x');
      expect(typed, '**wordx**');
    });

    test('collapsed caret keeps its mid-word position', () {
      final v = const TextEditingValue(
        text: 'hello',
        selection: TextSelection.collapsed(offset: 3),
      );
      final out = applyFormat(v, FormatKind.bold);
      expect(out.text, '**hello**');
      expect(out.selection.isCollapsed, isTrue);
      expect(out.selection.baseOffset, 5); // 3 + 2
    });

    test('real selection stays selected so a second press toggles off', () {
      final v = const TextEditingValue(
        text: 'word',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
      );
      final wrapped = applyFormat(v, FormatKind.italic);
      expect(wrapped.selection, const TextSelection(baseOffset: 1, extentOffset: 5));
      final unwrapped = applyFormat(wrapped, FormatKind.italic);
      expect(unwrapped.text, 'word');
      expect(unwrapped.selection, const TextSelection(baseOffset: 0, extentOffset: 4));
    });

    test('collapsed caret unwrapping returns to the same character', () {
      final v = const TextEditingValue(
        text: '**word**',
        selection: TextSelection.collapsed(offset: 4),
      );
      final out = applyFormat(v, FormatKind.bold); // caret inside the word -> unwrap
      expect(out.text, 'word');
      expect(out.selection.isCollapsed, isTrue);
      expect(out.selection.baseOffset, 2); // 4 - 2 '**'
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
