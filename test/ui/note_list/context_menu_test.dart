import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/models/note.dart';
import 'package:sheaf/ui/note_list/list_pane.dart';

import '../../helpers/spy_vault_controller.dart';

Note _note(String title) =>
    Note(path: '$title.md', title: title, body: '$title body', updatedAt: null);

void main() {
  Future<SpyVaultController> pumpList(WidgetTester tester) async {
    final controller = SpyVaultController('/tmp/sheaf_spy_settings.json');
    addTearDown(controller.dispose);
    controller.fakeNotes = [_note('Alpha'), _note('Beta')];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ListPane(controller: controller)),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('secondary click on a row opens a menu with Delete', (tester) async {
    final controller = await pumpList(tester);

    await tester.tap(find.text('Alpha'), buttons: kSecondaryButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    // QuireMenuItem renders its label exactly once.
    expect(find.text('Delete'), findsOneWidget);

    // Quire typography: full-contrast Hanken label, compact row.
    final label = tester.widget<Text>(find.text('Delete'));
    expect(label.style?.fontSize, 13);
    expect(label.style?.fontWeight, FontWeight.w500);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(controller.deleted, ['Alpha.md']);
  });
}
