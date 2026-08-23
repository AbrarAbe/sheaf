import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/logic/image_link.dart';

void main() {
  const link = '![pic](attachments/pic.png)';

  test('inserts at a middle offset and parks the caret after the link', () {
    final r = insertImageLink(body: 'beforeXafter', link: link, offset: 6);
    expect(r.text, 'before${link}Xafter');
    expect(r.caret, 6 + link.length);
  });

  test('negative or out-of-range offsets clamp to the end', () {
    final r = insertImageLink(body: 'abc', link: link, offset: -5);
    expect(r.text, 'abc$link');
    expect(r.caret, 3 + link.length);

    final r2 = insertImageLink(body: 'abc', link: link, offset: 99);
    expect(r2.text, 'abc$link');
  });

  test('empty body works', () {
    final r = insertImageLink(body: '', link: link);
    expect(r.text, link);
    expect(r.caret, link.length);
  });
}
