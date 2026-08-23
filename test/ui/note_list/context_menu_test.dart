import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taker/models/note.dart';
import 'package:taker/ui/note_list/list_pane.dart';

import '../../helpers/spy_vault_controller.dart';

Note _note(String title) =>
    Note(path: '$title.md', title: title, body: '$title body', updatedAt: null);

void main() {
  Future<SpyVaultController> pumpList(WidgetTester tester) async {
    final controller = SpyVaultController('/tmp/taker_spy_settings.json');
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

    // The library renders entry text more than once (visual + semantics).
    expect(find.text('Delete'), findsWidgets);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(controller.deleted, ['Alpha.md']);
  });

  testWidgets('filter starts collapsed as an icon and expands on tap', (tester) async {
    await pumpList(tester);

    expect(find.byType(TextField), findsNothing);
    expect(byTooltip('Search notes'), findsOneWidget);

    await tester.tap(byTooltip('Search notes'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'alp');
    await tester.pump();
    expect(find.text('Beta'), findsNothing);

    await tester.tap(byTooltip('Close search'));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Beta'), findsOneWidget);
  });
}

Finder byTooltip(String message) => find.byTooltip(message);
