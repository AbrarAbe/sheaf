import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/ui/sidebar/trash_view.dart';

import '../../helpers/spy_vault_controller.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_trash_test');
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

  testWidgets('entries carry their trashed-at stamp', (tester) async {
    await pumpTrash(tester);

    // Fixture date is months old → falls back to the absolute date label.
    expect(find.text('Jan 1, 2026'), findsOneWidget);
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
