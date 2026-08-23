import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/ui/sidebar/sidebar.dart';

import '../../helpers/test_vault.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_sidebar_test');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  Future<VaultController> pumpSidebar(WidgetTester tester) async {
    final controller = (await tester.runAsync(
      () => TestVault.seeded(
        tempDir,
        seed: (vault) async {
          await vault.createFolder('work');
          await vault.createFolder('personal');
          await vault.createNote(title: 'A', body: '#work #q3');
          await vault.createNote(title: 'B', body: '#personal stuff #work');
        },
      ),
    ))!;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Sidebar(controller: controller, width: 240)),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('lists folders and tags with counts', (tester) async {
    await pumpSidebar(tester);

    expect(find.text('All notes'), findsOneWidget);
    expect(find.text('work'), findsOneWidget);
    expect(find.text('personal'), findsOneWidget);
    // Tag rows render as "#tag" with a mono count.
    expect(find.text('#work'), findsOneWidget);
    expect(find.text('#q3'), findsOneWidget);
    expect(find.text('#personal'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // #work count
    expect(find.text('Trash'), findsOneWidget);
  });

  testWidgets('tapping a folder scopes selection', (tester) async {
    final controller = await pumpSidebar(tester);

    await tester.tap(find.text('work'));
    await tester.pump();
    expect(controller.selectedFolder, 'work');

    await tester.tap(find.text('All notes'));
    await tester.pump();
    expect(controller.selectedFolder, isNull);
  });

  testWidgets('tapping a tag selects it; tapping again clears', (tester) async {
    final controller = await pumpSidebar(tester);

    await tester.tap(find.text('#work'));
    await tester.pump();
    expect(controller.selectedTag, 'work');

    await tester.tap(find.text('#work'));
    await tester.pump();
    expect(controller.selectedTag, isNull);
  });
}
