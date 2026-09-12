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

  testWidgets('secondary click on a row opens context menu with Trash and Delete', (tester) async {
    final controller = await pumpList(tester);

    await tester.tap(find.text('Alpha'), buttons: kSecondaryButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Context menu has both "Trash" and "Delete".
    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Tap "Trash" to move the note to trash.
    await tester.tap(find.text('Trash'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Confirmation dialog appears — tap "Move to trash" to confirm.
    await tester.tap(find.widgetWithText(TextButton, 'Move to trash'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(controller.deleted, ['Alpha.md']);
  });
}
