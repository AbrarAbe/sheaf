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

    // Create the files on disk so NoteInfoDialog can stat them.
    for (final n in controller.fakeNotes) {
      controller.fileOf(n.path).createSync(recursive: true);
      controller.fileOf(n.path).writeAsStringSync('${n.title} body');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ListPane(controller: controller)),
      ),
    );
    await tester.pump();
    return controller;
  }

  group('NoteRow context menu (Task 5)', () {
    testWidgets('Info entry appears alongside Trash/Delete', (tester) async {
      await pumpList(tester);

      await tester.tap(find.text('Alpha'), buttons: kSecondaryButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('tapping Info opens NoteInfoDialog', (tester) async {
      await pumpList(tester);

      await tester.tap(find.text('Alpha'), buttons: kSecondaryButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Info'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Note Info'), findsOneWidget);
      expect(find.text('Filename'), findsOneWidget);
      expect(find.text('Path'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      expect(find.text('Modified'), findsOneWidget);
      // Both Created and Modified should include time
      expect(find.textContaining(' at '), findsAtLeastNWidgets(2));
    });

    testWidgets('Info dialog can be dismissed via Close', (tester) async {
      await pumpList(tester);

      await tester.tap(find.text('Alpha'), buttons: kSecondaryButton, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();

      expect(find.text('Note Info'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Note Info'), findsNothing);
    });
  });
}
