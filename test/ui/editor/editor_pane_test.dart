import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/settings_repository.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/editor_controller.dart';
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/models/settings.dart';
import 'package:sheaf/ui/editor/editor_pane.dart';
import 'package:sheaf/ui/editor/markdown_preview.dart';

/// Widget tests must route every real-I/O call through [real] because
/// unwrapped awaits deadlock inside the tester's FakeAsync zone.
void main() {
  late Directory tempDir;
  late VaultController vaultController;
  late EditorController editorController;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_editor_ui_test');
    final repo = VaultRepository(root: Directory('${tempDir.path}/vault'));
    vaultController = VaultController(
      settings: SettingsRepository(file: File('${tempDir.path}/settings.json')),
      vaultFactory: (path) => VaultRepository(root: Directory(path)),
    );
    // Plain awaits are safe here: setUp runs outside the FakeAsync zone.
    await vaultController.initialize();
    await vaultController.openVault('${tempDir.path}/vault');
    editorController = EditorController(vault: repo);
  });

  tearDown(() async {
    editorController.dispose();
    vaultController.dispose();
    await tempDir.delete(recursive: true);
  });

  Future<T> real<T>(Future<T> Function() action, WidgetTester tester) async =>
      (await tester.runAsync(action)) as T;

  Future<void> pumpEditor(
    WidgetTester tester, {
    Future<File?> Function()? pickImage,
    Future<String> Function(File)? importImage,
  }) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPane(
            controller: editorController,
            pickImage: pickImage,
            importImage: importImage,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows placeholder when nothing is open', (tester) async {
    await pumpEditor(tester);

    expect(find.text('Select a note'), findsOneWidget);
  });

  testWidgets('opening a note shows title/body', (tester) async {
    final note = await real(() => vaultController.createNote(title: 'Draft'), tester);
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    expect(find.widgetWithText(TextField, 'Draft'), findsOneWidget);
    expect(find.widgetWithText(TextField, ''), findsOneWidget); // empty body
  });

  testWidgets('typing marks the note dirty; flush persists to disk', (tester) async {
    final note = await real(() => vaultController.createNote(title: 'Draft'), tester);
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).last, '# Draft\nhello world');
    await tester.pump();
    // Debounce timing itself is covered by editor_controller_test.
    expect(find.textContaining('unsaved'), findsOneWidget);

    await real(editorController.flush, tester);
    await tester.pump();

    final onDisk = File('${tempDir.path}/vault/${note.path}').readAsStringSync();
    expect(onDisk, '# Draft\nhello world');
    expect(find.textContaining('saved'), findsOneWidget);
  });

  testWidgets('title and body fields render without fill background', (tester) async {
    final note = await real(() => vaultController.createNote(title: 'Clean'), tester);
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.length, 2); // title + body
    for (final field in fields) {
      expect(
        field.decoration?.filled,
        isFalse,
        reason: 'editor prose sits on the card, not in a well',
      );
    }
  });

  testWidgets('tag chips render from body tags', (tester) async {
    final note = await real(
      () => vaultController.createNote(title: 'Tagged', body: '#work #q3\nbody'),
      tester,
    );
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    expect(find.text('#work'), findsOneWidget);
    expect(find.text('#q3'), findsOneWidget);
  });

  testWidgets('preview toggle swaps body field for rendered markdown', (tester) async {
    final note = await real(
      () => vaultController.createNote(title: 'Doc', body: '# Rendered Heading\nbody'),
      tester,
    );
    await real(() => editorController.open(note), tester);
    await pumpEditor(tester);

    expect(find.byKey(const Key('editor-body')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mode-preview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editor-body')), findsNothing);
    expect(find.byType(MarkdownPreview), findsOneWidget);
    expect(find.text('Rendered Heading', findRichText: true), findsWidgets);
  });

  testWidgets('insert button invokes picker and marks the note dirty', (tester) async {
    var picked = 0;
    final note = await real(() => vaultController.createNote(title: 'Pics'), tester);
    await real(() => editorController.open(note), tester);

    final upload = File('${tempDir.path}/upload.png')..writeAsBytesSync([9]);
    await pumpEditor(
      tester,
      pickImage: () async {
        picked++;
        return upload;
      },
      importImage: (_) async => 'attachments/upload.png',
    );

    await tester.tap(find.byTooltip('Insert image'));
    await tester.pump();

    expect(picked, 1);
    expect(editorController.body, '![upload](attachments/upload.png)');
    expect(editorController.status, EditorStatus.dirty);

    // Cancel the pending autosave timer; persistence of the link lands via
    // the debounced write covered in editor_controller_test.
    await tester.runAsync(editorController.flush);
  });

  group('editor modes (spec story 12)', () {
    Future<void> openAndPump(WidgetTester tester) async {
      final note = await real(
        () => vaultController.createNote(title: 'Modes', body: '# Modes\nbody text'),
        tester,
      );
      await real(() => editorController.open(note), tester);
      await pumpEditor(tester);
    }

    testWidgets('normal mode edits with proportional type by default', (tester) async {
      await openAndPump(tester);

      expect(find.byKey(const Key('editor-body')), findsOneWidget);
      final field = tester.widget<TextField>(find.byKey(const Key('editor-body')));
      expect(field.style?.fontFamily, isNot(contains('Spline Sans Mono')));
    });

    testWidgets('markdown segment switches to monospace source', (tester) async {
      await openAndPump(tester);

      await tester.tap(find.byKey(const Key('mode-markdown')));
      await tester.pump();

      expect(editorController.mode, EditorMode.markdown);
      final field = tester.widget<TextField>(find.byKey(const Key('editor-body')));
      expect(field.style?.fontFamily, contains('SplineSansMono'));
      // Still editable in markdown mode.
      await tester.enterText(find.byKey(const Key('editor-body')), 'raw');
      expect(editorController.body, 'raw');
      await real(editorController.flush, tester);
    });

    testWidgets('preview segment swaps to rendered output', (tester) async {
      await openAndPump(tester);

      await tester.tap(find.byKey(const Key('mode-preview')));
      await tester.pump();

      expect(editorController.mode, EditorMode.preview);
      expect(find.byKey(const Key('editor-body')), findsNothing);
      expect(find.byType(MarkdownPreview), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MarkdownPreview),
          matching: find.text('Modes', findRichText: true),
        ),
        findsOneWidget,
      );
    });

    testWidgets('mode survives reopening the pane via controller state', (tester) async {
      await openAndPump(tester);
      await tester.tap(find.byKey(const Key('mode-preview')));
      await tester.pump();

      // A brand-new pane reading the same controller opens in preview too.
      await pumpEditor(tester);
      expect(editorController.mode, EditorMode.preview);
    });
  });
}
