import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/vault_repository.dart';
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/models/note.dart';
import 'package:sheaf/ui/note_list/list_pane.dart';

import '../../helpers/test_vault.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sheaf_list_test');
  });

  tearDown(() async => tempDir.delete(recursive: true));

  Future<VaultController> pumpList(
    WidgetTester tester, {
    required Future<void> Function(VaultRepository vault) seed,
    Future<Note?> Function()? onCreate,
  }) async {
    final controller = (await tester.runAsync(() => TestVault.seeded(tempDir, seed: seed)))!;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListPane(controller: controller, onCreateNote: onCreate),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('groups rows under day eyebrows with titles', (tester) async {
    await pumpList(
      tester,
      seed: (vault) async {
        await vault.createNote(title: 'Fresh note', body: 'first line here');
        await vault.createNote(title: 'Older note');
      },
    );

    expect(find.text('Fresh note'), findsOneWidget);
    expect(find.text('Older note'), findsOneWidget);
    expect(find.text('first line here'), findsOneWidget);
    // Both created moments apart land in the same day bucket (uppercased eyebrow).
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('filter narrows the visible rows', (tester) async {
    await pumpList(
      tester,
      seed: (vault) async {
        await vault.createNote(title: 'Meeting notes');
        await vault.createNote(title: 'Groceries');
      },
    );

    // Filter starts collapsed; expand it before typing.
    await tester.tap(find.byTooltip('Search notes'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'meet');
    await tester.pump();

    expect(find.text('Meeting notes'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
  });

  testWidgets('tapping a row selects the note', (tester) async {
    final controller = await pumpList(
      tester,
      seed: (vault) async {
        await vault.createNote(title: 'Pick me');
      },
    );

    await tester.tap(find.text('Pick me'));
    await tester.pump();

    expect(controller.selectedNotePath, 'Pick me.md');
  });

  testWidgets('New note affordance is visible with notes present and invokes handler', (
    tester,
  ) async {
    var invoked = 0;
    await pumpList(
      tester,
      onCreate: () async {
        invoked++;
        return null;
      },
      seed: (vault) async {
        await vault.createNote(title: 'Existing');
      },
    );

    expect(find.text('New note'), findsOneWidget);
    await tester.tap(find.text('New note'));
    await tester.pump();
    expect(invoked, 1);
  });

  testWidgets('empty state offers writing the first note', (tester) async {
    var invoked = 0;
    await pumpList(
      tester,
      onCreate: () async {
        invoked++;
        return null;
      },
      seed: (vault) async {},
    );

    expect(find.text('Nothing here yet.'), findsOneWidget);
    await tester.tap(find.text('Write the first note'));
    await tester.pump();
    expect(invoked, 1);
  });
}
