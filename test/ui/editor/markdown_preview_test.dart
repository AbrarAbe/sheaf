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
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownPreview(body: body, vaultRoot: tempDir, scrollController: scrollController),
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

  testWidgets('images with whitespace in filename render via URL encoding',
      (tester) async {
    // Files are stored verbatim on disk (`My Photo.png`) but appear in
    // markdown as URL-encoded (`My%20Photo.png`) because spaces aren't
    // valid in markdown URLs. The resolver must decode before lookup.
    final att = Directory('${tempDir.path}/attachments')..createSync();
    File('${att.path}/My Photo.png').writeAsBytesSync(_pngBytes);
    await pumpPreview(tester, '![a pic|300](attachments/My%20Photo.png)');

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

  testWidgets('renders <u> spans underlined', (tester) async {
    await pumpPreview(tester, 'plain <u>under here</u> end');

    final finder = find.byWidgetPredicate(
      (w) => w is RichText && _hasUnderlinedText(w.text, 'under here'),
    );
    expect(finder, findsOneWidget);
  });

  testWidgets('links use theme accent color (v0.3.4 Task 7)', (tester) async {
    // Render with a MaterialTheme that has a distinctive primary color so the
    // assertion is unambiguous.
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    const accent = Color(0xFF123456);
    final theme = ThemeData(
      colorScheme: const ColorScheme.light().copyWith(primary: accent),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: MarkdownPreview(
            body: 'see [docs](https://example.com/docs) for more',
            vaultRoot: tempDir,
            scrollController: scrollController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Walk every RichText's TextSpan tree and find the 'docs' span; assert
    // its color matches the theme's primary color.
    final linkFinder = find.byWidgetPredicate(
      (w) => w is RichText && _hasSpanWithStyle(w.text, 'docs', accent),
    );
    expect(linkFinder, findsOneWidget, reason: 'link span with theme accent color not found');
  });

  testWidgets('pre-migration attachments/ path resolves after rename (v0.3.4 Task 6)',
      (tester) async {
    // Post-migration state: the directory was renamed to `.attachments/`
    // but old notes still say `attachments/foo.png` in their markdown.
    // The resolver must fall back to the legacy path when the canonical
    // path does not exist. The setUp created the file at the legacy
    // path; move it to the new location to simulate the migration.
    final migrated = Directory('${tempDir.path}/.attachments')..createSync();
    File('${tempDir.path}/attachments/pic.png').copySync('${migrated.path}/pic.png');
    await pumpPreview(tester, '![a pic|300](attachments/pic.png)');

    final box = tester.renderObject<RenderBox>(find.byKey(const Key('md-img-300')));
    expect(box.size.width, 300);
  });

  testWidgets('canonical .attachments/ path still resolves (v0.3.4 Task 6)',
      (tester) async {
    // Post-migration imports write to `.attachments/`. The resolver must
    // keep finding those files (regression guard against the fallback
    // logic above).
    final migrated = Directory('${tempDir.path}/.attachments')..createSync();
    File('${migrated.path}/pic.png').writeAsBytesSync(_pngBytes);
    await pumpPreview(tester, '![a pic|300](.attachments/pic.png)');

    final box = tester.renderObject<RenderBox>(find.byKey(const Key('md-img-300')));
    expect(box.size.width, 300);
  });

  testWidgets('other raw HTML stays literal text', (tester) async {
    await pumpPreview(tester, '<script>alert(1)</script>');

    expect(_visibleText(tester), contains('<script>'));
  });

  testWidgets('any leading-space indent on non-list lines is stripped from prose', (tester) async {
    // 1, 2, 3, 4, 5 spaces and a tab all render as a dedented paragraph.
    // None of them should render as a `<pre>` code block, and the raw
    // leading spaces must not appear in the visible text.
    for (final indent in [
      ' ',
      '  ',
      '   ',
      '    ',
      '     ',
      '        ',
      '\t',
      '\t\t',
    ]) {
      final body = 'before\n\n${indent}indented line one\n${indent}indented line two\n\nafter';
      await pumpPreview(tester, body);

      // The indented block becomes one paragraph containing both lines,
      // with no residual leading whitespace.
      final visible = _visibleText(tester);
      expect(visible, contains('indented line one'));
      expect(visible, contains('indented line two'));
      // Surrounding prose still renders.
      expect(find.text('before', findRichText: true), findsOneWidget);
      expect(find.text('after', findRichText: true), findsOneWidget);
      // No RichText should carry the raw indentation prefix.
      expect(visible, isNot(contains('${indent}indented')));
    }
  });

  testWidgets('nested lists still nest by indentation', (tester) async {
    await pumpPreview(tester, '- parent\n  - child\n    - grandchild');

    // Nested list items render as part of a composite TextSpan tree, so
    // match on the accumulated visible text rather than exact-match spans.
    final body = _visibleText(tester);
    expect(body, contains('parent'));
    expect(body, contains('child'));
    expect(body, contains('grandchild'));
  });

  testWidgets('fenced code blocks still render as code', (tester) async {
    await pumpPreview(tester, '```\nvoid main() {}\n```');

    expect(find.text('void main() {}', findRichText: true), findsOneWidget);
  });
}

bool _hasUnderlinedText(InlineSpan span, String needle) {
  if (span is TextSpan) {
    if ((span.text ?? '').contains(needle) && span.style?.decoration == TextDecoration.underline) {
      return true;
    }
    return span.children?.any((c) => _hasUnderlinedText(c, needle)) ?? false;
  }
  return false;
}

bool _hasSpanWithStyle(InlineSpan span, String needle, Color color) {
  if (span is TextSpan) {
    if (span.text == needle && span.style?.color == color) return true;
    return span.children?.any((c) => _hasSpanWithStyle(c, needle, color)) ?? false;
  }
  return false;
}

String _visibleText(WidgetTester tester) {
  final buffer = StringBuffer();
  void walk(InlineSpan span) {
    if (span is TextSpan) {
      if (span.text != null) buffer.write(span.text);
      span.children?.forEach(walk);
    }
  }

  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    walk(rt.text);
  }
  return buffer.toString();

}
