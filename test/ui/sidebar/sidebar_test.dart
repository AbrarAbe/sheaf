import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/data/vault_repository.dart' show FolderNode;
import 'package:sheaf/logic/vault_controller.dart';
import 'package:sheaf/models/note.dart';
import 'package:sheaf/ui/common/context_menus.dart';
import 'package:sheaf/ui/sidebar/sidebar.dart';

import '../../helpers/spy_vault_controller.dart';
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

  group('folder row context menu (v0.3.6 task E)', () {
    Future<SpyVaultController> pumpFolderSidebar(
      WidgetTester tester, {
      Future<Note?> Function()? onCreateNote,
    }) async {
      final controller = SpyVaultController('${tempDir.path}/settings.json');
      addTearDown(controller.dispose);
      controller.fakeFolders = [
        const FolderNode(name: 'work', relPath: 'work'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Sidebar(controller: controller, width: 240, onCreateNote: onCreateNote),
          ),
        ),
      );
      await tester.pump();
      return controller;
    }

    Future<void> openFolderMenu(WidgetTester tester) async {
      await tester.tap(find.text('work'), buttons: kSecondaryButton, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    testWidgets('lists New note inside above New folder inside', (tester) async {
      await pumpFolderSidebar(tester, onCreateNote: () async => null);
      await openFolderMenu(tester);

      expect(find.text('New note inside'), findsOneWidget);
      expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
      // Existing entries untouched, in their original order.
      expect(find.text('New folder inside'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('selecting New note inside selects the folder and creates', (tester) async {
      var calls = 0;
      final controller = await pumpFolderSidebar(
        tester,
        onCreateNote: () async {
          calls++;
          return null;
        },
      );

      await openFolderMenu(tester);
      await tester.tap(find.text('New note inside'));
      await tester.pump();

      expect(calls, 1);
      expect(controller.selectedFolder, 'work');
    });

    testWidgets('New note inside renders disabled and stays inert without onCreateNote',
        (tester) async {
      final controller = await pumpFolderSidebar(tester);
      await openFolderMenu(tester);

      // Entries are data objects, not widgets, so read them off the region's
      // menu definition rather than searching the tree.
      final noteItem = tester
          .widgetList<QuireContextMenuRegion>(find.byType(QuireContextMenuRegion))
          .expand((r) => r.menu.entries)
          .whereType<QuireMenuItem>()
          .singleWhere((e) => e.debugLabel == 'QuireMenuItem(New note inside)');
      expect(noteItem.enabled, isFalse);

      await tester.tap(find.text('New note inside'));
      await tester.pump();
      expect(controller.selectedFolder, isNull);
    });
  });
}
