import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/font_scanner.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_font_scan_test');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  Future<Directory> dir(String path) async {
    final d = Directory('${tempDir.path}/$path');
    await d.create(recursive: true);
    return d;
  }

  test('finds ttf/otf/ttc files and skips everything else', () async {
    final fonts = await dir('fonts');
    File('${fonts.path}/Iosevka-Regular.ttf').writeAsBytesSync([0]);
    File('${fonts.path}/Fira Code.otf').writeAsBytesSync([0]);
    File('${fonts.path}/Collection.ttc').writeAsBytesSync([0]);
    File('${fonts.path}/notes.txt').writeAsStringSync('nope');
    File('${fonts.path}/image.png').writeAsBytesSync([0]);

    final found = await scanFonts(roots: [fonts.path]);

    expect(found.map((f) => f.name).toSet(), {'Iosevka-Regular', 'Fira Code', 'Collection'});
  });

  test('scans multiple roots and dedupes by resolved path', () async {
    final a = await dir('a');
    final b = await dir('b');
    File('${a.path}/Same.ttf').writeAsBytesSync([0]);
    File('${b.path}/Other.otf').writeAsBytesSync([0]);

    final found = await scanFonts(roots: [a.path, b.path, a.path]);
    expect(found.length, 2);
  });

  test('missing roots are skipped silently', () async {
    final found = await scanFonts(roots: ['${tempDir.path}/does-not-exist']);
    expect(found, isEmpty);
  });

  test('recurses into subdirectories', () async {
    final nested = await dir('fonts/nested/deep');
    File('${nested.path}/Deep.ttf').writeAsBytesSync([0]);

    final found = await scanFonts(roots: ['${tempDir.path}/fonts']);
    expect(found.single.name, 'Deep');
  });
}
