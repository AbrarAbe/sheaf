import 'dart:io';

import 'package:flutter/gestures.dart';
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

  group('pinning (spec story 13)', () {
    testWidgets('pinned notes get a PINNED eyebrow and float to the top', (tester) async {
      await pumpList(
        tester,
        seed: (vault) async {
          final old = await vault.createNote(title: 'Old but gold', body: 'stale');
          await vault.createNote(title: 'Fresh news', body: 'new');
          await vault.setPinned(old.path, true);
        },
      );

      // Pinned section leads regardless of recency.
      expect(find.text('PINNED'), findsOneWidget);
      final pinnedTitle = tester.getTopLeft(find.text('Old but gold'));
      final freshTitle = tester.getTopLeft(find.text('Fresh news'));
      expect(pinnedTitle.dy, lessThan(freshTitle.dy));

      // Filled pin indicator on the pinned row only.
      final icons = tester.widgetList<Icon>(find.byIcon(Icons.push_pin)).toList();
      expect(icons.length, 1);
      expect(icons.single.color, isNotNull);
    });

    testWidgets('tapping the hover pin toggles the controller state', (tester) async {
      final controller = await pumpList(
        tester,
        seed: (vault) => vault.createNote(title: 'Toggle me'),
      );
      final path = controller.notes.single.path;
      expect(controller.isPinned(path), isFalse);

      // The pin button only paints/hits while the row is hovered.
      final rowCenter = tester.getCenter(find.text('Toggle me'));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: rowCenter);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(rowCenter);
      await tester.pump();

      // togglePin writes meta.json on real disk — wait for the flip
      // deterministically instead of guessing a delay.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(Key('row-pin-${Uri.encodeComponent(path)}')));
        for (var i = 0; i < 50 && !controller.isPinned(path); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
      await tester.pump();

      expect(controller.isPinned(path), isTrue);
      expect(find.text('PINNED'), findsOneWidget);
    });
  });
}
