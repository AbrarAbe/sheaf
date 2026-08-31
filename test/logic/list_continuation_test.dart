import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/logic/list_continuation.dart';

void main() {
  // Helper: caret at end of text unless stated.
  FormatEdit? cont(String text, [int? caret]) =>
      continueList(text: text, caret: caret ?? text.length);

  group('marker carry-over', () {
    test('continues an unordered dash item', () {
      final r = cont('- bought milk')!;
      expect(r.text, '- bought milk\n- ');
      expect(r.selStart, r.text.length);
    });

    test('carries asterisk and plus markers verbatim', () {
      expect(cont('* a')!.text, '* a\n* ');
      expect(cont('+ a')!.text, '+ a\n+ ');
    });

    test('increments ordered numbers', () {
      expect(cont('1. first')!.text, '1. first\n2. ');
      expect(cont('9. ninth')!.text, '9. ninth\n10. ');
    });

    test('preserves the ordered delimiter style', () {
      expect(cont('1) first')!.text, '1) first\n2) ');
    });

    test('resets task checkboxes to unchecked', () {
      expect(cont('- [ ] open')!.text, '- [ ] open\n- [ ] ');
      expect(cont('- [x] done')!.text, '- [x] done\n- [ ] ');
    });

    test('preserves leading indentation', () {
      expect(cont('  - sub item')!.text, '  - sub item\n  - ');
      expect(cont('\t\t3. deep')!.text, '\t\t3. deep\n\t\t4. ');
    });
  });

  group('smart exit', () {
    test('empty dash item removes the marker instead of continuing', () {
      final r = cont('- ')!;
      expect(r.text, '');
      expect(r.selStart, 0);
    });

    test(
      'empty nested item removes marker and indent (no whitespace line)',
      () {
        final r = cont('  - ')!;
        expect(r.text, '');
        expect(r.selStart, 0);
      },
    );
  });

  group('non-list lines', () {
    test('returns null so the editor inserts a plain newline', () {
      expect(cont('just prose'), isNull);
      expect(cont('# A heading'), isNull);
      expect(cont(''), isNull);
    });

    test('a marker mid-line without trailing space is not a list item', () {
      expect(cont('use the *emphasis* here'), isNull);
    });
  });
}
