import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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

  testWidgets('folder scope shows a removable chip; clearing restores all notes', (tester) async {
    final controller = await pumpList(
      tester,
      seed: (vault) async {
        await vault.createFolder('proj');
        await vault.createNote(title: 'Meeting notes', folder: 'proj');
        await vault.createNote(title: 'Groceries');
      },
    );
    // Unfiltered view shows the immediate-parent folder label.
    expect(find.text('Vault root'), findsOneWidget);
    expect(find.text('proj'), findsOneWidget);

    controller.selectFolder('proj');
    await tester.pump();

    // Folder-scoped view hides the directory label.
    expect(find.text('Vault root'), findsNothing);
    expect(find.text('proj'), findsNothing);
    expect(find.text('in proj'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);

    await tester.tap(find.byKey(const Key('scope-chip-folder')));
    await tester.pump();

    expect(controller.selectedFolder, isNull);
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('tag scope shows a #chip that clears on tap', (tester) async {
    final controller = await pumpList(
      tester,
      seed: (vault) async {
        await vault.createNote(title: 'Tagged', body: 'has #urgent inside');
        await vault.createNote(title: 'Plain');
      },
    );
    controller.selectTag('urgent');
    await tester.pump();

    expect(find.byKey(const Key('scope-chip-tag')), findsOneWidget);
    expect(find.text('Plain'), findsNothing);

    await tester.tap(find.byKey(const Key('scope-chip-tag')));
    await tester.pump();

    expect(controller.selectedTag, isNull);
    expect(find.text('Plain'), findsOneWidget);
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

    testWidgets('pinned toggle collapses and re-expands the section', (tester) async {
      final controller = await pumpList(
        tester,
        seed: (vault) async {
          final old = await vault.createNote(title: 'Old but gold', body: 'stale');
          await vault.createNote(title: 'Fresh news', body: 'new');
          await vault.setPinned(old.path, true);
        },
      );

      // Default expanded: pinned rows visible and the section toggle present.
      expect(controller.settings.pinnedExpanded, isTrue);
      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('Old but gold'), findsOneWidget);
      expect(find.byKey(const Key('pinned-toggle')), findsOneWidget);

      // Collapse — persists the flag and hides the pinned rows, but keeps the
      // section header so it can be re-expanded. The button discards the
      // setPinnedExpanded future, which notifies only after an awaited disk
      // save, so settle across several real pump+delay frames before asserting.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('pinned-toggle')));
        for (var i = 0; i < 15; i++) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump();

      expect(controller.settings.pinnedExpanded, isFalse);
      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('Old but gold'), findsNothing);

      // Re-expand restores the rows.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('pinned-toggle')));
        for (var i = 0; i < 15; i++) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump();

      expect(controller.settings.pinnedExpanded, isTrue);
      expect(find.text('Old but gold'), findsOneWidget);
    });

    testWidgets('pinned count chip is grey when expanded and accented when collapsed', (
      tester,
    ) async {
      final controller = await pumpList(
        tester,
        seed: (vault) async {
          final a = await vault.createNote(title: 'Pin A');
          final b = await vault.createNote(title: 'Pin B');
          await vault.setPinned(a.path, true);
          await vault.setPinned(b.path, true);
        },
      );

      Color chipColor() => tester
          .widget<Text>(
            find.descendant(of: find.byKey(const Key('pinned-count')), matching: find.byType(Text)),
          )
          .style!
          .color!;

      // Expanded: the chip shows the pinned total in the grey treatment.
      expect(find.byKey(const Key('pinned-count')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      final expandedColor = chipColor();

      // Collapse — the chip stays visible as a handle but changes treatment.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('pinned-toggle')));
        for (var i = 0; i < 15; i++) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pump();

      expect(controller.settings.pinnedExpanded, isFalse);
      expect(find.byKey(const Key('pinned-count')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      final collapsedColor = chipColor();

      // Collapsed drops the grey expanded treatment for an accent.
      expect(collapsedColor, isNot(equals(expandedColor)));
    });

    testWidgets('pinned toggle carries hand cursor', (tester) async {
      await pumpList(
        tester,
        seed: (vault) async {
          final old = await vault.createNote(title: 'Old but gold', body: 'stale');
          await vault.setPinned(old.path, true);
        },
      );
      final region = find.ancestor(
        of: find.byKey(const Key('pinned-toggle')),
        matching: find.byType(MouseRegion),
      );
      expect(tester.widget<MouseRegion>(region).cursor, SystemMouseCursors.click);
    });
  });
}
