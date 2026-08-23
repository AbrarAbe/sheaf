import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taker/data/settings_repository.dart';
import 'package:taker/data/vault_repository.dart';
import 'package:taker/logic/vault_controller.dart';
import 'package:taker/ui/sidebar/trash_view.dart';

/// Records which items the dialog asks to mutate, without touching disks.
class SpyVaultController extends VaultController {
  SpyVaultController(String settingsPath)
    : super(
        settings: SettingsRepository(file: File(settingsPath)),
        vaultFactory: (path) => throw UnimplementedError(),
      );

  final restored = <String>[];
  final emptied = <String>[];
  List<TrashEntry> entries = const [];

  @override
  Future<List<TrashEntry>> trash() async => entries;

  @override
  Future<void> restoreFromTrash(String trashedName) async {
    restored.add(trashedName);
    entries = [
      for (final e in entries)
        if (e.trashedName != trashedName) e,
    ];
  }

  @override
  Future<void> emptyTrashItem(String trashedName) async {
    emptied.add(trashedName);
    entries = [
      for (final e in entries)
        if (e.trashedName != trashedName) e,
    ];
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('taker_trash_test');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  Future<SpyVaultController> pumpTrash(WidgetTester tester) async {
    final controller = SpyVaultController('${tempDir.path}/settings.json');
    addTearDown(controller.dispose);
    final entries = [
      TrashEntry(
        trashedName: 'Goner.md',
        isFolder: false,
        originalPath: 'keep/Goner.md',
        trashedAt: DateTime(2026, 1, 1),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrashDialogContent(controller: controller, initial: entries),
        ),
      ),
    );
    return controller;
  }

  testWidgets('lists entries with origin paths', (tester) async {
    await pumpTrash(tester);

    expect(find.text('Goner.md'), findsOneWidget);
    expect(find.text('keep/Goner.md'), findsOneWidget);
  });

  testWidgets('restore delegates to the controller and refreshes', (tester) async {
    final controller = await pumpTrash(tester);

    await tester.tap(find.byTooltip('Restore'));
    await tester.pump();

    expect(controller.restored, ['Goner.md']);
    expect(find.text('Trash is empty.'), findsOneWidget);
  });

  testWidgets('delete forever delegates to the controller and refreshes', (tester) async {
    final controller = await pumpTrash(tester);

    await tester.tap(find.byTooltip('Delete forever'));
    await tester.pump();

    expect(controller.emptied, ['Goner.md']);
    expect(find.text('Trash is empty.'), findsOneWidget);
  });
}
