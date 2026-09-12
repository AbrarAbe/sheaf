import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/ui/dialogs/confirm_delete.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    String title = 'Delete note?',
    String message = 'Are you sure?',
    String confirmLabel = 'Delete',
    IconData? confirmIcon,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showConfirmDeleteDialog(
                context,
                title: title,
                message: message,
                confirmLabel: confirmLabel,
                confirmIcon: confirmIcon,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('renders title and message', (tester) async {
    await pumpDialog(
      tester,
      title: 'Delete note?',
      message: 'Are you sure you want to delete "My Note"?',
    );
    await openDialog(tester);

    expect(find.text('Delete note?'), findsOneWidget);
    expect(find.text('Are you sure you want to delete "My Note"?'), findsOneWidget);
  });

  testWidgets('Cancel is FilledButton (accent), Delete is TextButton (destructive)', (
    tester,
  ) async {
    await pumpDialog(tester);
    await openDialog(tester);

    expect(find.widgetWithText(FilledButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
  });

  testWidgets('Cancel returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showConfirmDeleteDialog(
                  context,
                  title: 'Delete note?',
                  message: 'Are you sure?',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await openDialog(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(result, false);
  });

  testWidgets('Confirm returns true with default label', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showConfirmDeleteDialog(
                  context,
                  title: 'Move to trash?',
                  message: 'Are you sure you want to move "My Note" to trash?',
                  confirmLabel: 'Move to trash',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await openDialog(tester);

    expect(find.text('Move to trash?'), findsOneWidget);
    expect(find.text('Move to trash'), findsOneWidget);

    // Confirm by tapping the TextButton 'Move to trash'
    await tester.tap(find.widgetWithText(TextButton, 'Move to trash'));
    await tester.pumpAndSettle();

    expect(result, true);
  });

  testWidgets('barrier dismiss returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                result = await showConfirmDeleteDialog(
                  context,
                  title: 'Delete note?',
                  message: 'Are you sure?',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await openDialog(tester);

    await tester.tapAt(const Offset(0, 0));
    await tester.pumpAndSettle();

    expect(result, false);
  });

  testWidgets('folder variant shows custom title and message', (tester) async {
    await pumpDialog(
      tester,
      title: 'Delete folder?',
      message:
          'Are you sure you want to delete "My Folder"? All notes inside will be moved to trash.',
    );
    await openDialog(tester);

    expect(find.text('Delete folder?'), findsOneWidget);
    expect(
      find.text(
        'Are you sure you want to delete "My Folder"? All notes inside will be moved to trash.',
      ),
      findsOneWidget,
    );
  });
}
