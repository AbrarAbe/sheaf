import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/models/note.dart';
import 'package:sheaf/ui/note_list/list_pane.dart';

import '../../helpers/spy_vault_controller.dart';

void main() {
  Future<SpyVaultController> pumpList(WidgetTester tester) async {
    final controller = SpyVaultController('/tmp/sheaf_spy_kb.json');
    addTearDown(controller.dispose);
    controller.fakeNotes = [
      const Note(path: 'A.md', title: 'Alpha', body: 'first'),
      const Note(path: 'B.md', title: 'Beta', body: 'second'),
      const Note(path: 'C.md', title: 'Gamma', body: 'third'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ListPane(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    return controller;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    await tester.pump();
  }

  testWidgets('ArrowDown moves selection down the visible list', (tester) async {
    final controller = await pumpList(tester);
    expect(controller.selectedNotePath, isNull);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(controller.selectedNotePath, 'A.md');

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(controller.selectedNotePath, 'B.md');

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(controller.selectedNotePath, 'C.md');

    // Clamps at the end rather than wrapping.
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(controller.selectedNotePath, 'C.md');
  });

  testWidgets('ArrowUp moves back up and clamps at the top', (tester) async {
    final controller = await pumpList(tester);
    controller.selectNote(controller.visibleNotes.last);

    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(controller.selectedNotePath, 'B.md');

    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(controller.selectedNotePath, 'A.md');

    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(controller.selectedNotePath, 'A.md');
  });

  testWidgets('unscoped toolbar shows the dim All-notes caption', (tester) async {
    await pumpList(tester);

    expect(find.text('All notes'), findsOneWidget);
  });
}
