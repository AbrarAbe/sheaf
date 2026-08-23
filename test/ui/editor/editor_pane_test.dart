import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taker/data/settings_repository.dart';
import 'package:taker/data/vault_repository.dart';
import 'package:taker/logic/editor_controller.dart';
import 'package:taker/logic/vault_controller.dart';
import 'package:taker/ui/editor/editor_pane.dart';

/// Widget tests must route every real-I/O call through [real] because
/// unwrapped awaits deadlock inside the tester's FakeAsync zone.
void main() {
  late Directory tempDir;
  late VaultController vaultController;
  late EditorController editorController;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taker_editor_ui_test');
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

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EditorPane(controller: editorController)),
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
}
