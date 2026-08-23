import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/ui/editor/markdown_preview.dart';

// 1×1 transparent PNG.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhf'
  'DwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_preview_test');
    final att = Directory('${tempDir.path}/attachments')..createSync();
    File('${att.path}/pic.png').writeAsBytesSync(_pngBytes);
  });

  tearDown(() async => tempDir.delete(recursive: true));

  Future<void> pumpPreview(WidgetTester tester, String body, {double width = 800}) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownPreview(body: body, vaultRoot: tempDir),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders headings, emphasis, lists, quotes, code', (tester) async {
    await pumpPreview(tester, '''
# Big Title

Some **bold** and *italic* text.

- item one
- item two

> quoted wisdom

```
code line
```

| A | B |
|---|---|
| 1 | 2 |
''');

    expect(find.text('Big Title', findRichText: true), findsOneWidget);
    expect(find.text('item one', findRichText: true), findsOneWidget);
    expect(find.text('quoted wisdom', findRichText: true), findsOneWidget);
    expect(find.text('code line', findRichText: true), findsOneWidget);
    expect(find.text('1', findRichText: true), findsOneWidget);
  });

  testWidgets('sized images render at their declared width', (tester) async {
    await pumpPreview(tester, 'before ![a pic|300](attachments/pic.png) after');

    final box = tester.renderObject<RenderBox>(find.byKey(const Key('md-img-300')));
    expect(box.size.width, 300);
  });

  testWidgets('bare images get natural size constraint', (tester) async {
    await pumpPreview(tester, '![plain](attachments/pic.png)');

    expect(find.byKey(const Key('md-img-natural')), findsOneWidget);
  });

  testWidgets('missing files show broken-image fallback with alt text', (tester) async {
    await pumpPreview(tester, '![ghost pic](attachments/none.png)');

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.broken_image), findsOneWidget);
  });
}
